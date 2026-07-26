# Database Object Registry
**Version:** 1.0  
**Status:** Approved — final pre-SQL governance pass complete  
**Date:** 2026-07-25  
**Produced by:** Discovery Partner + Claude (implementation governance session)  
**Scope:** Migration 0002 and Migration 0003 — all database objects  
**Purpose:** Canonical inventory of every database object introduced by these migrations. No SQL. No architecture changes. Documentation only.

**Input documents:**  
MIGRATION_0003_PROPOSAL.md v0.2 · VOCABULARY_RLS_MATRIX.md v3.0 · GOVERNANCE_ENFORCEMENT_MODEL.md v0.2 · MIGRATION_IMPLEMENTATION_PLAN.md v1.0 · SECURITY_DEFINER_REVIEW.md v1.0

---

## Reading This Document

**Governance Owner** — the actor class with primary write authority over the object. Reference/catalogue tables with no public write access are owned by `system`. Tables that are written exclusively by governed application workflows are owned by `governed-workflow`.

**Permanent Record** — YES means the table has a DELETE-denied RLS policy (USING FALSE). No actor may DELETE from a permanent record table. Records are corrected by supersession or status transition.

**RLS Enabled** — YES means `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` is applied in Migration 0003 Phase 6. All 25 RLS-enabled tables are content or governance tables; all reference/catalogue tables are RLS-disabled (access controlled by grants only).

**Trigger Protection** — lists all triggers defined on the table in VOCABULARY_RLS_MATRIX.md §3. Pass A = no cross-table deps; Pass B = cross-table deps; Pass C = after seed commit.

---

## Part I — Migration 0002 Objects

### Enum Types

| Object Name | Object Type | Migration | Purpose | Governance Owner | RLS Enabled | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|
| `relationship_interaction_type` | PostgreSQL enum | 0002 | Classifies how one Claim predicate relates to another (proposes, supports, describes, none); used on `claim_predicates` table | system | N/A | N/A | Values authored in MIGRATION_0002 per PRE_SQL_READINESS_REVIEW.md | None — enum creates first |
| `display_policy_status` | PostgreSQL enum | 0002 | Governs DisplayPolicy lifecycle state machine (draft, active, superseded, withdrawn); enforced by `trg_display_policies_lifecycle` | system | N/A | N/A | Values authored in MIGRATION_0002 | None |
| `display_policy_decision` | PostgreSQL enum | 0002 | Specifies a DisplayPolicy rule outcome (allow, deny, conditional); used on `display_policy_rules.decision` column | system | N/A | N/A | Values authored in MIGRATION_0002 | None |

### Reference Table

| Object Name | Object Type | Migration | Batch | Purpose | Governance Owner | RLS Enabled | Trigger Protection | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `display_contexts` | Table (reference) | 0002 | 0002 seed | Canonical registry of all display context codes; provides the TEXT PRIMARY KEY referenced by `display_policy_rules.display_context_code`; carries label, description, sort_order | system | No | None | No — reference table; protected by schema-level grants only | 9 records authored in migration 0002; codes are architectural constants per DISPLAY_POLICY_MODEL.md v0.1 | None — created in 0002; all 0003 display_policy_rules references depend on this |

---

## Part II — Migration 0003 Objects

### Tables — Batch 1: Jurisdiction

| Object Name | Object Type | Migration | Batch | Purpose | Governance Owner | RLS Enabled | Trigger Protection | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `jurisdictions` | Table | 0003 | Batch 1 | Defines legal jurisdictions (country, province/state) with PIPEDA applicability flags; required before any LifeBook can be created (NOT NULL FK on lifebooks) | system | No | None | No — system-managed reference | Minimum 6 records per OPERATIONAL_MODELS.md §4 (Canada/federal, Alberta, British Columbia, Ontario, Ukraine, international default) | None |
| `jurisdiction_policy_versions` | Table | 0003 | Batch 1 | Tracks versioned policy snapshots per jurisdiction; supports historical audit of which policy version governed a given LifeBook record at a point in time | system | No | None | No | None at migration time; authored as policies change | `jurisdictions` |

### Tables — Batch 2: Users

| Object Name | Object Type | Migration | Batch | Purpose | Governance Owner | RLS Enabled | Trigger Protection | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `user_profiles` | Table | 0003 | Batch 2 | Application-layer wrapper for Supabase `auth.users`; extends authentication identity with LifeBook-specific profile fields; required by all actor-linked tables | system | No | None | No — profiles are managed by authentication lifecycle | None | `auth.users(id)` (Supabase auth schema) |

### Tables — Batch 3: Entity Anchors

| Object Name | Object Type | Migration | Batch | Purpose | Governance Owner | RLS Enabled | Trigger Protection | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `entities` | Table | 0003 | Batch 3 | Entity supertype; every named subject (person, organization, place, vessel, community, event_series) is an entity; provides the `entity_id` UUID referenced throughout the schema | system | No | None | No — entities may be merged or deprecated via governed workflow | None | `user_profiles` |
| `persons` | Table | 0003 | Batch 3 | Person subtype of entity; carries birth date range, deceased flag, living_status; no PersonName FKs at this table (names are in Batch 14) | steward | No | None | No | None | `entities` |
| `organizations` | Table | 0003 | Batch 3 | Organization subtype of entity | steward | No | None | No | None | `entities` |
| `places` | Table | 0003 | Batch 3 | Place subtype; carries `cached_latitude` and `cached_longitude` — application cache fields, not authoritative geography (P11 in ARCHITECTURE_FREEZE_V1.md) | steward | No | None | No | None | `entities` |
| `vessels` | Table | 0003 | Batch 3 | Vessel subtype of entity | steward | No | None | No | None | `entities` |
| `communities` | Table | 0003 | Batch 3 | Community subtype; used for Indigenous communities and other collective entities requiring cultural governance | steward / cultural_authority | No | None | No | None | `entities` |
| `event_series` | Table | 0003 | Batch 3 | EventSeries subtype of entity (e.g., "World War II", "2024 Olympics"); anchor record distinct from individual `events` in Batch 10 | steward | No | None | No | None | `entities` |

### Tables — Batch 4: LifeBook Scoping

**Internal ordering:** `lifebook_entities` must be created before `lifebook_person_contexts` within Batch 4. Both depend on `lifebooks`, which must precede them.

| Object Name | Object Type | Migration | Batch | Purpose | Governance Owner | RLS Enabled | Trigger Protection | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `lifebooks` | Table | 0003 | Batch 4 | The primary governance container; all content tables carry `lifebook_id` scoped to this record; FK to `jurisdictions` is NOT NULL (P13) | steward | No | None | No — LifeBooks have a lifecycle; closed LifeBooks are not deleted but may be archived | None | `jurisdictions`, `user_profiles` |
| `lifebook_memberships` | Table | 0003 | Batch 4 | Maps users to LifeBooks with role (`steward`, `contributor`, `viewer`); read by `fn_lb_membership_role` (SECURITY DEFINER) for all RLS policy evaluation; central to the entire access model | system / steward | Yes | None | No — memberships change as steward manages access | None | `lifebooks`, `user_profiles` |
| `user_person_links` | Table | 0003 | Batch 4 | Optional link between an authenticated user and a person entity, establishing subject status; read by `fn_is_subject_of` (SECURITY DEFINER); not all users are subjects | system / steward | No | None | No | None | `user_profiles`, `persons` |
| `lifebook_entities` | Table | 0003 | Batch 4 | Many-to-many association between LifeBook and Entity (all subtypes); records participation context: role, visibility, and relationship description; `visibility_status` governs member-level read access; `removed_at` provides soft-delete pattern | steward | **Yes** | `trg_lifebook_person_context_completeness` (Pass B — **CONSTRAINT TRIGGER DEFERRABLE INITIALLY DEFERRED** on this table; fires at COMMIT not immediately after INSERT) | No — soft-deleted via `removed_at`; hard DELETE denied by RLS policy 59 | None | `lifebooks`, `entities`, `user_profiles` |
| `lifebook_person_contexts` | Table | 0003 | Batch 4 | Person-specific participation overlay for LifeBookEntity records where `entity_type = person`; records authority context, contribution lifecycle, terms acceptance, cross-LifeBook consent, and cached permission state; dual governance (steward: authority/contribution fields; subject: consent fields); cache fields managed by system_service | steward / subject | **Yes** | None | No — lifecycle managed via parent `lifebook_entities.removed_at`; hard DELETE denied by RLS policy 65 | None | `lifebook_entities`, `entities` |

**DDL specification — `lifebook_entities`:**

