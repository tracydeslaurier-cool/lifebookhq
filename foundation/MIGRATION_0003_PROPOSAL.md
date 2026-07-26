# Migration 0003 — Core Schema Scope Proposal
**Version:** 0.2  
**Status:** Approved in principle — scope and filenames updated per DP decisions; SQL NOT authorized  
**Produced:** 2026-07-25  
**Produced by:** Discovery Partner + Claude (architecture session)  
**Depends on:** Migration 0001 (applied: `20260724153745_types_and_vocabularies.sql`); Migration 0002 (`<TIMESTAMP>_predicate_governance_types.sql`, pending)  
**Note:** Migration ordinals revised — an intervening vocabulary migration (0002) precedes this core-schema migration (0003). See §2a.

---

## Purpose

This document defines the proposed scope, sequencing, and open items for migration 0003 — the core-schema migration. It covers every table group in SCHEMA_INVENTORY.md and MIGRATION_SCOPE_MATRIX.md and draws on CONTENT_LAYER.md, GOVERNANCE_MODELS.md, OPERATIONAL_MODELS.md, APPROVAL_INSTANCE_MODEL.md, PERSON_ATTRIBUTE_CATALOGUE.md, and ARCHITECTURE_FREEZE_V1.md.

No SQL is produced until this proposal is reviewed and authorized by the Discovery Partner.

---

## Recommended Filenames

An intervening vocabulary migration is required before the core-schema migration (see §2a). The approved migration sequence is:

```
<TIMESTAMP>_predicate_governance_types.sql   ← new vocabulary migration (0002)
<TIMESTAMP>_core_schema.sql                  ← core schema (0003)
```

## 2a. Intervening Vocabulary Migration (0002)

Per DP Decision 4.2 (PRE_SQL_READINESS_REVIEW.md §4.2), a new `relationship_interaction_type` enum type is required on the `claim_predicates` table. Migration 0001 is applied and immutable. Per MIGRATION_PHILOSOPHY.md §8, new types cannot be inserted into an applied migration.

Migration 0002 (`<TIMESTAMP>_predicate_governance_types.sql`) is a governed vocabulary migration. It must create the following governed types and seed data before the core-schema migration may proceed:

| Object | Kind | Notes |
|---|---|---|
| `relationship_interaction_type` | PostgreSQL enum | 4 values: `proposes / supports / describes / none` |
| `display_policy_status` | PostgreSQL enum | 4 values: `draft / active / superseded / withdrawn` |
| `display_policy_decision` | PostgreSQL enum | 3 values: `allow / deny / conditional` |
| `display_contexts` | Reference table | `code TEXT PRIMARY KEY, label TEXT NOT NULL, description TEXT NOT NULL, sort_order INT NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now()` |
| `display_contexts` seed | 9 INSERT records | `public_ui, family_ui, steward_ui, historical_record, ordinary_search, identity_resolution_search, default_export, steward_export, ai_generation` |

Migration 0002 contains table DDL, seed data, and constraints. The previous description ("no table DDL, seed data, or constraints") applied only before the `display_contexts` reference table was added to scope; that language is superseded. All MIGRATION_PHILOSOPHY.md strictness rules apply in full: explicit transaction, `CREATE TABLE` without `IF NOT EXISTS`, `INSERT INTO` without `ON CONFLICT DO NOTHING`, fail loudly on unexpected state.

Migration 0003 (`<TIMESTAMP>_core_schema.sql`) contains all content previously described as "0002 core schema" in this proposal.

---

## 1. What Migration 0001 Delivered

Applied `20260724153745_types_and_vocabularies.sql`. Contains all 37 enum types and vocabularies, including:

`evidence_status`, `precision_status`, `dispute_status`, `review_status`, `submission_origin`, `access_classification`, `entity_type`, `authority_basis_type`, `authority_role`, `action_type`, `coordination_rule`, `succession_behaviour`, `lifecycle_status`, `conflict_type`, `resolution_rule`, `source_type`, `relationship_status`, `claim_text_validity_state`, and all remaining governed vocabulary enums.

These are available to all tables in the core-schema migration (0003) without further migration work.

---

## 2. Resolved Blockers

