# SOURCE_TO_SCHEMA_TYPE_MATRIX.md

**Status:** Pre-approval draft — awaiting Discovery Partner review  
**Date:** 2026-07-23  
**Version:** 4.0  
**Applies to:** All types in `0001_types_and_vocabularies.sql` (v4)

Every type is traced to: authoritative document and section · owning table · owning column · migration that creates the column · classification decision · whether values changed during architecture.

"Values changed" means the value set was modified between initial design and the v2 audit — either wrong values were corrected, values were added, or the type was renamed.

---

## Key

| Symbol | Meaning |
|--------|---------|
| ✓ | Values confirmed stable across architecture work |
| ⚠ | Values changed or corrected during architecture work |
| † | Owning column uses this type via TEXT FK (reference table pattern) |
| ‡ | Owning column is an array — FK enforcement implication noted |
| § | Deferred — type not in 0001 |

---

## Part I: PostgreSQL Enums (39 types)

### Section A — Universal Quality Dimensions

| # | Type | Auth. Document | Section | Owning Table | Column | Migration | Changed? |
|---|------|----------------|---------|-------------|--------|-----------|----------|
| A.1 | `evidence_status` | GOVERNANCE_MODELS.md | §1.1 | Claim; PersonAttribute subtype tables | `evidence_status` | Claim migration | ⚠ Completely wrong values in v1 |
| A.2 | `precision_status` | GOVERNANCE_MODELS.md | §1.2 | Claim | `precision_status` | Claim migration | ✓ |
| A.3 | `dispute_status` | CONTENT_LAYER.md | Core Design Principles | Claim | `dispute_status` | Claim migration | ✓ |
| A.4 | `review_status` | CONTENT_LAYER.md | Core Design Principles | Multiple content tables | `review_status` | Multiple migrations | ✓ |

### Section B — Entity Record States

| # | Type | Auth. Document | Section | Owning Table | Column | Migration | Changed? |
|---|------|----------------|---------|-------------|--------|-----------|----------|
| B.1 | `entity_type` | ANCHOR_MODELS.md | §1.1 | Entity | `entity_type` | Entity migration | ✓ |
| B.2 | `canonical_status` | ANCHOR_MODELS.md | §1.3 | Entity | `canonical_status` | Entity migration | ✓ |
| B.3 | `suppression_state` | ANCHOR_MODELS.md | §1.4 | Entity | `suppression_state` | Entity migration | ✓ |
| B.4 | `erasure_state` | ANCHOR_MODELS.md | §1.2 | Entity | `erasure_state` | Entity migration | ✓ |
| B.5 | `merge_operation_type` | ANCHOR_MODELS.md | §13 | MergeRecord | `operation_type` | MergeRecord migration | ✓ |

### Section C — LifeBook and Anchor Status

| # | Type | Auth. Document | Section | Owning Table | Column | Migration | Changed? |
|---|------|----------------|---------|-------------|--------|-----------|----------|
| C.1 | `visibility_status` | ANCHOR_MODELS.md | §9.3 | LifeBookEntity | `visibility_status` | LifeBook migration | ⚠ 3 values in v1; correct is 5 |
| C.2 | `contribution_status` | ANCHOR_MODELS.md | §10.3 | LifeBookContributor | `contribution_status` | LifeBook migration | ✓ (DP restored to enum) |
| C.3 | `verification_status` | ANCHOR_MODELS.md | §11.2 | UserPersonLink | `verification_status` | User migration | ⚠ `failed_verification` → `rejected` |
| C.4 | `lifebook_status` | ANCHOR_MODELS.md | §8.2 | LifeBook | `lifebook_status` | LifeBook migration | ✓ |
| C.5 | `lifebook_visibility` | ANCHOR_MODELS.md | §8.4 | LifeBook | `visibility` | LifeBook migration | ✓ |
| C.6 | `subject_scope` | ANCHOR_MODELS.md | §8.3 | LifeBook | `subject_scope` | LifeBook migration | ✓ |
| C.7 | `stewardship_type` | ANCHOR_MODELS.md | §8.1 | LifeBook | `stewardship_type` | LifeBook migration | ✓ |
| C.8 | `account_status` | ANCHOR_MODELS.md | §11.1 | User | `account_status` | User migration | ✓ |
| C.9 | `cross_lifebook_authorization_status` | ANCHOR_MODELS.md | §12.4 | CrossLifeBookAuthorization | `status` | CrossLifeBook migration | ✓ |
| C.10 | `entity_match_status` | ANCHOR_MODELS.md | §14.2 | EntityMatchCandidate | `status` | EntityMatch migration | ⚠ Completely wrong values in v1 |
| C.11 | `entity_match_review_outcome` | ANCHOR_MODELS.md | §14.3 | EntityMatchCandidate | `review_outcome` | EntityMatch migration | ⚠ Completely wrong values in v1 |

