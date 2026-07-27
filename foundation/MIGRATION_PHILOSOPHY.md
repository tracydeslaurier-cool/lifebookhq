# LifeBook Migration Philosophy
**Version:** 0.1  
**Status:** Approved for inclusion as preamble in each LifeBook migration from 0002 onward  
**Produced:** 2026-07-25  
**Produced by:** Discovery Partner + Claude (architecture session)  
**Scope:** Applies to all LifeBook Supabase migrations from 0002 onward

---

This document records the migration philosophy governing how LifeBook's database schema is written, applied, and maintained. It is intended to be reproduced verbatim as the opening comment block of each migration, beginning with migration 0002, with the migration-specific sections updated per file.

---

## 1. One Migration, One Logical Purpose

Each migration file corresponds to one logical layer of the schema. It does not patch a previous migration. It does not anticipate the next one. It begins where the prior migration ended and brings the schema to a named, self-consistent state.

| Migration | Logical purpose | Applied |
|---|---|---|
| `20260724153745_types_and_vocabularies.sql` (0001) | All enum types and controlled vocabularies | 2026-07-24 |
| `<TIMESTAMP>_predicate_governance_types.sql` (0002) | `relationship_interaction_type` enum; `display_policy_status` enum; `display_policy_decision` enum; `display_contexts` reference table (9 codes) | Pending |
| `<TIMESTAMP>_core_schema.sql` (0003) | All tables, constraints, triggers, and seed data for the structural layer | Pending |

If a future change requires modifying behaviour established in a prior migration — renaming a field, adding a column, dropping a constraint — it must be a new numbered migration, not an edit to the prior file. A migration file, once applied to any environment other than a local development branch, is immutable.

---

## 2. Migrations Are Additive

LifeBook migrations in the v1 phase are additive only. They do not rename columns by altering and re-populating live tables. They do not drop columns that carry data. They do not change enum values that are in use.

Additive means: new tables, new columns (nullable or with default), new constraints on empty tables, new seed data, new indexes, new triggers.

If a future architectural decision requires a non-additive change (e.g., splitting a table, removing a column with existing data, changing a column type), that change requires a formal Discovery Partner review session and a migration design document before SQL is written.

---

## 3. Migration 0001 Is the Foundation

Migration 0001 (`20260724153745_types_and_vocabularies.sql`) established all 37 enum types. Migration 0002 (`<TIMESTAMP>_predicate_governance_types.sql`) is a governed vocabulary migration: it adds `relationship_interaction_type`, `display_policy_status`, and `display_policy_decision` enums, and creates and seeds the `display_contexts` reference table (9 codes). Migration 0002 contains table DDL and seed data, not only enum types. Every table in the core-schema migration (0003) is written against the types and reference tables from migrations 0001 and 0002. The core-schema migration does not re-create, alter, or add to those types or reference tables.

If a future session determines that a new enum value is needed, it must be added in a new migration — not by editing 0001. The applied migration is not available for editing.

---

## 4. FK Ordering Is Explicit and Documented

Within a single migration file, tables must be created in an order that satisfies all foreign key constraints at the time each table is created. This means:

- Referenced tables must exist before referencing tables
- Self-referential FKs (e.g., `claims.superseded_by_claim_id → claims`) are declared at creation time and require no special handling
- Circular dependencies (where table A references table B and table B references table A) are resolved by declaring one FK as "file-order deferred" — added via `ALTER TABLE` after both tables exist. These FKs are **not** SQL-DEFERRABLE (they do not carry `DEFERRABLE INITIALLY DEFERRED/IMMEDIATE`); they are simply positioned later in the migration file to satisfy creation-order requirements.

Every file-order deferred FK in a migration is documented at the top of the migration file under **Deferred FK declarations**, specifying the table, field, target, and the step number within the migration where the `ALTER TABLE` is executed.

The core-schema migration (0003) carries the following deferred FK:

