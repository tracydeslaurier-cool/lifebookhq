# Final Static Validation Report
## LifeBook HQ — Migrations 0001, 0002, 0002b (application_roles), 0003

**Report date:** 2026-07-26  
**Validator:** validate_migrations.py v1.4 (pglast v8.4, AST-aware) — extended with M0002b, M0001 seed-total checks, Section 14 semantic schema validator (SEM-001–SEM-012), Section 15 regression tests (REGR-001–REGR-010), Section 16 execution-order validation (EO-001–EO-007)  
**Migration boundary correction applied:** Yes — claim_value_units removed from Migration 0003; owned by Migration 0001  
**Role correction applied (2026-07-26):** Yes — agent_service, system_service, admin, governance_functions created by new Migration 0002b (20260726083202_application_roles.sql); CREATE ROLE removed from core_schema; core_schema renamed to 20260726083203_core_schema.sql  
**M0001 seed count corrected (2026-07-26):** 338 → 345 (live-confirmed from disposable project)  
**FK defect correction applied (2026-07-26):** Yes — REFERENCES persons(id) corrected to REFERENCES persons(entity_id) in person_names, person_pronouns, person_gender_descriptors; RLS policy joins p.id corrected to p.entity_id  
**DP authorization:** Boundary correction approved; role correction authorized 2026-07-26; static validation phase authorized; FK defect correction authorized 2026-07-26  

---

## Executive Result

**STATIC VALIDATION PASSED — 141/141 checks, 0 failures, 0 undocumented dependencies.**

All four migration files parse cleanly with pglast. No duplicate schema objects exist across migrations. All foreign key targets are accounted for. The role correction (four NOLOGIN group roles extracted into dedicated migration 0002b) is confirmed in force and validated by machine check. The M0001 live seed count (345) matches the validator check. The FK defect (REFERENCES persons(id) → persons(entity_id)) has been corrected in M0003 and validated by new semantic and regression check sections. The validator script self-reports zero failures with no manual interpretation required.

> **Index count correction (2026-07-26):** `idx_entities_lifebook_id` removed from M0003 — the `entities` table has no `lifebook_id` column; lifebook scoping is via the `lifebook_entities` junction table. This was stale implementation drift. Index count reduced from 15 to 14.

> **FK defect correction (2026-07-26):** `REFERENCES persons(id)` corrected to `REFERENCES persons(entity_id)` in `person_names`, `person_pronouns`, and `person_gender_descriptors`. RLS policy joins using `p.id` where `p` aliases `persons` corrected to `p.entity_id`. Detection: live FK error against disposable project `tmvtdvrggmoiidvxdjzr`. Root cause: stale schema-reference defect — entity-typed persons PK refactor. Check count increased from 112 to 134 (22 new semantic/regression checks added).

> **Limitation statement:** Static validation cannot prove PostgreSQL runtime execution, transactional rollback, trigger behaviour, deferred-constraint behaviour, or RLS behaviour under non-superuser roles. The findings in this report reflect AST-level and text-structural analysis only.

---

## 1. Migration Ownership Audit

| Migration | File | Status | Owner |
|---|---|---|---|
| 0001 | `20260724153745_types_and_vocabularies.sql` | Applied to Supabase production AND disposable | Vocabulary layer: 39 ENUM types, 39 tables, 345 seed records (incl. 11 ClaimValueUnit) |
| 0002 | `20260726083201_predicate_governance_types.sql` | Applied to disposable; pending production | Predicate governance: 3 ENUM types, 1 table (display_contexts), 9 records |
| 0002b | `20260726083202_application_roles.sql` | Pending | Application roles: agent_service, system_service, admin, governance_functions (all NOLOGIN) |
| 0003 | `20260726083203_core_schema.sql` | Pending | Core schema: 49 tables, 31 functions, 22 triggers, 14 indexes, 71 RLS policies |

**Settled ownership:**
- Migration 0001 owns `claim_value_units`, the `unit_category` ENUM type, and all 11 ClaimValueUnit seed records. Live-confirmed total seed records: 345.
- Migration 0002 owns predicate-governance types and `display_contexts`.
- Migration 0002b owns all four NOLOGIN application group roles. Discovered as missing during disposable project baseline inspection 2026-07-26.
- Migration 0003 consumes those prerequisite objects and creates the core schema. Does not create roles.
- Migration 0003 does not recreate or reseed `claim_value_units`.

