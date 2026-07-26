# Migration 0002 — Pre-SQL Readiness Review
**Version:** 0.9  
**Status:** Architecture phase complete — all architectural blockers resolved; RLS design session is the sole remaining gate before SQL authoring  
**Produced:** 2026-07-25  
**Produced by:** Discovery Partner + Claude (architecture session)

---

This document is the final gate before migration SQL may be written. It records the status of every pre-SQL prerequisite.

**GATE STATUS: ALL GATES CLEARED — MIGRATION 0002 AND 0003 SQL AUTHORING AUTHORIZED**

---

## 1. Pre-SQL Deliverables — Final Status

| Deliverable | File | Status |
|---|---|---|
| Migration scope proposal | `foundation/MIGRATION_0003_PROPOSAL.md` v0.2 | Approved in principle — updated with DisplayPolicy scope |
| Discovery Operations Model | `foundation/DISCOVERY_OPERATIONS_MODEL.md` v0.2 | Revised — approved |
| PersonName confidence normalization (G2 blocker) | `foundation/PERSON_ATTRIBUTE_CATALOGUE.md` v0.2 | Approved — G2 resolved; display contexts section updated |
| Migration philosophy | `foundation/MIGRATION_PHILOSOPHY.md` | Revised — approved for migration preamble; §1 and §3 updated with expanded 0002 scope |
| ClaimPredicate seed authoring plan | `foundation/CLAIM_PREDICATE_SEED_PLAN.md` v0.3 | Decisions 4.1 and 4.2 recorded |
| DisplayPolicy model | `foundation/DISPLAY_POLICY_MODEL.md` v0.1 | New — field-complete; AttributeDisplayPolicy blocker resolved |
| Governance Enforcement Model | `foundation/GOVERNANCE_ENFORCEMENT_MODEL.md` v0.1 | New — architecture complete; three new blockers identified (§4.5) |

---

## 2. All Three Blockers — Final Status

| Blocker | Status |
|---|---|
| G1 — AuthorityBasisRecord eliminated | **Resolved.** Direct Claim FK (`basis_claim_id`) on AuthorityAssignment. ARCHITECTURE_FREEZE_V1.md §5 closure authorized — update may be made. |
| G2 — PersonName confidence normalization | **Resolved.** PERSON_ATTRIBUTE_CATALOGUE.md v0.2 carries `evidence_status`, `dispute_status`, `precision_status`, `review_status` on PersonName; independent `review_status` (not inherited) on PersonNameDerivative. |
| G3 — FK terminology (ApprovalPolicy → ApprovalRecord) | **Resolved.** Corrections documented; will be applied correctly in SQL. |

---

## 3. Recorded DP Decisions

### 3.1 AttributeDisplayPolicy field completeness
**Decision: Design session required before SQL.**

AttributeDisplayPolicy must be designed before the relevant SQL is written. Batch 5 tables can proceed up to and including `conflict_resolution_policies`; `attribute_display_policies` table DDL is blocked until the design session is completed.

**Complete blocking impact — verified against SCHEMA_INVENTORY.md, CONTENT_LAYER.md, and MIGRATION_SCOPE_MATRIX.md:**

All FK references to `attribute_display_policies` are nullable, but PostgreSQL still requires the referenced table to exist at CREATE TABLE time. The following 11 tables cannot be created until `attribute_display_policies` is designed and written:

| Table | Batch | FK field |
|---|---|---|
| `Claim` | 7.1 | `display_policy_id` (nullable) |
| `Relationship` | 6.3 | `display_policy_id` (nullable) |
| `Narrative` | 7.3 | `display_policy_id` (nullable) |
| `NarrativeEntity` | 7.4 | `display_policy_id` (nullable) |
| `Source` | 7.5 | `display_policy_id` (nullable) |
| `Artifact` | 7.7 | `display_policy_id` (nullable) |
| `Event` | 7.10 | `display_policy_id` (nullable) |
| `EventParticipant` | 7.11 | `display_policy_id` (nullable) |
| `PersonName` | 14.1 | relational (one record per display context per attribute) |
| `PersonPronouns` | 14.3 | relational (one record per display context per attribute) |
| `PersonGenderDescriptor` | 14.4 | relational (one record per display context per attribute) |

The prior version of this document listed only three tables. This was incomplete. The correct count is 11 tables, including the entire content layer (Claim, Relationship, Narrative, Source, Artifact, Event, and their junction tables).

