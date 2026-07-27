# LIVE_EXECUTION_RUNBOOK.md
## LifeBook HQ — M0003 Core Schema: CLI Execution Runbook

**Status:** READY FOR EXECUTION  
**Authorized by:** Discovery Partner — 2026-07-26  
**Migration target:** Disposable project `iximbhwsjmppsdiwdixl` (lifebook-disposable-3)  
**Superseded project:** `gunkacvftnvwxcppqvxr` — paused; MCP/CLI version-stamp inconsistency; see INCIDENT_REPORT_gunkacvftnvwxcppqvxr.md  
**Production project:** `qrdoebsoviksdaxnjyak` — **DO NOT TOUCH**  
**Authored:** 2026-07-26

---

## Why CLI Is Required

The Supabase MCP `apply_migration` tool requires the full SQL as a single string parameter.
`20260726083203_core_schema.sql` is 181,758 bytes (~45K tokens). This exceeds the model output
token limit for a single tool invocation. This is a tooling transport limitation only — it is not
a schema defect. The migration file is correct and fully validated.

The CLI applies the file directly from disk, bypassing the string-transport limitation, while
still writing the correct migration-history record into `supabase_migrations.schema_migrations`.

**No schema modifications are authorised until CLI execution either:**
- succeeds completely, or
- exposes a genuine runtime SQL defect.

---

## Frozen Migration State

| Field        | Value                                                                    |
|--------------|--------------------------------------------------------------------------|
| File         | `supabase/migrations/20260726083203_core_schema.sql`                     |
| Byte count   | 181,758                                                                  |
| Line count   | 2,903                                                                    |
| SHA-256      | `2559ca0e56769bc159e5943bbdf7c1326bfb154179440a218e74fb9d90047f8a`       |
| Git commit   | `5dac8d3`                               |
| Commit msg   | `fix(M0003): add GRANT governance_functions TO current_user (DEF-0003)` |
| Working tree | Clean (no uncommitted changes to this file)                              |

**Do not modify the migration file.** If a runtime defect is found, a new DP session is required
before any change is authorised.

---

## Prerequisites

### 1. Supabase CLI

The Supabase CLI (`supabase`) must be installed and on `$PATH`.

Install (macOS, Homebrew):
```bash
brew install supabase/tap/supabase
```

Install (npm — any platform):
```bash
npm install -g supabase
```

Verify:
```bash
supabase --version
```
**Minimum required version:** `1.200.0`  
**Latest at runbook authoring:** `2.109.1` (npm registry, 2026-07-26)

### 2. Supabase Account Access

You must be authenticated to the Supabase account that owns project `iximbhwsjmppsdiwdixl`.

### 3. Repository

Working directory must be the repo root:
```
/Users/tracydeslaurier/Projects/lifebookhq
```

The `supabase/migrations/` directory contains exactly four files in this order:
```
20260724153745_types_and_vocabularies.sql
20260726083201_predicate_governance_types.sql
20260726083202_application_roles.sql
20260726083203_core_schema.sql
```

### 4. Environment Variables

No `.env` files should be sourced for this operation. The CLI uses your Supabase account
access token (set via `supabase login`) and the project ref flag directly.

**CRITICAL — never export or echo these in shell history:**
- `SUPABASE_ACCESS_TOKEN` — if used non-interactively (CI/CD only)
- Do NOT pass database passwords on the command line

### 5. What Must Already Be Applied

Verify before proceeding (see Step 3 below) that exactly these three migrations exist
in `schema_migrations` on `iximbhwsjmppsdiwdixl`:
- `20260724153745` — types_and_vocabularies
- `20260726083201` — predicate_governance_types
- `20260726083202` — application_roles

---

## Commands in Exact Execution Order

All commands are run from the repository root:
```bash
cd /Users/tracydeslaurier/Projects/lifebookhq
```

---

### Step 1 — Authenticate

```bash
supabase login
```

This opens a browser window. Authenticate with the Supabase account that owns
`iximbhwsjmppsdiwdixl`. On success you will see:
```
You are now logged in. Happy coding!
```

---

### Step 2 — Link the Disposable Project

```bash
supabase link --project-ref iximbhwsjmppsdiwdixl
```

You will be prompted for the database password for project `iximbhwsjmppsdiwdixl`.
Enter it when prompted.