Full object-by-object ownership detail: see `MIGRATION_OBJECT_OWNERSHIP_MATRIX.md`.

---

## 2. Object Ownership Matrix Reference

See: `foundation/MIGRATION_OBJECT_OWNERSHIP_MATRIX.md`

---

## 3. Migration-Specific Object Counts

### Migration 0001 (applied)

| Object Type | Count |
|---|---|
| ENUM types created | 39 |
| Tables created | 39 |
| RLS policies created | 39 (vocab_read_authenticated × 39 tables) |
| Seed datasets | 39 |
| Total seed records | **345** (incl. 11 for claim_value_units) — live-confirmed 2026-07-26 |
| Functions, triggers, indexes | 0 each |
| Grants | 0 (grants applied by M0003) |

### Migration 0002 (pending)

| Object Type | Count |
|---|---|
| ENUM types created | 3 |
| Tables created | 1 (display_contexts) |
| RLS policies created | 0 |
| Seed records | 9 (display_contexts) |
| Functions, triggers, indexes | 0 each |
| Grants | 0 (grants applied by M0003) |

### Migration 0002b (pending)

| Object Type | Count |
|---|---|
| Roles created | 4 (agent_service, system_service, admin, governance_functions — all NOLOGIN) |
| Tables, functions, triggers, indexes, RLS policies | 0 each |
| Grants | 0 (grants applied by M0003) |
| Seed records | 0 |

### Migration 0003 (pending)

| Object Type | Count |
|---|---|
| Tables created | 49 |
| Functions created | 31 (9 public helpers + 22 trigger functions) |
| Triggers created | 22 |
| Indexes created | 14 (13 performance + 1 partial unique) |
| Deferred FKs (file-order ALTER TABLE) | 4 — added via ALTER TABLE for ordering; NOT SQL-DEFERRABLE (condeferrable=false) |
| CONSTRAINT TRIGGER (SQL-deferrable) | 1 |
| RLS-enabled tables | 25 |
| RLS policies created | 71 |
| Roles created | **0** — roles created by M0002b |
| ALTER OWNER statements | 8 |
| GRANT statements | 65 |
| Seed tables | 8 |
| Seed records — this migration only | 134 |
| ENUM types created | **0** |
| claim_value_units DDL | **None** — owned by M0001 |
| claim_value_units seeds | **0** — owned by M0001 |

---

## 4. Cumulative Counts After Migrations 0001–0002b–0003

| Object Type | Total | Breakdown |
|---|---|---|
| ENUM types | 42 | M0001: 39, M0002: 3, M0002b: 0, M0003: 0 |
| Tables | 89 | M0001: 39, M0002: 1, M0002b: 0, M0003: 49 |
| Functions | 31 | M0001: 0, M0002: 0, M0002b: 0, M0003: 31 |
| Triggers | 22 | M0001: 0, M0002: 0, M0002b: 0, M0003: 22 |
| Indexes (explicit) | 14 | M0001: 0, M0002: 0, M0002b: 0, M0003: 14 |
| Deferred FKs (ALTER TABLE, NOT SQL-DEFERRABLE) | 4 | M0003 only |
| CONSTRAINT TRIGGERs (SQL-deferrable) | 1 | M0003 only |
| RLS-enabled tables | 25 | M0003 only (M0001 tables have dormant policies) |
| RLS policies | 110 | M0001: 39, M0002: 0, M0002b: 0, M0003: 71 |
| Roles | 4 | M0002b: agent_service, system_service, admin, governance_functions |
| GRANT statements | 65 | M0003 only |
| Seed records | **488** | M0001: 345, M0002: 9, M0002b: 0, M0003: 134 |

**claim_value_units — cumulative state:**
- Table exists: Yes (created in M0001)
- Rows present: 11 (seeded in M0001, live-confirmed)
- Rows added by M0003: **0**
- FK consumer: `claims.value_unit_code` (M0003)
- GRANT SELECT: Applied in M0003 (M0001 does not grant)

---

## 5. Syntax / AST Validation

All four migrations parsed cleanly with pglast. No syntax errors. No unclassified statement types.

| Migration | Lines | Statements | Status |
|---|---|---|---|
| M0001 | 1,761 | 158 | CLEAN |
| M0002 | 207 | 8 | CLEAN |
| M0002b | 186 | 10 | CLEAN |
| M0003 | 2,906 | 302 | CLEAN |

