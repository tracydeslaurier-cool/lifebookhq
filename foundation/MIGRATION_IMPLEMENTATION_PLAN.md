# Migration Implementation Plan
**Version:** 1.0  
**Status:** Approved — implementation planning complete; SQL authoring authorized  
**Date:** 2026-07-25  
**Produced by:** Discovery Partner + Claude (architecture closure session)  
**Input documents:**  
- MIGRATION_0003_PROPOSAL.md v0.2  
- VOCABULARY_RLS_MATRIX.md v3.0  
- GOVERNANCE_ENFORCEMENT_MODEL.md v0.2  
- SECURITY_DEFINER_REVIEW.md v1.0  
- ADR-0003.md  
- MIGRATION_PHILOSOPHY.md  

**Purpose:** Translate the approved architecture into an ordered implementation roadmap. This document contains no SQL, modifies no architecture, and introduces no new models.

---

## §1. Migration 0002 Plan

### 1.1 Purpose

Migration 0002 is a vocabulary migration. It creates the three enum types and the one reference table that are required by Migration 0003 but could not be included in Migration 0001 (which is applied and immutable). It also seeds the `display_contexts` table with the nine canonical display context records that govern all DisplayPolicy evaluation.

Migration 0002 must be fully applied and verified before Migration 0003 authoring begins. Migration 0003 references `display_contexts.code` as a TEXT FK; if the table or its seed records do not exist, Migration 0003 DDL and constraint authoring will fail.

### 1.2 Objects Created

| Object | Kind | Values / Structure |
|---|---|---|
| `relationship_interaction_type` | PostgreSQL enum | `proposes`, `supports`, `describes`, `none` |
| `display_policy_status` | PostgreSQL enum | `draft`, `active`, `superseded`, `withdrawn` |
| `display_policy_decision` | PostgreSQL enum | `allow`, `deny`, `conditional` |
| `display_contexts` | Reference table | `code TEXT PRIMARY KEY`, `label TEXT NOT NULL`, `description TEXT NOT NULL`, `sort_order INT NOT NULL`, `created_at TIMESTAMPTZ NOT NULL DEFAULT now()` |
| `display_contexts` seed | 9 INSERT records | `public_ui`, `family_ui`, `steward_ui`, `historical_record`, `ordinary_search`, `identity_resolution_search`, `default_export`, `steward_export`, `ai_generation` |

### 1.3 Dependency Rationale

`relationship_interaction_type` is required by `claim_predicates`, which must exist in Migration 0003 Batch 8. It could not be added to Migration 0001 because that migration is applied and MIGRATION_PHILOSOPHY.md prohibits modifying applied migrations.

`display_policy_status` and `display_policy_decision` are required by `display_policies` and `display_policy_rules` (Batch 5 in Migration 0003). They govern the lifecycle state machine and rule evaluation, respectively.

`display_contexts` is a reference table (not an enum) because display context codes have associated metadata (label, description, sort_order) and may eventually need to carry additional fields. It is created in Migration 0002 rather than 0003 because it is seed data — a stable, authored dataset that is logically prior to the DDL that references it. The nine codes are architectural constants per DISPLAY_POLICY_MODEL.md v0.1 and PRE_SQL_READINESS_REVIEW.md.

### 1.4 Seed Data Requirements

All nine display_contexts records must be inserted within Migration 0002, in sort_order sequence:

| code | label | sort_order | Fail-Closed Default |
|---|---|---|---|
| `public_ui` | Public UI | 1 | deny |
| `family_ui` | Family UI | 2 | deny |
| `steward_ui` | Steward UI | 3 | allow (steward only) |
| `historical_record` | Historical Record | 4 | deny |
| `ordinary_search` | Ordinary Search | 5 | deny |
| `identity_resolution_search` | Identity Resolution Search | 6 | deny |
| `default_export` | Default Export | 7 | deny |
| `steward_export` | Steward Export | 8 | allow (steward only) |
| `ai_generation` | AI Generation | 9 | deny |

These defaults are not enforced by the seed data itself — they are documented constants enforced by `fn_display_policy_allows` and the display context evaluation logic defined in VOCABULARY_RLS_MATRIX.md §4.6.

### 1.5 Validation Requirements

After Migration 0002 is applied, verify:

1. Three new enum types exist: `SELECT * FROM pg_type WHERE typname IN ('relationship_interaction_type', 'display_policy_status', 'display_policy_decision')` — must return 3 rows
2. `display_contexts` table exists with correct structure: `\d display_contexts` — must show PRIMARY KEY on `code`
3. Exactly 9 seed records: `SELECT count(*) FROM display_contexts` — must return 9
4. All 9 codes present: `SELECT code FROM display_contexts ORDER BY sort_order` — must match the nine codes above in order
5. No orphan records: `SELECT sort_order, count(*) FROM display_contexts GROUP BY sort_order HAVING count(*) > 1` — must return 0 rows (no duplicate sort_orders)

### 1.6 Rollback Considerations

Migration 0002 is purely additive. If rollback is required before Migration 0003 is applied, execute:

```
-- Rollback order: table first (no downstream FKs yet), then types
DROP TABLE display_contexts;
DROP TYPE display_policy_decision;
DROP TYPE display_policy_status;
DROP TYPE relationship_interaction_type;
```

Once Migration 0003 is applied, `display_contexts` has downstream FK references and individual rollback of 0002 is not possible without rolling back 0003 first. The recommended rollback path after 0003 application is a dedicated rollback migration, not manual intervention.

---

## §2. Migration 0003 Plan

### 2.1 Purpose

