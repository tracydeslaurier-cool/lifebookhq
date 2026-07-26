# Implementation Handoff Review
**Version:** 1.0  
**Date:** 2026-07-25  
**Produced by:** Tracy DesLaurier + Claude  
**Status:** Pre-authorization — no SQL written

---

## Executive Summary

Both migrations are ready to author with two categories of remaining work:

**Category 1 — Documentation fixes (no architecture impact):** Three documentation-level discrepancies found across three documents. All are annotation errors in older documents; the skeleton and registry are architecturally correct and the skeleton is authoritative.

**Category 2 — Seed authoring gaps:** Six seed datasets are source-documented but not field-level specified. These are smaller datasets (6–13 records each) and can be authored inline from source documents during the migration session. ClaimPredicate (74 records) is fully specified. This is not a blocker but adds work to the authoring session.

**All pre-authoring confirmations are satisfied.** No design decisions are open.

---

## §1. Migration 0002 — Complete Scope Inventory

### 1.1 Objects

| Object | Type | Exact Name | Values | Source Document | Status |
|---|---|---|---|---|---|
| Enum | PostgreSQL enum | `relationship_interaction_type` | `proposes, supports, describes, none` | MIGRATION_IMPLEMENTATION_PLAN.md §1.2 | ✓ Fully specified |
| Enum | PostgreSQL enum | `display_policy_status` | `draft, active, superseded, withdrawn` | MIGRATION_IMPLEMENTATION_PLAN.md §1.2 | ✓ Fully specified |
| Enum | PostgreSQL enum | `display_policy_decision` | `allow, deny, conditional` | MIGRATION_IMPLEMENTATION_PLAN.md §1.2 | ✓ Fully specified |
| Table | Reference table | `display_contexts` | code PK, label, description, sort_order, created_at | MIGRATION_IMPLEMENTATION_PLAN.md §1.2 | ✓ Fully specified |
| Seed | 9 INSERT records | `display_contexts` | 9 codes: public_ui, family_ui, steward_ui, historical_record, ordinary_search, identity_resolution_search, default_export, steward_export, ai_generation | MIGRATION_IMPLEMENTATION_PLAN.md §1.4 (table with sort_order) | ✓ Fully specified |

### 1.2 Validation Queries After 0002 Applied

5 checks defined in MIGRATION_IMPLEMENTATION_PLAN.md §1.5:
1. Three enum types exist — `SELECT * FROM pg_type WHERE typname IN (...)` — 3 rows
2. `display_contexts` has correct structure with PK on `code`
3. Exactly 9 seed records — `SELECT count(*) FROM display_contexts` — 9
4. All 9 codes present in sort_order sequence
5. No duplicate sort_orders

### 1.3 Rollback Procedure

Documented in plan §1.6. Rollback order: DROP TABLE display_contexts first, then DROP TYPE in reverse creation order. Cannot roll back 0002 independently after 0003 is applied.

### 1.4 Dependency Trigger

`display_policy_rules.display_context_code` carries a TEXT FK referencing `display_contexts.code`. If 0002 seed is missing, Batch 5 DDL in 0003 will fail. **Verify 0002 seed before beginning 0003 authoring.**

### 1.5 Placeholder

**File name:** `<TIMESTAMP>_predicate_governance_types.sql` — timestamp assigned at authoring time. No other placeholders in 0002.

---

## §2. Migration 0003 — Complete Scope Inventory

### 2.1 Tables (50 total)

| Batch | Tables | Count | Source Document | RLS | Permanent Records |
|---|---|---|---|---|---|
| 1 — Jurisdiction | jurisdictions, jurisdiction_policy_versions | 2 | OPERATIONAL_MODELS.md §4 | None | None |
| 2 — Users | user_profiles | 1 | ANCHOR_MODELS.md | None | None |
| 3 — Entity anchors | entities, persons, organizations, places, vessels, communities, event_series | 7 | ANCHOR_MODELS.md | None | None |
| 4 — LifeBook scoping | lifebooks, lifebook_memberships, user_person_links, lifebook_entities, lifebook_person_contexts | 5 | ANCHOR_MODELS.md | lifebook_memberships, lifebook_entities, lifebook_person_contexts | None |
| 5 — Governance templates | escalation_policies, approval_policies, conflict_resolution_policies, display_policies, display_policy_rules | 5 | GOVERNANCE_MODELS.md, DISPLAY_POLICY_MODEL.md | display_policies, display_policy_rules | None |
| 6 — Approval instances | approval_records | 1 | GOVERNANCE_MODELS.md | approval_records | approval_records |
| 7 — Authority | authority_assignments | 1 | GOVERNANCE_MODELS.md | authority_assignments | authority_assignments |
| 8 — Reference catalogues | claim_predicates, relationship_types | 2 | CLAIM_PREDICATE_CATALOGUE.md, RELATIONSHIP_TYPE_CATALOGUE.md | None | None |
| 8 — Prerequisite (Migration 0001) | claim_value_units | N/A — owned by Migration 0001 | CONTENT_LAYER.md §3.2.2 | N/A | N/A |
| 9 — AI context | agent_registry, context_profiles | 2 | AI_CONTEXT_BROKER.md | None | None |
| 10 — Content | sources, claims, claim_evidence, relationships, narratives, narrative_entities, events, event_participants, artifacts, artifact_source_links | 10 | CONTENT_LAYER.md | All 10 | sources, claims, claim_evidence, relationships, narratives, narrative_entities, events, event_participants, artifacts, artifact_source_links |
| 11 — AI manifests | context_manifests, source_derivatives | 2 | AI_CONTEXT_BROKER.md | Both | context_manifests |
| 12 — Cross-LifeBook | merge_records, cross_lifebook_authorizations, lifebook_source_access | 3 | GOVERNANCE_MODELS.md | None | None |
| 13 — Escalation/dispute | contest_records, escalation_records, escalation_notifications, access_policy_changed_events | 4 | GOVERNANCE_MODELS.md, CONTENT_LAYER.md | contest_records, access_policy_changed_events | contest_records, access_policy_changed_events |
| 14 — Person attributes | person_names, person_name_derivatives, person_pronouns, person_gender_descriptors | 4 | PERSON_ATTRIBUTE_CATALOGUE.md | All 4 | All 4 |

