# ENUM_CLASSIFICATION_AUDIT.md — Version 2.0

**Status:** Pre-approval draft — awaiting Discovery Partner review  
**Supersedes:** v1 (2026-07-22) — original audit, 44 types, systematically wrong values  
**Date:** 2026-07-23  
**Migration file:** `supabase/migrations/0001_types_and_vocabularies.sql`  
**Author:** Claude (Cowork), verified against authoritative design documents  

---

## What Changed from v1

v1 was written from recalled knowledge rather than systematic document reading. It had systematic value errors throughout and wrong enum-vs-reference-table classifications. v2 is built from a complete read of all six authoritative design documents.

**Key corrections from v1:**
- `evidence_status` — completely wrong values (was oral_tradition/documentary/physical_artifact/...)
- `governance_lifecycle_condition` — wrong name (`approval_policy_lifecycle_status`) + wrong values
- `succession_behaviour` — completely wrong values
- `entity_match_status`, `entity_match_review_outcome` — completely wrong values
- `composition_status` — `under_review` → `in_review`; `retracted` → `withdrawn`
- `visibility_status` — 3 values in v1; correct is 5
- `artifact_validity_state` — wrong name (`derivative_validity_state`) + wrong values
- `unit_category` was TEXT in v1; correct is a PostgreSQL enum
- `data_conflict_type` → reference table `data_conflict_types` (DP Decision 1)
- `right_to_erasure` → reference table `erasure_regimes` (DP Decision 4)
- `contribution_status` → RESTORED to enum (DP reversed reference table classification)
- 30+ enum types and 10+ reference tables from v1 were missing entirely

---

## Classification Criteria

**PostgreSQL enum** — Use when:
- Closed set of values that changes only via migration
- No metadata per value needed
- Values are states, not extensible vocabulary
- Used as a column type directly (e.g., `evidence_status evidence_status`)

**Reference table** — Use when:
- Extensible governed vocabulary (new values expected without migration)
- Values carry metadata (descriptions, governance flags, sort order, deprecation)
- Values can be deprecated without removal
- FK typing discipline required across multiple tables

---

## Part I: PostgreSQL Enum Types (57 total)

### Section A — Universal Quality Dimensions
*Source: GOVERNANCE_MODELS.md §1; CONTENT_LAYER.md Core*

| # | Enum Type | Values | Source Section |
|---|-----------|--------|---------------|
| A.1 | `evidence_status` | `unreviewed` / `asserted` / `inferred` / `supported` / `corroborated` | GOVERNANCE_MODELS §1.1 |
| A.2 | `precision_status` | `exact` / `approximate` / `range` / `unknown` | GOVERNANCE_MODELS §1.2 |
| A.3 | `dispute_status` | `uncontested` / `disputed` / `contradicted` / `retracted` / `superseded` | CONTENT_LAYER Core |
| A.4 | `review_status` | `pending` / `human_reviewed` / `policy_approved` | CONTENT_LAYER Core |

### Section B — Entity Classification
*Source: ANCHOR_MODELS.md §1–§14*

