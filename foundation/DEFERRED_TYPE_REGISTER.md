# DEFERRED_TYPE_REGISTER.md

**Status:** Pre-approval draft — awaiting Discovery Partner review  
**Date:** 2026-07-23  
**Related migration:** `supabase/migrations/0001_types_and_vocabularies.sql`

This register documents every vocabulary type or enum excluded from `0001_types_and_vocabularies.sql`, with the precise reason for exclusion and the conditions that must be satisfied before the type may be introduced in a later migration.

---

## 1. `escalation_record_status` and `escalation_resolution_type`

> These two types are co-deferred. Both belong to EscalationRecord. Neither may be introduced independently — the state machine, terminal condition identification, and status-to-resolution mapping must be designed together before either is defined.

---

### 1a. `escalation_record_status`

**Proposed values (provisional, not approved):**  
`pending` / `in_progress` / `waiting_external` / `resolved` / `cancelled` / `expired` / `superseded`

**Classification when designed:** Enum — lifecycle state of an EscalationRecord

**Reason for deferral:**  
OPERATIONAL_MODELS.md §4.1 explicitly states that EscalationRecord is "not yet designed." The values listed above were synthesized from patterns in adjacent models and are not authoritative. Introducing placeholder values into a foundational migration embeds speculative schema that cannot be altered without a new migration.

**Conditions for inclusion:**

1. EscalationRecord table must be fully designed and its state machine formally documented in OPERATIONAL_MODELS.md §4.
2. Every value must be traceable to a specific state transition in the EscalationRecord state machine diagram.
3. The complete set of terminal states must be identified and distinguished from intermediate states.
4. The relationship between `escalation_record_status` and `escalation_resolution_type` must be formally specified (e.g., which resolution types are valid in which status transitions).
5. DP must approve the state machine before the enum is introduced.

**Target migration:** The migration that creates the EscalationRecord table (co-deployed with `escalation_resolution_type`).

---

### 1b. `escalation_resolution_type`

**Proposed values (provisional, not approved):**  
`resolved_accepted` / `resolved_rejected` / `resolved_partial` / `withdrawn` / `superseded_by_policy` / `expired_no_action` / `transferred_external`

**Classification when designed:** Enum — describes how an EscalationRecord was concluded. Terminal-state discriminator only; not a lifecycle progression type.

**Reason for deferral:**  
EscalationRecord is not yet designed (OPERATIONAL_MODELS.md §4.1 explicitly states this). `escalation_resolution_type` is meaningful only in the context of the EscalationRecord state machine — specifically, it applies at the transition into terminal states (those from which no further escalation progression is possible). Without the state machine, the value list is speculative, and embedding speculative values in a foundational migration creates schema that cannot be altered without a new migration.

Additionally, valid resolutions depend on which statuses are terminal vs intermediate (e.g., a `resolved_partial` outcome may only be valid from the `waiting_external` status, not from `in_progress`). These status-to-resolution combinations must be formally specified before the enum is introduced.

**Note on `escalation_default_action`:** This field lives on EscalationPolicy (which is designed), not on EscalationRecord. It remains in `0001_types_and_vocabularies.sql`. Only the resolution type — which describes the outcome of an EscalationRecord — is deferred.

**Conditions for inclusion:**

1. EscalationRecord table must be fully designed and its state machine formally documented in OPERATIONAL_MODELS.md §4.
2. Terminal states must be identified and distinguished from intermediate states in the state machine diagram. `escalation_resolution_type` applies only at transitions into terminal states.
3. The valid status-to-resolution combinations must be formally specified — which resolution types are valid from which status values.
4. Cancellation and supersession semantics must be defined: what triggers a `withdrawn` or `superseded_by_policy` resolution, and how those differ from ordinary resolution paths.
5. The effect of `escalation_default_action` (from EscalationPolicy) on resolution outcomes must be documented — specifically, what happens if no explicit resolution action is taken before the escalation deadline.
6. DP must approve the complete state machine and the resolution type value list before either enum is introduced.

