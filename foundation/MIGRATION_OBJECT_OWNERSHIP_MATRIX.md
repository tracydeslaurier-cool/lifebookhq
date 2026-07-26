# Migration Object Ownership Matrix

**Project:** LifeBook HQ
**Migrations covered:** 0001, 0002, 0003
**Produced:** 2026-07-26
**Status:** Final — post-boundary-correction

This document records every schema object introduced by Migrations 0001 through 0003.
It distinguishes objects *created* by a migration, objects *referenced* by a migration,
and permissions *applied* by a later migration to an object owned by an earlier migration.

---

## 1. Count Summary

### A. Migration-Specific Object Counts

| Object Type | M0001 creates | M0002 creates | M0003 creates | Total |
|---|---|---|---|---|
| ENUM types | 39 | 3 | 0 | **42** |
| Tables | 39 | 1 | 49 | **89** |
| Functions | 0 | 0 | 31 | **31** |
| Triggers | 0 | 0 | 22 | **22** |
| Indexes | 0 | 0 | 15 | **15** |
| Deferred FKs (file-order) | 0 | 0 | 4 | **4** |
| CONSTRAINT TRIGGERs (SQL-deferrable) | 0 | 0 | 1 | **1** |
| RLS policies | 39 | 0 | 71 | **110** |
| GRANT statements | 0 | 0 | 64 | **64** |
| Roles created | 0 | 0 | 1 | **1** |
| ALTER OWNER statements | 0 | 0 | 8 | **8** |

### B. Migration-Specific Seed Counts

| Table | M0001 seeds | M0002 seeds | M0003 seeds | Total rows |
|---|---|---|---|---|
| `claim_value_units` | **11** | — | **0** | 11 |
| `display_contexts` | — | **9** | — | 9 |
| `jurisdictions` | — | — | **6** | 6 |
| `escalation_policies` | — | — | **7** | 7 |
| `approval_policies` | — | — | **5** | 5 |
| `conflict_resolution_policies` | — | — | **4** | 4 |
| `claim_predicates` | — | — | **74** | 74 |
| `relationship_types` | — | — | **27** | 27 |
| `agent_registry` | — | — | **9** | 9 |
| `context_profiles` | — | — | **2** | 2 |
| 39 M0001 vocabulary tables (other) | **327** | — | — | 327 |

**Migration-specific seed totals:** M0001 = 338, M0002 = 9, M0003 = 134
**Cumulative seed records after 0001–0003:** 481

### C. Cumulative Totals After Migrations 0001–0003

| Object Type | Count | Note |
|---|---|---|
| ENUM types | 42 | 39 from M0001, 3 from M0002 |
| Tables | 89 | 39 from M0001, 1 from M0002, 49 from M0003 |
| Functions | 31 | All from M0003 |
| Triggers | 22 | All from M0003 |
| Indexes (explicit) | 15 | All from M0003 |
| Deferred FKs (file-order ALTER TABLE) | 4 | All from M0003 |
| CONSTRAINT TRIGGER (SQL-deferrable) | 1 | M0003: trg_lifebook_person_context_completeness |
| RLS-enabled tables | 25 | All from M0003 (M0001 tables use non-ENABLE approach) |
| RLS policies | 110 | 39 from M0001, 71 from M0003 |
| Roles | 1 | M0003: governance_functions role |
| GRANT statements | 64 | All from M0003 |
| Seed records (total) | 481 | 338 from M0001, 9 from M0002, 134 from M0003 |

---

## 2. ENUM Types (42 total)

