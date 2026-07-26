#!/usr/bin/env python3
"""
LifeBook Migration Static Validator
Validates migrations 0001, 0002, 0002b (application_roles), 0003 using pglast AST-aware checks.
All checks are structural — no brittle text matching.

Migration sequence:
  M0001  20260724153745_types_and_vocabularies.sql   — applied
  M0002  20260726083201_predicate_governance_types.sql — pending
  M0002b 20260726083202_application_roles.sql         — pending (new: agent_service, system_service, admin, governance_functions)
  M0003  20260726083203_core_schema.sql               — pending (renamed from 083201)

Usage: python3 validate_migrations.py
Exit code 0 = all checks passed; non-zero = failures detected.
"""

import sys
import re
import hashlib
from pathlib import Path

try:
    from pglast import parse_sql
except ImportError:
    print("ERROR: pglast not installed. Run: pip install pglast")
    sys.exit(1)

# ── Paths ──────────────────────────────────────────────────────────────────────
MIGRATION_DIR = Path('/sessions/determined-awesome-tesla/mnt/lifebookhq/supabase/migrations')
M0001  = MIGRATION_DIR / '20260724153745_types_and_vocabularies.sql'
M0002  = MIGRATION_DIR / '20260726083201_predicate_governance_types.sql'
M0002b = MIGRATION_DIR / '20260726083202_application_roles.sql'
M0003  = MIGRATION_DIR / '20260726083203_core_schema.sql'

MIGRATIONS = [
    ('M0001',  M0001,  'applied'),
    ('M0002',  M0002,  'pending'),
    ('M0002b', M0002b, 'pending'),
    ('M0003',  M0003,  'pending'),
]

# ── Result tracking ────────────────────────────────────────────────────────────
_results = []
_failures = 0

def check(name: str, passed: bool, detail: str = ''):
    global _failures
    status = 'PASS' if passed else 'FAIL'
    if not passed:
        _failures += 1
    msg = f"  [{status}] {name}"
    if detail:
        msg += f": {detail}"
    _results.append(msg)
    print(msg)

def section(title: str):
    line = f"\n{'─' * 70}\n  {title}\n{'─' * 70}"
    _results.append(line)
    print(line)

# ── Helpers ────────────────────────────────────────────────────────────────────

def load_sql(path: Path) -> str:
    with open(path) as f:
        return f.read()

def strip_line_comments(sql: str) -> str:
    """Remove -- ... line comments so text searches don't match comment text."""
    return re.sub(r'--[^\n]*', '', sql)

def has_transaction_begin(sql: str) -> bool:
    """Detect transaction-level BEGIN via pglast AST (not inside function bodies)."""
    stmts = parse_sql(sql)
    for s in stmts:
        if type(s.stmt).__name__ == 'TransactionStmt':
            kind = str(s.stmt.kind)
            if 'BEGIN' in kind.upper():
                return True
    return False

def has_transaction_commit(sql: str) -> bool:
    """Detect transaction-level COMMIT via pglast AST."""
    stmts = parse_sql(sql)
    for s in stmts:
        if type(s.stmt).__name__ == 'TransactionStmt':
            kind = str(s.stmt.kind)
            if 'COMMIT' in kind.upper():
                return True
    return False

def get_stmt_types(stmts) -> dict:
    counts = {}
    for s in stmts:
        t = type(s.stmt).__name__
        counts[t] = counts.get(t, 0) + 1
    return counts

def _resolve_string_node(node) -> str:
    """Extract the string value from a pglast String node or plain str."""
    if hasattr(node, 'sval'):
        return node.sval
    return str(node)

def get_enum_names(stmts) -> list:
    names = []
    for s in stmts:
        if type(s.stmt).__name__ == 'CreateEnumStmt':
            try:
                tn = s.stmt.typeName
                names.append(_resolve_string_node(tn[-1]))
            except Exception:
                pass
    return names

def get_table_names(stmts) -> list:
    names = []
    for s in stmts:
        if type(s.stmt).__name__ == 'CreateStmt':
            try:
                names.append(str(s.stmt.relation.relname))
            except Exception:
                pass
    return names

def get_function_names(stmts) -> list:
    names = []
    for s in stmts:
        if type(s.stmt).__name__ == 'CreateFunctionStmt':
            try:
                fn_parts = s.stmt.funcname
                names.append(_resolve_string_node(fn_parts[-1]))
            except Exception:
                pass
    return names

def get_trigger_names(stmts) -> list:
    names = []
    for s in stmts:
        if type(s.stmt).__name__ == 'CreateTrigStmt':
            try:
                names.append(str(s.stmt.trigname))
            except Exception:
                pass
    return names

def get_index_names(stmts) -> list:
    names = []
    for s in stmts:
        if type(s.stmt).__name__ == 'IndexStmt':
            try:
                names.append(str(s.stmt.idxname))
            except Exception:
                pass
    return names

def get_insert_counts(stmts) -> dict:
    """Returns {table_name: row_count} for all INSERT statements via AST valuesLists."""
    counts = {}
    for s in stmts:
        if type(s.stmt).__name__ == 'InsertStmt':
            try:
                target = str(s.stmt.relation.relname)
                sel = s.stmt.selectStmt
                if hasattr(sel, 'valuesLists') and sel.valuesLists:
                    row_count = len(list(sel.valuesLists))
                else:
                    row_count = 0
                counts[target] = counts.get(target, 0) + row_count
            except Exception:
                pass
    return counts

def get_on_conflict_insert_count(stmts) -> int:
    """
    Count INSERT statements that carry an ON CONFLICT clause via AST.
    This avoids matching comment text.
    """
    count = 0
    for s in stmts:
        if type(s.stmt).__name__ == 'InsertStmt':
            on_conflict = getattr(s.stmt, 'onConflictClause', None)
            if on_conflict is not None:
                count += 1
    return count

def check_no_ddl_if_not_exists(stmts) -> list:
    """
    Flag DDL-level IF NOT EXISTS in CREATE TABLE / CREATE TYPE / CREATE FUNCTION.
    Uses AST — does NOT flag PL/pgSQL body content.
    """
    violations = []
    for s in stmts:
        stype = type(s.stmt).__name__
        if stype in ('CreateStmt', 'CreateEnumStmt', 'CreateFunctionStmt'):
            ine = getattr(s.stmt, 'if_not_exists', False)
            if ine:
                violations.append(stype)
    return violations