**Total: 50 tables.** RLS enabled on exactly **25 tables**. Remaining 25 are reference, infrastructure, or workflow tables controlled by grants.

### 2.2 Deferred Foreign Keys (3)

| Constraint Name | Table.Column | References | Inserted At | Source |
|---|---|---|---|---|
| `fk_authority_basis_claim` | `authority_assignments.basis_claim_id` | `claims(id)` | Immediately after Batch 10 `claims` DDL | DATABASE_OBJECT_REGISTRY.md |
| `fk_display_policy_approval_record` | `display_policies.approval_record_id` | `approval_records(id)` | Immediately after Batch 6 `approval_records` DDL | DATABASE_OBJECT_REGISTRY.md |
| `fk_permission_cache_approval_policy` | `lifebook_person_contexts.permission_cache_policy_version_id` | `approval_policies(id)` | Immediately after Batch 5 `approval_policies` DDL (not at end of file) | DATABASE_OBJECT_REGISTRY.md |

**Two inline self-FKs (not deferred — declared at table creation):**
- `claims.superseded_by_claim_id REFERENCES claims(id)`
- `relationships.superseded_by_relationship_id REFERENCES relationships(id)`

### 2.3 Indexes (8 total: 7 named + 1 partial unique)

| Index Name | Table | Columns | Type | Helper Function / Purpose |
|---|---|---|---|---|
| `uq_lifebook_entities_active` | `lifebook_entities` | `(lifebook_id, entity_id) WHERE removed_at IS NULL` | **Partial unique index — NOT table UNIQUE constraint** | Soft-delete re-add support |
| `idx_lifebook_memberships_user_lifebook` | `lifebook_memberships` | `(user_id, lifebook_id)` | Standard | `fn_lb_membership_role` |
| `idx_authority_assignments_role_entity` | `authority_assignments` | `(authority_role, entity_id)` | Standard | `fn_has_active_authority` |
| `idx_authority_assignments_expiry` | `authority_assignments` | `(effective_until) WHERE effective_until IS NOT NULL` | Partial | `fn_has_active_authority` expiry check |
| `idx_claims_lifebook_review_access` | `claims` | `(lifebook_id, review_status, access_classification)` | Standard | RLS policies 1, 30-31, 37 |
| `idx_display_policy_rules_policy_context` | `display_policy_rules` | `(display_policy_id, display_context_code)` | Standard | `fn_display_policy_allows` |
| `idx_user_person_links_user_entity` | `user_person_links` | `(user_id, entity_id)` | Standard | `fn_is_subject_of` |
| `idx_contest_records_contested_record` | `contest_records` | `(contested_record_table, contested_record_id)` | Standard | `fn_has_contest_standing`, triggers 15–16 |

### 2.4 Helper Functions (9)

All SECURITY DEFINER functions must carry `SET search_path = 'public', pg_temp` and be owned by `governance_functions` role. Source: SECURITY_DEFINER_REVIEW.md v1.0.

| Order | Name | SECURITY DEFINER | Tables Read | Recursion Constraint |
|---|---|---|---|---|
| 1 | `fn_user_is_agent` | No | None (`current_user` only) | None |
| 2 | `fn_lb_membership_role` | Yes | `lifebook_memberships` | `lifebook_memberships` RLS must NOT call this function |
| 3 | `fn_is_subject_of` | Yes | `user_person_links` | None |
| 4 | `fn_has_active_authority` | Yes | `authority_assignments` | `authority_assignments` RLS must NOT call this function |
| 5 | `fn_display_policy_allows` | Yes | `display_policies`, `display_policy_rules` | `display_policies` and `display_policy_rules` RLS must NOT call this function |
| 6 | `fn_has_source_access_grant` | Yes | `lifebook_source_access`, `cross_lifebook_authorizations` | None |
| 7 | `fn_has_community_authorization` | Yes | `approval_records`, `approval_policies` | None |
| 8 | `fn_has_contest_standing` | Yes | `user_person_links`, `authority_assignments`, `lifebook_memberships` + whitelisted table | `contest_records` SELECT RLS must NOT call this function; whitelist is hard-coded 9 tables |
| 9 | `fn_generate_artifact_signed_url` | Yes | **STUB — returns NULL immediately; does NOT reference `file_storage_references`** | None at stub time |

