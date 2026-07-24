# ENUM_AND_VOCABULARY_CLASSIFICATION_AUDIT.md — Version 4.0

**Status:** Pre-approval draft — awaiting Discovery Partner review  
**Supersedes:** Version 3.0 (2026-07-23)  
**Date:** 2026-07-23  
**Migration file:** `supabase/migrations/0001_types_and_vocabularies.sql` (v4)

---

## Classification Framework

**Question set applied to every proposed type:**

1. Is this a machine lifecycle state, or a category/classification?
2. Must arbitrary new values be prohibited by the database?
3. Would adding a new value require new application logic, transitions, constraints, or table structure?
4. Does the vocabulary require: display labels · descriptions · localization · deprecation · replacement · jurisdiction-specific behavior · access defaults · policy metadata · feature flags · historical effective dates?
5. Has the value list already changed during architecture work?
6. Could a future valid value be added without changing the meaning of existing database constraints?

**Retain as PostgreSQL enum when:** answers to Q1-3 clearly support a closed state machine or structural invariant, AND Q4 shows no extensibility requirements.

**Convert to reference table when:** Q4 identifies extensibility requirements, OR Q6 shows the set is open, OR the vocabulary is used primarily for categorization, display, routing, defaults, or policy selection.

---

## Summary of Revised Counts

| Category | v2 | v3 | v4 (current) | Delta v3→v4 |
|----------|-----|-----|-------------|-------------|
| PostgreSQL enums | 57 | 41 | 39 | −2 |
| Reference / mapping tables | 25 | 38 | 39 | +1 |
| Deferred (excluded from 0001) | 0 | 2 | 3 | +1 |
| Removed as duplicate | 0 | 1 | 1 | 0 |

**Changes v3→v4:**
- `escalation_resolution_type`: ENUM → DEFERRED (EscalationRecord not yet designed; co-deferred with escalation_record_status)
- `evidence_role`: ENUM → REFERENCE TABLE `evidence_roles` (requires semantic policy fields: may_raise_evidence_status, is_contradictory, is_superseding)
- `narrative_authenticity_status` → RENAMED to `narrative_attribution_status` (concerns narrator/author attribution, not content authenticity)
- `governance_lifecycle_condition`: `cultural_governed` value REMOVED (9→8 values; cultural governance is a separate ApprovalPolicy dimension, not a lifecycle condition — see GOVERNANCE_MODELS.md §4.5)

**Removed from enum list (total: 18 types from v2 baseline):**
- 14 converted to reference tables (13 in v3 + evidence_role in v4)
- 3 deferred (escalation_record_status, escalation_resolution_type, person_lifecycle_status)
- 1 removed as duplicate (source_derivative_type)

---

## Part I: Full Classification Audit — All Proposed Types

### Types Retained as PostgreSQL Enums (39)

For brevity, types with clear unanimous answers are grouped. Full Q1-Q6 analysis is provided for borderline and newly discovered types.

---

#### CLEAR ENUM CASES — State machines and structural invariants

**A.1 `evidence_status`** — Q1: lifecycle state of claim evidence quality. Q2-3: each value triggers different promotion rules and editorial workflows. Q4: no per-value metadata. Q5: ⚠ completely wrong values in v1 (corrected). Q6: adding a new evidence level requires new promotion logic. **ENUM.**

**A.2 `precision_status`** — Q1: precision qualifier for Claim values. Q2-3: controls claim rendering and validation. Q4: no metadata. Q5: stable. Q6: adding 'estimated' would require new rendering logic. **ENUM.** *(Borderline — drives display, but the set is semantically sealed by the measurement model.)*

**A.3 `dispute_status`** — Q1: dispute lifecycle state on a Claim. Q2-3: 'disputed' and 'contradicted' trigger review workflows and access restrictions. Q4: no metadata. Q5: stable. Q6: no. **ENUM.**

**A.4 `review_status`** — Q1: editorial review workflow state. Q2-3: each value has distinct access and publication implications. Q4: no metadata. Q5: stable. Q6: no. **ENUM.**

**B.1 `entity_type`** — Q1: class-table inheritance discriminator. Q2-3: a new entity type requires a new subtype table and all associated schema. Q4: no. Q5: stable (6 types frozen). Q6: no. **ENUM.** *(DP-confirmed: entity_type defines class-table inheritance and must remain enum.)*