**Impact on 0003 scope:** The core-schema migration cannot be written without AttributeDisplayPolicy. The design session is a hard prerequisite for any SQL authoring. Recommend: proceed directly to AttributeDisplayPolicy design session.

### 3.2 PersonName tables — include in the core-schema migration (0003)
**Decision: Include in the core-schema migration (0003).**

Batch 14 (PersonName, PersonNameDerivative, PersonPronouns, PersonGenderDescriptor) remains in the core-schema migration (0003). The G2 blocker is resolved. This decision holds pending resolution of §3.1 (AttributeDisplayPolicy design).

### 3.3 Migration file strategy — one migration file per logical purpose
**Decision: One migration file per logical purpose. An intervening vocabulary migration is required before the core-schema migration.**

Decision 4.2 (see §4.2) requires a new `relationship_interaction_type` enum type. Migration 0001 is already applied; new enum types cannot be inserted into it. Per MIGRATION_PHILOSOPHY.md, each migration has one logical purpose and is additive. The new enum must be introduced in a separate vocabulary migration before the core-schema migration.

**Updated migration sequence:**

| Ordinal | Filename | Logical purpose | Status |
|---|---|---|---|
| 0001 | `20260724153745_types_and_vocabularies.sql` | All enum types and controlled vocabularies | Applied 2026-07-24 |
| 0002 | `<TIMESTAMP>_predicate_governance_types.sql` | `relationship_interaction_type` enum and any additional governed types required by core-schema | Pending — SQL not yet authorized |
| 0003 | `<TIMESTAMP>_core_schema.sql` | All tables, constraints, triggers, and seed data for the structural layer | Pending — SQL not yet authorized |

Filenames are provisional placeholders (`<TIMESTAMP>_...`) until authoring time. Do not hard-code filenames in any downstream document.

### 3.4 ARCHITECTURE_FREEZE_V1.md §5 G1 closure — authorized
**Decision: Authorized.**

The AuthorityBasisRecord gap entry in ARCHITECTURE_FREEZE_V1.md §5 may be updated to reflect its resolution. This update is authorized as a documentation correction, not a new architectural decision.

**Done.** ARCHITECTURE_FREEZE_V1.md v1.2 applied 2026-07-25.

### 3.5 Culturally governed content and AI-promotion RLS — design now
**Decision: Design now, in the core-schema migration (0003).**

RLS policies for culturally governed content exclusion and AI-generated content promotion restriction must be designed and written as part of the core-schema migration (0003). These policies must be documented in VOCABULARY_RLS_MATRIX.md before SQL is written.

**Impact:** Two RLS design tasks must be completed before SQL authoring:
- Culturally governed content: row-level exclusion policy on content tables
- AI-generated content promotion: deny direct UPDATE of `review_status` to `policy_approved` for AI-generated records without an approved ApprovalRecord

### 3.6 Discovery Registry — structured registry from day one
**Decision: Structured database from day one.**

DISCOVERY_OPERATIONS_MODEL.md v0.2 reflects this decision. A spreadsheet may serve as an operational export view; it is not the authoritative system of record.

**Open questions from DISCOVERY_OPERATIONS_MODEL.md §7** (registry platform selection and media storage platform) must be resolved before any participant data is collected.

---

## 4. New Open Items Arising From Revisions

These items were not in the original readiness review. They are raised by the DP revision instructions and require decision before SQL authoring.

### 4.1 nullable `created_by_id` on catalogue tables
**From CLAIM_PREDICATE_SEED_PLAN.md §2.1 — Decision recorded 2026-07-25**

**Decision: Approved with modification.**

`created_by_id` may be nullable on catalogue and reference tables (ClaimPredicate, ClaimValueUnit, RelationshipType, AgentRegistry, ContextProfile, and any other reference table seeded by migration). However, NULL alone is not sufficient provenance. Records without a user creator must carry an explicit, non-null system-origin identifier.

**Implementation requirement:** Catalogue tables must carry a companion field:
```
created_by_system   TEXT    -- NOT NULL for seed records; NULL for application-created records
```
Seed records inserted by the migration must have `created_by_system = 'migration:<migration_filename>'` (e.g., `'migration:<actual_core_schema_filename>'`). Application-created records must have `created_by_system = NULL` and `created_by_id NOT NULL`.