### Statement Breakdown — M0001 (158)

| Type | Count |
|---|---|
| CreateEnumStmt | 39 |
| CreatePolicyStmt | 39 |
| CreateStmt (TABLE) | 39 |
| DoStmt | 1 |
| InsertStmt | 39 |
| UpdateStmt | 1 |

### Statement Breakdown — M0002 (8)

| Type | Count |
|---|---|
| CommentStmt | 1 |
| CreateEnumStmt | 3 |
| CreateStmt (TABLE) | 1 |
| InsertStmt | 1 |
| TransactionStmt (BEGIN, COMMIT) | 2 |

### Statement Breakdown — M0002b (10)

| Type | Count |
|---|---|
| CommentStmt | 4 |
| CreateRoleStmt | 4 |
| TransactionStmt (BEGIN, COMMIT) | 2 |

### Statement Breakdown — M0003 (302)

| Type | Count |
|---|---|
| AlterOwnerStmt | 8 |
| AlterTableStmt | 31 |
| CreateFunctionStmt | 31 |
| CreatePolicyStmt | 71 |
| CreateRoleStmt | **0** — roles in M0002b |
| CreateStmt (TABLE) | 49 |
| CreateTrigStmt | 22 |
| GrantStmt | 64 |
| IndexStmt | 14 |
| InsertStmt | 8 |
| TransactionStmt (BEGIN, COMMIT) | 2 |
| UpdateStmt | 1 |

---

## 6. Duplicate-Object Audit

No duplicate schema object names exist across any pair of migrations.

| Comparison | Types | Tables | Functions | Triggers | Roles |
|---|---|---|---|---|---|
| M0001 vs M0002 | 0 duplicates ✓ | 0 duplicates ✓ | N/A | N/A | N/A |
| M0001 vs M0003 | 0 duplicates ✓ | 0 duplicates ✓ | N/A (M0001 defines none) | N/A | N/A |
| M0002 vs M0003 | 0 duplicates ✓ | 0 duplicates ✓ | N/A (M0002 defines none) | N/A | N/A |
| M0001 creates no roles | ✓ | — | — | — | 0 roles |
| M0002 creates no roles | ✓ | — | — | — | 0 roles |
| M0003 creates no roles | ✓ | — | — | — | 0 roles |

**claim_value_units conflict resolution:** Confirmed. The `CREATE TABLE claim_value_units` and all 11 `INSERT INTO claim_value_units` records were removed from Migration 0003 on 2026-07-26 per DP decision (Option C). The table is now exclusively owned and seeded by Migration 0001.

**governance_functions role conflict resolution:** Confirmed. `CREATE ROLE governance_functions` was removed from Migration 0003 on 2026-07-26. The role is now exclusively created by Migration 0002b.

---

## 7. Dependency Validation

All external dependencies referenced by Migration 0003 are classified. Zero undocumented dependencies.

| Classification | Count | Objects |
|---|---|---|
| Created within M0003 (earlier in file) | 30 | All core schema tables |
| Prerequisite from M0001 | 1 | `claim_value_units` |
| Prerequisite from M0002 | 1 | `display_contexts` |
| Prerequisite from M0002b | 4 | `agent_service`, `system_service`, `admin`, `governance_functions` (roles consumed by GRANT and OWNER TO) |
| Supabase/PostgreSQL built-in | 1 | `auth.users` |
| **UNDOCUMENTED (stop condition)** | **0** | — |

### External Prerequisites Inventory

| Object | Type | Source | Used By |
|---|---|---|---|
| `auth.users` | Table | Supabase auth schema (built-in) | `user_profiles.id` FK |
| `pg_temp` | Schema | PostgreSQL built-in | SET search_path in SECURITY DEFINER functions |
| `public` | Schema | PostgreSQL default | SET search_path in SECURITY DEFINER functions |
| `gen_random_uuid()` | Function | PostgreSQL pgcrypto / pg_catalog | DEFAULT on all UUID PKs |
| `now()` | Function | PostgreSQL built-in | DEFAULT on timestamp columns |
| `authenticated` | Role | Supabase platform (built-in) | GRANT targets |
| `agent_service` | Role | Migration 0002b (20260726083202_application_roles.sql) — NOLOGIN group role | GRANT targets |
| `system_service` | Role | Migration 0002b (20260726083202_application_roles.sql) — NOLOGIN group role | GRANT targets |
| `admin` | Role | Migration 0002b (20260726083202_application_roles.sql) — NOLOGIN group role | GRANT targets |
| `governance_functions` | Role | Migration 0002b (20260726083202_application_roles.sql) — NOLOGIN group role | OWNER TO target for functions |

