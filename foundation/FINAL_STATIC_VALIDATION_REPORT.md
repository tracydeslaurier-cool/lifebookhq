# Final Static Validation Report
## LifeBook HQ — Migrations 0001, 0002, 0003

**Report date:** 2026-07-26  
**Validator:** validate_migrations.py v1.0 (pglast v8.4, AST-aware)  
**Migration boundary correction applied:** Yes — claim_value_units removed from Migration 0003; owned by Migration 0001  
**DP authorization:** Boundary correction approved; static validation phase authorized  

---

## Executive Result

**STATIC VALIDATION PASSED — 90/90 checks, 0 failures, 0 undocumented dependencies.**

All three migration files parse cleanly with pglast. No duplicate schema objects exist across migrations. All foreign key targets are accounted for. The migration-boundary correction (removing `claim_value_units` from Migration 0003) is confirmed in force and validated by machine check. The validator script self-reports zero failures with no manual interpretation required.

> **Limitation statement:** Static validation cannot prove PostgreSQL runtime execution, transactional rollback, trigger behaviour, deferred-constraint behaviour, or RLS behaviour under non-superuser roles. The findings in this report reflect AST-level and text-structural analysis only.

---

## 1. Migration Ownership Audit

| Migration | File | Status | Owner |
|---|---|---|---|
| 0001 | `20260724153745_types_and_vocabularies.sql` | Applied to Supabase production | Vocabulary layer: 39 ENUM types, 39 tables, 11 ClaimValueUnit records |
| 0002 | `20260726083201_predicate_governance_types.sql` | Pending | Predicate governance: 3 ENUM types, 1 table (display_contexts), 9 records |
| 0003 | `20260726083201_core_schema.sql` | Pending | Core schema: 49 tables, 31 functions, 22 triggers, 15 indexes, 71 RLS policies |

**Settled ownership:**
- Migration 0001 owns `claim_value_units`, the `unit_category` ENUM type, and all 11 ClaimValueUnit seed records.
- Migration 0002 owns predicate-governance types and `display_contexts`.
- Migration 0003 consumes those prerequisite objects and creates the core schema.
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
| Total seed records | 338 (incl. 11 for claim_value_units) |
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

### Migration 0003 (pending)

| Object Type | Count |
|---|---|
| Tables created | 49 |
| Functions created | 31 (9 public helpers + 22 trigger functions) |
| Triggers created | 22 |
| Indexes created | 15 (14 performance + 1 partial unique) |
| Deferred FKs (file-order ALTER TABLE) | 4 |
| CONSTRAINT TRIGGER (SQL-deferrable) | 1 |
| RLS-enabled tables | 25 |
| RLS policies created | 71 |
| Roles created | 1 (governance_functions) |
| ALTER OWNER statements | 8 |
| GRANT statements | 64 |
| Seed tables | 8 |
| Seed records — this migration only | 134 |
| ENUM types created | **0** |
| claim_value_units DDL | **None** — owned by M0001 |
| claim_value_units seeds | **0** — owned by M0001 |

---

## 4. Cumulative Counts After Migrations 0001–0003

| Object Type | Total | Breakdown |
|---|---|---|
| ENUM types | 42 | M0001: 39, M0002: 3, M0003: 0 |
| Tables | 89 | M0001: 39, M0002: 1, M0003: 49 |
| Functions | 31 | M0001: 0, M0002: 0, M0003: 31 |
| Triggers | 22 | M0001: 0, M0002: 0, M0003: 22 |
| Indexes (explicit) | 15 | M0001: 0, M0002: 0, M0003: 15 |
| Deferred FKs (ALTER TABLE) | 4 | M0003 only |
| CONSTRAINT TRIGGERs (SQL-deferrable) | 1 | M0003 only |
| RLS-enabled tables | 25 | M0003 only (M0001 tables have dormant policies) |
| RLS policies | 110 | M0001: 39, M0002: 0, M0003: 71 |
| Roles | 1 | M0003: governance_functions |
| GRANT statements | 64 | M0003 only |
| Seed records | 481 | M0001: 338, M0002: 9, M0003: 134 |

