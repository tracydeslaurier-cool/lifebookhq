# LifeBook Schema Inventory
**Version:** 0.2  
**Status:** Pre-migration inventory — not SQL  
**Depends on:** ANCHOR_MODELS.md v0.2, CONTENT_LAYER.md v0.3, CLAIM_PREDICATE_CATALOGUE.md v0.2, GOVERNANCE_MODELS.md, OPERATIONAL_MODELS.md, AI_CONTEXT_BROKER.md, PERSON_ATTRIBUTE_CATALOGUE.md  
**Produced:** 2026-07-23

### Revision history

| Version | Date | Summary | Supersedes |
|---|---|---|---|
| 0.1 | 2026-07-23 | Initial inventory; 13 groups; 34-step migration sequence | — |
| 0.2 | 2026-07-23 | evidence_status and precision_status values defined; stale "required addition" labels cleared; ClaimValueUnit and coordinate_precision added to Group 1; CONTENT_LAYER dependency updated to v0.3; deployment blocker language updated | 0.1 |
| 0.3 | 2026-07-24 | Added deferred schema objects section for Memory Atmosphere Engine (5 objects; not migration blockers) | — |

This document is the dependency-ordered inventory of all tables required before the Supabase migration is produced. For each table it records: primary key, foreign keys, authoritative vs. cached fields, LifeBook scope, access classification, legal or governance dependencies, whether the table may be deployed disabled, and unresolved questions.

This is not SQL. The migration follows only after this inventory is reviewed and approved.

---

## Reading guide

**Authoritative field:** A field that is the system of record for a fact. Changing it changes the truth the system presents. Requires provenance, versioning, or history.

**Cached field:** A derived or pre-computed value stored for performance. Never authoritative. Must carry lineage (policy_version, validity_state, invalidated_at). Must be invalidated by AccessPolicyChanged.

**LifeBook-scoped:** The table has a `lifebook_id` FK. Records belong to one LifeBook.

**Global:** The table has no `lifebook_id`. Records are shared across the system.

**Deploy-disabled:** A feature or table that can be deployed in the schema but with all access locked (RLS deny-all, or a deployment_permitted = false gate), pending legal review, community consultation, or design completion.

---

## Group 1 — Enums and Controlled Vocabularies

These are PostgreSQL enum types or reference tables. Reference tables (TYPE = `ref table`) are preferred over enums for extensible catalogues. Enum types are acceptable only for vocabularies that are architectural constants unlikely to need extension.