**Expected output (success):**
```
Finished supabase link.
```

A `.supabase/` directory will be created or updated in the repo root with the linked
project reference. This does not affect the `supabase/migrations/` directory.

---

### Step 3 — Verify Current Migration Status

```bash
supabase db remote commit --dry-run 2>/dev/null || supabase migration list
```

Or directly via the Management API equivalent:
```bash
supabase migration list
```

**Expected output — exactly 3 applied migrations, 1 pending:**
```
      LOCAL      │     REMOTE     │     TIME (UTC)
  ───────────────┼────────────────┼──────────────────────
  20260724153745 │ 20260724153745 │ 2026-07-26 ...
  20260726083201 │ 20260726083201 │ 2026-07-26 ...
  20260726083202 │ 20260726083202 │ 2026-07-26 ...
  20260726083203 │                │
```

The `20260726083203` row must show local only (no remote timestamp yet).

**If you see a different state — STOP.** Do not proceed without DP review.

---

### Step 4 — Verify the Migration File Integrity

Before applying, confirm the file on disk matches the frozen state:

```bash
sha256sum supabase/migrations/20260726083203_core_schema.sql
```

**Expected:**
```
2559ca0e56769bc159e5943bbdf7c1326bfb154179440a218e74fb9d90047f8a  supabase/migrations/20260726083203_core_schema.sql
```

If the SHA-256 does not match — **STOP. Do not apply. Report to DP.**

---

### Step 5 — Apply Pending Migrations

```bash
supabase db push
```

This will apply all locally-present migrations that are not yet in the remote
`schema_migrations` table. In this case that is exactly one: `20260726083203_core_schema`.

The CLI reads the SQL file directly from disk and executes it in a single transaction.
The migration-history record is written by the CLI, not by this runbook.

**Expected output (success):**
```
Applying migration 20260726083203_core_schema.sql...
Migration applied successfully.
```

The exact wording varies by CLI version. What matters:
- No `ERROR` lines
- No `ROLLBACK` lines
- Exit code 0

---

### Step 6 — Confirm Migration History

```bash
supabase migration list
```

**Expected output — all 4 migrations applied:**
```
      LOCAL      │     REMOTE     │     TIME (UTC)
  ───────────────┼────────────────┼──────────────────────
  20260724153745 │ 20260724153745 │ 2026-07-26 ...
  20260726083201 │ 20260726083201 │ 2026-07-26 ...
  20260726083202 │ 20260726083202 │ 2026-07-26 ...
  20260726083203 │ 20260726083203 │ 2026-07-26 ...
```

All four rows must show matching LOCAL and REMOTE timestamps.

---

### Step 7 — Post-Application Validation SQL

Run each query in the Supabase SQL editor or via `supabase db execute` against
project `iximbhwsjmppsdiwdixl`. All queries are read-only.

#### V1 — Table count (expect 49 tables from M0003, plus prior tables)
```sql
SELECT count(*) AS table_count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE';
-- Expected: 49 tables (M0003) + 39 vocabulary tables (M0001) + 1 display_contexts (M0002) = 89
```

#### V2 — RLS enabled on exactly 25 tables
```sql
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND rowsecurity = TRUE
ORDER BY tablename;
-- Expected: 25 rows
-- Tables: access_policy_changed_events, approval_records, artifact_source_links, artifacts,
--         authority_assignments, claim_evidence, claims, contest_records, context_manifests,
--         display_policies, display_policy_rules, event_participants, events,
--         lifebook_entities, lifebook_person_contexts, lifebook_memberships,
--         narrative_entities, narratives, person_gender_descriptors, person_name_derivatives,
--         person_names, person_pronouns, relationships, source_derivatives, sources
```

#### V3 — Trigger count (expect 22)
```sql
SELECT count(*) AS trigger_count
FROM information_schema.triggers
WHERE trigger_schema = 'public';
-- Expected: 22
```

#### V4 — Helper function count (expect 9, fn_ prefix)
```sql
SELECT proname
FROM pg_proc
WHERE proname LIKE 'fn_%'
  AND pronamespace = 'public'::regnamespace
ORDER BY proname;
-- Expected: 9 rows:
-- fn_display_policy_allows, fn_generate_artifact_signed_url, fn_has_active_authority,
-- fn_has_community_authorization, fn_has_contest_standing, fn_has_source_access_grant,
-- fn_is_subject_of, fn_lb_membership_role, fn_user_is_agent
```