| # | Enum Type | Values | Source Section |
|---|-----------|--------|---------------|
| B.1 | `entity_type` | `person` / `organization` / `place` / `vessel` / `community` / `event_series` | ANCHOR_MODELS §1.1 |
| B.2 | `canonical_status` | `canonical` / `candidate` / `merged_into` / `split_from` | ANCHOR_MODELS §1.3 |
| B.3 | `suppression_state` | `active` / `suppressed` / `redacted` / `deletion_pending` | ANCHOR_MODELS §1.4 |
| B.4 | `erasure_state` | `none` / `erasure_requested` / `erasure_in_progress` / `erased` | ANCHOR_MODELS §1.2 |
| B.5 | `creation_source` | `user_created` / `document_extracted` / `system_inferred` / `imported` | ANCHOR_MODELS §1.1 |
| B.6 | `person_lifecycle_status` | `living` / `deceased` / `unknown` / `presumed_deceased` | ANCHOR_MODELS §2.2 |
| B.7 | `place_type` | `country` / `province_state` / `city_town_village` / `neighbourhood` / `street` / `building` / `church` / `cemetery` / `farm_estate` / `geographic_feature` / `other` | ANCHOR_MODELS §4.1 |
| B.8 | `coordinate_precision` | `exact` / `approximate` / `centroid` / `disputed` / `unknown` | ANCHOR_MODELS §4.1 |
| B.9 | `organization_type` | `religious` / `governmental` / `military` / `educational` / `commercial` / `civic` / `community` / `cultural` / `other` | ANCHOR_MODELS §3.1 |
| B.10 | `vessel_type` | `ship` / `steamship` / `sailing_vessel` / `aircraft` / `train` / `other` | ANCHOR_MODELS §5.1 |
| B.11 | `community_type` | `indigenous_nation` / `ethnic_community` / `religious_community` / `geographic_community` / `occupational_community` / `other` | ANCHOR_MODELS §6.1 |
| B.12 | `series_type` | `annual_gathering` / `institutional_record_series` / `migration_wave` / `military_campaign` / `other` | ANCHOR_MODELS §7.1 |
| B.13 | `merge_operation_type` | `merge` / `split` | ANCHOR_MODELS §13 |

### Section C — Anchor / LifeBook Status
*Source: ANCHOR_MODELS.md §8–§14*

| # | Enum Type | Values | Source Section |
|---|-----------|--------|---------------|
| C.1 | `visibility_status` | `visible` / `hidden` / `restricted` / `pending_confirmation` / `anonymized` | ANCHOR_MODELS §9.3 |
| C.2 | `contribution_status` | `active_contributor` / `past_contributor` / `invited` / `declined` / `revoked` / `not_a_contributor` | ANCHOR_MODELS §10.3 · DP restored to enum |
| C.3 | `verification_status` | `unverified` / `pending_verification` / `verified` / `rejected` | ANCHOR_MODELS §11.2 |
| C.4 | `lifebook_status` | `active` / `archived` / `suspended` / `transfer_pending` / `deletion_pending` | ANCHOR_MODELS §8.2 |
| C.5 | `lifebook_visibility` | `private` / `family` / `public_preview` / `published` | ANCHOR_MODELS §8.4 |
| C.6 | `subject_scope` | `individual` / `family` / `community` / `institutional` | ANCHOR_MODELS §8.3 |
| C.7 | `stewardship_type` | `self` / `designated` / `institutional` / `post_mortem` | ANCHOR_MODELS §8.1 |
| C.8 | `creation_reason` | `personal_history` / `family_history` / `memorial` / `community_record` / `other` | ANCHOR_MODELS §8.1 |
| C.9 | `account_status` | `active` / `suspended` / `pending_verification` / `deactivated` | ANCHOR_MODELS §11.1 |
| C.10 | `cross_lifebook_authorization_status` | `active` / `suspended` / `revoked` | ANCHOR_MODELS §12.4 |
| C.11 | `entity_match_status` | `generated` / `pending_review` / `confirmed_same` / `confirmed_distinct` / `insufficient_evidence` / `rejected` / `superseded` | ANCHOR_MODELS §14.2 |
| C.12 | `entity_match_review_outcome` | `merged` / `linked` / `distinct_confirmed` / `deferred` / `no_action` | ANCHOR_MODELS §14.3 |

### Section D — Content Layer
*Source: CONTENT_LAYER.md §2–§17*

