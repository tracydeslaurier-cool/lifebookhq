# Migration 0003 — SQL File Skeleton
**Version:** 1.0  
**Status:** Pre-authoring navigation document — no SQL  
**Date:** 2026-07-25  
**Purpose:** Exact structural outline of the Migration 0003 SQL file. Use this document to navigate the file during authoring and review. Every section header below corresponds to a section in the migration file. Order is authoritative — do not deviate.

**Source documents:**  
MIGRATION_IMPLEMENTATION_PLAN.md v1.0 · VOCABULARY_RLS_MATRIX.md v3.0 · DATABASE_OBJECT_REGISTRY.md v1.0

**File to be authored:** `<TIMESTAMP>_core_schema.sql`  
**File strategy:** Single file — all content in one transaction  
**Table count:** 50 tables across 14 batches  
**RLS policies:** 71 across 8 groups  
**Triggers:** 22 across 3 passes  
**Helper functions:** 9 in strict dependency order  
**Indexes:** 7 named + 1 partial unique index (`uq_lifebook_entities_active` on `lifebook_entities`)  
**Deferred FKs:** 3 (inserted inline at their dependency point, not deferred to file end)

---

## Pre-Authoring Confirmations Required

Before authoring any section of this file, confirm:

| # | Confirmation | Blocks |
|---|---|---|
| A | PERSON_ATTRIBUTE_CATALOGUE.md G2 normalization confirmed (four-field model: `evidence_status`, `dispute_status`, `precision_status`, `review_status` — all on PersonName; `review_status` independent on PersonNameDerivative, not inherited from parent) | Batch 14 DDL section |
| B | ClaimPredicate seed file (74 records) authored and reviewed against CLAIM_PREDICATE_CATALOGUE.md v0.2 | Batch 8 seed subsection + Pass C trigger |
| C | Single-file strategy confirmed | Entire file |

Do not begin authoring until all three are resolved.

---

## File Structure Overview

```
[FILE HEADER]
BEGIN;

  [PHASE 1 — TABLES]
    Batch  1: Jurisdiction (2 tables + seed)
    Batch  2: Users (1 table)
    Batch  3: Entity anchors (7 tables)
    Batch  4: LifeBook scoping (5 tables)
      ↳ [DEFERRED FK 3 INSERTION POINT — after approval_policies in Batch 5]
    Batch  5: Governance policy templates (5 tables + seed)
      ↳ [DEFERRED FK 3 INSERTION POINT — fk_permission_cache_approval_policy]
    Batch  6: Approval instances (1 table)
      ↳ [DEFERRED FK 2 INSERTION POINT]
    Batch  7: Authority (1 table)
    Batch  8: Reference catalogues (3 tables + 111 seed records)
    Batch  9: AI context infrastructure (2 tables + seed)
    Batch 10: Content tables (10 tables)
      ↳ [DEFERRED FK 1 INSERTION POINT]
    Batch 11: AI context manifests (2 tables)
    Batch 12: Cross-LifeBook (3 tables)
    Batch 13: Escalation and dispute (4 tables)
    Batch 14: Person attributes (4 tables) *** REQUIRES CONFIRMATION A ***

  [PHASE 3 — INDEXES]         7 indexes

  [PHASE 4 — HELPER FUNCTIONS] 9 functions (dependency order)
    ↳ [SECURITY DEFINER VERIFICATION CHECKPOINT]

  [PHASE 5 — TRIGGERS]
    Pass A: 12 triggers (no cross-table dependencies)
    Pass B:  9 triggers (cross-table dependencies)
    Pass C:  1 trigger  (after Batch 8 seed — numeric unit check)

  [PHASE 6 — RLS ENABLEMENT]  25 tables

  [PHASE 7 — RLS POLICIES]    71 policies (groups A→H + new policies 66–71)

  [PHASE 8 — GRANTS]

  [PHASE 9 — VALIDATION]      10 queries

COMMIT;

  [PHASE 10 — POST-COMMIT VERIFICATION]
```

Note: Phase 2 (Deferred FKs) has no standalone section — both deferred FKs are inserted inline within Phase 1 at their dependency points. See Batch 6 and Batch 10 below.

---

## Detailed Section Outline

---

### FILE HEADER

Contents of this section (no SQL):
- Migration number and name
- Timestamp placeholder
- Depends on: `20260724153745_types_and_vocabularies.sql` (applied) and `<TIMESTAMP>_predicate_governance_types.sql` (must be applied first)
- Authoring date and Discovery Partner authorization reference
- Reference to ADR-0003.md as the governing architecture decision record
- Table of deferred FK constraints declared in this file (both, with constraint names, tables, and dependency rationale)
- Warning: `trg_claim_numeric_unit_check` must not be created before Batch 8 seed is committed — noted here and enforced by position in Phase 5 Pass C
- Warning: `fn_generate_artifact_signed_url` is a stub — noted here; full implementation at storage integration milestone

---

### BEGIN

Transaction boundary opens here. Every statement below until COMMIT is atomic. Any failure rolls back the entire migration.

---

## PHASE 1 — TABLES

---

### BATCH 1 — JURISDICTION
*2 tables + seed | No upstream table dependencies*

#### `jurisdictions`
- Reference doc: OPERATIONAL_MODELS.md §4
- No RLS
- No triggers
- Not a permanent record

#### `jurisdiction_policy_versions`
- Reference doc: OPERATIONAL_MODELS.md §4
- No RLS
- No triggers
- Not a permanent record

#### BATCH 1 SEED — Jurisdiction records
- Minimum 6 records inserted immediately after table DDL
- Required before any `lifebooks` record can be created (NOT NULL FK on `lifebooks.jurisdiction_id`)
- Records: Canada/federal, Alberta, British Columbia, Ontario, Ukraine, international default
- Source: OPERATIONAL_MODELS.md §4

---

### BATCH 2 — USERS
*1 table | Depends on: auth.users (Supabase auth schema — external)*

#### `user_profiles`
- Reference doc: ANCHOR_MODELS.md
- FK target `auth.users(id)` is in Supabase auth schema, not this migration
- No RLS
- No triggers
- Not a permanent record

---

### BATCH 3 — ENTITY ANCHORS
*7 tables | Depends on: user_profiles*

#### `entities`
Entity supertype. No person attribute FKs here.

#### `persons`
Person subtype. No PersonName FKs at this table (those are in Batch 14).

#### `organizations`

#### `places`
Carries `cached_latitude`, `cached_longitude` — application cache fields, not authoritative geography (P11).