**Constraint:** A CHECK constraint must enforce that at least one of `created_by_id` or `created_by_system` is non-null:
```sql
CHECK (created_by_id IS NOT NULL OR created_by_system IS NOT NULL)
```

**Implication for CLAIM_PREDICATE_SEED_PLAN.md:** §2.1 must be updated to reflect this modification. The seed records will carry `created_by_id = NULL, created_by_system = 'migration:<actual_core_schema_filename>'`.

### 4.2 Governed predicate metadata columns on `claim_predicates`
**From CLAIM_PREDICATE_SEED_PLAN.md §2.2 — Decision recorded 2026-07-25**

**Decision: Approved with modifications.**

Store predicate governance metadata as data-driven columns on `claim_predicates`. Do not hard-code these behaviours in application logic. The three columns are approved with the following names and types (revised from the proposal):

| Column (approved name) | Proposed name | Type | Notes |
|---|---|---|---|
| `relationship_interaction` | `relationship_interaction` | `relationship_interaction_type` enum | Unchanged — requires new enum in vocab migration 0002 |
| `default_access_classification` | `sensitivity_default` | `access_classification` enum (from 0001) | Renamed for clarity |
| `generates_event_type` | `generates_event` | `TEXT REFERENCES event_types(code)` | Renamed; governed FK — not unrestricted text (see §4.2.1) |

**`relationship_interaction_type` enum — vocabulary migration required:**

This is a new enum type. Migration 0001 is already applied and immutable. Per MIGRATION_PHILOSOPHY.md §1 and §8, new types must be introduced in a new migration. This enum must be created in migration 0002 (`<TIMESTAMP>_predicate_governance_types.sql`) before the core-schema migration can reference it.

Four values (from CLAIM_PREDICATE_SEED_PLAN.md §2.2):
```
proposes | supports | describes | none
```

#### 4.2.1 `generates_event_type` — governed vocabulary confirmed

**The governed vocabulary for `generates_event_type` is the `event_types` reference table established in migration 0001.**

`event_types` is a governed reference table (not a free text field) with 21 seeded codes including `birth`, `marriage`, `civil_partnership_registration`, `death`, `immigration`, `adoption`, and `other`. The column must be typed as `TEXT REFERENCES event_types(code)` (nullable FK). This is not unrestricted text.

**Implication:** `generates_event_type` is a FK to a table that already exists in 0001. No additional vocabulary migration is required for this column. The FK constraint is safe to write in the core-schema migration (0003).

**Implication for CLAIM_PREDICATE_SEED_PLAN.md:** §2.2 must be updated to reflect the three approved column names, the `generates_event_type` FK type, and the vocabulary migration requirement for `relationship_interaction_type`.

### 4.3 AttributeDisplayPolicy design session
**From §3.1 above — blocking impact confirmed as 11 tables**

**Fully resolved — DISPLAY_POLICY_MODEL.md v0.1 produced 2026-07-25. All four closure items decided by Discovery Partner 2026-07-25.**

The two-table model (`display_policies` + `display_policy_rules`) is field-complete and approved. All closure items are decided. The AttributeDisplayPolicy blocker is fully resolved.

| Closure item | Decision |
|---|---|
| A — Draft lifecycle | Approved with simplification. Draft = editable + deletable. A record becomes part of permanent governance when status → active. No evaluation-tracking mechanism required. |
| B — Lifecycle enforcement | Option D approved. Application manages workflow. Database enforces invariants via BEFORE UPDATE/DELETE triggers (status-transition rules + immutability). No business logic in triggers. |
| C — Authority model | Option C approved. Schema validates FK existence. Authority rules for specific record types belong to RLS + application workflow. `display_policies` DDL is unblocked. |
| D — Cardinality | Option A approved. Operative policies are record-specific by application invariant. Future hardening: UNIQUE(display_policy_id) partial index on each governed table as a V1.1 item. |

Design constants confirmed:
- No `entity_id` on `display_policies`; no discriminator field
- Field name: `display_context_code TEXT NOT NULL REFERENCES display_contexts(code) ON UPDATE RESTRICT ON DELETE RESTRICT`
- UNIQUE (display_policy_id, display_context_code)
- `display_contexts.code` is TEXT PRIMARY KEY
- `display_contexts` is a reference table (not enum); rationale documented in DISPLAY_POLICY_MODEL.md §11
- Migration 0002 scope: 3 enums + `display_contexts` table + 9 seed records (DDL, seed data, and constraints)
- Exactly 3 deferred FKs: `authority_assignments.basis_claim_id → claims(id)`, `display_policies.approval_record_id → approval_records(id)`, and `lifebook_person_contexts.permission_cache_policy_version_id → approval_policies(id)` (Deferred FK 3; added after Batch 5 `approval_policies` DDL)
- `claims.superseded_by_claim_id` is an inline nullable self-reference, NOT a deferred FK