**fn_has_contest_standing whitelist (9 tables — hard-coded in function body):**
`'claims'`, `'relationships'`, `'narratives'`, `'sources'`, `'artifacts'`, `'events'`, `'person_names'`, `'person_pronouns'`, `'person_gender_descriptors'`
Unrecognized table name → `RAISE EXCEPTION` (not return FALSE).

### 2.5 Triggers (22)

| Pass | # | Trigger Name | Table | Timing | Event | Stub? |
|---|---|---|---|---|---|---|
| A | 1 | `trg_claim_value_not_null` | `claims` | BEFORE | INSERT | No |
| A | 2 | `trg_claim_ai_provenance` | `claims` | BEFORE | INSERT, UPDATE | No |
| A | 3 | `trg_claim_content_immutable` | `claims` | BEFORE | UPDATE | No |
| A | 4 | `trg_relationship_content_immutable` | `relationships` | BEFORE | UPDATE | No |
| A | 5 | `trg_source_dna_classification` | `sources` | BEFORE | INSERT | No |
| A | 6 | `trg_source_type_immutable` | `sources` | BEFORE | UPDATE | No |
| A | 7 | `trg_source_lifebook_immutable` | `sources` | BEFORE | UPDATE | No |
| A | 8 | `trg_event_provenance_immutable` | `events` | BEFORE | UPDATE | No |
| A | 9 | `trg_approval_records_immutable` | `approval_records` | BEFORE | UPDATE | No |
| A | 10 | `trg_authority_assignment_revocation_guard` | `authority_assignments` | BEFORE | UPDATE | No |
| A | 11 | `trg_display_policies_lifecycle` | `display_policies` | BEFORE | UPDATE | No |
| A | 12 | `trg_display_policies_delete_guard` | `display_policies` | BEFORE | DELETE | No |
| B | 13 | `trg_claim_supersession_integrity` | `claims` | BEFORE | UPDATE | No |
| B | 14 | `trg_relationship_supersession_integrity` | `relationships` | BEFORE | UPDATE | No |
| B | 15 | `trg_claim_dispute_requires_contest` | `claims` | BEFORE | UPDATE | No |
| B | 16 | `trg_relationship_dispute_requires_contest` | `relationships` | BEFORE | UPDATE | No |
| B | 17 | `trg_display_policy_rules_update_guard` | `display_policy_rules` | BEFORE | UPDATE | No |
| B | 18 | `trg_display_policy_rules_delete_guard` | `display_policy_rules` | BEFORE | DELETE | No |
| B | 19 | `trg_contest_record_standing_validation` | `contest_records` | BEFORE | INSERT | No |
| B | 20 | `trg_lifebook_person_context_completeness` | `lifebook_entities` | CONSTRAINT TRIGGER AFTER DEFERRABLE INITIALLY DEFERRED | INSERT | No |
| B | 22 | `trg_source_derivative_invalidation_cascade` | `source_derivatives` | AFTER | UPDATE | **Yes — RAISE NOTICE stub** |
| C | 21 | `trg_claim_numeric_unit_check` | `claims` | BEFORE | INSERT, UPDATE | No |

