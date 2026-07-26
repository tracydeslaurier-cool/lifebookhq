# LifeBook Content Layer
**Version:** 0.3  
**Status:** Pre-schema design document  
**Depends on:** ANCHOR_MODELS.md v0.2, GOVERNANCE_MODELS.md, AI_CONTEXT_BROKER.md, PERSON_ATTRIBUTE_CATALOGUE.md, CLAIM_PREDICATE_CATALOGUE.md v0.2  
**Produced:** 2026-07-23

### Revision history

| Version | Date | Summary | Supersedes |
|---|---|---|---|
| 0.1 | 2026-07-23 | Initial draft | — |
| 0.2 | 2026-07-23 | submission_origin added; ClaimPredicate catalogue; dedicated Relationship model; controlled status vocabulary; Narrative confidence redesign; Source scoping corrected; ArtifactSourceLink; LifeBookSourceAccess; FileStorageReference; translation lineage; event-derived claims policy | 0.1 |
| 0.3 | 2026-07-23 | ClaimValueUnit added (§3.2); value_unit_code / value_unit_qualifier added to Claim; numeric predicate metadata added to ClaimPredicate (§3.1); DB enforcement trigger spec added (§3.5); source_type split (legal_document / court_record); dna_analysis added with §9.3 governance and sub-type classification; civil_partnership_registration added to event_type; seed predicate table corrected and marked non-authoritative; evidence_status and precision_status values defined | 0.2 |

Covers: Submission Origin · Claim · ClaimPredicate · ClaimEvidence · Relationship · RelationshipType · Narrative · NarrativeEntity · Source · SourceDerivative · LifeBookSourceAccess · Artifact · FileStorageReference · ArtifactSourceLink · Event · EventParticipant

---

## Core Design Principles

**Entity references.** All content records target `entity_id → Entity.id` (ANCHOR_MODELS.md §1). No content record carries a raw `person_id`.

**LifeBook scoping.** All content records are scoped to a LifeBook via `lifebook_id`. Every Source has exactly one home LifeBook (`lifebook_id` is NOT NULL on Source). Cross-LifeBook use of sources requires a `LifeBookSourceAccess` record backed by a `CrossLifeBookAuthorization`.

**Four-identity enforcement.** Every content record preserves the distinction between the authenticated User who created it (`created_by_id`), the storyteller who provided the account (`composed_by_entity_id` on Narrative), the subject of the content (`subject_entity_id` or the entity referenced in a claim or event), and the authority holder (resolved at action time via AuthorityAssignment). These must never be conflated by default, trigger, import, or AI process.

**Submission origin.** Every content record carries a `submission_origin` field (§1) that determines default review routing and approval thresholds. Submission origin is set at creation and never changed.

**Controlled status vocabulary.** The following values are canonical across all content records:

- `review_status`: `pending` / `human_reviewed` / `policy_approved`
- `dispute_status`: `uncontested` / `disputed` / `contradicted` / `retracted` / `superseded`

Do not use `approved`, `under_investigation`, or any other values. Investigation belongs to ContestRecord (OPERATIONAL_MODELS.md §2).

**Confidence model.** Content records that make factual assertions carry the applicable dimensions from GOVERNANCE_MODELS.md §1. Not all four dimensions apply to every table; inapplicable dimensions are omitted.

**Claims own facts.** Any value that is changeable, uncertain, temporal, disputed, or sourced must exist as a Claim, not as a direct field on an anchor or subtype table. Display labels may be cached on entity records only if they are explicitly non-authoritative, derived from approved records, carry policy-version lineage, and are invalidated by AccessPolicyChanged.

---

## 1. Submission Origin

Submission origin classifies who or what submitted a content record. It determines default review routing and approval thresholds. It does not grant authority.

### 1.1 submission_origin values

| Value | Description |
|---|---|
| `subject_submission` | The subject entity themselves submitted this content. Accepted as subject assertion; consequential use still follows policy. |
| `authorized_representative_submission` | Submitted by a User holding a verified `representative_of` or `guardian_of` UserPersonLink, within the scope of the applicable AuthorityAssignment. |
| `steward_submission` | Submitted by the LifeBook steward. Human-reviewed by default. Does not override subject-controlled identity attributes. |
| `executor_submission` | Submitted by a User holding `executor_for` UserPersonLink. Accepted only for posthumous or estate-related scope. |
| `family_submission` | Submitted by a User with a family-member relationship to the subject. Pending review. Never overrides subject identity preferences. |
| `contributor_submission` | Submitted by a User with a `contributor_about` link. Pending review; no automatic publication or evidence promotion. |
| `institutional_submission` | Submitted by a User acting on behalf of an institution. Pending review; documentary provenance required. |
| `ai_extracted_submission` | Extracted by an AI agent from source material. `evidence_status = unreviewed`; quarantined pending human review. |
| `system_inferred_submission` | Inferred by a system process (identity resolution, duplicate detection). `evidence_status = inferred`; never self-approved. |

### 1.2 Default review treatment

| Submission origin | Default review treatment |
|---|---|
| `subject_submission` | Accepted as subject assertion; consequential use (publication, cross-LifeBook share) still follows ApprovalPolicy |
| `steward_submission` | `review_status = pending`; escalates to `human_reviewed` after steward confirmation |
| `authorized_representative_submission` | Accepted within AuthorityAssignment scope; out-of-scope submissions require escalation |
| `executor_submission` | Accepted for posthumous scope; flagged for non-posthumous scope |
| `family_submission` | `review_status = pending`; requires steward or representative confirmation |
| `contributor_submission` | `review_status = pending`; no automatic promotion; no publication until `policy_approved` |
| `institutional_submission` | `review_status = pending`; source provenance required before `human_reviewed` |
| `ai_extracted_submission` | `evidence_status = unreviewed`; `review_status = pending`; quarantined from display and AI context |
| `system_inferred_submission` | `evidence_status = inferred`; `review_status = pending`; no display; no AI context supply |

---

## 2. Claim

A Claim is an atomic, independently verifiable factual assertion. It states that a specific subject entity has a specific attribute or stands in a specific relationship to another entity or value. Claims are the atomic unit of knowledge in LifeBook.

Claims are distinct from Narratives (extended human accounts), Events (structured occurrences), and Relationships (persistent connections). A Narrative may imply many claims; those become explicit Claim records when extracted, linked through ClaimEvidence, and reviewed.