| # | Type Name | Owner Migration | Consumer Migrations | Authoritative Source |
|---|---|---|---|---|
| 1 | `evidence_status` | **M0001** | M0003 (claim_evidence.evidence_status) | Source architecture docs |
| 2 | `precision_status` | **M0001** | M0003 (claims.precision_status) | Source architecture docs |
| 3 | `dispute_status` | **M0001** | M0003 (claims.dispute_status, relationships.dispute_status) | Source architecture docs |
| 4 | `review_status` | **M0001** | M0003 (claims.review_status) | Source architecture docs |
| 5 | `entity_type` | **M0001** | M0003 (claim_predicates.permitted_entity_types, entities.entity_type) | Source architecture docs |
| 6 | `canonical_status` | **M0001** | M0003 (persons.canonical_status, organizations.canonical_status, places.canonical_status) | Source architecture docs |
| 7 | `suppression_state` | **M0001** | M0003 (claims.suppression_state, relationships.suppression_state) | Source architecture docs |
| 8 | `erasure_state` | **M0001** | M0003 (various) | Source architecture docs |
| 9 | `merge_operation_type` | **M0001** | M0003 (merge_records.operation_type) | Source architecture docs |
| 10 | `visibility_status` | **M0001** | M0003 (various) | Source architecture docs |
| 11 | `contribution_status` | **M0001** | M0003 (various) | Source architecture docs |
| 12 | `verification_status` | **M0001** | M0003 (various) | Source architecture docs |
| 13 | `lifebook_status` | **M0001** | M0003 (lifebooks.status) | Source architecture docs |
| 14 | `lifebook_visibility` | **M0001** | M0003 (lifebooks.visibility) | Source architecture docs |
| 15 | `subject_scope` | **M0001** | M0003 (various) | Source architecture docs |
| 16 | `stewardship_type` | **M0001** | M0003 (various) | Source architecture docs |
| 17 | `account_status` | **M0001** | M0003 (user_profiles.account_status) | Source architecture docs |
| 18 | `cross_lifebook_authorization_status` | **M0001** | M0003 (cross_lifebook_authorizations.status) | Source architecture docs |
| 19 | `entity_match_status` | **M0001** | M0003 (entities.match_status) | Source architecture docs |
| 20 | `entity_match_review_outcome` | **M0001** | M0003 (various) | Source architecture docs |
| 21 | `composition_status` | **M0001** | M0003 (narratives.composition_status) | Source architecture docs |
| 22 | `narrative_parent_relationship` | **M0001** | M0003 (narrative_entities.parent_relationship) | Source architecture docs |
| 23 | `narrative_attribution_status` | **M0001** | M0003 (narratives.attribution_status) | Source architecture docs |
| 24 | `claim_text_validity_state` | **M0001** | M0003 (claims.text_validity_state) | Source architecture docs |
| 25 | `artifact_validity_state` | **M0001** | M0003 (artifacts.validity_state) | Source architecture docs |
| 26 | `claim_predicate_permitted_value_type` | **M0001** | M0003 (claim_predicates.permitted_value_type) | Source architecture docs |
| 27 | `unit_category` | **M0001** | M0001 (claim_value_units.unit_category); M0003 trigger reads via FK | Source architecture docs |
| 28 | `coordination_rule` | **M0001** | M0003 (various governance) | Source architecture docs |
| 29 | `succession_behaviour` | **M0001** | M0003 (various governance) | Source architecture docs |
| 30 | `governance_lifecycle_condition` | **M0001** | M0003 (display_policies.lifecycle_condition) | Source architecture docs |
| 31 | `resolution_rule` | **M0001** | M0003 (conflict_resolution_policies.resolution_rule) | Source architecture docs |
| 32 | `approval_record_status` | **M0001** | M0003 (approval_records.status) | Source architecture docs |
| 33 | `escalation_default_action` | **M0001** | M0003 (escalation_policies.default_action) | Source architecture docs |
| 34 | `contest_status` | **M0001** | M0003 (contest_records.status) | Source architecture docs |
| 35 | `contest_resolution_type` | **M0001** | M0003 (contest_records.resolution_type) | Source architecture docs |
| 36 | `contest_access_mode` | **M0001** | M0003 (various) | Source architecture docs |
| 37 | `guardian_coordination_presumption` | **M0001** | M0003 (jurisdictions.guardian_coordination_presumption) | Source architecture docs |
| 38 | `jurisdiction_review_status` | **M0001** | M0003 (jurisdiction_policy_versions.review_status) | Source architecture docs |
| 39 | `person_name_derivative_type` | **M0001** | M0003 (person_name_derivatives.derivative_type) | Source architecture docs |
| 40 | `relationship_interaction_type` | **M0002** | M0003 (claim_predicates.relationship_interaction_type) | CONTENT_LAYER.md §3 |
| 41 | `display_policy_status` | **M0002** | M0003 (display_policies.status) | DISPLAY_POLICY_MODEL.md |
| 42 | `display_policy_decision` | **M0002** | M0003 (display_policies.decision) | DISPLAY_POLICY_MODEL.md |

---

## 3. Tables (89 total)

### 3.1 Migration 0001 Tables (39) — Vocabulary / Reference

All 39 tables are read-only vocabulary catalogues. RLS policies created but tables use
ON CONFLICT DO NOTHING seed guards (M0001 predates the strict no-ON CONFLICT philosophy).
M0003 applies GRANT SELECT to these tables via bulk GRANT statements.