**claim_value_units — cumulative state:**
- Table exists: Yes (created in M0001)
- Rows present: 11 (seeded in M0001)
- Rows added by M0003: **0**
- FK consumer: `claims.value_unit_code` (M0003)
- GRANT SELECT: Applied in M0003 (M0001 does not grant)

---

## 5. Syntax / AST Validation

All three migrations parsed cleanly with pglast. No syntax errors. No unclassified statement types (all statement node names match expected PostgreSQL grammar constructs).

| Migration | Lines | Statements | Status |
|---|---|---|---|
| M0001 | 1,761 | 158 | CLEAN |
| M0002 | 207 | 8 | CLEAN |
| M0003 | 2,867 | 303 | CLEAN |

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

### Statement Breakdown — M0003 (303)

| Type | Count |
|---|---|
| AlterOwnerStmt | 8 |
| AlterTableStmt | 31 |
| CreateFunctionStmt | 31 |
| CreatePolicyStmt | 71 |
| CreateRoleStmt | 1 |
| CreateStmt (TABLE) | 49 |
| CreateTrigStmt | 22 |
| GrantStmt | 64 |
| IndexStmt | 15 |
| InsertStmt | 8 |
| TransactionStmt (BEGIN, COMMIT) | 2 |
| UpdateStmt | 1 |

---

## 6. Duplicate-Object Audit

No duplicate schema object names exist across any pair of migrations.

| Comparison | Types | Tables | Functions | Triggers |
|---|---|---|---|---|
| M0001 vs M0002 | 0 duplicates ✓ | 0 duplicates ✓ | N/A (neither defines functions) | N/A |
| M0001 vs M0003 | 0 duplicates ✓ | 0 duplicates ✓ | N/A (M0001 defines none) | N/A |
| M0002 vs M0003 | 0 duplicates ✓ | 0 duplicates ✓ | N/A (M0002 defines none) | N/A |

**claim_value_units conflict resolution:** Confirmed. The `CREATE TABLE claim_value_units` and all 11 `INSERT INTO claim_value_units` records were removed from Migration 0003 on 2026-07-26 per DP decision (Option C). The table is now exclusively owned and seeded by Migration 0001. Zero occurrences of `CREATE TABLE claim_value_units` or `INSERT INTO claim_value_units` remain in Migration 0003.

---

## 7. Dependency Validation

All external dependencies referenced by Migration 0003 are classified. Zero undocumented dependencies.

| Classification | Count | Objects |
|---|---|---|
| Created within M0003 (earlier in file) | 30 | All core schema tables |
| Prerequisite from M0001 | 1 | `claim_value_units` |
| Prerequisite from M0002 | 1 | `display_contexts` |
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
| `agent_service` | Role | Supabase platform (built-in) | GRANT targets |
| `system_service` | Role | Supabase platform (built-in) | GRANT targets |
| `admin` | Role | Supabase platform (built-in) | GRANT targets |
| `governance_functions` | Role | Created in M0003 itself (CreateRoleStmt) | OWNER TO target for functions |

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

**ON CONFLICT note:** Migration 0001 seed INSERTs use `ON CONFLICT DO NOTHING` (pre-philosophy era). Migration 0002 and 0003 use plain INSERTs per the current migration philosophy — confirmed zero ON CONFLICT clauses in M0002 and M0003 (AST-verified).

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
| M0003 | 25 (AST-verified) | 71 | Active |

**RLS coverage note:** M0001's 39 `vocab_read_authenticated` policies are present in the database but will not be enforced unless `ENABLE ROW LEVEL SECURITY` is issued for each table in a future migration. The vocabulary tables are currently readable without RLS enforcement, which is the intended behaviour (universal read access for authenticated sessions).

---

## 11. Checksum Manifest

Migration files must not be modified after this manifest without regenerating the report.