| # | Enum Type | Values | Source Section |
|---|-----------|--------|---------------|
| D.1 | `composition_status` | `draft` / `submitted` / `in_review` / `approved` / `archived` / `withdrawn` | CONTENT_LAYER §7.4 |
| D.2 | `narrative_parent_relationship` | `translation` / `revision` / `sanitized_version` / `ai_draft_of` / `excerpt_of` | CONTENT_LAYER §7.5 |
| D.3 | `narrative_authenticity_status` | `unverified` / `attested` / `disputed` / `confirmed` | CONTENT_LAYER §7.1 |
| D.4 | `claim_text_validity_state` | `valid` / `policy_superseded` / `invalidated` | CONTENT_LAYER §2.1 |
| D.5 | `artifact_validity_state` | `valid` / `policy_superseded` / `under_review` / `invalidated` / `expired` | CONTENT_LAYER §7.1; AI_CONTEXT_BROKER §11.5 |
| D.6 | `mention_role` | `subject` / `narrator` / `participant` / `mentioned` / `quoted` / `depicted` / `community` | CONTENT_LAYER §8.1 |
| D.7 | `evidence_role` | `supports` / `corroborates` / `contextualizes` / `contradicts` / `supersedes` | CONTENT_LAYER §4.1 |
| D.8 | `claim_predicate_permitted_value_type` | `text` / `date` / `numeric` / `entity` | CONTENT_LAYER §3.1 |
| D.9 | `unit_category` | `duration` / `distance` / `area` / `mass` / `currency` / `count` / `ratio` / `other` | CONTENT_LAYER §3.2.1 |
| D.10 | `source_derivative_type` | `exact_transcript` / `extracted_claims` / `sanitized_summary` / `identity_resolution_tokens` / `access_metadata` | CONTENT_LAYER §10.1 |

### Section E — Governance
*Source: GOVERNANCE_MODELS.md §3–§5; APPROVAL_INSTANCE_MODEL.md §3*

| # | Enum Type | Values | Source Section |
|---|-----------|--------|---------------|
| E.1 | `authority_role` | `subject` / `guardian_sole` / `guardian_joint` / `supported_decision_maker` / `legal_representative` / `court_appointed_guardian` / `steward` / `executor` / `estate_administrator` / `cultural_authority` / `institutional_authority` / `next_of_kin` | GOVERNANCE_MODELS §3.2 |
| E.2 | `action_type` | `assert_preferred_name` / `assert_legal_name` / `assert_former_name` / `assert_birth_name` / `assert_pronouns` / `assert_gender_descriptor` / `assert_indigenous_name` / `assert_ceremonial_name` / `modify_display_policy` / `modify_export_policy` / `modify_search_policy` / `approve_evidence_promotion` / `approve_ai_promotion` / `approve_merge` / `approve_split` / `approve_publish_living` / `approve_contact` / `approve_share_sensitive` / `approve_posthumous_disclosure` / `transfer_stewardship` / `revoke_access` / `archive_record` / `export_full` | GOVERNANCE_MODELS §3.3 |
| E.3 | `coordination_rule` | `sole` / `joint_unanimous` / `joint_majority` / `joint_any` / `escalate` | GOVERNANCE_MODELS §3.4 |
| E.4 | `succession_behaviour` | `terminate` / `transfer_to_named` / `transfer_to_steward` / `transfer_to_court` / `policy_default` | GOVERNANCE_MODELS §3.5 |
| E.5 | `governance_lifecycle_condition` | `living_with_capacity` / `minor_sole_guardian` / `minor_joint_guardian` / `supported_decision_making` / `legal_representative` / `deceased_with_preferences` / `deceased_without_preferences` / `disputed_authority` / `cultural_governed` | GOVERNANCE_MODELS §4.2 |
| E.6 | `resolution_rule` | `subject_wins` / `documented_preference_wins` / `highest_evidence_status` / `most_recent` / `documentary_over_oral` / `steward_decides` / `freeze_pending_review` / `escalate_external` | GOVERNANCE_MODELS §5.4 |
| E.7 | `approval_record_status` | `draft` / `pending` / `approved` / `rejected` / `expired` / `superseded` | APPROVAL_INSTANCE_MODEL §3 |

### Section F — Operational
*Source: OPERATIONAL_MODELS.md §1–§2*