The following items were recorded as open blockers in ARCHITECTURE_FREEZE_V1.md §5 and MIGRATION_SCOPE_MATRIX.md. All three are resolved by existing design documents.

### Blocker G1: AuthorityAssignment — authority_basis_record_id
**Status: Resolved by GOVERNANCE_MODELS.md §2**

`AuthorityBasisRecord` is eliminated. The documentary basis for an authority assignment belongs in the Claim layer (P2). AuthorityAssignment instead carries:
- `authority_basis_type` — enum (already in 0001)
- `basis_claim_id` — UUID FK → Claim; **nullable** (null for `self_assertion` and `policy_default`)
- `basis_notes` — Text; nullable

This is a deferred FK: AuthorityAssignment must be created before Claim (governance-first sequencing), so the FK constraint `basis_claim_id → claims(id)` is added via `ALTER TABLE` after Claim is created. See §5.

**Action required before SQL:** Update ARCHITECTURE_FREEZE_V1.md §5 to close this gap as resolved. The entry currently says "Not yet designed — blocks AuthorityAssignment migration."

### Blocker G2: PersonName confidence normalization
**Status: Resolved by GOVERNANCE_MODELS.md §1 and CONTENT_LAYER.md §18.5**

The old combined `confidence` enum on PersonName and PersonNameDerivative is replaced by three separate fields:
- `evidence_status` (enum from 0001)
- `dispute_status` (enum from 0001)
- `precision_status` (enum from 0001)

**Action required before SQL:** PERSON_ATTRIBUTE_CATALOGUE.md must be updated to reflect this normalization, per ARCHITECTURE_FREEZE_V1.md §5. Until that update is made and confirmed, PersonName and PersonNameDerivative SQL may not be written.

### Blocker G3: FK terminology — ApprovalPolicy → ApprovalRecord
**Status: Resolved by APPROVAL_INSTANCE_MODEL.md v1.0**

Three tables use ApprovalPolicy FKs where they must use ApprovalRecord (the instance, not the template). The corrections, per ARCHITECTURE_FREEZE_V1.md §1.1:

| Table | Field | Must reference |
|---|---|---|
| `MergeRecord` | `approval_record_id` | ApprovalRecord — NOT NULL |
| `CrossLifeBookAuthorization` | `approval_a_id` | ApprovalRecord — NOT NULL |
| `CrossLifeBookAuthorization` | `approval_b_id` | ApprovalRecord — NOT NULL |
| `CrossLifeBookAuthorization` | `person_authorization_id` | ApprovalRecord — nullable |
| `EscalationRecord` | `approval_record_id` | ApprovalRecord — nullable (renamed from `approval_workflow_id`) |

**Action required before SQL:** SCHEMA_INVENTORY.md must be updated to correct these FK references and add ApprovalRecord to the inventory. SQL for MergeRecord, CrossLifeBookAuthorization, and EscalationRecord may not be written until this is done.

---

## 3. Tables Proposed for the Core-Schema Migration (0003)

Listed in FK dependency order. Batch labels are for readability; within a single migration file, order matters only for FK constraint satisfaction.

### Batch 1 — Jurisdiction (prerequisite for LifeBook per P13)

| Table | Design doc | Notes |
|---|---|---|
| `jurisdictions` | OPERATIONAL_MODELS.md §4 | Field-complete. 10 launch jurisdictions defined |
| `jurisdiction_policy_versions` | OPERATIONAL_MODELS.md §4 | Field-complete |

**Seed required:** Minimum 6 jurisdiction records before LifeBook records can exist: Canada (federal), Alberta, British Columbia, Ontario, Ukraine, and an international default. PIPEDA applicability mapped in OPERATIONAL_MODELS.md.

### Batch 2 — Users

| Table | Design doc | Notes |
|---|---|---|
| `user_profiles` | ANCHOR_MODELS.md | Wraps auth.users; references auth.users(id) |

### Batch 3 — Entity anchors