| # | Table | Seeded | RLS Enabled | Records | M0003 References |
|---|---|---|---|---|---|
| 1 | `access_classifications` | Yes | Policy only¹ | 5 | GRANT SELECT (M0003) |
| 2 | `participation_roles` | Yes | Policy only¹ | 12 | GRANT SELECT (M0003) |
| 3 | `authority_contexts` | Yes | Policy only¹ | 6 | GRANT SELECT (M0003) |
| 4 | `link_types` | Yes | Policy only¹ | 7 | GRANT SELECT (M0003) |
| 5 | `submission_origins` | Yes | Policy only¹ | 4 | GRANT SELECT (M0003) |
| 6 | `narrative_types` | Yes | Policy only¹ | 10 | GRANT SELECT (M0003) |
| 7 | `content_types` | Yes | Policy only¹ | 6 | GRANT SELECT (M0003) |
| 8 | `source_types` | Yes | Policy only¹ | 21 | GRANT SELECT (M0003) |
| 9 | `artifact_types` | Yes | Policy only¹ | 13 | GRANT SELECT (M0003) |
| 10 | `storage_providers` | Yes | Policy only¹ | 6 | GRANT SELECT (M0003) |
| 11 | `file_storage_roles` | Yes | Policy only¹ | 6 | GRANT SELECT (M0003) |
| 12 | `artifact_source_relationships` | Yes | Policy only¹ | 6 | GRANT SELECT (M0003) |
| 13 | `participant_roles` | Yes | Policy only¹ | 17 | GRANT SELECT (M0003) |
| 14 | `event_types` | Yes | Policy only¹ | 22 | GRANT SELECT (M0003) |
| 15 | `authority_basis_types` | Yes | Policy only¹ | 4 | GRANT SELECT (M0003) |
| 16 | `conflict_resolution_purposes` | Yes | Policy only¹ | 10 | GRANT SELECT (M0003) |
| 17 | `escalation_trigger_types` | Yes | Policy only¹ | 3 | GRANT SELECT (M0003) |
| 18 | `contest_types` | Yes | Policy only¹ | 10 | GRANT SELECT (M0003) |
| 19 | `jurisdiction_types` | Yes | Policy only¹ | 6 | GRANT SELECT (M0003) |
| 20 | `person_name_usage_types` | Yes | Policy only¹ | 14 | GRANT SELECT (M0003) |
| 21 | `source_derivative_types` | Yes | Policy only¹ | 6 | GRANT SELECT (M0003) |
| 22 | `data_conflict_types` | Yes | Policy only¹ | 6 | GRANT SELECT (M0003) |
| 23 | `organization_types` | Yes | Policy only¹ | 10 | GRANT SELECT (M0003) |
| 24 | `creation_sources` | Yes | Policy only¹ | 5 | GRANT SELECT (M0003) |
| 25 | `place_types` | Yes | Policy only¹ | 12 | GRANT SELECT (M0003) |
| 26 | `coordinate_precisions` | Yes | Policy only¹ | 6 | GRANT SELECT (M0003) |
| 27 | `vessel_types` | Yes | Policy only¹ | 7 | GRANT SELECT (M0003) |
| 28 | `community_types` | Yes | Policy only¹ | 7 | GRANT SELECT (M0003) |
| 29 | `series_types` | Yes | Policy only¹ | 6 | GRANT SELECT (M0003) |
| 30 | `creation_reasons` | Yes | Policy only¹ | 6 | GRANT SELECT (M0003) |
| 31 | `mention_roles` | Yes | Policy only¹ | 8 | GRANT SELECT (M0003) |
| 32 | `authority_roles` | Yes | Policy only¹ | 13 | GRANT SELECT (M0003) |
| 33 | `action_types` | Yes | Policy only¹ | 24 | GRANT SELECT (M0003) |
| 34 | `person_name_derivation_methods` | Yes | Policy only¹ | 5 | GRANT SELECT (M0003) |
| 35 | `pronoun_set_types` | Yes | Policy only¹ | 8 | GRANT SELECT (M0003) |
| 36 | `evidence_roles` | Yes | Policy only¹ | 1 | GRANT SELECT (M0003) |
| 37 | `erasure_regimes` | Yes | Policy only¹ | 1 | GRANT SELECT (M0003) |
| 38 | `authority_context_policy_conditions` | Yes | Policy only¹ | 8 | GRANT SELECT (M0003) |
| 39 | `claim_value_units` | Yes | Policy only¹ | 11 | FK target (claims.value_unit_code); GRANT SELECT (M0003); trigger reads (M0003) |

¹ M0001 creates RLS policies (vocab_read_authenticated) on all 39 tables but does NOT issue
ALTER TABLE ENABLE ROW LEVEL SECURITY. The policies are present but dormant. Tables are
readable without RLS enforcement at the PostgreSQL level.

### 3.2 Migration 0002 Tables (1)

| # | Table | Seeded | RLS Enabled | Records | M0003 References |
|---|---|---|---|---|---|
| 1 | `display_contexts` | Yes | No | 9 | FK target (display_policy_rules.display_context_code); GRANT SELECT (M0003) |

### 3.3 Migration 0003 Tables (49) — Core Schema