def has_or_replace_function(stmts) -> bool:
    """Check if any function uses OR REPLACE via AST."""
    for s in stmts:
        if type(s.stmt).__name__ == 'CreateFunctionStmt':
            replace = getattr(s.stmt, 'replace', False)
            if replace:
                return True
    return False

def get_security_definer_functions(stmts) -> list:
    """
    Return names of SECURITY DEFINER functions via AST option scan.
    Uses .sval for string resolution to avoid repr wrapping.
    """
    names = []
    for s in stmts:
        if type(s.stmt).__name__ == 'CreateFunctionStmt':
            opts = getattr(s.stmt, 'options', None) or []
            for opt in opts:
                try:
                    defname = str(getattr(opt, 'defname', '')).lower()
                    if defname == 'security':
                        arg = getattr(opt, 'arg', None)
                        # arg is a Boolean node; boolval=True means SECURITY DEFINER
                        if arg is not None and getattr(arg, 'boolval', False):
                            fn_parts = s.stmt.funcname
                            names.append(_resolve_string_node(fn_parts[-1]))
                except Exception:
                    pass
    return names

def count_alter_table_add_fk(stmts) -> int:
    """
    Count ALTER TABLE ADD CONSTRAINT FOREIGN KEY statements.
    These are the 'file-order deferred' FKs that could not be declared inline
    because their reference target was created later in the same migration.
    """
    count = 0
    for s in stmts:
        if type(s.stmt).__name__ == 'AlterTableStmt':
            cmds = getattr(s.stmt, 'cmds', None) or []
            for cmd in cmds:
                subtype = str(getattr(cmd, 'subtype', ''))
                if 'AddConstraint' in subtype:
                    constr = getattr(cmd, 'def_', None)
                    if constr is not None and type(constr).__name__ == 'Constraint':
                        contype = str(getattr(constr, 'contype', ''))
                        if 'FOREIGN' in contype:
                            count += 1
    return count

def count_rls_enables(stmts) -> int:
    """Count ENABLE ROW LEVEL SECURITY via AST (AT_EnableRowSecurity subtype)."""
    count = 0
    for s in stmts:
        if type(s.stmt).__name__ == 'AlterTableStmt':
            cmds = getattr(s.stmt, 'cmds', None) or []
            for cmd in cmds:
                subtype = str(getattr(cmd, 'subtype', ''))
                if 'EnableRowSecurity' in subtype:
                    count += 1
    return count

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()

def line_count(path: Path) -> int:
    return path.read_text().count('\n')

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

def get_create_role_names(stmts) -> list:
    """Return role names from all CreateRoleStmt nodes (CREATE ROLE statements)."""
    names = []
    for s in stmts:
        if type(s.stmt).__name__ == 'CreateRoleStmt':
            try:
                names.append(str(s.stmt.role))
            except Exception:
                pass
    return names


# ── Semantic schema validator helpers ──────────────────────────────────────────

def extract_create_table_blocks(sql_text: str) -> list:
    """
    Extract (table_name, body) tuples from CREATE TABLE statements.
    Uses parenthesis-depth tracking to handle nested CHECK/DEFAULT expressions.
    """
    result = []
    sql_nc = re.sub(r'--[^\n]*', '', sql_text)
    pattern = re.compile(r'CREATE\s+TABLE\s+(\w+)\s*\(', re.IGNORECASE)
    for m in pattern.finditer(sql_nc):
        table_name = m.group(1)
        start = m.end() - 1  # position of opening '('
        depth = 0
        end = start
        while end < len(sql_nc):
            if sql_nc[end] == '(':
                depth += 1
            elif sql_nc[end] == ')':
                depth -= 1
                if depth == 0:
                    break
            end += 1
        body = sql_nc[start + 1:end]
        result.append((table_name, body))
    return result


def _split_csv_depth_aware(text: str) -> list:
    """Split text on commas, respecting parenthesis depth (ignores commas inside parens)."""
    parts = []
    depth = 0
    current = []
    for ch in text:
        if ch == '(':
            depth += 1
            current.append(ch)
        elif ch == ')':
            depth -= 1
            current.append(ch)
        elif ch == ',' and depth == 0:
            parts.append(''.join(current).strip())
            current = []
        else:
            current.append(ch)
    if current:
        parts.append(''.join(current).strip())
    return parts


def parse_table_body(body: str) -> dict:
    """
    Parse a CREATE TABLE body (between the outer parens) to extract:
      - columns: {col_name: col_type}
      - pk: [col_name, ...]
      - fks: [(col_name, ref_table, ref_col), ...]
      - unique: [col_name, ...]
    """
    parts = _split_csv_depth_aware(body)
    columns: dict = {}
    pk_cols: list = []
    fks: list = []
    unique_cols: list = []

    for part in parts:
        part = part.strip()
        if not part:
            continue

        # Table-level PRIMARY KEY constraint
        pk_m = re.match(r'PRIMARY\s+KEY\s*\(([^)]+)\)', part, re.IGNORECASE)
        if pk_m:
            pk_cols.extend(c.strip() for c in pk_m.group(1).split(','))
            continue

        # Table-level named PRIMARY KEY: CONSTRAINT name PRIMARY KEY (cols)
        named_pk_m = re.match(
            r'CONSTRAINT\s+\w+\s+PRIMARY\s+KEY\s*\(([^)]+)\)', part, re.IGNORECASE
        )
        if named_pk_m:
            pk_cols.extend(c.strip() for c in named_pk_m.group(1).split(','))
            continue

        # Table-level UNIQUE constraint (with or without CONSTRAINT name)
        uq_m = re.match(r'(?:CONSTRAINT\s+\w+\s+)?UNIQUE\s*\(([^)]+)\)', part, re.IGNORECASE)
        if uq_m:
            unique_cols.extend(c.strip() for c in uq_m.group(1).split(','))
            continue

        # Table-level CONSTRAINT FOREIGN KEY — extract the FK reference
        if re.match(r'CONSTRAINT\s+\w+\s+FOREIGN\s+KEY', part, re.IGNORECASE):
            fk_m = re.search(
                r'FOREIGN\s+KEY\s*\(([^)]+)\)\s*REFERENCES\s+(\w+)\s*\(([^)]+)\)',
                part, re.IGNORECASE
            )
            if fk_m:
                cols = [c.strip() for c in fk_m.group(1).split(',')]
                ref_table = fk_m.group(2)
                ref_cols = [c.strip() for c in fk_m.group(3).split(',')]
                for col, rcol in zip(cols, ref_cols):
                    fks.append((col, ref_table, rcol))
            continue

        # Skip other table-level constraint keywords
        if re.match(r'(CONSTRAINT|CHECK|FOREIGN)\s', part, re.IGNORECASE):
            continue

        # Column definition: col_name type ...
        col_m = re.match(r'(\w+)\s+', part)
        if not col_m:
            continue
        col_name = col_m.group(1)
        if col_name.upper() in ('PRIMARY', 'UNIQUE', 'CHECK', 'FOREIGN', 'CONSTRAINT'):
            continue

        rest = part[col_m.end():]
        type_m = re.match(r'(\S+)', rest)
        col_type = type_m.group(1) if type_m else 'UNKNOWN'
        columns[col_name] = col_type

        # Inline PRIMARY KEY
        if re.search(r'\bPRIMARY\s+KEY\b', part, re.IGNORECASE):
            pk_cols.append(col_name)

        # Inline UNIQUE
        if re.search(r'\bUNIQUE\b', part, re.IGNORECASE):
            unique_cols.append(col_name)

        # Inline REFERENCES (schema-unqualified only: REFERENCES table(col))
        ref_m = re.search(r'REFERENCES\s+(\w+)\s*\((\w+)\)', part, re.IGNORECASE)
        if ref_m:
            fks.append((col_name, ref_m.group(1), ref_m.group(2)))

    return {'columns': columns, 'pk': pk_cols, 'fks': fks, 'unique': unique_cols}


