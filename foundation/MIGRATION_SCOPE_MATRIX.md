# LifeBook Migration Scope Matrix
**Version:** 1.1  
**Status:** Active — governs which table groups are authorized for structural SQL  
**Produced:** 2026-07-23  
**Produced by:** Architecture session — Discovery Partner + Claude

### Revision history

| Version | Date | Summary | Supersedes |
|---|---|---|---|
| 1.0 | 2026-07-23 | Initial classification; incorrectly classified GOVERNANCE_MODELS.md, OPERATIONAL_MODELS.md, and PERSON_ATTRIBUTE_CATALOGUE.md as "not yet written" | — |
| 1.1 | 2026-07-23 | Corrected classification based on actual document content; Jurisdiction, JurisdictionPolicyVersion, EscalationPolicy, ContestRecord, EscalationRecord, and most governance tables reclassified as ready or near-ready; ApprovalRecord, MergeRecord, CrossLifeBookAuthorization moved to `requires-completion`; LifeBook Jurisdiction FK confirmed NOT NULL; migration sequence revised | 1.0 |

---

## Classification key

| Status | Meaning |
|---|---|
| `ready` | Governing design documents complete; FKs available; structural SQL may be written |
| `requires-completion` | Design is substantially done but a specific named gap must be resolved before this table's SQL is written |
| `deploy-disabled` | Schema may be migrated; access must be locked at deploy pending policy approval |
| `feature-blocked` | Table is `ready` but a specific feature using it requires a separate gate before enablement |
| `deferred` | Table design not yet started or explicitly deferred to v2; excluded from first migration |

A table may carry more than one status (e.g., `ready` + `deploy-disabled`).

---

## Group 1 — Enums and Controlled Vocabularies

All 37 items: **`ready`**

| # | Name | Status | Notes |
|---|---|---|---|
| 1.1 | `entity_type` | `ready` | Frozen: ARCHITECTURE_FREEZE_V1.md §2.1 |
| 1.2 | `canonical_status` | `ready` | |
| 1.3 | `suppression_state` | `ready` | |
| 1.4 | `erasure_state` | `ready` | |
| 1.5 | `evidence_status` | `ready` | Frozen: ARCHITECTURE_FREEZE_V1.md §2.2 |
| 1.6 | `precision_status` | `ready` | Frozen: ARCHITECTURE_FREEZE_V1.md §2.3 |
| 1.7 | `dispute_status` | `ready` | |
| 1.8 | `review_status` | `ready` | |
| 1.9 | `submission_origin` | `ready` | |
| 1.10 | `access_classification` | `ready` | |
| 1.11 | `lifecycle_status` (person) | `ready` | |
| 1.12 | `lifebook_status` | `ready` | |
| 1.13 | `subject_scope` | `ready` | |
| 1.14 | `visibility` (LifeBook) | `ready` | |
| 1.15 | `participation_role` | `ready` | |
| 1.16 | `visibility_status` (LifeBookEntity) | `ready` | |
| 1.17 | `authority_context` | `ready` | |
| 1.18 | `contribution_status` | `ready` | |
| 1.19 | `account_status` | `ready` | |
| 1.20 | `link_type` | `ready` | |
| 1.21 | `verification_status` | `ready` | |
| 1.22 | `narrative_type` | `ready` | |
| 1.23 | `content_type` | `ready` | |
| 1.24 | `composition_status` | `ready` | |
| 1.25 | `validity_state` | `ready` | |
| 1.26 | `source_type` | `ready` | 19 values; `dna_analysis` access restricted by default; raw_genotype_file sub-type is feature-blocked (F1) |
| 1.27 | `artifact_type` | `ready` | |
| 1.28 | `event_type` | `ready` | 21 values including `civil_partnership_registration` |
| 1.29 | `storage_provider` | `ready` | |
| 1.30 | `derivative_relationship` | `ready` | |
| 1.31 | `artifact_source_relationship` | `ready` | |
| 1.32 | `entity_match_status` | `ready` | |
| 1.33 | `entity_match_review_outcome` | `ready` | |
| 1.34 | `SourceDerivative.derivative_type` | `ready` | |
| 1.35 | `cross_lifebook_status` | `ready` | |
| 1.36 | `ClaimValueUnit` (ref table) | `ready` | 11 seed units; S3 seed blocker applies before numeric Claims accepted |
| 1.37 | `coordinate_precision` | `ready` | |