Migration 0003 is the core schema migration. It creates all 50 governed tables, 3 deferred FK constraints, 7 performance indexes + 1 partial unique index (`uq_lifebook_entities_active`), 9 helper functions, 22 triggers, RLS enablement on 25 tables, 71 RLS policies, and all minimum-privilege grants. It also seeds reference catalogues (ClaimPredicates, ClaimValueUnits, RelationshipTypes) and governance seed data.

This is the largest and most complex migration in the LifeBook sequence. It must be executed as a single transaction. Any failure aborts the entire migration with no partial state.

### 2.2 File Strategy

Single file: `<TIMESTAMP>_core_schema.sql`. Per MIGRATION_0003_PROPOSAL.md §8 Option A, a single file avoids cross-migration FK dependencies and matches the pattern established in Migration 0001. The file will be large; the complexity is managed by strict internal section ordering, not by splitting across files.

Internal section labels must mark each batch, phase, and step, making the file navigable for review and auditing.

### 2.3 Table Creation Order

Tables must be created in the following batch sequence to satisfy FK dependencies at creation time. Deferred FKs (where the referenced table does not yet exist at creation time) are added via ALTER TABLE in Phase 2, after all tables are created.

**Batch 1 — Jurisdiction (prerequisite for LifeBook)**

`jurisdictions`, `jurisdiction_policy_versions`

Seed immediately: minimum 6 jurisdiction records (Canada/federal, Alberta, British Columbia, Ontario, Ukraine, international default). These records are required before any LifeBook record can be created.

**Batch 2 — Users**

`user_profiles`

Wraps `auth.users`. References `auth.users(id)` — this FK targets the Supabase auth schema, not a table created in this migration.

**Batch 3 — Entity anchors**

`entities`, `persons`, `organizations`, `places`, `vessels`, `communities`, `event_series`

All entity subtypes. No person attribute tables at this batch; those are in Batch 14. `places` carries cached coordinates (`cached_latitude`, `cached_longitude`) — these are application cache fields, not authoritative geographic data.

**Batch 4 — LifeBook scoping**

`lifebooks`, `lifebook_memberships`, `user_person_links`, `lifebook_entities`, `lifebook_person_contexts`

`lifebooks` requires `jurisdictions` (NOT NULL FK per P13 in ARCHITECTURE_FREEZE_V1.md) and `user_profiles`. `user_person_links` is an optional link — not all authenticated users are LifeBook subjects. This table is central to `fn_is_subject_of`. `lifebook_entities` must precede `lifebook_person_contexts` within this batch. `lifebook_person_contexts` is created **without** the `permission_cache_policy_version_id` FK referencing `approval_policies`; that FK is Deferred FK 3 (see §2.4), added immediately after Batch 5 `approval_policies` DDL.

**Batch 5 — Governance policy templates**

`escalation_policies`, `approval_policies`, `conflict_resolution_policies`, `display_policies`, `display_policy_rules`

`display_policies` is created here **without** the `approval_record_id` FK column referencing `approval_records`. That FK is a deferred constraint added in Phase 2 after Batch 6. `display_policy_rules` requires `display_contexts.code` as a TEXT FK — this is the dependency on Migration 0002 seed data.

Seed immediately after DDL: representative ApprovalPolicy records (per GOVERNANCE_MODELS.md §4.4), ConflictResolutionPolicy records (per GOVERNANCE_MODELS.md §5.5), and EscalationPolicy records (per OPERATIONAL_MODELS.md §2).

**Batch 6 — Approval instances**

`approval_records`

Requires `approval_policies`. After this table is created, add Deferred FK 2 immediately (see Phase 2).

**Batch 7 — Authority**

`authority_assignments`

Requires `persons`, `lifebooks`, `user_profiles`, `approval_policies`. Created **without** the `basis_claim_id` FK; that FK references `claims` which does not exist yet. Deferred FK 1 is added in Phase 2 after Batch 10.

**Batch 8 — Reference catalogues**

`claim_predicates`, `relationship_types`

These are reference tables (not enums) because they carry metadata and may evolve independently of the PostgreSQL type system.

Note: `claim_value_units` is **not** created or seeded in this migration. It is a prerequisite vocabulary table created and seeded in Migration 0001 (`20260724153745_types_and_vocabularies.sql`). Its 11 records are already present when Migration 0003 executes.

Seed immediately: 74 ClaimPredicate records (per CLAIM_PREDICATE_CATALOGUE.md), 27 RelationshipType records (per RELATIONSHIP_TYPE_CATALOGUE.md).

**Critical:** `trg_claim_numeric_unit_check` (Trigger 21) must NOT be created until ClaimPredicate and ClaimValueUnit seed data is committed. This trigger is deferred to Pass C in Phase 5.

**Batch 9 — AI Context infrastructure**

`agent_registry`, `context_profiles`

Seed immediately: registered agents per AI_CONTEXT_BROKER.md §3.2, and context profiles (`respectful_generation`, `identity_resolution`) per AI_CONTEXT_BROKER.md §2.

**Batch 10 — Content tables**

`sources`, `claims`, `claim_evidence`, `relationships`, `narratives`, `narrative_entities`, `events`, `event_participants`, `artifacts`, `artifact_source_links`

Ordering constraints within this batch:
- `sources` before `artifacts` (artifacts may reference sources)
- `claims` before `claim_evidence` (claim_evidence references claims)
- `claims` before `relationships` is not required (no cross-dependency at creation time — both reference `entities` and `lifebooks`)
- `claims` before `events` — `events.source_claim_id` is an inline FK referencing `claims(id)`. This is **not** a deferred FK; claims must precede events in the batch.
- `events` before `event_participants` (event_participants references events)
- `narratives` before `narrative_entities` (narrative_entities references narratives)