**B.2 `canonical_status`** — Q1: entity record lifecycle state (merge/split workflow). Q2-3: merge and split operations depend on these states. Q4: no. Q5: stable. Q6: no. **ENUM.**

**B.3 `suppression_state`** — Q1: privacy/suppression lifecycle state. Q2-3: access control logic is coded against these states. Q4: no. Q5: stable. Q6: no. **ENUM.**

**B.4 `erasure_state`** — Q1: erasure processing workflow state. Q2-3: erasure pipeline logic depends on each state. Q4: no. Q5: stable. Q6: no. **ENUM.**

**B.5 `merge_operation_type`** — Q1: structural discriminator for MergeRecord (merge vs. split). Q2: exactly two operations in the model. Q3: a third operation type would require a new workflow model. Q4: no. Q5: stable. Q6: no. **ENUM.** *(2-value enum; truly closed.)*

**C.1 `visibility_status`** — Q1: access control state for LifeBookEntity display. Q2-3: access policy is coded against each state. Q4: no. Q5: ⚠ expanded from 3 values in v1; correct is 5. Q6: no — adding 'embargoed' requires new access logic. **ENUM.** *(Changed count is a yellow flag, but the change corrected a wrong count, not an open expansion.)*

**C.2 `contribution_status`** — Q1: contribution lifecycle state of a person-LifeBook relationship. Q2-3: each state has different access and notification implications. Q4: no. Q5: stable. Q6: no. **ENUM.** *(DP explicitly restored to enum.)*

**C.3 `verification_status`** — Q1: verification workflow state of a UserPersonLink. Q2-3: identity verification logic depends on each state. Q4: no. Q5: ⚠ terminal value corrected (failed_verification → rejected). Q6: no. **ENUM.**

**C.4 `lifebook_status`** — Q1: LifeBook record lifecycle state. Q2-3: determines allowed operations on the LifeBook. Q4: no. Q5: stable. Q6: no. **ENUM.**

**C.5 `lifebook_visibility`** — Q1: access control scope of a LifeBook. Q2-3: access policy depends on these values. Q4: no per-value metadata (contrast access_classifications which carries routing defaults and metadata). Q5: stable. Q6: no. **ENUM.**

**C.6 `subject_scope`** — Q1: structural discriminator for LifeBook subject type, which affects governance rules. Q2: the governance model has 4 distinct subject types. Q3: adding a new scope requires new governance coverage. Q4: no. Q5: stable. Q6: no. **ENUM.** *(Categorization-adjacent, but governance model treats each scope as a structural discriminator.)*

**C.7 `stewardship_type`** — Q1: discriminator for stewardship governance pattern (4 distinct authority models). Q2-3: each type entails a different authority assignment model. Q4: no. Q5: stable. Q6: no. **ENUM.**

**C.8 `account_status`** — Q1: User account lifecycle state. Q2-3: authentication and access logic depends on each state. Q4: no. Q5: stable. Q6: no. **ENUM.**

**C.9 `cross_lifebook_authorization_status`** — Q1: authorization record lifecycle state. Q2-3: access control. Q4: no. Q5: stable. Q6: no. **ENUM.**

**C.10 `entity_match_status`** — Q1: identity resolution workflow state. Q2-3: match review workflow. Q4: no. Q5: ⚠ completely wrong values in v1. Q6: no. **ENUM.**

**C.11 `entity_match_review_outcome`** — Q1: outcome record for a match review decision. Q2-3: outcome drives merge or link workflows. Q4: no. Q5: ⚠ completely wrong values in v1. Q6: no. **ENUM.**

**D.1 `composition_status`** — Q1: Narrative publication workflow state. Q2-3: editorial and access workflow. Q4: no. Q5: ⚠ `under_review`→`in_review`; `retracted`→`withdrawn`. Q6: no. **ENUM.**

**D.2 `narrative_parent_relationship`** — Q1: structural discriminator for how a derived Narrative relates to its parent (provenance). Q2: set of derivation mechanisms is semantically bounded. Q3: adding 'audio_reading_of' would require new attribution and rights logic. Q4: no. Q5: stable. Q6: no. **ENUM.**

**D.3 `narrative_attribution_status`** *(renamed from `narrative_authenticity_status`)* — Q1: workflow state tracking whether a Narrative's narrator/author attribution has been verified. Q2-3: drives editorial review of attribution claims. Q4: no. Q5: renamed — original name `narrative_authenticity_status` conflated attribution (who authored/narrated) with authenticity (whether content is genuine). DP correction: this type concerns attribution, not content authenticity; rename required. Q6: no. **ENUM.** *(See schema implication Flag 6 re semantic boundary with review_status/dispute_status.)*