#### `vessels`

#### `communities`

#### `event_series`
EventSeries entity anchor — distinct from individual `events` records in Batch 10.

All Batch 3 tables: No RLS. No triggers. Not permanent records.

---

### BATCH 4 — LIFEBOOK SCOPING
*5 tables | Depends on: jurisdictions (NOT NULL FK), user_profiles, entities*

**Internal ordering within Batch 4:** `lifebooks` → `lifebook_memberships` → `user_person_links` → `lifebook_entities` → `lifebook_person_contexts`. Each depends on the prior.

#### `lifebooks`
`jurisdiction_id` is NOT NULL per P13. Seed in Batch 1 must be committed before any lifebooks row can be inserted. No RLS. No triggers. Not a permanent record.

#### `lifebook_memberships`
Central to all RLS policy evaluation — `fn_lb_membership_role` reads this table under SECURITY DEFINER. **RLS ENABLED** (25-table list). No triggers. Not a permanent record (memberships change as stewards manage access).

#### `user_person_links`
Optional link establishing subject status. Read by `fn_is_subject_of` under SECURITY DEFINER. No RLS (read via helper function only). No triggers. Not a permanent record.

#### `lifebook_entities`
Many-to-many between LifeBook and Entity. `visibility_status` (5 values: `visible`, `hidden`, `restricted`, `pending_confirmation`, `anonymized`) creates per-row access differences. **RLS ENABLED** (25-table list). **Partial unique index:** `CREATE UNIQUE INDEX uq_lifebook_entities_active ON lifebook_entities(lifebook_id, entity_id) WHERE removed_at IS NULL` — do NOT use a table-level UNIQUE constraint; the partial index permits re-adding a soft-deleted entity. Trigger protection: `trg_lifebook_person_context_completeness` — **CONSTRAINT TRIGGER DEFERRABLE INITIALLY DEFERRED** (Pass B; fires at COMMIT, not immediately after INSERT). Hard DELETE denied by RLS policy 59; use `removed_at` for soft delete. Not a permanent record.

**Fields (13 total):** `id` (UUID PK), `lifebook_id` (FK NOT NULL → lifebooks), `entity_id` (FK NOT NULL → entities), `entity_type` (enum NOT NULL, denormalized), `participation_role` (enum NOT NULL), `relationship_description` (TEXT NULL), `is_focal_entity` (BOOLEAN NOT NULL DEFAULT FALSE), `visibility_status` (enum NOT NULL), `added_by_id` (FK NOT NULL → user_profiles), `added_at` (TIMESTAMPTZ NOT NULL DEFAULT now()), `removed_at` (TIMESTAMPTZ NULL), `removed_by_id` (FK NULL → user_profiles), `removal_reason` (TEXT NULL), `steward_notes` (TEXT NULL).

#### `lifebook_person_contexts`
Person-specific overlay on LifeBookEntity (one-to-one). `lifebook_entity_id` is UNIQUE. Contains authority context, contribution lifecycle, terms acceptance, cross-LifeBook consent (subject-sovereign), and cached permission state. **RLS ENABLED** (25-table list). No triggers. Hard DELETE denied by RLS policy 65. Not a permanent record.

**Fields (13 total):** `id` (UUID PK), `lifebook_entity_id` (FK NOT NULL UNIQUE → lifebook_entities), `entity_id` (FK NOT NULL → entities; redundant for joins; must equal parent entity_id), `authority_context` (enum NOT NULL), `contribution_status` (enum NOT NULL), `has_accepted_terms` (BOOLEAN NOT NULL DEFAULT FALSE), `terms_accepted_at` (TIMESTAMPTZ NULL), `cross_lifebook_linkage_authorized` (BOOLEAN NOT NULL DEFAULT FALSE), `cross_lifebook_linkage_authorized_at` (TIMESTAMPTZ NULL), `cross_lifebook_linkage_scope` (JSONB NULL), `cached_permission_summary` (JSONB NULL — NOT authoritative), `permission_cache_policy_version_id` (UUID NULL — **no FK constraint here**; Deferred FK 3 added after Batch 5 approval_policies), `permission_cache_computed_at` (TIMESTAMPTZ NULL).

**⚠ Deferred FK 3 insertion point is AFTER Batch 5 `approval_policies` DDL — not here. The column exists as UUID NULL at creation time. The FK constraint is added in Batch 5.**

---

### BATCH 5 — GOVERNANCE POLICY TEMPLATES
*5 tables + seed | Depends on: display_contexts (Migration 0002 seed — must verify present)*

#### `escalation_policies`
No RLS. No triggers. Not a permanent record.

#### BATCH 5 SEED — EscalationPolicy representative records
Source: OPERATIONAL_MODELS.md §2. ≥1 record.

#### `approval_policies`
Includes `cultural_governance_required BOOLEAN NOT NULL DEFAULT FALSE`. No RLS. No triggers. Not a permanent record.

#### BATCH 5 SEED — ApprovalPolicy representative records
Source: GOVERNANCE_MODELS.md §4.4. ≥1 record.

#### `conflict_resolution_policies`
No RLS. No triggers. Not a permanent record.

#### BATCH 5 SEED — ConflictResolutionPolicy representative records
Source: GOVERNANCE_MODELS.md §5.5. ≥1 record.

#### `display_policies`
**Declared WITHOUT `approval_record_id` FK** — that FK references `approval_records` (Batch 6) which does not exist yet. The column exists; the FK constraint is added immediately after Batch 6.
**RLS ENABLED.** Trigger protection: `trg_display_policies_lifecycle` (Pass A), `trg_display_policies_delete_guard` (Pass A). Not a permanent record (draft policies may be deleted; non-draft are permanent-in-practice).

#### `display_policy_rules`
Depends on `display_policies` and `display_contexts.code` (FK). `display_contexts` must have its 9 seed records present from Migration 0002 before this table's FK constraint can be satisfied.
**RLS ENABLED.** Trigger protection: `trg_display_policy_rules_update_guard` (Pass B), `trg_display_policy_rules_delete_guard` (Pass B). Not a permanent record.

---

### ▶ DEFERRED FK 3 INSERTION POINT
*Placed immediately after `approval_policies` DDL within Batch 5, before `conflict_resolution_policies`*

**Constraint name:** `fk_permission_cache_approval_policy`  
**Table:** `lifebook_person_contexts`  
**Column:** `permission_cache_policy_version_id`  
**References:** `approval_policies(id)`  
**Type:** Nullable FK — added via `ALTER TABLE`  
**Rationale:** `lifebook_person_contexts` (Batch 4) was created before `approval_policies` (Batch 5); the column existed as UUID NULL but the FK constraint could not be declared inline.