| # | Enum Type | Values | Source Section |
|---|-----------|--------|---------------|
| F.1 | `escalation_default_action` | `freeze` / `deny` / `apply_policy_default` / `route_to_steward` / `route_external` / `terminate_agent_run` | OPERATIONAL_MODELS §1.4 |
| F.2 | `escalation_record_status` | `pending` / `in_progress` / `waiting_external` / `resolved` / `cancelled` / `expired` / `superseded` | SCHEMA_INVENTORY Group 1 — **PLACEHOLDER** (EscalationRecord not yet designed; OPERATIONAL_MODELS §4.1) |
| F.3 | `escalation_resolution_type` | `step_resolved` / `default_action_applied` / `external_resolution` / `manual_steward_resolution` / `cancelled_by_resolution_of_trigger` / `cancelled_by_steward` | PRE_MIGRATION_CLOSURE.md |
| F.4 | `contest_status` | `open` / `under_review` / `pending_external` / `resolved` / `closed_without_resolution` / `superseded` | OPERATIONAL_MODELS §2.4 |
| F.5 | `contest_resolution_type` | `authority_determination` / `consent_agreement` / `external_legal` / `community_decision` / `steward_decision` / `withdrawn` / `subject_asserts` | OPERATIONAL_MODELS §2.5 |
| F.6 | `contest_access_mode` | `read_only_all_parties` / `read_only_steward_only` / `frozen` / `per_party_isolation` | OPERATIONAL_MODELS §2.6 |

### Section G — Jurisdiction
*Source: OPERATIONAL_MODELS.md §3–§5*

| # | Enum Type | Values | Source Section |
|---|-----------|--------|---------------|
| G.1 | `guardian_coordination_presumption` | `joint_unanimous` / `joint_any` / `unclear` | OPERATIONAL_MODELS §3.4 |
| G.2 | `jurisdiction_review_status` | `draft` / `legally_reviewed` / `approved` / `superseded` | OPERATIONAL_MODELS §5.1 |

### Section H — Attribute Layer
*Source: PERSON_ATTRIBUTE_CATALOGUE.md*

| # | Enum Type | Values | Source Section |
|---|-----------|--------|---------------|
| H.1 | `person_name_derivative_type` | `transliteration` / `translation` | PERSON_ATTRIBUTE_CATALOGUE |
| H.2 | `person_name_derivation_method` | `subject_provided` / `community_provided` / `automated` / `scholarly` | PERSON_ATTRIBUTE_CATALOGUE |
| H.3 | `pronoun_set_type` | `she_her` / `he_him` / `they_them` / `she_they` / `he_they` / `custom` / `unspecified` | PERSON_ATTRIBUTE_CATALOGUE |

---

## Part II: Reference Tables (25 total)

Reference tables follow the standard base pattern: `code`, `display_label`, `description`, `is_active`, `deprecated_at`, `replaced_by_code`, `sort_order`, `created_at`. Several have additional domain columns noted below.