| # | Table | Seeded | RLS Enabled | Records | Prerequisite Dependencies |
|---|---|---|---|---|---|
| 1 | `jurisdictions` | Yes | No | 6 | jurisdiction_types (M0001) |
| 2 | `jurisdiction_policy_versions` | No | No | — | jurisdictions (M0003) |
| 3 | `user_profiles` | No | No | — | auth.users (Supabase), account_status (M0001) |
| 4 | `entities` | No | No | — | lifebooks (M0003), entity_type (M0001) |
| 5 | `persons` | No | No | — | entities (M0003), canonical_status (M0001) |
| 6 | `organizations` | No | No | — | entities (M0003) |
| 7 | `places` | No | No | — | entities (M0003) |
| 8 | `vessels` | No | No | — | entities (M0003) |
| 9 | `communities` | No | No | — | entities (M0003) |
| 10 | `event_series` | No | No | — | entities (M0003) |
| 11 | `lifebooks` | No | No | — | user_profiles (M0003), lifebook_status (M0001) |
| 12 | `lifebook_memberships` | No | Yes | — | lifebooks (M0003), user_profiles (M0003) |
| 13 | `user_person_links` | No | No | — | user_profiles (M0003), persons (M0003) |
| 14 | `lifebook_entities` | No | Yes | — | lifebooks (M0003), entities (M0003) |
| 15 | `lifebook_person_contexts` | No | Yes | — | lifebook_entities (M0003), persons (M0003), approval_policies (M0003, deferred FK) |
| 16 | `escalation_policies` | Yes | No | 7 | escalation_trigger_types (M0001) |
| 17 | `approval_policies` | Yes | No | 5 | governance_lifecycle_condition (M0001) |
| 18 | `conflict_resolution_policies` | Yes | No | 4 | conflict_resolution_purposes (M0001) |
| 19 | `display_policies` | No | Yes | — | lifebooks (M0003), approval_records (M0003, deferred FK), display_policy_status (M0002) |
| 20 | `display_policy_rules` | No | Yes | — | display_policies (M0003), display_contexts (M0002) |
| 21 | `approval_records` | No | Yes | — | approval_policies (M0003), approval_record_status (M0001) |
| 22 | `authority_assignments` | No | Yes | — | authority_roles (M0001), claims (M0003, deferred FK) |
| 23 | `claim_predicates` | Yes | No | 74 | relationship_interaction_type (M0002), claim_predicate_permitted_value_type (M0001) |
| 24 | `relationship_types` | Yes | No | 27 | None (self-referential inverse FK) |
| 25 | `agent_registry` | Yes | No | 9 | None |
| 26 | `context_profiles` | Yes | No | 2 | None |
| 27 | `sources` | No | Yes | — | lifebooks (M0003), user_profiles (M0003), source_types (M0001) |
| 28 | `claims` | No | Yes | — | entities (M0003), lifebooks (M0003), claim_predicates (M0003), claim_value_units (M0001), user_profiles (M0003), display_policies (M0003), context_manifests (M0003, deferred FK) |
| 29 | `claim_evidence` | No | Yes | — | claims (M0003), sources (M0003), evidence_roles (M0001) |
| 30 | `relationships` | No | Yes | — | entities (M0003), lifebooks (M0003), relationship_types (M0003) |
| 31 | `narratives` | No | Yes | — | lifebooks (M0003), entities (M0003) |
| 32 | `narrative_entities` | No | Yes | — | narratives (M0003), entities (M0003) |
| 33 | `events` | No | Yes | — | lifebooks (M0003), entities (M0003), event_types (M0001) |
| 34 | `event_participants` | No | Yes | — | events (M0003), entities (M0003) |
| 35 | `artifacts` | No | Yes | — | lifebooks (M0003), sources (M0003), storage_providers (M0001) |
| 36 | `artifact_source_links` | No | Yes | — | artifacts (M0003), sources (M0003) |
| 37 | `context_manifests` | No | Yes | — | agent_registry (M0003), context_profiles (M0003) |
| 38 | `source_derivatives` | No | Yes | — | sources (M0003), source_derivative_types (M0001) |
| 39 | `merge_records` | No | No | — | entities (M0003), user_profiles (M0003) |
| 40 | `cross_lifebook_authorizations` | No | No | — | lifebooks (M0003), user_profiles (M0003) |
| 41 | `lifebook_source_access` | No | No | — | lifebooks (M0003), sources (M0003) |
| 42 | `contest_records` | No | Yes | — | lifebooks (M0003), user_profiles (M0003), contest_types (M0001) |
| 43 | `escalation_records` | No | No | — | contest_records (M0003), escalation_policies (M0003) |
| 44 | `escalation_notifications` | No | No | — | escalation_records (M0003), user_profiles (M0003) |
| 45 | `access_policy_changed_events` | No | Yes | — | display_policies (M0003) |
| 46 | `person_names` | No | Yes | — | persons (M0003), person_name_usage_types (M0001) |
| 47 | `person_name_derivatives` | No | Yes | — | person_names (M0003), person_name_derivative_type (M0001) |
| 48 | `person_pronouns` | No | Yes | — | persons (M0003), pronoun_set_types (M0001) |
| 49 | `person_gender_descriptors` | No | Yes | — | persons (M0003) |