---

## Group 2 — Authentication and User Tables

| # | Table | Status | Notes |
|---|---|---|---|
| 2.1 | `auth.users` | `ready` | Supabase-managed; no migration action required |
| 2.2 | `user_profiles` | `ready` | |
| 2.3 | `UserPersonLink` | `ready` | Guardian/executor verification workflow undefined; that is a feature design item, not a migration blocker; table structure is complete |

---

## Group 3 — Entity and Subtype Anchors

| # | Table | Status | Notes |
|---|---|---|---|
| 3.1 | `Entity` | `ready` | `creation_source_record_id` FK to Source must be nullable at creation (Source comes later in sequence); tighten post-Source via deferred FK or application invariant |
| 3.2 | `Person` | `ready` | |
| 3.3 | `Organization` | `ready` | `OrgName` versioned table is `deferred` — Organization table itself is ready |
| 3.4 | `Place` | `ready` | `coordinate_source_id` FK to Source is non-blocking; may be deferred to a later migration step |
| 3.5 | `Vessel` | `ready` | |
| 3.6 | `Community` | `ready` + `deploy-disabled` (partial) | Schema ready. Records with `community_type = indigenous_nation` must be deploy-disabled pending L3/L4 |
| 3.7 | `EventSeries` | `ready` | |
| 3.8 | `MergeRecord` | `requires-completion` | **G3 blocker:** `approval_record_id` currently references ApprovalPolicy — must be corrected to reference ApprovalRecord (NOT NULL). No MergeRecord may be created without an `approved` ApprovalRecord instance. Migration file may not be written until G3 is resolved |
| 3.9 | `EntityMatchCandidate` | `ready` | Must come after MergeRecord in migration sequence (nullable FK to MergeRecord); RLS deny-all for non-steward roles required at deploy |

---

## Group 4 — LifeBook Scoping Tables

| # | Table | Status | Notes |
|---|---|---|---|
| 4.1 | `LifeBook` | `ready` + `deploy-disabled` (jurisdiction gate) | `primary_jurisdiction_id` is NOT NULL — confirmed. Resolved by placing Jurisdiction seed before LifeBook in migration sequence. Minimum seed records (CA, CA-AB, UA, INTERNATIONAL_DEFAULT) required before any LifeBook record can be created. CA-QC and EU LifeBooks have `deployment_permitted = false` until L1/L2 |
| 4.2 | `LifeBookEntity` | `ready` | |
| 4.3 | `LifeBookPersonContext` | `ready` | Deferred constraint trigger (11.1) applied after both LifeBookEntity and LifeBookPersonContext exist |

---

## Group 5 — Authority and Governance Tables

Source document: GOVERNANCE_MODELS.md v0.1 Draft (field-complete for all tables listed here).

| # | Table | Status | Notes |
|---|---|---|---|
| 5.1 | `AuthorityAssignment` | `requires-completion` | **G1 blocker:** `authority_basis_record_id` is a nullable FK to `AuthorityBasisRecord`, which is not yet designed. The nullable FK means the table could be migrated with that column deferred — but the model should be complete before migration is written. Discovery Partner decision: design AuthorityBasisRecord first, or explicitly defer and add `authority_basis_record_id` via ALTER TABLE in a later migration bundle |
| 5.2 | `ApprovalPolicy` | `ready` | Template table; no instance dependency; field-complete in GOVERNANCE_MODELS.md §4 |
| 5.3 | `ConflictResolutionPolicy` | `ready` | Field-complete in GOVERNANCE_MODELS.md §5 |
| 5.4 | `AttributeDisplayPolicy` | `ready` | Referenced by PersonName, Claim, Narrative, Relationship, Artifact, Event, NarrativeEntity, EventParticipant (all as nullable FKs). Field definition in SCHEMA_INVENTORY.md row 5.4 is sparse — confirm fields are sufficient before migration is written |

**Note:** `ApprovalRecord` (APPROVAL_INSTANCE_MODEL.md v1.0) is a new table in this governance tier. It is not listed in SCHEMA_INVENTORY.md v0.2 and must be added. Its migration position is: after ApprovalPolicy and EscalationRecord; before MergeRecord and CrossLifeBookAuthorization.