---

## 8. Seed Validation

| Table | Owner | Expected | AST count | Status |
|---|---|---|---|---|
| `claim_value_units` | **M0001** | 11 | 11 | ✓ PASS |
| `display_contexts` | M0002 | 9 | 9 | ✓ PASS |
| `jurisdictions` | M0003 | 6 | 6 | ✓ PASS |
| `claim_predicates` | M0003 | 74 | 74 | ✓ PASS |
| `relationship_types` | M0003 | 27 | 27 | ✓ PASS |
| `escalation_policies` | M0003 | 7 | 7 | ✓ PASS |
| `approval_policies` | M0003 | 5 | 5 | ✓ PASS |
| `conflict_resolution_policies` | M0003 | 4 | 4 | ✓ PASS |
| `agent_registry` | M0003 | 9 | 9 | ✓ PASS |
| `context_profiles` | M0003 | 2 | 2 | ✓ PASS |

**M0001 total seed records:** 345 (AST-confirmed). Live-confirmed against disposable project 2026-07-26.

**ON CONFLICT note:** Migration 0001 seed INSERTs use `ON CONFLICT DO NOTHING` (pre-philosophy era). Migrations 0002, 0002b, and 0003 use plain INSERTs per the current migration philosophy — confirmed zero ON CONFLICT clauses (AST-verified).

---

## 9. Trigger and Function Wiring Validation

All 22 `_fn_trg_*` trigger functions have a matching `trg_*` CREATE TRIGGER statement — no orphaned functions, no triggers without backing functions.

| Trigger | Table | Timing | Special |
|---|---|---|---|
| `trg_claim_numeric_unit_check` | `claims` | BEFORE INSERT, UPDATE | SECURITY DEFINER; reads `claim_value_units` from M0001; confirmed BEFORE timing via AST |
| `trg_lifebook_person_context_completeness` | `lifebook_entities` | AFTER INSERT | CONSTRAINT TRIGGER DEFERRABLE INITIALLY DEFERRED (confirmed via AST) |
| `trg_source_derivative_invalidation_cascade` | `source_derivatives` | AFTER UPDATE | STUB — issues RAISE NOTICE only; no cascade logic until Context Broker spec |
| `fn_generate_artifact_signed_url` | N/A (public helper) | N/A | STUB — returns NULL; awaiting storage integration |

`_fn_trg_claim_numeric_unit_check` SECURITY DEFINER check:
- SECURITY DEFINER: ✓
- SET search_path = 'public', pg_temp: ✓
- References only columns present in M0001 schema (`unit_category`, `requires_qualifier`, `deprecated_at`): ✓
- No reference to `claim_value_units.id`: ✓
- No `value_unit_id` column reference: ✓

---

## 10. RLS Inventory Validation

| Migration | RLS-enabled tables | RLS policies | Status |
|---|---|---|---|
| M0001 | 0 (policies present but ENABLE not issued) | 39 | Dormant policies |
| M0002 | 0 | 0 | No RLS |
| M0002b | 0 | 0 | No RLS (roles only) |
| M0003 | 25 (AST-verified) | 71 | Active |

**RLS coverage note:** M0001's 39 `vocab_read_authenticated` policies are present in the database but will not be enforced unless `ENABLE ROW LEVEL SECURITY` is issued for each table in a future migration. The vocabulary tables are currently readable without RLS enforcement, which is the intended behaviour (universal read access for authenticated sessions).

---

## 11. Checksum Manifest

Migration files must not be modified after this manifest without regenerating the report.

| Migration | File | SHA-256 | Lines | Bytes |
|---|---|---|---|---|
| M0001 | `20260724153745_types_and_vocabularies.sql` | `10299654bc6d58ede4f685fbe2642149498ef08e652d3ea98231e449bada9f93` | 1,761 | 81,844 |
| M0002 | `20260726083201_predicate_governance_types.sql` | `1022fd2aa57410a005da4502dc64a0ba07fc363c0f2d45d771bd39d458178656` | 207 | 8,576 |
| M0002b | `20260726083202_application_roles.sql` | `24daadbeef3afd448a5637a5a0c5cec28fea23dd48948a9f1203c15e9f064d24` | 186 | 7,885 |
| M0003 | `20260726083203_core_schema.sql` | `136b1f255b019ce97bbd7f62e868c0f411f941ebde1658a638d21d19276a54cc` | 2,953 | 185,021 |