```
-- DEFERRED FK: authority_assignments.basis_claim_id → claims(id)
-- Added via ALTER TABLE at Step 15 (after claims table and seed)
-- Nullable FK; null is valid for authority_basis_type IN ('self_assertion', 'policy_default')
```

---

## 5. Seed Data Is Part of the Migration

Seed data — ClaimPredicates, RelationshipTypes, ClaimValueUnits, Jurisdictions, AgentRegistry records, ContextProfiles, and representative policy records — is inserted within the migration file, not in a separate operation.

Seed data is not optional data that can be added later. Reference tables (ClaimPredicate, RelationshipType, ClaimValueUnit) are used as FK targets by content records (Claim, Relationship). If the seed is not present, the FK constraints cannot be satisfied. The schema is not functional without the seed.

**Seed data ordering within the migration:**

1. Insert Jurisdiction seed (required before LifeBook records)
2. Create tables through the full dependency chain
3. Insert ClaimValueUnit seed
4. Insert ClaimPredicate seed (after ClaimValueUnit; predicates reference unit categories)
5. Create `trg_claim_numeric_unit_check` trigger (must appear after both seed INSERT blocks in migration execution order)
6. Insert RelationshipType seed
7. Insert AgentRegistry seed
8. Insert ContextProfile seed
9. Insert representative ApprovalPolicy, ConflictResolutionPolicy, and EscalationPolicy records

---

## 6. Triggers and Constraints Are the Final Layer

Database triggers and constraint checks that depend on seed data must be created after the relevant seed INSERT statements in the migration file. In a single-file migration, this means trigger DDL appears after the relevant INSERT blocks.

The exception is table-level DDL constraints (NOT NULL, UNIQUE, CHECK, FK) that apply to the table's own structure — these are declared at table creation time.

**Trigger naming convention:**

`trg_{table}_{behaviour}` — lowercase, underscore-separated, descriptive.

Example: `trg_claim_numeric_unit_check`

Trigger names must be stable. A trigger name, once created and applied, must not be changed without a new migration that drops and recreates the trigger.

---

## 7. RLS Is Part of the Migration

Row Level Security (RLS) policies are not applied as a separate operational step. They are part of the migration that creates the table they govern. If a table requires RLS, its policies are written in the same migration, after the table DDL.

RLS policies must be documented in VOCABULARY_RLS_MATRIX.md before they are written as SQL.

**Permanent-record tables** (where DELETE is denied for all roles) must have their RLS policy established in the same migration as the table. Deferring RLS on a permanent-record table is not permitted.

---

## 8. Strict Execution — Fail Loudly on Unexpected State

Governed migrations execute transactionally and fail loudly on unexpected prior state.

**Tables must not exist before creation.** Migrations use `CREATE TABLE` without `IF NOT EXISTS`. If a table already exists when a migration runs, the migration must fail — not silently skip the creation. An unexpected table means something is wrong with the migration lineage (partial prior application, out-of-order execution, manual intervention). The correct response is to investigate and resolve, not to proceed.

**Seed records must not already exist.** Seed data inserts use plain `INSERT INTO` without `ON CONFLICT DO NOTHING`. If a seed record with the same code already exists, the migration must fail with a unique constraint violation. A pre-existing seed record means either the migration was previously partially applied (a lineage problem) or a manual seed was inserted outside the migration system (a governance problem). Neither is silently acceptable.

**All migration SQL is wrapped in an explicit transaction.** If any statement in the migration fails, the entire migration rolls back. The database returns to its pre-migration state. There is no partial success. This is the correct behaviour for a governed schema migration.

**The only exception** is when a Supabase branch environment is being explicitly re-seeded for development purposes, under a documented process. Even then, re-seeding is performed by resetting the branch and re-applying the migration from scratch — not by patching the migration file to add `IF NOT EXISTS` or `ON CONFLICT` guards.

---

## 9. No Migration May Assume Application State