**Critical trigger notes:**
- `trg_lifebook_person_context_completeness` must be `CREATE CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED`. A plain AFTER trigger fires immediately and will block normal insert sequences. This is one of the highest-probability authoring errors.
- `trg_source_derivative_invalidation_cascade` is a stub. Body must issue `RAISE NOTICE ... and RETURN NULL`. Do not insert into `access_policy_changed_events` until full implementation.
- `trg_claim_numeric_unit_check` (trigger #21, Pass C) must be placed AFTER the Batch 8 seed is committed within the transaction. Position in file enforces this.

### 2.6 RLS (Phase 6 Enablement + Phase 7 Policies)

**25 tables for RLS enablement** (alphabetical order within batch for readability at authoring; correctness is independent of order within Phase 6):

access_policy_changed_events, approval_records, artifact_source_links, artifacts, authority_assignments, claim_evidence, claims, contest_records, context_manifests, display_policies, display_policy_rules, event_participants, events, lifebook_entities, lifebook_memberships, lifebook_person_contexts, narrative_entities, narratives, person_gender_descriptors, person_name_derivatives, person_names, person_pronouns, relationships, source_derivatives, sources

**71 policies across 8 groups.** The SKELETON Phase 7 is authoritative for group membership, policy names, and ordering. Individual USING/WITH CHECK clauses are in VOCABULARY_RLS_MATRIX.md §2.

### 2.7 Grants (Phase 8)

3 steps as specified in MIGRATION_0003_SKELETON.md Phase 8 (Step 8.4 deferred — W11 resolved):
1. REVOKE EXECUTE FROM PUBLIC for all 9 functions
2. Per-role EXECUTE grants per SECURITY_DEFINER_REVIEW.md
3. Content table grants by role (authenticated, agent_service, system_service, admin)

### 2.8 Seed Datasets

| Dataset | Count | Spec Status | Source |
|---|---|---|---|
| `display_contexts` | 9 | **Fully specified** — MIGRATION_IMPLEMENTATION_PLAN.md §1.4 | Implementation plan |
| `jurisdictions` | 6 minimum | **Source-documented, field-level not authored** | OPERATIONAL_MODELS.md §4 |
| `claim_predicates` | 74 | **Fully specified** — CLAIM_PREDICATE_SEED_SPEC.md | CLAIM_PREDICATE_CATALOGUE.md |
| `claim_value_units` | 11 | **Seeded in Migration 0001** — zero records added by Migration 0003 | CONTENT_LAYER.md §3.2.2 |
| `relationship_types` | 27 | **Source-documented, field-level not authored** | RELATIONSHIP_TYPE_CATALOGUE.md |
| `agent_registry` | ≥1 | **Source-documented, field-level not authored** | AI_CONTEXT_BROKER.md §3.2 |
| `context_profiles` | 2 minimum | **Source-documented, field-level not authored** | AI_CONTEXT_BROKER.md §2 |
| `approval_policies` | ≥1 | **Source-documented, field-level not authored** | GOVERNANCE_MODELS.md §4.4 |
| `conflict_resolution_policies` | ≥1 | **Source-documented, field-level not authored** | GOVERNANCE_MODELS.md §5.5 |
| `escalation_policies` | ≥1 | **Source-documented, field-level not authored** | OPERATIONAL_MODELS.md §2 |

**Total seed records in 0003:** 74 (ClaimPredicate) + 10 (ClaimValueUnit) + 27 (RelationshipType) + ~6 (jurisdictions) + ~2–6 (governance seeds) + ~3 (AI seeds) = **approximately 122–130 INSERTs in a single migration file.** The migration's internal comment at Batch 8 says "111 seed records" — this is ClaimPredicate + ClaimValueUnit + RelationshipType only (74+10+27=111). Governance and AI seeds add to this.

### 2.9 Validation (Phase 9)

11 queries must pass before COMMIT (skeleton Phase 9 is authoritative; the 11th query for policy count was added beyond the 10 originally in VOCABULARY_RLS_MATRIX.md §9):

1. RLS active — 25 tables
2. Trigger count — 22
3. Function count — 9
4. Fail-closed (unauthenticated) — 0 rows or permission denied
5. Agent cultural exclusion — 0 culturally_governed claims visible to agent_service
6. Permanent record DELETE denied — RLS error
7. Content immutability — trigger error on UPDATE
8. DisplayPolicy rule guard — trigger error on active-policy rule INSERT
9. Deferred FK names present — 3 constraint names returned
10. Supersession self-reference guard — trigger error
11. Policy count — 71

---

## §3. Placeholder Audit

### 3.1 Expected Placeholders (Resolved at Authoring Time)

| Placeholder | Location | Resolution |
|---|---|---|
| `<TIMESTAMP>_predicate_governance_types.sql` | MIGRATION_0003_SKELETON.md file header, MIGRATION_IMPLEMENTATION_PLAN.md §7 | Timestamp assigned when file is created; use `date +%Y%m%d%H%M%S` format |
| `<TIMESTAMP>_core_schema.sql` | MIGRATION_0003_SKELETON.md header | Same |
| `'migration:<actual_core_schema_filename>'` | `created_by_system` field in all 111+ seed INSERT records | Replace with actual filename once known (e.g., `'migration:20260726143000_core_schema.sql'`); applied identically to all seed records |

### 3.2 Unresolved Placeholders — ⚠ MUST RESOLVE BEFORE SQL

None. All architectural decisions, field names, constraint names, function names, trigger names, policy names, and index names are explicitly specified.

### 3.3 TBD Text Found

**None** — no TBD, TODO, or unresolved design notes found in MIGRATION_IMPLEMENTATION_PLAN.md, MIGRATION_0003_SKELETON.md, CLAIM_PREDICATE_SEED_SPEC.md, or CLAIM_PREDICATE_SEED_PLAN.md.

**MIGRATION_0003_SKELETON.md deferred items** are explicitly marked as intentionally deferred follow-on work, not unresolved design decisions:
- `fn_generate_artifact_signed_url` full implementation — deferred to storage integration milestone
- `trg_source_derivative_invalidation_cascade` full cascade — deferred to Context Broker implementation
- `memory_atmosphere_policy_evaluator` agent record — deferred to Memory Atmosphere Engine (ADR-0002)

---

## §4. Documentation Discrepancies Found

These are annotation errors in older documents. They do not affect SQL correctness; the skeleton is authoritative. The responsible author is noted for correction but correction is not a blocker.

### Discrepancy 1 — MIGRATION_IMPLEMENTATION_PLAN.md §4.5 RLS table count

| Location | Says | Should Say | Source of Truth |
|---|---|---|---|
| §4.5 validation check text | `expected: 23` | `expected: 25` | §2.8, Skeleton Phase 6 (25 tables enumerated), Skeleton Phase 9 Query 1 (25 rows), Registry Part III (25 tables listed) |

**Correction:** In §4.5, change the RLS validation expected value from 23 to 25.

### Discrepancy 2 — MIGRATION_IMPLEMENTATION_PLAN.md §2.11 validation query count

| Location | Says | Should Say | Source of Truth |
|---|---|---|---|
| §2.11 header | "10 validation queries must pass" | "11 validation queries must pass" | MIGRATION_0003_SKELETON.md Phase 9 (includes Query 11: policy count = 71) |

**Correction:** Change §2.11 header count from 10 to 11. Query 11 is already present in the skeleton.

### Discrepancy 3 — DATABASE_OBJECT_REGISTRY.md RLS policy group summary

The registry's RLS policy group summary table (the table with Group A–H counts) uses stale counts that don't match the skeleton. Specifically: Group A says 14 (should be 16), Group D says 11 (should be 12), Group E says 8 (should be 7), Group F says 4 (should be 3), Group H says 12 (should be 10). The total in the registry table header claims 71 but sums to 72. The skeleton is authoritative; the registry table is a summary view and does not affect SQL authoring.

**Correction:** Update DATABASE_OBJECT_REGISTRY.md Group A→16, D→12, E→7, F→3, H→10.

---

## §5. Pre-Authoring Confirmation Status

| Confirmation | Blocks | Status |
|---|---|---|
| A — G2 four-field normalization (evidence_status, dispute_status, precision_status, review_status on PersonName; review_status independent on PersonNameDerivative) | Batch 14 DDL | **RESOLVED** ✓ — confirmed this session; PERSON_ATTRIBUTE_CATALOGUE.md, DATABASE_OBJECT_REGISTRY.md, MIGRATION_IMPLEMENTATION_PLAN.md, and MIGRATION_0003_SKELETON.md all updated |
| B — ClaimPredicate seed (74 records) authored and reviewed | Batch 8 seed + Pass C trigger | **RESOLVED** ✓ — CLAIM_PREDICATE_SEED_SPEC.md authored this session; all validation checks pass |
| C — Single-file strategy | Entire migration file | **CONFIRMED** ✓ — per MIGRATION_IMPLEMENTATION_PLAN.md §2.2 |

---

## §6. Final SQL Authoring Checklist

Execute in this order.

### Migration 0002

- [ ] **2.1** Generate timestamp. File name: `<TIMESTAMP>_predicate_governance_types.sql`
- [ ] **2.2** Write transaction wrapper: `BEGIN; ... COMMIT;`
- [ ] **2.3** CREATE TYPE relationship_interaction_type AS ENUM ('proposes', 'supports', 'describes', 'none')
- [ ] **2.4** CREATE TYPE display_policy_status AS ENUM ('draft', 'active', 'superseded', 'withdrawn')
- [ ] **2.5** CREATE TYPE display_policy_decision AS ENUM ('allow', 'deny', 'conditional')
- [ ] **2.6** CREATE TABLE display_contexts (code TEXT PRIMARY KEY, label TEXT NOT NULL, description TEXT NOT NULL, sort_order INT NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now())
- [ ] **2.7** INSERT 9 display_contexts seed records (public_ui through ai_generation in sort_order)
- [ ] **2.8** Run 5 validation queries from MIGRATION_IMPLEMENTATION_PLAN.md §1.5 — all must pass
- [ ] **2.9** Apply via Supabase migration tooling
- [ ] **2.10** Verify applied cleanly (no warnings or errors)
- [ ] **2.11** Commit to git

### Migration 0003 — Pre-authoring

- [ ] **3.0** Determine filename timestamp. Record it. All seed records will carry `created_by_system = 'migration:<filename>'`
- [ ] **3.1** Read the following source documents before authoring inline seed records:
  - OPERATIONAL_MODELS.md §4 → jurisdiction seed records
  - CONTENT_LAYER.md §3.2.2 → ClaimValueUnit seed records (10)
  - RELATIONSHIP_TYPE_CATALOGUE.md → RelationshipType seed records (27)
  - AI_CONTEXT_BROKER.md §3.2 → AgentRegistry seed records
  - AI_CONTEXT_BROKER.md §2 → ContextProfile seed records
  - GOVERNANCE_MODELS.md §4.4 → ApprovalPolicy representative records
  - GOVERNANCE_MODELS.md §5.5 → ConflictResolutionPolicy representative records
  - OPERATIONAL_MODELS.md §2 → EscalationPolicy representative records
- [ ] **3.2** For ClaimPredicate seed: use CLAIM_PREDICATE_SEED_SPEC.md as the authoritative column-value reference. Do not re-derive from the catalogue.

### Migration 0003 — Phase 1 (Tables, Batches 1–14)

- [ ] **B1** Batch 1: jurisdictions, jurisdiction_policy_versions + 6 jurisdiction seed records
- [ ] **B2** Batch 2: user_profiles
- [ ] **B3** Batch 3: entities, persons, organizations, places, vessels, communities, event_series
- [ ] **B4** Batch 4: lifebooks, lifebook_memberships, user_person_links, lifebook_entities (with partial unique index note in comment), lifebook_person_contexts (permission_cache_policy_version_id as UUID NULL — no FK here)
- [ ] **B5a** Batch 5: escalation_policies + seed, approval_policies + seed, conflict_resolution_policies + seed
- [ ] **FK3** ← ADD CONSTRAINT fk_permission_cache_approval_policy immediately here
- [ ] **B5b** Batch 5 continued: display_policies (without approval_record_id FK), display_policy_rules
- [ ] **B6** Batch 6: approval_records
- [ ] **FK2** ← ADD CONSTRAINT fk_display_policy_approval_record immediately here
- [ ] **B7** Batch 7: authority_assignments (without basis_claim_id FK)
- [ ] **B8a** Batch 8: claim_predicates (table DDL)
- [ ] **B8b** Batch 8 seed: 74 ClaimPredicate INSERTs + Pass 2 UPDATE (3 symmetric self-inverses) — per CLAIM_PREDICATE_SEED_SPEC.md
- ~~**B8c**~~ **claim_value_units is a Migration 0001 prerequisite** — not created or seeded in Migration 0003; already present with 11 records
- [ ] **B8d** Batch 8: relationship_types (table DDL) + 27 seed records
- [ ] **B9** Batch 9: agent_registry + seed, context_profiles + seed
- [ ] **B10a** Batch 10: sources, claims (with superseded_by_claim_id inline self-FK)
- [ ] **FK1** ← ADD CONSTRAINT fk_authority_basis_claim immediately here
- [ ] **B10b** Batch 10 continued: claim_evidence, relationships (with superseded_by_relationship_id inline self-FK), narratives, narrative_entities, events (with source_claim_id inline FK → claims), event_participants, artifacts, artifact_source_links
- [ ] **B11** Batch 11: context_manifests, source_derivatives
- [ ] **B12** Batch 12: merge_records, cross_lifebook_authorizations, lifebook_source_access
- [ ] **B13** Batch 13: contest_records, escalation_records, escalation_notifications, access_policy_changed_events
- [ ] **B14** Batch 14: person_names, person_name_derivatives, person_pronouns, person_gender_descriptors (**Confirmation A required — already satisfied**)

### Migration 0003 — Phase 3 (Indexes)

- [ ] **I1** uq_lifebook_entities_active — partial unique index — **must be `CREATE UNIQUE INDEX`, not `ALTER TABLE ADD UNIQUE`**
- [ ] **I2–I8** 7 named indexes per MIGRATION_0003_SKELETON.md Phase 3 table

### Migration 0003 — Phase 4 (Helper Functions)

- [ ] **F1** fn_user_is_agent (NOT SECURITY DEFINER)
- [ ] **F2** fn_lb_membership_role (SECURITY DEFINER, search_path, governance_functions owner)
- [ ] **F3** fn_is_subject_of (SECURITY DEFINER)
- [ ] **F4** fn_has_active_authority (SECURITY DEFINER)
- [ ] **F5** fn_display_policy_allows (SECURITY DEFINER)
- [ ] **F6** fn_has_source_access_grant (SECURITY DEFINER)
- [ ] **F7** fn_has_community_authorization (SECURITY DEFINER)
- [ ] **F8** fn_has_contest_standing (SECURITY DEFINER — whitelist 9 tables — RAISE EXCEPTION on unknown)
- [ ] **F9** fn_generate_artifact_signed_url (SECURITY DEFINER — STUB — returns NULL — comment must say STUB)
- [ ] **SEC-CHECK** SECURITY DEFINER verification checkpoint (4-item checklist per skeleton) — must pass before Phase 5

### Migration 0003 — Phase 5 (Triggers)

- [ ] **T-A1–T-A12** Pass A: 12 triggers (no cross-table deps) — see MIGRATION_0003_SKELETON.md Phase 5 Pass A table
- [ ] **T-B13–T-B22** Pass B: 9 triggers (cross-table deps) — note trigger 20 (`trg_lifebook_person_context_completeness`) **must be** `CREATE CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED`
- [ ] **T-C21** Pass C: trg_claim_numeric_unit_check — **last trigger; must follow Batch 8 seed**

### Migration 0003 — Phases 6–9

- [ ] **P6** RLS enablement: 25 tables (ALTER TABLE ... ENABLE ROW LEVEL SECURITY)
- [ ] **P7-A** Group A: 16 DELETE-denied policies (USING (FALSE))
- [ ] **P7-B** Group B: 1 UPDATE immutability policy
- [ ] **P7-C** Group C: 19 LifeBook-scoped SELECT policies (policies 1–15, 66–68, 70)
- [ ] **P7-D** Group D: 12 INSERT and AI restriction policies (policies 30–36, 41, 47, 51, 69, 71)
- [ ] **P7-E** Group E: 7 cultural/classification policies (policies 37–40, 42–44)
- [ ] **P7-F** Group F: 3 DisplayPolicy lifecycle policies (policies 45, 46, 48)
- [ ] **P7-G** Group G: 3 governance policies (policies 50, 52, 53)
- [ ] **P7-H** Group H: 10 LifeBook entity access policies (policies 54–58, 60–64)
- [ ] **P8-1** REVOKE EXECUTE FROM PUBLIC for all 9 functions
- [ ] **P8-2** Per-role EXECUTE grants (per SECURITY_DEFINER_REVIEW.md table)
- [ ] **P8-3** Content table grants by role
- [x] ~~**P8-4** REVOKE SELECT on file_storage_references.object_key~~ **DEFERRED — W11 resolved (DP Decision 2026-07-25)**
- [ ] **P9** Run all 11 validation queries — all must pass before COMMIT

### Post-Commit

- [ ] COMMIT
- [ ] Phase 10 (post-commit): record migration hash, confirm Supabase green, git commit, update PRE_SQL_READINESS_REVIEW.md gate

---

## §7. Implementation Warnings

Ordered by severity. These are documented risks requiring heightened attention during authoring and review.

### CRITICAL

**W1 — fn_has_contest_standing dynamic SQL**
This SECURITY DEFINER function accepts a table name as TEXT and executes a dynamic JOIN. The whitelist of 9 permitted table names must be hard-coded in the function body. Any unrecognized table name must `RAISE EXCEPTION`, not return FALSE. A missing or incorrect whitelist check combined with SECURITY DEFINER privileges = SQL injection in a privilege-escalation context. This function must be independently reviewed before the migration is applied.

**W2 — RLS recursion boundaries**
Four pairs of functions and tables have fatal circular-call potential. Violation produces infinite recursion that fails at runtime, not at authoring time.
- `authority_assignments` RLS must NOT call `fn_has_active_authority`
- `display_policies` and `display_policy_rules` RLS must NOT call `fn_display_policy_allows`
- `contest_records` SELECT RLS must NOT call `fn_has_contest_standing`

Verify these constraints explicitly during Group E, F, and G policy authoring. The policy names that are at risk: policies 15, 25, 50, 52 — spot-check these against VOCABULARY_RLS_MATRIX.md §2.

**W3 — Cultural AI exclusion AND/OR**
Policies 37–40 must use AND when filtering `access_classification = 'culturally_governed'`. Using OR instead of AND would grant agent_service access to all records on those tables, not just non-culturally-governed ones. This is Architectural Invariant 7. Review these four policy USING clauses in isolation after authoring.

### HIGH

**W4 — trg_lifebook_person_context_completeness trigger type**
Must be `CREATE CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED`. A plain AFTER trigger fires after each INSERT row, which will block the normal transaction pattern where `lifebook_entities` and `lifebook_person_contexts` are inserted in the same transaction. The CONSTRAINT TRIGGER fires at COMMIT, when both rows exist. This is the most common trigger-type authoring error.

**W5 — Deferred FK insertion points are inline, not at file end**
All three deferred FKs must appear at the specified points within Phase 1. FK3 is added within Batch 5 (after `approval_policies`, before `conflict_resolution_policies`). FK2 is added immediately after Batch 6. FK1 is added immediately after `claims` DDL within Batch 10. Moving any of these to a final ALTER TABLE block at the end of the file creates a window where FK-constrained columns are unchecked during batch execution.

**W6 — trg_claim_numeric_unit_check must be Pass C (after seed)**
This trigger reads `claim_predicates` at INSERT/UPDATE time. If created before the ClaimPredicate seed is committed, it evaluates against an empty table and will silently pass all numeric unit validations. Position in the file (Pass C, after Batch 8 seed) is the enforcement mechanism — it is documented in a required file comment. Do not move it earlier.

**W7 — uq_lifebook_entities_active must be a partial unique index**
`CREATE UNIQUE INDEX uq_lifebook_entities_active ON lifebook_entities(lifebook_id, entity_id) WHERE removed_at IS NULL`
NOT `ALTER TABLE lifebook_entities ADD UNIQUE (lifebook_id, entity_id)`. The table-level UNIQUE constraint would permanently block re-adding a soft-deleted entity. The partial index only enforces uniqueness for active (non-removed) participation records.

### MEDIUM

**W8 — fn_generate_artifact_signed_url stub**
The stub body must return NULL without referencing `file_storage_references`. That table may not exist at migration time. SECURITY DEFINER frame, search_path, ownership, and EXECUTE revocation must all be correct even in stub form — only the body is a stub.

**W9 — trg_source_dna_classification coerce vs. raise behavior**
Two code paths:
- `source_type = 'dna_analysis'` AND `access_classification IS NULL` → coerce silently to 'restricted'
- `source_type = 'dna_analysis'` AND `access_classification IS NOT NULL` AND ≠ 'restricted' → RAISE (explicit intent conflict)
Do not implement this as a simple coerce-always trigger. The RAISE path is required.

**W10 — created_by_system placeholder in seed records**
All 111+ seed INSERT records must carry `created_by_system = 'migration:<actual_filename>'`. The filename is known once the timestamp is assigned (checklist step 3.0). Update this value before finalizing the seed sections. A find-and-replace after the file is drafted is acceptable but must be done before the migration is applied.

**W11 — File_storage_references column grant — ✅ RESOLVED (DP Decision 2026-07-25)**
Option B adopted: `REVOKE SELECT ON file_storage_references.object_key` is removed from Migration 0003 Phase 8. `file_storage_references` is a storage integration concern, not part of the LifeBook core schema. Column-level restrictions on storage metadata are deferred to the storage integration migration where `file_storage_references` is formally introduced and governed. No placeholder tables. No exception-swallowing logic. No impact on core schema authoring.

**W12 — authority_assignments NULL lifebook_id and policy 50**
`authority_assignments.lifebook_id` is nullable. Entity-scoped assignments have `lifebook_id = NULL`. RLS policy 50 (`pol_authority_assignments_update_revocation_only`) was confirmed to cover entity-scoped NULL rows per VOCABULARY_RLS_MATRIX.md, but the revocation of entity-scoped assignments "must go through a SECURITY DEFINER function" per the registry. Confirm at authoring time that the USING clause in policy 50 correctly handles NULL lifebook_id, or document that entity-scoped revocations are application-layer only.

### REQUIRES PRE-DEPLOYMENT AUDIT

**W13 — fn_generate_artifact_signed_url full implementation**
The stub is deliberately incomplete. Per ADR-0003.md and SECURITY_DEFINER_REVIEW.md: the full implementation requires an independent security audit before the function is enabled in production. The stub satisfies the migration; the audit is a production gate, not a migration gate.

---

## §8. Source Document → SQL Object Mapping

Every SQL object in both migrations has a source document. No orphan objects. No objects without specified enforcement locations.

| SQL Object Class | Source Document | Specification Completeness |
|---|---|---|
| Migration 0002 enums (3) | MIGRATION_IMPLEMENTATION_PLAN.md §1.2 | Complete — exact values |
| display_contexts table + seed | MIGRATION_IMPLEMENTATION_PLAN.md §1.2, §1.4 | Complete — all 9 records with values |
| Tables (50) — DDL field specs | DATABASE_OBJECT_REGISTRY.md, ANCHOR_MODELS.md, CONTENT_LAYER.md, PERSON_ATTRIBUTE_CATALOGUE.md | Complete for all tables; lifebook_entities and lifebook_person_contexts have explicit field-level DDL specs in registry |
| Deferred FKs (3) | DATABASE_OBJECT_REGISTRY.md Constraints section | Complete — constraint names, insertion points |
| Indexes (8) | MIGRATION_0003_SKELETON.md Phase 3 | Complete — names, tables, columns, index types |
| Helper functions (9) | SECURITY_DEFINER_REVIEW.md v1.0 | Complete for all — per-function body specifications exist |
| Triggers (22) | DATABASE_OBJECT_REGISTRY.md Triggers table | Complete — per-trigger invariant specifications |
| RLS policies (71) | VOCABULARY_RLS_MATRIX.md §2 | Complete — USING/WITH CHECK clauses per policy |
| Grants | MIGRATION_0003_SKELETON.md Phase 8 + SECURITY_DEFINER_REVIEW.md | Complete — per-role, per-function, per-table |
| ClaimPredicate seed (74) | CLAIM_PREDICATE_SEED_SPEC.md | Complete — all 74 records with all column values |
| ClaimValueUnit seed (10) | CONTENT_LAYER.md §3.2.2 | Source-documented; field-level authoring in session |
| RelationshipType seed (27) | RELATIONSHIP_TYPE_CATALOGUE.md | Source-documented; field-level authoring in session |
| Jurisdiction seed (6) | OPERATIONAL_MODELS.md §4 | Source-documented; field-level authoring in session |
| Governance seeds | GOVERNANCE_MODELS.md §4.4, §5.5; OPERATIONAL_MODELS.md §2 | Source-documented; field-level authoring in session |
| AI seeds | AI_CONTEXT_BROKER.md §2, §3.2 | Source-documented; field-level authoring in session |

---

## §9. Authorization Request

### What Has Been Completed

All pre-authoring work for both migrations is complete:
- All architectural decisions are resolved (no open design questions)
- All pre-authoring confirmations are satisfied (A, B, C)
- The 74-record ClaimPredicate seed specification is authored and validated (CLAIM_PREDICATE_SEED_SPEC.md)
- The implementation sequence is fully specified across MIGRATION_IMPLEMENTATION_PLAN.md, MIGRATION_0003_SKELETON.md, and DATABASE_OBJECT_REGISTRY.md
- All SQL object names, dependency orders, and enforcement locations are documented
- Implementation warnings are documented and the highest-risk areas are identified

### What Remains

Six seed datasets will be authored inline during the migration session (ClaimValueUnit, RelationshipType, Jurisdictions, AgentRegistry, ContextProfile, and three governance policy seed sets). These are smaller datasets (totalling approximately 50–60 records) that do not require dedicated pre-authoring specification documents. They will be read from source documents during the authoring session.

### Authorization Status — ✅ GRANTED (DP Decision 2026-07-25)

**W11 resolved:** Option B adopted. `REVOKE SELECT ON file_storage_references.object_key` removed from Migration 0003 Phase 8. Column-level restriction deferred to storage integration migration. No placeholder tables. No impact on core schema authoring.

**SQL generation authorized for:**
1. **Migration 0002** (`<TIMESTAMP>_predicate_governance_types.sql`) — 3 enums + 1 table + 9 seed records
2. **Migration 0003** (`<TIMESTAMP>_core_schema.sql`) — full core schema as specified in MIGRATION_0003_SKELETON.md

**Implementation constraints confirmed:**
- MIGRATION_0003_SKELETON.md is the authoritative execution order
- DATABASE_OBJECT_REGISTRY.md is the authoritative object inventory
- VOCABULARY_RLS_MATRIX.md is the authoritative RLS, trigger, and enforcement specification
- CLAIM_PREDICATE_SEED_SPEC.md is the authoritative ClaimPredicate seed source
- Do not modify settled architecture during SQL authoring
- If a contradiction is discovered between approved architecture documents, stop SQL generation and report before proceeding

---

*This document contains no SQL. It is the final pre-authoring governance record. Architecture is frozen.*