| # | Table | Seed Count | Extra Columns | Source Section | Decision |
|---|-------|-----------|---------------|----------------|----------|
| I.1 | `access_classifications` | 5 | `requires_context_profile_code` | CONTENT_LAYER §17 | — |
| I.2 | `participation_roles` | 11 | `applies_to_entity_types TEXT[]` | ANCHOR_MODELS §9.2 | candidate_match removed |
| I.3 | `authority_contexts` | 12 | — | ANCHOR_MODELS §10.2 | — |
| I.4 | `link_types` | 7 | `requires_verification BOOLEAN` | ANCHOR_MODELS §11.3 | — |
| I.5 | `submission_origins` | 9 | `default_evidence_status evidence_status`, `default_review_status review_status` | CONTENT_LAYER §1.1 | Typed FK (enum, not TEXT) |
| I.6 | `narrative_types` | 9 | `requires_ai_review BOOLEAN` | CONTENT_LAYER §7.2 | — |
| I.7 | `content_types` | 5 | — | CONTENT_LAYER §7.3 | — |
| I.8 | `source_types` | 20 | `default_access_classification_code TEXT REFERENCES access_classifications`, `dna_restricted BOOLEAN` | CONTENT_LAYER §9.2 | Typed FK |
| I.9 | `artifact_types` | 12 | — | CONTENT_LAYER §12.2 | — |
| I.10 | `storage_providers` | 5 | — | CONTENT_LAYER §13.1 | — |
| I.11 | `file_storage_roles` | 5 | — | CONTENT_LAYER §13.1 | DP Decision 3: renamed from `file_derivative_relationships`; FK column renamed to `file_storage_role_code` |
| I.12 | `artifact_source_relationships` | 5 | — | CONTENT_LAYER §14.2 | — |
| I.13 | `participant_roles` | 16 | — | CONTENT_LAYER §16.2 | — |
| I.14 | `event_types` | 21 | — | CONTENT_LAYER §15.2 | — |
| I.15 | `authority_basis_types` | 14 | `requires_documentary_basis BOOLEAN`, `claim_predicate_code TEXT` (FK deferred) | GOVERNANCE_MODELS §2 | FK to ClaimPredicate added via ALTER TABLE in later migration |
| I.16 | `conflict_resolution_purposes` | 9 | — | GOVERNANCE_MODELS §5.3 | — |
| I.17 | `escalation_trigger_types` | 11 | `freezes_actions BOOLEAN` | OPERATIONAL_MODELS §1.2 | — |
| I.18 | `contest_types` | 9 | `default_access_mode contest_access_mode` | OPERATIONAL_MODELS §2.2 | Typed FK (enum) |
| I.19 | `jurisdiction_types` | 5 | — | OPERATIONAL_MODELS §3.2 | — |
| I.20 | `person_name_usage_types` | 13 | `requires_cultural_authority BOOLEAN`, `subject_only_assertion BOOLEAN` | PERSON_ATTRIBUTE_CATALOGUE | — |
| I.21 | `source_derivative_types` | 5 | `contains_personal_data BOOLEAN` | CONTENT_LAYER §10.1 | — |
| I.22 | `data_conflict_types` | 5 | `default_resolution_rule resolution_rule`, `default_escalation_policy_code TEXT` (FK deferred) | GOVERNANCE_MODELS §5.2 | DP Decision 1: converted from enum `data_conflict_type` |
| J.1 | `erasure_regimes` | 4 | `permits_full_erasure`, `permits_structural_tombstone`, `permits_audit_event_retention`, `requires_derivative_deletion`, `requires_search_deindexing`, `legal_review_required`, `reviewed_at`, `effective_from`, `effective_until` | OPERATIONAL_MODELS §3.3 | DP Decision 4: converted from enum `right_to_erasure` |
| J.2 | `authority_context_policy_conditions` | 12 | `authority_context_code FK`, `governance_lifecycle_condition enum`, `priority`, `jurisdiction_code` (FK deferred), `effective_from/until` | DP Decision 2 | Mapping table; replaces renaming of governance_lifecycle_condition values |
| K.1 | `claim_value_units` | 11 | `unit_category unit_category` (enum FK), `requires_qualifier BOOLEAN`, `deprecated_at DATE` | CONTENT_LAYER §3.2 | PK is `unit_code` not `code`; unit_category uses enum |

---

## Part III: Source-to-SQL Matrix

Every type with its authoritative document and the section where values can be verified.