| Field | Type | Nullable | Notes |
|---|---|---|---|
| `id` | UUID | NOT NULL | PK; `DEFAULT gen_random_uuid()` |
| `lifebook_id` | UUID FK | NOT NULL | References `lifebooks(id)` |
| `entity_id` | UUID FK | NOT NULL | References `entities(id)` |
| `entity_type` | `entity_type` enum | NOT NULL | Denormalized from `Entity.entity_type` for query efficiency; values: `person`, `organization`, `place`, `vessel`, `community`, `event_series` |
| `participation_role` | `participation_role` enum | NOT NULL | See ANCHOR_MODELS.md §9.2; values: `subject`, `family_member`, `storyteller`, `contributor`, `event_participant`, `historical_associate`, `referenced_entity`, `steward`, `witness`, `institutional_representative`, `location_reference` |
| `relationship_description` | TEXT | NULL | Human-readable description of how this entity relates to the focal subject |
| `is_focal_entity` | BOOLEAN | NOT NULL | `DEFAULT FALSE`; is this entity a primary subject of this LifeBook? |
| `visibility_status` | `visibility_status` enum | NOT NULL | See ANCHOR_MODELS.md §9.3; values: `visible`, `hidden`, `restricted`, `pending_confirmation`, `anonymized` |
| `added_by_id` | UUID FK | NOT NULL | References `user_profiles(id)` |
| `added_at` | TIMESTAMPTZ | NOT NULL | `DEFAULT now()` |
| `removed_at` | TIMESTAMPTZ | NULL | Soft-delete timestamp; set by steward when entity participation ends |
| `removed_by_id` | UUID FK | NULL | References `user_profiles(id)` |
| `removal_reason` | TEXT | NULL | |
| `steward_notes` | TEXT | NULL | Internal notes; not exposed to non-steward actors (application enforces) |

**Constraints:** `UNIQUE(lifebook_id, entity_id) WHERE removed_at IS NULL` — implemented as a **partial unique index** (`CREATE UNIQUE INDEX uq_lifebook_entities_active ON lifebook_entities(lifebook_id, entity_id) WHERE removed_at IS NULL`), not a table-level UNIQUE constraint. This permits stewards to re-add an entity to the same LifeBook after a soft-delete by creating a new participation record with a fresh `id`. The prior soft-deleted row is preserved for audit purposes. The plain `UNIQUE(lifebook_id, entity_id)` table-level constraint must NOT be used — it would permanently block re-add. `entity_id`, `lifebook_id`, `entity_type`, `added_at`, `added_by_id` immutable after INSERT (application-enforced in V1).

---

**DDL specification — `lifebook_person_contexts`:**

| Field | Type | Nullable | Notes |
|---|---|---|---|
| `id` | UUID | NOT NULL | PK; `DEFAULT gen_random_uuid()` |
| `lifebook_entity_id` | UUID FK | NOT NULL UNIQUE | References `lifebook_entities(id)`; UNIQUE enforces one-to-one |
| `entity_id` | UUID FK | NOT NULL | References `entities(id)`; redundant reference for direct joins; must equal `lifebook_entities.entity_id` (application enforced) |
| `authority_context` | `authority_context` enum | NOT NULL | See ANCHOR_MODELS.md §10.2; 12 values including `full_subject_authority`, `disputed`, `historical_only`, etc. |
| `contribution_status` | `contribution_status` enum | NOT NULL | See ANCHOR_MODELS.md §10.3; values: `active_contributor`, `past_contributor`, `invited`, `declined`, `revoked`, `not_a_contributor` |
| `has_accepted_terms` | BOOLEAN | NOT NULL | `DEFAULT FALSE`; updated by subject |
| `terms_accepted_at` | TIMESTAMPTZ | NULL | Set when `has_accepted_terms` transitions to TRUE |
| `cross_lifebook_linkage_authorized` | BOOLEAN | NOT NULL | `DEFAULT FALSE`; subject's consent for cross-LifeBook participation disclosure; **immutable by steward** |
| `cross_lifebook_linkage_authorized_at` | TIMESTAMPTZ | NULL | |
| `cross_lifebook_linkage_scope` | JSONB | NULL | What specifically is authorized to disclose across LifeBooks |
| `cached_permission_summary` | JSONB | NULL | Derived performance cache only — NOT authoritative; updated by `system_service` only |
| `permission_cache_policy_version_id` | UUID | NULL | References `approval_policies(id)`; **Deferred FK 3** — FK constraint added after Batch 5 `approval_policies` DDL |
| `permission_cache_computed_at` | TIMESTAMPTZ | NULL | |

**Deferred FK 3:** `ALTER TABLE lifebook_person_contexts ADD CONSTRAINT fk_permission_cache_approval_policy FOREIGN KEY (permission_cache_policy_version_id) REFERENCES approval_policies(id);` — inserted immediately after Batch 5 `approval_policies` DDL.

---

### Tables — Batch 5: Governance Policy Templates

| Object Name | Object Type | Migration | Batch | Purpose | Governance Owner | RLS Enabled | Trigger Protection | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `escalation_policies` | Table | 0003 | Batch 5 | Defines escalation rules (who is notified, timelines, resolution paths) triggered by ContestRecords | system | No | None | No | Representative records per OPERATIONAL_MODELS.md §2 | None |
| `approval_policies` | Table | 0003 | Batch 5 | Defines approval thresholds, quorum, required approvers, and `cultural_governance_required` flag; template for ApprovalRecord creation | system | No | None | No | Representative records per GOVERNANCE_MODELS.md §4.4 | None |
| `conflict_resolution_policies` | Table | 0003 | Batch 5 | Defines structured resolution rules for contested records | system | No | None | No | Representative records per GOVERNANCE_MODELS.md §5.5 | None |
| `display_policies` | Table | 0003 | Batch 5 | Each record defines access decisions for a governed record across all display contexts; two-column model: `display_policies` + `display_policy_rules`; `approval_record_id` carries Deferred FK 2 | steward / subject / cultural_authority | Yes | `trg_display_policies_lifecycle` (Pass A), `trg_display_policies_delete_guard` (Pass A) | No — draft policies may be deleted; active/superseded/withdrawn are permanent-in-practice | None | `display_contexts` (via `display_policy_rules`); Deferred FK 2 → `approval_records` |
| `display_policy_rules` | Table | 0003 | Batch 5 | Individual per-context rules belonging to a DisplayPolicy; UNIQUE(display_policy_id, display_context_code); fully immutable once parent policy is non-draft | steward / subject / cultural_authority | Yes | `trg_display_policy_rules_update_guard` (Pass B), `trg_display_policy_rules_delete_guard` (Pass B) | No | None | `display_policies`, `display_contexts` |

### Tables — Batch 6: Approval Instances

| Object Name | Object Type | Migration | Batch | Purpose | Governance Owner | RLS Enabled | Trigger Protection | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `approval_records` | Table | 0003 | Batch 6 | Governance audit instance; records that a specific ApprovalPolicy threshold was met for a specific action; immutable after creation; referenced by DisplayPolicies, MergeRecords, CrossLifeBookAuthorizations, EscalationRecords | governed-workflow | Yes | `trg_approval_records_immutable` (Pass A) | **YES** — permanent governance record | None | `approval_policies` |

### Tables — Batch 7: Authority

| Object Name | Object Type | Migration | Batch | Purpose | Governance Owner | RLS Enabled | Trigger Protection | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `authority_assignments` | Table | 0003 | Batch 7 | Records that a user holds a specific authority role for a specific entity or LifeBook scope; used by `fn_has_active_authority`; `basis_claim_id` carries Deferred FK 1 → `claims`; **`lifebook_id` IS nullable** — entity-scoped assignments (e.g., cultural authority for an entity not tied to a specific LifeBook) have `lifebook_id = NULL`; LifeBook-scoped assignments have `lifebook_id IS NOT NULL`; **revocation of entity-scoped (NULL lifebook_id) assignments must go through a SECURITY DEFINER function — RLS policy 50 does not cover NULL lifebook_id rows** | steward / admin | Yes | `trg_authority_assignment_revocation_guard` (Pass A) | **YES** — permanent governance record; revocation sets `effective_until`, does not delete | None | `persons`, `lifebooks`, `user_profiles`, `approval_policies`; Deferred FK 1 → `claims` |

### Tables — Batch 8: Reference Catalogues