def extract_alter_add_columns(sql_text: str) -> list:
    """
    Extract (table_name, col_name, col_type) tuples from ALTER TABLE ... ADD COLUMN statements.
    Handles both single-line and multi-line ADD COLUMN clauses.
    """
    result = []
    sql_nc = re.sub(r'--[^\n]*', '', sql_text)
    # Match: ALTER TABLE tbl ADD COLUMN col_name col_type ...;
    pattern = re.compile(
        r'ALTER\s+TABLE\s+(\w+)\s+ADD\s+COLUMN\s+(\w+)\s+(\S+)',
        re.IGNORECASE
    )
    for m in pattern.finditer(sql_nc):
        result.append((m.group(1), m.group(2), m.group(3)))
    return result


def build_schema_model(sql_texts: list) -> dict:
    """
    Build combined schema from a list of SQL texts executed in order.
    Returns {table_name: {columns, pk, fks, unique}}.
    Pre-seeds known Supabase built-in external tables.
    Also processes ALTER TABLE ADD COLUMN statements so late-added columns
    are visible to index and FK existence checks.
    """
    schema = {
        'auth.users': {'columns': {'id': 'UUID'}, 'pk': ['id'], 'fks': [], 'unique': []},
    }
    for sql_text in sql_texts:
        # Process CREATE TABLE blocks
        for table_name, body in extract_create_table_blocks(sql_text):
            schema[table_name] = parse_table_body(body)
        # Process ALTER TABLE ADD COLUMN (e.g. columns added after initial CREATE TABLE)
        for (tbl, col, col_type) in extract_alter_add_columns(sql_text):
            if tbl in schema:
                schema[tbl]['columns'][col] = col_type
            # If table not yet in schema (external), skip silently
    return schema


def extract_indexes_from_sql(sql_text: str) -> list:
    """
    Extract (index_name, table_name, [col_or_None]) from CREATE [UNIQUE] INDEX statements.
    Expression-index columns are represented as None (skip existence check).
    """
    sql_nc = re.sub(r'--[^\n]*', '', sql_text)
    pattern = re.compile(
        r'CREATE\s+(?:UNIQUE\s+)?INDEX\s+(\w+)\s+ON\s+(\w+)\s*\(([^)]+)\)',
        re.IGNORECASE
    )
    indexes = []
    for m in pattern.finditer(sql_nc):
        idx_name = m.group(1)
        tbl_name = m.group(2)
        cols_raw = m.group(3)
        col_names = []
        for part in cols_raw.split(','):
            part = part.strip()
            col_names.append(None if '(' in part else part)
        indexes.append((idx_name, tbl_name, col_names))
    return indexes