**D.4 `claim_text_validity_state`** — Q1: cache validity state for materialized claim text. Q2-3: cache invalidation logic. Q4: no. Q5: stable. Q6: no. **ENUM.** *(3 values; clean closed set.)*

**D.5 `artifact_validity_state`** — Q1: validity state of AI-generated content managed by the AI Context Broker. Q2-3: Context Broker regeneration and access logic. Q4: no. Q5: ⚠ wrong name and wrong values in v1. Q6: no. **ENUM.**

**D.6 `evidence_role` → `evidence_roles`** *(CONVERTED TO REFERENCE TABLE per DP correction)*  
Q1: categorization of how a Source relates to a Claim via ClaimEvidence — not a lifecycle state. Q2-3: 'contradicts' and 'supersedes' carry semantic signals that affect evidence promotion, but these signals belong as queryable boolean policy columns on the reference row, not as hardcoded enum interpretations. Q4: **YES** — requires semantic policy fields: `may_raise_evidence_status BOOLEAN`, `is_contradictory BOOLEAN`, `is_superseding BOOLEAN`, plus standard display_label, description, deprecation, and sort_order. These fields allow promotion rules to be driven by data rather than code. Q5: stable in current values. Q6: adding 'partially_supports' or 'amplifies' requires no constraint changes. **REFERENCE TABLE `evidence_roles`.**  
*(Promotion rules themselves remain in domain logic — the reference row signals semantic intent; it does not implement the rule.)*

**D.7 `claim_predicate_permitted_value_type`** — Q1: structural discriminator determining which value column in Claim is populated. Q2: exactly 4 scalar types in the model. Q3: adding 'geolocation' would require a new Claim value column. Q4: no. Q5: stable. Q6: no. **ENUM.** *(Strong structural invariant.)*

**D.8 `unit_category`** — Q1: classification of measurement unit. Q2-3: each category has distinct validation rules (currency requires qualifier, count requires integer). Q4: no per-category metadata. Q5: ⚠ seed values used `length`/`weight` (wrong — corrected to `distance`/`mass`). Q6: adding 'temperature' requires new validation rules. **ENUM.** *(The 'other' escape hatch exists but each named category has distinct semantics.)*

**E.1 `coordination_rule`** — Q1: behavioral specification for multi-authority coordination (algorithmic, not categorical). Q2-3: coordination logic implements each rule. Q4: no. Q5: stable. Q6: no — adding 'committee_decision' requires a new algorithm. **ENUM.**

**E.2 `succession_behaviour`** — Q1: behavioral specification for what happens when an AuthorityAssignment ends. Q2-3: succession logic implements each behaviour. Q4: no. Q5: ⚠ completely wrong values in v1. Q6: no. **ENUM.**

**E.3 `governance_lifecycle_condition`** — Q1: condition discriminator for ApprovalPolicy applicability — determines which policy applies to a given person context. Q2-3: adding a new condition requires comprehensive governance policy coverage. Q4: could need localization, but the conditions are structural governance categories, not display labels. Q5: ⚠ wrong name in v1; v4 removes `cultural_governed` (9→8 values). Q6: no. **ENUM (8 values).** *(Borderline: jurisdiction-specific terminology varies, but the underlying condition categories are structural. Retaining as enum with the mapping table `authority_context_policy_conditions` handling jurisdiction-specific variation. `cultural_governed` removed: cultural governance is not a person lifecycle condition — see GOVERNANCE_MODELS.md §4.5 and DEFERRED decision in DEFERRED_TYPE_REGISTER.md. Values: living_with_capacity / minor_sole_guardian / minor_joint_guardian / supported_decision_making / legal_representative / deceased_with_preferences / deceased_without_preferences / disputed_authority.)*

**E.4 `resolution_rule`** — Q1: behavioral specification — each value is an algorithm for resolving competing assertions. Q2-3: resolution logic implements each rule. Q4: no. Q5: stable. Q6: no. **ENUM.**

**E.5 `approval_record_status`** — Q1: approval workflow lifecycle state. Q2-3: approval workflow logic. Q4: no. Q5: stable. Q6: no. **ENUM.**