File note: Mark this location clearly as "DEFERRED FK 3 — lifebook_person_contexts.permission_cache_policy_version_id → approval_policies(id)".

---

### BATCH 6 — APPROVAL INSTANCES
*1 table | Depends on: approval_policies*

#### `approval_records`
**RLS ENABLED.** Trigger protection: `trg_approval_records_immutable` (Pass A). **PERMANENT RECORD** — DELETE denied (policy 22), UPDATE denied (policy 49 + trigger).

---

### ▶ DEFERRED FK 2 INSERTION POINT
*Placed immediately after `approval_records` DDL, before Batch 7*

**Constraint name:** `fk_display_policy_approval_record`  
**Table:** `display_policies`  
**Column:** `approval_record_id`  
**References:** `approval_records(id)`  
**Type:** Nullable FK — added via `ALTER TABLE`  
**Rationale:** `display_policies` (Batch 5) was created before `approval_records` (Batch 6); the column existed but the FK constraint could not be declared inline.

File note: Mark this location clearly as "DEFERRED FK 2 — display_policies.approval_record_id → approval_records(id)".

---

### BATCH 7 — AUTHORITY
*1 table | Depends on: persons, lifebooks, user_profiles, approval_policies*

#### `authority_assignments`
**Declared WITHOUT `basis_claim_id` FK** — that FK references `claims` (Batch 10) which does not exist yet. The column exists; the FK constraint is added immediately after Batch 10 `claims` DDL.
**RLS ENABLED.** Trigger protection: `trg_authority_assignment_revocation_guard` (Pass A). **PERMANENT RECORD** — DELETE denied (policy 25). Revocation sets `effective_until`; no deletion.

---

### BATCH 8 — REFERENCE CATALOGUES
*2 tables + 101 seed records | No upstream table dependencies beyond enums*
*Note: `claim_value_units` is a Migration 0001 prerequisite — created and seeded there; not recreated here.*

#### `claim_predicates`
Depends on: `relationship_interaction_type` enum (Migration 0002 — must verify present).
No RLS. No triggers. Not a permanent record (system-managed catalogue).

#### BATCH 8 SEED — ClaimPredicate records (74 records)
**PRE-AUTHORING CONFIRMATION B REQUIRED** — seed file must be authored and reviewed before this section is written.
Source: CLAIM_PREDICATE_CATALOGUE.md v0.2.
**CRITICAL ORDERING:** These 74 records must be committed within the transaction before `trg_claim_numeric_unit_check` is created in Phase 5 Pass C. The trigger reads this table at INSERT/UPDATE time on `claims`.

#### `claim_value_units` — PREREQUISITE FROM MIGRATION 0001
**This table is NOT created or seeded in Migration 0003.**
`claim_value_units` (11 records) was created and seeded in Migration 0001 (`20260724153745_types_and_vocabularies.sql`). Migration 0003 consumes it as an existing prerequisite vocabulary table. The FK `claims.value_unit_code → claim_value_units(unit_code)` and the `trg_claim_numeric_unit_check` trigger both depend on it being present, which it is.
Schema owner: Migration 0001. Seed owner: Migration 0001. Count owner: Migration 0001.

#### `relationship_types`
No RLS. No triggers. Not a permanent record.

#### BATCH 8 SEED — RelationshipType records (27 records)
Source: RELATIONSHIP_TYPE_CATALOGUE.md.

---

### BATCH 9 — AI CONTEXT INFRASTRUCTURE
*2 tables + seed | No upstream table dependencies*

#### `agent_registry`
No RLS. No triggers. Not a permanent record (updated as agents are versioned).

#### BATCH 9 SEED — AgentRegistry records
Source: AI_CONTEXT_BROKER.md §3.2. At minimum: initial extraction agent record.
Note: `memory_atmosphere_policy_evaluator` deferred pending Memory Atmosphere Engine implementation (ADR-0002).

#### `context_profiles`
No RLS. No triggers. Not a permanent record.

#### BATCH 9 SEED — ContextProfile records
Source: AI_CONTEXT_BROKER.md §2. At minimum: `respectful_generation`, `identity_resolution`.

---

### BATCH 10 — CONTENT TABLES
*10 tables | Internal ordering constraint: claims before events (inline FK dependency)*

#### `sources`
Depends on: lifebooks, user_profiles.
**RLS ENABLED.** Trigger protection: `trg_source_dna_classification` (Pass A), `trg_source_type_immutable` (Pass A), `trg_source_lifebook_immutable` (Pass A). **PERMANENT RECORD** — DELETE denied (policy 18).

#### `claims`
Depends on: entities, lifebooks, claim_predicates, claim_value_units, user_profiles, display_policies.
**Inline self-FK declared at table creation:** `superseded_by_claim_id UUID NULL REFERENCES claims(id)` — this is NOT a deferred FK.
**RLS ENABLED.** Trigger protection: `trg_claim_value_not_null` (Pass A), `trg_claim_ai_provenance` (Pass A), `trg_claim_content_immutable` (Pass A), `trg_claim_supersession_integrity` (Pass B), `trg_claim_dispute_requires_contest` (Pass B), `trg_claim_numeric_unit_check` (Pass C). **PERMANENT RECORD** — DELETE denied (policy 16).

---

### ▶ DEFERRED FK 1 INSERTION POINT
*Placed immediately after `claims` DDL, before `claim_evidence`*

**Constraint name:** `fk_authority_basis_claim`  
**Table:** `authority_assignments`  
**Column:** `basis_claim_id`  
**References:** `claims(id)`  
**Type:** Nullable FK — added via `ALTER TABLE`  
**Rationale:** `authority_assignments` (Batch 7) was created before `claims` (Batch 10); governance infrastructure precedes content. The column existed but the FK constraint could not be declared inline.

File note: Mark this location clearly as "DEFERRED FK 1 — authority_assignments.basis_claim_id → claims(id)".

---

#### `claim_evidence`
Depends on: claims, sources.
**RLS ENABLED.** No triggers. **PERMANENT RECORD** — DELETE denied (implicit via parent claim governance; enforce via RLS).

#### `relationships`
Depends on: entities, lifebooks, relationship_types, user_profiles.
**Inline self-FK declared at table creation:** `superseded_by_relationship_id UUID NULL REFERENCES relationships(id)` — this is NOT a deferred FK.
**RLS ENABLED.** Trigger protection: `trg_relationship_content_immutable` (Pass A), `trg_relationship_supersession_integrity` (Pass B), `trg_relationship_dispute_requires_contest` (Pass B). **PERMANENT RECORD** — DELETE denied (policy 20).