---

## 4. Functions (31 total — all Migration 0003)

All 31 functions are created in Migration 0003. None exist in M0001 or M0002.
8 of 9 public helper functions are SECURITY DEFINER with SET search_path = 'public', pg_temp.
`fn_user_is_agent` is NOT SECURITY DEFINER.

| # | Function | Type | SECURITY DEFINER | Owner | Grantees | Source |
|---|---|---|---|---|---|---|
| 1 | `fn_user_is_agent` | Public helper | No | governance_functions | authenticated, agent_service, system_service | M0003 |
| 2 | `fn_lb_membership_role` | Public helper | Yes | governance_functions | authenticated, agent_service, system_service | M0003 |
| 3 | `fn_is_subject_of` | Public helper | Yes | governance_functions | authenticated | M0003 |
| 4 | `fn_has_active_authority` | Public helper | Yes | governance_functions | authenticated, system_service | M0003 |
| 5 | `fn_display_policy_allows` | Public helper | Yes | governance_functions | authenticated, agent_service, system_service | M0003 |
| 6 | `fn_has_source_access_grant` | Public helper | Yes | governance_functions | authenticated | M0003 |
| 7 | `fn_has_community_authorization` | Public helper | Yes | governance_functions | authenticated, system_service | M0003 |
| 8 | `fn_has_contest_standing` | Public helper | Yes | governance_functions | authenticated | M0003 |
| 9 | `fn_generate_artifact_signed_url` | Public helper (STUB) | Yes | governance_functions | authenticated | M0003 |
| 10 | `_fn_trg_claim_value_not_null` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 11 | `_fn_trg_claim_ai_provenance` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 12 | `_fn_trg_claim_content_immutable` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 13 | `_fn_trg_relationship_content_immutable` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 14 | `_fn_trg_source_dna_classification` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 15 | `_fn_trg_source_type_immutable` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 16 | `_fn_trg_source_lifebook_immutable` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 17 | `_fn_trg_event_provenance_immutable` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 18 | `_fn_trg_approval_records_immutable` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 19 | `_fn_trg_authority_assignment_revocation_guard` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 20 | `_fn_trg_display_policies_lifecycle` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 21 | `_fn_trg_display_policies_delete_guard` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 22 | `_fn_trg_claim_supersession_integrity` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 23 | `_fn_trg_relationship_supersession_integrity` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 24 | `_fn_trg_claim_dispute_requires_contest` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 25 | `_fn_trg_relationship_dispute_requires_contest` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 26 | `_fn_trg_display_policy_rules_update_guard` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 27 | `_fn_trg_display_policy_rules_delete_guard` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 28 | `_fn_trg_contest_record_standing_validation` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 29 | `_fn_trg_lifebook_person_context_completeness` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 30 | `_fn_trg_source_derivative_invalidation_cascade` | Trigger function | Yes | governance_functions | Internal only | M0003 |
| 31 | `_fn_trg_claim_numeric_unit_check` | Trigger function | Yes | governance_functions | Internal only | M0003 |

---

## 5. Triggers (22 total — all Migration 0003)