| Type | Classification | Authoritative Document | Section |
|------|---------------|----------------------|---------|
| `evidence_status` | Enum | GOVERNANCE_MODELS.md | §1.1 |
| `precision_status` | Enum | GOVERNANCE_MODELS.md | §1.2 |
| `dispute_status` | Enum | CONTENT_LAYER.md | Core Design Principles |
| `review_status` | Enum | CONTENT_LAYER.md | Core Design Principles |
| `entity_type` | Enum | ANCHOR_MODELS.md | §1.1 |
| `canonical_status` | Enum | ANCHOR_MODELS.md | §1.3 |
| `suppression_state` | Enum | ANCHOR_MODELS.md | §1.4 |
| `erasure_state` | Enum | ANCHOR_MODELS.md | §1.2 |
| `creation_source` | Enum | ANCHOR_MODELS.md | §1.1 |
| `person_lifecycle_status` | Enum | ANCHOR_MODELS.md | §2.2 |
| `place_type` | Enum | ANCHOR_MODELS.md | §4.1 |
| `coordinate_precision` | Enum | ANCHOR_MODELS.md | §4.1 |
| `organization_type` | Enum | ANCHOR_MODELS.md | §3.1 |
| `vessel_type` | Enum | ANCHOR_MODELS.md | §5.1 |
| `community_type` | Enum | ANCHOR_MODELS.md | §6.1 |
| `series_type` | Enum | ANCHOR_MODELS.md | §7.1 |
| `merge_operation_type` | Enum | ANCHOR_MODELS.md | §13 |
| `visibility_status` | Enum | ANCHOR_MODELS.md | §9.3 |
| `contribution_status` | Enum (restored) | ANCHOR_MODELS.md | §10.3 |
| `verification_status` | Enum | ANCHOR_MODELS.md | §11.2 |
| `lifebook_status` | Enum | ANCHOR_MODELS.md | §8.2 |
| `lifebook_visibility` | Enum | ANCHOR_MODELS.md | §8.4 |
| `subject_scope` | Enum | ANCHOR_MODELS.md | §8.3 |
| `stewardship_type` | Enum | ANCHOR_MODELS.md | §8.1 |
| `creation_reason` | Enum | ANCHOR_MODELS.md | §8.1 |
| `account_status` | Enum | ANCHOR_MODELS.md | §11.1 |
| `cross_lifebook_authorization_status` | Enum | ANCHOR_MODELS.md | §12.4 |
| `entity_match_status` | Enum | ANCHOR_MODELS.md | §14.2 |
| `entity_match_review_outcome` | Enum | ANCHOR_MODELS.md | §14.3 |
| `composition_status` | Enum | CONTENT_LAYER.md | §7.4 |
| `narrative_parent_relationship` | Enum | CONTENT_LAYER.md | §7.5 |
| `narrative_authenticity_status` | Enum | CONTENT_LAYER.md | §7.1 |
| `claim_text_validity_state` | Enum | CONTENT_LAYER.md | §2.1 |
| `artifact_validity_state` | Enum | CONTENT_LAYER.md | §7.1; AI_CONTEXT_BROKER §11.5 |
| `mention_role` | Enum | CONTENT_LAYER.md | §8.1 |
| `evidence_role` | Enum | CONTENT_LAYER.md | §4.1 |
| `claim_predicate_permitted_value_type` | Enum | CONTENT_LAYER.md | §3.1 |
| `unit_category` | Enum | CONTENT_LAYER.md | §3.2.1 |
| `source_derivative_type` | Enum | CONTENT_LAYER.md | §10.1 |
| `authority_role` | Enum | GOVERNANCE_MODELS.md | §3.2 |
| `action_type` | Enum | GOVERNANCE_MODELS.md | §3.3 |
| `coordination_rule` | Enum | GOVERNANCE_MODELS.md | §3.4 |
| `succession_behaviour` | Enum | GOVERNANCE_MODELS.md | §3.5 |
| `governance_lifecycle_condition` | Enum | GOVERNANCE_MODELS.md | §4.2 |
| `resolution_rule` | Enum | GOVERNANCE_MODELS.md | §5.4 |
| `approval_record_status` | Enum | APPROVAL_INSTANCE_MODEL.md | §3 |
| `escalation_default_action` | Enum | OPERATIONAL_MODELS.md | §1.4 |
| `escalation_record_status` | Enum (placeholder) | SCHEMA_INVENTORY.md | Group 1 — EscalationRecord not yet designed |
| `escalation_resolution_type` | Enum | PRE_MIGRATION_CLOSURE.md | — |
| `contest_status` | Enum | OPERATIONAL_MODELS.md | §2.4 |
| `contest_resolution_type` | Enum | OPERATIONAL_MODELS.md | §2.5 |
| `contest_access_mode` | Enum | OPERATIONAL_MODELS.md | §2.6 |
| `guardian_coordination_presumption` | Enum | OPERATIONAL_MODELS.md | §3.4 |
| `jurisdiction_review_status` | Enum | OPERATIONAL_MODELS.md | §5.1 |
| `person_name_derivative_type` | Enum | PERSON_ATTRIBUTE_CATALOGUE.md | — |
| `person_name_derivation_method` | Enum | PERSON_ATTRIBUTE_CATALOGUE.md | — |
| `pronoun_set_type` | Enum | PERSON_ATTRIBUTE_CATALOGUE.md | — |
| `access_classifications` | Ref table | CONTENT_LAYER.md | §17 |
| `participation_roles` | Ref table | ANCHOR_MODELS.md | §9.2 |
| `authority_contexts` | Ref table | ANCHOR_MODELS.md | §10.2 |
| `link_types` | Ref table | ANCHOR_MODELS.md | §11.3 |
| `submission_origins` | Ref table | CONTENT_LAYER.md | §1.1 |
| `narrative_types` | Ref table | CONTENT_LAYER.md | §7.2 |
| `content_types` | Ref table | CONTENT_LAYER.md | §7.3 |
| `source_types` | Ref table | CONTENT_LAYER.md | §9.2 |
| `artifact_types` | Ref table | CONTENT_LAYER.md | §12.2 |
| `storage_providers` | Ref table | CONTENT_LAYER.md | §13.1 |
| `file_storage_roles` | Ref table | CONTENT_LAYER.md | §13.1 |
| `artifact_source_relationships` | Ref table | CONTENT_LAYER.md | §14.2 |
| `participant_roles` | Ref table | CONTENT_LAYER.md | §16.2 |
| `event_types` | Ref table | CONTENT_LAYER.md | §15.2 |
| `authority_basis_types` | Ref table | GOVERNANCE_MODELS.md | §2 |
| `conflict_resolution_purposes` | Ref table | GOVERNANCE_MODELS.md | §5.3 |
| `escalation_trigger_types` | Ref table | OPERATIONAL_MODELS.md | §1.2 |
| `contest_types` | Ref table | OPERATIONAL_MODELS.md | §2.2 |
| `jurisdiction_types` | Ref table | OPERATIONAL_MODELS.md | §3.2 |
| `person_name_usage_types` | Ref table | PERSON_ATTRIBUTE_CATALOGUE.md | — |
| `source_derivative_types` | Ref table | CONTENT_LAYER.md | §10.1 |
| `data_conflict_types` | Ref table (DP Decision 1) | GOVERNANCE_MODELS.md | §5.2 |
| `erasure_regimes` | Ref table (DP Decision 4) | OPERATIONAL_MODELS.md | §3.3 |
| `authority_context_policy_conditions` | Mapping table (DP Decision 2) | DP Decision 2 | — |
| `claim_value_units` | Ref table | CONTENT_LAYER.md | §3.2 |