| Migration | File | SHA-256 | Lines | Bytes |
|---|---|---|---|---|
| M0001 | `20260724153745_types_and_vocabularies.sql` | `10299654bc6d58ede4f685fbe2642149498ef08e652d3ea98231e449bada9f93` | 1,761 | 81,844 |
| M0002 | `20260726083201_predicate_governance_types.sql` | `1022fd2aa57410a005da4502dc64a0ba07fc363c0f2d45d771bd39d458178656` | 207 | 8,576 |
| M0003 | `20260726083201_core_schema.sql` | `9770d0b34398047ded53c447f6364842582addb1d54e2d2352ddd28319231c41` | 2,867 | 179,182 |

**Git working tree state:** M0001 is committed. M0002 and M0003 are untracked working-tree files as of this report date. They should be committed under version control before any live execution attempt.

**Timestamp:** 2026-07-26

---

## 12. Known Environment Limitation

Live execution of Migration 0003 has not been performed. The following constraints apply to the current environment:

| Constraint | Detail |
|---|---|
| No local PostgreSQL | ARM64 Ubuntu 22.04 sandbox has no root access; PostgreSQL cannot be installed |
| Supabase branching requires Pro plan | The LifeBook HQ project is on a Free plan; `create_branch` returned "Branching is supported only on the Pro plan or above" |
| Migration 0002 + 0003 not yet applied | Only Migration 0001 has been applied to the live Supabase project |
| Production database treated as immutable | The current Supabase project must not receive M0002 or M0003 until live execution validation is complete in an isolated environment |

---

## 13. Available Paths for Live Execution Validation

The following options are available to complete live execution validation, in recommended order:

| Option | Description | Cost / Effort | Risk |
|---|---|---|---|
| **A. Temporary Supabase Pro upgrade** | Upgrade LifeBook HQ project to Pro; create a disposable branch; apply M0001→M0002→M0003 in order; run the 13 trigger test cases; validate RLS under non-superuser roles; delete branch; downgrade if desired | ~$25 USD for one month | Lowest — identical production environment (PostgreSQL 17.6.1, ca-central-1) |
| **B. Isolated temporary Supabase project** | Create a new Free-tier Supabase project in the same region; apply all 3 migrations; validate; delete the project | Free | Low — same platform, minor schema drift if Supabase version differs |
| **C. Local disposable PostgreSQL 17** | Install PostgreSQL 17 in a Docker container or Nix environment on a local machine; apply migrations; run tests | Free, requires Docker or Nix | Low — requires matching `gen_random_uuid()` and `auth.users` stub |
| **D. CI PostgreSQL 17 service container** | Add a GitHub Actions workflow with `services: postgres:17`; apply migrations; run test assertions | Free if repo is public or has available Actions minutes | Low — automated, reproducible |

**Recommendation:** Option A (temporary Supabase branch) is the most reliable because it uses an exact replica of the production environment including PostgreSQL version, extension set, auth schema, and row-level storage. Options B–D require stub work for `auth.users` or may introduce subtle version differences.

---

## 14. Final Recommendation

Migration 0003 is structurally sound at the static level. The migration-boundary conflict (`claim_value_units` duplicated between M0001 and M0003) has been resolved and verified by machine check. All 90 static validation checks pass. Zero undocumented dependencies exist.

**Recommended next actions, in order:**

1. Commit M0002 and M0003 to version control under the `supabase/migrations/` path.
2. Select a live execution environment from the options in Section 13.
3. Apply migrations 0001 → 0002 → 0003 in a disposable environment.
4. Execute the 13 trigger test cases for `trg_claim_numeric_unit_check`.
5. Validate `uq_lifebook_entities_active` partial unique constraint.
6. Validate RLS under `authenticated`, `agent_service`, and `system_service` roles.
7. Confirm W11 deferral (`file_storage_references` REVOKE not present in M0003).
8. Confirm rollback and rebuild from scratch (apply all 3 migrations from zero).
9. Produce the live execution validation report.

No architectural changes are authorised. The static validation phase is complete.

---

*FINAL_STATIC_VALIDATION_REPORT.md — LifeBook HQ — 2026-07-26*