| Table | Design doc | Notes |
|---|---|---|
| `entities` | ANCHOR_MODELS.md | Entity supertype |
| `persons` | ANCHOR_MODELS.md | Person subtype; no PersonName FKs here |
| `organizations` | ANCHOR_MODELS.md | Organization subtype |
| `places` | ANCHOR_MODELS.md | Place subtype; cached_latitude/longitude are cached, not authoritative (P11) |
| `vessels` | ANCHOR_MODELS.md | Vessel subtype |
| `communities` | ANCHOR_MODELS.md | Community subtype |
| `event_series` | ANCHOR_MODELS.md | EventSeries subtype |

### Batch 4 — LifeBook scoping

| Table | Design doc | Notes |
|---|---|---|
| `lifebooks` | ANCHOR_MODELS.md | Requires jurisdictions (NOT NULL FK per P13) and user_profiles |
| `lifebook_memberships` | ANCHOR_MODELS.md | Requires lifebooks + user_profiles |
| `user_person_links` | ANCHOR_MODELS.md | Requires user_profiles + persons; optional link (P1) |
| `lifebook_entities` | ANCHOR_MODELS.md §9 | Requires lifebooks, entities, user_profiles; RLS enabled; `visibility_status` governs member access; deferred completeness trigger in Phase 5 Pass B |
| `lifebook_person_contexts` | ANCHOR_MODELS.md §10 | Requires lifebook_entities, entities; RLS enabled; `permission_cache_policy_version_id` FK to approval_policies is **Deferred FK 3** (approval_policies not yet created); created in same transaction as parent lifebook_entity |

**Internal ordering:** `lifebook_entities` must be created before `lifebook_person_contexts` within Batch 4.

**Deferred FK 3:** `lifebook_person_contexts.permission_cache_policy_version_id` references `approval_policies(id)`. `approval_policies` is Batch 5. The FK constraint is added immediately after Batch 5 `approval_policies` DDL:
```
ALTER TABLE lifebook_person_contexts
  ADD CONSTRAINT fk_permission_cache_approval_policy
  FOREIGN KEY (permission_cache_policy_version_id) REFERENCES approval_policies(id);
```

### Batch 5 — Governance policy templates

| Table | Design doc | Notes |
|---|---|---|
| `escalation_policies` | OPERATIONAL_MODELS.md §2 | Field-complete; no upstream entity FKs |
| `approval_policies` | GOVERNANCE_MODELS.md §4 | Includes `cultural_governance_required BOOLEAN NOT NULL DEFAULT FALSE` (§4.5); 8 lifecycle_status values (cultural_governed removed) |
| `conflict_resolution_policies` | GOVERNANCE_MODELS.md §5 | Field-complete |
| `display_policies` | DISPLAY_POLICY_MODEL.md §2 | Field-complete — see DISPLAY_POLICY_MODEL.md; two-table model; `approval_record_id` is a deferred FK (see §5) |
| `display_policy_rules` | DISPLAY_POLICY_MODEL.md §3 | Depends on display_policies and display_contexts (from migration 0002); UNIQUE(display_policy_id, display_context) |

### Batch 6 — Approval instances

| Table | Design doc | Notes |
|---|---|---|
| `approval_records` | APPROVAL_INSTANCE_MODEL.md v1.0 | Requires approval_policies; must precede MergeRecord and CrossLifeBookAuthorization (NOT NULL FKs) |

### Batch 7 — Authority

| Table | Design doc | Notes |
|---|---|---|
| `authority_assignments` | GOVERNANCE_MODELS.md §3 | Requires persons, lifebooks, user_profiles, approval_policies; `basis_claim_id` FK to claims is deferred (see §5) |

### Batch 8 — Reference catalogues (tables, not enums)

| Table | Design doc | Notes |
|---|---|---|
| `claim_predicates` | CONTENT_LAYER.md §3 | Reference table; 74 predicates from CLAIM_PREDICATE_CATALOGUE.md govern seed content |
| `claim_value_units` | CONTENT_LAYER.md §3.2 | **Prerequisite from Migration 0001** — 11 records already present; NOT created or seeded in Migration 0003 |
| `relationship_types` | RELATIONSHIP_TYPE_CATALOGUE.md | Reference table; 27 types govern seed content |

**Note on seed timing:** The numeric Claim enforcement trigger (`trg_claim_numeric_unit_check`) must be created *after* ClaimPredicate and ClaimValueUnit seed data is committed. Trigger creation is a separate step within the migration file.