| # | Name | Type | Values defined in | Notes |
|---|---|---|---|---|
| 1.1 | `entity_type` | Enum | ANCHOR_MODELS.md §1.2 | `person` / `organization` / `place` / `vessel` / `community` / `event_series`. Architectural constant; enum acceptable. |
| 1.2 | `canonical_status` | Enum | ANCHOR_MODELS.md §1.3 | `canonical` / `candidate` / `merged_into` / `split_from` / `duplicate_pending_review` |
| 1.3 | `suppression_state` | Enum | ANCHOR_MODELS.md §1.4 | `active` / `suppressed` / `redacted` / `deletion_pending` |
| 1.4 | `erasure_state` | Enum | ANCHOR_MODELS.md §1.2 | `none` / `erasure_requested` / `erasure_in_progress` / `erased` |
| 1.5 | `evidence_status` | Enum | CONTENT_LAYER.md §18.5 | `unreviewed` / `asserted` / `inferred` / `supported` / `corroborated`. Does not encode dispute (→ dispute_status) or review state (→ review_status). |
| 1.6 | `precision_status` | Enum | CONTENT_LAYER.md §18.5 | `exact` / `approximate` / `range` / `unknown`. Temporal and locational precision only. |
| 1.7 | `dispute_status` | Enum | This document §core | `uncontested` / `disputed` / `contradicted` / `retracted` / `superseded` |
| 1.8 | `review_status` | Enum | This document §core | `pending` / `human_reviewed` / `policy_approved` |
| 1.9 | `submission_origin` | Enum | CONTENT_LAYER.md §1.1 | 9 values; see §1.1 |
| 1.10 | `access_classification` | Enum | CONTENT_LAYER.md §17 | `public` / `family` / `steward` / `restricted` / `culturally_governed` |
| 1.11 | `lifecycle_status` (person) | Enum | ANCHOR_MODELS.md §2.2 | `living` / `deceased` / `unknown` / `presumed_deceased` |
| 1.12 | `lifebook_status` | Enum | ANCHOR_MODELS.md §8.2 | `active` / `archived` / `suspended` / `transfer_pending` / `deletion_pending` |
| 1.13 | `subject_scope` | Enum | ANCHOR_MODELS.md §8.3 | `individual` / `family` / `community` / `institutional` |
| 1.14 | `visibility` (LifeBook) | Enum | ANCHOR_MODELS.md §8.4 | `private` / `family` / `public_preview` / `published` |
| 1.15 | `participation_role` | Enum | ANCHOR_MODELS.md §9.2 | 11 values; candidate_match removed |
| 1.16 | `visibility_status` (LifeBookEntity) | Enum | ANCHOR_MODELS.md §9.3 | `visible` / `hidden` / `restricted` / `pending_confirmation` / `anonymized` |
| 1.17 | `authority_context` | Enum | ANCHOR_MODELS.md §10.2 | 12 values |
| 1.18 | `contribution_status` | Enum | ANCHOR_MODELS.md §10.3 | 6 values |
| 1.19 | `account_status` | Enum | ANCHOR_MODELS.md §11.1 | `active` / `suspended` / `pending_verification` / `deactivated` |
| 1.20 | `link_type` | Enum | ANCHOR_MODELS.md §11.3 | 7 values |
| 1.21 | `verification_status` | Enum | ANCHOR_MODELS.md §11.2 | `unverified` / `pending_verification` / `verified` / `rejected` |
| 1.22 | `narrative_type` | Enum | CONTENT_LAYER.md §7.2 | 9 values |
| 1.23 | `content_type` | Enum | CONTENT_LAYER.md §7.3 | 5 values |
| 1.24 | `composition_status` | Enum | CONTENT_LAYER.md §7.4 | `draft` / `submitted` / `in_review` / `approved` / `archived` / `withdrawn` |
| 1.25 | `validity_state` | Enum | AI_CONTEXT_BROKER.md §11.5 | `valid` / `policy_superseded` / `under_review` / `invalidated` / `expired` |
| 1.26 | `source_type` | Enum | CONTENT_LAYER.md §9.2 | 19 values: original 17 + `dna_analysis` (restricted; §9.3 governance) + `court_record`. `legal_document` and `court_record` now distinct. |
| 1.27 | `artifact_type` | Enum | CONTENT_LAYER.md §12.2 | 12 values |
| 1.28 | `event_type` | Enum | CONTENT_LAYER.md §15.2 | 21 values: original 20 + `civil_partnership_registration` (distinct from `marriage`). |
| 1.29 | `storage_provider` | Enum | CONTENT_LAYER.md §13.1 | `supabase_storage` / `s3` / `gcs` / `azure_blob` / `other` |
| 1.30 | `derivative_relationship` | Enum | CONTENT_LAYER.md §13.1 | `original` / `thumbnail` / `compressed` / `transcript` / `derivative` |
| 1.31 | `artifact_source_relationship` | Enum | CONTENT_LAYER.md §14.2 | 5 values |
| 1.32 | `entity_match_status` | Enum | ANCHOR_MODELS.md §14.2 | 7 values |
| 1.33 | `entity_match_review_outcome` | Enum | ANCHOR_MODELS.md §14.3 | 5 values |
| 1.34 | `SourceDerivative.derivative_type` | Enum | AI_CONTEXT_BROKER.md §5.4 | 5 values |
| 1.35 | `cross_lifebook_status` | Enum | ANCHOR_MODELS.md §12.4 | `active` / `suspended` / `revoked` |
| 1.36 | `ClaimValueUnit` | Ref table | CONTENT_LAYER.md §3.2 | 11 seed units: year, month, day, km, mile, acre, hectare, currency, count, percentage, age_years. Extensible without schema migration. Must be seeded before Claim numeric values are accepted. |
| 1.37 | `coordinate_precision` | Enum | ANCHOR_MODELS.md §4.1 | `exact` / `approximate` / `centroid` / `disputed` / `unknown` |

**Resolved:** `evidence_status` and `precision_status` values are now defined in CONTENT_LAYER.md §18.5 and in this inventory (rows 1.5, 1.6). No longer TBD.

---

## Group 2 — Authentication and User Tables

| # | Table | PK | Key FKs | Auth/Cached | LifeBook scope | Access classification | Legal / governance | Deploy-disabled | Open questions |
|---|---|---|---|---|---|---|---|---|---|
| 2.1 | `auth.users` | `id` UUID | — | Supabase-managed | Global | Supabase auth | Standard data processing | No | Supabase-controlled; do not add custom columns |
| 2.2 | `public.user_profiles` | `id` UUID (= auth.users.id) | None beyond PK/FK to auth.users | All authoritative | Global | Internal admin | Standard data processing | No | Review how account_status deactivation propagates to active LifeBook authority |
| 2.3 | `UserPersonLink` | `id` UUID | `user_id` → user_profiles, `person_entity_id` → Entity | All authoritative | Global | Steward + admin | Verification workflow to be designed | No | Guardian/executor verification workflow undefined; initial: steward attestation |