### Section D — Content Layer States

| # | Type | Auth. Document | Section | Owning Table | Column | Migration | Changed? |
|---|------|----------------|---------|-------------|--------|-----------|----------|
| D.1 | `composition_status` | CONTENT_LAYER.md | §7.4 | Narrative | `composition_status` | Narrative migration | ⚠ `under_review`→`in_review`; `retracted`→`withdrawn` |
| D.2 | `narrative_parent_relationship` | CONTENT_LAYER.md | §7.5 | Narrative | `parent_relationship` | Narrative migration | ✓ |
| D.3 | `narrative_attribution_status` *(renamed from `narrative_authenticity_status`)* | CONTENT_LAYER.md | §7.1 | Narrative | `attribution_status` *(column also renamed)* | Narrative migration | ⚠ Renamed v4 — original name conflated attribution (narrator/author identity) with content authenticity; concerns attribution only |
| D.4 | `claim_text_validity_state` | CONTENT_LAYER.md | §2.1 | Claim (cached display column); Organization, Place, Vessel, Community, EventSeries (cached_display_name_validity_state) | multiple cached columns | Claim migration + entity migrations | ✓ |
| D.5 | `artifact_validity_state` | CONTENT_LAYER.md | §7.1; AI_CONTEXT_BROKER §11.5 | Narrative (AI-generated); SourceDerivative | `validity_state` | Narrative and SourceDerivative migrations | ⚠ Wrong name (`derivative_validity_state`) + wrong values in v1 |
| D.6 | ~~`evidence_role`~~ → see N.14 `evidence_roles` | — | — | — | — | — | Converted to reference table in v4; see Part II N.14 |
| D.7 | `claim_predicate_permitted_value_type` | CONTENT_LAYER.md | §3.1 | ClaimPredicate | `permitted_value_type` | ClaimPredicate migration | ✓ |
| D.8 | `unit_category` | CONTENT_LAYER.md | §3.2.1 | ClaimValueUnit (ref table column) | `unit_category` | 0001 (column within claim_value_units table) | ⚠ Was TEXT in v1; correct is enum; seed values used `length`/`weight` (wrong) |

### Section E — Governance States and Behavioral Rules

| # | Type | Auth. Document | Section | Owning Table | Column | Migration | Changed? |
|---|------|----------------|---------|-------------|--------|-----------|----------|
| E.1 | `coordination_rule` | GOVERNANCE_MODELS.md | §3.4 | ApprovalPolicy; AuthorityAssignment | `coordination_rule` | Governance migration | ✓ |
| E.2 | `succession_behaviour` | GOVERNANCE_MODELS.md | §3.5 | AuthorityAssignment | `succession_behaviour` | Governance migration | ⚠ Completely wrong values in v1 |
| E.3 | `governance_lifecycle_condition` | GOVERNANCE_MODELS.md | §4.2 | ApprovalPolicy | `lifecycle_status` (field named lifecycle_status; type is governance_lifecycle_condition) | Governance migration | ⚠ Wrong name in v1; v4: `cultural_governed` removed (9→8 values) — cultural governance is a separate ApprovalPolicy dimension (GOVERNANCE_MODELS.md §4.5) |
| E.4 | `resolution_rule` | GOVERNANCE_MODELS.md | §5.4 | ConflictResolutionPolicy; data_conflict_types.default_resolution_rule | `resolution_rule`; ref table column | Governance migration | ✓ |
| E.5 | `approval_record_status` | APPROVAL_INSTANCE_MODEL.md | §3 | ApprovalRecord | `status` | Governance migration | ✓ |

### Section F — Operational States and Behavioral Rules

| # | Type | Auth. Document | Section | Owning Table | Column | Migration | Changed? |
|---|------|----------------|---------|-------------|--------|-----------|----------|
| F.1 | `escalation_default_action` | OPERATIONAL_MODELS.md | §1.4 | EscalationPolicy | `default_action` | EscalationPolicy migration | ✓ |
| F.2 | ~~`escalation_resolution_type`~~ → DEFERRED§ | PRE_MIGRATION_CLOSURE.md | — | EscalationRecord | `resolution_type` | EscalationRecord migration | ⚠ Deferred in v4 — EscalationRecord not yet designed; co-deferred with escalation_record_status; see DEFERRED_TYPE_REGISTER §1b |
| F.3 | `contest_status` | OPERATIONAL_MODELS.md | §2.4 | ContestRecord | `status` | ContestRecord migration | ✓ |
| F.4 | `contest_resolution_type` | OPERATIONAL_MODELS.md | §2.5 | ContestRecord | `resolution_type` | ContestRecord migration | ✓ |
| F.5 | `contest_access_mode` | OPERATIONAL_MODELS.md | §2.6 | ContestRecord; contest_types.default_access_mode | `access_mode`; ref table column | ContestRecord migration | ✓ |