#### `narratives`
Depends on: lifebooks, user_profiles.
**RLS ENABLED.** No triggers. **PERMANENT RECORD** — DELETE denied (policy 17).

#### `narrative_entities`
Depends on: narratives, entities.
**RLS ENABLED.** No triggers. **PERMANENT RECORD** — DELETE denied (implicit via parent narrative governance).

#### `events`
Depends on: lifebooks, user_profiles, claims (inline FK).
**Inline FK declared at table creation:** `source_claim_id UUID NULL REFERENCES claims(id)` — records the generating Claim when an Event is created from a Claim (DP Decision 2026-07-25); NULL for manually authored Events.
**RLS ENABLED.** Trigger protection: `trg_event_provenance_immutable` (Pass A). **PERMANENT RECORD** — DELETE denied (policy 21).

#### `event_participants`
Depends on: events, entities.
**RLS ENABLED.** No triggers. **PERMANENT RECORD** — DELETE denied.

#### `artifacts`
Depends on: lifebooks, sources, user_profiles, display_policies.
**Column restriction note:** `object_key` in the referenced `file_storage_references` record must never be exposed to non-admin roles. The column-level REVOKE for `file_storage_references.object_key` is deferred to the storage integration migration where `file_storage_references` is formally introduced and governed — it is not part of Migration 0003.
**RLS ENABLED.** No triggers. **PERMANENT RECORD** — DELETE denied (policy 19).

#### `artifact_source_links`
Depends on: artifacts, sources.
**RLS ENABLED.** No triggers. **PERMANENT RECORD** — DELETE denied.

---

### BATCH 11 — AI CONTEXT MANIFESTS
*2 tables | Depends on: claims, sources, agent_registry, context_profiles*

#### `context_manifests`
**RLS ENABLED.** No triggers. **PERMANENT RECORD** — DELETE denied (policy 23).

#### `source_derivatives`
Depends on: sources, context_manifests.
**RLS ENABLED.** Trigger protection: `trg_source_derivative_invalidation_cascade` (Pass B). Not a permanent record (derivatives may be invalidated and regenerated).

---

### BATCH 12 — CROSS-LIFEBOOK
*3 tables | Depends on: lifebooks, persons, approval_records*

#### `merge_records`
`approval_record_id` FK is NOT NULL — references `approval_records` (G3 blocker resolved). No RLS. No triggers. Not a permanent record.

#### `cross_lifebook_authorizations`
Three ApprovalRecord FKs: `approval_a_id` (NOT NULL), `approval_b_id` (NOT NULL), `person_authorization_id` (nullable). No RLS. No triggers. Not a permanent record.

#### `lifebook_source_access`
Read by `fn_has_source_access_grant` under SECURITY DEFINER. No RLS. No triggers. Not a permanent record.

---

### BATCH 13 — ESCALATION AND DISPUTE
*4 tables | Depends on: contest_records, escalation_policies, approval_records, escalation_records*

#### `contest_records`
Depends on: claims, authority_assignments, lifebooks, user_person_links.
**RLS ENABLED.** Trigger protection: `trg_contest_record_standing_validation` (Pass B). **PERMANENT RECORD** — DELETE denied (policy 26).

#### `escalation_records`
Field name: `approval_record_id` (renamed from `approval_workflow_id` — G3 blocker resolved). Depends on: escalation_policies, approval_records, contest_records. No RLS. No triggers. Not a permanent record.

#### `escalation_notifications`
Depends on: escalation_records, user_profiles. No RLS. No triggers. Not a permanent record.

#### `access_policy_changed_events`
**RLS ENABLED.** No triggers. **PERMANENT RECORD** — DELETE denied (policy 24).

---

### BATCH 14 — PERSON ATTRIBUTES
*4 tables | Depends on: persons*

**⚠ PRE-AUTHORING CONFIRMATION A REQUIRED** before authoring any table in this batch. PERSON_ATTRIBUTE_CATALOGUE.md must confirm four-field normalization: `evidence_status`, `dispute_status`, `precision_status`, `review_status` on PersonName; `review_status` independent on PersonNameDerivative (not inherited from parent) — replacing former combined `confidence` enum (G2 blocker resolution).

#### `person_names`
13 `usage_type` values (preferred, legal, birth, maiden, alias, nickname, etc.).
Four separate status fields (replacing former combined `confidence` enum): `evidence_status`, `dispute_status`, `precision_status`, `review_status`. On `person_name_derivatives`, `review_status` is independent — not inherited from the parent PersonName record.
**RLS ENABLED.** No triggers listed (content immutability enforced by application + supersession pattern). **PERMANENT RECORD** — DELETE denied (policy 27).

#### `person_name_derivatives`
Depends on: person_names.
**RLS ENABLED.** No triggers. **PERMANENT RECORD** — DELETE denied.

#### `person_pronouns`
Subject authority overrides steward in case of conflict (application-enforced).
**RLS ENABLED.** No triggers. **PERMANENT RECORD** — DELETE denied (policy 28).

#### `person_gender_descriptors`
Same authority model as person_pronouns.
**RLS ENABLED.** No triggers. **PERMANENT RECORD** — DELETE denied (policy 29).

---

## PHASE 3 — INDEXES
*7 named indexes + 1 partial unique index | Placed after all tables, before Phase 4 helper functions*

Indexes are created before helper functions because the STABLE helper functions depend on efficient lookups for acceptable RLS evaluation performance.

**Critical: `lifebook_entities` partial unique index** — The uniqueness constraint on `lifebook_entities(lifebook_id, entity_id)` must be implemented as a **partial index** (`WHERE removed_at IS NULL`), not a table-level UNIQUE constraint. A table-level UNIQUE would permanently block re-adding a soft-deleted entity. Create this index in Phase 3 alongside the named indexes below.

