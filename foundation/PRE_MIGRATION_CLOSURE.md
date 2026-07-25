# LifeBook Pre-Migration Closure
**Version:** 1.2  
**Status:** Stage 1 substantially complete — structural SQL authorized for ready table groups; design gaps identified for near-ready groups  
**Produced:** 2026-07-23  
**Produced by:** Architecture session — Discovery Partner + Claude

### Revision history

| Version | Date | Summary | Supersedes |
|---|---|---|---|
| 1.0 | 2026-07-23 | Initial gate record; B1–B5 all pending; no SQL authorized | — |
| 1.1 | 2026-07-23 | B1 and B2 approved; 6-stage gate model adopted; B3–B5 incorrectly classified as "not yet written" (error) | 1.0 |
| 1.2 | 2026-07-23 | Corrected document assessment: GOVERNANCE_MODELS.md, OPERATIONAL_MODELS.md, and PERSON_ATTRIBUTE_CATALOGUE.md are substantially designed, not pending. LifeBook.primary_jurisdiction_id confirmed NOT NULL. ApprovalRecord vs. ApprovalPolicy distinction resolved. B3–B5 reclassified as targeted design gaps, not document-level blockers. Jurisdiction reclassified as ready. | 1.1 |

This document is the authoritative gate record for the LifeBook Supabase migration. It records the approval state of all governed design documents, defines the 6-stage migration gate, and states explicitly which structural SQL is authorized.

---

## 1. Governed document versions

| Document | Version | Status |
|---|---|---|
| `ANCHOR_MODELS.md` | 0.2 | **Approved** |
| `CONTENT_LAYER.md` | 0.3 | **Approved** |
| `CLAIM_PREDICATE_CATALOGUE.md` | 0.2 | **Approved** — 74 predicates |
| `RELATIONSHIP_TYPE_CATALOGUE.md` | 0.1 | **Approved** — 27 types |
| `GOVERNANCE_MODELS.md` | 0.1 Draft | **Substantially designed** — AuthorityAssignment, ApprovalPolicy, ConflictResolutionPolicy, authority basis model, decision matrix, and interaction rules are field-complete. Gaps: ApprovalRecord (now defined in APPROVAL_INSTANCE_MODEL.md v1.0), AuthorityBasisRecord (nullable FK; design pending) |
| `OPERATIONAL_MODELS.md` | 0.1 Draft | **Field-complete** — EscalationPolicy, ContestRecord, Jurisdiction, JurisdictionPolicyVersion, EscalationRecord all fully modelled. Remaining open questions are application-layer implementation details, not migration blockers. One field rename required: EscalationRecord.approval_workflow_id → approval_record_id |
| `PERSON_ATTRIBUTE_CATALOGUE.md` | 0.1 Draft | **Structurally complete** — PersonName (13 usage types), PersonNameDerivative, PersonPronouns, PersonGenderDescriptor fully modelled. One normalization required before migration: PersonName.confidence must be replaced with separate evidence_status, dispute_status, and precision_status fields per CONTENT_LAYER.md v0.3 |
| `APPROVAL_INSTANCE_MODEL.md` | 1.0 | **Approved** — ApprovalRecord model defined; corrects prior FK conflation |
| `SCHEMA_INVENTORY.md` | 0.2 | **Current** — FK terminology errors in MergeRecord and CrossLifeBookAuthorization must be corrected per ARCHITECTURE_FREEZE_V1.md §1.1 before those tables are migrated |
| `SEMANTIC_COLLISION_REPORT.md` | 0.2 | **Approved** |
| `ARCHITECTURE_FREEZE_V1.md` | 1.1 | **Current** |
| `MIGRATION_SCOPE_MATRIX.md` | 1.1 | **Current** |
| `AI_CONTEXT_BROKER.md` | (current) | Not modified in this session |

---

## 2. Resolved semantic additions

All six items from SEMANTIC_COLLISION_REPORT.md §5 are resolved and in the governed documents:

| Item | Predicate / type | Document | Section |
|---|---|---|---|
| New predicate | `apprenticed_to` | CLAIM_PREDICATE_CATALOGUE.md v0.2 | Family 6 |
| New predicate | `associated_with` | CLAIM_PREDICATE_CATALOGUE.md v0.2 | Family 8 |
| New predicate | `in_civil_partnership_with` | CLAIM_PREDICATE_CATALOGUE.md v0.2 | Family 2 |
| New event type | `civil_partnership_registration` | CONTENT_LAYER.md v0.3 | §15.2 |
| New source type | `dna_analysis` | CONTENT_LAYER.md v0.3 | §9.2–9.3 |
| New source type | `court_record` | CONTENT_LAYER.md v0.3 | §9.2 |