---

## Group 3 — Entity and Subtype Anchors

| # | Table | PK | Key FKs | Auth/Cached | LifeBook scope | Access classification | Legal / governance | Deploy-disabled | Open questions |
|---|---|---|---|---|---|---|---|---|---|
| 3.1 | `Entity` | `id` UUID | `suppressed_by_id` → user_profiles, `creation_source_record_id` → Source (nullable), `erasure_jurisdiction_id` → Jurisdiction | All authoritative | Global | `suppression_state` + `erasure_state` govern access; no direct access_classification field | Right-to-erasure law (jurisdiction-dependent); suppression_state governs | No | FK to Source for creation_source_record_id creates a dependency on Group 7; circular if enforced as FK — consider nullable text reference instead for bootstrap |
| 3.2 | `Person` | `entity_id` UUID PK/FK → Entity | `lifecycle_status_evidence_id` → Source (nullable) | All authoritative | Global | Via Entity suppression_state | Right-to-erasure | No | None |
| 3.3 | `Organization` | `entity_id` UUID PK/FK → Entity | `primary_jurisdiction_id` → Jurisdiction | `cached_display_name` = cached; all others authoritative | Global | Via Entity | None | No | OrgName versioned attribute table not yet designed |
| 3.4 | `Place` | `entity_id` UUID PK/FK → Entity | `parent_place_entity_id` → Entity (nullable); `coordinate_source_id` → Source (nullable, non-blocking FK — may be added in later migration step) | `cached_primary_name` = cached; `cached_latitude` / `cached_longitude` = **cached representative coordinates** (not authoritative); `coordinate_precision` = enum qualifier | Global | Via Entity | None | No | Authoritative, disputed, or area-based geometry belongs in Claim layer or future PlaceGeometry table. See ANCHOR_MODELS.md §4.2. |
| 3.5 | `Vessel` | `entity_id` UUID PK/FK → Entity | `operating_entity_id` → Entity (nullable) | `cached_vessel_name` = cached | Global | Via Entity | None | No | Vessel registry and voyage dates are Claims, not fields |
| 3.6 | `Community` | `entity_id` UUID PK/FK → Entity | `primary_jurisdiction_id` → Jurisdiction | `cached_display_name` = cached | Global | Via Entity | Indigenous: requires community consultation before `culturally_governed_processing` enabled | `community_type = indigenous_nation`: deploy disabled pending consultation | Community name authority for indigenous communities undefined |
| 3.7 | `EventSeries` | `entity_id` UUID PK/FK → Entity | — | `cached_display_name` = cached | Global | Via Entity | None | No | First/last occurrence dates are Claims |
| 3.8 | `MergeRecord` | `id` UUID | `approval_record_id` → ApprovalPolicy, `reversed_merge_record_id` → self | All authoritative | Global | Admin only | None | No | None |
| 3.9 | `EntityMatchCandidate` | `id` UUID | `entity_a_id` → Entity, `entity_b_id` → Entity, `lifebook_a_id` → LifeBook (nullable), `lifebook_b_id` → LifeBook (nullable), `merge_record_id` → MergeRecord (nullable), `context_manifest_id` → ContextManifest (nullable) | All authoritative | Global | Steward + system only; RLS deny-all for non-steward roles | None | No | RLS policy and API exposure rules not yet specified |

---

## Group 4 — LifeBook Scoping Tables

| # | Table | PK | Key FKs | Auth/Cached | LifeBook scope | Access classification | Legal / governance | Deploy-disabled | Open questions |
|---|---|---|---|---|---|---|---|---|---|
| 4.1 | `LifeBook` | `id` UUID | `steward_id` → user_profiles, `primary_jurisdiction_id` → Jurisdiction | All authoritative | Self (is the scope container) | `visibility` governs discoverability; content governed per record | Jurisdiction-dependent; CA-QC and EU blocked pending legal review | CA-QC + EU: deploy-disabled | Transfer-pending lifecycle state needs a workflow |
| 4.2 | `LifeBookEntity` | `id` UUID | `lifebook_id` → LifeBook, `entity_id` → Entity, `added_by_id` → user_profiles | All authoritative | Yes | `visibility_status` governs; steward has full access | None | No | Deferred constraint: every person-type LifeBookEntity must have one LifeBookPersonContext |
| 4.3 | `LifeBookPersonContext` | `id` UUID | `lifebook_entity_id` → LifeBookEntity (unique), `entity_id` → Entity | `cached_permission_summary` = cached (JSONB); all others authoritative | Yes | Steward + subject | None | No | Deferred constraint trigger required for completeness invariant; cache invalidation on AccessPolicyChanged |