| # | Index Name | Table | Columns |
|---|---|---|---|
| * | `uq_lifebook_entities_active` | `lifebook_entities` | `(lifebook_id, entity_id) WHERE removed_at IS NULL` — **partial unique index; must not be a table-level UNIQUE constraint** |
| 1 | `idx_lifebook_memberships_user_lifebook` | `lifebook_memberships` | `(user_id, lifebook_id)` |
| 2 | `idx_authority_assignments_role_entity` | `authority_assignments` | `(authority_role, entity_id)` |
| 3 | `idx_authority_assignments_expiry` | `authority_assignments` | `(effective_until) WHERE effective_until IS NOT NULL` — partial index |
| 4 | `idx_claims_lifebook_review_access` | `claims` | `(lifebook_id, review_status, access_classification)` |
| 5 | `idx_display_policy_rules_policy_context` | `display_policy_rules` | `(display_policy_id, display_context_code)` |
| 6 | `idx_user_person_links_user_entity` | `user_person_links` | `(user_id, entity_id)` |
| 7 | `idx_contest_records_contested_record` | `contest_records` | `(contested_record_table, contested_record_id)` |

---

## PHASE 4 — HELPER FUNCTIONS
*9 functions | Strict dependency order — do not reorder*

All SECURITY DEFINER functions must carry `SET search_path = 'public', pg_temp` and be owned by the `governance_functions` role. REVOKE EXECUTE FROM PUBLIC is issued per function before any per-role grants (grants are issued in Phase 8).

| Order | Function | SECURITY DEFINER | Tables Read |
|---|---|---|---|
| 1 | `fn_user_is_agent` | No | None |
| 2 | `fn_lb_membership_role` | Yes | `lifebook_memberships` |
| 3 | `fn_is_subject_of` | Yes | `user_person_links` |
| 4 | `fn_has_active_authority` | Yes | `authority_assignments` |
| 5 | `fn_display_policy_allows` | Yes | `display_policies`, `display_policy_rules` |
| 6 | `fn_has_source_access_grant` | Yes | `lifebook_source_access`, `cross_lifebook_authorizations` |
| 7 | `fn_has_community_authorization` | Yes | `approval_records`, `approval_policies` |
| 8 | `fn_has_contest_standing` | Yes | `user_person_links`, `authority_assignments`, `lifebook_memberships` + whitelisted contested table |
| 9 | `fn_generate_artifact_signed_url` | Yes | **STUB — body returns NULL immediately; must NOT reference `file_storage_references` in stub form** (table may not exist at migration time); SECURITY DEFINER frame, search_path, ownership, and EXECUTE revocation must all be correct at stub creation time |

### ▶ SECURITY DEFINER VERIFICATION CHECKPOINT
*Placed after all 9 functions, before Phase 5*

File note at this location: confirm before proceeding that for functions 2–9:
- [ ] `prosecdef = TRUE` — SECURITY DEFINER is set
- [ ] `search_path = 'public', pg_temp` — appears in `proconfig`
- [ ] Function is owned by `governance_functions` role
- [ ] No function accepts a `user_id` or `p_user_id` parameter (all derive user from `current_user` internally)

Also confirm recursion constraints are satisfied by the RLS policies to be written in Phase 7:
- [ ] `authority_assignments` RLS will NOT call `fn_has_active_authority`
- [ ] `display_policies` RLS will NOT call `fn_display_policy_allows`
- [ ] `display_policy_rules` RLS will NOT call `fn_display_policy_allows`
- [ ] `contest_records` SELECT RLS will NOT call `fn_has_contest_standing`

---

## PHASE 5 — TRIGGERS
*22 triggers across 3 passes*

### Pass A — No Cross-Table Dependencies
*12 triggers | Created before Pass B and Pass C*

| # | Trigger | Table | Timing | Event |
|---|---|---|---|---|
| 1 | `trg_claim_value_not_null` | `claims` | BEFORE | INSERT |
| 2 | `trg_claim_ai_provenance` | `claims` | BEFORE | INSERT, UPDATE |
| 3 | `trg_claim_content_immutable` | `claims` | BEFORE | UPDATE |
| 4 | `trg_relationship_content_immutable` | `relationships` | BEFORE | UPDATE |
| 5 | `trg_source_dna_classification` | `sources` | BEFORE | INSERT |
| 6 | `trg_source_type_immutable` | `sources` | BEFORE | UPDATE |
| 7 | `trg_source_lifebook_immutable` | `sources` | BEFORE | UPDATE |
| 8 | `trg_event_provenance_immutable` | `events` | BEFORE | UPDATE |
| 9 | `trg_approval_records_immutable` | `approval_records` | BEFORE | UPDATE |
| 10 | `trg_authority_assignment_revocation_guard` | `authority_assignments` | BEFORE | UPDATE |
| 11 | `trg_display_policies_lifecycle` | `display_policies` | BEFORE | UPDATE |
| 12 | `trg_display_policies_delete_guard` | `display_policies` | BEFORE | DELETE |

### Pass B — Cross-Table Dependencies
*9 triggers | Requires all Batch 14 tables to exist*

| # | Trigger | Table | Timing | Event | Cross-Table Dependency |
|---|---|---|---|---|---|
| 13 | `trg_claim_supersession_integrity` | `claims` | BEFORE | UPDATE | `claims` self-join |
| 14 | `trg_relationship_supersession_integrity` | `relationships` | BEFORE | UPDATE | `relationships` self-join |
| 15 | `trg_claim_dispute_requires_contest` | `claims` | BEFORE | UPDATE | `contest_records` |
| 16 | `trg_relationship_dispute_requires_contest` | `relationships` | BEFORE | UPDATE | `contest_records` |
| 17 | `trg_display_policy_rules_update_guard` | `display_policy_rules` | BEFORE | UPDATE | `display_policies` |
| 18 | `trg_display_policy_rules_delete_guard` | `display_policy_rules` | BEFORE | DELETE | `display_policies` |
| 19 | `trg_contest_record_standing_validation` | `contest_records` | BEFORE | INSERT | `authority_assignments`, `user_person_links` |
| 20 | `trg_lifebook_person_context_completeness` | `lifebook_entities` | **CONSTRAINT TRIGGER** AFTER DEFERRABLE INITIALLY DEFERRED | INSERT | `lifebook_person_contexts` |
| 22 | `trg_source_derivative_invalidation_cascade` | `source_derivatives` | AFTER | UPDATE | `access_policy_changed_events`, `context_manifests` |

### Pass C — After Batch 8 Seed
*1 trigger | Must be last trigger created — Batch 8 ClaimPredicate seed must be committed; claim_value_units is a Migration 0001 prerequisite already present*

| # | Trigger | Table | Timing | Event | Seed Dependency |
|---|---|---|---|---|---|
| 21 | `trg_claim_numeric_unit_check` | `claims` | BEFORE | INSERT, UPDATE | `claim_predicates` (74 records, this migration, committed in Batch 8); `claim_value_units` (11 records, Migration 0001 prerequisite — already present) |