### 2.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `lifebook_id` | UUID FK | NOT NULL; scoping field |
| `predicate_id` | UUID FK | References ClaimPredicate.id; the governed predicate of this assertion |
| `subject_entity_id` | UUID FK | References Entity.id; what or who this claim is about |
| `object_entity_id` | UUID FK | Nullable; the other entity in a relational claim |
| `value_text` | Text | Nullable; for non-entity scalar values |
| `value_date` | Date | Nullable; for temporal claims |
| `value_date_precision` | precision_status | Nullable |
| `value_date_end` | Date | Nullable; for date ranges |
| `value_numeric` | Decimal | Nullable |
| `value_unit_code` | Text | Nullable; FK to ClaimValueUnit.unit_code. Required when `value_numeric` is present unless the ClaimPredicate explicitly defines a unitless numeric value (e.g., a count of children). A numeric Claim without a unit is rejected at the application layer if the predicate requires one. |
| `value_unit_qualifier` | Text | Nullable; secondary qualifier for units that require it (e.g., ISO 4217 currency code when `value_unit_code = currency`). Only populated when ClaimValueUnit.requires_qualifier = true. |
| `claim_text_cached` | Text | Nullable; see §2.3; generated display form of the claim |
| `claim_text_access_classification` | Enum | See §8.1; governs display of the cached text |
| `claim_text_policy_version_id` | UUID FK | Nullable; policy version under which the text was generated |
| `claim_text_validity_state` | Enum | `valid` / `policy_superseded` / `invalidated`; invalidated text must not be displayed |
| `claim_text_invalidated_at` | Timestamp | Nullable |
| `evidence_status` | Enum | See GOVERNANCE_MODELS.md §1.1 |
| `precision_status` | Enum | See GOVERNANCE_MODELS.md §1.2 |
| `dispute_status` | Enum | `uncontested` / `disputed` / `contradicted` / `retracted` / `superseded` |
| `review_status` | Enum | `pending` / `human_reviewed` / `policy_approved` |
| `submission_origin` | Enum | See §1.1 |
| `access_classification` | Enum | See §8.1 |
| `display_policy_id` | UUID FK | Nullable; FK → display_policies(id); see DISPLAY_POLICY_MODEL.md |
| `superseded_by_claim_id` | UUID FK | Nullable |
| `ai_generated` | Boolean | Default false |
| `producing_agent_code` | Text | Nullable |
| `context_manifest_id` | UUID FK | Nullable |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | References public.user_profiles |
| `updated_at` | Timestamp | |
| `updated_by_id` | UUID FK | |
| `notes` | Text | Internal steward notes |

### 2.2 Claim constraints

A Claim must have at least one of: `object_entity_id`, `value_text`, `value_date`, `value_numeric`. A Claim with none of these has no assertable content and must be rejected at the database layer.

If `value_numeric` is non-null and the ClaimPredicate does not define a unitless value, then `value_unit_code` must be non-null. If the referenced ClaimValueUnit has `requires_qualifier = true`, then `value_unit_qualifier` must also be non-null. These constraints are enforced at the application layer; a database check constraint may be added in a future migration once ClaimValueUnit is seeded.

If `dispute_status` is `disputed` or `contradicted`, a ContestRecord must exist linking to this Claim.

`ai_generated = true` requires `producing_agent_code` and `context_manifest_id` to be non-null. An AI-generated Claim has `submission_origin = ai_extracted_submission` and may not be promoted to `review_status = policy_approved` without human review.

### 2.3 claim_text_cached

`claim_text_cached` is a generated display form of the claim, derived at presentation time from the predicate and structured fields, using the authorized display identity for the applicable ContextProfile. It must not be treated as a primary record.

If stored (as a cache or pre-rendered form), it must carry access_classification, policy_version, validity_state, and invalidation support — because it may contain former names, restricted dates, restricted places, or sensitive relationship descriptors that are governed by display policy. It is invalidated by AccessPolicyChanged events in the same way as other derived AI artifacts.

The preferred implementation is to generate claim_text at presentation time rather than storing it. If caching is needed for performance, it follows the same lineage requirements as other cached derived fields.

---

## 3. ClaimPredicate

ClaimPredicate is the governed catalogue of claim predicates. `Claim.predicate_id` is a foreign key to this table. Predicates are not stored as free-text strings or PostgreSQL enums; using a reference table allows new predicates to be added without schema migrations.

### 3.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `predicate_code` | Text | Machine-readable identifier (e.g., `born_at`, `married_to`, `employed_by`); unique; immutable |
| `display_label` | Text | Human-readable label (e.g., "Born at", "Married to") |
| `description` | Text | Full description of what this predicate asserts |
| `permitted_subject_entity_types` | Array\<entity_type\> | Which entity types may appear as the subject of a claim with this predicate |
| `permitted_object_entity_types` | Array\<entity_type\> | Nullable; which entity types may appear as object_entity_id |
| `permitted_value_type` | Enum | Nullable; `text` / `date` / `numeric` / `entity`; if null, any scalar value permitted |
| `inverse_predicate_id` | UUID FK | Nullable; self-referential; the logical inverse predicate (e.g., `employed_by` ↔ `employs`) |
| `is_symmetric` | Boolean | If true, A→B implies B→A (e.g., `travelled_with`) |
| `is_transitive` | Boolean | If true, A→B and B→C implies A→C (e.g., `ancestor_of`) |
| `temporal_allowed` | Boolean | Whether effective_from / effective_until apply to this predicate |
| `deprecated_at` | Date | Nullable; when this predicate was retired from new use |
| `replaced_by_predicate_id` | UUID FK | Nullable; self-referential; the replacement predicate when deprecated |
| `numeric_unit_required` | Boolean | Default false. If true, a Claim with this predicate must carry `value_unit_code`. |
| `permitted_unit_categories` | Array\<Text\> | Nullable; if non-null, restricts the ClaimValueUnit.unit_category values allowed for this predicate (e.g., `['duration']` for employment_duration). If null and numeric_unit_required = true, any unit is permitted. |
| `permitted_unit_codes` | Array\<Text\> | Nullable; if non-null, further restricts to specific unit_code values within the permitted categories. |
| `numeric_integer_only` | Boolean | Default false. If true, `value_numeric` must be a whole number for this predicate. Enforced by trigger. |
| `numeric_min_value` | Decimal | Nullable; minimum permitted value for `value_numeric`. |
| `numeric_max_value` | Decimal | Nullable; maximum permitted value for `value_numeric` (e.g., 100 for percentage predicates). |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | |

### 3.2 ClaimValueUnit

ClaimValueUnit is the controlled catalogue of units for numeric Claims. It is a reference table, not an enum, to allow extension without schema migration. A `value_unit_code` on a Claim is a FK to this table.

#### 3.2.1 Fields

| Field | Type | Notes |
|---|---|---|
| `unit_code` | Text | Machine-readable identifier (e.g., `year`, `km`, `currency`); unique; immutable |
| `display_label` | Text | Human-readable label (e.g., "Years", "Kilometres") |
| `unit_category` | Enum | `duration` / `distance` / `area` / `mass` / `currency` / `count` / `ratio` / `other` |
| `requires_qualifier` | Boolean | If true, a qualifier value is required (e.g., currency code for `currency`); stored in a `value_unit_qualifier` text field on Claim |
| `deprecated_at` | Date | Nullable |
| `notes` | Text | Nullable |

#### 3.2.2 Initial seed units