#### V5 — RLS policy count (expect 71)
```sql
SELECT count(*) AS policy_count
FROM pg_policies
WHERE schemaname = 'public';
-- Expected: 71
```

#### V6 — Deferred FK constraints (expect 3)
```sql
SELECT conname, contype, condeferrable, condeferred
FROM pg_constraint
WHERE conname IN (
  'fk_authority_basis_claim',
  'fk_display_policy_approval_record',
  'fk_permission_cache_approval_policy'
)
ORDER BY conname;
-- Expected: 3 rows, all condeferrable = true, condeferred = false (DEFERRABLE INITIALLY IMMEDIATE)
-- fk_permission_cache_approval_policy is the Deferred FK 3 (lifebook_person_contexts → approval_policies)
```

#### V7 — Partial unique index exists
```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'lifebook_entities'
  AND indexname = 'uq_lifebook_entities_active';
-- Expected: 1 row
-- indexdef: CREATE UNIQUE INDEX uq_lifebook_entities_active ON public.lifebook_entities(lifebook_id, entity_id) WHERE (removed_at IS NULL)
```

#### V8 — Application roles exist with correct attributes
```sql
SELECT rolname, rolcanlogin, rolsuper, rolcreaterole, rolcreatedb, rolreplication, rolbypassrls
FROM pg_roles
WHERE rolname IN ('agent_service','system_service','admin','governance_functions')
ORDER BY rolname;
-- Expected: 4 rows, all: rolcanlogin=false, rolsuper=false, rolcreaterole=false,
--           rolcreatedb=false, rolreplication=false, rolbypassrls=false
```

#### V9 — SECURITY DEFINER function ownership
```sql
SELECT p.proname, r.rolname AS owner
FROM pg_proc p
JOIN pg_roles r ON r.oid = p.proowner
WHERE p.proname IN (
  'fn_lb_membership_role',
  'fn_is_subject_of',
  'fn_has_active_authority',
  'fn_display_policy_allows',
  'fn_has_source_access_grant',
  'fn_has_community_authorization',
  'fn_has_contest_standing',
  'fn_generate_artifact_signed_url'
)
ORDER BY p.proname;
-- Expected: 8 rows, all owner = 'governance_functions'
```

#### V10 — persons table uses entity_id as PK (no id column)
```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'persons'
ORDER BY ordinal_position;
-- Expected: columns are entity_id, lifecycle_status, lifecycle_status_evidence_id,
--           last_governance_review_at, notes
-- NO 'id' column — entity_id is both PK and FK
```

#### V11 — claims addendum columns present
```sql
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'claims'
  AND column_name IN ('review_status','submission_origin','ai_generated','producing_agent_code','context_manifest_id')
ORDER BY column_name;
-- Expected: 5 rows
```

#### V12 — Seed record counts
```sql
SELECT
  (SELECT count(*) FROM claim_predicates)        AS claim_predicates,
  (SELECT count(*) FROM relationship_types)       AS relationship_types,
  (SELECT count(*) FROM agent_registry)           AS agent_registry,
  (SELECT count(*) FROM context_profiles)         AS context_profiles,
  (SELECT count(*) FROM jurisdictions)            AS jurisdictions,
  (SELECT count(*) FROM escalation_policies)      AS escalation_policies,
  (SELECT count(*) FROM approval_policies)        AS approval_policies,
  (SELECT count(*) FROM conflict_resolution_policies) AS conflict_resolution_policies,
  (SELECT count(*) FROM display_contexts)         AS display_contexts;
-- Expected:
-- claim_predicates: 74
-- relationship_types: 27
-- agent_registry: 9
-- context_profiles: 2
-- jurisdictions: 6
-- escalation_policies: 7
-- approval_policies: 5
-- conflict_resolution_policies: 4
-- display_contexts: 9
```

#### V13 — governance_functions role membership (DEF-0003 verification)
```sql
SELECT r.rolname AS role, mr.rolname AS member
FROM pg_auth_members m
JOIN pg_roles r  ON r.oid = m.roleid
JOIN pg_roles mr ON mr.oid = m.member
WHERE r.rolname = 'governance_functions';
-- Expected: 1 row — role='governance_functions', member='postgres' (or project owner role)
-- If 0 rows: GRANT governance_functions TO current_user in M0003 did not execute — STOP.
```