File note at Pass C location: "TRIGGER PASS C — trg_claim_numeric_unit_check — created after Batch 8 seed. Do not move earlier in the file."

---

## PHASE 6 — RLS ENABLEMENT
*25 tables | Placed after Phase 5 triggers, before any seed data that targets governed tables*

Enable RLS on all 25 governed tables. The order of ALTER TABLE statements within this section does not affect correctness; all 25 must be present.

```
Tables to enable (in batch order for readability):
  lifebook_memberships        (Batch 4)
  lifebook_entities           (Batch 4)
  lifebook_person_contexts    (Batch 4)
  display_policies            (Batch 5)
  display_policy_rules        (Batch 5)
  approval_records            (Batch 6)
  authority_assignments       (Batch 7)
  sources                     (Batch 10)
  claims                      (Batch 10)
  claim_evidence              (Batch 10)
  relationships               (Batch 10)
  narratives                  (Batch 10)
  narrative_entities          (Batch 10)
  events                      (Batch 10)
  event_participants          (Batch 10)
  artifacts                   (Batch 10)
  artifact_source_links       (Batch 10)
  context_manifests           (Batch 11)
  source_derivatives          (Batch 11)
  contest_records             (Batch 13)
  access_policy_changed_events (Batch 13)
  person_names                (Batch 14)
  person_name_derivatives     (Batch 14)
  person_pronouns             (Batch 14)
  person_gender_descriptors   (Batch 14)
```

Total: 25. Verify with Validation Query 1 in Phase 9.

---

## PHASE 7 — RLS POLICIES
*71 policies across 8 groups | Ordered by helper function dependency*

### Group A — DELETE Denied
*16 policies | Policies 16–29, 59, 65 | No function dependencies — create first*

All 16 use `USING (FALSE)`. Verify each is exactly the literal `FALSE` — not a function call, not an expression.

| Policy # | Name | Table |
|---|---|---|
| 16 | `pol_claims_delete_denied` | `claims` |
| 17 | `pol_narratives_delete_denied` | `narratives` |
| 18 | `pol_sources_delete_denied` | `sources` |
| 19 | `pol_artifacts_delete_denied` | `artifacts` |
| 20 | `pol_relationships_delete_denied` | `relationships` |
| 21 | `pol_events_delete_denied` | `events` |
| 22 | `pol_approval_records_delete_denied` | `approval_records` |
| 23 | `pol_context_manifests_delete_denied` | `context_manifests` |
| 24 | `pol_access_policy_events_delete_denied` | `access_policy_changed_events` |
| 25 | `pol_authority_assignments_delete_denied` | `authority_assignments` |
| 26 | `pol_contest_records_delete_denied` | `contest_records` |
| 27 | `pol_person_names_delete_denied` | `person_names` |
| 28 | `pol_person_pronouns_delete_denied` | `person_pronouns` |
| 29 | `pol_person_gender_delete_denied` | `person_gender_descriptors` |
| 59 | `pol_lifebook_entities_delete_denied` | `lifebook_entities` |
| 65 | `pol_lifebook_person_contexts_delete_denied` | `lifebook_person_contexts` |

### Group B — UPDATE Immutability
*1 policy | Policy 49 | No function dependencies*

| Policy # | Name | Table | USING |
|---|---|---|---|
| 49 | `pol_approval_records_update_denied` | `approval_records` | `FALSE` |

### Group C — LifeBook-Scoped SELECT
*19 policies | Policies 1–15, 66–68, 70 | Requires: `fn_lb_membership_role`, `fn_is_subject_of`, `fn_has_source_access_grant`, `fn_user_is_agent`*

**Policies 11–14 join path:** These use a multi-hop correlated subquery through `persons → entities → lifebook_entities → lifebook_id`. The join path is specified in VOCABULARY_RLS_MATRIX.md §2.1. Do not simplify or abbreviate — the full EXISTS subquery is required.

| Policy # | Name | Table |
|---|---|---|
| 1 | `pol_claims_select_lifebook` | `claims` |
| 2 | `pol_relationships_select_lifebook` | `relationships` |
| 3 | `pol_narratives_select_lifebook` | `narratives` |
| 4 | `pol_narrative_entities_select_lifebook` | `narrative_entities` |
| 5 | `pol_sources_select_lifebook` | `sources` |
| 6 | `pol_artifacts_select_lifebook` | `artifacts` |
| 7 | `pol_events_select_lifebook` | `events` |
| 8 | `pol_event_participants_select_lifebook` | `event_participants` |
| 9 | `pol_claim_evidence_select_lifebook` | `claim_evidence` |
| 10 | `pol_artifact_source_links_select_lifebook` | `artifact_source_links` |
| 11 | `pol_person_names_select_lifebook` | `person_names` |
| 12 | `pol_person_pronouns_select_lifebook` | `person_pronouns` |
| 13 | `pol_person_gender_select_lifebook` | `person_gender_descriptors` |
| 14 | `pol_person_name_derivatives_select` | `person_name_derivatives` |
| 15 | `pol_authority_assignments_select` | `authority_assignments` |
| 66 | `pol_approval_records_select` | `approval_records` |
| 67 | `pol_display_policies_select` | `display_policies` |
| 68 | `pol_display_policy_rules_select` | `display_policy_rules` |
| 70 | `pol_source_derivatives_select_lifebook` | `source_derivatives` |

### Group D — INSERT and AI Restrictions
*12 policies | Policies 30–36, 41, 47, 51, 69, 71 | Requires: `fn_user_is_agent`, `fn_lb_membership_role`, `fn_has_active_authority`, `fn_has_community_authorization`, `fn_has_contest_standing`*

**Policies 30–32 — USING and WITH CHECK both required:** See VOCABULARY_RLS_MATRIX.md §2.3 for the explicit USING and WITH CHECK expressions. These are not simple deny-all; the USING clause must permit access to the row, and the WITH CHECK clause blocks the prohibited new state. Using only USING or only WITH CHECK is incorrect for these three policies.