**Target migration:** The migration that creates the EscalationRecord table (co-deployed with `escalation_record_status`).

---

## 2. `person_lifecycle_status`

**Proposed values:**  
`living` / `deceased` / `unknown` / `presumed_deceased`

**Classification when designed:** Requires architectural decision (see below)

**Reason for deferral:**  
`person_lifecycle_status` describes a factual condition about a person. The P2 principle holds that changeable, uncertain, temporal, disputed, or sourced facts must not be direct fields. A person's vitality status is:

- **Temporal** — changes over time (living → deceased)
- **Uncertain** — may require evidence (`presumed_deceased`, `unknown`)
- **Disputed** — can be contested
- **Sourced** — requires documentary or oral evidence

These characteristics place `person_lifecycle_status` squarely in the domain of Claims. However, LifeBook also uses lifecycle status as a governance shortcut: the AuthorityAssignment and ApprovalPolicy systems depend on knowing whether a subject is living (with capacity) or deceased (with/without preferences) to select the correct governance lifecycle condition.

The architectural question that must be resolved before this type is introduced:

**Question A:** Is `person_lifecycle_status` a **materialized cache** of the best available Claim about vitality, governed by the same evidence_status promotion rules as all other Claims?

**Question B:** Is it an **authoritative field** set directly by a steward, independent of the Claim layer?

**Question C:** Is it **derived** from governance_lifecycle_condition on the active AuthorityAssignment, making Person.lifecycle_status a denormalization?

If the answer is A, then the field exists on Person but is populated and governed by the Claim promotion pipeline, not by direct update — and the vocabulary should align with evidence quality. If the answer is B, it is a steward-controlled field and should be an enum. If the answer is C, it may not need to exist as a direct field at all.

**Conditions for inclusion:**

1. The authority and derivation model must be documented in ANCHOR_MODELS.md §2.
2. The relationship between Person.lifecycle_status and Person's Claims (particularly vitality claims) must be formally specified.
3. The derivation or update mechanism must be described.
4. Any interaction with governance_lifecycle_condition selection must be documented.
5. DP must approve the authority model before this field and its vocabulary are introduced.

**Target migration:** The migration that creates the Person table (likely 0002 or 0003).

---

## 3. `source_derivative_type` (enum — removed as duplicate)

**Proposed values:**  
`exact_transcript` / `extracted_claims` / `sanitized_summary` / `identity_resolution_tokens` / `access_metadata`

**Reason for removal:**  
The reference table `source_derivative_types` (I.21 in the v1 audit) already carries this vocabulary. The enum `source_derivative_type` in Section D.10 of the v1 SQL was a duplicate semantic system created in error — the same five values appeared as both a PostgreSQL enum and a reference table.

**Resolution:**  
The reference table `source_derivative_types` is retained in 0001. The enum `source_derivative_type` is not created. The owning column on SourceDerivative will be `derivative_type_code TEXT NOT NULL REFERENCES source_derivative_types(code)`.

**No further action required** — this is a removal, not a deferral.

---

## Summary Table

| Type | Kind | Reason | Target |
|------|------|---------|--------|
| `escalation_record_status` | Enum | EscalationRecord not yet designed; state machine and value list provisional | EscalationRecord migration (co-deployed with escalation_resolution_type) |
| `escalation_resolution_type` | Enum | EscalationRecord not yet designed; valid resolutions depend on terminal-state definition; status-to-resolution combinations not specified | EscalationRecord migration (co-deployed with escalation_record_status) |
| `person_lifecycle_status` | Enum or field | Authority/derivation model not resolved; P2 principle may prohibit direct field | Person table migration |
| `source_derivative_type` | Enum | Duplicate of `source_derivative_types` reference table; removed, not deferred | N/A — removed |