Inline self-FKs declared at table creation time:
- `claims.superseded_by_claim_id UUID NULL REFERENCES claims(id)` — inline nullable self-FK
- `relationships.superseded_by_relationship_id UUID NULL REFERENCES relationships(id)` — inline nullable self-FK

After Batch 10 DDL is complete, add Deferred FK 1 (authority_assignments.basis_claim_id → claims(id)).

**Batch 11 — AI Context manifests**

`context_manifests`, `source_derivatives`

`context_manifests` requires `claims`, `sources`, `agent_registry`, `context_profiles`. Permanent records — DELETE denied by RLS (Policy 23).

**Batch 12 — Cross-LifeBook**

`merge_records`, `cross_lifebook_authorizations`, `lifebook_source_access`

`merge_records` and `cross_lifebook_authorizations` require `approval_records` (NOT NULL FKs — G3 blocker resolved per MIGRATION_0003_PROPOSAL.md §2). `cross_lifebook_authorizations` carries three ApprovalRecord FKs: `approval_a_id` (NOT NULL), `approval_b_id` (NOT NULL), `person_authorization_id` (nullable).

**Batch 13 — Escalation and dispute**

`contest_records`, `escalation_records`, `escalation_notifications`, `access_policy_changed_events`

`escalation_records` carries renamed FK: `approval_record_id` (was `approval_workflow_id` — G3 blocker resolved). `access_policy_changed_events` are permanent records — DELETE denied by RLS (Policy 24).

**Batch 14 — Person attributes**

`person_names`, `person_name_derivatives`, `person_pronouns`, `person_gender_descriptors`

`person_names` and `person_name_derivatives` were blocked pending G2 resolution (PersonName confidence normalization). G2 is resolved: four separate fields (`evidence_status`, `dispute_status`, `precision_status`, `review_status`) replace the old combined `confidence` enum; `review_status` is independent on `person_name_derivatives` and is not inherited from the parent PersonName record. PERSON_ATTRIBUTE_CATALOGUE.md must be confirmed updated before SQL for these tables is authored.

### 2.4 Deferred Foreign Keys (Phase 2 and inline)

Three deferred FKs are added via ALTER TABLE within Migration 0003, after the referenced tables are created. All three are nullable.

**Deferred FK 1 — authority_assignments.basis_claim_id → claims(id)**

Added immediately after Batch 10 DDL. Constraint name: `fk_authority_basis_claim`.

Rationale: AuthorityAssignment (Batch 7) is created before Claim (Batch 10) because governance infrastructure must precede content. The FK constraint cannot be declared inline without reversing this dependency order.

**Deferred FK 2 — display_policies.approval_record_id → approval_records(id)**

Added immediately after Batch 6 DDL. Constraint name: `fk_display_policy_approval_record`.

Rationale: DisplayPolicy (Batch 5) is created before ApprovalRecord (Batch 6) because policy templates must precede instances. The FK is nullable — most DisplayPolicies do not require an ApprovalRecord at creation time.

**Deferred FK 3 — lifebook_person_contexts.permission_cache_policy_version_id → approval_policies(id)**

Added immediately after Batch 5 `approval_policies` DDL. Constraint name: `fk_permission_cache_approval_policy`.

Rationale: `lifebook_person_contexts` (Batch 4) is created before `approval_policies` (Batch 5). The FK is nullable — the column is null when the permission cache has not yet been computed. Note: this is inserted within the Batch 5 block (after `approval_policies` but before `conflict_resolution_policies`), not at the end of Phase 2.

**All other FKs** in the schema are declared inline at table creation time (including the two inline self-FKs on claims and relationships).

### 2.5 Indexes (Phase 3)

Create before helper functions. These indexes are required for STABLE helper function performance; without them, RLS evaluation on large tables will degrade unacceptably.

| Index Name | Table | Columns | Purpose |
|---|---|---|---|
| `idx_lifebook_memberships_user_lifebook` | `lifebook_memberships` | `(user_id, lifebook_id)` | `fn_lb_membership_role` lookup |
| `idx_authority_assignments_role_entity` | `authority_assignments` | `(authority_role, entity_id)` | `fn_has_active_authority` lookup |
| `idx_authority_assignments_expiry` | `authority_assignments` | `(effective_until) WHERE effective_until IS NOT NULL` | Partial index for expiry checks |
| `idx_claims_lifebook_review_access` | `claims` | `(lifebook_id, review_status, access_classification)` | RLS policy 1; AI context filtering |
| `idx_display_policy_rules_policy_context` | `display_policy_rules` | `(display_policy_id, display_context_code)` | `fn_display_policy_allows` lookup |
| `idx_user_person_links_user_entity` | `user_person_links` | `(user_id, entity_id)` | `fn_is_subject_of` lookup |
| `idx_contest_records_contested_record` | `contest_records` | `(contested_record_table, contested_record_id)` | `fn_has_contest_standing` lookup |

### 2.6 Helper Functions (Phase 4)

All 9 helper functions created in this dependency order. SECURITY DEFINER, search_path, and ownership must be verified on functions 2 and 4–9 before any RLS policy is created.