---

## Group 5 — Authority and Governance Tables

Tables from GOVERNANCE_MODELS.md. Full field definitions there; this inventory records dependencies and deployment considerations.

| # | Table | PK | Key FKs | Auth/Cached | LifeBook scope | Access classification | Legal / governance | Deploy-disabled | Open questions |
|---|---|---|---|---|---|---|---|---|---|
| 5.1 | `AuthorityAssignment` | `id` UUID | `lifebook_id` → LifeBook (nullable), `entity_id` → Entity, `assigned_to_user_id` → user_profiles, `assigned_by_id` → user_profiles | All authoritative | Optional | Steward + admin | Legal authority types (guardian, executor, representative) must align with jurisdiction; CA-QC + EU: legal review required | No | Succession_behaviour and coordination_rule fields must be enforced by application logic or triggers |
| 5.2 | `ApprovalPolicy` | `id` UUID | `lifebook_id` → LifeBook (nullable), `entity_id` → Entity (nullable), `jurisdiction_id` → Jurisdiction (nullable) | All authoritative | Optional | Steward + admin | None | No | lifecycle_status transitions must be trigger-enforced |
| 5.3 | `ConflictResolutionPolicy` | `id` UUID | `lifebook_id` → LifeBook | All authoritative | Yes | Steward + admin | None | No | None |
| 5.4 | `AttributeDisplayPolicy` | `id` UUID | `entity_id` → Entity, `lifebook_id` → LifeBook (nullable) | All authoritative | Optional | Steward | None | No | None |

---

## Group 6 — Relationship and Predicate Catalogues

| # | Table | PK | Key FKs | Auth/Cached | LifeBook scope | Access classification | Legal / governance | Deploy-disabled | Open questions |
|---|---|---|---|---|---|---|---|---|---|
| 6.1 | `ClaimPredicate` | `id` UUID | `inverse_predicate_id` → self (nullable), `replaced_by_predicate_id` → self (nullable) | All authoritative | Global (seed/config table) | Admin for write; public for read (predicate codes are not sensitive) | None | No | Full seed catalogue not yet written; must be complete before migration |
| 6.2 | `RelationshipType` | `id` UUID | `replaced_by_type_id` → self (nullable) | All authoritative | Global (seed/config table) | Admin for write; public for read | None | No | Full seed catalogue not yet written; must be complete before migration |
| 6.3 | `Relationship` | `id` UUID | `lifebook_id` → LifeBook, `relationship_type_id` → RelationshipType, `entity_a_id` → Entity, `entity_b_id` → Entity, `display_policy_id` → AttributeDisplayPolicy (nullable), `context_manifest_id` → ContextManifest (nullable) | All authoritative | Yes | `access_classification` field | None | No | `role_a` / `role_b` are currently free-text; consider whether a controlled vocabulary is needed |

---

## Group 7 — Content Tables