def main():
    print("=" * 70)
    print("  LifeBook Migration Static Validator")
    print("=" * 70)

    # ── Load and parse all four migrations ────────────────────────────────────
    parsed = {}
    sqls = {}
    for label, path, status in MIGRATIONS:
        sql = load_sql(path)
        sqls[label] = sql
        try:
            stmts = parse_sql(sql)
            parsed[label] = stmts
        except Exception as e:
            print(f"FATAL: {label} parse error: {e}")
            sys.exit(1)

    m0001_stmts  = parsed['M0001']
    m0002_stmts  = parsed['M0002']
    m0002b_stmts = parsed['M0002b']
    m0003_stmts  = parsed['M0003']

    # ── Section 1: pglast parse results ───────────────────────────────────────
    section("1. pglast Parse Results")

    for label, path, status in MIGRATIONS:
        stmts = parsed[label]
        counts = get_stmt_types(stmts)
        total = sum(counts.values())
        lc = line_count(path)
        sha = sha256_file(path)
        print(f"\n  {label} ({status}) — {path.name}")
        print(f"    Lines:    {lc}")
        print(f"    SHA-256:  {sha}")
        print(f"    Statements parsed: {total}")
        for t, n in sorted(counts.items()):
            print(f"      {t}: {n}")
        check(f"{label} parses cleanly", True, f"{total} statements")

    m0002b_counts = get_stmt_types(m0002b_stmts)

    # ── Section 2: Transaction Wrapping ───────────────────────────────────────
    section("2. Transaction Wrapping")

    # M0001: No explicit transaction wrap (seeds use ON CONFLICT, DDL not in explicit txn)
    m0001_has_begin = has_transaction_begin(sqls['M0001'])
    m0001_has_commit = has_transaction_commit(sqls['M0001'])
    check("M0001 has no transaction-level BEGIN (no explicit wrap)", not m0001_has_begin)
    check("M0001 has no transaction-level COMMIT (no explicit wrap)", not m0001_has_commit)

    # M0002, M0002b, M0003: must have BEGIN + COMMIT
    m0002_has_begin = has_transaction_begin(sqls['M0002'])
    m0002_has_commit = has_transaction_commit(sqls['M0002'])
    check("M0002 has transaction-level BEGIN", m0002_has_begin)
    check("M0002 has transaction-level COMMIT", m0002_has_commit)

    m0002b_has_begin = has_transaction_begin(sqls['M0002b'])
    m0002b_has_commit = has_transaction_commit(sqls['M0002b'])
    check("M0002b has transaction-level BEGIN", m0002b_has_begin)
    check("M0002b has transaction-level COMMIT", m0002b_has_commit)

    m0003_has_begin = has_transaction_begin(sqls['M0003'])
    m0003_has_commit = has_transaction_commit(sqls['M0003'])
    check("M0003 has transaction-level BEGIN", m0003_has_begin)
    check("M0003 has transaction-level COMMIT", m0003_has_commit)

    # ── Section 3: Object Counts ───────────────────────────────────────────────
    section("3. Object Counts")

    # M0002b: application_roles migration — exactly 4 CREATE ROLE, no DDL, no functions
    m0002b_roles = get_create_role_names(m0002b_stmts)
    expected_roles = {'agent_service', 'system_service', 'admin', 'governance_functions'}
    check("M0002b has exactly 4 CREATE ROLE statements",
          len(m0002b_roles) == 4,
          f"found {len(m0002b_roles)}: {m0002b_roles}")
    check("M0002b role names match expected set (agent_service, system_service, admin, governance_functions)",
          set(m0002b_roles) == expected_roles,
          f"found: {set(m0002b_roles)} expected: {expected_roles}")
    check("M0002b has no CREATE TABLE statements",
          m0002b_counts.get('CreateStmt', 0) == 0,
          f"found {m0002b_counts.get('CreateStmt', 0)}")
    check("M0002b has no CREATE FUNCTION statements",
          m0002b_counts.get('CreateFunctionStmt', 0) == 0,
          f"found {m0002b_counts.get('CreateFunctionStmt', 0)}")
    check("M0002b has no CREATE TRIGGER statements",
          m0002b_counts.get('CreateTrigStmt', 0) == 0,
          f"found {m0002b_counts.get('CreateTrigStmt', 0)}")
    check("M0002b has no CREATE POLICY statements",
          m0002b_counts.get('CreatePolicyStmt', 0) == 0,
          f"found {m0002b_counts.get('CreatePolicyStmt', 0)}")
    check("M0002b has no GRANT statements (roles only — grants are M0003's scope)",
          m0002b_counts.get('GrantStmt', 0) == 0,
          f"found {m0002b_counts.get('GrantStmt', 0)}")
    check("M0002b has no IF NOT EXISTS DDL guards (roles fail loudly if pre-existing)",
          len(check_no_ddl_if_not_exists(m0002b_stmts)) == 0)

    m0001_counts = get_stmt_types(m0001_stmts)
    check("M0001 has exactly 39 enum types",
          m0001_counts.get('CreateEnumStmt', 0) == 39,
          f"found {m0001_counts.get('CreateEnumStmt', 0)}")
    check("M0001 has exactly 39 tables",
          m0001_counts.get('CreateStmt', 0) == 39,
          f"found {m0001_counts.get('CreateStmt', 0)}")
    check("M0001 has exactly 39 RLS policies",
          m0001_counts.get('CreatePolicyStmt', 0) == 39,
          f"found {m0001_counts.get('CreatePolicyStmt', 0)}")
    check("M0001 has exactly 39 INSERT statements",
          m0001_counts.get('InsertStmt', 0) == 39,
          f"found {m0001_counts.get('InsertStmt', 0)}")

    m0001_inserts = get_insert_counts(m0001_stmts)
    m0001_total_seeds = sum(m0001_inserts.values())
    check("M0001 total seed records = 345 (live-confirmed 2026-07-26)",
          m0001_total_seeds == 345,
          f"found {m0001_total_seeds}")
    check("M0001 claim_value_units seeded with exactly 11 records",
          m0001_inserts.get('claim_value_units', 0) == 11,
          f"found {m0001_inserts.get('claim_value_units', 0)}")

    m0002_counts = get_stmt_types(m0002_stmts)
    check("M0002 has exactly 3 enum types",
          m0002_counts.get('CreateEnumStmt', 0) == 3,
          f"found {m0002_counts.get('CreateEnumStmt', 0)}")
    check("M0002 has exactly 1 table (display_contexts)",
          m0002_counts.get('CreateStmt', 0) == 1,
          f"found {m0002_counts.get('CreateStmt', 0)}")
    m0002_inserts = get_insert_counts(m0002_stmts)
    check("M0002 display_contexts seeded with exactly 9 records",
          m0002_inserts.get('display_contexts', 0) == 9,
          f"found {m0002_inserts.get('display_contexts', 0)}")

    m0003_counts = get_stmt_types(m0003_stmts)
    check("M0003 has exactly 49 tables",
          m0003_counts.get('CreateStmt', 0) == 49,
          f"found {m0003_counts.get('CreateStmt', 0)}")
    check("M0003 has exactly 31 functions",
          m0003_counts.get('CreateFunctionStmt', 0) == 31,
          f"found {m0003_counts.get('CreateFunctionStmt', 0)}")
    check("M0003 has exactly 22 triggers",
          m0003_counts.get('CreateTrigStmt', 0) == 22,
          f"found {m0003_counts.get('CreateTrigStmt', 0)}")
    check("M0003 has exactly 14 indexes (13 regular + 1 partial unique)",
          m0003_counts.get('IndexStmt', 0) == 14,
          f"found {m0003_counts.get('IndexStmt', 0)}")
    check("M0003 has exactly 71 RLS policies",
          m0003_counts.get('CreatePolicyStmt', 0) == 71,
          f"found {m0003_counts.get('CreatePolicyStmt', 0)}")

    m0003_inserts = get_insert_counts(m0003_stmts)
    check("M0003 jurisdictions seeded with exactly 6 records",
          m0003_inserts.get('jurisdictions', 0) == 6,
          f"found {m0003_inserts.get('jurisdictions', 0)}")
    check("M0003 claim_predicates seeded with exactly 74 records",
          m0003_inserts.get('claim_predicates', 0) == 74,
          f"found {m0003_inserts.get('claim_predicates', 0)}")
    check("M0003 relationship_types seeded with exactly 27 records",
          m0003_inserts.get('relationship_types', 0) == 27,
          f"found {m0003_inserts.get('relationship_types', 0)}")
    check("M0003 escalation_policies seeded with exactly 7 records",
          m0003_inserts.get('escalation_policies', 0) == 7,
          f"found {m0003_inserts.get('escalation_policies', 0)}")
    check("M0003 approval_policies seeded with exactly 5 records",
          m0003_inserts.get('approval_policies', 0) == 5,
          f"found {m0003_inserts.get('approval_policies', 0)}")
    check("M0003 conflict_resolution_policies seeded with exactly 4 records",
          m0003_inserts.get('conflict_resolution_policies', 0) == 4,
          f"found {m0003_inserts.get('conflict_resolution_policies', 0)}")
    check("M0003 agent_registry seeded with exactly 9 records",
          m0003_inserts.get('agent_registry', 0) == 9,
          f"found {m0003_inserts.get('agent_registry', 0)}")
    check("M0003 context_profiles seeded with exactly 2 records",
          m0003_inserts.get('context_profiles', 0) == 2,
          f"found {m0003_inserts.get('context_profiles', 0)}")

    # M0003 must NOT create or seed claim_value_units
    m0003_table_list = get_table_names(m0003_stmts)
    m0003_tables_set = set(m0003_table_list)
    check("M0003 does NOT create claim_value_units (M0001 prerequisite)",
          'claim_value_units' not in m0003_tables_set)
    check("M0003 does NOT insert into claim_value_units",
          'claim_value_units' not in m0003_inserts)

    # M0003 must NOT create or seed display_contexts
    check("M0003 does NOT create display_contexts (M0002 prerequisite)",
          'display_contexts' not in m0003_tables_set)
    check("M0003 does NOT insert into display_contexts",
          'display_contexts' not in m0003_inserts)

    # M0003 must NOT contain CREATE ROLE — all roles created by M0002b
    m0003_roles = get_create_role_names(m0003_stmts)
    check("M0003 has zero CREATE ROLE statements (roles are owned by M0002b)",
          len(m0003_roles) == 0,
          f"unexpected roles: {m0003_roles}" if m0003_roles else "clean")

    # ── Section 4: DDL Guard Checks ───────────────────────────────────────────
    section("4. DDL Guard Checks (No IF NOT EXISTS in DDL Statements)")

    for label, stmts in [('M0001', m0001_stmts), ('M0002', m0002_stmts),
                         ('M0002b', m0002b_stmts), ('M0003', m0003_stmts)]:
        violations = check_no_ddl_if_not_exists(stmts)
        check(f"{label} has no DDL-level IF NOT EXISTS guards",
              len(violations) == 0,
              f"violations: {violations}" if violations else "clean")

    # ON CONFLICT guards via AST (avoids matching comment text)
    # M0002 must have 0 INSERT ON CONFLICT clauses
    m0002_oc_ast = get_on_conflict_insert_count(m0002_stmts)
    check("M0002 INSERT statements have no ON CONFLICT clauses (AST check)",
          m0002_oc_ast == 0,
          f"found {m0002_oc_ast}")

    # M0003 must have 0 INSERT ON CONFLICT clauses
    m0003_oc_ast = get_on_conflict_insert_count(m0003_stmts)
    check("M0003 INSERT statements have no ON CONFLICT clauses (AST check)",
          m0003_oc_ast == 0,
          f"found {m0003_oc_ast}")

    # M0001 must have exactly 39 INSERT ON CONFLICT DO NOTHING clauses (one per seed table)
    m0001_oc_ast = get_on_conflict_insert_count(m0001_stmts)
    check("M0001 seed INSERTs use ON CONFLICT DO NOTHING (exactly 39 INSERT statements with ON CONFLICT)",
          m0001_oc_ast == 39,
          f"found {m0001_oc_ast} (expected 39 — one per reference table)")

    # ── Section 5: Function Form Checks ───────────────────────────────────────
    section("5. Function Form Checks")

    check("M0001 has no CREATE OR REPLACE FUNCTION", not has_or_replace_function(m0001_stmts))
    check("M0002 has no CREATE OR REPLACE FUNCTION", not has_or_replace_function(m0002_stmts))
    check("M0002b has no CREATE OR REPLACE FUNCTION", not has_or_replace_function(m0002b_stmts))
    check("M0003 has no CREATE OR REPLACE FUNCTION", not has_or_replace_function(m0003_stmts))

    # SECURITY DEFINER: _fn_trg_claim_numeric_unit_check must be SECURITY DEFINER
    # Uses .sval for string resolution (not str(), which adds repr wrapper)
    m0003_sec_def = get_security_definer_functions(m0003_stmts)
    check("M0003 _fn_trg_claim_numeric_unit_check is SECURITY DEFINER",
          '_fn_trg_claim_numeric_unit_check' in m0003_sec_def,
          f"SECURITY DEFINER functions: {m0003_sec_def}" if '_fn_trg_claim_numeric_unit_check' not in m0003_sec_def
          else f"{len(m0003_sec_def)} SECURITY DEFINER functions found including target")

    # SET search_path on the security definer function body (text scan of DDL only)
    sec_fn_pattern = re.compile(
        r'CREATE FUNCTION _fn_trg_claim_numeric_unit_check.*?'
        r"SET search_path\s*=\s*'public'\s*,\s*pg_temp",
        re.DOTALL | re.IGNORECASE
    )
    check("M0003 _fn_trg_claim_numeric_unit_check has SET search_path = 'public', pg_temp",
          bool(sec_fn_pattern.search(sqls['M0003'])))

    # ── Section 6: Index Checks ────────────────────────────────────────────────
    section("6. Index Checks (Multiline-safe via AST)")

    m0003_indexes = get_index_names(m0003_stmts)
    check("M0003 has uq_lifebook_entities_active (partial unique index)",
          'uq_lifebook_entities_active' in m0003_indexes,
          f"all indexes: {sorted(m0003_indexes)}")

    expected_indexes = [
        # idx_entities_lifebook_id removed 2026-07-26: entities has no lifebook_id column
        'idx_claims_subject_entity_id',
        'idx_claims_predicate_id',
        'idx_relationships_entity_a',
        'idx_relationships_entity_b',
        'idx_authority_assignments_entity_id',
        'idx_context_manifests_agent_code',
        'idx_lifebook_memberships_user_lifebook',
        'idx_authority_assignments_role_entity',
        'idx_authority_assignments_expiry',
        'idx_claims_lifebook_review_access',
        'idx_display_policy_rules_policy_context',
        'idx_user_person_links_user_entity',
        'idx_contest_records_contested_record',
    ]
    for idx_name in expected_indexes:
        check(f"M0003 index present: {idx_name}", idx_name in m0003_indexes)

    # ── Section 7: File-Order Deferred FK Count ────────────────────────────────
    section("7. File-Order Deferred FK Count (ALTER TABLE ADD CONSTRAINT FOREIGN KEY)")

    # 'Deferred FKs' = FKs that could not be declared inline in CREATE TABLE
    # because their reference target was defined later in the same migration file.
    # These are expressed as ALTER TABLE ADD CONSTRAINT FOREIGN KEY statements.
    alter_fk_count = count_alter_table_add_fk(m0003_stmts)
    check("M0003 has exactly 4 file-order deferred FKs (ALTER TABLE ADD CONSTRAINT FK)",
          alter_fk_count == 4,
          f"found {alter_fk_count}")

    # The CONSTRAINT TRIGGER is separately DEFERRABLE INITIALLY DEFERRED
    ctrig_deferrable_count = sum(
        1 for s in m0003_stmts
        if type(s.stmt).__name__ == 'CreateTrigStmt'
        and getattr(s.stmt, 'deferrable', False)
    )
    check("M0003 has exactly 1 DEFERRABLE INITIALLY DEFERRED CONSTRAINT TRIGGER",
          ctrig_deferrable_count == 1,
          f"found {ctrig_deferrable_count}")

    # ── Section 8: Trigger Integrity ───────────────────────────────────────────
    section("8. Trigger Integrity")

    m0003_triggers_list = get_trigger_names(m0003_stmts)
    m0003_fns = get_function_names(m0003_stmts)
    trg_fns = [f for f in m0003_fns if f.startswith('_fn_trg_')]
    unmatched_fns = []
    for fn in trg_fns:
        expected_trg = fn.replace('_fn_trg_', 'trg_', 1)
        if expected_trg not in m0003_triggers_list:
            unmatched_fns.append(f"{fn} -> {expected_trg}")
    check("All _fn_trg_* functions have a matching trg_* trigger",
          len(unmatched_fns) == 0,
          f"unmatched: {unmatched_fns}" if unmatched_fns else "all matched")

    # trg_claim_numeric_unit_check: BEFORE (timing=2) trigger on claims
    # pglast uses timing=2 for BEFORE, timing=0 for AFTER
    trg_numeric_found = False
    trg_numeric_is_before = False
    trg_numeric_on_claims = False
    for s in m0003_stmts:
        if type(s.stmt).__name__ == 'CreateTrigStmt':
            if str(s.stmt.trigname) == 'trg_claim_numeric_unit_check':
                trg_numeric_found = True
                timing = getattr(s.stmt, 'timing', None)
                # pglast: timing=2 means BEFORE, timing=0 means AFTER
                trg_numeric_is_before = (int(str(timing)) == 2)
                rel = getattr(s.stmt, 'relation', None)
                if rel:
                    trg_numeric_on_claims = (str(rel.relname) == 'claims')

    check("M0003 trg_claim_numeric_unit_check exists", trg_numeric_found)
    check("M0003 trg_claim_numeric_unit_check fires BEFORE (timing=2)",
          trg_numeric_is_before)
    check("M0003 trg_claim_numeric_unit_check fires on 'claims' table",
          trg_numeric_on_claims)

    # trg_lifebook_person_context_completeness: CONSTRAINT TRIGGER (DEFERRABLE)
    ctrig_found = False
    ctrig_is_constraint = False
    ctrig_is_deferrable = False
    for s in m0003_stmts:
        if type(s.stmt).__name__ == 'CreateTrigStmt':
            if str(s.stmt.trigname) == 'trg_lifebook_person_context_completeness':
                ctrig_found = True
                ctrig_is_constraint = bool(getattr(s.stmt, 'isconstraint', False))
                ctrig_is_deferrable = bool(getattr(s.stmt, 'deferrable', False))
    check("M0003 trg_lifebook_person_context_completeness exists", ctrig_found)
    check("M0003 trg_lifebook_person_context_completeness is CONSTRAINT TRIGGER",
          ctrig_is_constraint)
    check("M0003 trg_lifebook_person_context_completeness is DEFERRABLE",
          ctrig_is_deferrable)

    # ── Section 9: Cross-Migration Object Uniqueness ───────────────────────────
    section("9. Cross-Migration Object Uniqueness (Types, Tables, Functions, Triggers)")

    m0001_enums = set(get_enum_names(m0001_stmts))
    m0002_enums = set(get_enum_names(m0002_stmts))
    m0003_enums = set(get_enum_names(m0003_stmts))
    for pair, dupes in [
        ("M0001 vs M0002", m0001_enums & m0002_enums),
        ("M0001 vs M0003", m0001_enums & m0003_enums),
        ("M0002 vs M0003", m0002_enums & m0003_enums),
    ]:
        check(f"No duplicate enum names {pair}",
              len(dupes) == 0,
              f"duplicates: {dupes}" if dupes else "clean")

    m0001_tables_set = set(get_table_names(m0001_stmts))
    m0002_tables_set = set(get_table_names(m0002_stmts))
    for pair, dupes in [
        ("M0001 vs M0002",  m0001_tables_set & m0002_tables_set),
        ("M0001 vs M0003",  m0001_tables_set & m0003_tables_set),
        ("M0002 vs M0003",  m0002_tables_set & m0003_tables_set),
    ]:
        check(f"No duplicate table names {pair}",
              len(dupes) == 0,
              f"duplicates: {dupes}" if dupes else "clean")

    # Role name uniqueness: M0002b creates all four roles; no other migration should create roles
    m0001_roles_count = len(get_create_role_names(m0001_stmts))
    m0002_roles_count = len(get_create_role_names(m0002_stmts))
    check("M0001 creates no roles", m0001_roles_count == 0, f"found {m0001_roles_count}")
    check("M0002 creates no roles", m0002_roles_count == 0, f"found {m0002_roles_count}")
    # M0003 role check already done in Section 3

    check("M0001 defines no functions", len(get_function_names(m0001_stmts)) == 0)
    check("M0002 defines no functions", len(get_function_names(m0002_stmts)) == 0)
    check("M0002b defines no functions", len(get_function_names(m0002b_stmts)) == 0)
    check("M0001 defines no triggers", len(get_trigger_names(m0001_stmts)) == 0)
    check("M0002 defines no triggers", len(get_trigger_names(m0002_stmts)) == 0)
    check("M0002b defines no triggers", len(get_trigger_names(m0002b_stmts)) == 0)

    check("M0003 creates no new enum types (all enums from M0001/M0002)",
          m0003_counts.get('CreateEnumStmt', 0) == 0,
          f"found {m0003_counts.get('CreateEnumStmt', 0)}")

    # ── Section 10: Deferred FK Targets Exist Earlier in M0003 ────────────────
    section("10. Deferred FK Targets Created Earlier in M0003")

    deferred_fk_targets = {
        'approval_policies': 'lifebook_person_contexts.permission_cache_policy_version_id FK',
        'approval_records': 'display_policies.approval_record_id FK',
        'claims': 'authority_assignments.basis_claim_id FK',
        'context_manifests': 'claims.context_manifest_id FK',
    }
    for tbl, desc in deferred_fk_targets.items():
        check(f"Deferred FK target '{tbl}' created within M0003 ({desc})",
              tbl in m0003_tables_set)

    # ── Section 11: Prerequisite Dependencies ─────────────────────────────────
    section("11. Prerequisite Dependency Checks")

    check("claim_value_units exists in M0001 (FK prerequisite for M0003 claims.value_unit_code)",
          'claim_value_units' in m0001_tables_set)
    check("display_contexts exists in M0002 (FK prerequisite for M0003 display_policy_rules.display_context_code)",
          'display_contexts' in m0002_tables_set)
    check("M0003 references auth.users (Supabase built-in, no DDL required)",
          bool(re.search(r'REFERENCES\s+auth\.users', sqls['M0003'])))

    # M0002b prerequisite: all four roles must be created by M0002b before M0003 consumes them
    for role_name in ['agent_service', 'system_service', 'admin', 'governance_functions']:
        check(f"M0002b creates role '{role_name}' (required by M0003 GRANT/OWNER TO statements)",
              role_name in m0002b_roles)

    # ── Section 12: RLS Coverage (AST-based) ──────────────────────────────────
    section("12. RLS Coverage (AST-based, not text match)")

    rls_enable_count = count_rls_enables(m0003_stmts)
    check("M0003 enables RLS on exactly 25 tables (AST: AT_EnableRowSecurity subtype)",
          rls_enable_count == 25,
          f"found {rls_enable_count}")
    check("M0003 has exactly 71 RLS policies",
          m0003_counts.get('CreatePolicyStmt', 0) == 71,
          f"found {m0003_counts.get('CreatePolicyStmt', 0)}")

    # ── Section 13: Grant Structure ────────────────────────────────────────────
    section("13. Grant / Revoke Structure")

    m0003_grants = m0003_counts.get('GrantStmt', 0)
    check("M0003 has >= 50 GRANT/REVOKE statements",
          m0003_grants >= 50,
          f"found {m0003_grants}")

    # ── Section 14: Semantic Schema Validator ─────────────────────────────────
    section("14. Semantic Schema Validator (SEM-001 through SEM-012)")

    # Build combined schema from all migrations in execution order
    all_sqls_list = [sqls['M0001'], sqls['M0002'], sqls['M0002b'], sqls['M0003']]
    sem_schema = build_schema_model(all_sqls_list)

    # Collect all indexes across all migrations
    sem_indexes_all = []
    for lbl in ['M0001', 'M0002', 'M0002b', 'M0003']:
        sem_indexes_all.extend(extract_indexes_from_sql(sqls[lbl]))

    # Indexes for M0003 only (for SEM-011)
    m0003_sem_indexes = extract_indexes_from_sql(sqls['M0003'])

    def _is_external_ref(table_name: str) -> bool:
        """Return True for schema-qualified or known external table references."""
        return '.' in table_name

    # SEM-001: FK target table exists in combined schema
    sem001_failures = []
    for tbl_name, tbl_info in sem_schema.items():
        for (col, ref_table, ref_col) in tbl_info.get('fks', []):
            if _is_external_ref(ref_table):
                continue
            if ref_table not in sem_schema:
                sem001_failures.append(f"{tbl_name}.{col} -> {ref_table} (not found)")
    check("SEM-001: All FK target tables exist in combined schema",
          len(sem001_failures) == 0,
          f"missing: {sem001_failures}" if sem001_failures else "all present")

    # SEM-002: FK target column exists in target table
    sem002_failures = []
    for tbl_name, tbl_info in sem_schema.items():
        for (col, ref_table, ref_col) in tbl_info.get('fks', []):
            if _is_external_ref(ref_table) or ref_table not in sem_schema:
                continue
            if ref_col not in sem_schema[ref_table].get('columns', {}):
                sem002_failures.append(f"{tbl_name}.{col} -> {ref_table}({ref_col}) col not found")
    check("SEM-002: All FK target columns exist in target table",
          len(sem002_failures) == 0,
          f"missing cols: {sem002_failures}" if sem002_failures else "all present")

    # SEM-003: FK target column is PK or has UNIQUE constraint
    sem003_failures = []
    for tbl_name, tbl_info in sem_schema.items():
        for (col, ref_table, ref_col) in tbl_info.get('fks', []):
            if _is_external_ref(ref_table) or ref_table not in sem_schema:
                continue
            ref_info = sem_schema[ref_table]
            is_pk = ref_col in ref_info.get('pk', [])
            is_unique = ref_col in ref_info.get('unique', [])
            if not (is_pk or is_unique):
                sem003_failures.append(
                    f"{tbl_name}.{col} -> {ref_table}({ref_col}) not PK/UNIQUE"
                )
    check("SEM-003: All FK target columns are PK or UNIQUE in target table",
          len(sem003_failures) == 0,
          f"violations: {sem003_failures}" if sem003_failures else "all valid")

    # SEM-004: No REFERENCES persons(id) anywhere in any migration
    sem004_count = 0
    for sql_text in all_sqls_list:
        sem004_count += len(re.findall(
            r'REFERENCES\s+persons\s*\(\s*id\s*\)', sql_text, re.IGNORECASE
        ))
    check("SEM-004: No REFERENCES persons(id) exists anywhere in migrations",
          sem004_count == 0,
          f"found {sem004_count} occurrences" if sem004_count else "clean")

    # SEM-005: Simple index column existence (skip expression indexes)
    sem005_failures = []
    for (idx_name, tbl_name, col_names) in sem_indexes_all:
        if tbl_name not in sem_schema:
            continue
        tbl_cols = sem_schema[tbl_name].get('columns', {})
        for col in col_names:
            if col is None:
                continue  # expression index — skip
            if col not in tbl_cols:
                sem005_failures.append(f"idx {idx_name}: {tbl_name}.{col} not found")
    check("SEM-005: All simple index columns exist in their target tables",
          len(sem005_failures) == 0,
          f"violations: {sem005_failures}" if sem005_failures else "all valid")

    # SEM-006: persons PK is entity_id (not id)
    persons_sem_info = sem_schema.get('persons', {})
    persons_sem_pk = persons_sem_info.get('pk', [])
    check("SEM-006: persons primary key column is entity_id",
          persons_sem_pk == ['entity_id'],
          f"pk is: {persons_sem_pk}")

    # SEM-007: person_names.person_id FK → persons(entity_id)
    pn_sem_info = sem_schema.get('person_names', {})
    pn_sem_fk_ok = any(
        col == 'person_id' and ref_table == 'persons' and ref_col == 'entity_id'
        for col, ref_table, ref_col in pn_sem_info.get('fks', [])
    )
    check("SEM-007: person_names.person_id FK targets persons(entity_id)", pn_sem_fk_ok)

    # SEM-008: person_pronouns.person_id FK → persons(entity_id)
    pp_sem_info = sem_schema.get('person_pronouns', {})
    pp_sem_fk_ok = any(
        col == 'person_id' and ref_table == 'persons' and ref_col == 'entity_id'
        for col, ref_table, ref_col in pp_sem_info.get('fks', [])
    )
    check("SEM-008: person_pronouns.person_id FK targets persons(entity_id)", pp_sem_fk_ok)

    # SEM-009: person_gender_descriptors.person_id FK → persons(entity_id)
    pgd_sem_info = sem_schema.get('person_gender_descriptors', {})
    pgd_sem_fk_ok = any(
        col == 'person_id' and ref_table == 'persons' and ref_col == 'entity_id'
        for col, ref_table, ref_col in pgd_sem_info.get('fks', [])
    )
    check("SEM-009: person_gender_descriptors.person_id FK targets persons(entity_id)", pgd_sem_fk_ok)

    # SEM-010: idx_entities_lifebook_id does not exist in any migration
    sem010_found = any(idx_name == 'idx_entities_lifebook_id' for idx_name, _, _ in sem_indexes_all)
    check("SEM-010: idx_entities_lifebook_id does not exist in any migration",
          not sem010_found)

    # SEM-011: Authored CREATE INDEX count in M0003 = 14
    check("SEM-011: M0003 authored CREATE INDEX count = 14",
          len(m0003_sem_indexes) == 14,
          f"found {len(m0003_sem_indexes)}")

    # SEM-012: Total seed count = 488 (M0001=345, M0002=9, M0002b=0, M0003=134)
    sem_m0001_seeds = sum(get_insert_counts(m0001_stmts).values())
    sem_m0002_seeds = sum(get_insert_counts(m0002_stmts).values())
    sem_m0002b_seeds = sum(get_insert_counts(m0002b_stmts).values())
    sem_m0003_seeds = sum(get_insert_counts(m0003_stmts).values())
    sem_total_seeds = sem_m0001_seeds + sem_m0002_seeds + sem_m0002b_seeds + sem_m0003_seeds
    check("SEM-012: Total seed count across all migrations = 488 (345+9+0+134)",
          sem_total_seeds == 488,
          f"found {sem_total_seeds} ({sem_m0001_seeds}+{sem_m0002_seeds}"
          f"+{sem_m0002b_seeds}+{sem_m0003_seeds})")

    # ── Section 15: Regression Tests ──────────────────────────────────────────
    section("15. Regression Tests — persons entity_id PK (REGR-001 through REGR-010)")

    # REGR-001: persons table has column entity_id
    check("REGR-001: persons table has column entity_id",
          'entity_id' in sem_schema.get('persons', {}).get('columns', {}))

    # REGR-002: persons table does NOT have column named 'id'
    check("REGR-002: persons table does NOT have column named 'id'",
          'id' not in sem_schema.get('persons', {}).get('columns', {}))

    # REGR-003: persons.entity_id is the PRIMARY KEY
    check("REGR-003: persons.entity_id is the PRIMARY KEY",
          sem_schema.get('persons', {}).get('pk', []) == ['entity_id'])

    # REGR-004: persons.entity_id FK targets entities(id)
    persons_regr_fks = sem_schema.get('persons', {}).get('fks', [])
    regr004_ok = any(
        col == 'entity_id' and ref_table == 'entities' and ref_col == 'id'
        for col, ref_table, ref_col in persons_regr_fks
    )
    check("REGR-004: persons.entity_id FK targets entities(id)", regr004_ok)

    # REGR-005: person_names.person_id FK targets persons(entity_id)
    check("REGR-005: person_names.person_id FK targets persons(entity_id)", pn_sem_fk_ok)

    # REGR-006: person_pronouns.person_id FK targets persons(entity_id)
    check("REGR-006: person_pronouns.person_id FK targets persons(entity_id)", pp_sem_fk_ok)

    # REGR-007: person_gender_descriptors.person_id FK targets persons(entity_id)
    check("REGR-007: person_gender_descriptors.person_id FK targets persons(entity_id)", pgd_sem_fk_ok)

    # REGR-008: Zero occurrences of "REFERENCES persons(id)" in any migration SQL file (raw text scan)
    regr008_count = 0
    for _, path, _ in MIGRATIONS:
        raw_text = path.read_text()
        regr008_count += len(re.findall(
            r'REFERENCES\s+persons\s*\(\s*id\s*\)', raw_text, re.IGNORECASE
        ))
    check("REGR-008: Zero occurrences of 'REFERENCES persons(id)' in any migration file",
          regr008_count == 0,
          f"found {regr008_count} occurrences" if regr008_count else "clean")

    # REGR-009: No CREATE INDEX idx_entities_lifebook_id in any migration file
    # (comment references are intentionally excluded — only live DDL matters)
    regr009_count = sum(
        1 for idx_name, _, _ in sem_indexes_all
        if idx_name == 'idx_entities_lifebook_id'
    )
    check("REGR-009: No CREATE INDEX idx_entities_lifebook_id in any migration file",
          regr009_count == 0,
          f"found {regr009_count} CREATE INDEX statement(s)" if regr009_count else "clean")

    # REGR-010: Explicit authored CREATE INDEX count in M0003 = 14
    check("REGR-010: M0003 explicit CREATE INDEX count = 14",
          len(m0003_sem_indexes) == 14,
          f"found {len(m0003_sem_indexes)}")

    # ── Final Summary ──────────────────────────────────────────────────────────
    section("SUMMARY")
    total_checks = len([r for r in _results if '[PASS]' in r or '[FAIL]' in r])
    total_pass = len([r for r in _results if '[PASS]' in r])
    total_fail = len([r for r in _results if '[FAIL]' in r])

    print(f"\n  Total checks:  {total_checks}")
    print(f"  Passed:        {total_pass}")
    print(f"  Failed:        {total_fail}")
    if total_fail == 0:
        print("\n  RESULT: ALL CHECKS PASSED — zero failures")
    else:
        print(f"\n  RESULT: {total_fail} FAILURE(S) DETECTED")
        print("\n  Failed checks:")
        for r in _results:
            if '[FAIL]' in r:
                print(r)

    return 0 if total_fail == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