| Order | Function | SECURITY DEFINER | Dependencies |
|---|---|---|---|
| 1 | `fn_user_is_agent` | No | None — `current_user` only |
| 2 | `fn_lb_membership_role` | Yes | `lifebook_memberships` (table must exist) |
| 3 | `fn_is_subject_of` | Yes | `user_person_links` |
| 4 | `fn_has_active_authority` | Yes | `authority_assignments`; must not be called by `authority_assignments` RLS |
| 5 | `fn_display_policy_allows` | Yes | `display_policies`, `display_policy_rules`; must not be called by those tables' RLS |
| 6 | `fn_has_source_access_grant` | Yes | `lifebook_source_access`, `cross_lifebook_authorizations` |
| 7 | `fn_has_community_authorization` | Yes | `approval_records`, `approval_policies` |
| 8 | `fn_has_contest_standing` | Yes | `user_person_links`, `authority_assignments`, `lifebook_memberships`; dynamic table join (table name must be whitelisted) |
| 9 | `fn_generate_artifact_signed_url` | Yes | `artifacts`, `display_policies`, `display_policy_rules`, `file_storage_references`, storage API |

Detailed per-function security requirements are in SECURITY_DEFINER_REVIEW.md v1.0.

**Recursion constraint verification:** Before proceeding to Phase 5, confirm that:
- `authority_assignments` RLS policies do NOT call `fn_has_active_authority`
- `display_policies` and `display_policy_rules` RLS policies do NOT call `fn_display_policy_allows`
- `contest_records` RLS SELECT policy does NOT call `fn_has_contest_standing` (uses `fn_lb_membership_role` instead)

These constraints are mandatory. Violation produces infinite recursion in RLS evaluation.

### 2.7 Triggers (Phase 5)

22 triggers created in three passes.

**Pass A — No cross-table dependencies (12 triggers)**

| # | Trigger | Table |
|---|---|---|
| 1 | `trg_claim_value_not_null` | `claims` |
| 2 | `trg_claim_ai_provenance` | `claims` |
| 3 | `trg_claim_content_immutable` | `claims` |
| 4 | `trg_relationship_content_immutable` | `relationships` |
| 5 | `trg_source_dna_classification` | `sources` |
| 6 | `trg_source_type_immutable` | `sources` |
| 7 | `trg_source_lifebook_immutable` | `sources` |
| 8 | `trg_event_provenance_immutable` | `events` |
| 9 | `trg_approval_records_immutable` | `approval_records` |
| 10 | `trg_authority_assignment_revocation_guard` | `authority_assignments` |
| 11 | `trg_display_policies_lifecycle` | `display_policies` |
| 12 | `trg_display_policies_delete_guard` | `display_policies` |

**Pass B — Cross-table dependencies (9 triggers, created after all tables exist)**

| # | Trigger | Table | Cross-Table Dependency |
|---|---|---|---|
| 13 | `trg_claim_supersession_integrity` | `claims` | Self-join |
| 14 | `trg_relationship_supersession_integrity` | `relationships` | Self-join |
| 15 | `trg_claim_dispute_requires_contest` | `claims` | `contest_records` |
| 16 | `trg_relationship_dispute_requires_contest` | `relationships` | `contest_records` |
| 17 | `trg_display_policy_rules_update_guard` | `display_policy_rules` | `display_policies` |
| 18 | `trg_display_policy_rules_delete_guard` | `display_policy_rules` | `display_policies` |
| 19 | `trg_contest_record_standing_validation` | `contest_records` | `authority_assignments`, `user_person_links` |
| 20 | `trg_lifebook_person_context_completeness` | `lifebook_entities` | `lifebook_person_contexts` |
| 22 | `trg_source_derivative_invalidation_cascade` | `source_derivatives` | `access_policy_changed_events`, `context_manifests` |

**Pass C — After seed data committed (1 trigger)**

| # | Trigger | Table | Seed Dependency |
|---|---|---|---|
| 21 | `trg_claim_numeric_unit_check` | `claims` | `claim_predicates` seed (74 records, this migration) must be committed; `claim_value_units` (11 records) is a Migration 0001 prerequisite already present |

### 2.8 RLS Enablement (Phase 6)

Enable RLS on exactly 25 tables. No content may be inserted into any governed table before RLS is enabled; the enablement step must follow immediately after triggers, before any seed data that goes into governed tables.

The 25 tables: `claims`, `relationships`, `narratives`, `narrative_entities`, `sources`, `artifacts`, `events`, `event_participants`, `display_policies`, `display_policy_rules`, `approval_records`, `authority_assignments`, `contest_records`, `person_names`, `person_pronouns`, `person_gender_descriptors`, `person_name_derivatives`, `context_manifests`, `access_policy_changed_events`, `source_derivatives`, `lifebook_memberships`, `claim_evidence`, `artifact_source_links`, `lifebook_entities`, `lifebook_person_contexts`

### 2.9 RLS Policies (Phase 7)

71 policies created in 8 groups, ordered by function dependency. Groups A and B have no function dependencies and can be created first; remaining groups require the helper functions from Phase 4 to exist.

| Group | Policies | Function Dependencies | Policy Numbers |
|---|---|---|---|
| A | DELETE denied | None | 16–29, 59, 65 |
| B | UPDATE immutability | None | 49 |
| C | LifeBook-scoped SELECT | `fn_lb_membership_role`, `fn_user_is_agent` | 1–15, 66–68, 70 |
| D | INSERT and AI restrictions | `fn_user_is_agent`, `fn_lb_membership_role` | 30–36, 41, 47, 51, 69, 71 |
| E | Cultural and classification | `fn_has_active_authority` | 37–44 |
| F | DisplayPolicy lifecycle | `fn_has_active_authority` | 45–48 |
| G | Governance | `fn_lb_membership_role`, `fn_has_contest_standing` | 50, 52–53 |
| H | LifeBook entity access | `fn_lb_membership_role`, `fn_is_subject_of`, `fn_user_is_agent` | 54–58, 60–64 |