| Object Name | Object Type | Migration | Batch | Purpose | Governance Owner | RLS Enabled | Trigger Protection | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `claim_predicates` | Table (reference) | 0003 | Batch 8 | 74 named predicate types (birth_date, preferred_name, legal_name, etc.); each predicate defines its value type, unit requirements, and `relationship_interaction_type`; governs what a Claim can assert; read by `trg_claim_numeric_unit_check` | system | No | None | No — system-managed catalogue | 74 records per CLAIM_PREDICATE_CATALOGUE.md; must be committed before `trg_claim_numeric_unit_check` is created | `relationship_interaction_type` enum (Migration 0002) |
| `claim_value_units` | Table (reference) | **0001** | Migration 0001 (`20260724153745_types_and_vocabularies.sql`) | 11 named unit types (year, month, day, km, mile, acre, hectare, currency, count, percentage, age_years); used on Claims where `predicate_id` requires a unit; read by `trg_claim_numeric_unit_check`. Schema: `unit_code TEXT PRIMARY KEY`, `unit_category unit_category NOT NULL` (ENUM), `requires_qualifier`, `deprecated_at`, `notes`, `created_at`. **Not created or seeded in Migration 0003.** Migration 0003 consumes it as a prerequisite. | system | No | None | No | 11 records seeded in Migration 0001. Migration 0003 seeds zero records into this table. | None |
| `relationship_types` | Table (reference) | 0003 | Batch 8 | 27 named relationship types (parent_of, married_to, employer_of, etc.); governs the `relationship_type_id` on Relationship records; no assertion about values — relationship meaning is in the type | system | No | None | No | 27 records per RELATIONSHIP_TYPE_CATALOGUE.md | None |

### Tables — Batch 9: AI Context Infrastructure

| Object Name | Object Type | Migration | Batch | Purpose | Governance Owner | RLS Enabled | Trigger Protection | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `agent_registry` | Table | 0003 | Batch 9 | Registry of AI agents authorized to interact with the LifeBook system; each agent has a code, version, and capability scope; referenced by `claims.producing_agent_code` and `context_manifests` | system | No | None | No — agent records updated as agents are versioned | Per AI_CONTEXT_BROKER.md §3.2; at minimum the initial extraction agent; `memory_atmosphere_policy_evaluator` deferred pending implementation | None |
| `context_profiles` | Table | 0003 | Batch 9 | Defines named AI context usage profiles (e.g., `respectful_generation`, `identity_resolution`) that govern which record types and display contexts an agent session may access | system | No | None | No | `respectful_generation`, `identity_resolution` profiles per AI_CONTEXT_BROKER.md §2 | None |

### Tables — Batch 10: Content Tables

| Object Name | Object Type | Migration | Batch | Purpose | Governance Owner | RLS Enabled | Trigger Protection | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `sources` | Table | 0003 | Batch 10 | Documentary and material evidence records (documents, DNA analyses, photographs, oral history recordings, etc.); `source_type = dna_analysis` → access_classification coerced to `restricted` by trigger; `lifebook_id` and `source_type` are immutable after INSERT | steward | Yes | `trg_source_dna_classification` (Pass A), `trg_source_type_immutable` (Pass A), `trg_source_lifebook_immutable` (Pass A) | **YES** — permanent record | None | `lifebooks`, `user_profiles` |
| `claims` | Table | 0003 | Batch 10 | Core assertion layer; every governed biographical fact is a Claim; content fields are immutable after INSERT (corrected by supersession); carries inline self-FK `superseded_by_claim_id`; AI-generated Claims carry `producing_agent_code` and `context_manifest_id` | steward / contributor / subject / agent_service (restricted) | Yes | `trg_claim_value_not_null` (Pass A), `trg_claim_ai_provenance` (Pass A), `trg_claim_content_immutable` (Pass A), `trg_claim_supersession_integrity` (Pass B), `trg_claim_dispute_requires_contest` (Pass B), `trg_claim_numeric_unit_check` (Pass C) | **YES** — permanent record | None | `entities`, `lifebooks`, `claim_predicates`, `claim_value_units`, `user_profiles`, `display_policies`; inline self-FK |
| `claim_evidence` | Table | 0003 | Batch 10 | Junction: links a Claim to one or more Sources; records the evidential relationship between an assertion and its documentary basis | steward / contributor | Yes | None | **YES** — permanent record | None | `claims`, `sources` |
| `relationships` | Table | 0003 | Batch 10 | Governed assertions about inter-entity relationships (family, legal, organizational); content fields immutable after INSERT; carries inline self-FK `superseded_by_relationship_id`; mirrors Claims supersession model (DP Decision 2026-07-25) | steward / contributor | Yes | `trg_relationship_content_immutable` (Pass A), `trg_relationship_supersession_integrity` (Pass B), `trg_relationship_dispute_requires_contest` (Pass B) | **YES** — permanent record | None | `entities`, `lifebooks`, `relationship_types`, `user_profiles` |
| `narratives` | Table | 0003 | Batch 10 | Long-form biographical text records; `narrative_type = community_account` requires a community authorization ApprovalRecord; community accounts excluded from AI generation context | steward / contributor | Yes | None | **YES** — permanent record | None | `lifebooks`, `user_profiles` |
| `narrative_entities` | Table | 0003 | Batch 10 | Junction: links a Narrative to entity mentions within it; `is_restricted_mention` controls whether the mention appears in non-permitted contexts | steward / contributor | Yes | None | **YES** — permanent record | None | `narratives`, `entities` |
| `events` | Table | 0003 | Batch 10 | Point-in-time occurrences involving one or more entities; carries `source_claim_id` (inline nullable FK → `claims`) recording the generating Claim when created from a Claim (DP Decision 2026-07-25); AI cannot INSERT events directly | steward / contributor | Yes | `trg_event_provenance_immutable` (Pass A) | **YES** — permanent record | None | `lifebooks`, `user_profiles`, `claims` (inline FK for `source_claim_id`) |
| `event_participants` | Table | 0003 | Batch 10 | Junction: links entities to Events with role information; scoped via parent Event's LifeBook | steward / contributor | Yes | None | **YES** — permanent record | None | `events`, `entities` |
| `artifacts` | Table | 0003 | Batch 10 | File-backed records (photographs, audio, video, documents); `object_key` in the referenced `file_storage_references` record must never be exposed to non-admin roles; URLs issued only via `fn_generate_artifact_signed_url`; column-level restriction on `object_key` is deferred to the storage integration migration (W11 — DP Decision 2026-07-25) | steward | Yes | None | **YES** — permanent record | None | `lifebooks`, `sources`, `user_profiles`, `display_policies` |
| `artifact_source_links` | Table | 0003 | Batch 10 | Junction: links Artifacts to Sources | steward | Yes | None | **YES** — permanent record | None | `artifacts`, `sources` |

### Tables — Batch 11: AI Context Manifests

| Object Name | Object Type | Migration | Batch | Purpose | Governance Owner | RLS Enabled | Trigger Protection | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `context_manifests` | Table | 0003 | Batch 11 | Immutable record of which Claim, Source, and Artifact records were included in a specific AI agent session; preserves provenance of every AI-generated output; DELETE denied | system_service | Yes | None | **YES** — permanent governance record | None | `claims`, `sources`, `agent_registry`, `context_profiles` |
| `source_derivatives` | Table | 0003 | Batch 11 | Tracks derivative outputs produced from Sources by AI agents (e.g., transcription, translation, entity extraction); invalidated by AccessPolicyChangedEvents when source policy changes | system_service / agent_service | Yes | `trg_source_derivative_invalidation_cascade` (Pass B) | No — derivatives may be invalidated and regenerated | None | `sources`, `context_manifests` |

### Tables — Batch 12: Cross-LifeBook

| Object Name | Object Type | Migration | Batch | Purpose | Governance Owner | RLS Enabled | Trigger Protection | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `merge_records` | Table | 0003 | Batch 12 | Records the governed merging of two Person entity records; requires ApprovalRecord (NOT NULL FK — G3 blocker resolved) | governed-workflow | No | None | No — merge is an event; the merged entities are the governed records | None | `persons`, `approval_records` (NOT NULL FK) |
| `cross_lifebook_authorizations` | Table | 0003 | Batch 12 | Authorizes a Source from one LifeBook to be referenced by another LifeBook; requires two ApprovalRecord FKs (approval_a_id, approval_b_id, both NOT NULL) and one optional third (person_authorization_id) | governed-workflow | No | None | No | None | `lifebooks`, `persons`, `approval_records` (×2 NOT NULL + ×1 nullable) |
| `lifebook_source_access` | Table | 0003 | Batch 12 | Junction: records which LifeBooks have been granted access to a specific Source via a CrossLifeBookAuthorization; read by `fn_has_source_access_grant` (SECURITY DEFINER) | governed-workflow | No | None | No | None | `lifebooks`, `sources`, `cross_lifebook_authorizations` |

### Tables — Batch 13: Escalation and Dispute