| # | Trigger | Table | Timing | Event | Pass | Type | Source |
|---|---|---|---|---|---|---|---|
| 1 | `trg_claim_value_not_null` | `claims` | BEFORE | INSERT, UPDATE | A | TRIGGER | M0003 |
| 2 | `trg_claim_ai_provenance` | `claims` | BEFORE | INSERT | A | TRIGGER | M0003 |
| 3 | `trg_claim_content_immutable` | `claims` | BEFORE | UPDATE | A | TRIGGER | M0003 |
| 4 | `trg_relationship_content_immutable` | `relationships` | BEFORE | UPDATE | A | TRIGGER | M0003 |
| 5 | `trg_source_dna_classification` | `sources` | BEFORE | INSERT, UPDATE | A | TRIGGER | M0003 |
| 6 | `trg_source_type_immutable` | `sources` | BEFORE | UPDATE | A | TRIGGER | M0003 |
| 7 | `trg_source_lifebook_immutable` | `sources` | BEFORE | UPDATE | A | TRIGGER | M0003 |
| 8 | `trg_event_provenance_immutable` | `events` | BEFORE | UPDATE | A | TRIGGER | M0003 |
| 9 | `trg_approval_records_immutable` | `approval_records` | BEFORE | UPDATE | A | TRIGGER | M0003 |
| 10 | `trg_authority_assignment_revocation_guard` | `authority_assignments` | BEFORE | UPDATE | A | TRIGGER | M0003 |
| 11 | `trg_display_policies_lifecycle` | `display_policies` | BEFORE | INSERT, UPDATE | A | TRIGGER | M0003 |
| 12 | `trg_display_policies_delete_guard` | `display_policies` | BEFORE | DELETE | A | TRIGGER | M0003 |
| 13 | `trg_claim_supersession_integrity` | `claims` | BEFORE | INSERT, UPDATE | B | TRIGGER | M0003 |
| 14 | `trg_relationship_supersession_integrity` | `relationships` | BEFORE | INSERT, UPDATE | B | TRIGGER | M0003 |
| 15 | `trg_claim_dispute_requires_contest` | `claims` | BEFORE | UPDATE | B | TRIGGER | M0003 |
| 16 | `trg_relationship_dispute_requires_contest` | `relationships` | BEFORE | UPDATE | B | TRIGGER | M0003 |
| 17 | `trg_display_policy_rules_update_guard` | `display_policy_rules` | BEFORE | UPDATE | B | TRIGGER | M0003 |
| 18 | `trg_display_policy_rules_delete_guard` | `display_policy_rules` | BEFORE | DELETE | B | TRIGGER | M0003 |
| 19 | `trg_contest_record_standing_validation` | `contest_records` | BEFORE | INSERT, UPDATE | B | TRIGGER | M0003 |
| 20 | `trg_lifebook_person_context_completeness` | `lifebook_entities` | AFTER | INSERT | B | CONSTRAINT TRIGGER DEFERRABLE INITIALLY DEFERRED | M0003 |
| 21 | `trg_source_derivative_invalidation_cascade` | `source_derivatives` | AFTER | UPDATE | B | TRIGGER (STUB) | M0003 |
| 22 | `trg_claim_numeric_unit_check` | `claims` | BEFORE | INSERT, UPDATE | C | TRIGGER (SECURITY DEFINER) | M0003 |

---

## 6. Indexes (15 total — all Migration 0003)

| # | Index | Table | Type | Purpose |
|---|---|---|---|---|
| 1 | `idx_entities_lifebook_id` | `entities` | Performance | Lifebook-scoped entity lookups |
| 2 | `idx_claims_subject_entity_id` | `claims` | Performance | Claims by subject entity |
| 3 | `idx_claims_predicate_id` | `claims` | Performance | Claims by predicate type |
| 4 | `idx_relationships_entity_a` | `relationships` | Performance | Relationships by first entity |
| 5 | `idx_relationships_entity_b` | `relationships` | Performance | Relationships by second entity |
| 6 | `idx_authority_assignments_entity_id` | `authority_assignments` | Performance | Authority by entity |
| 7 | `idx_context_manifests_agent_code` | `context_manifests` | Performance | Context manifests by agent |
| 8 | `uq_lifebook_entities_active` | `lifebook_entities` | Partial UNIQUE (WHERE removed_at IS NULL) | Enforces no duplicate active entity in lifebook |
| 9 | `idx_lifebook_memberships_user_lifebook` | `lifebook_memberships` | Performance | Membership by user+lifebook |
| 10 | `idx_authority_assignments_role_entity` | `authority_assignments` | Performance | Authority by role+entity |
| 11 | `idx_authority_assignments_expiry` | `authority_assignments` | Performance | Authority expiry range queries |
| 12 | `idx_claims_lifebook_review_access` | `claims` | Performance | Claims by lifebook+review_status |
| 13 | `idx_display_policy_rules_policy_context` | `display_policy_rules` | Performance | Policy rules by policy+context |
| 14 | `idx_user_person_links_user_entity` | `user_person_links` | Performance | User-to-person link lookups |
| 15 | `idx_contest_records_contested_record` | `contest_records` | Performance | Contest records by contested object |

---

## 7. Deferred Foreign Keys (4 file-order + 1 SQL-deferrable constraint trigger)

These FKs could not be declared inline because the referenced table did not exist at DDL time.

| # | Constraint | Table | Column | References | Reason for deferral | Owner |
|---|---|---|---|---|---|---|
| 1 | `fk_permission_cache_approval_policy` | `lifebook_person_contexts` | `permission_cache_policy_version_id` | `approval_policies(id)` | lifebook_person_contexts (Batch 4) created before approval_policies (Batch 5) | M0003 |
| 2 | `fk_display_policy_approval_record` | `display_policies` | `approval_record_id` | `approval_records(id)` | display_policies (Batch 5) created before approval_records (Batch 6) | M0003 |
| 3 | `fk_authority_basis_claim` | `authority_assignments` | `basis_claim_id` | `claims(id)` | authority_assignments (Batch 7) created before claims (Batch 10) | M0003 |
| 4 | `fk_claims_context_manifest` | `claims` | `context_manifest_id` | `context_manifests(id)` | context_manifests (Batch 9) but FK declared after claims DDL | M0003 |
| 5 | `trg_lifebook_person_context_completeness` | `lifebook_entities` | — | — | CONSTRAINT TRIGGER DEFERRABLE INITIALLY DEFERRED (fires at COMMIT, not row INSERT) | M0003 |