### 2.10 Grants (Phase 8)

Minimum-privilege grants applied after RLS is active. RLS further restricts what each role can access beyond these base grants.

| Role | Privileges |
|---|---|
| `authenticated` | SELECT, INSERT, UPDATE on content tables; RLS restricts further by actor class |
| `agent_service` | SELECT on `claims`, `narratives`, `sources`, `artifacts`, `events`; INSERT on `claims`, `narratives` |
| `system_service` | SELECT all; INSERT on `approval_records`, `context_manifests`, `source_derivatives`, `access_policy_changed_events` |
| `admin` | SELECT all; no superuser (admin does not bypass RLS) |

**Column restriction deferred (W11 — DP Decision 2026-07-25):** `REVOKE SELECT ON file_storage_references.object_key` is not authored in this migration. That restriction is deferred to the storage integration migration where `file_storage_references` is formally introduced.

REVOKE EXECUTE FROM PUBLIC on all helper functions before per-role grants. Grant EXECUTE per the table in SECURITY_DEFINER_REVIEW.md §Cross-Cutting Mitigations.

### 2.11 Validation (Phase 9)

10 validation queries must pass before the migration is considered complete. These are documented in VOCABULARY_RLS_MATRIX.md §9 Phase 9 and are reproduced here for the implementation record:

| # | Check | Query | Expected Result |
|---|---|---|---|
| 1 | RLS active | `SELECT tablename FROM pg_tables WHERE rowsecurity = TRUE` | 25 governed tables |
| 2 | Trigger count | `SELECT count(*) FROM information_schema.triggers` | 22 |
| 3 | Function count | `SELECT count(*) FROM pg_proc WHERE proname LIKE 'fn_%'` | 9 |
| 4 | Fail-closed | `SELECT count(*) FROM claims` as unauthenticated role | 0 rows or permission denied |
| 5 | Agent exclusion | `SELECT count(*) FROM claims WHERE access_classification = 'culturally_governed'` as `agent_service` | 0 rows |
| 6 | Permanence | `DELETE FROM claims LIMIT 1` | RLS error |
| 7 | Immutability | `UPDATE claims SET predicate_id = predicate_id WHERE id = <any_id>` | Trigger error |
| 8 | Policy guard | `INSERT INTO display_policy_rules VALUES (<active_policy_id>, ...)` | Trigger error |
| 9 | Deferred FKs | `SELECT conname FROM pg_constraint WHERE conname IN ('fk_authority_basis_claim','fk_display_policy_approval_record','fk_permission_cache_approval_policy')` | 3 rows |
| 10 | Supersession | `UPDATE claims SET superseded_by_claim_id = id WHERE id = <any_id>` | Trigger error (self-reference) |

### 2.12 Migration Verification (Phase 10)

After all validation queries pass:
1. Record migration hash in `migration_log` per MIGRATION_PHILOSOPHY.md §7
2. Confirm Supabase migration applied cleanly with no warnings or errors
3. Commit migration file to git with commit message format per MIGRATION_PHILOSOPHY.md §7
4. Update PRE_SQL_READINESS_REVIEW.md gate status to: `MIGRATION 0003 COMPLETE`

---

## §3. Dependency Graph

The following graph shows object dependencies across migration locations. Arrows denote "required before."