---

## Group 6 — Relationship and Predicate Catalogues

| # | Table | Status | Notes |
|---|---|---|---|
| 6.1 | `ClaimPredicate` | `ready` | Table structure ready; S1 seed blocker applies before Claims can be created |
| 6.2 | `RelationshipType` | `ready` | Table structure ready; S2 seed blocker applies before Relationships can be created |
| 6.3 | `Relationship` | `ready` | `display_policy_id` FK to AttributeDisplayPolicy is nullable; no structural blocker |

---

## Group 7 — Content Tables

| # | Table | Status | Notes |
|---|---|---|---|
| 7.1 | `Claim` | `ready` | `display_policy_id` and `context_manifest_id` nullable; `value_unit_code` FK to ClaimValueUnit in scope; numeric Claims require S3/S4 before trigger fires |
| 7.2 | `ClaimEvidence` | `ready` | |
| 7.3 | `Narrative` | `ready` + `deploy-disabled` (partial) | `community_account` narrative type deploy-disabled without community auth |
| 7.4 | `NarrativeEntity` | `ready` | |
| 7.5 | `Source` | `ready` | `dna_analysis` restricted by default; raw_genotype_file sub-type feature-blocked (F1) |
| 7.6 | `SourceDerivative` | `ready` | |
| 7.7 | `Artifact` | `ready` | `file_storage_reference_id` nullable; service interface not yet specified (pre-production item) |
| 7.8 | `FileStorageReference` | `ready` | Signed URL service interface not yet specified; structural table ready |
| 7.9 | `ArtifactSourceLink` | `ready` | |
| 7.10 | `Event` | `ready` | |
| 7.11 | `EventParticipant` | `ready` | |

---

## Group 8 — AI Context Broker Tables

| # | Table | Status | Notes |
|---|---|---|---|
| 8.1 | `AgentRegistry` | `ready` | AgentRegistry seed (12.6) required before AI invocation |
| 8.2 | `ContextManifest` | `ready` | F2 feature gate blocks AI invocation; structural table ready |
| 8.4 | `AccessPolicyChangedEvent` | `ready` | RLS must deny DELETE for all roles at deploy |

---

## Group 9 — Cross-LifeBook Authorization Tables

| # | Table | Status | Notes |
|---|---|---|---|
| 9.1 | `CrossLifeBookAuthorization` | `requires-completion` | **G3 blocker:** `approval_a_id`, `approval_b_id`, and `person_authorization_id` currently reference ApprovalPolicy — must be corrected to reference ApprovalRecord instances. All three are NOT NULL on a completed authorization. Migration file may not be written until G3 is resolved and ApprovalRecord table exists |
| 9.2 | `LifeBookSourceAccess` | `requires-completion` | Hard dependency on CrossLifeBookAuthorization (9.1); cascades from G3 blocker |

---

## Group 10 — Escalation, Dispute, and Audit Tables

Source document: OPERATIONAL_MODELS.md v0.1 Draft (all tables field-complete).

| # | Table | Status | Notes |
|---|---|---|---|
| 10.1 | `AccessPolicyChangedEvent` | `ready` | Also listed as Group 8 (8.4); same table |
| 10.2 | `EscalationPolicy` | `ready` | Fully modelled in OPERATIONAL_MODELS.md §1 |
| 10.3 | `EscalationRecord` | `requires-completion` | **G3 blocker (partial):** `approval_workflow_id` must be renamed to `approval_record_id` (nullable FK → ApprovalRecord). EscalationRecord also has a nullable FK to ContestRecord — circular with ContestRecord.escalation_record_id. Circular resolved: both nullable; create EscalationRecord before ContestRecord, populate FKs after both exist |
| 10.4 | `ContestRecord` | `ready` | Fully modelled in OPERATIONAL_MODELS.md §2; circular FK with EscalationRecord resolved as above |

---

## Group 11 — Required Constraints and Deferred Triggers