| unit_code | display_label | category | requires_qualifier | notes |
|---|---|---|---|---|
| `year` | Years | duration | No | Elapsed duration in years. Do not use for age assertions; use `age_years`. |
| `month` | Months | duration | No | Elapsed duration in months. |
| `day` | Days | duration | No | Elapsed duration in days. |
| `km` | Kilometres | distance | No | |
| `mile` | Miles | distance | No | |
| `acre` | Acres | area | No | |
| `hectare` | Hectares | area | No | |
| `currency` | Currency | currency | Yes | Qualifier must be a valid ISO 4217 three-letter currency code (e.g., `CAD`, `USD`, `UAH`). Claims using `currency` without a valid qualifier are rejected. |
| `count` | Count | count | No | Used only where the predicate explicitly permits an integer count. The predicate must set `numeric_integer_only = true`. |
| `percentage` | Percentage | ratio | No | Bounded 0–100 unless the predicate explicitly sets `numeric_max_value` to a different value. |
| `age_years` | Age in years | duration | No | Age at an event, observation, source date, or other specific point in time. Distinct from `year`. Do not use `year` for age assertions. |

**Semantic rules for numeric Claims:**
- `year`, `month`, and `day` express elapsed durations. They must not be used for age-at-event assertions; use `age_years`.
- `age_years` is an age-specific semantic unit for a value-at-a-point-in-time assertion. It must not be used for generic duration.
- `count` applies only where the predicate sets `numeric_integer_only = true` and explicitly permits an integer count.
- `percentage` is bounded 0–100 by default. A predicate may override this with `numeric_max_value`.
- `currency` requires a valid ISO 4217 three-letter qualifier in `value_unit_qualifier`. Claims missing or carrying an invalid qualifier are rejected.
- Unit categories must be compatible with the predicate's `permitted_unit_categories` if that field is set.

A numeric Claim whose predicate explicitly defines a unitless value (e.g., a predicate that asserts a birth order or a number of children) does not require value_unit_code. All other numeric Claims must carry a unit.

**`value_unit_qualifier` field note:** A second supplementary field `value_unit_qualifier` (text, nullable) must be added to Claim to carry the qualifier for `currency` and any future unit that requires a secondary code. This field is only populated when `requires_qualifier = true` for the referenced ClaimValueUnit.

---

### 3.3 Seed predicates (illustrative reference only)

> **Authority notice:** This table is a non-authoritative orientation reference. Full predicate semantics, permitted range types, permitted entity types, symmetric/temporal/transitive flags, relationship interaction rules, and event generation rules are defined exclusively in **CLAIM_PREDICATE_CATALOGUE.md**. No entry in this table may override or conflict with the governed catalogue. In case of any conflict, CLAIM_PREDICATE_CATALOGUE.md governs.

Representative predicates include:

| predicate_code | Subject types | Value type | Notes |
|---|---|---|---|
| `born_at` | person | Place entity **only** | Date component is a separate predicate (`born_on`) |
| `born_on` | person | Date **only** | Place component is a separate predicate (`born_at`) |
| `died_at` | person | Place entity **only** | Date component is `died_on` |
| `died_on` | person | Date **only** | Place component is `died_at` |
| `baptised_at` | person | Place entity **only** | Date component is `baptised_on` |
| `baptised_on` | person | Date **only** | Place component is `baptised_at` |
| `married_to` | person | Person entity | Proposes `marriage` Relationship |
| `in_civil_partnership_with` | person | Person entity | Proposes `civil_partnership` Relationship; not interchangeable with `married_to` |
| `parent_of` | person | Person entity | |
| `employed_by` | person | Organization or Person entity | Proposes `employment` Relationship |
| `apprenticed_to` | person | Person or Organization entity | Proposes `apprenticeship` Relationship |
| `member_of` | person, organization | Organization or Community entity | Proposes `organizational_membership` or `community_membership` |
| `resided_at` | person, organization | Place entity | |
| `associated_with` | any | Entity | `relationship_interaction = none`; placeholder; does not create Relationship |
| `founding_date_of` | organization, community, vessel | Date | |
| `dissolved_date_of` | organization, community, vessel | Date | |

See CLAIM_PREDICATE_CATALOGUE.md for all 74 predicates with full specifications.

---

### 3.4 Numeric Claim enforcement trigger

The compatibility rules for numeric Claims are enforced by a PostgreSQL deferred constraint trigger created after ClaimPredicate and ClaimValueUnit seed insertion. This ensures the trigger can query seed data. The trigger fires on INSERT and UPDATE to the Claim table and runs deferred (at transaction end).

**The trigger must reject the following conditions:**

| Condition | Rejection message |
|---|---|
| `value_unit_code` is non-null when `value_numeric` is null | Unit supplied without numeric value |
| `value_numeric` is non-null, predicate has `numeric_unit_required = true`, and `value_unit_code` is null | Numeric Claim requires a unit for this predicate |
| `value_unit_code` is set and `ClaimValueUnit.requires_qualifier = true` but `value_unit_qualifier` is null | Unit requires a qualifier |
| `value_unit_qualifier` is non-null but `ClaimValueUnit.requires_qualifier = false` | Qualifier supplied for unit that does not permit it |
| `value_unit_code = 'currency'` and `value_unit_qualifier` is not a valid ISO 4217 three-letter code | Invalid currency code |
| `predicate.permitted_unit_categories` is non-null and the unit's `unit_category` is not in the permitted list | Unit category incompatible with predicate |
| `predicate.permitted_unit_codes` is non-null and `value_unit_code` is not in the permitted list | Unit not permitted for this predicate |
| `predicate.numeric_integer_only = true` and `value_numeric` is not a whole number | Predicate requires integer value |
| `predicate.numeric_min_value` is non-null and `value_numeric` < `numeric_min_value` | Value below minimum for predicate |
| `predicate.numeric_max_value` is non-null and `value_numeric` > `numeric_max_value` | Value above maximum for predicate |

**Trigger creation timing:** The trigger must be created in a migration step that runs after both the ClaimPredicate seed and the ClaimValueUnit seed are committed. It is a separate migration step, not part of the initial table DDL.

**Trigger name:** `trg_claim_numeric_unit_check` (deferred, per-row, fires on INSERT and UPDATE).

---

## 4. ClaimEvidence

ClaimEvidence links a Claim to the Source material that supports, corroborates, contextualizes, or contradicts it.

### 4.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `claim_id` | UUID FK | |
| `source_id` | UUID FK | The Source providing evidence |
| `source_derivative_id` | UUID FK | Nullable; the specific SourceDerivative that supports this link |
| `evidence_role` | Enum | `supports` / `corroborates` / `contextualizes` / `contradicts` / `supersedes` |
| `evidence_excerpt` | Text | Nullable; the specific portion of the source relevant to this claim |
| `excerpt_location` | Text | Nullable; where in the source (page, timestamp, folio) |
| `added_by_id` | UUID FK | |
| `added_at` | Timestamp | |
| `review_status` | Enum | `pending` / `human_reviewed` / `policy_approved` |
| `notes` | Text | Nullable |

---

## 5. Relationship

Relationship is the dedicated model for persistent, typed connections between entities. Persistent relationships must not be represented only as relational Claims. While a Claim may assert a fact about a relationship, the Relationship record is the primary record of the connection itself.