```
MIGRATION 0001 (Applied)
│
├── 37 enum types
│     ↓
│     Available to all Migration 0002 and 0003 objects
│
MIGRATION 0002 (Pending)
│
├── relationship_interaction_type (enum)
│     ↓
│     claim_predicates.relationship_interaction_type column [0003 Batch 8]
│
├── display_policy_status (enum)
│     ↓
│     display_policies.status column [0003 Batch 5]
│
├── display_policy_decision (enum)
│     ↓
│     display_policy_rules.decision column [0003 Batch 5]
│
└── display_contexts (reference table + 9 seed records)
      ↓
      display_policy_rules.display_context_code FK [0003 Batch 5]
      ↓
      fn_display_policy_allows (p_context_code lookup) [0003 Phase 4]
      ↓
      fn_display_policy_allows evaluation [application layer]
│
MIGRATION 0003 (Pending — requires 0002 applied)
│
├── Batch 1: jurisdictions, jurisdiction_policy_versions
│     ↓
│     lifebooks.jurisdiction_id (NOT NULL FK) [Batch 4]
│
├── Batch 2: user_profiles
│     ↓
│     lifebooks.created_by_id [Batch 4]
│     lifebook_memberships.user_id [Batch 4]
│     user_person_links.user_id [Batch 4]
│
├── Batch 3: entities, persons, organizations, places, vessels, communities, event_series
│     ↓
│     claims.entity_id [Batch 10]
│     relationships.entity_a_id, entity_b_id [Batch 10]
│     authority_assignments.entity_id [Batch 7]
│
├── Batch 4: lifebooks, lifebook_memberships, user_person_links,
│            lifebook_entities, lifebook_person_contexts (no permission_cache_approval_policy FK)
│     ↓
│     claims.lifebook_id [Batch 10]
│     fn_lb_membership_role (reads lifebook_memberships) [Phase 4]
│     fn_is_subject_of (reads user_person_links) [Phase 4]
│     lifebook_person_contexts ← Deferred FK 3 (permission_cache_policy_version_id) added after Batch 5 approval_policies
│
├── Batch 5: escalation_policies, approval_policies, conflict_resolution_policies,
│            display_policies (no approval_record_id FK), display_policy_rules
│     ↓
│     approval_records.policy_id [Batch 6]
│     authority_assignments.approval_policy_id [Batch 7]
│     lifebook_person_contexts ← Deferred FK 3 (permission_cache_policy_version_id) added after approval_policies DDL
│     display_policies ← Deferred FK 2 (approval_record_id) added after Batch 6
│
├── Batch 6: approval_records
│     ↓ [immediately after DDL]
│     Deferred FK 2: ALTER TABLE display_policies ADD FK approval_record_id → approval_records(id)
│     ↓
│     merge_records.approval_record_id (NOT NULL) [Batch 12]
│     cross_lifebook_authorizations.approval_a_id, approval_b_id (NOT NULL) [Batch 12]
│     escalation_records.approval_record_id [Batch 13]
│
├── Batch 7: authority_assignments (no basis_claim_id FK)
│     ↓
│     fn_has_active_authority (reads authority_assignments) [Phase 4]
│     trg_contest_record_standing_validation (reads authority_assignments) [Phase 5 Pass B]
│     ↓ [Deferred FK 1 added after Batch 10 claims DDL]
│
├── Batch 8: claim_predicates, relationship_types
│     (claim_value_units is a Migration 0001 prerequisite — not created here)
│     ↓ [seed data committed immediately]
│     claims.predicate_id FK [Batch 10]
│     trg_claim_numeric_unit_check [Phase 5 Pass C — after seed]
│
├── Batch 9: agent_registry, context_profiles
│     ↓
│     context_manifests.agent_code FK [Batch 11]
│
├── Batch 10: sources, claims, claim_evidence, relationships, narratives,
│             narrative_entities, events, event_participants, artifacts, artifact_source_links
│
│     Note: within Batch 10, claims must precede events (events.source_claim_id inline FK)
│     ↓ [immediately after claims DDL]
│     Deferred FK 1: ALTER TABLE authority_assignments ADD FK basis_claim_id → claims(id)
│     ↓
│     context_manifests.source_ids, claim_ids [Batch 11]
│
├── Batch 11: context_manifests, source_derivatives
│     ↓
│     trg_source_derivative_invalidation_cascade [Phase 5 Pass B]
│
├── Batch 12: merge_records, cross_lifebook_authorizations, lifebook_source_access
│     ↓
│     fn_has_source_access_grant (reads lifebook_source_access, cross_lifebook_authorizations) [Phase 4]
│
├── Batch 13: contest_records, escalation_records, escalation_notifications,
│             access_policy_changed_events
│     ↓
│     trg_claim_dispute_requires_contest [Phase 5 Pass B — reads contest_records]
│     fn_has_contest_standing (reads contest_records) [Phase 4]
│
├── Batch 14: person_names, person_name_derivatives, person_pronouns, person_gender_descriptors
│
├── Phase 2: Deferred FKs (already noted above at point-of-addition)
│
├── Phase 3: Indexes (7 indexes — before Phase 4)
│
├── Phase 4: Helper functions (dependency order: fn_user_is_agent → fn_lb_membership_role →
│            fn_is_subject_of → fn_has_active_authority → fn_display_policy_allows →
│            fn_has_source_access_grant → fn_has_community_authorization →
│            fn_has_contest_standing → fn_generate_artifact_signed_url)
│
├── Phase 5: Triggers (Pass A → Pass B → Pass C)
│
├── Phase 6: RLS enablement (25 tables)
│
├── Phase 7: RLS policies (Groups A→B→C→D→E→F→G→H)
│
├── Phase 8: Grants (after RLS active)
│
├── Phase 9: Validation (10 checks must pass)
│
└── Phase 10: Migration verification and commit
```

---

## §4. Validation Strategy

### 4.1 Schema Checks

After all DDL is committed, verify the structural completeness of the migration:

- **Table count:** The migration creates 50 tables (14 batches). Run `SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'` and confirm the expected count.
- **Enum count:** Migration 0002 adds 3 enums to the 37 from Migration 0001. `SELECT count(*) FROM pg_type WHERE typtype = 'e'` — expected count depends on base database state; confirm all three new enum names are present.
- **Column existence spot-checks:** Verify the two DP-decision columns exist:
  - `SELECT column_name FROM information_schema.columns WHERE table_name = 'events' AND column_name = 'source_claim_id'` — must return 1 row
  - `SELECT column_name FROM information_schema.columns WHERE table_name = 'relationships' AND column_name = 'superseded_by_relationship_id'` — must return 1 row
- **Deferred FK names:** `SELECT conname FROM pg_constraint WHERE conname IN ('fk_authority_basis_claim','fk_display_policy_approval_record','fk_permission_cache_approval_policy')` — must return 3 rows
- **Self-FK existence on claims:** `SELECT conname FROM pg_constraint WHERE conrelid = 'claims'::regclass AND confrelid = 'claims'::regclass` — must return 1 row (superseded_by_claim_id self-FK)
- **Self-FK existence on relationships:** Same pattern on `relationships` table

### 4.2 FK Checks

- For each deferred FK, verify the constraint exists in `pg_constraint` and points to the correct referenced table
- Verify `display_policy_rules.display_context_code` references `display_contexts.code`: `SELECT conname FROM pg_constraint WHERE conrelid = 'display_policy_rules'::regclass AND confrelid = 'display_contexts'::regclass` — must return 1 row

### 4.3 Seed Verification