### 4.5 Governance Enforcement Model — three new blockers identified

**From GOVERNANCE_ENFORCEMENT_MODEL.md v0.1 §15 — produced 2026-07-25. Requires DP decision.**

Three architectural questions were surfaced during the Governance Enforcement Model design session that were not previously recorded. None block migration 0002 or the majority of migration 0003 tables. Each blocks a specific table's DDL or RLS authoring.

**Blocker 1 — Relationship versioning model**

Claims are versioned via `superseded_by_claim_id`. The `relationships` table has no equivalent field. The governance model for Relationships is unresolved: mutable in place (requires UPDATE permission model + audit trail), versioned (requires `superseded_by_relationship_id` field addition), or immutable once active.

Recommendation: versioned (Option B in GEM §15, Blocker 1). Mirrors Claims. Requires adding `superseded_by_relationship_id UUID NULLABLE FK → relationships(id)` to the `relationships` table in migration 0003.

Blocks: `relationships` table DDL and RLS authoring.

**Blocker 2 — Claim → Event back-reference**

When a Claim with `generates_event_type` non-null results in Event creation, there is no structural back-reference from the Event to the originating Claim. Without it, the audit chain is incomplete.

Recommendation: add `source_claim_id UUID NULLABLE FK → claims(id)` to the `events` table (Option B in GEM §15, Blocker 2).

Blocks: `events` table DDL (if Option B chosen; the field must be in migration 0003).

**Blocker 3 — ContestRecord standing**

Who has standing to initiate a ContestRecord (dispute) is not defined in any existing document. Standing governs who may set `dispute_status = disputed / contradicted` and who may create a ContestRecord.

Recommendation: governed standing (Option C in GEM §15, Blocker 3). Subject, steward, original asserting party, or a party with an applicable AuthorityAssignment for the relevant action type.

Blocks: ContestRecord INSERT RLS and the `trg_claim_dispute_requires_contest_record` trigger design.

### 4.4 RLS policy design — for the core-schema migration (0003)
**From §3.5 above; expanded to include DisplayPolicy enforcement**

The following RLS policies and triggers must be designed and documented in VOCABULARY_RLS_MATRIX.md before SQL authoring:

1. Culturally governed content exclusion — row-level exclusion on content tables for `access_classification = culturally_governed`
2. AI-generated content promotion restriction — deny direct UPDATE of `review_status` to `policy_approved` for AI-generated records without an approved ApprovalRecord
3. `display_policies` and `display_policy_rules` — RLS policies (DELETE restrictions; UPDATE restrictions) and BEFORE UPDATE/DELETE trigger specs for lifecycle enforcement (DISPLAY_POLICY_MODEL.md §7.2)

**Action required:** RLS design session covering all three items.

---

## 5. Pending Actions Before SQL Authoring Begins

| # | Action | Status | Blocks |
|---|---|---|---|
| 1 | DP decision on nullable `created_by_id` (§4.1) | **Done — recorded above** | — |
| 2 | DP decision on predicate metadata columns (§4.2) | **Done — recorded above** | — |
| 3 | AttributeDisplayPolicy design session — all closure items decided (§4.3) | **Done — DISPLAY_POLICY_MODEL.md v0.1; all decisions recorded 2026-07-25** | — |
| 4 | RLS design session for culturally governed content and AI promotion (§4.4) | Open | Content table RLS policies |
| 8 | DP decision: Relationship versioning model (§4.5 Blocker 1) | **Done — Option B approved 2026-07-25; `superseded_by_relationship_id UUID NULL` added** | — |
| 9 | DP decision: Claim → Event back-reference (§4.5 Blocker 2) | **Done — approved 2026-07-25; `source_claim_id UUID NULL` added to `events`** | — |
| 10 | DP decision: ContestRecord standing (§4.5 Blocker 3) | **Done — governed-standing model approved 2026-07-25; 7 standing classes defined** | — |
| 5 | ARCHITECTURE_FREEZE_V1.md §5 G1 closure edit (§3.4) | **Done — v1.2 applied** | — |
| 6 | Update CLAIM_PREDICATE_SEED_PLAN.md §2.1 and §2.2 with decision modifications | **Done — v0.3 applied 2026-07-25** | — |
| 7 | Update MIGRATION_0003_PROPOSAL.md and MIGRATION_PHILOSOPHY.md §1 with revised migration filenames and expanded 0002 scope | **Done — applied 2026-07-25** | — |