### Batch 9 — AI Context infrastructure

| Table | Design doc | Notes |
|---|---|---|
| `agent_registry` | AI_CONTEXT_BROKER.md | Seed: registered agents per AI_CONTEXT_BROKER.md §3.2. `memory_atmosphere_policy_evaluator` deferred (pending implementation) |
| `context_profiles` | AI_CONTEXT_BROKER.md | Seed: `respectful_generation`, `identity_resolution`, and any other profiles from AI_CONTEXT_BROKER.md §2 |

### Batch 10 — Content tables

| Table | Design doc | Notes |
|---|---|---|
| `sources` | CONTENT_LAYER.md | Requires lifebooks, user_profiles; `source_type = dna_analysis` → restricted by default (P8) |
| `claims` | CONTENT_LAYER.md §2 | Requires entities, lifebooks, claim_predicates, claim_value_units, user_profiles, display_policies; includes `value_unit_qualifier` (TEXT, nullable); self-referential FK `superseded_by_claim_id` |
| `claim_evidence` | CONTENT_LAYER.md §4 | Requires claims, sources |
| `relationships` | CONTENT_LAYER.md | Requires entities, lifebooks, relationship_types, user_profiles; inline self-FK `superseded_by_relationship_id UUID NULL` (DP Decision 2026-07-25) |
| `narratives` | CONTENT_LAYER.md | Requires lifebooks, user_profiles |
| `events` | CONTENT_LAYER.md | Requires lifebooks, user_profiles, claims; inline nullable FK `source_claim_id UUID NULL REFERENCES claims(id)` (DP Decision 2026-07-25); distinct from EventSeries entity anchor |
| `artifacts` | CONTENT_LAYER.md | Requires lifebooks, sources, user_profiles |

### Batch 11 — AI Context manifests

| Table | Design doc | Notes |
|---|---|---|
| `context_manifests` | AI_CONTEXT_BROKER.md | Requires claims, sources, agent_registry, context_profiles; permanent records (P9 — DELETE denied by RLS) |
| `source_derivatives` | AI_CONTEXT_BROKER.md | Requires sources, context_manifests |

### Batch 12 — Cross-LifeBook

| Table | Design doc | Notes |
|---|---|---|
| `merge_records` | ANCHOR_MODELS.md + APPROVAL_INSTANCE_MODEL.md | Requires persons + approval_records (NOT NULL FK — G3 blocker resolved) |
| `cross_lifebook_authorizations` | ANCHOR_MODELS.md + APPROVAL_INSTANCE_MODEL.md | Requires lifebooks, persons + approval_records (NOT NULL × 2 + nullable × 1 — G3 blocker resolved) |

### Batch 13 — Escalation and dispute

| Table | Design doc | Notes |
|---|---|---|
| `contest_records` | OPERATIONAL_MODELS.md §3 | Requires claims, authority_assignments, lifebooks, user_profiles |
| `escalation_records` | OPERATIONAL_MODELS.md §5 | Field rename: `approval_record_id` (was `approval_workflow_id`); requires escalation_policies, approval_records, contest_records |
| `escalation_notifications` | OPERATIONAL_MODELS.md §6 | Requires escalation_records, user_profiles |
| `access_policy_changed_events` | CONTENT_LAYER.md | Permanent records; DELETE denied by RLS (P9) |

### Batch 14 — Person attributes

| Table | Design doc | Notes |
|---|---|---|
| `person_names` | PERSON_ATTRIBUTE_CATALOGUE.md | **Blocked until G2 resolved:** confidence normalization must be applied in PERSON_ATTRIBUTE_CATALOGUE.md before SQL is written; 13 usage_types |
| `person_name_derivatives` | PERSON_ATTRIBUTE_CATALOGUE.md | Requires person_names; blocked until G2 resolved |
| `person_pronouns` | PERSON_ATTRIBUTE_CATALOGUE.md | Requires persons |
| `person_gender_descriptors` | PERSON_ATTRIBUTE_CATALOGUE.md | Requires persons |

### Batch 15 — Deferred FKs and constraints