---

## 3. Canonical enum values

### 3.1 `evidence_status`
`unreviewed` / `asserted` / `inferred` / `supported` / `corroborated`
Does not encode dispute (→ `dispute_status`) or review state (→ `review_status`).

### 3.2 `precision_status`
`exact` / `approximate` / `range` / `unknown`
Temporal precision only.

---

## 4. Migration gate model

### Stage 1 — Architecture design
**Status: SUBSTANTIALLY COMPLETE**

All governed documents covering the ready and near-ready table groups are either approved or substantially designed with identified, bounded gaps. The two prior decisions (LifeBook jurisdiction FK and MergeRecord approval reference) are now resolved. No new document-level blockers.

Outstanding gaps (targeted, not document-level):
- ApprovalRecord: resolved by APPROVAL_INSTANCE_MODEL.md v1.0
- AuthorityBasisRecord: design not yet started; affects AuthorityAssignment migration only
- PersonName.confidence normalization: PERSON_ATTRIBUTE_CATALOGUE.md update required before PersonName table is migrated

### Stage 2 — Structural migration authoring
**Status: IN PROGRESS — authorized for ready table groups**

Structural SQL may be written and reviewed for all table groups classified `ready` in MIGRATION_SCOPE_MATRIX.md v1.1. Near-ready groups remain excluded until their specific gaps are resolved.

**Authorization statement:** Structural SQL may begin for every table group classified `ready` in MIGRATION_SCOPE_MATRIX.md v1.1. This authorization was issued by the Discovery Partner on 2026-07-23.

**Remaining targeted blockers for specific table groups:**

| Blocker | Scope (tables blocked) | Current state |
|---|---|---|
| G1: AuthorityBasisRecord not yet designed | AuthorityAssignment (nullable FK; blocked pending design) | Design not started |
| G2: PersonName.confidence not normalized | PersonName, PersonNameDerivative | PERSON_ATTRIBUTE_CATALOGUE.md must be updated; no SQL until updated |
| G3: ApprovalRecord FK terminology not yet corrected in SCHEMA_INVENTORY.md and ANCHOR_MODELS.md | MergeRecord (approval_record_id), CrossLifeBookAuthorization (approval_a_id, approval_b_id, person_authorization_id), EscalationRecord (approval_workflow_id) | Must correct references before those tables' migration files are written |

**Confirmed decisions — no further resolution required:**

| Decision | Resolution |
|---|---|
| LifeBook.primary_jurisdiction_id | NOT NULL — Jurisdiction seeded before LifeBook in migration sequence |
| Jurisdiction minimum seed records | CA, CA-AB, UA, INTERNATIONAL_DEFAULT required at migration; CA-QC and EU present with deployment_permitted = false |
| MergeRecord.approval_record_id | NOT NULL — references ApprovalRecord (not ApprovalPolicy); no MergeRecord without an approved ApprovalRecord |
| CrossLifeBookAuthorization approval FKs | All three (approval_a_id, approval_b_id, person_authorization_id) reference ApprovalRecord instances |
| JurisdictionPolicyVersion circular FK | Jurisdiction.current_policy_version_id is nullable at creation; JurisdictionPolicyVersion is created after Jurisdiction; FK populated after seeding via deferred FK or ALTER TABLE |
| ContestRecord ↔ EscalationRecord circular FK | Both nullable; create EscalationRecord first (nullable contest_record_id), then ContestRecord (nullable escalation_record_id); no ALTER TABLE needed |

### Stage 3 — Migration review and validation
**Status: Not started**

Each migration file must be reviewed by the Discovery Partner. Seed data must be approved and validated. Group 11 constraints must be verified against migration sequence.

### Stage 4 — Test deployment
**Status: Not started**

Migration applied to non-production Supabase environment; smoke tests pass; seed data correct; no FK violations; no RLS bypass.

### Stage 5 — Feature enablement
**Status: Not started**

Feature-level gates; none is a migration-wide blocker:

| Blocker | Feature | Condition | State |
|---|---|---|---|
| F1 | `dna_analysis` raw_genotype_file ingestion | Genetic-data governance policy; sub-type deploy-disabled | Not started |
| F2 | AI model invocation (any agent) | AI Context Broker built and verified | Not started |
| F3 | Cross-LifeBook authorization for person entities | Person consent workflow designed and tested | Not started |
| F4 | `associated_with` → `policy_approved` | Review workflow with rationale field built | Not started |

### Stage 6 — Production deployment
**Status: Not started**

Jurisdiction-scoped deployment gates:

| Blocker | Scope | Condition | State |
|---|---|---|---|
| L1 | CA-QC | Quebec Law 25 erasure, AI disclosure, consent | Legal review not started |
| L2 | EU | GDPR right to erasure, portability, adequacy | Legal review not started |
| L3 | `community_type = indigenous_nation` | Community consultation; name governance policy | Blocked |
| L4 | `culturally_governed_processing` ContextProfile | Indigenous governance policy | Blocked |

---

## 5. Seed data blockers

Structural schema may be migrated; these block user-generated records in specific tables:

| Blocker | Condition | State |
|---|---|---|
| S1 | ClaimPredicate seed (74 predicates, v0.2 catalogue) | Catalogue approved; fixture file not yet written |
| S2 | RelationshipType seed (27 types, v0.1 catalogue) | Catalogue approved; fixture file not yet written |
| S3 | ClaimValueUnit seed (11 units, CONTENT_LAYER.md §3.2) | Pending |
| S4 | `trg_claim_numeric_unit_check` trigger (CONTENT_LAYER.md §3.4) | Spec defined; implementation not yet written |
| S5 | Jurisdiction minimum seed (CA, CA-AB, UA, INTERNATIONAL_DEFAULT) | Required before LifeBook table accepts records |

---

## 6. Pre-production design items

Must be complete before production deployment; do not block migration:

- File storage service interface (bucket structure, signed URL expiry, access-classification enforcement)
- OrgName versioned attribute table design
- Guardian/executor verification workflow
- Cross-LifeBook Person consent workflow
- Place historical name query specification (display layer)
- AuthorityBasisRecord table design (also a migration blocker for AuthorityAssignment specifically)
- CapacityDetermination record design (referenced in GOVERNANCE_MODELS.md §9.4; no current FK dependency)

---

## 7. Explicit migration authorization

**Current authorization:** Structural SQL migration may begin for all table groups classified `ready` in MIGRATION_SCOPE_MATRIX.md v1.1.

**Near-ready groups excluded until specific gaps resolve:** AuthorityAssignment (AuthorityBasisRecord), PersonName/PersonNameDerivative (confidence normalization), MergeRecord/CrossLifeBookAuthorization/EscalationRecord (FK terminology correction — Blocker G3).

**No feature may be enabled merely because its table exists. No production deployment is authorized by this instruction.**

---

## 8. Document cross-reference

| Topic | Authoritative location |
|---|---|
| Entity supertype, User ≠ Person, LifeBook structure | ANCHOR_MODELS.md v0.2 |
| Place coordinate policy | ANCHOR_MODELS.md §4.2 |
| Claim, Relationship, Narrative, Source, Event models | CONTENT_LAYER.md v0.3 |
| Predicate semantics (all 74) | CLAIM_PREDICATE_CATALOGUE.md v0.2 |
| Relationship types (all 27) | RELATIONSHIP_TYPE_CATALOGUE.md v0.1 |
| evidence_status and precision_status values | CONTENT_LAYER.md §18.5 |
| ClaimValueUnit catalogue and semantic rules | CONTENT_LAYER.md §3.2 |
| Numeric Claim DB enforcement trigger spec | CONTENT_LAYER.md §3.4 |
| DNA source governance | CONTENT_LAYER.md §9.3 |
| `associated_with` promotion rule | CLAIM_PREDICATE_CATALOGUE.md v0.2 |
| `member_of` routing rule | SEMANTIC_COLLISION_REPORT.md §4.3 |
| ApprovalPolicy (template definition) | GOVERNANCE_MODELS.md §4 |
| ApprovalRecord (instance model) | APPROVAL_INSTANCE_MODEL.md v1.0 |
| AuthorityAssignment | GOVERNANCE_MODELS.md §3 |
| ConflictResolutionPolicy | GOVERNANCE_MODELS.md §5 |
| EscalationPolicy, ContestRecord, EscalationRecord | OPERATIONAL_MODELS.md §1, §2, §6 |
| Jurisdiction, JurisdictionPolicyVersion | OPERATIONAL_MODELS.md §3, §5 |
| PersonName, PersonPronouns, PersonGenderDescriptor | PERSON_ATTRIBUTE_CATALOGUE.md |
| Dependency-ordered migration sequence | SCHEMA_INVENTORY.md v0.2 |
| Semantic gap resolution history | SEMANTIC_COLLISION_REPORT.md v0.2 |
| AI Context Broker constraints | AI_CONTEXT_BROKER.md |
| Table-by-table migration classification | MIGRATION_SCOPE_MATRIX.md v1.1 |
| Frozen architectural principles | ARCHITECTURE_FREEZE_V1.md v1.1 |