Relationships are distinct from EventParticipant records (momentary roles in discrete events) and from Claim records (atomic assertions). A marriage is a Relationship; the wedding ceremony is an Event; "married on 11 October 2024" is a Claim supported by ClaimEvidence.

### 5.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `lifebook_id` | UUID FK | NOT NULL; the LifeBook in whose context this relationship is recorded |
| `relationship_type_id` | UUID FK | References RelationshipType.id |
| `entity_a_id` | UUID FK | References Entity.id |
| `entity_b_id` | UUID FK | References Entity.id |
| `role_a` | Text | Nullable; the role entity_a plays in this relationship (e.g., "parent", "employer", "guardian") |
| `role_b` | Text | Nullable; the role entity_b plays in this relationship |
| `effective_from` | Date | Nullable; when the relationship began |
| `effective_from_precision` | precision_status | Nullable |
| `effective_until` | Date | Nullable; when the relationship ended |
| `effective_until_precision` | precision_status | Nullable |
| `is_ongoing` | Boolean | Default true; set to false when effective_until is established |
| `evidence_status` | Enum | Confidence in the relationship's existence |
| `dispute_status` | Enum | `uncontested` / `disputed` / `contradicted` / `retracted` / `superseded` |
| `review_status` | Enum | `pending` / `human_reviewed` / `policy_approved` |
| `submission_origin` | Enum | See §1.1 |
| `access_classification` | Enum | See §8.1 |
| `display_policy_id` | UUID FK | Nullable; FK → display_policies(id); see DISPLAY_POLICY_MODEL.md |
| `ai_generated` | Boolean | Default false |
| `producing_agent_code` | Text | Nullable |
| `context_manifest_id` | UUID FK | Nullable |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | |
| `updated_at` | Timestamp | |
| `updated_by_id` | UUID FK | |
| `notes` | Text | Nullable |

### 5.2 Relationship and Claim interaction

Claims may be made about a Relationship using `predicate_id` targeting a relationship-focused predicate (e.g., a claim asserting the nature of a relationship is disputed). ClaimEvidence links to the Source supporting the relationship's existence. The Relationship record is the subject; the Claims provide the evidence and factual overlay.

---

## 6. RelationshipType

RelationshipType is the governed catalogue of relationship categories. It is a reference table, not an enum, to allow extension without schema migration.

### 6.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `type_code` | Text | Machine-readable identifier; unique; immutable |
| `display_label` | Text | Human-readable label |
| `description` | Text | |
| `permitted_entity_a_types` | Array\<entity_type\> | Which entity types may be entity_a |
| `permitted_entity_b_types` | Array\<entity_type\> | Which entity types may be entity_b |
| `is_symmetric` | Boolean | If true, A→B and B→A represent the same relationship |
| `is_exclusive` | Boolean | If true, entity_a may hold only one active relationship of this type at a time |
| `temporal_allowed` | Boolean | Whether effective_from / effective_until apply |
| `deprecated_at` | Date | Nullable |
| `replaced_by_type_id` | UUID FK | Nullable; self-referential |
| `created_at` | Timestamp | |

### 6.2 Seed relationship types (illustrative)

| type_code | Symmetric | Description |
|---|---|---|
| `biological_parent_child` | No | Biological parenthood |
| `legal_parent_child` | No | Legal parenthood (including where different from biological) |
| `adoptive_parent_child` | No | Adoptive parenthood |
| `guardianship` | No | Legal or informal guardianship |
| `marriage` | Yes | Legally or ceremonially recognized marriage |
| `civil_partnership` | Yes | Civil partnership or equivalent |
| `separation` | Yes | Formal separation; terminates marriage/civil_partnership record |
| `sibling` | Yes | Sibling relationship |
| `employment` | No | Employment (entity_a is employee, entity_b is employer) |
| `military_association` | Yes | Military service connection |
| `community_membership` | No | Membership in a community entity |
| `caregiving` | No | Formal or informal caregiving |
| `friendship` | Yes | Friendship |
| `professional_association` | Yes | Professional or collegial connection |
| `institutional_membership` | No | Membership in an organization |
| `ownership` | No | Ownership of an asset entity |

---

## 7. Narrative

A Narrative is an extended account: a personal recollection, oral history, interview transcript, biographical essay, written memoir, community account, or AI-generated summary. It may describe events, relationships, places, and periods, and may contain factual assertions, opinions, interpretations, and errors simultaneously.

A Narrative is not itself a Claim. It is the human or AI-mediated layer of storytelling from which Claims may be extracted. Factual assertions extracted from a Narrative become Claim records, linked through NarrativeEntity and ClaimEvidence.

### 7.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `lifebook_id` | UUID FK | NOT NULL |
| `title` | Text | Nullable |
| `narrative_type` | Enum | See §7.2 |
| `content_type` | Enum | See §7.3 |
| `composed_by_entity_id` | UUID FK | Nullable; the person or organization who authored or told this narrative; distinct from created_by_id |
| `composed_at` | Date | Approximate; when the narrative was composed or recorded; nullable |
| `composed_at_precision` | precision_status | Nullable |
| `composed_at_location_entity_id` | UUID FK | Nullable |
| `body_text` | Text | The narrative content |
| `body_language` | String | BCP 47 |
| `composition_status` | Enum | See §7.4 |
| `transcription_review_status` | Enum | Nullable; applies to interview transcripts and audio/video records. `pending` / `human_reviewed` / `policy_approved` |
| `authenticity_status` | Enum | Nullable; applies where the origin or attribution of the narrative may be questioned. `unverified` / `attested` / `disputed` / `confirmed` |
| `dispute_status` | Enum | `uncontested` / `disputed` / `contradicted` / `retracted` / `superseded` |
| `review_status` | Enum | `pending` / `human_reviewed` / `policy_approved` |
| `submission_origin` | Enum | See §1.1 |
| `access_classification` | Enum | See §8.1 |
| `display_policy_id` | UUID FK | Nullable; FK → display_policies(id); see DISPLAY_POLICY_MODEL.md |
| `is_restricted_content` | Boolean | If true, body_text requires explicit authorization to access |
| `ai_generated` | Boolean | Default false |
| `producing_agent_code` | Text | Nullable |
| `context_manifest_id` | UUID FK | Nullable |
| `validity_state` | Enum | Nullable; for AI-generated narratives: `valid` / `policy_superseded` / `under_review` / `invalidated` / `expired` |
| `invalidated_at` | Timestamp | Nullable |
| `invalidation_event_id` | UUID FK | Nullable |
| `parent_narrative_id` | UUID FK | Nullable |
| `parent_relationship` | Enum | See §7.5 |
| `translation_metadata` | JSONB | Nullable; see §7.6; required when parent_relationship = `translation` |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | References public.user_profiles; who typed or entered this narrative |
| `updated_at` | Timestamp | |
| `updated_by_id` | UUID FK | |
| `notes` | Text | Internal notes |

Note: `created_by_id` and `composed_by_entity_id` are distinct fields. Tracy (User, created_by_id) may enter a narrative told by Iryna (Entity, composed_by_entity_id). These must never be conflated.