| Object Name | Object Type | Migration | Batch | Purpose | Governance Owner | RLS Enabled | Trigger Protection | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `contest_records` | Table | 0003 | Batch 13 | Records a formal dispute over a governed record (Claim, Relationship, Narrative, etc.); INSERT requires verified standing in one of 7 recognized classes; `dispute_status` transition on the contested record requires a ContestRecord to exist first | subject / steward / cultural_authority / standing parties | Yes | `trg_contest_record_standing_validation` (Pass B) | **YES** — permanent governance record | None | `claims`, `authority_assignments`, `lifebooks`, `user_person_links` |
| `escalation_records` | Table | 0003 | Batch 13 | Records the escalation of a ContestRecord through a formal escalation workflow; `approval_record_id` field (renamed from `approval_workflow_id` — G3 resolved) | governed-workflow | No | None | No | None | `escalation_policies`, `approval_records`, `contest_records` |
| `escalation_notifications` | Table | 0003 | Batch 13 | Records notifications sent to parties as part of an escalation; audit trail for escalation communication | system_service | No | None | No | None | `escalation_records`, `user_profiles` |
| `access_policy_changed_events` | Table | 0003 | Batch 13 | Records every event where an access policy change may have affected the validity of existing SourceDerivatives or ContextManifests; triggers the `trg_source_derivative_invalidation_cascade` flow; DELETE denied | system_service | Yes | None | **YES** — permanent audit record | None | `sources`, `context_manifests` |

### Tables — Batch 14: Person Attributes

| Object Name | Object Type | Migration | Batch | Purpose | Governance Owner | RLS Enabled | Trigger Protection | Permanent Record | Seed Data Source | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `person_names` | Table | 0003 | Batch 14 | Governed name records for persons; 13 `usage_type` values (preferred, legal, birth, maiden, alias, nickname, etc.); four separate status fields (`evidence_status`, `dispute_status`, `precision_status`, `review_status`) replacing the former combined `confidence` enum (G2 blocker resolved); `review_status` is independent on `person_name_derivatives` — not inherited from parent PersonName; agent INSERT denied | steward / subject | Yes | None | **YES** — permanent record; corrections by supersession | None | `persons` — **Note: Batch 14 SQL may not be authored until PERSON_ATTRIBUTE_CATALOGUE.md G2 update is confirmed** |
| `person_name_derivatives` | Table | 0003 | Batch 14 | Automatically or manually derived name variants (transliterations, romanizations, normalizations); generated by system_service or authored by steward; agent INSERT denied; invalidated when parent name is superseded | system_service / steward | Yes | None | **YES** — permanent record | None | `person_names` — **Blocked with person_names on G2 confirmation** |
| `person_pronouns` | Table | 0003 | Batch 14 | Subject-asserted pronouns; subject authority overrides steward in case of conflict; agent INSERT denied; content immutable (corrections by supersession) | subject / steward | Yes | None | **YES** — permanent record | None | `persons` |
| `person_gender_descriptors` | Table | 0003 | Batch 14 | Subject-asserted gender identity descriptors; same authority model as `person_pronouns`; agent INSERT denied | subject / steward | Yes | None | **YES** — permanent record | None | `persons` |

---

### Constraints (Phase 2: Deferred Foreign Keys)

| Object Name | Object Type | Migration | Phase | Table | References | Constraint Type | Purpose | Dependencies |
|---|---|---|---|---|---|---|---|---|
| `fk_authority_basis_claim` | FK Constraint | 0003 | Phase 2 | `authority_assignments.basis_claim_id` | `claims(id)` | Nullable FK; added via ALTER TABLE immediately after Batch 10 `claims` DDL | Records the documentary Claim basis for an AuthorityAssignment; null for `self_assertion` and `policy_default` authority types | `claims` table (Batch 10) must exist |
| `fk_display_policy_approval_record` | FK Constraint | 0003 | Phase 2 | `display_policies.approval_record_id` | `approval_records(id)` | Nullable FK; added via ALTER TABLE immediately after Batch 6 `approval_records` DDL | Links a DisplayPolicy to the ApprovalRecord that authorized it, for scenarios requiring approval before activation | `approval_records` table (Batch 6) must exist |
| `fk_permission_cache_approval_policy` | FK Constraint | 0003 | Batch 5 (inline) | `lifebook_person_contexts.permission_cache_policy_version_id` | `approval_policies(id)` | Nullable FK; added via ALTER TABLE immediately after Batch 5 `approval_policies` DDL; `lifebook_person_contexts` is Batch 4 (before `approval_policies`) | Records which ApprovalPolicy version was used to compute the permission cache; null when cache is not yet computed | `approval_policies` table (Batch 5) must exist |

Note: `claims.superseded_by_claim_id REFERENCES claims(id)` and `relationships.superseded_by_relationship_id REFERENCES relationships(id)` are inline nullable self-FKs declared at table creation time — not deferred constraints.

---

### Indexes (Phase 3)

| Object Name | Object Type | Migration | Phase | Table | Columns | Index Type | Purpose | Helper Function Served |
|---|---|---|---|---|---|---|---|---|
| `idx_lifebook_memberships_user_lifebook` | Index | 0003 | Phase 3 | `lifebook_memberships` | `(user_id, lifebook_id)` | Standard | `fn_lb_membership_role` lookup; called in virtually every RLS policy evaluation | `fn_lb_membership_role` |
| `idx_authority_assignments_role_entity` | Index | 0003 | Phase 3 | `authority_assignments` | `(authority_role, entity_id)` | Standard | `fn_has_active_authority` lookup | `fn_has_active_authority` |
| `idx_authority_assignments_expiry` | Index | 0003 | Phase 3 | `authority_assignments` | `(effective_until) WHERE effective_until IS NOT NULL` | Partial | Filters active assignments in expiry check | `fn_has_active_authority` |
| `idx_claims_lifebook_review_access` | Index | 0003 | Phase 3 | `claims` | `(lifebook_id, review_status, access_classification)` | Standard | Core RLS policy 1 scoping; AI context filtering where `review_status = 'policy_approved'` | RLS policies 1, 30–31, 37 |
| `idx_display_policy_rules_policy_context` | Index | 0003 | Phase 3 | `display_policy_rules` | `(display_policy_id, display_context_code)` | Standard | `fn_display_policy_allows` lookup — called for every display context evaluation | `fn_display_policy_allows` |
| `idx_user_person_links_user_entity` | Index | 0003 | Phase 3 | `user_person_links` | `(user_id, entity_id)` | Standard | `fn_is_subject_of` lookup; called from RLS policies where subject access is relevant | `fn_is_subject_of` |
| `idx_contest_records_contested_record` | Index | 0003 | Phase 3 | `contest_records` | `(contested_record_table, contested_record_id)` | Standard | `fn_has_contest_standing` lookup; `trg_claim_dispute_requires_contest` join | `fn_has_contest_standing`; triggers 15, 16 |

---

### Helper Functions (Phase 4)

| Object Name | Object Type | Migration | Phase | Creation Order | SECURITY DEFINER | Purpose | Tables Read | Recursion Risk | Governance Owner |
|---|---|---|---|---|---|---|---|---|---|
| `fn_user_is_agent` | Function | 0003 | Phase 4 | 1st | **No** | Returns TRUE if current session role is the `agent_service` database role; uses `current_user` or `pg_has_role()` — no table access | None | None | system |
| `fn_lb_membership_role` | Function | 0003 | Phase 4 | 2nd | **Yes** | Returns the current user's membership role ('steward', 'contributor', 'viewer', 'none') for a given lifebook_id; the foundational access check called by virtually every RLS policy | `lifebook_memberships` | **`lifebook_memberships` RLS must NOT call this function** | system / governance |
| `fn_is_subject_of` | Function | 0003 | Phase 4 | 3rd | **Yes** | Returns TRUE if the current user has a `user_person_links` record pointing to the given entity; establishes subject status | `user_person_links` | None | system / governance |
| `fn_has_active_authority` | Function | 0003 | Phase 4 | 4th | **Yes** | Returns TRUE if the current user holds a non-expired AuthorityAssignment for the given role code and entity scope | `authority_assignments` | **`authority_assignments` RLS must NOT call this function; use only `fn_lb_membership_role` and `fn_is_subject_of`** | system / governance |
| `fn_display_policy_allows` | Function | 0003 | Phase 4 | 5th | **Yes** | Returns TRUE only for an active DisplayPolicy with an explicit `allow` rule for the requested display context; returns FALSE for NULL policy_id, inactive policy, missing context rule, deny, or unsatisfied conditional | `display_policies`, `display_policy_rules` | **`display_policies` and `display_policy_rules` RLS must NOT call this function** | system / governance |
| `fn_has_source_access_grant` | Function | 0003 | Phase 4 | 6th | **Yes** | Returns TRUE if the current user's LifeBook has a valid LifeBookSourceAccess record for the given Source via CrossLifeBookAuthorization | `lifebook_source_access`, `cross_lifebook_authorizations` | None | system / governance |
| `fn_has_community_authorization` | Function | 0003 | Phase 4 | 7th | **Yes** | Returns TRUE if the LifeBook has a valid ApprovalRecord authorizing community_account Narrative creation | `approval_records`, `approval_policies` | None | system / governance |
| `fn_has_contest_standing` | Function | 0003 | Phase 4 | 8th | **Yes** | Returns TRUE if current user belongs to the claimed standing class for the contested record; validates across 7 recognized standing classes; executes dynamic SQL — table name parameter MUST be validated against a **hard-coded whitelist of 9 tables** before use; raises EXCEPTION (not returns FALSE) on unrecognized table name. **Whitelist:** `'claims'`, `'relationships'`, `'narratives'`, `'sources'`, `'artifacts'`, `'events'`, `'person_names'`, `'person_pronouns'`, `'person_gender_descriptors'`. Any value not in this list → `RAISE EXCEPTION 'fn_has_contest_standing: unrecognized contested_record_table: %', p_table` | `user_person_links`, `authority_assignments`, `lifebook_memberships`; targeted join to whitelisted contested table | **Targeted join mitigation; `contest_records` RLS SELECT must not call this function** | system / governance |
| `fn_generate_artifact_signed_url` | Function | 0003 | Phase 4 | 9th | **Yes** | **STUB in Migration 0003** — stub body returns NULL immediately without referencing `file_storage_references` or calling any storage API. Migration comment must mark this explicitly as STUB. Full implementation (authority + DisplayPolicy validation + signed URL generation) is deferred to the storage integration milestone in a future migration. The SECURITY DEFINER frame, search_path, ownership, and EXECUTE revocation must all be in place at stub creation time — only the body is a stub | None at stub time (full: `artifacts`, `display_policies`, `display_policy_rules`, `file_storage_references`; storage API call) | **`file_storage_references` must NOT be referenced in the stub body** — this table may not exist at migration time | system / governance |