**Note on M0003 checksum change:** M0003 has undergone seven corrections since initial authoring:
1. Renamed from `20260726083201_core_schema.sql`; header updated; `CREATE ROLE governance_functions` removed (SHA-256 was: `9770d0b34398047ded53c447f6364842582addb1d54e2d2352ddd28319231c41`, then: `e254372a6c6658ea87b68ad4b747a974e632b16ad9632eb0eefa060fac916110`).
2. Removed stale `idx_entities_lifebook_id` index 2026-07-26 — entities has no `lifebook_id` column; index count reduced 15 → 14 (SHA-256: `fbd60d9f5208be8b6af567cc341a80e7a4ccfc67c5c909a5da541609f395a60a`, 179,606 bytes).
3. FK defect correction 2026-07-26 — REFERENCES persons(id) → persons(entity_id) in 3 tables; RLS joins p.id → p.entity_id in 8 locations. Line count unchanged (2,872); byte count 179,606 → 179,683.
4. Authored-order defect correction 2026-07-26 — `CREATE INDEX idx_claims_lifebook_review_access` moved from Phase 3 (before `ALTER TABLE claims ADD COLUMN review_status`) to after the Addendum ALTER TABLE. Root cause: SQLSTATE 42703 on iximbhwsjmppsdiwdixl. Lines 2,872 → 2,882; bytes 179,683 → 180,269. Validator extended with Section 16 EO-001–EO-003.
5. Ownership transfer bootstrap — role membership 2026-07-26 — `GRANT governance_functions TO postgres` added immediately after BEGIN. Root cause: SQLSTATE 42501 "must be able to SET ROLE governance_functions" on iximbhwsjmppsdiwdixl. Supabase migration executor (postgres) is not automatically a member of governance_functions after M0002b creates it. `GRANT ... TO current_user` causes unexpected EOF on Supabase CLI — postgres must be named explicitly. Lines 2,882 → 2,906; bytes 180,269 → 182,054. Validator extended with EO-004–EO-005.
6. Ownership transfer bootstrap — schema CREATE privilege 2026-07-26 — `GRANT USAGE, CREATE ON SCHEMA public TO governance_functions` added immediately after the role membership GRANT. Root cause: SQLSTATE 42501 "permission denied for schema public" at ALTER FUNCTION ... OWNER TO governance_functions. Evidence: governance_functions held USAGE but not CREATE on the public schema; PostgreSQL requires CREATE to transfer object ownership. Lines 2,906 → 2,933; bytes 182,054 → 183,741. Validator extended with EO-006 (both prerequisites must precede first OWNER TO). Header grant count updated 64 → 65.
7. RLS policy execution-order defect 2026-07-26 — `pol_claims_ai_promotion_denied` (Policy 30) and `pol_narratives_ai_promotion_denied` (Policy 32) moved from Group D (Phase 8 RLS block) to after the Addendum ALTER TABLE statements. Root cause: SQLSTATE 42703 "column review_status does not exist" — both policies referenced `claims.review_status` and `narratives.review_status` respectively, which are added by Addendum ALTER TABLEs executed later in the file. Lines 2,933 → 2,953; bytes 183,741 → 185,021. Validator extended with EO-007. 141/141 checks pass.
The checksum above reflects the fully corrected file.

**Git working tree state:** All four migrations committed. See commit log for hashes.

**Timestamp:** 2026-07-26 (updated post ownership-transfer bootstrap correction)

---

## 12. Defect History

### DEF-0001 — REFERENCES persons(id) in person_names, person_pronouns, person_gender_descriptors