### 7.2 narrative_type values

| Value | Description |
|---|---|
| `personal_recollection` | First-person memory account |
| `family_oral_history` | Story passed down within a family |
| `biographical_essay` | Third-person biographical account |
| `historical_account` | Account of historical events or context |
| `interview_transcript` | Transcribed or recorded interview |
| `written_memoir` | Memoir or autobiographical text |
| `community_account` | Account originating from or authorized by a community |
| `ai_generated_summary` | Summary produced by an AI agent from source material |
| `ai_generated_draft` | AI-drafted narrative awaiting human review |

### 7.3 content_type values (from GOVERNANCE_MODELS.md §8)

| Value | Description |
|---|---|
| `archival_transcript` | Verbatim; attributed; unedited |
| `historical_quotation` | Selected extract in quotation marks with attribution |
| `respectful_presentation` | Steward-authored using approved attribute representations |
| `ai_generated_summary` | AI-produced; requires `review_status = policy_approved` before display or AI reuse |
| `community_account` | Authorized by a community |

### 7.4 composition_status values

| Value | Description |
|---|---|
| `draft` | Not yet complete; not available for review |
| `submitted` | Submitted for review |
| `in_review` | Under active review |
| `approved` | Approved for display per applicable policy |
| `archived` | Preserved but no longer in active display |
| `withdrawn` | Withdrawn by the submitter or steward |

### 7.5 parent_relationship values

| Value | Description |
|---|---|
| `translation` | Translation into a different language; requires translation_metadata |
| `revision` | A revised version of the parent |
| `sanitized_version` | Privacy-sanitized derivative; carries full sanitization lineage |
| `ai_draft_of` | AI draft generated from the parent source or narrative |
| `excerpt_of` | A selected excerpt |

### 7.6 Translation lineage (translation_metadata JSONB)

When `parent_relationship = translation`, `translation_metadata` is required and must contain:

| Key | Type | Notes |
|---|---|---|
| `source_language` | String | BCP 47; the parent narrative's language |
| `target_language` | String | BCP 47; this narrative's language |
| `translator_user_id` | UUID | Nullable; the User who performed the translation |
| `translator_entity_id` | UUID | Nullable; if the translator is an Entity in the system |
| `producing_agent_code` | Text | Nullable; if machine-translated |
| `translation_method` | String | `human` / `machine_translated` / `machine_assisted` |
| `context_manifest_id` | UUID | Nullable; if AI-assisted |
| `synchronization_status` | String | `in_sync` / `parent_updated` / `superseded`; tracks whether the translation is current with the parent |
| `reviewed_at` | Timestamp | Nullable |
| `reviewed_by_id` | UUID | Nullable |

Translations are derivatives. They do not silently replace the parent. The parent record is preserved; the translation links to it. If the parent is updated or invalidated, `synchronization_status` must be updated on all child translations.

---

## 8. NarrativeEntity

NarrativeEntity links Narratives to the Entities they mention, feature, quote, or depict.

### 8.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `narrative_id` | UUID FK | |
| `entity_id` | UUID FK | References Entity.id |
| `mention_role` | Enum | `subject` / `narrator` / `participant` / `mentioned` / `quoted` / `depicted` / `community` |
| `is_restricted_mention` | Boolean | If true, this entity's involvement in this narrative is not surfaced in ordinary display |
| `display_policy_id` | UUID FK | Nullable; FK → display_policies(id); see DISPLAY_POLICY_MODEL.md |
| `added_by_id` | UUID FK | |
| `added_at` | Timestamp | |
| `notes` | Text | Nullable |

---

## 9. Source

A Source is the evidential origin of information: an official document, personal correspondence, oral testimony, archival record, church register, ship manifest, photograph, or any other form of evidence.

Source is the record of an information origin. Artifact (§12) is the record of a preserved object. Some objects are both: a photograph is an artifact and may also be a source. The relationship is recorded in ArtifactSourceLink (§14), not by reciprocal FK fields.

### 9.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `lifebook_id` | UUID FK | NOT NULL; every Source has exactly one home LifeBook. Cross-LifeBook access is through LifeBookSourceAccess (§11), not by making this nullable. |
| `source_type` | Enum | See §9.2 |
| `title` | Text | Nullable |
| `description` | Text | |
| `repository` | Text | Nullable; where the source is held |
| `repository_reference` | Text | Nullable; catalog or archive reference |
| `date_of_source` | Date | Approximate; nullable |
| `date_precision` | precision_status | Nullable |
| `language` | String | BCP 47; nullable |
| `originating_entity_id` | UUID FK | Nullable; who created this source |
| `holding_entity_id` | UUID FK | Nullable; who currently holds the original |
| `jurisdiction_id` | UUID FK | Nullable |
| `submission_origin` | Enum | See §1.1 |
| `access_classification` | Enum | See §8.1 |
| `display_policy_id` | UUID FK | Nullable; FK → display_policies(id); see DISPLAY_POLICY_MODEL.md |
| `review_status` | Enum | `pending` / `human_reviewed` / `policy_approved` |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | |
| `updated_at` | Timestamp | |
| `updated_by_id` | UUID FK | |
| `notes` | Text | Nullable |

### 9.2 source_type values

| Value | Description |
|---|---|
| `personal_recollection` | Individual's spoken or written memory |
| `official_document` | Government-issued document |
| `vital_record` | Birth, death, marriage, or divorce registration |
| `church_register` | Baptism, marriage, burial, or confirmation record |
| `census_record` | Population census or household enumeration |
| `ship_manifest` | Passenger or crew list |
| `military_record` | Service record, pension file, discharge paper |
| `newspaper` | Newspaper article, obituary, or announcement |
| `photograph_metadata` | Information associated with a photograph |
| `audio_recording` | Recorded speech or oral history |
| `video_recording` | Recorded video |
| `letter_correspondence` | Personal or official correspondence |
| `diary_journal` | Personal diary or journal |
| `legal_document` | Will, deed, contract, power of attorney, certificate of title, notarial record. Does not include court records (use `court_record`). |
| `court_record` | Court pleadings, orders, judgments, and decrees, including adoption orders, custody orders, name-change orders, divorce decrees, and hearing records. Default classification: `steward` or `restricted` depending on content and jurisdiction. |
| `institutional_record` | School, hospital, employer, organization record |
| `archival_database` | Record from an archival database |
| `map` | Cartographic document |
| `dna_analysis` | Results or reports from genetic genealogy testing or DNA analysis. **Restricted by default.** See §9.3 for DNA-specific governance. |
| `other` | Any type not otherwise categorized |

### 9.3 DNA analysis source governance

Sources of type `dna_analysis` carry special restrictions that apply from the moment of ingestion regardless of other access_classification settings. All DNA source subtypes default to `access_classification = restricted`. Stewards may not downgrade below `steward`.

#### 9.3.1 DNA source sub-types

The following sub-types must be tracked within `dna_analysis` sources via a `dna_subtype` metadata field (stored in Source.notes or a future structured field until a dedicated column is added):