**F.1 `escalation_default_action`** — Q1: behavioral specification for what the system does when an escalation SLA is not met. Q2-3: system behavior implements each action. Q4: no. Q5: stable. Q6: no. **ENUM.**

**F.2 `escalation_resolution_type`** — *(DEFERRED per DP correction)* Q1: outcome classifier for how an EscalationRecord was resolved — belongs to EscalationRecord, which is not yet designed. Q5: value list is provisional; valid resolutions depend on which statuses are terminal vs intermediate (unresolvable without the state machine). **DEFERRED** — co-deferred with `escalation_record_status`; see DEFERRED_TYPE_REGISTER.md §1b for full conditions. *Note: `escalation_default_action` is NOT deferred — it belongs to EscalationPolicy (designed) and remains in 0001.*

**F.3 `contest_status`** — Q1: ContestRecord workflow lifecycle state. Q2-3: 'open' status freezes actions on affected records; 'pending_external' has different access implications. Q4: no. Q5: stable. Q6: no. **ENUM.**

**F.4 `contest_resolution_type`** — Q1: outcome classifier for how a contest was resolved. Q2-3: resolution type affects what records are updated and what notifications are sent. Q4: no. Q5: stable. Q6: no. **ENUM.**

**F.5 `contest_access_mode`** — Q1: behavioral specification for access mode during an active ContestRecord. Q2-3: access control logic implements each mode. Q4: no. Q5: stable. Q6: no. **ENUM.**

**G.1 `guardian_coordination_presumption`** — Q1: behavioral specification for default joint guardian coordination in a jurisdiction. Q2-3: same logic as coordination_rule (derives from it). Q4: no. Q5: stable. Q6: no. **ENUM.**

**G.2 `jurisdiction_review_status`** — Q1: lifecycle state of a JurisdictionPolicyVersion. Q2-3: governance workflow — only 'approved' versions are active. Q4: no. Q5: stable. Q6: no. **ENUM.**

**H.1 `person_name_derivative_type`** — Q1: structural discriminator for type of derived PersonName (transliteration or translation). Q2: exactly two derivation methods in the design model. Q3: adding 'romanization' would be semantically equivalent to transliteration — the set is bounded by the linguistic model. Q4: no. Q5: stable. Q6: no. **ENUM.** *(2 values; truly closed.)*

---

### Types Converted to Reference Tables (13)

Full Q1-Q6 analysis provided for each.

---

**N.1 `organization_type` → `organization_types`**  
*DP explicit instruction.*  
Q1: Categorization of an Organization entity. Q2: New org types are possible (cooperative, trust, foundation, tribal government). Q3: Adding new type does not require new application logic. Q4: Needs localization (governmental means different things in different countries), hierarchy (religious/state church), jurisdiction-specific behavior, possibly display descriptions. Q5: Stable currently but DP noted expansion expectation. Q6: Yes — adding 'cooperative' requires no constraint changes. **REFERENCE TABLE.**

---

**N.2 `creation_source` → `creation_sources`**  
*DP explicit instruction.*  
Q1: Classification of how an Entity record was created — not a lifecycle state. Q2-3: Could expand to include institutional_import, archival_ingest, merge, system_generation, ai_proposal, api_integration, migration_import, reconciliation_workflow. Q4: May need provenance metadata, import-policy metadata per source type. Q5: Stable currently, but DP identified at least 8 additional plausible values. Q6: Yes — could add without changing constraints. **REFERENCE TABLE.**

---

**N.3 `place_type` → `place_types`**  
Q1: Categorization of a Place entity — not a lifecycle state. Q2-3: Adding 'reservation', 'township', 'district', 'territory' does not change application logic. Q4: Needs localization (province_state is a Canadian/US concept; other jurisdictions use different terminology), hierarchy (settlement patterns are hierarchical), historical effective dates (place types change over time). Q5: Stable. Q6: Yes. **REFERENCE TABLE.**

---

**N.4 `coordinate_precision` → `coordinate_precisions`**  
Q1: Categorization of coordinate quality for display and mapping — not a lifecycle state. Q2-3: Adding 'regional_centroid' or 'interpolated' would require no constraint changes. Q4: Needs display labels for map rendering. Q5: Stable. Q6: Yes. **REFERENCE TABLE.** *(Was borderline; DP criteria "vocabulary used mainly for display" resolves it.)*

---