| Field | Detail |
|---|---|
| Defect ID | DEF-0001 |
| Defect | `REFERENCES persons(id)` in `person_names`, `person_pronouns`, `person_gender_descriptors`; `p.id` join in RLS policies where `p` aliases `persons` table |
| Detection | Live FK error against disposable Supabase project `tmvtdvrggmoiidvxdjzr` (2026-07-26) |
| Root cause | Stale schema-reference defect — entity-typed `persons` PK refactor; `persons.entity_id` is the PK; `persons.id` does not exist |
| Fix applied | Changed `REFERENCES persons(id)` to `REFERENCES persons(entity_id)` in 3 FK column definitions; changed 8 RLS join/filter expressions from `p.id` to `p.entity_id` |
| Files modified | `supabase/migrations/20260726083203_core_schema.sql` only |
| Locations fixed | Lines 1056, 1109, 1128 (FK definitions); lines 2337, 2343, 2357, 2363, 2377, 2383, 2395, 2406 (RLS joins) |
| Static validation gap | pglast AST parsing cannot resolve FK target column existence without live schema state; the defect was present in the file since authoring and passed all prior static checks |
| Gap closure | Section 14 semantic schema validator (SEM-001–SEM-012) and Section 15 regression tests (REGR-001–REGR-010) added to `validate_migrations.py` to close this gap; SEM-002, SEM-004, SEM-007–009, REGR-005–008 directly guard against recurrence |

### DEF-0002 — CREATE INDEX idx_claims_lifebook_review_access before ADD COLUMN review_status

| Field | Detail |
|---|---|
| Defect ID | DEF-0002 |
| Defect | `CREATE INDEX idx_claims_lifebook_review_access ON claims (lifebook_id, review_status, access_classification)` placed in Phase 3 (line 1167), before `ALTER TABLE claims ADD COLUMN review_status` in the Addendum (line 2789) |
| Detection | Runtime failure SQLSTATE 42703 on disposable project `iximbhwsjmppsdiwdixl` — "column review_status does not exist" |
| Root cause | Use-before-definition: CREATE INDEX executed before the ALTER TABLE that creates the referenced column |
| Fix applied | Removed CREATE INDEX from Phase 3; added it after `ALTER TABLE narratives ADD COLUMN review_status` in the Addendum, with explanatory comments at both locations |
| Files modified | `supabase/migrations/20260726083203_core_schema.sql`, `foundation/validate_migrations.py` |
| Gap closure | Section 16 EO-001–EO-003 added to `validate_migrations.py` with execution-order model (`check_index_execution_order`, `strip_dollar_quoted_blocks`); detects use-before-definition for all CREATE INDEX statements |

### DEF-0003 — governance_functions ownership prerequisites missing before OWNER TO

| Field | Detail |
|---|---|
| Defect ID | DEF-0003 |
| Defect | `ALTER FUNCTION fn_lb_membership_role(UUID) OWNER TO governance_functions` (and 7 further OWNER TO statements) issued without two required prerequisites: (a) migration executor membership in `governance_functions`, and (b) `governance_functions` holding CREATE privilege on the public schema. |
| Detection (part 1) | Runtime failure SQLSTATE 42501 on disposable project `iximbhwsjmppsdiwdixl` — "must be able to SET ROLE governance_functions" |
| Detection (part 2) | After role membership fix, runtime failure SQLSTATE 42501 — "permission denied for schema public" at the first OWNER TO statement. Evidence: `governance_functions` USAGE=true, CREATE=false on public schema. |
| Root cause (part 1) | PostgreSQL requires SET ROLE access to the target role for ownership transfer. Supabase migration executor (postgres) is not automatically a member of `governance_functions` after M0002b creates it. `GrantRoleStmt` was absent from M0003. |
| Root cause (part 2) | PostgreSQL requires the target role to hold CREATE on the schema containing the object being re-owned. USAGE alone is not sufficient — without CREATE, ownership transfer is denied even when role membership is satisfied. |
| Fix applied | Two bootstrap GRANTs added to M0003 immediately after BEGIN, in order: (1) `GRANT governance_functions TO postgres;` — provides SET ROLE access. (2) `GRANT USAGE, CREATE ON SCHEMA public TO governance_functions;` — provides schema CREATE privilege. `GRANT ... TO current_user` causes unexpected EOF / connection termination on Supabase CLI — postgres must be named explicitly. Both GRANTs are permanent. Header grant count updated 64 → 65 (the schema GRANT is a `GrantStmt`). |
| Files modified | `supabase/migrations/20260726083203_core_schema.sql`, `foundation/validate_migrations.py` |
| Design note | M0002b's invariant ("no GRANT statements — grants are M0003's scope") is preserved. The bootstrap grants live in M0003 alongside all other grants. `GrantRoleStmt` (role membership) is a distinct AST type from `GrantStmt` (object/schema privilege) — role membership GRANT does not change the `GrantStmt` count. |
| Gap closure | EO-004 (role membership GRANT precedes first OWNER TO), EO-005 (exactly 1 GrantRoleStmt targeting postgres), and EO-006 (both prerequisites — role membership + schema CREATE — precede first OWNER TO governance_functions) added to `validate_migrations.py` Section 16 |