| Sub-type | Description | Launch status | Processing rules |
|---|---|---|---|
| `raw_genotype_file` | Raw sequence data or SNP array file (e.g., .vcf, .23andme.txt) | **Deploy-disabled. Upload and storage blocked at launch.** | Cannot be uploaded, stored, or processed without a separate approved genetic-data governance policy. |
| `provider_generated_report` | PDF or structured report produced by a DNA testing provider (e.g., AncestryDNA, 23andMe ethnicity report) | May be stored as a restricted Artifact/Source | Excluded from all AI context. No auto-derived Claims. Stored as opaque document; not parsed at launch. |
| `user_entered_match_summary` | A steward or contributor has manually entered a summary of a DNA match or result | May be stored as a restricted Source | Treated as an assertion (`evidence_status = asserted`), not a verified relationship. Requires human review before any Relationship is proposed. |
| `inferred_kinship_suggestion` | A kinship conclusion inferred by a DNA provider algorithm (e.g., "predicted 2nd cousin") | May be recorded, but only as a pending Claim | `evidence_status = inferred`, `review_status = pending`. Must not create a Relationship without human review and corroborating non-DNA evidence where feasible. |
| `reviewed_genetic_claim` | A DNA-derived assertion that has been reviewed by a human steward, supported by corroborating evidence, and promoted | Permitted after human review | May reach `evidence_status = supported` or `corroborated`. Biological Relationship creation permitted only after human review approval. |

#### 9.3.2 Launch restrictions

All of the following apply by default. No configuration setting overrides them without a separate approved genetic-data governance policy:

1. **Raw genotype files cannot be uploaded or processed at launch.** `raw_genotype_file` sub-type is deploy-disabled.
2. **Provider reports may be stored as restricted Artifacts/Sources but are excluded from AI context.** They are not parsed or processed at launch.
3. **User-entered match summaries are assertions, not verified relationships.** They carry `evidence_status = asserted` and require human review before any downstream use.
4. **Inferred kinship suggestions remain pending.** `evidence_status = inferred`, `review_status = pending`. No automatic Relationship creation.
5. **No biological Relationship is created without human review.** For `reviewed_genetic_claim`, corroborating non-DNA evidence is strongly recommended but not strictly required if the reviewer explicitly documents rationale.
6. **No ordinary search indexing.** All `dna_analysis` sources are excluded from general search. Accessible only through direct FK navigation by authorized stewards.
7. **No AI context supply.** All `dna_analysis` sources are excluded from all AI Context Broker ContextManifests.
8. **Related-person privacy.** One person's DNA reveals information about biological relatives who have not consented to LifeBook. Any Claim derived from DNA must be reviewed for secondary privacy impact before promotion.

---

## 10. SourceDerivative

SourceDerivative records sanitized derivatives produced from a Source by the AI Context Broker's SanitizationPipeline (AI_CONTEXT_BROKER.md §5). One source produces up to five derivative types.

### 10.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `source_id` | UUID FK | |
| `derivative_type` | Enum | `exact_transcript` / `extracted_claims` / `sanitized_summary` / `identity_resolution_tokens` / `access_metadata` |
| `content` | Text | Nullable; not populated for identity_resolution_tokens |
| `access_classification` | Enum | See §8.1; may be more restrictive than the source |
| `producing_agent_code` | Text | Nullable |
| `context_manifest_id` | UUID FK | Nullable |
| `review_status` | Enum | `pending` / `human_reviewed` / `policy_approved` |
| `reviewed_by_id` | UUID FK | Nullable |
| `reviewed_at` | Timestamp | Nullable |
| `translation_metadata` | JSONB | Nullable; if this derivative is a translation of another derivative; same structure as §7.6 |
| `validity_state` | Enum | `valid` / `policy_superseded` / `under_review` / `invalidated` / `expired` |
| `invalidated_at` | Timestamp | Nullable |
| `invalidation_event_id` | UUID FK | Nullable |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | |

---

## 11. LifeBookSourceAccess

LifeBookSourceAccess records cross-LifeBook access grants for Source records. A Source belongs to one LifeBook (via `source_id → Source.lifebook_id`). A second LifeBook may access it only through a LifeBookSourceAccess record backed by a CrossLifeBookAuthorization.

### 11.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `source_id` | UUID FK | The source being shared |
| `source_lifebook_id` | UUID FK | Denormalized from Source.lifebook_id; the home LifeBook |
| `recipient_lifebook_id` | UUID FK | The LifeBook being granted access |
| `cross_lifebook_authorization_id` | UUID FK | The CrossLifeBookAuthorization that permits this access |
| `permitted_derivative_types` | Array\<String\> | Which derivative_type values the recipient may receive (subset of SourceDerivative derivative_type) |
| `permitted_data_categories` | Array\<String\> | Which data categories may flow through |
| `effective_from` | Timestamp | |
| `effective_until` | Timestamp | Nullable |
| `status` | Enum | `active` / `suspended` / `revoked` |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | |

---

## 12. Artifact

An Artifact is a preserved object: a photograph, letter, certificate, audio recording, video recording, document, map, recipe, diary, or other physical or digital object of historical significance.

Artifact is about the object's existence and custody, not about its informational content. When an artifact is also used as evidence (i.e., it serves as a Source), the relationship is recorded in ArtifactSourceLink (§14), not by mutual FK fields.

### 12.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `lifebook_id` | UUID FK | NOT NULL |
| `artifact_type` | Enum | See §12.2 |
| `title` | Text | Nullable |
| `description` | Text | |
| `medium` | Text | Nullable; physical medium |
| `date_created` | Date | Approximate; nullable |
| `date_precision` | precision_status | Nullable |
| `creator_entity_id` | UUID FK | Nullable |
| `current_holder_entity_id` | UUID FK | Nullable |
| `original_location_entity_id` | UUID FK | Nullable |
| `file_storage_reference_id` | UUID FK | Nullable; references FileStorageReference.id |
| `submission_origin` | Enum | See §1.1 |
| `access_classification` | Enum | See §8.1 |
| `display_policy_id` | UUID FK | Nullable; FK → display_policies(id); see DISPLAY_POLICY_MODEL.md |
| `review_status` | Enum | `pending` / `human_reviewed` / `policy_approved` |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | |
| `updated_at` | Timestamp | |
| `updated_by_id` | UUID FK | |
| `notes` | Text | Internal steward notes |

### 12.2 artifact_type values

| Value | Description |
|---|---|
| `photograph` | Still image |
| `letter` | Personal or official correspondence |
| `certificate` | Official certificate |
| `audio_recording` | Sound recording |
| `video_recording` | Video recording |
| `document` | Document not otherwise categorized |
| `map` | Cartographic artifact |
| `recipe` | Written recipe |
| `diary_journal` | Personal diary or journal |
| `artwork` | Painting, drawing, illustration, or other artwork |
| `object` | Physical object |
| `other` | Any type not otherwise categorized |

---

## 13. FileStorageReference

FileStorageReference is the structured secure storage descriptor for digital files associated with Artifacts or SourceDerivatives. It replaces free-text `file_storage_reference` strings and `file_mime_type` / `file_size_bytes` fields.