### Section G — Jurisdiction States

| # | Type | Auth. Document | Section | Owning Table | Column | Migration | Changed? |
|---|------|----------------|---------|-------------|--------|-----------|----------|
| G.1 | `guardian_coordination_presumption` | OPERATIONAL_MODELS.md | §3.4 | JurisdictionPolicyVersion | `default_guardian_coordination` | Jurisdiction migration | ✓ |
| G.2 | `jurisdiction_review_status` | OPERATIONAL_MODELS.md | §5.1 | JurisdictionPolicyVersion | `review_status` | Jurisdiction migration | ✓ |

### Section H — Attribute Layer Structural Types

| # | Type | Auth. Document | Section | Owning Table | Column | Migration | Changed? |
|---|------|----------------|---------|-------------|--------|-----------|----------|
| H.1 | `person_name_derivative_type` | PERSON_ATTRIBUTE_CATALOGUE.md | — | PersonName | `derivative_type` | PersonName migration | ✓ |

---

## Part II: Reference Tables (39 total)

### Standard Reference Tables — Original 22 (carried from classification)

| # | Table | Auth. Document | Section | Referenced By (table · column) | Migration of FK column |
|---|-------|----------------|---------|-------------------------------|----------------------|
| I.1 | `access_classifications` | CONTENT_LAYER.md | §17 | Source.access_classification_code; ContentRecord.access_classification_code; source_types.default_access_classification_code | Content migrations |
| I.2 | `participation_roles` | ANCHOR_MODELS.md | §9.2 | LifeBookEntity.participation_role_code | LifeBook migration |
| I.3 | `authority_contexts` | ANCHOR_MODELS.md | §10.2 | LifeBookPersonContext.authority_context_code; authority_context_policy_conditions.authority_context_code (0001) | LifeBook migration |
| I.4 | `link_types` | ANCHOR_MODELS.md | §11.3 | UserPersonLink.link_type_code | User migration |
| I.5 | `submission_origins` | CONTENT_LAYER.md | §1.1 | ContentSubmission.submission_origin_code | Content migration |
| I.6 | `narrative_types` | CONTENT_LAYER.md | §7.2 | Narrative.narrative_type_code | Narrative migration |
| I.7 | `content_types` | CONTENT_LAYER.md | §7.3 | Narrative.content_type_code | Narrative migration |
| I.8 | `source_types` | CONTENT_LAYER.md | §9.2 | Source.source_type_code | Source migration |
| I.9 | `artifact_types` | CONTENT_LAYER.md | §12.2 | Artifact.artifact_type_code | Artifact migration |
| I.10 | `storage_providers` | CONTENT_LAYER.md | §13.1 | FileStorageReference.storage_provider_code | FileStorage migration |
| I.11 | `file_storage_roles` | CONTENT_LAYER.md | §13.1 | FileStorageReference.file_storage_role_code | FileStorage migration |
| I.12 | `artifact_source_relationships` | CONTENT_LAYER.md | §14.2 | ArtifactSourceLink.relationship_code | ArtifactSource migration |
| I.13 | `participant_roles` | CONTENT_LAYER.md | §16.2 | EventParticipant.participant_role_code | Event migration |
| I.14 | `event_types` | CONTENT_LAYER.md | §15.2 | Event.event_type_code | Event migration |
| I.15 | `authority_basis_types` | GOVERNANCE_MODELS.md | §2 | AuthorityAssignment.authority_basis_type_code; authority_basis_types.claim_predicate_code (FK deferred to ClaimPredicate migration) | Governance migration |
| I.16 | `conflict_resolution_purposes` | GOVERNANCE_MODELS.md | §5.3 | ConflictResolutionPolicy.purpose_code | Governance migration |
| I.17 | `escalation_trigger_types` | OPERATIONAL_MODELS.md | §1.2 | EscalationPolicy.trigger_type_code | EscalationPolicy migration |
| I.18 | `contest_types` | OPERATIONAL_MODELS.md | §2.2 | ContestRecord.contest_type_code | ContestRecord migration |
| I.19 | `jurisdiction_types` | OPERATIONAL_MODELS.md | §3.2 | Jurisdiction.jurisdiction_type_code | Jurisdiction migration |
| I.20 | `person_name_usage_types` | PERSON_ATTRIBUTE_CATALOGUE.md | — | PersonName.usage_type_code | PersonName migration |
| I.21 | `source_derivative_types` | CONTENT_LAYER.md | §10.1 | SourceDerivative.derivative_type_code | SourceDerivative migration |
| I.22 | `data_conflict_types` | GOVERNANCE_MODELS.md | §5.2 | ConflictResolutionPolicy.conflict_type_code; ConflictRecord.conflict_type_code; data_conflict_types.default_escalation_policy_code (FK deferred) | Governance migration |