| Item | Notes |
|---|---|
| `ALTER TABLE authority_assignments ADD CONSTRAINT fk_authority_basis_claim FOREIGN KEY (basis_claim_id) REFERENCES claims(id)` | **Deferred FK 1.** authority_assignments (Batch 7) created before claims (Batch 10); nullable FK |
| `ALTER TABLE display_policies ADD CONSTRAINT fk_display_policy_approval_record FOREIGN KEY (approval_record_id) REFERENCES approval_records(id)` | **Deferred FK 2.** display_policies (Batch 5) created before approval_records (Batch 6); nullable FK |
| `ALTER TABLE lifebook_person_contexts ADD CONSTRAINT fk_permission_cache_approval_policy FOREIGN KEY (permission_cache_policy_version_id) REFERENCES approval_policies(id)` | **Deferred FK 3.** lifebook_person_contexts (Batch 4) created before approval_policies (Batch 5); nullable FK; inserted immediately after Batch 5 approval_policies DDL |
| `trg_claim_numeric_unit_check` | Deferred constraint trigger (not a FK); must be created after claim_predicates seed (74 records, this migration) is committed; claim_value_units (11 records) is a Migration 0001 prerequisite already present; fires on INSERT and UPDATE to claims |
| All constraint-layer items (Group 11) | RLS policies, other triggers per MIGRATION_SCOPE_MATRIX.md Group 11; see §6 |
| `trg_claim_numeric_unit_check` | Deferred constraint trigger; must be created after claim_predicates seed is committed (claim_value_units prerequisite is from Migration 0001); fires on INSERT and UPDATE to claims; defined in CONTENT_LAYER.md §3.4 |
| All 13 constraint-layer items | RLS policies, other triggers per MIGRATION_SCOPE_MATRIX.md Group 11 |

---

## 4. Tables Deferred Out of the Core-Schema Migration (0003)

| Table | Reason |
|---|---|
| `AtmosphereProfile` | Memory Atmosphere Engine — not yet implemented; no migration blocker; deferred pending implementation (ADR-0002 §Deferred schema objects) |
| `AtmosphereConsentRecord` | Same |
| `AtmospherePolicyVersion` | Same |
| `AtmosphereAuditLog` | Same |
| `ArtifactAtmospherePermission` | Same |
| `CapacityDetermination` | No current FK dependency; design deferred to v2 (ARCHITECTURE_FREEZE_V1.md §4) |
| `PlaceGeometry` | Authoritative area-based geometry; deferred to v2 |
| `OrgName versioned attribute` | Not yet designed; excluded from v1 |
| `ConstraintProfile` | Per-LifeBook predicate restriction; deferred to v2 |
| Indigenous/ceremonial name records | Requires external community engagement before any deployment (GOVERNANCE_MODELS.md §9 Scenario 9 — pre-deployment blocker) |

---

## 5. FK Ordering and Circular Dependencies

There are exactly **two** true deferred FKs in migration 0003. Both must be added via `ALTER TABLE` within the same migration file, after the referenced table is created, and both must be documented at the top of the migration file under **Deferred FK declarations**.

`claims.superseded_by_claim_id → claims(id)` is a nullable self-referential FK on the same table. It is declared inline at table creation time and is NOT a deferred FK.

**Deferred FK 1 — AuthorityAssignment → Claim:**

`authority_assignments.basis_claim_id` references `claims(id)`. AuthorityAssignment must be created before Claim (governance precedes content). The FK constraint is added after the `claims` table DDL.

```
-- Order: CREATE TABLE authority_assignments (...) [no FK on basis_claim_id]
-- ... [many steps later] ...
-- CREATE TABLE claims (...)
-- ... [seed predicates, units] ...
-- ALTER TABLE authority_assignments 
--   ADD CONSTRAINT fk_authority_basis_claim 
--   FOREIGN KEY (basis_claim_id) REFERENCES claims(id);
```

**Deferred FK 2 — DisplayPolicy → ApprovalRecord:**

`display_policies.approval_record_id` references `approval_records(id)`. `display_policies` is created in Batch 5, before `approval_records` (Batch 6). The FK constraint is added after `approval_records` is created.