| # | Table | PK | Key FKs | Auth/Cached | LifeBook scope | Access classification | Legal / governance | Deploy-disabled | Open questions |
|---|---|---|---|---|---|---|---|---|---|
| 7.1 | `Claim` | `id` UUID | `lifebook_id` → LifeBook, `predicate_id` → ClaimPredicate, `subject_entity_id` → Entity, `object_entity_id` → Entity (nullable), `display_policy_id` → AttributeDisplayPolicy (nullable), `superseded_by_claim_id` → self (nullable), `context_manifest_id` → ContextManifest (nullable), `created_by_id` → user_profiles | `claim_text_cached` = cached; all others authoritative | Yes | `access_classification` field | Right-to-erasure: retracted claims must be structurally retained with values erased | No | claim_text_cached generation strategy (at-presentation vs. stored cache) to be decided |
| 7.2 | `ClaimEvidence` | `id` UUID | `claim_id` → Claim, `source_id` → Source, `source_derivative_id` → SourceDerivative (nullable), `added_by_id` → user_profiles | All authoritative | Via Claim | Via Claim | None | No | None |
| 7.3 | `Narrative` | `id` UUID | `lifebook_id` → LifeBook, `composed_by_entity_id` → Entity (nullable), `composed_at_location_entity_id` → Entity (nullable), `display_policy_id` → AttributeDisplayPolicy (nullable), `parent_narrative_id` → self (nullable), `context_manifest_id` → ContextManifest (nullable), `invalidation_event_id` → AccessPolicyChangedEvent (nullable), `created_by_id` → user_profiles | All authoritative | Yes | `access_classification` field | Community account narratives require community authorization | Deploy-disabled for `community_account` type without community auth | translation_metadata JSONB structure must be documented as a schema fixture |
| 7.4 | `NarrativeEntity` | `id` UUID | `narrative_id` → Narrative, `entity_id` → Entity, `display_policy_id` → AttributeDisplayPolicy (nullable), `added_by_id` → user_profiles | All authoritative | Via Narrative | Via Narrative + `is_restricted_mention` | None | No | None |
| 7.5 | `Source` | `id` UUID | `lifebook_id` → LifeBook (NOT NULL), `originating_entity_id` → Entity (nullable), `holding_entity_id` → Entity (nullable), `jurisdiction_id` → Jurisdiction (nullable), `display_policy_id` → AttributeDisplayPolicy (nullable), `created_by_id` → user_profiles | All authoritative | Yes (NOT NULL) | `access_classification` field | None | No | None |
| 7.6 | `SourceDerivative` | `id` UUID | `source_id` → Source, `context_manifest_id` → ContextManifest (nullable), `invalidation_event_id` → AccessPolicyChangedEvent (nullable), `created_by_id` → user_profiles | All authoritative | Via Source | `access_classification` field | Right-to-erasure: invalidated derivatives must not be recoverable | No | Large derivative content (audio/video transcripts) should use FileStorageReference rather than inline text |
| 7.7 | `Artifact` | `id` UUID | `lifebook_id` → LifeBook, `creator_entity_id` → Entity (nullable), `current_holder_entity_id` → Entity (nullable), `original_location_entity_id` → Entity (nullable), `file_storage_reference_id` → FileStorageReference (nullable), `display_policy_id` → AttributeDisplayPolicy (nullable), `created_by_id` → user_profiles | All authoritative | Yes | `access_classification` field | None | No | None |
| 7.8 | `FileStorageReference` | `id` UUID | `parent_storage_reference_id` → self (nullable), `created_by_id` → user_profiles | All authoritative | Global (referenced by Artifact; no direct lifebook_id) | `access_classification` field | None | No | Signed URL generation service interface not yet specified |
| 7.9 | `ArtifactSourceLink` | `id` UUID | `artifact_id` → Artifact, `source_id` → Source, `created_by_id` → user_profiles | All authoritative | Via Artifact + Source | Via more restrictive of Artifact or Source | None | No | None |
| 7.10 | `Event` | `id` UUID | `lifebook_id` → LifeBook, `primary_location_entity_id` → Entity (nullable), `organizing_entity_id` → Entity (nullable), `series_entity_id` → Entity (nullable), `display_policy_id` → AttributeDisplayPolicy (nullable), `created_by_id` → user_profiles | All authoritative | Yes | `access_classification` field | None | No | Claim suggestion workflow not yet designed |
| 7.11 | `EventParticipant` | `id` UUID | `event_id` → Event, `entity_id` → Entity, `display_policy_id` → AttributeDisplayPolicy (nullable), `added_by_id` → user_profiles | All authoritative | Via Event | `access_classification` field | None | No | None |

---

## Group 8 — AI Context Broker Tables

From AI_CONTEXT_BROKER.md. Full field definitions there.

| # | Table | PK | Key FKs | Auth/Cached | LifeBook scope | Access classification | Legal / governance | Deploy-disabled | Open questions |
|---|---|---|---|---|---|---|---|---|---|
| 8.1 | `AgentRegistry` | `id` / `agent_code` | — | All authoritative | Global | Admin only | None | No | None |
| 8.2 | `ContextManifest` | `id` UUID | `lifebook_id` → LifeBook (nullable), `agent_code` → AgentRegistry, `requesting_user_id` → user_profiles | All authoritative; never deleted | Global | Admin + audit | Audit retention obligation; must define retention period | No | Retention period not specified |
| 8.3 | `SanitizedSourceDerivative` | Part of SourceDerivative table (§7.6) | — | — | — | — | — | — | Represented as SourceDerivative records; no separate table needed |
| 8.4 | `AccessPolicyChangedEvent` | `id` UUID | Various trigger_record FKs by type | All authoritative; permanent audit record | Global | Admin + audit | Audit retention obligation | No | Cascade sequence from trigger to derivative invalidation needs specification |

---

## Group 9 — Cross-LifeBook Authorization Tables