**All SECURITY DEFINER functions must:** set `search_path = 'public', pg_temp`; be owned by a dedicated `governance_functions` role; have EXECUTE revoked from PUBLIC before per-role grants are applied. See SECURITY_DEFINER_REVIEW.md v1.0 for per-function detail.

---

### Triggers (Phase 5)

| Object Name | Object Type | Migration | Phase/Pass | Table | Timing | Event | Invariant Enforced | Cross-Table Deps | Permanent Effect |
|---|---|---|---|---|---|---|---|---|---|
| `trg_claim_value_not_null` | Trigger | 0003 | Phase 5 Pass A | `claims` | BEFORE | INSERT | At least one of value_text, value_date, value_numeric, object_entity_id must be non-null | None | Rejects INSERT |
| `trg_claim_ai_provenance` | Trigger | 0003 | Phase 5 Pass A | `claims` | BEFORE | INSERT, UPDATE | `ai_generated = true` requires `producing_agent_code` and `context_manifest_id` | None | Rejects write |
| `trg_claim_content_immutable` | Trigger | 0003 | Phase 5 Pass A | `claims` | BEFORE | UPDATE | Content fields (predicate_id, value_text, value_date, value_numeric, object_entity_id, lifebook_id, entity_id, submission_origin, ai_generated) are immutable after INSERT; status fields permitted | None | Rejects UPDATE |
| `trg_relationship_content_immutable` | Trigger | 0003 | Phase 5 Pass A | `relationships` | BEFORE | UPDATE | Content fields (relationship_type_id, entity_a_id, entity_b_id, role_a, role_b, lifebook_id, submission_origin) are immutable after INSERT | None | Rejects UPDATE |
| `trg_source_dna_classification` | Trigger | 0003 | Phase 5 Pass A | `sources` | BEFORE | INSERT | `source_type = 'dna_analysis'` → coerce `access_classification = 'restricted'`; **coerce silently if `NEW.access_classification IS NULL`** (field omitted or defaulted); **raise if `NEW.access_classification IS NOT NULL AND NEW.access_classification != 'restricted'`** (caller explicitly set a non-restricted value — intent conflict) | None | Coerces silently on NULL; raises on explicit non-restricted value |
| `trg_source_type_immutable` | Trigger | 0003 | Phase 5 Pass A | `sources` | BEFORE | UPDATE | `source_type` may not change after INSERT | None | Rejects UPDATE |
| `trg_source_lifebook_immutable` | Trigger | 0003 | Phase 5 Pass A | `sources` | BEFORE | UPDATE | `lifebook_id` may not change after INSERT | None | Rejects UPDATE |
| `trg_event_provenance_immutable` | Trigger | 0003 | Phase 5 Pass A | `events` | BEFORE | UPDATE | `source_claim_id` is immutable after INSERT; NULL stays NULL; non-NULL stays same value | None | Rejects UPDATE |
| `trg_approval_records_immutable` | Trigger | 0003 | Phase 5 Pass A | `approval_records` | BEFORE | UPDATE | No UPDATE permitted on any approval record field | None | Rejects all UPDATE |
| `trg_authority_assignment_revocation_guard` | Trigger | 0003 | Phase 5 Pass A | `authority_assignments` | BEFORE | UPDATE | Only `effective_until` (NULL → date only; never revert to NULL) and `is_contested` may change; all other fields immutable | None | Rejects invalid UPDATE |
| `trg_display_policies_lifecycle` | Trigger | 0003 | Phase 5 Pass A | `display_policies` | BEFORE | UPDATE | Enforces status machine: draft→any; draft→active (status-only); active→superseded (status-only); active→withdrawn (status-only); all other transitions rejected; non-status field UPDATE on non-draft → rejected | None | Rejects invalid UPDATE |
| `trg_display_policies_delete_guard` | Trigger | 0003 | Phase 5 Pass A | `display_policies` | BEFORE | DELETE | DELETE only when `status = 'draft'` | None | Rejects DELETE on non-draft |
| `trg_claim_supersession_integrity` | Trigger | 0003 | Phase 5 Pass B | `claims` | BEFORE | UPDATE | `superseded_by_claim_id`: NULL → non-NULL once only; no self-reference; referenced claim must exist | `claims` (self-join) | Rejects invalid supersession |
| `trg_relationship_supersession_integrity` | Trigger | 0003 | Phase 5 Pass B | `relationships` | BEFORE | UPDATE | Same pattern as claim supersession; `superseded_by_relationship_id` | `relationships` (self-join) | Rejects invalid supersession |
| `trg_claim_dispute_requires_contest` | Trigger | 0003 | Phase 5 Pass B | `claims` | BEFORE | UPDATE | `dispute_status` → 'disputed' or 'contradicted' only when a ContestRecord exists for this claim | `contest_records` | Rejects dispute without ContestRecord |
| `trg_relationship_dispute_requires_contest` | Trigger | 0003 | Phase 5 Pass B | `relationships` | BEFORE | UPDATE | Same rule as claims; dispute_status requires ContestRecord | `contest_records` | Rejects dispute without ContestRecord |
| `trg_display_policy_rules_update_guard` | Trigger | 0003 | Phase 5 Pass B | `display_policy_rules` | BEFORE | UPDATE | UPDATE only when parent `display_policies.status = 'draft'` | `display_policies` | Rejects UPDATE on non-draft rules |
| `trg_display_policy_rules_delete_guard` | Trigger | 0003 | Phase 5 Pass B | `display_policy_rules` | BEFORE | DELETE | DELETE only when parent `display_policies.status = 'draft'` | `display_policies` | Rejects DELETE on non-draft rules |
| `trg_contest_record_standing_validation` | Trigger | 0003 | Phase 5 Pass B | `contest_records` | BEFORE | INSERT | `standing_class` must be one of 7 recognized classes; initiating user must match the claimed class verified against `authority_assignments` and `user_person_links` | `authority_assignments`, `user_person_links` | Rejects INSERT with invalid standing |
| `trg_lifebook_person_context_completeness` | **CONSTRAINT TRIGGER** | 0003 | Phase 5 Pass B | `lifebook_entities` | AFTER | INSERT | Every person-type LifeBookEntity must have a LifeBookPersonContext; **must be created as `CREATE CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED`** — fires at COMMIT, not immediately after INSERT; a plain `CREATE TRIGGER ... AFTER INSERT` will fire immediately and block normal insert sequences where `lifebook_person_contexts` is inserted in the same transaction after `lifebook_entities` | `lifebook_person_contexts` | Raises at COMMIT if `entity_type = 'person'` and no matching `lifebook_person_contexts` record exists |
| `trg_source_derivative_invalidation_cascade` | Trigger | 0003 | Phase 5 Pass B | `source_derivatives` | AFTER | UPDATE | `validity_state` → 'invalid' triggers AccessPolicyChangedEvent cascade; **STUB implementation** — stub body issues `RAISE NOTICE 'trg_source_derivative_invalidation_cascade: stub — source_derivative % validity_state changed to invalid', NEW.id` and returns NULL without inserting into `access_policy_changed_events`. Full cascade logic (insert AccessPolicyChangedEvent, cascade invalidation to related ContextManifests) is deferred to Context Broker specification and will be implemented in a future migration body replacement. | `access_policy_changed_events`, `context_manifests` (full impl); None (stub) | STUB — issues RAISE NOTICE only; no AccessPolicyChangedEvent inserted until full implementation |
| `trg_claim_numeric_unit_check` | Trigger | 0003 | Phase 5 Pass C | `claims` | BEFORE | INSERT, UPDATE | Full unit enforcement per CONTENT_LAYER.md §3.4: enforces 10 conditions including non-numeric/unit field separation, predicate unit requirement and prohibition, unit existence and deprecation check, permitted_unit_codes and permitted_unit_categories whitelists, requires_qualifier enforcement, integer-only, min/max value constraints; all failures RAISE EXCEPTION. SECURITY DEFINER. Reads `value_unit_code` and `value_unit_qualifier` from `claims`. | `claim_predicates` (74 records, Migration 0003); `claim_value_units` (11 records, **Migration 0001 prerequisite**) | Rejects invalid unit assignment |

