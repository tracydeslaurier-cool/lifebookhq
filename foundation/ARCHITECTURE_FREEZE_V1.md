# LifeBook Architecture Freeze — Version 1
**Version:** 1.2  
**Status:** Frozen — no architectural principle in this document may be modified without a formal Discovery Partner revision session  
**Produced:** 2026-07-23  
**Produced by:** Architecture session — Discovery Partner + Claude

### Revision history

| Version | Date | Summary | Supersedes |
|---|---|---|---|
| 1.0 | 2026-07-23 | Initial freeze; governed documents incorrectly classified GOVERNANCE_MODELS.md, OPERATIONAL_MODELS.md, and PERSON_ATTRIBUTE_CATALOGUE.md as "not yet written" | — |
| 1.1 | 2026-07-23 | Corrected document register based on actual file content; added APPROVAL_INSTANCE_MODEL.md; documented design gaps (ApprovalRecord, AuthorityBasisRecord, PersonName confidence normalization); resolved LifeBook jurisdiction and MergeRecord approval conflicts | 1.0 |
| 1.2 | 2026-07-25 | Closed §5 gaps: AuthorityBasisRecord (G1) resolved — eliminated by GOVERNANCE_MODELS.md §2, replaced by nullable `basis_claim_id` FK + `authority_basis_type` enum on AuthorityAssignment; PersonName confidence normalization (G2) resolved — PERSON_ATTRIBUTE_CATALOGUE.md v0.2 applies four separate status fields; AttributeDisplayPolicy gap remains open — design session required before migration | 1.1 |

This document records the frozen state of LifeBook's v1 architecture. It is not a design document — it does not define fields or relationships. It records what has been decided, by whom, and at what version. Any future session proposing to change an item in §3 must explicitly cite this document and provide a rationale accepted by the Discovery Partner.

---

## 1. Governed document register

| Document | Version | Actual state | Governance type |
|---|---|---|---|
| `ANCHOR_MODELS.md` | 0.2 | **Approved** | Structural — entity supertype, subtypes, LifeBook, authority, and user profile schemas |
| `CONTENT_LAYER.md` | 0.3 | **Approved** | Structural — Claim, Relationship, Narrative, Source, Event, Artifact, AI context, and all controlled vocabularies governing content |
| `CLAIM_PREDICATE_CATALOGUE.md` | 0.2 | **Approved** — 74 predicates | Catalogue — authoritative definition of all ClaimPredicates; governs seed data |
| `RELATIONSHIP_TYPE_CATALOGUE.md` | 0.1 | **Approved** — 27 types | Catalogue — authoritative definition of all RelationshipTypes; governs seed data |
| `GOVERNANCE_MODELS.md` | 0.1 Draft | **Substantially designed** — AuthorityAssignment, ApprovalPolicy, ConflictResolutionPolicy, structured authority basis, decision matrix, content type rules, and interaction rules are field-complete. Missing: ApprovalRecord (instance model — addressed in APPROVAL_INSTANCE_MODEL.md), AuthorityBasisRecord (referenced nullable FK; not yet designed), CapacityDetermination (referenced in open questions; not a current FK dependency; deferred) | Structural — governs Group 5 tables |
| `OPERATIONAL_MODELS.md` | 0.1 Draft | **Field-complete** — EscalationPolicy, ContestRecord, Jurisdiction (10 launch jurisdictions), JurisdictionPolicyVersion, and EscalationRecord are all fully modelled. Open questions are application-layer implementation details (notification infrastructure, SLA scheduling, party isolation in dispute UI), not migration blockers. One field rename required: `EscalationRecord.approval_workflow_id` → `approval_record_id` (→ ApprovalRecord) | Structural — governs Group 10 tables and Jurisdiction |
| `PERSON_ATTRIBUTE_CATALOGUE.md` | 0.1 Draft | **Field-complete for structure** — PersonName (13 usage types), PersonNameDerivative, PersonPronouns, and PersonGenderDescriptor are all fully modelled with authority, display, search, export, and conflict-resolution rules. One normalization required before migration: PersonName.`confidence` uses the old combined enum (`asserted / inferred / supported / corroborated / approximate / disputed / contradicted / unresolved`) and must be replaced with separate `evidence_status`, `dispute_status`, and `precision_status` fields per CONTENT_LAYER.md v0.3 §18.5 | Catalogue — governs person attribute subtables |
| `APPROVAL_INSTANCE_MODEL.md` | 1.0 | **Approved** — ApprovalRecord model defined; corrects prior conflation of ApprovalPolicy (template) with approval instances in MergeRecord and CrossLifeBookAuthorization FKs | Structural — governs ApprovalRecord table and consequential record FK rules |
| `SCHEMA_INVENTORY.md` | 0.2 | **Current** — reflects approved additions; FK terminology errors noted (see §1.1 below) | Inventory — dependency-ordered table list; governs migration sequence |
| `SEMANTIC_COLLISION_REPORT.md` | 0.2 | **Approved** — all 9 gaps resolved or deferred | Audit — semantic collision analysis; not an independent design document |
| `PRE_MIGRATION_CLOSURE.md` | 1.2 | **Current** | Gate record — approval state, migration authorization, and stage gate model |
| `MIGRATION_SCOPE_MATRIX.md` | 1.1 | **Current** | Classification — table-by-table migration readiness |
| `AI_CONTEXT_BROKER.md` | (current) | Not modified in this session | Structural — governs AI model invocation, ContextManifest, and SourceDerivative sanitization |
| `DESIGN_DOCTRINES.md` | 0.1 | **New — 2026-07-25** — ten enduring design philosophies governing LifeBook across all subsystems; intentionally independent of implementation; expected to evolve slowly over the lifetime of the platform | Foundational — operating philosophy; not a requirements or schema document |
| `MEMORY_ATMOSPHERE_ENGINE.md` | 0.1 Draft | **New — 2026-07-24** — architectural specification; not yet implemented. Defines the governed contextual subsystem responsible for emotional and sensory atmosphere during memory-gathering sessions. Depends on AI_CONTEXT_BROKER.md, GOVERNANCE_MODELS.md, CONTENT_LAYER.md | Structural — governs atmosphere level model, inertia rules, safety constraints, trauma-sensitive behaviour, governance and consent tiers, and relationship to upstream subsystems |