Item 4 (RLS design session) is the sole remaining gate. Items 8–10 are closed. All architectural blockers are resolved. The architecture phase is complete.

---

## 6. What May Proceed Now (Without Further Authorization)

| Item | Status |
|---|---|
| ARCHITECTURE_FREEZE_V1.md §5 G1 closure edit | Done |
| Update CLAIM_PREDICATE_SEED_PLAN.md §2.1 and §2.2 | Done |
| Update MIGRATION_0003_PROPOSAL.md and MIGRATION_PHILOSOPHY.md §1 with new filenames and expanded 0002 scope | Done |
| AttributeDisplayPolicy design session + all closure items | Done — DISPLAY_POLICY_MODEL.md v0.1; decisions A/B/C/D recorded 2026-07-25 |
| Governance Enforcement Model design session | Done — GOVERNANCE_ENFORCEMENT_MODEL.md v0.1; three new blockers identified |
| RLS design session — culturally governed content, AI promotion, display_policies | **Done — VOCABULARY_RLS_MATRIX.md v3.0; SQL authoring now authorized** |
| DP decisions on GEM §15 blockers (Relationship versioning, Event back-reference, ContestRecord standing) | **Done — all three decided 2026-07-25; GEM v0.2 applied** |
| SQL authoring of any kind | Not authorized |

---

## 7. Complete Prerequisites Summary

```
SQL authoring may begin when:
  [x] G1 resolved — ARCHITECTURE_FREEZE_V1.md v1.2 updated
  [x] G2 resolved — PERSON_ATTRIBUTE_CATALOGUE.md v0.2
  [x] G3 resolved — will be applied correctly in SQL
  [x] Migration strategy confirmed — one file per logical purpose
  [x] PersonName tables confirmed in scope
  [x] created_by_id / created_by_system model approved (§4.1)
  [x] Three predicate metadata columns approved with modifications (§4.2)
  [x] relationship_interaction_type enum — vocabulary migration required (§3.3)
  [x] generates_event_type governed vocabulary confirmed — event_types(code) FK (§4.2.1)
  [x] CLAIM_PREDICATE_SEED_PLAN.md §2.1 and §2.2 updated with decision modifications (v0.3)
  [x] MIGRATION_0003_PROPOSAL.md and MIGRATION_PHILOSOPHY.md §1 updated with new filenames and expanded 0002 scope
  [x] AttributeDisplayPolicy design session completed — DISPLAY_POLICY_MODEL.md v0.1; all closure items decided (§4.3)
  [x] Governance Enforcement Model design session completed — GOVERNANCE_ENFORCEMENT_MODEL.md v0.1 (§4.5)
  [x] DP decisions on GEM §15 blockers: Relationship versioning (Option B), Event back-reference (source_claim_id), ContestRecord standing (governed model, 7 classes) — GEM v0.2 applied 2026-07-25
  [x] GEM §17 Architectural Invariants added — 9 invariants documented; architecture phase complete
  [x] RLS design session completed — VOCABULARY_RLS_MATRIX.md v3.0; 53 RLS policies → revised to 65 → final 71 RLS policies, 22 triggers, 9 helper functions; implementation order specified (§4.4)
```

---

**DP decisions recorded 2026-07-25:**

| | |
|---|---|
| **Decision 4.1 — created_by_id / created_by_system:** | Approved with modification — nullable FK permitted; non-null `created_by_system` required for seed records |
| **Decision 4.2 — predicate metadata columns:** | Approved with modifications — column names revised; `generates_event_type` is a governed FK to `event_types(code)`; `relationship_interaction_type` enum requires vocabulary migration 0002 before core-schema |
| **Decision 4.2.1 — generates_event_type vocabulary:** | Confirmed — governed vocabulary is `event_types(code)` from migration 0001; unrestricted text not approved |