---

## 8. RLS Policies (110 total)

### 8.1 Migration 0001 (39 policies)

One `vocab_read_authenticated` policy per vocabulary table. All use `FOR SELECT` with
`TO authenticated`. No `USING` filter — deprecated codes remain readable for historical integrity.

| Policy | Table | For | Action |
|---|---|---|---|
| `vocab_read_authenticated` | Each of the 39 vocabulary tables | authenticated | SELECT without WHERE filter |

### 8.2 Migration 0002 (0 policies)

`display_contexts` does not have RLS enabled in Migration 0002.

### 8.3 Migration 0003 (71 policies across 25 RLS-enabled tables)

| # | Policy Name |
|---|---|
| 1 | `pol_claims_delete_denied` |
| 2 | `pol_narratives_delete_denied` |
| 3 | `pol_sources_delete_denied` |
| 4 | `pol_artifacts_delete_denied` |
| 5 | `pol_relationships_delete_denied` |
| 6 | `pol_events_delete_denied` |
| 7 | `pol_approval_records_delete_denied` |
| 8 | `pol_context_manifests_delete_denied` |
| 9 | `pol_access_policy_events_delete_denied` |
| 10 | `pol_authority_assignments_delete_denied` |
| 11 | `pol_contest_records_delete_denied` |
| 12 | `pol_person_names_delete_denied` |
| 13 | `pol_person_pronouns_delete_denied` |
| 14 | `pol_person_gender_delete_denied` |
| 15 | `pol_lifebook_entities_delete_denied` |
| 16 | `pol_lifebook_person_contexts_delete_denied` |
| 17 | `pol_approval_records_update_denied` |
| 18 | `pol_claims_select_lifebook` |
| 19 | `pol_relationships_select_lifebook` |
| 20 | `pol_narratives_select_lifebook` |
| 21 | `pol_narrative_entities_select_lifebook` |
| 22 | `pol_sources_select_lifebook` |
| 23 | `pol_artifacts_select_lifebook` |
| 24 | `pol_events_select_lifebook` |
| 25 | `pol_event_participants_select_lifebook` |
| 26 | `pol_claim_evidence_select_lifebook` |
| 27 | `pol_artifact_source_links_select_lifebook` |
| 28 | `pol_person_names_select_lifebook` |
| 29 | `pol_person_pronouns_select_lifebook` |
| 30 | `pol_person_gender_select_lifebook` |
| 31 | `pol_person_name_derivatives_select` |
| 32 | `pol_authority_assignments_select` |
| 33 | `pol_approval_records_select` |
| 34 | `pol_display_policies_select` |
| 35 | `pol_display_policy_rules_select` |
| 36 | `pol_source_derivatives_select_lifebook` |
| 37 | `pol_claims_ai_promotion_denied` |
| 38 | `pol_claims_ai_dispute_denied` |
| 39 | `pol_narratives_ai_promotion_denied` |
| 40 | `pol_events_insert_agent_denied` |
| 41 | `pol_approval_records_insert_agent_denied` |
| 42 | `pol_sources_insert_agent_denied` |
| 43 | `pol_person_names_insert_agent_denied` |
| 44 | `pol_narratives_community_account_gate` |
| 45 | `pol_display_policies_insert_authorized` |
| 46 | `pol_contest_records_insert_standing` |
| 47 | `pol_person_name_derivatives_insert` |
| 48 | `pol_source_derivatives_insert_system` |
| 49 | `pol_claims_cultural_ai_excluded` |
| 50 | `pol_narratives_cultural_ai_excluded` |
| 51 | `pol_artifacts_cultural_ai_excluded` |
| 52 | `pol_sources_cultural_ai_excluded` |
| 53 | `pol_artifacts_restricted_steward_only` |
| 54 | `pol_artifacts_culturally_governed_authority` |
| 55 | `pol_sources_restricted_steward_only` |
| 56 | `pol_display_policies_delete_non_draft_denied` |
| 57 | `pol_display_policies_update_frozen` |
| 58 | `pol_display_policy_rules_non_draft_denied` |
| 59 | `pol_authority_assignments_update_revocation_only` |
| 60 | `pol_contest_records_select_parties` |
| 61 | `pol_person_name_derivatives_agent_restricted` |
| 62 | `pol_lifebook_entities_select_steward` |
| 63 | `pol_lifebook_entities_select_member_visible` |
| 64 | `pol_lifebook_entities_select_subject_own` |
| 65 | `pol_lifebook_entities_insert_steward` |
| 66 | `pol_lifebook_entities_update_steward` |
| 67 | `pol_lifebook_person_contexts_select_steward` |
| 68 | `pol_lifebook_person_contexts_select_subject` |
| 69 | `pol_lifebook_person_contexts_insert_steward` |
| 70 | `pol_lifebook_person_contexts_update_steward` |
| 71 | `pol_lifebook_person_contexts_update_subject` |