| Policy # | Name | Table | Operation |
|---|---|---|---|
| 30 | `pol_claims_ai_promotion_denied` | `claims` | UPDATE |
| 31 | `pol_claims_ai_dispute_denied` | `claims` | UPDATE |
| 32 | `pol_narratives_ai_promotion_denied` | `narratives` | UPDATE |
| 33 | `pol_events_insert_agent_denied` | `events` | INSERT |
| 34 | `pol_approval_records_insert_agent_denied` | `approval_records` | INSERT |
| 35 | `pol_sources_insert_agent_denied` | `sources` | INSERT |
| 36 | `pol_person_names_insert_agent_denied` | `person_names` | INSERT |
| 41 | `pol_narratives_community_account_gate` | `narratives` | INSERT |
| 47 | `pol_display_policies_insert_authorized` | `display_policies` | INSERT |
| 51 | `pol_contest_records_insert_standing` | `contest_records` | INSERT |
| 69 | `pol_person_name_derivatives_insert` | `person_name_derivatives` | INSERT |
| 71 | `pol_source_derivatives_insert_system` | `source_derivatives` | INSERT |

### Group E — Cultural and Classification Filtering
*7 policies | Policies 37–44 | Requires: `fn_user_is_agent`, `fn_has_active_authority`*

**Review gate: policies 37–40** must use AND (not OR) in the `access_classification = 'culturally_governed'` filter. An OR bug would grant agent access to all records. These four policies are the absolute AI cultural exclusion boundary (Architectural Invariant 7).

| Policy # | Name | Table | Operation |
|---|---|---|---|
| 37 | `pol_claims_cultural_ai_excluded` | `claims` | SELECT |
| 38 | `pol_narratives_cultural_ai_excluded` | `narratives` | SELECT |
| 39 | `pol_artifacts_cultural_ai_excluded` | `artifacts` | SELECT |
| 40 | `pol_sources_cultural_ai_excluded` | `sources` | SELECT |
| 41 | *(listed in Group D)* | — | — |
| 42 | `pol_artifacts_restricted_steward_only` | `artifacts` | SELECT |
| 43 | `pol_artifacts_culturally_governed_authority` | `artifacts` | SELECT |
| 44 | `pol_sources_restricted_steward_only` | `sources` | SELECT |

### Group F — DisplayPolicy Lifecycle
*3 policies | Policies 45–48 | Requires: `fn_has_active_authority`*

| Policy # | Name | Table | Operation |
|---|---|---|---|
| 45 | `pol_display_policies_delete_non_draft_denied` | `display_policies` | DELETE |
| 46 | `pol_display_policies_update_frozen` | `display_policies` | UPDATE |
| 47 | *(listed in Group D)* | — | — |
| 48 | `pol_display_policy_rules_non_draft_denied` | `display_policy_rules` | DELETE |

### Group G — Governance
*3 policies | Policies 50, 52–53 | Requires: `fn_lb_membership_role`, `fn_has_contest_standing`*

| Policy # | Name | Table | Operation |
|---|---|---|---|
| 50 | `pol_authority_assignments_update_revocation_only` | `authority_assignments` | UPDATE |
| 52 | `pol_contest_records_select_parties` | `contest_records` | SELECT |
| 53 | `pol_person_name_derivatives_agent_restricted` | `person_name_derivatives` | SELECT |

### Group H — LifeBook Entity Access
*10 policies | Policies 54–58, 60–64 (delete-denied 59, 65 are in Group A) | Requires: `fn_lb_membership_role`, `fn_is_subject_of`, `fn_user_is_agent`*

**Note on `lifebook_person_contexts` SELECT policies (60, 61):** These policies resolve `lifebook_id` via subquery `(SELECT lifebook_id FROM lifebook_entities WHERE id = lifebook_entity_id)`. The subquery is required because `lifebook_person_contexts` has no direct `lifebook_id` column.

**Note on `lifebook_person_contexts` UPDATE policies (63, 64):** Two permissive UPDATE policies combine with OR. Policy 63 covers steward (governance fields); policy 64 covers subject (consent fields). Field-level split between steward and subject domains is enforced at the application layer — the database cannot restrict specific columns within an UPDATE RLS policy.

| Policy # | Name | Table | Operation |
|---|---|---|---|
| 54 | `pol_lifebook_entities_select_steward` | `lifebook_entities` | SELECT |
| 55 | `pol_lifebook_entities_select_member_visible` | `lifebook_entities` | SELECT |
| 56 | `pol_lifebook_entities_select_subject_own` | `lifebook_entities` | SELECT |
| 57 | `pol_lifebook_entities_insert_steward` | `lifebook_entities` | INSERT |
| 58 | `pol_lifebook_entities_update_steward` | `lifebook_entities` | UPDATE |
| 59 | *(listed in Group A)* | `lifebook_entities` | DELETE |
| 60 | `pol_lifebook_person_contexts_select_steward` | `lifebook_person_contexts` | SELECT |
| 61 | `pol_lifebook_person_contexts_select_subject` | `lifebook_person_contexts` | SELECT |
| 62 | `pol_lifebook_person_contexts_insert_steward` | `lifebook_person_contexts` | INSERT |
| 63 | `pol_lifebook_person_contexts_update_steward` | `lifebook_person_contexts` | UPDATE |
| 64 | `pol_lifebook_person_contexts_update_subject` | `lifebook_person_contexts` | UPDATE |
| 65 | *(listed in Group A)* | `lifebook_person_contexts` | DELETE |

**Total policy count after Phase 7: 71.** Verify with Validation Query (see Phase 9, item 11).

---

## PHASE 8 — GRANTS
*Placed after RLS is active | Minimum-privilege grants only*

### Step 8.1 — Revoke EXECUTE from PUBLIC
Issue REVOKE EXECUTE FROM PUBLIC for all 9 helper functions before any per-role grants. PostgreSQL grants EXECUTE to PUBLIC by default.

Functions to revoke: `fn_user_is_agent`, `fn_lb_membership_role`, `fn_is_subject_of`, `fn_has_active_authority`, `fn_display_policy_allows`, `fn_has_source_access_grant`, `fn_has_community_authorization`, `fn_has_contest_standing`, `fn_generate_artifact_signed_url`

### Step 8.2 — Per-Role EXECUTE Grants on Helper Functions

Per SECURITY_DEFINER_REVIEW.md §EXECUTE grants table:

| Function | Granted to |
|---|---|
| `fn_user_is_agent` | `authenticated`, `agent_service`, `system_service` |
| `fn_lb_membership_role` | `authenticated`, `agent_service`, `system_service` |
| `fn_is_subject_of` | `authenticated` |
| `fn_has_active_authority` | `authenticated`, `system_service` |
| `fn_display_policy_allows` | `authenticated`, `agent_service`, `system_service` |
| `fn_has_source_access_grant` | `authenticated` |
| `fn_has_community_authorization` | `authenticated`, `system_service` |
| `fn_has_contest_standing` | `authenticated` |
| `fn_generate_artifact_signed_url` | `authenticated` |