| # | Constraint | Status | Notes |
|---|---|---|---|
| 11.1 | LifeBookPersonContext completeness | `ready` | Applied after both tables exist |
| 11.2 | created_by_id ≠ subject_entity_id | `ready` | |
| 11.3 | disputed Claim → ContestRecord | `ready` | ContestRecord now field-complete |
| 11.4 | Claim must have at least one value | `ready` | |
| 11.5 | Source.lifebook_id NOT NULL | `ready` | |
| 11.6 | Invalid SourceDerivative not supplied to ContextManifest | `ready` | Application invariant |
| 11.7 | EntityMatchCandidate must not cascade to LifeBookEntity | `ready` | |
| 11.8 | Deleting user_profile must not cascade to content | `ready` | |
| 11.9 | Ending UserPersonLink must not alter Entity | `ready` | Application invariant |
| 11.10 | AI-generated content starts as pending | `ready` | |
| 11.11 | AccessPolicyChangedEvent no DELETE | `ready` | |
| 11.12 | ContextManifest no DELETE | `ready` | |
| 11.13 | Translation Narrative metadata required | `ready` | |

**All 13 constraints ready.**

---

## Group 12 — Seed and Configuration Tables

| # | Table / seed | Status | Notes |
|---|---|---|---|
| 12.1 | ClaimPredicate seed | `ready` | Catalogue v0.2 approved; fixture file not yet written (S1) |
| 12.2 | RelationshipType seed | `ready` | Catalogue v0.1 approved; fixture file not yet written (S2) |
| 12.3 | Jurisdiction | `ready` | Fully modelled in OPERATIONAL_MODELS.md §3; minimum seed (CA, CA-AB, UA, INTERNATIONAL_DEFAULT) required (S5); CA-QC and EU present with deployment_permitted = false |
| 12.4 | JurisdictionPolicyVersion | `ready` | Fully modelled in OPERATIONAL_MODELS.md §5; `current_policy_version_id` circular FK with Jurisdiction resolved: Jurisdiction.current_policy_version_id nullable at creation; updated via deferred FK or ALTER TABLE after seeding |
| 12.5 | EscalationPolicy seed | `ready` | Representative records defined in OPERATIONAL_MODELS.md §1.5; fixture file not yet written |
| 12.6 | AgentRegistry seed | `ready` | Agent codes defined in AI_CONTEXT_BROKER.md; fixture file not yet written |

---

## Person attribute subtables

Source document: PERSON_ATTRIBUTE_CATALOGUE.md v0.1 Draft (structurally complete; one normalization required).

| Table | Status | Notes |
|---|---|---|
| `PersonName` | `requires-completion` | **G2 blocker:** `confidence` field uses old combined enum (`asserted / inferred / supported / corroborated / approximate / disputed / contradicted / unresolved`). Must be replaced with separate `evidence_status` (→ CONTENT_LAYER.md §18.5 enum), `dispute_status` (→ CONTENT_LAYER.md enum), and `precision_status` (→ CONTENT_LAYER.md §18.5 enum) before migration. All other fields are complete |
| `PersonNameDerivative` | `requires-completion` | Inherits G2 blocker from PersonName (`confidence` field same issue) |
| `PersonPronouns` | `ready` | Field-complete; no normalization required; approval_policy_id and conflict_resolution_policy_id reference templates correctly |
| `PersonGenderDescriptor` | `ready` | Field-complete |

---

## New table — not yet in SCHEMA_INVENTORY.md

| Table | Status | Notes |
|---|---|---|
| `ApprovalRecord` | `ready` | Defined in APPROVAL_INSTANCE_MODEL.md v1.0; must be added to SCHEMA_INVENTORY.md; migration position: after ApprovalPolicy and EscalationRecord, before MergeRecord and CrossLifeBookAuthorization |

---

## Deferred tables

| Table | Status | Notes |
|---|---|---|
| `OrgName` (versioned) | `deferred` | Design not started; Organization carries only `cached_display_name` in v1 |
| `PlaceGeometry` | `deferred` | Authoritative geometry design not started; Place carries only cached coordinates in v1 |
| `AuthorityBasisRecord` | `deferred` (pending decision) | Referenced as nullable FK in AuthorityAssignment; not yet designed; blocks AuthorityAssignment migration until designed or explicitly deferred |
| `CapacityDetermination` | `deferred` | Referenced in GOVERNANCE_MODELS.md §9.4; no current FK dependency in any defined table; not a migration blocker; design pending |