After each seed batch is committed, verify row counts against expected values:

| Table | Expected Count | Owner Migration | Source |
|---|---|---|---|
| `display_contexts` | 9 | 0002 | Migration 0002 |
| `jurisdictions` | ≥ 6 | 0003 | OPERATIONAL_MODELS.md §4 |
| `claim_predicates` | 74 | 0003 | CLAIM_PREDICATE_CATALOGUE.md |
| `claim_value_units` | 11 | **0001** | CONTENT_LAYER.md §3.2.2 — seeded in Migration 0001; zero records added by Migration 0003 |
| `relationship_types` | 27 | 0003 | RELATIONSHIP_TYPE_CATALOGUE.md |
| `agent_registry` | ≥ 1 | AI_CONTEXT_BROKER.md §3.2 |
| `context_profiles` | ≥ 2 | AI_CONTEXT_BROKER.md |
| `approval_policies` | ≥ 1 | GOVERNANCE_MODELS.md §4.4 |
| `conflict_resolution_policies` | ≥ 1 | GOVERNANCE_MODELS.md §5.5 |
| `escalation_policies` | ≥ 1 | OPERATIONAL_MODELS.md §2 |

### 4.4 Trigger Verification

- **Count:** `SELECT count(*) FROM information_schema.triggers WHERE trigger_schema = 'public'` — expected: 22
- **Named presence spot-check:** `SELECT trigger_name FROM information_schema.triggers WHERE trigger_name IN ('trg_claim_content_immutable','trg_event_provenance_immutable','trg_relationship_supersession_integrity','trg_contest_record_standing_validation','trg_display_policies_lifecycle')` — must return 5 rows
- **Pass C trigger exists:** `SELECT trigger_name FROM information_schema.triggers WHERE trigger_name = 'trg_claim_numeric_unit_check'` — must return 1 row
- **Immutability live test:** Attempt an UPDATE on a content field of a claims row; must fail with trigger error (see Validation Query 7)
- **Supersession one-write-only test:** Attempt to set `superseded_by_claim_id` to a self-reference (Validation Query 10); must fail
- **DeleteGuard test:** Attempt DELETE on an active display_policy; must fail (Validation Query 8 pattern)

### 4.5 RLS Verification

- **RLS active count:** `SELECT count(*) FROM pg_tables WHERE schemaname = 'public' AND rowsecurity = TRUE` — expected: 23
- **Fail-closed test (unauthenticated):** Validation Query 4 — no rows visible without authenticated session
- **Agent cultural exclusion:** Validation Query 5 — culturally governed claims invisible to agent_service
- **Permanent record DELETE:** Validation Query 6 — DELETE on claims fails with RLS error
- **DELETE denied tables spot-check:** Attempt DELETE on `approval_records`, `authority_assignments`, `contest_records` — all must fail with RLS error
- **Policy count:** `SELECT count(*) FROM pg_policies WHERE schemaname = 'public'` — expected: 71

### 4.6 Security Checks

- **SECURITY DEFINER verification:** `SELECT proname, prosecdef FROM pg_proc WHERE proname LIKE 'fn_%'` — `prosecdef = TRUE` for all functions except `fn_user_is_agent`
- **search_path verification:** `SELECT proname, proconfig FROM pg_proc WHERE proname LIKE 'fn_%'` — all SECURITY DEFINER functions must show `search_path=public,pg_temp` in proconfig
- **EXECUTE FROM PUBLIC revoked:** Attempt `SELECT fn_lb_membership_role(gen_random_uuid())` as unauthenticated — must fail
- **Governance function ownership:** `SELECT proname, pg_get_userbyid(proowner) FROM pg_proc WHERE proname LIKE 'fn_%'` — all SECURITY DEFINER functions must be owned by the governance role, not `postgres`

---

## §5. Implementation Risks

### 5.1 Highest-Risk SQL Areas

**`fn_has_contest_standing` (Critical)**  
This function accepts a table name as a TEXT parameter and executes a dynamic SQL join. If the whitelist check is absent or incorrect, it introduces SQL injection into a SECURITY DEFINER context — the worst possible combination. The whitelist of permitted table names must be hard-coded within the function body and must raise an exception (not return FALSE) for any unrecognized table name. This function must be independently reviewed before the migration is applied.

**`fn_generate_artifact_signed_url` (Critical)**  
Highest-privilege function in the schema. Any code path that does not produce a URL must return NULL — not an error message, not a partial result. `object_key` must not appear in any return value, log entry, or error string. This function is a stub in Migration 0003; the full implementation requires storage integration review and independent audit per SECURITY_DEFINER_REVIEW.md §Pre-Deployment Audit Requirement.

**Recursion boundaries in RLS policies (High)**  
Three helper functions carry recursion risk: `fn_has_active_authority`, `fn_display_policy_allows`, `fn_has_contest_standing`. The RLS policies on the tables they read must not call these functions. These constraints are documented but must be actively verified during SQL authoring — a subtle policy miswiring does not fail at migration time; it fails at runtime with an infinite recursion error that is difficult to diagnose.

**Trigger Pass C dependency on seed commit (Medium)**  
`trg_claim_numeric_unit_check` must not be created until ClaimPredicate and ClaimValueUnit seed data is committed within the migration transaction. If the trigger is created before the seed, it has no predicate data to validate against and will incorrectly pass all claims. The ordering constraint within the migration file must be documented and enforced by comment.