```
-- Order: CREATE TABLE display_policies (...) [no FK on approval_record_id]
-- ... [Batch 6] ...
-- CREATE TABLE approval_records (...)
-- ALTER TABLE display_policies
--   ADD CONSTRAINT fk_display_policy_approval_record
--   FOREIGN KEY (approval_record_id) REFERENCES approval_records(id);
```

**No other circular dependencies identified.** The Context Manifest → Claim FK is not circular: context_manifests is created after claims.

---

## 6. RLS Implications

The following tables require specific RLS rules that must be implemented in the core-schema migration (0003), not added later:

**Permanent-record tables (P9 — DELETE denied for all roles):**
- `access_policy_changed_events`
- `context_manifests`

**Culturally governed content:**
- Records with `access_classification = culturally_governed` must be excluded from all data access by default. This must be enforced at the data access layer, not only by application logic (GOVERNANCE_MODELS.md §8). RLS policy design required before SQL.

**LifeBook-scoped access:**
- Content tables (claims, narratives, events, artifacts, relationships, sources) are scoped to `lifebook_id`. Cross-LifeBook access requires an explicit `cross_lifebook_authorizations` record (P6).

**DNA source data (P8):**
- `sources` where `source_type = dna_analysis` must be `access_classification = restricted` at INSERT time. Enforced by trigger or check constraint.

**AI-generated content:**
- Claims and artifacts where `ai_generated = true` may not be promoted to `review_status = policy_approved` without a human review step. This is an application-layer enforcement rule, but RLS should deny direct UPDATE of `review_status` to `policy_approved` for AI-generated records without an intermediary approval pathway.

---

## 7. Seed Data Requirements

The following seed data must be inserted within the core-schema migration (0003), in this order relative to table creation:

| Seed dataset | Source | Timing |
|---|---|---|
| Jurisdiction records (min 6) | OPERATIONAL_MODELS.md §4 | Before lifebooks INSERT |
| ClaimPredicate records (74) | CLAIM_PREDICATE_CATALOGUE.md | After claim_predicates DDL; before trg_claim_numeric_unit_check trigger creation |
| ClaimValueUnit records (11) | CONTENT_LAYER.md §3.2.2 | **Seeded in Migration 0001** — zero records added by Migration 0003; already present |
| `trg_claim_numeric_unit_check` trigger | CONTENT_LAYER.md §3.4 | After ClaimPredicate seed committed; ClaimValueUnit prerequisite is from Migration 0001 |
| RelationshipType records (27) | RELATIONSHIP_TYPE_CATALOGUE.md | After relationship_types DDL |
| AgentRegistry initial records | AI_CONTEXT_BROKER.md §3.2 | After agent_registry DDL |
| ContextProfile initial records | AI_CONTEXT_BROKER.md | After context_profiles DDL |
| Representative ApprovalPolicy records | GOVERNANCE_MODELS.md §4.4 | After approval_policies DDL |
| Representative ConflictResolutionPolicy records | GOVERNANCE_MODELS.md §5.5 | After conflict_resolution_policies DDL |
| Representative EscalationPolicy records | OPERATIONAL_MODELS.md §2 | After escalation_policies DDL |

**Seed files not yet written:** ClaimPredicate (74 records), RelationshipType (27 records), EscalationPolicy initial set, AgentRegistry initial set. These must be authored before SQL is written for those tables.

---

## 8. Recommended Migration File Strategy

**Option A: Single migration file (recommended for v1)**

All Batch 1–15 content in one file (`<TIMESTAMP>_core_schema.sql`). Arguments for this approach:
- Avoids cross-migration FK dependencies (a fragile pattern in Supabase)
- A partial migration leaves the schema in an unusable state regardless of where it breaks; splitting provides no additional safety
- 0001 established the pattern of one-file-per-logical-layer; 0003 is the structural layer

**Option B: Two files**

If migration file size is a concern, a clean split exists between governance infrastructure and content:

- `<TIMESTAMP>_governance_infrastructure.sql` — Batches 1–7 (Jurisdiction through Authority)
- `<TIMESTAMP>_content_and_operational_layer.sql` — Batches 8–15 (catalogues through constraints)

Split risk: the content-and-operational-layer migration cannot run without the governance-infrastructure migration; partial application leaves schema incomplete.

---

## 9. Rollback Considerations