Signed access URLs are generated only after policy evaluation against the associated Artifact or SourceDerivative's `access_classification` and `display_policy_id`. The `object_key` field must never be exposed directly to clients.

### 13.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `storage_provider` | Enum | `supabase_storage` / `s3` / `gcs` / `azure_blob` / `other` |
| `bucket_or_container` | Text | The bucket or container name |
| `object_key` | Text | Opaque, system-generated object key; not a filename or URL |
| `checksum_sha256` | Char(64) | SHA-256 hex digest of the file content |
| `mime_type` | Text | IANA MIME type |
| `file_size_bytes` | BigInt | |
| `encryption_class` | Text | Nullable; encryption or classification metadata |
| `access_classification` | Enum | See §8.1; governs which policy evaluation path produces a signed URL |
| `storage_region` | Text | Nullable; cloud region or datacenter |
| `original_filename` | Text | Restricted metadata; original filename as provided by the uploader; not shown to unauthorized users |
| `derivative_relationship` | Enum | `original` / `thumbnail` / `compressed` / `transcript` / `derivative` |
| `parent_storage_reference_id` | UUID FK | Nullable; self-referential; if this is a derivative of another stored file |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | |

---

## 14. ArtifactSourceLink

ArtifactSourceLink records the relationship between an Artifact and a Source. It replaces the circular FK pattern (`Source.artifact_id` / `Artifact.source_id`) that was present in v0.1.

One artifact may relate to multiple sources; one source may be evidenced by multiple artifacts. The relationship_type field distinguishes the nature of the connection.

### 14.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `artifact_id` | UUID FK | |
| `source_id` | UUID FK | |
| `relationship_type` | Enum | See §14.2 |
| `notes` | Text | Nullable |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | |

### 14.2 relationship_type values

| Value | Description |
|---|---|
| `artifact_is_source` | The artifact itself serves as primary evidence (e.g., the photograph is the source) |
| `artifact_contains_source` | The artifact contains source material (e.g., a book that includes a vital record) |
| `source_describes_artifact` | The source describes or documents the artifact (e.g., an inventory listing describes a painting) |
| `digital_copy_of_source` | The artifact is a digital copy of the source document |
| `derivative_of_artifact` | The source is derived from or produced by the artifact |

---

## 15. Event

An Event is an occurrence: something that happened at a specific time and place with identifiable participants. Events are the structured record of occurrences; Narratives are the human stories describing them.

Event is distinct from Claim: a Claim is an atomic assertion (subject-predicate-object); an Event is a structured occurrence with participants, dates, and locations. Events may suggest claims, but must not automatically create accepted Claim records (see §15.3).

### 15.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `lifebook_id` | UUID FK | NOT NULL |
| `event_type` | Enum | See §15.2 |
| `title` | Text | Nullable |
| `description` | Text | Nullable |
| `date_start` | Date | Approximate; nullable |
| `date_end` | Date | Nullable |
| `date_precision` | precision_status | Nullable |
| `primary_location_entity_id` | UUID FK | Nullable; Place entity |
| `organizing_entity_id` | UUID FK | Nullable |
| `series_entity_id` | UUID FK | Nullable; FK to EventSeries Entity anchor |
| `submission_origin` | Enum | See §1.1 |
| `evidence_status` | Enum | Confidence in the event's occurrence |
| `dispute_status` | Enum | `uncontested` / `disputed` / `contradicted` / `retracted` / `superseded` |
| `review_status` | Enum | `pending` / `human_reviewed` / `policy_approved` |
| `access_classification` | Enum | See §8.1 |
| `display_policy_id` | UUID FK | Nullable; FK → display_policies(id); see DISPLAY_POLICY_MODEL.md |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | |
| `updated_at` | Timestamp | |
| `updated_by_id` | UUID FK | |
| `notes` | Text | Nullable |

### 15.2 event_type values

| Value | Description |
|---|---|
| `birth` | Birth of a person |
| `baptism` | Baptism or religious name-giving |
| `naming_ceremony` | Secular or cultural naming ceremony |
| `marriage` | Marriage ceremony or registration |
| `civil_partnership_registration` | Civil partnership registration or equivalent. Distinct from `marriage`. Supports participants, registration date and place, registering authority, documentary evidence, jurisdiction, and a link to the related `civil_partnership` Relationship. |
| `separation_divorce` | Legal separation or divorce |
| `death` | Death of a person |
| `burial_interment` | Burial, cremation, or interment |
| `immigration` | Crossing a national border with intent to settle |
| `emigration` | Departure from a country of residence |
| `naturalization` | Acquisition of citizenship |
| `employment_start` | Commencement of employment or vocation |
| `employment_end` | End of employment |
| `military_service` | Enlistment, deployment, or discharge |
| `graduation` | Completion of an educational program |
| `ordination` | Religious ordination |
| `adoption` | Legal or cultural adoption |
| `voyage` | Significant journey or passage |
| `community_ceremony` | Community or cultural ceremony |
| `institutional_event` | Organizational founding, dissolution, or milestone |
| `other` | Any event type not otherwise categorized |

### 15.3 Event and Claim relationship

Events may produce pending claim suggestions during data entry or AI extraction. They must not automatically create accepted Claim records. System-generated claim suggestions from events carry:
- `evidence_status = inferred`
- `review_status = pending`
- `submission_origin = system_inferred_submission` (for system events) or `ai_extracted_submission` (for AI-extracted events)

No claim suggestion originating from an event may become `review_status = policy_approved` without human review.

---

## 16. EventParticipant

EventParticipant links Entity records to Event records with their specific role.

### 16.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `event_id` | UUID FK | |
| `entity_id` | UUID FK | References Entity.id |
| `participant_role` | Enum | See §16.2 |
| `participation_notes` | Text | Nullable |
| `evidence_status` | Enum | Confidence that this entity participated |
| `access_classification` | Enum | See §8.1 |
| `display_policy_id` | UUID FK | Nullable; FK → display_policies(id); see DISPLAY_POLICY_MODEL.md |
| `added_by_id` | UUID FK | |
| `added_at` | Timestamp | |
| `notes` | Text | Nullable |

### 16.2 participant_role values

| Value | Description |
|---|---|
| `subject` | The person the event primarily concerns |
| `spouse_partner` | Spouse or partner in a marriage or union event |
| `parent` | Parent in a birth, baptism, or adoption event |
| `guardian` | Legal guardian in an adoption or guardianship event |
| `witness` | A witness who attested to the event |
| `officiant` | A celebrant, registrar, or official who presided |
| `family_member` | A family member present |
| `passenger` | A traveller on a voyage |
| `crew_member` | Crew on a vessel |
| `employer` | An employer |
| `employee` | An employee |
| `community_member` | A community member in a community ceremony |
| `location` | A place entity in a multi-location event |
| `vessel` | A vessel entity in a voyage event |
| `organizing_body` | An organization that organized or officiated |
| `other` | Any role not otherwise categorized |

---

## 17. Access Classification (shared enum)