**N.5 `vessel_type` → `vessel_types`**  
Q1: Categorization of a Vessel entity. Q2-3: Can expand (automobile, spacecraft, canal boat, etc.) without application logic changes. Q4: Needs localization (vessel terminology is culture- and era-specific), historical effective dates. Q5: Stable. Q6: Yes. **REFERENCE TABLE.**

---

**N.6 `community_type` → `community_types`**  
Q1: Categorization of a Community entity. Q2-3: Can expand (diaspora_community, linguistic_community, etc.). Q4: Indigenous classifications are culturally governed — may require specific governance metadata per community type. Localization needed. Q5: Stable. Q6: Yes. **REFERENCE TABLE.** *(Indigenous community classifications require governed expansion — reference table with cultural authority review process.)*

---

**N.7 `series_type` → `series_types`**  
Q1: Categorization of an EventSeries. Q2-3: Can expand. Q4: Localization needed. Q5: Stable. Q6: Yes. **REFERENCE TABLE.**

---

**N.8 `creation_reason` → `creation_reasons`**  
Q1: Categorization of why a LifeBook was created — not a lifecycle state. Q2-3: Can expand (refugee_documentation, institutional_archive, trauma_testimony, genealogical_research). Q4: Localization needed. Q5: Stable. Q6: Yes. **REFERENCE TABLE.**

---

**N.9 `mention_role` → `mention_roles`**  
Q1: Classification of how an Entity is mentioned in a Narrative — categorization for display and attribution. Q2-3: Can expand (illustrator, transcriber, translator, editor) without changing application logic. Q4: Needs display labels, localization. Q5: Stable. Q6: Yes. **REFERENCE TABLE.**

---

**N.10 `authority_role` → `authority_roles`**  
Q1: Classification of a governance role held by an authority — categorization for policy selection. Q2-3: Can expand with new legal instruments. Q4: Jurisdiction-specific behavior (guardian_sole means different things under different family law regimes), localization, may need effective dates. Q5: Stable. Q6: Possibly — adding 'digital_executor' might not require new code. **REFERENCE TABLE.** *(Jurisdiction-specific behavior is the deciding factor.)*

---

**N.11 `action_type` → `action_types`**  
Q1: Classification of a governed action — categorization for policy selection (which actions an AuthorityAssignment covers). Q2: Adding new governed actions is expected as features develop. Q3: Adding new action requires new policy coverage in ApprovalPolicy, but does not change schema. Q4: Policy metadata per action (e.g., which actions require dual approval, which have cooling-off periods) is needed. Q5: Stable. Q6: Yes — but note schema implication: AuthorityAssignment.permitted_actions was an enum array; converting to ref table affects FK enforcement (see Schema Implication Flag 1 in SOURCE_TO_SCHEMA_TYPE_MATRIX.md). **REFERENCE TABLE.**

---

**N.12 `person_name_derivation_method` → `person_name_derivation_methods`**  
Q1: Classification of how a derived PersonName was produced — categorization for provenance display. Q2-3: Can expand (institutional, historical, community_transcription) without application logic changes. Q4: Needs display labels. Q5: Stable. Q6: Yes. **REFERENCE TABLE.**

---

**N.13 `pronoun_set_type` → `pronoun_set_types`**  
Q1: Classification of a pronoun set — extensible vocabulary. Q2-3: New pronoun sets (xe_xem, ze_zir, etc.) are emerging and culturally expected. Adding them requires no application logic changes — 'custom' already exists as escape hatch. Q4: Localization needed (pronoun systems vary by language). Q5: Stable in current set. Q6: Yes — the 'custom' escape hatch confirms the set is not intended to be closed. **REFERENCE TABLE.**

---

### Types Deferred (3) and Removed (1)

See `DEFERRED_TYPE_REGISTER.md` for full analysis.

| Type | Disposition | Reason |
|------|------------|--------|
| `escalation_record_status` | DEFERRED | EscalationRecord not yet designed; state machine and value list provisional |
| `escalation_resolution_type` | DEFERRED | EscalationRecord not yet designed; valid resolutions depend on terminal-state definition; co-deferred with escalation_record_status |
| `person_lifecycle_status` | DEFERRED | Authority/derivation model unresolved; P2 principle may prohibit direct field |
| `source_derivative_type` (enum) | REMOVED | Duplicate of `source_derivative_types` reference table; created in error in v2 |

---

## Part II: Reference Tables Full List (39 total)