---

### RLS Policies (Phase 7)

Policies are enumerated in VOCABULARY_RLS_MATRIX.md §2. Summary by group:

| Group | Count | Tables Covered | Function Dependencies |
|---|---|---|---|
| A — DELETE denied | 14 | claims, narratives, sources, artifacts, relationships, events, approval_records, context_manifests, access_policy_changed_events, authority_assignments, contest_records, person_names, person_pronouns, person_gender_descriptors | None |
| B — UPDATE immutability | 1 | approval_records | None |
| C — LifeBook-scoped SELECT | 19 | All content and attribute tables; approval_records, display_policies, display_policy_rules, source_derivatives (added) | `fn_lb_membership_role` |
| D — INSERT and AI restrictions | 11 | claims, narratives, events, approval_records, sources, person_names, display_policies, contest_records, person_name_derivatives, source_derivatives (added) | `fn_user_is_agent`, `fn_lb_membership_role` |
| E — Cultural and classification | 8 | claims, narratives, artifacts, sources | `fn_has_active_authority` |
| F — DisplayPolicy lifecycle | 4 | display_policies, display_policy_rules | `fn_has_active_authority` |
| G — Governance | 3 | authority_assignments, contest_records, person_name_derivatives | `fn_lb_membership_role`, `fn_has_contest_standing` |
| H — LifeBook Entity Access | 12 | lifebook_entities (6 policies), lifebook_person_contexts (6 policies) | `fn_lb_membership_role`, `fn_is_subject_of`, `fn_user_is_agent` |
| **Total** | **71** | | |

Individual policy names and USING/WITH CHECK specifications are in VOCABULARY_RLS_MATRIX.md §2.

---

## Part III — RLS Coverage Summary

### Tables WITH RLS (25 tables)

These tables contain governed content or governance records. RLS provides row-level actor scoping that cannot be guaranteed by application-layer checks alone.

| Table | Why RLS Is Required |
|---|---|
| `claims` | Core assertion layer; actor class, LifeBook scope, access_classification, AI restrictions, and cultural governance all govern access at the row level |
| `relationships` | Same as claims; content fields are governed assertions about entity relationships |
| `narratives` | Long-form content with actor scope, community_account gate, and cultural governance |
| `narrative_entities` | Scoped via parent narrative; `is_restricted_mention` field controls display context access |
| `sources` | Cross-LifeBook access requires explicit grant; DNA and restricted sources require steward-only access; AI denied |
| `artifacts` | Access_classification filtering; `object_key` must be column-restricted; URL issuance gated through SECURITY DEFINER function |
| `events` | AI cannot INSERT events; culturally governed events excluded from AI context |
| `event_participants` | Scoped via parent event; restricted participants must not appear in AI context |
| `display_policies` | Governance records; actor scope is set_by_role authority, not LifeBook membership; AI denied |
| `display_policy_rules` | Governance records; fully immutable when parent policy is non-draft |
| `approval_records` | Immutable governance records; UPDATE denied for all actors; AI INSERT denied |
| `authority_assignments` | Governance records; revocation is the only permitted update; permanent records |
| `contest_records` | Dispute records visible only to parties with standing; AI denied |
| `person_names` | Subject-controlled attributes; AI denied; usage_type filtering for display contexts |
| `person_pronouns` | Subject authority overrides steward; AI denied |
| `person_gender_descriptors` | Subject authority overrides steward; AI denied |
| `person_name_derivatives` | Agent restricted from restricted parent names; system service writes |
| `context_manifests` | AI governance records; permanent; DELETE denied |
| `access_policy_changed_events` | Audit records; permanent; DELETE denied |
| `source_derivatives` | AI-generated outputs; invalidated by policy changes |
| `lifebook_memberships` | RLS enabled because `fn_lb_membership_role` reads this table under SECURITY DEFINER; enabling RLS prevents external actors from reading all membership records directly |
| `claim_evidence` | Scoped via parent claim's LifeBook; access follows claim access |
| `artifact_source_links` | Scoped via parent artifact's LifeBook |
| `lifebook_entities` | `visibility_status` creates per-row access differences (visible vs. hidden/restricted/pending_confirmation/anonymized); subject has independent SELECT grant for their own record regardless of visibility_status; AI denied entirely; steward notes must not be visible to non-stewards |
| `lifebook_person_contexts` | Contains sensitive governance fields (authority_context, contribution lifecycle) and subject-sovereign consent fields (cross-LifeBook authorization); dual-governance model requires row-level actor differentiation; contributor/viewer denied; AI denied entirely |

### Tables WITHOUT RLS (26 tables)

These tables are reference catalogues, infrastructure anchors, or operational records where actor scoping is handled by database grants (role-level access) rather than row-level policies.

**Count note:** 25 tables have RLS + 26 tables do not = 51 total tables across Migration 0002 (1 table: `display_contexts`) and Migration 0003 (50 tables). MIGRATION_0003_PROPOSAL.md §12 has been updated to reflect the correct count of 50 tables and 3 deferred FKs.

| Table | Why RLS Is Not Applied |
|---|---|
| `jurisdictions` | System-managed reference table; all authenticated roles may read; no per-row actor differences |
| `jurisdiction_policy_versions` | System-managed reference; same as jurisdictions |
| `user_profiles` | Authentication anchor; access controlled by application layer; no LifeBook-specific row distinctions at this layer |
| `entities` | Entity supertype anchor; read access is governed by the content tables that reference entities, not by the entity record itself |
| `persons` | Same as entities; person metadata without biographical assertions |
| `organizations` | Same as entities |
| `places` | Same as entities |
| `vessels` | Same as entities |
| `communities` | Same as entities |
| `event_series` | Same as entities |
| `lifebooks` | LifeBook records are scoped at the application layer; membership is in `lifebook_memberships` which has RLS |
| `user_person_links` | Read by `fn_is_subject_of` (SECURITY DEFINER); not governed at the row level directly |
| `escalation_policies` | System reference; no per-row actor differences |
| `approval_policies` | System reference; template records, not instance records |
| `conflict_resolution_policies` | System reference |
| `display_contexts` | Architectural constants; read by all |
| `claim_predicates` | Catalogue; read by all authenticated roles |
| `claim_value_units` | Catalogue; read by all authenticated roles — created in Migration 0001; GRANT SELECT granted in Migration 0003 |
| `relationship_types` | Catalogue; read by all authenticated roles |
| `agent_registry` | System reference; read by all |
| `context_profiles` | System reference; read by all |
| `merge_records` | Operational governance record; access controlled by application workflow layer |
| `cross_lifebook_authorizations` | Cross-LifeBook operational record; access governed by application |
| `lifebook_source_access` | Junction for cross-LifeBook source access; read by `fn_has_source_access_grant` under SECURITY DEFINER |
| `escalation_records` | Operational workflow record |
| `escalation_notifications` | Operational audit record |

---

## Part IV — Seed Data Registry

### 4.1 Display Contexts (Migration 0002)

9 records. These are architectural constants — they may not be added to, removed from, or renamed without a new ADR and DP decision.

| code | label | sort_order | Fail-Closed Default |
|---|---|---|---|
| `public_ui` | Public UI | 1 | deny |
| `family_ui` | Family UI | 2 | deny |
| `steward_ui` | Steward UI | 3 | allow (steward role only) |
| `historical_record` | Historical Record | 4 | deny |
| `ordinary_search` | Ordinary Search | 5 | deny |
| `identity_resolution_search` | Identity Resolution Search | 6 | deny |
| `default_export` | Default Export | 7 | deny |
| `steward_export` | Steward Export | 8 | allow (steward role only) |
| `ai_generation` | AI Generation | 9 | deny |

Source: DISPLAY_POLICY_MODEL.md v0.1. Committed in Migration 0002 before any `display_policy_rules` can be created.

### 4.2 Jurisdiction Records (Migration 0003 — Batch 1 seed)

Minimum 6 records. Must be committed before any `lifebooks` record can be created (NOT NULL FK). Additional jurisdictions added over time without migration.