### Governed Reference Tables — Original 2

| # | Table | Auth. Document | Section | Referenced By | Migration of FK column |
|---|-------|----------------|---------|--------------|----------------------|
| J.1 | `erasure_regimes` | OPERATIONAL_MODELS.md | §3.3 | Jurisdiction.erasure_regime_code (FK added in Jurisdiction migration) | Jurisdiction migration |
| J.2 | `authority_context_policy_conditions` | DP Decision 2 | — | Application policy-selection logic; no direct FK from entity tables | N/A (lookup table) |

### Unit Reference Table — Original 1

| # | Table | Auth. Document | Section | Referenced By | Notes |
|---|-------|----------------|---------|--------------|-------|
| K.1 | `claim_value_units` | CONTENT_LAYER.md | §3.2 | Claim.unit_code; ClaimPredicate.permitted_unit_code | PK is `unit_code` not `code` |

### Newly Classified as Reference Tables — 14 (13 converted in v3 + 1 in v4)

| # | Table | Auth. Document | Section | Referenced By | Reason for Ref Table | Migration of FK column |
|---|-------|----------------|---------|--------------|----------------------|----------------------|
| N.1 | `organization_types` | ANCHOR_MODELS.md | §3.1 | Organization.organization_type_code† | Extensible; cultural/jurisdictional expansion; hierarchy needed | Organization migration |
| N.2 | `creation_sources` | ANCHOR_MODELS.md | §1.1 | Entity.creation_source_code† | Will expand (institutional import, archival ingest, AI proposal, API, migration); may need provenance metadata | Entity migration |
| N.3 | `place_types` | ANCHOR_MODELS.md | §4.1 | Place.place_type_code† | Categorization vocabulary; will expand (reservation, township, district); localization needed | Place migration |
| N.4 | `coordinate_precisions` | ANCHOR_MODELS.md | §4.1 | Place.coordinate_precision_code† | Categorization for display; not a state machine | Place migration |
| N.5 | `vessel_types` | ANCHOR_MODELS.md | §5.1 | Vessel.vessel_type_code† | Categorization; historical expansion expected (automobile, spacecraft, etc.) | Vessel migration |
| N.6 | `community_types` | ANCHOR_MODELS.md | §6.1 | Community.community_type_code† | Cultural classification; must accommodate Indigenous and international community forms; localization | Community migration |
| N.7 | `series_types` | ANCHOR_MODELS.md | §7.1 | EventSeries.series_type_code† | Categorization; will expand as archival and community forms are supported | EventSeries migration |
| N.8 | `creation_reasons` | ANCHOR_MODELS.md | §8.1 | LifeBook.creation_reason_code† | Categorization; non-structural; will expand (refugee_documentation, institutional_archive) | LifeBook migration |
| N.9 | `mention_roles` | CONTENT_LAYER.md | §8.1 | Mention.mention_role_code† | Categorization for display and attribution; can expand without changing application logic | Mention migration |
| N.10 | `authority_roles` | GOVERNANCE_MODELS.md | §3.2 | AuthorityAssignment.authority_role_code† | Jurisdiction-specific behavior; localization; may expand with new legal instruments | Governance migration |
| N.11 | `action_types` | GOVERNANCE_MODELS.md | §3.3 | `authority_assignment_permitted_actions.action_type_code†` (junction table — see Schema Flag 1) | Extensible set of governed operations; policy metadata needed per action | AuthorityAssignment migration |
| N.12 | `person_name_derivation_methods` | PERSON_ATTRIBUTE_CATALOGUE.md | — | PersonName.derivation_method_code† | Categorization for provenance display; can expand | PersonName migration |
| N.13 | `pronoun_set_types` | PERSON_ATTRIBUTE_CATALOGUE.md | — | PersonPronouns.pronoun_set_type_code† | Expanding vocabulary; localization; custom escape hatch signals openness | PersonPronouns migration |
| N.14 | `evidence_roles` | CONTENT_LAYER.md | §4.1 | ClaimEvidence.evidence_role_code† | *(Converted from enum in v4)* Requires semantic policy fields: may_raise_evidence_status, is_contradictory, is_superseding; allows promotion rules to be data-driven; expansion expected | ClaimEvidence migration |