| # | Table | PK | Key FKs | Auth/Cached | LifeBook scope | Access classification | Legal / governance | Deploy-disabled | Open questions |
|---|---|---|---|---|---|---|---|---|---|
| 9.1 | `CrossLifeBookAuthorization` | `id` UUID | `lifebook_a_id` → LifeBook, `lifebook_b_id` → LifeBook, `entity_id` → Entity, `approval_a_id` → ApprovalPolicy, `approval_b_id` → ApprovalPolicy, `person_authorization_id` → ApprovalPolicy (nullable), `revoked_by_id` → user_profiles (nullable) | All authoritative | Spans two LifeBooks | Steward + admin | Revocation triggers AccessPolicyChangedEvent cascade (AI_CONTEXT_BROKER.md §11.4) | No | The cascade from revocation to LifeBookSourceAccess suspension needs a trigger or application-layer sequence |
| 9.2 | `LifeBookSourceAccess` | `id` UUID | `source_id` → Source, `source_lifebook_id` → LifeBook, `recipient_lifebook_id` → LifeBook, `cross_lifebook_authorization_id` → CrossLifeBookAuthorization | All authoritative | Spans two LifeBooks | Steward + admin | Suspended on CrossLifeBookAuthorization revocation | No | Cascade trigger sequence not yet specified |

---

## Group 10 — Invalidation, Lineage, Escalation, and Audit Tables

| # | Table | PK | Key FKs | Auth/Cached | LifeBook scope | Access classification | Legal / governance | Deploy-disabled | Open questions |
|---|---|---|---|---|---|---|---|---|---|
| 10.1 | `AccessPolicyChangedEvent` | `id` UUID | `trigger_record_id` (polymorphic by trigger_record_type) | All authoritative; permanent | Global | Admin + audit | Audit retention | No | Polymorphic FK pattern must be handled carefully; consider a trigger_record_context JSONB |
| 10.2 | `EscalationPolicy` | `id` UUID | `lifebook_id` → LifeBook (nullable) | All authoritative | Optional | Steward | None | No | Defined in OPERATIONAL_MODELS.md |
| 10.3 | `EscalationRecord` | `id` UUID | `escalation_policy_id` → EscalationPolicy, `trigger_record_id` (polymorphic), `lifebook_id` → LifeBook (nullable) | All authoritative | Optional | Steward + admin | None | No | Timer/scheduling mechanism for step escalation not yet specified |
| 10.4 | `ContestRecord` | `id` UUID | `lifebook_id` → LifeBook (nullable), per-party-isolation JSONB | All authoritative | Optional | Per-party isolation; steward + admin | Investigation must use ContestRecord, not review_status; CA-QC + EU: legal review | No | Defined in OPERATIONAL_MODELS.md |

---

## Group 11 — Required Constraints and Deferred Triggers

These must be implemented as part of the migration, not deferred to application code.

| # | Constraint | Mechanism | Tables involved | Notes |
|---|---|---|---|---|
| 11.1 | Every `entity_type = person` LifeBookEntity must have exactly one LifeBookPersonContext | Deferred constraint trigger | LifeBookEntity, LifeBookPersonContext | Creation must be transactional |
| 11.2 | `created_by_id` and `subject_entity_id` must not be populated with the same UUID by a trigger or default | CHECK constraint + trigger | Claim, Narrative | Cannot enforce full semantic equivalence at DB layer; enforce as NOT DEFAULT; document as an application invariant |
| 11.3 | A Claim with `dispute_status = disputed` or `contradicted` must have a corresponding ContestRecord | Trigger or application-layer validation | Claim, ContestRecord | Enforce at creation/update |
| 11.4 | A Claim must have at least one of object_entity_id, value_text, value_date, value_numeric | CHECK constraint | Claim | Enforce at DB layer |
| 11.5 | Source.lifebook_id must not be NULL | NOT NULL constraint | Source | Enforced in schema |
| 11.6 | SourceDerivative with validity_state ≠ valid must not be supplied to a ContextManifest | Trigger or application invariant | SourceDerivative, ContextManifest | Cannot fully enforce at DB layer; document as Context Broker invariant |
| 11.7 | EntityMatchCandidate must not trigger any LifeBookEntity change | Trigger (no cascade from EntityMatchCandidate to LifeBookEntity) | EntityMatchCandidate, LifeBookEntity | Enforce via RLS: EntityMatchCandidate writes must not cascade |
| 11.8 | Deleting a user_profile must not delete any Entity, Claim, Narrative, Source, Artifact, or Relationship | ON DELETE RESTRICT or SET NULL on created_by_id FKs | All content tables | Prefer SET NULL on created_by_id; never CASCADE DELETE |
| 11.9 | Ending a UserPersonLink must not alter the Person entity or any content records | Application invariant | UserPersonLink, Entity, all content tables | Enforce via application layer; document clearly |
| 11.10 | AI-generated content with submission_origin = ai_extracted_submission or system_inferred_submission must have review_status = pending at creation | CHECK constraint | Claim, Narrative, Relationship, Source | Enforce at DB layer |
| 11.11 | AccessPolicyChangedEvent records must never be deleted | No DELETE privilege on AccessPolicyChangedEvent for any role | AccessPolicyChangedEvent | RLS: deny DELETE for all roles |
| 11.12 | ContextManifest records must never be deleted | No DELETE privilege | ContextManifest | RLS: deny DELETE for all roles |
| 11.13 | Translation Narrative must have translation_metadata populated | CHECK: when parent_relationship = translation, translation_metadata IS NOT NULL | Narrative | Enforce at DB layer |