| Jurisdiction | Level | PIPEDA Applicability | Notes |
|---|---|---|---|
| Canada | Federal | Yes | Default for all Canadian residents |
| Alberta | Provincial | Yes (+ PIPA AB) | Province where primary deployment operates |
| British Columbia | Provincial | Yes (+ PIPA BC) | Initial target province |
| Ontario | Provincial | Yes | Initial target province |
| Ukraine | National | No | For Iryna Pikul's LifeBook and Ukrainian-resident subjects |
| International default | N/A | Varies | Catch-all for subjects outside defined jurisdictions |

Source: OPERATIONAL_MODELS.md §4.

### 4.3 Claim Predicate Records (Migration 0003 — Batch 8 seed)

74 records. Source: CLAIM_PREDICATE_CATALOGUE.md v0.2.

These records govern what a Claim can assert. Every Claim's `predicate_id` must reference a record in this table. The `trg_claim_numeric_unit_check` trigger reads this table at INSERT/UPDATE time and must not be created until all 74 records are committed.

Predicate categories (per CLAIM_PREDICATE_CATALOGUE.md):

| Category | Approximate Count | Notes |
|---|---|---|
| Identity predicates | ~12 | birth_date, birth_place, preferred_name, legal_name, aliases, etc. |
| Biographical predicates | ~10 | education, occupation, nationality, religion, etc. |
| Physical predicates | ~8 | height, weight, eye_colour, hair_colour, etc. |
| Event predicates | ~10 | death_date, death_place, marriage_date, emigration_date, etc. |
| Relationship predicates | ~6 | birth_order, adoption_status, etc. |
| Source/evidence predicates | ~8 | document_date, document_issuer, record_number, etc. |
| Cultural predicates | ~10 | cultural_affiliation, traditional_name_usage, treaty_number, etc. |
| Medical predicates | ~5 | cause_of_death, genetic_condition (requires restricted access) |
| Other | ~5 | miscellaneous biographical |

**Authoring status:** Seed file must be authored and reviewed before Migration 0003 Batch 8 SQL is written. This is a pre-authoring confirmation item per MIGRATION_IMPLEMENTATION_PLAN.md §6.

### 4.4 Claim Value Unit Records (Migration 0001 — prerequisite; not seeded by Migration 0003)

**Owner: Migration 0001** (`20260724153745_types_and_vocabularies.sql`). Migration 0003 seeds zero records into this table.
11 records. Source: CONTENT_LAYER.md §3.2.2 (authoritative).

| Unit Code | Label | Category | requires_qualifier |
|---|---|---|---|
| `year` | Years | duration | FALSE |
| `month` | Months | duration | FALSE |
| `day` | Days | duration | FALSE |
| `age_years` | Age in years | duration | FALSE |
| `km` | Kilometres | distance | FALSE |
| `mile` | Miles | distance | FALSE |
| `acre` | Acres | area | FALSE |
| `hectare` | Hectares | area | FALSE |
| `currency` | Currency | currency | **TRUE** — qualifier must be ISO 4217 code (e.g. CAD, USD, UAH) |
| `count` | Count | count | FALSE |
| `percentage` | Percentage | ratio | FALSE |

### 4.5 Relationship Type Records (Migration 0003 — Batch 8 seed)

27 records. Source: RELATIONSHIP_TYPE_CATALOGUE.md.

| Category | Types |
|---|---|
| Family (biological) | parent_of, sibling_of, child_of, twin_of |
| Family (legal) | adopted_child_of, adoptive_parent_of, step_parent_of, step_child_of, guardian_of, ward_of |
| Marital / partnership | married_to, separated_from, divorced_from, widowed_by, domestic_partner_of, betrothed_to |
| Professional / organizational | employer_of, employee_of, colleague_of, business_partner_of |
| Community / cultural | member_of_community, cultural_mentor_of, cultural_apprentice_of |
| Other | roommate_of, neighbour_of, friend_of, acquaintance_of |

### 4.6 Governance Policy Seed Records (Migration 0003 — Batches 5–6 seed)

Representative records only. These are not exhaustive governance configurations — they establish that the policy tables are functional and provide a baseline for initial deployments. Production governance configurations are authored by stewards and Discovery Partners outside migration scope.

| Table | Records | Source |
|---|---|---|
| `approval_policies` | ≥ 1 representative policy per GOVERNANCE_MODELS.md §4.4 (e.g., `standard_two_steward_approval`, `cultural_authority_required`) | GOVERNANCE_MODELS.md §4.4 |
| `conflict_resolution_policies` | ≥ 1 representative policy (e.g., `standard_escalation_path`) | GOVERNANCE_MODELS.md §5.5 |
| `escalation_policies` | ≥ 1 representative policy (e.g., `default_48hr_notification`) | OPERATIONAL_MODELS.md §2 |

### 4.7 Agent Registry Records (Migration 0003 — Batch 9 seed)

Records per AI_CONTEXT_BROKER.md §3.2. At minimum:

| Agent Code | Purpose | Notes |
|---|---|---|
| Initial extraction agent | The core AI extraction agent authorized for `ai_extracted_submission` Claims | Version-tagged; updated as agent versions change |

`memory_atmosphere_policy_evaluator` is deferred — pending Memory Atmosphere Engine implementation (ADR-0002).

### 4.8 Context Profile Records (Migration 0003 — Batch 9 seed)

Records per AI_CONTEXT_BROKER.md §2. At minimum:

| Profile Code | Purpose |
|---|---|
| `respectful_generation` | Default profile for AI-assisted biographical content generation; full cultural and sensitivity governance applied |
| `identity_resolution` | Profile for identity resolution search; restricted to non-culturally-governed, policy_approved records; limited field exposure |

---

## Part V — Final SQL Authoring Checklist

### Pre-Authoring Confirmations (must be resolved before the blocked tables are authored)

| # | Item | Blocks | Status |
|---|---|---|---|
| A | Confirm PERSON_ATTRIBUTE_CATALOGUE.md G2 normalization: four-field model (`evidence_status`, `dispute_status`, `precision_status`, `review_status`) replacing former combined `confidence` enum; `review_status` independent on `person_name_derivatives` | `person_names` and `person_name_derivatives` SQL (Batch 14) | **Required** — confirm before authoring Batch 14 |
| B | Confirm ClaimPredicate seed file (74 records) is authored, reviewed, and verified against CLAIM_PREDICATE_CATALOGUE.md v0.2 | Batch 8 seed section + `trg_claim_numeric_unit_check` creation | **Required** — seed file must pre-exist authoring of the seed section |
| C | Confirm single-file strategy for Migration 0003 is accepted (per MIGRATION_IMPLEMENTATION_PLAN.md §2.2 Option A) | Migration file structure | Recommended: single file. Confirm before authoring begins |

### Migration 0002 Authoring Checklist

- [ ] **0002-1:** Author three enum type DDL statements (`relationship_interaction_type`, `display_policy_status`, `display_policy_decision`) — no IF NOT EXISTS; explicit fail on unexpected state per MIGRATION_PHILOSOPHY.md
- [ ] **0002-2:** Author `display_contexts` table DDL — TEXT PRIMARY KEY on `code`; NOT NULL on label, description, sort_order; `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`
- [ ] **0002-3:** Author 9 seed INSERT statements for `display_contexts` in sort_order sequence
- [ ] **0002-4:** Wrap entire migration in explicit transaction block
- [ ] **0002-5:** Run 5 post-apply validation checks (enum count, table structure, seed count, all 9 codes present, no duplicate sort_orders) — see MIGRATION_IMPLEMENTATION_PLAN.md §1.5
- [ ] **0002-6:** Apply to Supabase; confirm clean application with no warnings
- [ ] **0002-7:** Commit to git per MIGRATION_PHILOSOPHY.md §7 format
- [ ] **0002-8:** Update PRE_SQL_READINESS_REVIEW.md gate status to: MIGRATION 0002 COMPLETE

### Migration 0003 Authoring Checklist

**Phase 1 — Tables (Batches 1–14)**