The core-schema migration (0003) is a purely additive schema migration. Rollback is available in Supabase branching environments by dropping all tables in reverse dependency order. No data migration or enum modification is involved.

If rollback is needed after 0003 is applied to production, the recommended path is a dedicated rollback migration (DROP TABLE in reverse order) rather than manual intervention, to maintain migration lineage integrity.

---

## 10. Pre-SQL Checklist — Items Requiring DP Decision

The following items must be resolved before SQL authoring begins. Each is a design question, not a typing task.

**10.1 DisplayPolicy design session (RESOLVED)**

Completed 2026-07-25. `display_policies` and `display_policy_rules` are field-complete per DISPLAY_POLICY_MODEL.md v0.1. SCHEMA_INVENTORY.md rows 5.4–5.5 updated. Two minor open items remain (DISPLAY_POLICY_MODEL.md §10.1 and §10.2) — require DP confirmation before applicable SQL is written, but do not block overall SQL authoring.

**10.2 PersonName confidence normalization (G2 blocker)**

PERSON_ATTRIBUTE_CATALOGUE.md must be updated before PersonName/PersonNameDerivative SQL is written. This is a targeted update — replacing the combined `confidence` enum with three separate fields. Discovery Partner decision: should this update be done now (unblocking Batch 14), or should Batch 14 be deferred to a subsequent migration?

**10.3 Single migration vs. two migrations**

Discovery Partner decision: Option A (single file) or Option B (two files)?

**10.4 ARCHITECTURE_FREEZE_V1.md §5 update**

The "AuthorityBasisRecord — not yet designed" gap entry must be updated to reflect its resolution (eliminated; replaced by direct Claim FK). Discovery Partner should confirm this update is authorized before it is made.

**10.5 RLS policy design**

Culturally governed content RLS and the AI-generated content promotion restriction require explicit policy design. Discovery Partner decision: design these now (in the core-schema migration) or defer to a subsequent migration? Deferring means these protections are not in place at launch.

**10.6 ClaimPredicate seed authorship**

74 predicates from CLAIM_PREDICATE_CATALOGUE.md v0.2 must be expressed as seed INSERT statements. This is a large but mechanical task. Discovery Partner decision: author seed in a separate session before SQL authoring, or author seed inline during SQL authoring?

---

## 11. Items Not Blocking 0002

The following open questions from GOVERNANCE_MODELS.md §9 are confirmed not to block 0002, either because they are resolved or because they are application-layer concerns:

- **EscalationPolicy** — resolved (OPERATIONAL_MODELS.md §2)
- **ContestRecord** — resolved (OPERATIONAL_MODELS.md §3)
- **Jurisdiction table** — resolved (OPERATIONAL_MODELS.md §4)
- **CapacityDetermination** — deferred to v2; no current FK dependency
- **AuthorityBasisRecord** — eliminated by GOVERNANCE_MODELS.md §2; direct Claim FK used instead
- **Indigenous governance policy** — external engagement required before deployment, but not a schema blocker; `cultural_governance_required` flag and Scenario 9 rules are representable in the core-schema migration
- **AI context management specification** — application-layer enforcement; the data access rules are documented; the schema supports them
- **review_status transition authorization** — application-layer flow; schema already carries all necessary fields

---

## 12. Summary

Migration 0003 — the core-schema migration — is the complete structural layer: 50 tables, 5 seed datasets, 3 deferred FKs, 1 enforcement trigger, and 13 constraint-layer items.

Three blockers are resolved by existing design documents. The DisplayPolicy design session is complete (DISPLAY_POLICY_MODEL.md v0.1). The RLS design session (§10.5) is the sole remaining pre-SQL design requirement. See PRE_SQL_READINESS_REVIEW.md §7 for the current gate status.

Atmosphere Engine schema objects are deferred in full. PersonName tables remain in scope; the DisplayPolicy blocker is resolved.

Migration 0001 is applied. Migration 0002 (predicate governance types) is pending. The schema is ready for 0003 authoring once the open items in PRE_SQL_READINESS_REVIEW.md §7 are resolved.

---

*DO NOT write 0002 SQL until this proposal is reviewed and authorized by the Discovery Partner.*