---

## Group 12 — Seed and Configuration Tables

These tables are populated by seed migrations at deployment. They are part of the schema but not user-generated data.

| # | Table | Seed required before | Notes |
|---|---|---|---|
| 12.1 | `ClaimPredicate` | Any Claim can be created | Full seed catalogue not yet written; must be reviewed and approved before migration |
| 12.2 | `RelationshipType` | Any Relationship can be created | Full seed catalogue not yet written; must be reviewed and approved before migration |
| 12.3 | `Jurisdiction` | LifeBook can be created; deployment gates can be enforced | Seed data defined in OPERATIONAL_MODELS.md; 10 launch jurisdictions |
| 12.4 | `JurisdictionPolicyVersion` | After Jurisdiction seed | Seed data defined in OPERATIONAL_MODELS.md |
| 12.5 | `EscalationPolicy` (seed records) | After LifeBook seed | Representative records in OPERATIONAL_MODELS.md |
| 12.6 | `AgentRegistry` | Before any AI context invocation | Agent codes and permitted ContextProfiles; defined in AI_CONTEXT_BROKER.md §6 |

---

## Group 13 — Deployment Blockers and Legal / Community Review Gates

These are conditions that must be satisfied before a table, feature, or jurisdiction is enabled in production. No migration approval removes these gates; they are policy decisions.

| # | Gate | Applies to | Condition to lift | Current status |
|---|---|---|---|---|
| 13.1 | CA-QC deployment blocked | All tables with right_to_erasure obligations | Legal review of provenance–erasure resolution (OPERATIONAL_MODELS.md §3.7) | Blocked |
| 13.2 | EU deployment blocked | All tables with right_to_erasure obligations | Legal review of provenance–erasure resolution | Blocked |
| 13.3 | `culturally_governed_processing` ContextProfile | ContextManifest, SourceDerivative, AgentRegistry | Community consultation with each Indigenous community whose data is in scope | Blocked; deploy-disabled |
| 13.4 | Community entity of type `indigenous_nation` | Community subtype table, cached_display_name | Community consultation for name governance | Blocked |
| 13.5 | Cross-LifeBook authorization for person-type entities | CrossLifeBookAuthorization, LifeBookSourceAccess | Person consent workflow must be implemented and tested | Blocked until consent workflow is designed |
| 13.6 | AI model invocation (any agent) | AgentRegistry, ContextManifest | Context Broker implementation verified against §9-step process (AI_CONTEXT_BROKER.md §2) | Blocked until Context Broker is built |
| 13.7 | ClaimPredicate seed data | Claim (all) | Full predicate catalogue reviewed and approved; three predicates added (`apprenticed_to`, `associated_with`, `in_civil_partnership_with`); `dna_analysis` and `court_record` added to source_type; `civil_partnership_registration` added to event_type; ClaimValueUnit seeded | Blocked — 6 required additions from SEMANTIC_COLLISION_REPORT.md are now defined; seed data to be written and reviewed before migration |
| 13.8 | RelationshipType seed data | Relationship (all) | Full type catalogue reviewed and approved; `civil_partnership_registration` event_type now defined in CONTENT_LAYER.md §15.2 | Blocked pending seed review |
| 13.9 | OrgName versioned attribute table | Organization (all) | Design of parallel name attribute table for organizations | Not started |
| 13.10 | Signed URL generation service | FileStorageReference, Artifact | File service interface specified (bucket, key format, signed URL expiry, access-classification enforcement) | Not started |
| 13.11 | Claim suggestion workflow (Event-derived claims) | Event, Claim | Application workflow for steward review and promotion of system_inferred claims designed | Not started |
| 13.12 | ContestRecord investigation workflow | ContestRecord, Claim, Narrative | Application workflow for dispute initiation, investigation, and resolution designed | Not started |