- [ ] **0003-T01:** Author Batch 1 DDL (jurisdictions, jurisdiction_policy_versions) + minimum 6 jurisdiction seed records
- [ ] **0003-T02:** Author Batch 2 DDL (user_profiles)
- [ ] **0003-T03:** Author Batch 3 DDL (entities, persons, organizations, places, vessels, communities, event_series)
- [ ] **0003-T04:** Author Batch 4 DDL in this internal order: `lifebooks` → `lifebook_memberships` → `user_person_links` → `lifebook_entities` → `lifebook_person_contexts` (**without** `permission_cache_policy_version_id` FK constraint)
- [ ] **0003-T05:** Author Batch 5 DDL (escalation_policies, approval_policies, conflict_resolution_policies, display_policies **without** `approval_record_id` FK, display_policy_rules) + governance policy seed records; **immediately after `approval_policies` DDL:** add Deferred FK 3 (`fk_permission_cache_approval_policy` on `lifebook_person_contexts`)
- [ ] **0003-T06:** Author Batch 6 DDL (approval_records)
- [ ] **0003-T07:** Author Batch 7 DDL (authority_assignments **without** `basis_claim_id` FK)
- [ ] **0003-T08:** Author Batch 8 DDL (claim_predicates, relationship_types) + seed datasets (74 + 27 records) — `claim_value_units` is a Migration 0001 prerequisite; not created or seeded here — **Note: trg_claim_numeric_unit_check is NOT created here**
- [ ] **0003-T09:** Author Batch 9 DDL (agent_registry, context_profiles) + seed records
- [ ] **0003-T10:** Author Batch 10 DDL in this internal order: sources → claims (with inline self-FK) → claim_evidence → relationships (with inline self-FK) → narratives → narrative_entities → events (with inline source_claim_id FK) → event_participants → artifacts → artifact_source_links
- [ ] **0003-T11:** Author Batch 11 DDL (context_manifests, source_derivatives)
- [ ] **0003-T12:** Author Batch 12 DDL (merge_records, cross_lifebook_authorizations, lifebook_source_access)
- [ ] **0003-T13:** Author Batch 13 DDL (contest_records, escalation_records, escalation_notifications, access_policy_changed_events)
- [ ] **0003-T14:** Author Batch 14 DDL (person_names, person_name_derivatives, person_pronouns, person_gender_descriptors) — **Blocked on Pre-Authoring Confirmation A**

**Phase 2 — Deferred Foreign Keys**

- [ ] **0003-FK1:** Author `ALTER TABLE authority_assignments ADD CONSTRAINT fk_authority_basis_claim FOREIGN KEY (basis_claim_id) REFERENCES claims(id)` — placed immediately after Batch 10 claims DDL in the file
- [ ] **0003-FK2:** Author `ALTER TABLE display_policies ADD CONSTRAINT fk_display_policy_approval_record FOREIGN KEY (approval_record_id) REFERENCES approval_records(id)` — placed immediately after Batch 6 DDL in the file
- [ ] **0003-FK3:** Author `ALTER TABLE lifebook_person_contexts ADD CONSTRAINT fk_permission_cache_approval_policy FOREIGN KEY (permission_cache_policy_version_id) REFERENCES approval_policies(id)` — placed immediately after Batch 5 `approval_policies` DDL in the file

**Phase 3 — Indexes**

- [ ] **0003-IDX:** Author all 7 index statements — placed after Phase 2, before Phase 4

**Phase 4 — Helper Functions**

- [ ] **0003-FN1:** Author `fn_user_is_agent` — no SECURITY DEFINER required; uses `current_user` or `pg_has_role()` only
- [ ] **0003-FN2:** Author `fn_lb_membership_role` — SECURITY DEFINER; `search_path = 'public', pg_temp`; no `user_id` parameter; returns TEXT; reads only own membership rows
- [ ] **0003-FN3:** Author `fn_is_subject_of` — SECURITY DEFINER; same controls; returns BOOLEAN
- [ ] **0003-FN4:** Author `fn_has_active_authority` — SECURITY DEFINER; **verify recursion constraint: authority_assignments RLS will not call this function**
- [ ] **0003-FN5:** Author `fn_display_policy_allows` — SECURITY DEFINER; accepts `p_policy_id UUID, p_context_code TEXT` only; **verify recursion constraint: display_policies/display_policy_rules RLS will not call this function**
- [ ] **0003-FN6:** Author `fn_has_source_access_grant` — SECURITY DEFINER
- [ ] **0003-FN7:** Author `fn_has_community_authorization` — SECURITY DEFINER
- [ ] **0003-FN8:** Author `fn_has_contest_standing` — SECURITY DEFINER; **hard-coded table name whitelist mandatory**; table name → exception (not FALSE) on unrecognized name; dynamic SQL must use parameterized queries not string concatenation; **verify recursion constraint: contest_records RLS SELECT will not call this function**
- [ ] **0003-FN9:** Author `fn_generate_artifact_signed_url` stub — SECURITY DEFINER; returns NULL on any check failure; never exposes `object_key`; full implementation deferred to storage integration milestone; **mark explicitly as STUB in migration comment**
- [ ] **0003-FN-VERIFY:** After all 9 functions are authored, verify SECURITY DEFINER flag, search_path, and governance_functions ownership on functions 2–9 before proceeding

**Phase 5 — Triggers**

- [ ] **0003-TRG-A:** Author all 12 Pass A triggers (no cross-table deps) — see trigger table above for names and tables
- [ ] **0003-TRG-B:** Author all 9 Pass B triggers (cross-table) — after all Batch 14 tables exist
- [ ] **0003-TRG-C:** Author `trg_claim_numeric_unit_check` (Pass C) — only after ClaimPredicate and ClaimValueUnit seed sections are confirmed committed in this transaction

**Phase 6 — RLS Enablement**

- [ ] **0003-RLS-ENABLE:** Author `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` for all 23 governed tables — placed after Phase 5, before any seed data that targets governed tables

**Phase 7 — RLS Policies**

- [ ] **0003-POL-A:** Author 14 DELETE denied policies (policies 16–29) — USING (FALSE); verify each is exactly `FALSE`, not an expression
- [ ] **0003-POL-B:** Author 1 UPDATE immutability policy (policy 49) — USING (FALSE)
- [ ] **0003-POL-C:** Author 15 LifeBook-scoped SELECT policies (policies 1–15)
- [ ] **0003-POL-D:** Author 9 INSERT and AI restriction policies (policies 30–36, 41, 47, 51)
- [ ] **0003-POL-E:** Author 8 cultural and classification policies (policies 37–44) — **verify AND (not OR) in `access_classification = 'culturally_governed'` filter**
- [ ] **0003-POL-F:** Author 4 DisplayPolicy lifecycle policies (policies 45–48)
- [ ] **0003-POL-G:** Author 3 governance policies (policies 50, 52–53)
- [ ] **0003-POL-VERIFY:** Confirm total policy count = 71: `SELECT count(*) FROM pg_policies WHERE schemaname = 'public'`

**Phase 8 — Grants**

- [ ] **0003-GR1:** Author `REVOKE EXECUTE FROM PUBLIC` for all 9 helper functions
- [ ] **0003-GR2:** Author per-role EXECUTE grants per SECURITY_DEFINER_REVIEW.md §EXECUTE grants table
- [ ] **0003-GR3:** Author content table grants by role (authenticated, agent_service, system_service, admin) per VOCABULARY_RLS_MATRIX.md §9 Phase 8
- [ ] ~~**0003-GR4:** Author `REVOKE SELECT ON file_storage_references.object_key` from all non-superuser roles~~ **DEFERRED — W11 resolved (DP Decision 2026-07-25).** `file_storage_references` is not a Migration 0003 object. Column-level restriction deferred to storage integration migration.

**Phase 9 — Validation**

- [ ] **0003-VAL:** Run all validation queries per VOCABULARY_RLS_MATRIX.md §9 Phase 9; expected results: 25 RLS tables, 22 triggers, 9 functions, 71 policies, 3 deferred FK constraints; all must pass before migration is considered complete

**Phase 10 — Verification and Commit**

- [ ] **0003-VFY1:** Record migration hash in migration_log
- [ ] **0003-VFY2:** Apply to Supabase; confirm clean application with no errors or warnings
- [ ] **0003-VFY3:** Commit to git per MIGRATION_PHILOSOPHY.md §7 format
- [ ] **0003-VFY4:** Update PRE_SQL_READINESS_REVIEW.md gate status to: MIGRATION 0003 COMPLETE

### SQL Review Gates

Before the migration is applied to any non-development environment, the following reviews must be completed:

| Review Gate | Reviewer | Focus |
|---|---|---|
| Helper function review | DP + independent reviewer | SECURITY DEFINER correctness, search_path, user_id parameter absence, recursion call chain |
| `fn_has_contest_standing` specific review | DP | Whitelist check, dynamic SQL parameterization, recursion constraint |
| RLS policy logic review | DP | USING/WITH CHECK correctness for all 71 policies; no accidental `USING (TRUE)` without intent |
| Cultural governance exclusion review | DP | Policies 37–40 use AND not OR; absolute exclusion is unconditional |
| `fn_generate_artifact_signed_url` pre-deployment audit | Independent — before production deployment | All failure paths return NULL; object_key never exposed; full audit per SECURITY_DEFINER_REVIEW.md |
| Seed data review | DP | ClaimPredicate 74 records, RelationshipType 27 records — completeness and correctness |
| Batch 14 G2 confirmation | DP | PERSON_ATTRIBUTE_CATALOGUE.md three-field normalization verified before person_names SQL is authored |

---

*Database Object Registry complete. No SQL has been written. No architecture has been modified. This document is the canonical pre-SQL governance record for all objects introduced by Migration 0002 and Migration 0003.*