---

## Part IV: Machine Validation Results

Validation run against `0001_types_and_vocabularies.sql` on 2026-07-23.

| Check | Result |
|-------|--------|
| SQL parses successfully (pglast) | PASS |
| 57 enum types present | PASS |
| All 57 enum types wrapped in idempotent `DO $$ BEGIN ... EXCEPTION WHEN duplicate_object THEN NULL; END $$` | PASS |
| All 25 INSERT statements have `ON CONFLICT DO NOTHING` | PASS |
| No duplicate codes within any seed block | PASS |
| All enum value counts match authoritative documents (57/57) | PASS |
| All `replaced_by_code` FKs reference own table | PASS |
| UPDATE for `dna_analysis` default access classification present | PASS |
| Typed enum columns in reference tables use enum types (not TEXT) | PASS |

---

## Part V: Final Object Counts

| Category | Count |
|----------|-------|
| PostgreSQL enum types | 57 |
| Standard reference tables (base pattern) | 22 |
| Governed reference tables (special schema) | 2 (`erasure_regimes`, `authority_context_policy_conditions`) |
| Mapping table | 1 (`authority_context_policy_conditions`) |
| ClaimValueUnit table | 1 |
| **Total reference/mapping tables** | **25** |

**Seed row breakdown:**

| Table | Seeds |
|-------|-------|
| access_classifications | 5 |
| participation_roles | 11 |
| authority_contexts | 12 |
| link_types | 7 |
| submission_origins | 9 |
| narrative_types | 9 |
| content_types | 5 |
| source_types | 20 |
| artifact_types | 12 |
| storage_providers | 5 |
| file_storage_roles | 5 |
| artifact_source_relationships | 5 |
| participant_roles | 16 |
| event_types | 21 |
| authority_basis_types | 14 |
| conflict_resolution_purposes | 9 |
| escalation_trigger_types | 11 |
| contest_types | 9 |
| jurisdiction_types | 5 |
| person_name_usage_types | 13 |
| source_derivative_types | 5 |
| data_conflict_types | 5 |
| erasure_regimes | 4 |
| authority_context_policy_conditions | 12 |
| claim_value_units | 11 |
| **Total** | **~253** |