All content records that carry an `access_classification` field use the following values:

| Value | Description |
|---|---|
| `public` | May appear in public-facing views where LifeBook visibility permits |
| `family` | Accessible to family members and authorized contributors |
| `steward` | Accessible to the LifeBook steward only |
| `restricted` | Accessible only to specifically authorized individuals per display policy |
| `culturally_governed` | Requires the `culturally_governed_processing` ContextProfile; DENIED by default |

---

## 18. Design Decisions and Constraints

### 18.1 Four-identity enforcement in content records

Every content record preserves distinct fields for each applicable identity:

| Identity | Field |
|---|---|
| Authenticated User (who entered the record) | `created_by_id` → public.user_profiles |
| Storyteller (who provided the account) | `composed_by_entity_id` on Narrative → Entity |
| Subject (who the content is about) | `subject_entity_id` on Claim; `entity_id` on EventParticipant, NarrativeEntity; `entity_a_id`/`entity_b_id` on Relationship |
| Authority holder | Not stored on content records; resolved via AuthorityAssignment |

No database trigger, application default, AI process, or import pipeline may populate `subject_entity_id` with the value of `created_by_id`.

### 18.2 Claims own facts; anchor tables cache labels

Entity subtype tables (Organization, Place, Vessel, Community, EventSeries in ANCHOR_MODELS.md) may contain display label fields for operational convenience. These are explicitly non-authoritative cached labels, not factual records. The authoritative record for any name, date, or other changeable fact is a Claim (with ClaimEvidence and provenance) or a versioned attribute record.

Cached display labels on subtype tables must carry:
- `_policy_version_id` (the policy version that authorized the current label)
- `_validity_state` (invalidated by AccessPolicyChanged)
- `_invalidated_at` (timestamp)

This is the same lineage requirement as other cached derived fields.

### 18.3 AI-generated content quarantine

Any content record with `submission_origin = ai_extracted_submission` or `system_inferred_submission` is quarantined from display and AI context supply until `review_status = human_reviewed` at minimum, and `policy_approved` before any consequential use (publication, cross-LifeBook sharing, identity resolution).

An AI-generated Narrative with `content_type = ai_generated_summary` may not be displayed or supplied to a new model invocation until `review_status = policy_approved`.

### 18.4 SourceDerivative is the AI context unit

The unit of content that the Context Broker supplies to a model invocation is the SourceDerivative, not the Source. The Source is the original record; the SourceDerivative is the sanitized, access-controlled, provenance-tracked form an agent may receive. A Narrative or Claim may reference the underlying Source; the Context Broker supplies only the applicable SourceDerivative for the current ContextProfile.

### 18.5 Canonical confidence enum values

The following values are canonical across all content records that carry confidence dimensions. These values supersede the "TBD" placeholders previously referenced from GOVERNANCE_MODELS.md.

**`evidence_status`** — confidence in the evidence supporting an assertion:

| Value | Meaning |
|---|---|
| `unreviewed` | No review has occurred; the value was submitted or extracted but not assessed |
| `asserted` | Stated by a contributor or subject; no independent corroboration yet |
| `inferred` | Derived by system process or AI; probabilistic; not submitted by a human |
| `supported` | Supported by at least one reviewed source record |
| `corroborated` | Confirmed by two or more independent sources |

**`precision_status`** — confidence in the precision of a temporal or locational value:

| Value | Meaning |
|---|---|
| `exact` | The value is precisely known and recorded as stated |
| `approximate` | The value is approximate; the true value is probably close |
| `range` | The value falls within a range; the Claim carries effective date range fields |
| `unknown` | The precision cannot be determined from available evidence |

**Separation of concerns — these enums must not encode:**
- Dispute: encoded in `dispute_status` (`uncontested` / `disputed` / `contradicted` / `retracted` / `superseded`)
- Review state: encoded in `review_status` (`pending` / `human_reviewed` / `policy_approved`)
- Temporal precision: encoded in `precision_status` (above); not in `evidence_status`

---

## 19. Open Questions

1. **Relationship display names.** When displaying a Relationship in UI, the system needs a human-readable description. Should this be generated from RelationshipType.display_label + role_a/role_b fields, or should a cached `relationship_description_text` be stored with full lineage? Recommendation: generate at presentation time; cache only if performance requires it, with full lineage.

2. **Controlled predicate vocabulary seed data.** ClaimPredicate is a reference table seeded at deployment. The full seed catalogue needs to be specified as a data fixture before migration. A draft list is in §3.2; it must be expanded and reviewed for completeness before migration.

3. **Multi-language claim text.** `claim_text_cached` is in one language. For multilingual LifeBooks, translated claim text is a derivative that follows the same translation lineage rules as Narrative translations (§7.6). This is not designed yet.

4. **RelationshipType seed data.** The full seed catalogue for RelationshipType needs to be reviewed and approved before migration. A draft is in §6.2.

5. **Claim suggestion workflow.** When an Event or AI extraction produces claim suggestions (`submission_origin = system_inferred_submission`), what is the UI flow for steward review and promotion? The data model supports this; the application workflow is not yet designed.

6. **Source sharing revocation.** When a CrossLifeBookAuthorization is revoked, LifeBookSourceAccess records backed by that authorization must be suspended or revoked. The cascade — from authorization revocation to LifeBookSourceAccess.status update to SourceDerivative invalidation — needs a defined trigger sequence. Currently specified in AI_CONTEXT_BROKER.md §11.4 at a high level; the database trigger or application-layer cascade needs specification.

7. **FileStorageReference and SourceDerivative.** SourceDerivative.content is currently a Text field for simple cases. For large transcripts or audio/video derivatives, the content should be stored via FileStorageReference rather than inline. A `source_derivative_file_id` FK to FileStorageReference should be added when file-based derivative storage is designed.

---

---

## 20. Relationship to the Memory Atmosphere Engine

The Content Layer is a **read-only source** for the Memory Atmosphere Engine (see `MEMORY_ATMOSPHERE_ENGINE.md` and `ADR-0002`).

Specifically, the engine consumes the following signals derived from Content Layer records, mediated entirely by the AI Context Broker:

| Content Layer field / concept | Signal provided to engine |
|---|---|
| `Artifact.access_classification` | Whether a specific artifact is eligible for display under current governance |
| `Source.access_classification` | Whether source-derived imagery is restricted or permitted at the current level |
| `SourceDerivative.source_authenticity_level` | Whether specific material is authenticated, inferred, or generic |
| `ArtifactSourceLink` | Whether a specific artifact has a verified source lineage |

The Memory Atmosphere Engine does not query these tables directly. The AI Context Broker resolves the applicable signals and passes them as typed inputs to the engine. The engine does not modify any Content Layer record.

No new fields are added to Content Layer tables in this session. Deferred schema objects required by the engine are documented in `MEMORY_ATMOSPHERE_ENGINE.md §11` and `SCHEMA_INVENTORY.md`.

---

*Next step: Review this document, then review the updated ANCHOR_MODELS.md, then proceed to SCHEMA_INVENTORY.md before migration.*