---

## Dependency order for migration

The migration must proceed in this order. A table in a later group must not be created before all tables it depends on in an earlier group exist.

1. Enums (Group 1) — must exist before any table
2. auth.users (managed by Supabase) — must exist before user_profiles
3. user_profiles (2.2)
4. Jurisdiction, JurisdictionPolicyVersion (12.3, 12.4) — LifeBook depends on Jurisdiction
5. Entity (3.1) — all subtypes and content tables depend on this
6. Person, Organization, Place, Vessel, Community, EventSeries (3.2–3.7)
7. MergeRecord (3.8) — references Entity; Entity.merge_record_id is nullable so circular dependency is deferred
8. LifeBook (4.1) — depends on user_profiles, Jurisdiction
9. UserPersonLink (2.3) — depends on user_profiles, Entity (Person)
10. LifeBookEntity (4.2) — depends on LifeBook, Entity
11. LifeBookPersonContext (4.3) — depends on LifeBookEntity; deferred constraint trigger added after
12. AuthorityAssignment, ApprovalPolicy, ConflictResolutionPolicy, AttributeDisplayPolicy (5.1–5.4) — depend on LifeBook, Entity, Jurisdiction
13. EscalationPolicy, EscalationRecord, ContestRecord (10.2–10.4)
14. ClaimPredicate (6.1) — seed data required immediately after
15. RelationshipType (6.2) — seed data required immediately after
16. AgentRegistry (12.6) — seed data required immediately after
17. Source (7.5) — depends on LifeBook, Entity, Jurisdiction
18. FileStorageReference (7.8)
19. Artifact (7.7) — depends on LifeBook, Entity, FileStorageReference
20. ArtifactSourceLink (7.9) — depends on Artifact, Source
21. ContextManifest (8.2) — depends on LifeBook, AgentRegistry, user_profiles
22. AccessPolicyChangedEvent (8.4 / 10.1)
23. SourceDerivative (7.6) — depends on Source, ContextManifest, AccessPolicyChangedEvent
24. Claim (7.1) — depends on LifeBook, ClaimPredicate, Entity, AttributeDisplayPolicy, ContextManifest
25. ClaimEvidence (7.2) — depends on Claim, Source, SourceDerivative
26. Relationship (6.3) — depends on LifeBook, RelationshipType, Entity, AttributeDisplayPolicy
27. Narrative (7.3) — depends on LifeBook, Entity, AttributeDisplayPolicy, ContextManifest, AccessPolicyChangedEvent
28. NarrativeEntity (7.4) — depends on Narrative, Entity
29. Event (7.10) — depends on LifeBook, Entity, AttributeDisplayPolicy
30. EventParticipant (7.11) — depends on Event, Entity
31. CrossLifeBookAuthorization (9.1) — depends on LifeBook, Entity, ApprovalPolicy
32. LifeBookSourceAccess (9.2) — depends on Source, LifeBook, CrossLifeBookAuthorization
33. EntityMatchCandidate (3.9) — depends on Entity, LifeBook, MergeRecord, ContextManifest
34. Deferred constraint triggers (Group 11) — applied after all tables exist

---

## Deferred Schema Objects — Memory Atmosphere Engine

The following objects are identified by `MEMORY_ATMOSPHERE_ENGINE.md v0.1` and `ADR-0002`. They are documented here for inventory completeness. None are migration blockers for 0001 or 0002. A dedicated schema design session is required before any migration is produced for these tables.

| Object | Purpose | Design dependency |
|---|---|---|
| `AtmosphereProfile` (record) | Persisted log of each computed atmosphere profile per session turn; supports audit | Session model, Voice/Conversation System |
| `AtmosphereConsentRecord` | Records participant consent for specific atmosphere levels and material types per session | Governance Engine, Participant/Person anchor, Artifact |
| `AtmospherePolicyVersion` | Versioned policy defining thresholds, level caps, and inertia parameters per jurisdiction or deployment context | Jurisdiction, JurisdictionPolicyVersion |
| `AtmosphereAuditLog` | Immutable log of all profile transitions, retreat events, and consent checks | Session model, AccessPolicyChangedEvent |
| `ArtifactAtmospherePermission` | Governs whether a specific artifact may appear at a specific atmosphere level in a specific session context | Artifact, AtmosphereConsentRecord |

These objects must not be migrated until the Memory Atmosphere Engine design review session is complete and the open questions in `MEMORY_ATMOSPHERE_ENGINE.md §12` are resolved.

---

*See PRE_MIGRATION_CLOSURE.md for the final gate status and explicit migration authorization.*