---

## Part VI: Known Open Items

These issues exist in the broader migration plan but do not block 0001 approval:

| ID | Issue | Status | Blocks |
|----|-------|--------|--------|
| G2 | `PersonName.confidence` diverges from `evidence_status` canonical values | Open | PersonName excluded from 0001 |
| G3 | FK terminology corrections across several tables | Open | Later migrations |
| OQ-1 | EscalationRecord table not yet designed; `escalation_record_status` values are placeholders | Open | EscalationRecord migration |
| OQ-2 | `authority_basis_types.claim_predicate_code` FK not yet wired; ClaimPredicate does not yet exist | Open | ClaimPredicate migration |
| OQ-3 | `data_conflict_types.default_escalation_policy_code` FK not yet wired; EscalationPolicy does not yet exist | Open | EscalationPolicy migration |
| OQ-4 | `authority_context_policy_conditions.jurisdiction_code` FK not yet wired; Jurisdiction table in core-schema migration (0003) | Open | Jurisdiction migration |
| OQ-5 | Jurisdiction seeds (CA, CA-AB, CA-ON, CA-BC, CA-QC, UA, EU, INTL) not seeded in 0001 | Open | Jurisdiction migration |
| ADR-0001 | 7 new ClaimPredicate entries needed (per ADR-0001 basis_claim_id pattern) | Open | CLAIM_PREDICATE_CATALOGUE update |

---

## Part VII: DP Decision Log

| Decision | Original | Resolution | Effect on 0001 |
|----------|----------|------------|----------------|
| DP Decision 1 | `data_conflict_type` enum | Reference table `data_conflict_types` with `default_resolution_rule`, `default_escalation_policy_code` | Enum removed; ref table + seeds added |
| DP Decision 2 | Rename `governance_lifecycle_condition` values | Do NOT rename; add `authority_context_policy_conditions` mapping table | Enum values unchanged; mapping table added |
| DP Decision 3 | `file_derivative_relationships` ref table | Renamed to `file_storage_roles`; FK column renamed to `file_storage_role_code` | Ref table renamed in 0001; FK column rename in table migration |
| DP Decision 4 | `right_to_erasure` enum | Reference table `erasure_regimes` with legal governance columns | Enum removed; ref table + seeds added |
| DP Restoration | `contribution_status` ref table | Restored to PostgreSQL enum | Reference table removed; enum added |
| ADR-0001 | `AuthorityBasisRecord` table | Replace with `basis_claim_id → Claim` nullable FK | No direct effect on 0001; deferred ClaimPredicate FK noted |