### DEF-0004 — CREATE POLICY referencing Addendum-added columns before ALTER TABLE

| Field | Detail |
|---|---|
| Defect ID | DEF-0004 |
| Defect | `pol_claims_ai_promotion_denied` (Policy 30) and `pol_narratives_ai_promotion_denied` (Policy 32) placed in Phase 8 (Group D RLS block) referenced `claims.review_status` and `narratives.review_status` respectively. Both columns are added by Addendum ALTER TABLE statements later in the file. |
| Detection | Runtime failure SQLSTATE 42703 on disposable project `iximbhwsjmppsdiwdixl` — "column review_status does not exist" at `CREATE POLICY pol_claims_ai_promotion_denied` |
| Root cause | PostgreSQL validates column references in CREATE POLICY expressions at statement execution time. If the column does not yet exist on the table, the statement fails. The migration was logically organised (all RLS policies in Phase 8) but not chronologically correct — the Addendum ADD COLUMN must precede any policy that references those columns. |
| Scope | Audit of all CREATE POLICY, CREATE INDEX, CREATE TRIGGER statements before the Addendum: only policies 30 and 32 were affected. CREATE INDEX (EO-002) and trigger functions (PL/pgSQL bodies not validated at CREATE FUNCTION time) were clean. |
| Fix applied | `pol_claims_ai_promotion_denied` and `pol_narratives_ai_promotion_denied` removed from Group D (Phase 8 RLS block) and placed after the Addendum ALTER TABLE statements, with forward-reference comments at the original locations explaining the deferral. Lines 2,933 → 2,953; bytes 183,741 → 185,021. |
| Files modified | `supabase/migrations/20260726083203_core_schema.sql`, `foundation/validate_migrations.py` |
| Gap closure | EO-007 added to `validate_migrations.py` Section 16: scans all CREATE POLICY statements before the Addendum marker and fails if any reference an Addendum-added column (`review_status`, `submission_origin`, `ai_generated`, `producing_agent_code`, `context_manifest_id`) in a non-comment SQL expression. Uses `strip_dollar_quoted_blocks()` to exclude PL/pgSQL body false-positives; strips per-block line comments before column-name matching. |

---

## 13. Known Environment Limitation

Live execution of Migration 0003 has not been performed. The following constraints apply:

| Constraint | Detail |
|---|---|
| No local PostgreSQL | ARM64 Ubuntu 22.04 sandbox has no root access; PostgreSQL cannot be installed |
| Supabase branching requires Pro plan | The LifeBook HQ project is on a Free plan |
| Migration 0002b + 0003 not yet applied | M0001 and M0002 applied to disposable; M0002b and M0003 pending |
| Production database treated as immutable | The production project must not receive any migration until live execution validation is complete in the disposable environment |
| Application roles missing from disposable | agent_service, system_service, admin, governance_functions did not exist on the disposable project before M0002b was authored — confirmed stop condition that triggered role correction |

---

## 14. Available Paths for Live Execution Validation

Live execution is planned against disposable project `tmvtdvrggmoiidvxdjzr` (ca-central-1, PostgreSQL 17.6.1.147). M0001 and M0002 are applied. Next step is to apply M0002b (application_roles), then M0003 (core_schema), and run the full trigger/RLS/constraint test matrix per the 17-step plan authorized by DP 2026-07-26.

---

## 15. Final Recommendation

**Proceed to live execution on disposable project.** Apply M0002b, then M0003. All static checks pass. The migration set is internally consistent, dependency-complete, and role-correct. No further static blockers exist.

The DP-authorized stop condition (missing application roles) has been resolved by the creation of M0002b. The stop condition check (pre-flight query: zero rows for all four role names in pg_roles) should be run against the disposable project before applying M0002b.

---

*FINAL_STATIC_VALIDATION_REPORT.md — LifeBook HQ — 2026-07-26 (v8, DEF-0001 FK correction, DEF-0002 authored-order index, DEF-0003 ownership bootstrap parts 1+2, DEF-0004 RLS policy execution-order; 141/141 checks)*