### Step 8.3 — Content Table Grants by Role

| Role | Grant |
|---|---|
| `authenticated` | SELECT, INSERT, UPDATE on content tables (RLS restricts actor scope within these operations) |
| `agent_service` | SELECT on `claims`, `narratives`, `sources`, `artifacts`, `events`; INSERT on `claims`, `narratives` |
| `system_service` | SELECT all tables; INSERT on `approval_records`, `context_manifests`, `source_derivatives`, `access_policy_changed_events`, `lifebook_person_contexts`; UPDATE on `lifebook_person_contexts` (cache fields: `cached_permission_summary`, `permission_cache_policy_version_id`, `permission_cache_computed_at`) |
| `admin` | SELECT all tables; no RLS bypass (admin is not a superuser) |

### Step 8.4 — Column Restriction on object_key (DEFERRED)

> **W11 resolved — DP Decision 2026-07-25:** `REVOKE SELECT ON file_storage_references.object_key` is not authored in this migration. `file_storage_references` is a storage integration concern and is not part of the LifeBook core schema. Column-level restrictions on storage metadata are deferred to the storage integration migration where `file_storage_references` is formally introduced and governed. Do not create placeholder tables. Do not use exception-swallowing compatibility logic.

---

## PHASE 9 — VALIDATION
*10 queries | Run after COMMIT within the same session before closing*

All 10 queries must pass. A failing query means the migration is incomplete or incorrect. Do not proceed to Phase 10 until all pass.

| # | What It Checks | Expected Result |
|---|---|---|
| 1 | RLS active on 25 tables | `SELECT tablename FROM pg_tables WHERE rowsecurity = TRUE` — 25 rows |
| 2 | Trigger count = 22 | `SELECT count(*) FROM information_schema.triggers WHERE trigger_schema = 'public'` — 22 |
| 3 | Helper function count = 9 | `SELECT count(*) FROM pg_proc WHERE proname LIKE 'fn_%'` — 9 |
| 4 | Fail-closed as unauthenticated | `SELECT count(*) FROM claims` — 0 rows or permission denied |
| 5 | Agent cultural exclusion | `SELECT count(*) FROM claims WHERE access_classification = 'culturally_governed'` as `agent_service` — 0 rows |
| 6 | Permanent record — DELETE denied | `DELETE FROM claims LIMIT 1` — RLS error |
| 7 | Content immutability | `UPDATE claims SET predicate_id = predicate_id WHERE id = <any_id>` — trigger error |
| 8 | DisplayPolicy rule guard | `INSERT INTO display_policy_rules VALUES (<active_policy_id>, ...)` — trigger error |
| 9 | All 3 deferred FKs present | `SELECT conname FROM pg_constraint WHERE conname IN ('fk_authority_basis_claim','fk_display_policy_approval_record','fk_permission_cache_approval_policy')` — 3 rows |
| 10 | Supersession self-reference guard | `UPDATE claims SET superseded_by_claim_id = id WHERE id = <any_id>` — trigger error |
| 11 | Policy count = 71 | `SELECT count(*) FROM pg_policies WHERE schemaname = 'public'` — 71 |

Note: Query 11 is an addition beyond the 10 defined in VOCABULARY_RLS_MATRIX.md §9 — include it.

---

## COMMIT

Transaction boundary closes here. If any validation query in Phase 9 fails, do not issue COMMIT. ROLLBACK and investigate.

---

## PHASE 10 — POST-COMMIT VERIFICATION AND COMPLETION STEPS
*Performed after COMMIT, outside the transaction*

These steps are operational, not SQL. They complete the migration lifecycle.

### Step 10.1 — Record Migration Hash
Record the migration file hash in `migration_log` per MIGRATION_PHILOSOPHY.md §7 format.

### Step 10.2 — Supabase Confirmation
Confirm Supabase reports the migration as applied cleanly — no errors, no warnings. Supabase migration status page or CLI output must show green.

### Step 10.3 — Git Commit
Commit the migration file per MIGRATION_PHILOSOPHY.md §7 format. Commit message must include:
- Migration number and timestamp
- Summary of table count, policy count, trigger count
- Reference to authorization: ADR-0003 and PRE_SQL_READINESS_REVIEW.md gate

### Step 10.4 — Documentation Update
Update `PRE_SQL_READINESS_REVIEW.md` gate status to: **MIGRATION 0003 COMPLETE**

### Step 10.5 — Deferred Items to Track
The following items were intentionally deferred and must be tracked as follow-on work:

| Item | Deferred To | Notes |
|---|---|---|
| `fn_generate_artifact_signed_url` full implementation | Storage integration milestone | Stub only in this migration; must not be used in production until full implementation and independent audit |
| `trg_source_derivative_invalidation_cascade` full cascade logic | Context Broker implementation | Stub covers the hook; full cascade specified in AI_CONTEXT_BROKER.md |
| `memory_atmosphere_policy_evaluator` agent record | Memory Atmosphere Engine implementation | ADR-0002; deferred pending implementation |
| Batch 14 person attribute DDL | If G2 confirmation was not resolved before authoring | If Batch 14 was deferred out of this migration, it becomes Migration 0004 |
| Indigenous/ceremonial name records | External community engagement | Governance requirement; not a schema gap |

---

## Navigation Quick Reference

| Need to find… | Go to… |
|---|---|
| Where Deferred FK 1 goes | After `claims` DDL in Batch 10 |
| Where Deferred FK 2 goes | After `approval_records` DDL in Batch 6 |
| Where Deferred FK 3 goes | After `approval_policies` DDL in Batch 5 |
| Where `trg_claim_numeric_unit_check` goes | Phase 5 Pass C — after all Batch 8 seed |
| Where `fn_generate_artifact_signed_url` stub goes | Phase 4, position 9 — last function |
| Where RLS is enabled | Phase 6 — after Phase 5 triggers, before Phase 7 policies |
| Where DELETE-denied policies go | Phase 7 Group A — first policies created |
| Where `object_key` grant revocation goes | Phase 8 Step 8.4 — after all other grants |
| Where to verify SECURITY DEFINER | Checkpoint section after Phase 4 |
| Where cultural AI exclusion policies go | Phase 7 Group E — policies 37–40 |
| Where to run validation queries | Phase 9 — after COMMIT |

---

*This document contains no SQL. It is a navigation and structural reference for the SQL author. All architectural decisions are fixed. The skeleton may not be used to introduce new objects, rename existing objects, or modify enforcement specifications.*