All reference tables are listed in SOURCE_TO_SCHEMA_TYPE_MATRIX.md Part II with authoritative source, owning table/column, and migration mapping. Summary counts only here.

| Category | Count |
|----------|-------|
| Original standard reference tables (carried from prior classification) | 22 |
| Original governed reference tables | 2 |
| Original unit reference table | 1 |
| Newly classified as reference tables (converted from proposed enums, v3) | 13 |
| Newly classified as reference table (converted from enum, v4) | 1 (`evidence_roles`) |
| **Total** | **39** |

### N.14 `evidence_role` → `evidence_roles`

*(Converted from enum, v4 — DP correction)*  
Q1: categorization of how a Source relates to a Claim via ClaimEvidence — not a lifecycle state; not a machine state machine. Q2-3: 'contradicts' and 'supersedes' carry semantic signals but these are better represented as queryable policy fields than as hardcoded enum interpretations requiring application code to switch on. Q4: **YES** — requires semantic policy columns: `may_raise_evidence_status BOOLEAN` (does this role support promoting the claim's evidence_status?), `is_contradictory BOOLEAN` (does this role signal a direct conflict?), `is_superseding BOOLEAN` (does this role signal replacement?); also standard display_label, description, deprecation, replaced_by_code, sort_order. These fields allow promotion rules to be driven by data queries rather than by enum-switched code. Q5: stable in current values but 'partially_supports', 'amplifies', 'neutralizes' are plausible additions. Q6: yes — adding new roles requires no constraint changes. **REFERENCE TABLE `evidence_roles`.**

Columns: `code TEXT PK`, `display_label TEXT NOT NULL`, `description TEXT`, `may_raise_evidence_status BOOLEAN NOT NULL DEFAULT FALSE`, `is_contradictory BOOLEAN NOT NULL DEFAULT FALSE`, `is_superseding BOOLEAN NOT NULL DEFAULT FALSE`, `is_active BOOLEAN NOT NULL DEFAULT TRUE`, `deprecated_at TIMESTAMPTZ`, `replaced_by_code TEXT FK → evidence_roles(code)`, `sort_order INTEGER`, `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`.

Seed values:

| code | may_raise | is_contradictory | is_superseding | sort_order |
|------|-----------|-----------------|----------------|-----------|
| `supports` | TRUE | FALSE | FALSE | 10 |
| `corroborates` | TRUE | FALSE | FALSE | 20 |
| `contextualizes` | FALSE | FALSE | FALSE | 30 |
| `contradicts` | FALSE | TRUE | FALSE | 40 |
| `supersedes` | FALSE | FALSE | TRUE | 50 |

---

## Part III: Types That Changed During Architecture Work

These types had values, names, or classifications that were wrong or unstable during architecture. Each is a known risk vector for schema drift.

| Type | What Changed | Risk |
|------|-------------|------|
| `evidence_status` | Completely wrong values in v1 | HIGH — values are authoritative for evidence promotion logic |
| `governance_lifecycle_condition` | Wrong name + wrong values in v1 | HIGH — drives policy selection |
| `succession_behaviour` | Completely wrong values in v1 | HIGH |
| `entity_match_status` | Completely wrong values in v1 | HIGH |
| `entity_match_review_outcome` | Completely wrong values in v1 | HIGH |
| `artifact_validity_state` | Wrong name (`derivative_validity_state`) + wrong values in v1 | HIGH |
| `visibility_status` | Count wrong in v1 (3 → 5) | MEDIUM |
| `composition_status` | Two values wrong (`under_review`, `retracted`) | MEDIUM |
| `verification_status` | Terminal value wrong (`failed_verification` → `rejected`) | MEDIUM |
| `unit_category` | Was TEXT, not enum; seed values wrong (`length`/`weight`) | MEDIUM |
| `creation_source` | Reclassified enum → reference table | LOW |
| `contribution_status` | Reclassified ref table → enum (DP reversal) | LOW |
| `data_conflict_type` | Reclassified enum → ref table (DP Decision 1) | LOW |
| `right_to_erasure` | Reclassified enum → ref table `erasure_regimes` (DP Decision 4) | LOW |
| `file_derivative_relationships` | Renamed → `file_storage_roles` (DP Decision 3) | LOW |

---

## Part IV: Newly Discovered Types Audit

These types did not appear in the original 0001_enums.sql (44 types). Each is traced to an authoritative document and verified for current relevance.

| Type | Discovered In | Owning Table | Column Present in Frozen Schema? | Current? | Duplicates Existing? | Decision | In 0001? |
|------|--------------|-------------|----------------------------------|----------|---------------------|----------|---------|
| `escalation_default_action` | OPERATIONAL_MODELS §1.4 | EscalationPolicy | Yes — EscalationPolicy.default_action | Yes | No | ENUM | Yes |
| `escalation_record_status` | SCHEMA_INVENTORY Group 1 | EscalationRecord | Yes (column exists) — table not designed | Provisional | No | DEFERRED | No |
| `escalation_resolution_type` | PRE_MIGRATION_CLOSURE | EscalationRecord | Yes — EscalationRecord.resolution_type | Yes | No | ENUM | Yes |
| `contest_status` | OPERATIONAL_MODELS §2.4 | ContestRecord | Yes | Yes | No | ENUM | Yes |
| `contest_resolution_type` | OPERATIONAL_MODELS §2.5 | ContestRecord | Yes | Yes | No | ENUM | Yes |
| `contest_access_mode` | OPERATIONAL_MODELS §2.6 | ContestRecord; contest_types | Yes | Yes | No | ENUM | Yes |
| `guardian_coordination_presumption` | OPERATIONAL_MODELS §3.4 | JurisdictionPolicyVersion | Yes | Yes | No (distinct from coordination_rule — jurisdiction default vs. per-assignment rule) | ENUM | Yes |
| `jurisdiction_review_status` | OPERATIONAL_MODELS §5.1 | JurisdictionPolicyVersion | Yes | Yes | No | ENUM | Yes |
| `person_name_derivative_type` | PERSON_ATTRIBUTE_CATALOGUE | PersonName | Yes | Yes | No | ENUM | Yes |
| `person_name_derivation_method` | PERSON_ATTRIBUTE_CATALOGUE | PersonName | Yes | Yes | No | REF TABLE → `person_name_derivation_methods` | Yes |
| `pronoun_set_type` | PERSON_ATTRIBUTE_CATALOGUE | PersonPronouns | Yes | Yes | No | REF TABLE → `pronoun_set_types` | Yes |
| `source_derivative_type` (enum) | CONTENT_LAYER §10.1 | SourceDerivative | Column is `derivative_type_code` → FK to ref table | Yes | YES — duplicates `source_derivative_types` | REMOVED (duplicate) | No |
| `creation_source` | ANCHOR_MODELS §1.1 | Entity | Yes | Yes | No | REF TABLE → `creation_sources` | Yes |
| `person_lifecycle_status` | ANCHOR_MODELS §2.2 | Person | Proposed field — authority model unresolved | Uncertain | Potentially overlaps with governance_lifecycle_condition derivation | DEFERRED | No |

---

## Part V: Classification Disputes and Borderline Cases for DP Review

The following types were close calls. The DP should confirm or override before 0001 approval.

**1. `precision_status`** — classified ENUM. Used primarily for display (how to render date ranges and location values). Could be reference table with display metadata. Retaining as enum because validation rules differ per value (range requires explicit bound values; unknown suppresses validation). Confirm?

**2. `evidence_role`** — classified ENUM. Values 'contradicts' and 'supersedes' are referenced in evidence_status promotion rules. Could be reference table. Risk: if evidence promotion logic is fully in the application layer, this could be a ref table. Confirm enum?

**3. `subject_scope`** — classified ENUM. Acts as a structural discriminator for LifeBook governance. Could be ref table if new subject scopes (e.g., 'household') could be accommodated by existing governance logic. Confirm enum?

**4. `narrative_authenticity_status`** — classified ENUM. Semantic boundary with `review_status` and `dispute_status` needs DP confirmation during Narrative table design. All three are currently separate types. Confirm three separate types are intended?

**5. `governance_lifecycle_condition`** — classified ENUM. DP noted jurisdiction-specific variation in terminology. The mapping table `authority_context_policy_conditions` handles the jurisdiction-specific mapping. The enum itself represents universal condition categories. Confirm enum is appropriate given the mapping table handles variation?

---

## Part VI: Final Counts for 0001

| Object | Count |
|--------|-------|
| PostgreSQL enum types | 41 |
| Standard reference tables | 35 |
| Governed reference tables | 2 |
| Mapping table | 1 |
| **Total reference/mapping tables** | **38** |
| Deferred types | 2 |
| Removed types (duplicate) | 1 |