---

## 9. Permission Grants (64 GRANT statements — all Migration 0003)

| Grantee | Privilege | Scope |
|---|---|---|
| `authenticated` | SELECT, INSERT, UPDATE | Core content tables (claims, relationships, narratives, sources, artifacts, events, event_participants, display_policies, display_policy_rules, authority_assignments, contest_records, person_names, person_pronouns, person_gender_descriptors, lifebook_entities, lifebook_person_contexts) |
| `authenticated` | SELECT only | approval_records, person_name_derivatives, context_manifests, access_policy_changed_events, source_derivatives, claim_evidence, artifact_source_links |
| `authenticated` | SELECT | Reference tables: claim_predicates, claim_value_units¹, relationship_types, agent_registry, context_profiles, display_contexts², jurisdictions, jurisdiction_policy_versions, escalation_policies, approval_policies, conflict_resolution_policies, entities, persons, organizations, places, vessels, communities, event_series, user_profiles, lifebooks, lifebook_memberships, user_person_links, merge_records, cross_lifebook_authorizations, lifebook_source_access, escalation_records, escalation_notifications |
| `authenticated` | EXECUTE | All 9 public helper functions |
| `agent_service` | SELECT | claims, narratives, sources, artifacts, events, event_participants, source_derivatives, claim_evidence |
| `agent_service` | INSERT | claims, narratives |
| `agent_service` | EXECUTE | fn_user_is_agent, fn_lb_membership_role, fn_display_policy_allows |
| `system_service` | SELECT | ALL TABLES IN SCHEMA public |
| `system_service` | INSERT | approval_records, context_manifests, source_derivatives, access_policy_changed_events, lifebook_person_contexts, person_name_derivatives |
| `system_service` | UPDATE | lifebook_person_contexts |
| `system_service` | EXECUTE | fn_user_is_agent, fn_lb_membership_role, fn_has_active_authority, fn_display_policy_allows, fn_has_community_authorization |
| `admin` | SELECT | ALL TABLES IN SCHEMA public |

¹ `claim_value_units` is owned by Migration 0001; GRANT SELECT is applied in Migration 0003
  because M0001 does not issue this grant.
² `display_contexts` is owned by Migration 0002; GRANT SELECT is applied in Migration 0003.

---

## 10. Seed Catalogues (481 total records across 49 seed datasets)

| Dataset | Owner Migration | Record Count | Source Authority |
|---|---|---|---|
| 39 vocabulary catalogues (M0001 tables) | M0001 | 327 | ANCHOR_MODELS.md, CONTENT_LAYER.md, GOVERNANCE_MODELS.md, OPERATIONAL_MODELS.md |
| `claim_value_units` | **M0001** | **11** | CONTENT_LAYER.md §3.2.2 |
| `display_contexts` | M0002 | 9 | MIGRATION_IMPLEMENTATION_PLAN.md §1.4 |
| `jurisdictions` | M0003 | 6 | OPERATIONAL_MODELS.md §4 (CA, CA-AB, CA-BC, CA-ON, UA, INTL) |
| `escalation_policies` | M0003 | 7 | GOVERNANCE_MODELS.md |
| `approval_policies` | M0003 | 5 | GOVERNANCE_MODELS.md §4.4 |
| `conflict_resolution_policies` | M0003 | 4 | GOVERNANCE_MODELS.md |
| `claim_predicates` | M0003 | 74 | CLAIM_PREDICATE_CATALOGUE.md |
| `relationship_types` | M0003 | 27 | RELATIONSHIP_TYPE_CATALOGUE.md |
| `agent_registry` | M0003 | 9 | AI_CONTEXT_BROKER.md §3.2 |
| `context_profiles` | M0003 | 2 | AI_CONTEXT_BROKER.md §2 |
| **Total** | | **481** | |

---

## 11. Permissions Applied by Later Migrations to Earlier-Owned Objects

The following permissions are applied by Migration 0003 to objects owned by earlier migrations.
This is intentional — M0001 and M0002 do not include GRANT statements.

| Object | Owner Migration | Permission Applied | Applied In | Rationale |
|---|---|---|---|---|
| `claim_value_units` | M0001 | GRANT SELECT TO authenticated | M0003 | M0001 does not grant to application roles; M0003 grants in bulk |
| All 39 M0001 vocabulary tables | M0001 | GRANT SELECT TO authenticated, agent_service, system_service, admin | M0003 | Same as above |
| `display_contexts` | M0002 | GRANT SELECT TO authenticated | M0003 | M0002 does not grant to application roles |

---

*End of MIGRATION_OBJECT_OWNERSHIP_MATRIX.md*