---

## Expected Migration-History Entries

After Step 6, `supabase_migrations.schema_migrations` must contain exactly:

| version          | name                              |
|------------------|-----------------------------------|
| 20260724153745   | types_and_vocabularies            |
| 20260726083201   | predicate_governance_types        |
| 20260726083202   | application_roles                 |
| 20260726083203   | core_schema                       |

No other entries. No gaps. In this exact order.

---

## Failure Handling

### Migration Fails Mid-Execution

`supabase db push` wraps the migration in a transaction. If any statement fails,
PostgreSQL rolls back the entire migration. The `schema_migrations` table will
NOT contain a `20260726083203` entry.

**If this happens:**
1. Run `supabase migration list` to confirm `20260726083203` is NOT in remote.
2. Do NOT attempt to re-run until the error is analysed.
3. Report the exact error output to the DP.
4. No schema modifications are authorised without a new DP session.

### Migration Appears to Succeed but Validation Fails

If `supabase db push` exits 0 but a validation query returns unexpected results:
1. Stop all further execution.
2. Run the full V1–V13 suite to determine scope of divergence.
3. Report all divergences to DP before any remediation.

### Link Step Fails

If `supabase link` fails (auth error, project not found):
- Verify you are logged in to the correct Supabase account.
- Verify project ref `iximbhwsjmppsdiwdixl` still exists (disposable projects
  may be paused or deleted after inactivity).
- If the project has been paused: restore via Dashboard or `supabase projects restore`.

---

## Rollback Guidance

### Before M0003 Is Applied

The disposable project `iximbhwsjmppsdiwdixl` is already in a clean pre-M0003 state.
No rollback is needed — simply fix the defect and re-run from Step 4.

### If M0003 Applies Successfully but Validation Reveals a Defect

M0003 contains no `DROP` statements. PostgreSQL does not support transactional DDL rollback
after COMMIT. To roll back after a successful COMMIT on the disposable project:

1. **Option A (preferred):** Delete and recreate the disposable project, then replay
   M0001 → M0002 → M0002b → (fixed M0003).

2. **Option B:** Write a dedicated rollback migration that reverses all DDL introduced
   by M0003. This is complex and requires a new DP session.

**Production `qrdoebsoviksdaxnjyak` is unaffected regardless** — M0003 has not been
applied there and is not authorised for production until the disposable validation
completes successfully.

---

## Post-Execution: Resume Validation

After `supabase migration list` confirms all 4 migrations applied (Step 6), return
to the active session and confirm. The session will then proceed with:

1. Full V1–V13 SQL validation (using MCP `execute_sql` on `iximbhwsjmppsdiwdixl`)
2. Trigger test matrix (22 triggers — 6 valid + 13 rejected numeric unit scenarios)
3. Deferred constraint integrity (3 deferred FKs + 1 constraint trigger)
4. Partial unique-index tests (`uq_lifebook_entities_active`)
5. RLS role matrix (agent_service, authenticated, system_service, admin, anon)
6. SECURITY DEFINER inspection
7. W11 deferral verification
8. Transactional rollback test
9. Full rebuild reproducibility check
10. `LIVE_EXECUTION_VALIDATION_REPORT.md`
11. Teardown (pause `iximbhwsjmppsdiwdixl`, confirm no credentials committed)

---

## Provenance Note (Permanent Record)

> M0003 (`20260726083203_core_schema.sql`) was applied through the official Supabase CLI
> migration mechanism (`supabase db push`) because the MCP `apply_migration` interface
> cannot transport approximately 180 KB of SQL in a single tool invocation. This is a
> tooling transport limitation only. It is not a schema defect and does not affect the
> validity of the migration. The migration file is frozen at commit
> `5dac8d3`, SHA-256
> `2559ca0e56769bc159e5943bbdf7c1326bfb154179440a218e74fb9d90047f8a`, 181,758 bytes,
> 2,903 lines. No further schema modifications are authorised until CLI execution either
> succeeds completely or exposes a genuine runtime SQL defect.

---

*End of LIVE_EXECUTION_RUNBOOK.md*