**Deferred FK timing (Medium)**  
Both deferred FKs must be added at precise points within the migration file — not at the end of the file. Deferred FK 1 is added immediately after Batch 10 claims DDL. Deferred FK 2 is added immediately after Batch 6. If either is added too late (e.g., in a final ALTER TABLE block), the intervening DDL will not have FK enforcement for those columns, which creates a window where invalid references could be committed.

### 5.2 Migration Failure Points

**Transaction atomicity:** Migration 0003 must execute in a single explicit transaction. If any statement fails, the entire migration must roll back. Supabase migration tooling wraps migrations in transactions by default; verify this is the case for the specific tooling version in use.

**Seed data volume:** 74 ClaimPredicate records + 27 RelationshipType records + 10 ClaimValueUnit records = 111 seed INSERT statements. If any INSERT fails (duplicate code, missing required field, FK violation), the migration fails. All seed data must be validated for structural correctness before the migration file is authored.

**Batch 14 G2 blocker:** `person_names` and `person_name_derivatives` require PERSON_ATTRIBUTE_CATALOGUE.md to be confirmed with the four-field normalization (`evidence_status`, `dispute_status`, `precision_status`, `review_status`). If this confirmation has not been received, Batch 14 DDL cannot be authored correctly. Do not author Batch 14 SQL until confirmation is received.

**`display_contexts` seed timing:** Migration 0003 Batch 5 (`display_policy_rules`) references `display_contexts.code` as a TEXT FK. If Migration 0002 was not applied cleanly — or if the 9 seed records are missing — Batch 5 DDL will fail at the FK constraint. Verify Migration 0002 seed before beginning Migration 0003 authoring.

**RLS Phase 6 before governed seed data:** Any seed data that goes into RLS-governed tables (e.g., representative ApprovalPolicy records, if those tables are governed) must be inserted after RLS is enabled. Inserting into governed tables before RLS enablement bypasses all policies. The migration file must place RLS enablement (Phase 6) before any seed data that targets governed tables.

### 5.3 Security-Sensitive Areas

The following migration sections require heightened attention during SQL review:

- **All 9 helper function bodies:** Check: SECURITY DEFINER declared, `search_path` set, no user_id parameters, query is scoped to `current_user` or equivalent
- **All 53 RLS policy USING and WITH CHECK clauses:** Check: each clause matches the specification in VOCABULARY_RLS_MATRIX.md §2; no accidental `USING (TRUE)` or `WITH CHECK (TRUE)` present
- **DELETE denied policies (16–29):** Check: `USING (FALSE)` — not `USING (TRUE)`, not an expression, exactly the literal `FALSE`
- **AI agent restrictions (30–36):** Check: `fn_user_is_agent()` is called correctly; the WITH CHECK pattern blocks INSERT, not just SELECT
- **Cultural governance exclusions (37–40):** Check: the `access_classification = 'culturally_governed'` filter is applied with AND (not OR); a bug that uses OR instead of AND would allow agent access to all records
- **Column grant restriction on `object_key`:** Verify the REVOKE statement is present and correct; this must be explicitly tested

### 5.4 Areas Requiring Manual Review Before Deployment

Per ADR-0003.md and SECURITY_DEFINER_REVIEW.md:

1. **`fn_generate_artifact_signed_url`** — independent audit required before production; the stub created in 0003 is not production-ready
2. **`fn_has_contest_standing`** — review the whitelist check; confirm dynamic SQL uses parameterized queries not string concatenation
3. **RLS recursion call chain** — manual verification that no RLS policy on `authority_assignments`, `display_policies`, `display_policy_rules`, or `contest_records` calls the recursive helper function for that table
4. **Superuser RLS bypass** — document that `SET session_replication_role = 'replica'` bypasses RLS; confirm production Supabase roles do not include this capability for application roles

---

## §6. Final Readiness Statement

### Current Status

Migration 0001: Applied (2026-07-24). 37 enum types present in the database.

Migration 0002: Ready to author immediately. No blockers. Scope is finalized: 3 enum types + 1 reference table + 9 seed records. Validation requirements are defined in §1.5 above.

Migration 0003: Ready to author after Migration 0002 is applied and verified. All architectural decisions are resolved. Implementation sequence (Phases 1–10) is fully specified in VOCABULARY_RLS_MATRIX.md §9. Risk areas are documented in §5 above.

### Outstanding Pre-Authoring Confirmation Required

The following items must be confirmed before SQL authoring begins for the affected tables. None block Migration 0002. One blocks Batch 14 of Migration 0003.

| Item | Blocks | Status |
|---|---|---|
| Confirm PERSON_ATTRIBUTE_CATALOGUE.md G2 normalization: four-field model (`evidence_status`, `dispute_status`, `precision_status`, `review_status`) on PersonName; `review_status` independent on PersonNameDerivative | Batch 14 SQL | Required — confirm before authoring `person_names` and `person_name_derivatives` |
| Confirm ClaimPredicate seed file (74 records) is authored and reviewed | Batch 8 seed + trg_claim_numeric_unit_check | Required before authoring seed section of migration |
| Confirm single-file vs. two-file strategy is finalized | Migration file structure | Decision: single file per §2.2 — confirm DP is aligned |

All other pre-SQL checklist items in PRE_SQL_READINESS_REVIEW.md are resolved.

### Authorization Statement

SQL authoring for Migration 0002 may proceed immediately.

SQL authoring for Migration 0003 may proceed in parallel with Migration 0002 authoring, subject to the confirmation items above, and requires Migration 0002 to be applied before Migration 0003 is executed.

No architectural decisions, governance decisions, or enforcement strategy decisions are pending. This document is the complete implementation roadmap. Remaining work is SQL authoring, review, and application.