---

## Required corrections before affected tables are migrated

These are FK terminology errors confirmed by searching all governed documents. The pattern `ApprovalPolicy` appears where `ApprovalRecord` is required. No SQL for the affected tables may be written until these are corrected in SCHEMA_INVENTORY.md and ANCHOR_MODELS.md.

| Table | Field | Incorrect reference | Correct reference | Nullable? |
|---|---|---|---|---|
| `MergeRecord` | `approval_record_id` | → ApprovalPolicy | → ApprovalRecord | NOT NULL |
| `CrossLifeBookAuthorization` | `approval_a_id` | → ApprovalPolicy | → ApprovalRecord | NOT NULL |
| `CrossLifeBookAuthorization` | `approval_b_id` | → ApprovalPolicy | → ApprovalRecord | NOT NULL |
| `CrossLifeBookAuthorization` | `person_authorization_id` | → ApprovalPolicy | → ApprovalRecord | Nullable |
| `EscalationRecord` | `approval_workflow_id` | (undefined) | `approval_record_id` → ApprovalRecord | Nullable |

---

## Revised first migration sequence

Subject to resolution of G2 (PersonName confidence normalization) and G3 (FK terminology correction), the recommended first migration proceeds in this order:

1. **Stable enums and reference tables** — all 37 Group 1 items; create before any table
2. **`public.user_profiles`** — must exist before all FK references to users
3. **`Jurisdiction`** — `current_policy_version_id` nullable at this step; seed CA, CA-AB, UA, INTERNATIONAL_DEFAULT immediately after creation
4. **`JurisdictionPolicyVersion`** — seed draft versions after creation; update `Jurisdiction.current_policy_version_id` via deferred FK or ALTER TABLE
5. **`Entity`** — all subtypes and content tables depend on this
6. **Entity subtype tables** — `Person`, `Organization`, `Place`, `Vessel`, `Community`, `EventSeries`
7. **`LifeBook`** — `primary_jurisdiction_id` NOT NULL; Jurisdiction seed must exist first
8. **`UserPersonLink`**
9. **`LifeBookEntity`** and **`LifeBookPersonContext`** (with deferred constraint trigger 11.1)
10. **Seed and config reference tables** — `ClaimPredicate`, `ClaimValueUnit`, `RelationshipType`, `AgentRegistry` seeds
11. **Person attribute tables** — `PersonPronouns`, `PersonGenderDescriptor` (ready now); `PersonName`, `PersonNameDerivative` (after G2 resolved)
12. **Governance template tables** — `ApprovalPolicy`, `ConflictResolutionPolicy`, `AttributeDisplayPolicy`
13. **Escalation and dispute tables** — `EscalationPolicy`, `EscalationRecord` (nullable approval_record_id at this step), `ContestRecord`
14. **`ApprovalRecord`** — after ApprovalPolicy and EscalationRecord; then ALTER TABLE EscalationRecord to add approval_record_id FK
15. **`AuthorityAssignment`** — after ApprovalRecord and ContestRecord; after AuthorityBasisRecord (if designed) or with authority_basis_record_id deferred
16. **Core content tables** — `Source`, `FileStorageReference`, `Artifact`, `ArtifactSourceLink`, `ContextManifest`, `AccessPolicyChangedEvent`, `SourceDerivative`, `Claim`, `ClaimEvidence`, `Relationship`, `Narrative`, `NarrativeEntity`, `Event`, `EventParticipant`
17. **`MergeRecord`** — after ApprovalRecord (NOT NULL FK); after G3 terminology correction
18. **`EntityMatchCandidate`** — after MergeRecord
19. **`CrossLifeBookAuthorization`** — after ApprovalRecord (all three NOT NULL FKs); after G3 terminology correction
20. **`LifeBookSourceAccess`** — after CrossLifeBookAuthorization
21. **Deferred foreign keys, triggers, indexes, and RLS scaffolding** — all Group 11 constraints; `Entity.creation_source_record_id` FK (deferred until Source exists); Place.coordinate_source_id (nullable; may be added here)

*See PRE_MIGRATION_CLOSURE.md v1.2 for the explicit migration authorization and stage gate model.*