---

## Part III: Deferred Types

| Type | Would-Be Classification | Owning Table | Owning Column | Reason | See |
|------|------------------------|-------------|--------------|--------|-----|
| `escalation_record_status` | Enum | EscalationRecord | `status` | EscalationRecord not yet designed; state machine provisional | DEFERRED_TYPE_REGISTER §1a |
| `escalation_resolution_type` | Enum | EscalationRecord | `resolution_type` | EscalationRecord not yet designed; valid resolutions depend on terminal-state definition; co-deferred with escalation_record_status | DEFERRED_TYPE_REGISTER §1b |
| `person_lifecycle_status` | TBD (enum or derived field) | Person | `lifecycle_status` (proposed) | Authority/derivation model unresolved; P2 principle may prohibit direct field | DEFERRED_TYPE_REGISTER §2 |
| `source_derivative_type` (enum) | N/A — removed | SourceDerivative | `derivative_type_code` | Duplicate of `source_derivative_types` ref table | DEFERRED_TYPE_REGISTER §3 |

---

## Part IV: Schema Implication Flags

These items require DP review before the owning table's migration is written. They do not block 0001 approval but are recorded here to prevent surprises downstream.

**Flag 1 — `action_types` junction table DECIDED (N.11)**  
**Decision (DP instruction #8, v4):** `AuthorityAssignment.permitted_actions` will be normalized to a junction table rather than an array column. No `TEXT[]` column will be created on AuthorityAssignment.

Junction table definition (to be created in the AuthorityAssignment migration — NOT in 0001):
```sql
CREATE TABLE authority_assignment_permitted_actions (
    authority_assignment_id  UUID        NOT NULL REFERENCES authority_assignments(id) ON DELETE CASCADE,
    action_type_code         TEXT        NOT NULL REFERENCES action_types(code),
    granted_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    granted_by               UUID,       -- nullable FK to User; added when User table exists
    conditions               JSONB,      -- nullable; action-specific conditions
    PRIMARY KEY (authority_assignment_id, action_type_code)
);
```

Rationale: Provides FK enforcement on `action_type_code`, enables per-action auditing of when and by whom each action was granted, and supports action-specific conditions without JSONB on the parent row. Array pattern was rejected: no database-enforced FK on array elements, no per-element grant metadata, harder to query.

This decision is recorded here to prevent AuthorityAssignment migration from reintroducing the array approach. The `action_types` reference table in 0001 is defined in anticipation of this junction table FK.

**Flag 2 — `governance_lifecycle_condition` field naming**  
The column on ApprovalPolicy is named `lifecycle_status` but the type is `governance_lifecycle_condition`. This naming inconsistency should be resolved in the ApprovalPolicy table definition. No action required in 0001.

**Flag 3 — `authority_basis_types.claim_predicate_code` deferred FK**  
This FK column exists in 0001 as a nullable TEXT column without a FK constraint. The FK (`REFERENCES claim_predicates(predicate_code)`) must be added via `ALTER TABLE authority_basis_types ADD CONSTRAINT ...` in the ClaimPredicate migration. If the ClaimPredicate migration is skipped or reordered, the FK will remain unenforceable. Track as OQ-2.

**Flag 4 — `data_conflict_types.default_escalation_policy_code` deferred FK**  
Same pattern as Flag 3. FK added in EscalationPolicy migration. Track as OQ-3.

**Flag 5 — `authority_context_policy_conditions.jurisdiction_code` deferred FK**  
Jurisdiction table created in a later migration. FK added then. Track as OQ-4.

**Flag 6 — `narrative_authenticity_status` semantic overlap**  
`narrative_authenticity_status` (unverified/attested/disputed/confirmed) overlaps semantically with `review_status` (pending/human_reviewed/policy_approved) and `dispute_status` (uncontested/disputed/...). `narrative_authenticity_status` specifically tracks attribution verification — whether the stated narrator/author is confirmed. This is distinct from editorial review (review_status) and content dispute (dispute_status). Retain as separate type but flag for DP to confirm the intended semantic boundary during Narrative table design.