Migrations must work against the database schema alone. They may not assume that any application code has run before the migration, or that any application-layer defaults have been applied. Every default, constraint, and seed value required for the schema to function correctly must be expressed in the migration SQL itself.

This means: no migration may create a table whose integrity depends on the application creating a required record before the table is usable.

---

## 10. Migration Lineage Integrity

The Supabase migration lineage is the single source of truth for the schema's history. The following practices protect lineage integrity:

**Applied migrations are immutable.** Once a migration has been applied to any environment that shares lineage with production (including staging), the file must not be edited. If a correction is needed, it goes in the next migration.

**Migration filenames encode the moment of authorship**, using the timestamp format `YYYYMMDDHHMMSS_description.sql`. The timestamp must reflect the actual time of authoring, not a manually assigned sequence number. The Supabase migration system applies migrations in timestamp order.

**Rollback is a migration.** If a migration must be reversed in production, the reversal is a new numbered migration that performs the inverse operations (DROP TABLE, ALTER TABLE, etc.) in reverse dependency order. It is not performed by editing the Supabase migration lineage directly.

**Branch testing before main.** No migration is applied to the main Supabase branch without first being applied and verified on a development branch. The verification includes: confirming all tables were created, all seed records were inserted, all constraints are active, and a representative application query returns expected results.

---

## 11. Relationship to Foundation Documents

The migration SQL is derived from these foundation documents, which govern what may be expressed in SQL:

| Document | What it governs in SQL |
|---|---|
| `ARCHITECTURE_FREEZE_V1.md` | Frozen principles; any SQL that would violate P1–P13 is invalid |
| `SCHEMA_INVENTORY.md` | Table list, dependency order, and readiness status; governs what tables appear in each migration |
| `MIGRATION_SCOPE_MATRIX.md` | Readiness classification and explicit open items; governs which tables may be written |
| `CONTENT_LAYER.md` | Claim, ClaimPredicate, ClaimValueUnit, Relationship, Narrative, Source, Event, Artifact, and AI Context table structures |
| `GOVERNANCE_MODELS.md` | AuthorityAssignment, ApprovalPolicy, ConflictResolutionPolicy table structures |
| `OPERATIONAL_MODELS.md` | EscalationPolicy, ContestRecord, Jurisdiction, EscalationRecord, and related tables |
| `APPROVAL_INSTANCE_MODEL.md` | ApprovalRecord table structure; FK rules for consequential tables |
| `PERSON_ATTRIBUTE_CATALOGUE.md` | PersonName, PersonNameDerivative, PersonPronouns, PersonGenderDescriptor |
| `CLAIM_PREDICATE_CATALOGUE.md` | ClaimPredicate seed data (74 records) |
| `RELATIONSHIP_TYPE_CATALOGUE.md` | RelationshipType seed data (27 records) |
| `ANCHOR_MODELS.md` | Entity, Person, Organization, Place, Vessel, Community, EventSeries, LifeBook, UserPersonLink |
| `AI_CONTEXT_BROKER.md` | AgentRegistry, ContextManifest, ContextProfile seed data |

Where a foundation document and a migration file are in conflict, the conflict must be surfaced and resolved with a Discovery Partner decision before the migration is applied. Migration SQL may not unilaterally resolve a conflict with a foundation document.

---

## 12. What Requires a New Discovery Partner Session

The following changes to any migration require a formal Discovery Partner review session before proceeding:

- Adding a new enum value to a type established in migration 0001
- Dropping any column, table, or constraint
- Changing any column type in a way that is not strictly additive
- Applying a migration to the production Supabase branch
- Splitting a single planned migration into two or merging two planned migrations into one
- Adding a table to 0002 that was not in the approved MIGRATION_0002_PROPOSAL.md scope
- Deferring a table out of the core-schema migration (0003) that was in the approved proposal scope

---

*This philosophy governs how LifeBook builds its data foundation. Migrations that do not follow this philosophy must be corrected before application, not after.*