### 1.1 Known FK terminology errors requiring correction before migration

The following FK references in SCHEMA_INVENTORY.md (and likely in ANCHOR_MODELS.md) use `ApprovalPolicy` where they must use `ApprovalRecord`. These must be corrected before those tables' migration files are written.

| Table | Field | Currently references | Must reference |
|---|---|---|---|
| `MergeRecord` | `approval_record_id` | ApprovalPolicy | ApprovalRecord (NOT NULL) |
| `CrossLifeBookAuthorization` | `approval_a_id` | ApprovalPolicy | ApprovalRecord (NOT NULL) |
| `CrossLifeBookAuthorization` | `approval_b_id` | ApprovalPolicy | ApprovalRecord (NOT NULL) |
| `CrossLifeBookAuthorization` | `person_authorization_id` | ApprovalPolicy | ApprovalRecord (nullable — only when person consent is required) |
| `EscalationRecord` | `approval_workflow_id` | (unnamed/undefined) | ApprovalRecord (nullable, renamed to `approval_record_id`) |

---

## 2. Architectural constants

The following values are sealed. Changing any of them requires a formal Discovery Partner revision session producing a new ARCHITECTURE_FREEZE document version.

### 2.1 `entity_type` values
`person` / `organization` / `place` / `vessel` / `community` / `event_series`

### 2.2 `evidence_status` values
`unreviewed` / `asserted` / `inferred` / `supported` / `corroborated`

Does not encode dispute (→ `dispute_status`) or review state (→ `review_status`).

### 2.3 `precision_status` values
`exact` / `approximate` / `range` / `unknown`

Temporal and locational precision only. Does not encode evidence confidence or dispute.

---

## 3. Frozen architectural principles

**P1 — User ≠ Person**
`auth.users` / `user_profiles` represent authenticated accounts. `Person` (as an `Entity` subtype) represents a human identity. A UserPersonLink connects them; it is optional and does not automatically confer subject identity. No field or trigger may assume that a user's account UUID is equivalent to any person entity ID.

**P2 — Claims own facts**
No changeable, uncertain, temporal, disputed, or sourced fact may be a direct authoritative field on an anchor or subtype table. All such facts belong in the Claim layer. Cached fields (prefixed `cached_`) are permitted on anchor tables for performance, but must carry lineage fields and must be invalidated on AccessPolicyChangedEvent.

**P3 — One predicate, one semantic relationship**
No ClaimPredicate may accept both a Place and a Date as its object. Predicates are strictly split (e.g., `born_at` → Place only; `born_on` → Date only). This rule is absolute and applies to all 74 predicates in the v0.2 catalogue and to any future predicate additions.

**P4 — Relationship is durable; Claim proposes**
A Relationship is a durable structural link between two entities. A Claim proposes, supports, or describes. When a Claim reaches `policy_approved`, the system may verify or create a corresponding Relationship. Both are retained; neither supersedes the other.

**P5 — State transitions are not RelationshipTypes**
A state change (separation, dissolution, departure) is an Event or Claim, not a RelationshipType. RelationshipTypes describe durable structural connections. No event_type or state transition may be added to RELATIONSHIP_TYPE_CATALOGUE.md.

**P6 — Three-layer architecture**
The system has three distinct layers: (1) global identity linkage; (2) LifeBook-specific content; (3) explicit cross-LifeBook permission. No content record in layer 2 may reach a user in a different LifeBook without an explicit layer 3 authorization.

**P7 — `associated_with` cannot auto-promote**
The predicate `associated_with` carries `relationship_interaction = none`. It does not auto-propose a RelationshipType. A Claim using this predicate may not reach `policy_approved` without explicit reviewer rationale or supersession by a typed predicate or Relationship.

**P8 — DNA source data is restricted by default**
All Claims with `source_type = dna_analysis` are `restricted` access_classification at creation. The raw_genotype_file sub-type is deploy-disabled. No relaxation of DNA source restrictions may be applied without explicit Discovery Partner sign-off.

**P9 — Audit records are permanent**
`AccessPolicyChangedEvent` and `ContextManifest` records must never be deleted. RLS must deny DELETE for all roles on these tables. This is not configurable.

**P10 — civil_partnership and marriage are distinct**
`in_civil_partnership_with` is a distinct predicate from `married_to`. It proposes a `civil_partnership` RelationshipType and may generate a `civil_partnership_registration` event. No system path may route a civil partnership through `married_to`, `marriage`, or the `marriage` event type.

**P11 — Coordinate fields on Place are cached, not authoritative**
`cached_latitude`, `cached_longitude`, and `coordinate_precision` on the Place table are cached representative coordinates. Authoritative geometry belongs in the Claim layer or a future PlaceGeometry table.

**P12 — ApprovalRecord instances, not ApprovalPolicy templates, authorize consequential actions**
ApprovalPolicy defines governance rules. ApprovalRecord proves those rules were satisfied for a specific action on a specific record. MergeRecord, CrossLifeBookAuthorization, and any future consequential table must carry a NOT NULL FK to an `approved` ApprovalRecord. A completed consequential record without an explicit approval instance must not exist.

**P13 — LifeBook.primary_jurisdiction_id is NOT NULL**
A LifeBook without a jurisdiction is a governance object whose rules cannot be resolved — age-of-majority, erasure policy, data residency, authority succession, and deployment eligibility all depend on it. `primary_jurisdiction_id` must be NOT NULL. The migration dependency is resolved by placing Jurisdiction (and its minimum seed records) before LifeBook in the migration sequence, not by making the FK nullable.

---

## 3a. Candidate Principles — Pending Discovery Partner Approval

The following proposed principles have been drafted and documented but are **not yet part of the frozen set**. They may not be cited as architectural constraints until ratified in a formal Discovery Partner revision session producing a new ARCHITECTURE_FREEZE document version.

**Candidate Principle P14 — Atmosphere is subordinate to cognition**  
*Proposed: 2026-07-24 — Status: Pending Discovery Partner approval — See ADR-0002*

Proposed wording:

> The Memory Atmosphere Engine may only create conditions that support authentic memory. It may never tell the participant what to remember. It may not direct, bias, dramatize, or substitute for recollection. Any feature, output, or configuration that produces imagery or sensory cues derived solely from conversational keyword extraction — without topic stability, confidence gating, and sensitivity evaluation — violates this principle. This constraint applies regardless of technical feasibility or apparent user benefit.

This principle will move to §3 and be assigned a permanent number upon formal Discovery Partner ratification.

---

## 4. Deferred design items — v2 or later

**ConstraintProfile** — per-LifeBook predicate restriction mechanism; deferred to v2. V1 applies predicate restrictions globally.

**evidence_status — submission origin separation** — current five-value enum is canonical for v1. Separation of assertion origin from evidentiary strength is a v2 consideration.

**PlaceGeometry table** — authoritative area-based or disputed geometry; deferred. V1 stores only cached representative coordinates.

**OrgName versioned attribute table** — organization name versioning; not yet designed; excluded from v1 migration.

**CapacityDetermination records** — referenced in GOVERNANCE_MODELS.md §9.4; no current FK dependency in defined tables; not a migration blocker; design deferred.

---

## 5. Design gaps requiring completion before affected tables are migrated

The following items are not deferred to v2 — they must be designed before the specific tables that depend on them can be migrated. They do not block the broader migration.

| Gap | Affects | Current state |
|---|---|---|
| `ApprovalRecord` model | MergeRecord (NOT NULL FK), CrossLifeBookAuthorization (NOT NULL FKs × 3) | **Resolved** — APPROVAL_INSTANCE_MODEL.md v1.0 |
| `AuthorityBasisRecord` model | AuthorityAssignment | **Resolved (G1) — 2026-07-25.** AuthorityBasisRecord eliminated by GOVERNANCE_MODELS.md §2. AuthorityAssignment carries nullable `basis_claim_id` (FK → claims) and `authority_basis_type` enum directly. No separate AuthorityBasisRecord table. DP-authorized in PRE_SQL_READINESS_REVIEW.md §3.4. |
| `PersonName.confidence` normalization | PersonName, PersonNameDerivative tables | **Resolved (G2) — 2026-07-25.** PERSON_ATTRIBUTE_CATALOGUE.md v0.2 replaces combined `confidence` with four separate fields: `evidence_status`, `dispute_status`, `precision_status`, `review_status`. PersonNameDerivative carries independent `review_status` (not inherited from parent). |
| AttributeDisplayPolicy field-level definition | PersonName, PersonPronouns, PersonGenderDescriptor (all reference display policies) | **Open — design session required.** Sparse definition in SCHEMA_INVENTORY.md row 5.4 is insufficient for migration. No SQL may be written for `attribute_display_policies` or for tables that FK to it until this session is completed. See PRE_SQL_READINESS_REVIEW.md §3.1 and §4.3. |
