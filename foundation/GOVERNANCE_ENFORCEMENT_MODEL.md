# Governance Enforcement Model
**Version:** 0.2  
**Status:** Architecture phase complete — all blockers resolved; approved for RLS design session and migration SQL authoring  
**Produced:** 2026-07-25  
**Produced by:** Discovery Partner + Claude (architecture session)  
**Bridges:** GOVERNANCE_MODELS.md · DISPLAY_POLICY_MODEL.md · CONTENT_LAYER.md · MIGRATION_0003_PROPOSAL.md → VOCABULARY_RLS_MATRIX.md → SQL

---

## Purpose

This document is the architectural bridge between governance design and SQL implementation. It separates every governance rule into three layers: what is governed, how it is enforced, and where the enforcement lives in SQL. It does not write SQL.

Every RLS policy, trigger, constraint, and application workflow in migration 0003 is traceable to a rule in this document. VOCABULARY_RLS_MATRIX.md will reference this document when specifying RLS and trigger SQL.

---

## How to Read This Document

**Layer 1 — Governance Rules:** What is true. Who holds authority. What conditions apply. What overrides what.

**Layer 2 — Enforcement Strategy:** Exactly one primary enforcement mechanism per rule. Defense-in-depth is noted explicitly when a second mechanism is required. Avoid duplicated enforcement otherwise.

**Layer 3 — SQL Mapping:** Which migration and what implementation type. No SQL is written here.

---

## 1. Claim Governance

### 1.1 Governance Rules (Layer 1)

**Creation:**
- Any authenticated user with a valid `submission_origin` may create a Claim.
- AI agents may create Claims with `submission_origin = ai_extracted_submission`; these start at `review_status = pending` and `evidence_status = unreviewed`.
- System processes may create Claims with `submission_origin = system_inferred_submission`; these start at `review_status = pending` and `evidence_status = inferred`.
- A Claim must have at least one of: `object_entity_id`, `value_text`, `value_date`, `value_numeric`.
- A Claim with `ai_generated = true` must carry `producing_agent_code` and `context_manifest_id`.

**Supersession (not in-place editing):**
- Claims are permanent records. Values are corrected via supersession: a new Claim is created with `superseded_by_claim_id` pointing to the prior Claim; the prior Claim's `dispute_status` transitions to `superseded`.
- The superseding party must hold authority for the relevant action type (e.g., `assert_preferred_name`, `assert_legal_name`) for the subject entity.
- A steward may supersede a steward-submitted Claim. A subject may supersede their own `subject_submission` Claims. A steward may supersede a family or contributor submission, but may not supersede a subject's submission on subject-controlled attributes without an applicable ApprovalPolicy requiring escalation.
- A subject may supersede a steward's claim about subject-controlled identity attributes (preferred name, pronouns, gender descriptor, birth name).

**Review status promotion:**
- `pending` → `human_reviewed`: any user with an applicable authority assignment for the relevant action type. Steward may promote steward-scoped Claims.
- `human_reviewed` → `policy_approved`: requires an ApprovalRecord confirming the applicable ApprovalPolicy threshold was met.
- AI-generated Claims (`ai_generated = true`) may never be promoted to `policy_approved` by the AI that generated them. A human review step is always required.
- A Claim may not be used as the basis for a consequential action unless its `review_status = policy_approved` for that action type.

**Evidence status promotion:**
- AI agents may set `evidence_status` up to `inferred`. They may not set `supported` or `corroborated`.
- Elevation from `inferred` → `supported` or `corroborated` requires human approval under the applicable ApprovalPolicy.

**Dispute:**
- Any party with standing (subject, steward, or any user with `authority_basis_type` relevant to the claim) may initiate a dispute.
- Transitioning `dispute_status` to `disputed` or `contradicted` requires a corresponding ContestRecord. A Claim may not carry `dispute_status = disputed` or `contradicted` without a linked ContestRecord.
- AI must not independently change `dispute_status`. AI may flag a potential contradiction; the flag creates a review task, not a dispute transition.
- `dispute_status = retracted` is set by the original asserting party only.

**Archival:**
- Claims are not deleted. `dispute_status = retracted` or `superseded` is the effective archival state.
- The combination of `superseded_by_claim_id IS NOT NULL` and `dispute_status = superseded` marks a Claim as replaced.

### 1.2 Enforcement Strategy (Layer 2)

| Rule | Primary Mechanism | Defense-in-Depth |
|---|---|---|
| At least one value field present | CHECK constraint on `claims` table | — |
| `ai_generated = true` requires `producing_agent_code` and `context_manifest_id` | CHECK constraint | — |
| `review_status = pending` at creation for AI/system origins | CHECK constraint: `submission_origin IN ('ai_extracted_submission', 'system_inferred_submission')` → `review_status = 'pending'` | Application |
| `evidence_status` may not exceed `inferred` at creation for AI origins | Application | CHECK constraint (partial) |
| AI may not promote `review_status` to `policy_approved` | RLS: deny UPDATE of `review_status` to `policy_approved` where `ai_generated = true` without ApprovalRecord | Application |
| `dispute_status = disputed / contradicted` requires ContestRecord | Trigger: BEFORE UPDATE on `claims.dispute_status` | Application |
| AI may not independently change `dispute_status` | RLS: deny `dispute_status` UPDATE by agent service role | Application |
| Claims are permanent records; no DELETE | RLS: DELETE denied for all roles | — |
| Supersession requires authority for the action type | Application (authority assignment lookup) | — |
| `review_status → policy_approved` requires ApprovalRecord | Application (ApprovalRecord existence check before UPDATE) | — |

### 1.3 SQL Mapping (Layer 3)

| Rule | Migration | Type |
|---|---|---|
| At-least-one-value CHECK constraint | 0003 | Schema |
| `ai_generated` fields CHECK | 0003 | Schema |
| review_status/origin CHECK constraint | 0003 | Schema |
| AI promotion RLS | 0003 | RLS |
| dispute_status ContestRecord trigger | 0003 | Trigger (BEFORE UPDATE) |
| AI dispute_status RLS | 0003 | RLS |
| DELETE denied RLS | 0003 | RLS |
| Supersession authority enforcement | Application | Application |
| `policy_approved` ApprovalRecord check | Application | Application |

---

## 2. Relationship Governance

### 2.1 Governance Rules (Layer 1)

**Creation:**
- Any authenticated user with steward or subject authority over the relevant LifeBook may assert a Relationship.
- `relationship_type_id` must reference a governed RelationshipType.
- Relationships have `review_status`, `dispute_status`, `submission_origin`, and `access_classification`. Same baseline rules as Claims for AI and system submissions.

**Versioning (DP Decision — Option B approved):**
- Relationships follow the same historical model as Claims. The `relationships` table carries `superseded_by_relationship_id UUID NULL REFERENCES relationships(id)` as an inline nullable self-FK.
- Relationships are superseded rather than overwritten. The superseding party creates a new Relationship record; the prior record's `dispute_status` transitions to `superseded`.
- No in-place mutation of Relationship content is permitted once a record has governance standing.

**Dispute:**
- Same rules as Claim dispute: `dispute_status = disputed / contradicted` requires ContestRecord.
- AI may not independently change `dispute_status`.

**Display:**
- Nullable `display_policy_id` FK → `display_policies`. If no policy exists, record-type defaults apply.

### 2.2 Enforcement Strategy (Layer 2)

| Rule | Primary Mechanism | Defense-in-Depth |
|---|---|---|
| Valid `relationship_type_id` | FK constraint | — |
| review_status/origin baseline rules | Same as Claims (CHECK + RLS) | — |
| dispute_status requires ContestRecord | Trigger: BEFORE UPDATE (same as Claims) | Application |
| `superseded_by_relationship_id` inline self-FK | Schema (nullable FK) | — |
| DELETE denied | RLS | — |

### 2.3 SQL Mapping (Layer 3)

| Rule | Migration | Type |
|---|---|---|
| `superseded_by_relationship_id` inline self-FK | 0003 | Schema |
| review_status/origin CHECK | 0003 | Schema |
| dispute_status trigger (same as Claims) | 0003 | Trigger (BEFORE UPDATE) |
| LifeBook-scoped RLS | 0003 | RLS |
| DELETE denied | 0003 | RLS |

---

## 3. Narrative Governance

### 3.1 Governance Rules (Layer 1)

**Creation:**
- Any authenticated user with contributor or higher authority over the LifeBook may create a Narrative.
- `narrative_type = community_account` requires prior community authorization; creation is deploy-disabled until community authorization mechanism is designed.
- AI-composed Narratives follow the same AI submission rules as Claims.

**Composition authority:**
- `composed_by_entity_id` records the entity who composed the narrative (not the user who entered it). The four-identity model must be preserved: the entering user (`created_by_id`), the storyteller (`composed_by_entity_id`), and the subject are distinct fields.

**NarrativeEntity:**
- Each NarrativeEntity record links a Narrative to a referenced Entity.
- `is_restricted_mention`: a Boolean flag indicating that the entity's mention in this narrative is restricted. Governed by the entity's DisplayPolicy, not the Narrative's.
- A NarrativeEntity with `is_restricted_mention = true` must be excluded from any display context that is not explicitly permitted by the entity's active DisplayPolicy.

**Review and display:**
- Same review_status promotion rules as Claims.
- Community account narratives must not be displayed without explicit community authorization even if `review_status = policy_approved`.
- Narrative `access_classification = culturally_governed` subjects all display decisions to cultural governance rules (§11).

**Parent/child narratives:**
- `parent_narrative_id` creates a hierarchy. A translation Narrative must have `translation_metadata` populated (CHECK constraint).

### 3.2 Enforcement Strategy (Layer 2)

| Rule | Primary Mechanism | Defense-in-Depth |
|---|---|---|
| Community account creation gate | Deploy-disabled (RLS deny-all on INSERT for `narrative_type = community_account`) | Application |
| Translation metadata present when `parent_relationship = translation` | CHECK constraint | — |
| `is_restricted_mention` respected | Application (display layer) | DisplayPolicy evaluation |
| AI restrictions (same as Claims) | RLS + CHECK | Application |
| DELETE denied | RLS | — |

### 3.3 SQL Mapping (Layer 3)

| Rule | Migration | Type |
|---|---|---|
| Translation metadata CHECK | 0003 | Schema |
| Community account deny-all INSERT RLS | 0003 | RLS |
| AI restrictions | 0003 | RLS + Schema |
| DELETE denied | 0003 | RLS |

---

## 4. Source Governance

### 4.1 Governance Rules (Layer 1)

**Scoping:**
- Every Source has exactly one home LifeBook (`lifebook_id` NOT NULL). This is an architectural constant (P6). A Source may be used by other LifeBooks only through a `LifeBookSourceAccess` record backed by a `CrossLifeBookAuthorization`.

**DNA analysis sources:**
- Any Source with `source_type = dna_analysis` must be set to `access_classification = restricted` at creation time. This is mandatory, not advisory.
- DNA sources are additionally governed by §11 (Cultural Governance) if the subject is Indigenous.

**Provenance protection:**
- A Source's `lifebook_id` is immutable after creation. Reassigning a Source to a different LifeBook is not permitted in V1.
- A Source's `source_type` is immutable after creation (changing the type would change the governance rules that were applied at creation).
- `created_by_id` is SET NULL if a user profile is deleted (never CASCADE DELETE per constraint 11.8).

**Cross-LifeBook access:**
- `LifeBookSourceAccess` records are the only mechanism for cross-LifeBook source use.
- Revocation of the backing `CrossLifeBookAuthorization` triggers an `AccessPolicyChangedEvent` which invalidates related `SourceDerivative` records.

**Deletion:**
- Sources are permanent records. No DELETE permitted.

### 4.2 Enforcement Strategy (Layer 2)

| Rule | Primary Mechanism | Defense-in-Depth |
|---|---|---|
| `lifebook_id` NOT NULL | Schema (NOT NULL constraint) | — |
| DNA analysis → `access_classification = restricted` | Trigger: BEFORE INSERT on `sources` where `source_type = dna_analysis` | CHECK constraint |
| `source_type` immutable after creation | Trigger: BEFORE UPDATE reject `source_type` change | — |
| `lifebook_id` immutable after creation | Trigger: BEFORE UPDATE reject `lifebook_id` change | — |
| Cross-LifeBook requires LifeBookSourceAccess | Application (access query enforces join) | RLS |
| DELETE denied | RLS | — |

### 4.3 SQL Mapping (Layer 3)

| Rule | Migration | Type |
|---|---|---|
| NOT NULL `lifebook_id` | 0003 | Schema |
| DNA classification trigger | 0003 | Trigger (BEFORE INSERT) |
| Source_type immutability trigger | 0003 | Trigger (BEFORE UPDATE) |
| lifebook_id immutability trigger | 0003 | Trigger (BEFORE UPDATE) |
| Cross-LifeBook access RLS | 0003 | RLS |
| DELETE denied | 0003 | RLS |

---

## 5. Artifact Governance

### 5.1 Governance Rules (Layer 1)

**Creation:**
- Any user with steward or contributor authority over the LifeBook may create an Artifact record.
- `file_storage_reference_id` may be NULL initially (artifact record created before file is uploaded) or set at creation.

**Access classification:**
- Artifacts with `access_classification = culturally_governed` are subject to cultural governance exclusion rules (§11). Access is denied by default for all display contexts unless an active DisplayPolicy with an explicit allow rule exists.
- Artifacts with `access_classification = restricted` are accessible only to steward and admin roles.

**File storage:**
- Signed URLs for file access must be generated only after policy evaluation against the artifact's `access_classification` and `display_policy_id`. The `file_storage_reference_id.object_key` must never be exposed directly.
- Generating a signed URL is a policy-evaluated action, not a direct read.

**Culturally governed artifacts:**
- See §11. Cultural authority co-authorization is required before a culturally governed artifact may be accessed by any party other than the cultural authority.

**Deletion:**
- Artifact records are permanent. `file_storage_reference_id` may be set NULL (file removed) but the Artifact record is retained.

### 5.2 Enforcement Strategy (Layer 2)

| Rule | Primary Mechanism | Defense-in-Depth |
|---|---|---|
| Culturally governed access default deny | RLS: LifeBook-scoped + access_classification filter | DisplayPolicy evaluation |
| Restricted access limited to steward/admin | RLS: role-based filter | — |
| Signed URL requires policy evaluation | Application (SECURITY DEFINER function for signed URL generation) | — |
| `object_key` never exposed directly | Application (no `object_key` in any public SELECT grant) | RLS column restriction |
| DELETE denied | RLS | — |

### 5.3 SQL Mapping (Layer 3)

| Rule | Migration | Type |
|---|---|---|
| LifeBook-scoped + access_classification RLS | 0003 | RLS |
| Restricted access RLS | 0003 | RLS |
| Signed URL generation | Application + SECURITY DEFINER function | Hybrid |
| DELETE denied | 0003 | RLS |

---

## 6. Event Governance

### 6.1 Governance Rules (Layer 1)

**Authorship:**
- Events may be manually authored by any steward or authorized contributor.
- Events may be system-generated from Claims with `generates_event_type` non-null, after the triggering Claim has reached `review_status = policy_approved` and a manual review step confirms the Event creation is warranted. The Event creation is not automatic.

**Generated Events — workflow:**
- A Claim with `generates_event_type` non-null does not automatically create an Event. The field identifies the governed event type that *may* be generated.
- The workflow: (1) Claim reaches `policy_approved`, (2) an authorized user or steward reviews the Claim and decides to generate the Event, (3) an Event record is created with `submission_origin = steward_submission` or `authorized_representative_submission` and `source_claim_id` set to the generating Claim's UUID (DP Decision, 2026-07-25).
- AI agents may not directly create Event records from Claims. AI may flag that an Event is warranted; creation requires a human action.

**Review:**
- Events carry `review_status`, `dispute_status`, and `submission_origin`. Same promotion rules as Claims apply.

**EventParticipant:**
- Each EventParticipant links an Entity to an Event with a `participation_role`.
- EventParticipant carries a nullable `display_policy_id`. Restricting an individual's participation record is governed by their DisplayPolicy.

### 6.2 Enforcement Strategy (Layer 2)

| Rule | Primary Mechanism | Defense-in-Depth |
|---|---|---|
| AI may not directly create Event records | RLS: deny INSERT for agent service role | Application |
| Event from Claim requires policy_approved Claim | Application (checks review_status before creating Event) | — |
| `source_claim_id` records generating Claim provenance | Schema (inline nullable FK → claims(id)) | — |
| review_status/origin baseline rules | Same as Claims (CHECK + RLS) | — |
| DELETE denied | RLS | — |

### 6.3 SQL Mapping (Layer 3)

| Rule | Migration | Type |
|---|---|---|
| `source_claim_id UUID NULL REFERENCES claims(id)` | 0003 | Schema (inline FK) |
| AI INSERT deny RLS | 0003 | RLS |
| review_status/origin CHECK | 0003 | Schema |
| DELETE denied | 0003 | RLS |

---

## 7. DisplayPolicy Governance

This section documents enforcement architecture for DisplayPolicy. The design is complete and approved (DISPLAY_POLICY_MODEL.md v0.1). Do not redesign.

### 7.1 Governance Rules (Layer 1)

**Who may create a DisplayPolicy:**
- Any user holding a valid `authority_roles.code` value in `set_by_role` for the applicable governed record type.
- Subject may create policies on subject-controlled records (`subject` role).
- Steward may create policies on records within steward authority scope.
- Cultural authority may create policies on culturally governed records.
- `approval_record_id` is required by governance rules for specific scenarios (steward modifying a record the subject controls; cultural authority setting policy; override of a default restrictive policy for a sensitive record type).

**Activation:**
- The application transitions `display_policies.status` from `draft` to `active` after all preconditions are met (approval record obtained if required; rules created).
- A policy has no governance standing until status = `active`.

**Versioning:**
- The application creates a successor policy (new record in draft), creates successor rules, attaches the successor to the governed record, transitions the predecessor to `superseded`, then activates the successor.
- The governed record always holds the UUID of the current active policy.

**Immutability:**
- Active, superseded, and withdrawn DisplayPolicy records and their rules are immutable.
- Draft records are editable and deletable.

**Lifecycle transitions permitted by triggers:**
- draft → active: permitted (application initiates UPDATE on status)
- active → superseded: permitted (status-only UPDATE by application during versioning workflow)
- active → withdrawn: permitted (status-only UPDATE by application)
- All other updates to active/superseded/withdrawn records: rejected by trigger
- DELETE on non-draft records: rejected by trigger and RLS

### 7.2 Enforcement Strategy (Layer 2)

| Rule | Primary Mechanism | Defense-in-Depth |
|---|---|---|
| Immutability of active/superseded/withdrawn policies | Trigger: BEFORE UPDATE on `display_policies` (enforce status transition rules; reject all other updates) | RLS: deny UPDATE where status IN ('superseded', 'withdrawn') |
| Immutability of rules belonging to non-draft policies | Trigger: BEFORE UPDATE / BEFORE DELETE on `display_policy_rules` | — |
| Draft DELETE only | Trigger: BEFORE DELETE on `display_policies` — reject if status != 'draft' | RLS: deny DELETE where status IN ('active', 'superseded', 'withdrawn') |
| `display_context_code` is governed | FK → `display_contexts(code)` ON UPDATE RESTRICT ON DELETE RESTRICT | — |
| UNIQUE context per policy | UNIQUE (display_policy_id, display_context_code) | — |
| Provenance: at least one of `created_by_id` or `created_by_system` | CHECK constraint | — |
| INSERT authority validation | RLS: INSERT permitted per `set_by_role` and applicable authority rules | Application |
| Condition schema consistency | CHECK: conditions IS NULL OR condition_schema_version IS NOT NULL | — |
| V1 condition type restriction | CHECK: conditions type IN closed set | — |

### 7.3 SQL Mapping (Layer 3)

| Rule | Migration | Type |
|---|---|---|
| BEFORE UPDATE trigger on `display_policies` | 0003 | Trigger |
| BEFORE DELETE trigger on `display_policies` | 0003 | Trigger |
| BEFORE UPDATE trigger on `display_policy_rules` | 0003 | Trigger |
| BEFORE DELETE trigger on `display_policy_rules` | 0003 | Trigger |
| display_context_code FK | 0003 | Schema |
| UNIQUE constraint | 0003 | Schema |
| Provenance CHECK | 0003 | Schema |
| INSERT RLS for display_policies | 0003 | RLS |
| Condition CHECK constraints | 0003 | Schema |

### 7.4 Application Responsibilities

The application manages the policy versioning workflow. The database does not implement these steps — it only enforces the invariants that prevent incorrect outcomes:
- Create successor DisplayPolicy in draft status
- Create DisplayPolicyRule records for the successor
- Update governed record's `display_policy_id` to successor UUID
- Issue UPDATE on predecessor: status → superseded
- Issue UPDATE on successor: status → active

---

## 8. ApprovalRecord Governance

### 8.1 Governance Rules (Layer 1)

**Authority:**
- An ApprovalRecord is an instance of an ApprovalPolicy being fulfilled. It records that the required approvers specified in the ApprovalPolicy have acted.
- The `required_approvers` JSONB on the applicable ApprovalPolicy specifies who must approve (named_subject, any_one_of, all_of, quorum, escalate).
- ApprovalRecords are created by the application after all required approvers have confirmed.
- The AI_PROMOTION_ANY policy requires any_one_of [steward, subject]; AI may never create its own ApprovalRecord.

**Immutability:**
- ApprovalRecords are permanent records. Once created, they are not deleted or modified.
- Revocation of an approval is recorded as a new ApprovalRecord with a `revoked_status`, not as a modification to the original.
- This ensures that records which relied on an approval at a point in time have an auditable basis.

**Revocation consequences:**
- When an ApprovalRecord that was the basis for a DisplayPolicy's `approval_record_id` is revoked, the DisplayPolicy is not automatically withdrawn. The revocation is a governance event that must trigger a human review of the dependent policy. The application is responsible for surfacing this review requirement.
- Similarly, a CrossLifeBookAuthorization backed by a revoked ApprovalRecord must be reviewed by the steward.

**Supersession:**
- When a new ApprovalRecord supersedes an older one for the same action and subject, both records are retained. The newer record governs current permissions; the older record governs the period during which it was active.

**Approval history:**
- Every consequential action (publishing, merging, cross-LifeBook sharing, AI promotion) must have an auditable ApprovalRecord chain. No consequential action may proceed without one.

### 8.2 Enforcement Strategy (Layer 2)

| Rule | Primary Mechanism | Defense-in-Depth |
|---|---|---|
| Permanent records; no DELETE | RLS: DELETE denied for all roles | — |
| No UPDATE after creation | RLS: UPDATE denied for all roles | Trigger: BEFORE UPDATE reject |
| Revocation creates new record, not modifies old | Application design | RLS (UPDATE denied prevents modification) |
| AI may not create own ApprovalRecord | Application (role check before INSERT) | RLS |
| ApprovalRecord required for consequential actions | Application (checks FK before proceeding) | FK constraint on referencing tables |

### 8.3 SQL Mapping (Layer 3)

| Rule | Migration | Type |
|---|---|---|
| DELETE denied | 0003 | RLS |
| UPDATE denied / BEFORE UPDATE trigger | 0003 | RLS + Trigger |
| ApprovalRecord NOT NULL on MergeRecord etc. | 0003 | Schema (FK NOT NULL) |

---

## 9. AuthorityAssignment Governance

### 9.1 Governance Rules (Layer 1)

**Creation:**
- AuthorityAssignments are created by stewards, administrators, or via application-layer workflows following external legal documentation.
- `authority_basis_type` and optionally `basis_claim_id` must be provided. For `self_assertion` and `policy_default`, `basis_claim_id` may be NULL.
- `basis_claim_id` references a Claim in the Claim layer (P2 compliance: documentary evidence belongs in Claim layer, not as a direct field).

**Delegation:**
- Delegation of authority to a third party is not supported in V1. An AuthorityAssignment is a direct assignment, not a delegated chain. The coordination_rule handles joint authority (joint_unanimous, joint_majority, joint_any) but does not implement delegation.

**Expiry:**
- `effective_until` is the mechanism for time-limited authority. A NULL `effective_until` means the assignment is currently active.
- An expired AuthorityAssignment (effective_until < now()) has no governance standing even if its record remains in the database.
- The application must check `effective_until` before treating an assignment as active. The schema does not automatically invalidate expired records.

**Revocation:**
- Revocation is recorded by setting `effective_until` to the revocation date. The original record is retained.
- A revoked AuthorityAssignment does not automatically revoke dependent records (e.g., an ApprovalRecord created while the authority was valid remains valid for the period it covered).
- `is_contested = true` flags the assignment as under active dispute. The associated ContestRecord governs the dispute resolution.

**Succession:**
- `succession_behaviour` governs what happens when the assignment expires or is revoked:
  - `terminate`: authority ends; steward must manually reassign
  - `transfer_to_named`: authority moves to `succession_target_id` automatically upon expiry
  - `transfer_to_steward`: authority reverts to steward
  - `transfer_to_court`: flags for external determination
  - `policy_default`: LifeBook default governance rules apply

**`basis_claim_id` deferred FK:**
- `authority_assignments.basis_claim_id → claims(id)` is a deferred FK (Deferred FK 1 in migration 0003). AuthorityAssignment is created before Claim in dependency order.

### 9.2 Enforcement Strategy (Layer 2)

| Rule | Primary Mechanism | Defense-in-Depth |
|---|---|---|
| `basis_claim_id` nullable (null for self_assertion, policy_default) | Schema (nullable FK) | — |
| Effective_until expiry check | Application (query filter on effective_until) | — |
| `is_contested` requires ContestRecord | Application constraint | — |
| Succession_behaviour enforcement | Application workflow | — |
| No delegation in V1 | Application design (no delegation FK field) | — |
| DELETE denied (permanent record) | RLS | — |

### 9.3 SQL Mapping (Layer 3)

| Rule | Migration | Type |
|---|---|---|
| Deferred FK `basis_claim_id → claims(id)` | 0003 | Schema (ALTER TABLE) |
| DELETE denied | 0003 | RLS |
| Expiry check | Application | Application |

---

## 10. AI Governance

### 10.1 Governance Rules (Layer 1)

**Creation restrictions:**
- AI agents may create: Claims (`ai_extracted_submission`), portions of Narratives, SourceDerivative content.
- AI agents may not create: Event records directly, ApprovalRecord records, AuthorityAssignment records, DisplayPolicy records, any record requiring human authorization.

**Evidence status boundary:**
- AI agents may set `evidence_status` up to `inferred`. They may not set `supported` or `corroborated`. These require human review under the applicable ApprovalPolicy.

**Review status boundary:**
- AI-generated records (`submission_origin IN ('ai_extracted_submission', 'system_inferred_submission')`) must begin at `review_status = pending`.
- AI may not promote `review_status` to `policy_approved` on any record it generated.
- AI promotion requires a human approver per the AI_PROMOTION_ANY policy (any_one_of [steward, subject]).

**Dispute status boundary:**
- AI must not independently change `dispute_status` on any record. AI may flag a potential contradiction for human review. The flag does not set `dispute_status`.

**Visibility restrictions:**
- AI context receives only records with `review_status = policy_approved` and `access_classification` that is not `restricted` or `culturally_governed`.
- AI context receives only `SourceDerivative` records with `validity_state = valid`.
- DisplayPolicy rules for `display_context_code = 'ai_generation'` govern what the AI context may receive. Default: if no policy exists, no record is included in AI context unless explicitly permitted.

**Generation restrictions:**
- AI-generated Narratives must carry `submission_origin = ai_extracted_submission`.
- `producing_agent_code` and `context_manifest_id` are required when `ai_generated = true`.
- AI may not generate content about a living subject without a `display_context_code = 'ai_generation'` ALLOW rule in the subject's applicable DisplayPolicy.

**Culturally governed exclusion:**
- Records with `access_classification = culturally_governed` are excluded from all AI context manifests.
- This is a hard exclusion. A DisplayPolicy rule cannot override this exclusion. Cultural governance takes precedence over AI generation permission. See §11.

**Audit:**
- All AI context accesses are logged via `ContextManifest`. ContextManifest records are permanent (DELETE denied for all roles).
- AccessPolicyChangedEvent triggers invalidation of SourceDerivative records that were provided to AI context under a policy that has since been revoked or changed.

### 10.2 Enforcement Strategy (Layer 2)

| Rule | Primary Mechanism | Defense-in-Depth |
|---|---|---|
| AI may not create Events directly | RLS: deny INSERT on `events` for agent service role | Application |
| AI may not create ApprovalRecords | RLS: deny INSERT on `approval_records` for agent service role | Application |
| AI submission → review_status = pending | CHECK constraint on `claims`, `narratives`, `relationships` | Application |
| AI may not promote to policy_approved | RLS: deny UPDATE of review_status = 'policy_approved' where ai_generated = true without approval | Application |
| AI may not change dispute_status | RLS: deny UPDATE of dispute_status for agent service role | Application |
| Culturally governed records excluded from AI context | RLS: query-time filter (access_classification != 'culturally_governed') applied to AI context reads | Application (Context Broker) |
| ContextManifest permanent | RLS: DELETE denied for all roles on context_manifests | — |
| SourceDerivative validity check | Application (Context Broker queries only validity_state = valid) | — |
| ai_generated = true requires producing_agent_code, context_manifest_id | CHECK constraint | Application |

### 10.3 SQL Mapping (Layer 3)

| Rule | Migration | Type |
|---|---|---|
| Agent INSERT restrictions (Events, ApprovalRecords) | 0003 | RLS |
| AI submission CHECK constraints | 0003 | Schema |
| AI promotion RLS | 0003 | RLS |
| AI dispute_status RLS | 0003 | RLS |
| Culturally governed exclusion RLS | 0003 | RLS |
| ContextManifest DELETE denied | 0003 | RLS |
| ai_generated fields CHECK | 0003 | Schema |

---

## 11. Cultural Governance

### 11.1 Governance Rules (Layer 1)

**Governed content:**
- Any record with `access_classification = culturally_governed` is subject to cultural governance rules.
- This applies across all content types: Claims, Relationships, Narratives, NarrativeEntities, Sources, Artifacts, Events, EventParticipants, and person attribute records.

**Cultural authority:**
- The `cultural_authority` role in `authority_roles` represents a community-recognized authority for cultural or ceremonial information.
- An `AuthorityAssignment` with `authority_role = cultural_authority` is required before any culturally governed content may be created, accessed, modified, or shared.
- Cultural authority is not assigned by LifeBook — it is recorded from an external community determination.

**ApprovalPolicy dimension:**
- ApprovalPolicies with `cultural_governance_required = TRUE` apply when the content is culturally governed AND the lifecycle condition matches.
- Any consequential action on culturally governed content requires an ApprovalRecord backed by a policy with `cultural_governance_required = TRUE`.

**Culturally restricted names:**
- Indigenous names and ceremonial names are managed through `PersonName` records with `usage_type IN ('indigenous', 'ceremonial')`.
- These are deferred from migration 0003 scope pending external community engagement.
- When these name types are created in a future migration, they must carry `access_classification = culturally_governed` by default.

**Culturally restricted artifacts:**
- Artifacts with `access_classification = culturally_governed` may be accessed only by parties with an active `cultural_authority` AuthorityAssignment or explicit permission from that authority.
- File storage signed URL generation for culturally governed artifacts requires cultural authority validation as a prerequisite.

**Culturally restricted narratives:**
- Community account narratives (`narrative_type = community_account`) require community authorization before creation and before display.
- This authorization is captured as an ApprovalRecord referencing an ApprovalPolicy with `cultural_governance_required = TRUE`.
- Community account narratives are deploy-disabled until the community authorization workflow is implemented.

**Exclusion rules:**
- Culturally governed records are excluded from: AI context manifests, public display contexts, ordinary search, identity resolution search, and default export.
- Exclusion is enforced by RLS at the data access layer, not only by application logic (ARCHITECTURE_FREEZE_V1.md P12 compliance).
- A DisplayPolicy `allow` rule for a governed display context may grant access to a culturally governed record for the specific context — but it cannot override the AI context exclusion or the culturally governed status itself.
- The AI context exclusion is absolute: `access_classification = culturally_governed` → excluded from all AI context, regardless of DisplayPolicy.

**Approval requirements:**
- Creating a culturally governed record: ApprovalRecord with `cultural_governance_required = TRUE` policy required.
- Accessing a culturally governed artifact's file: cultural authority validation required (application layer).
- Sharing culturally governed content cross-LifeBook: ApprovalRecord with `cultural_governance_required = TRUE` on the CrossLifeBookAuthorization.

### 11.2 Enforcement Strategy (Layer 2)

| Rule | Primary Mechanism | Defense-in-Depth |
|---|---|---|
| Culturally governed records excluded from AI context | RLS: exclude `access_classification = 'culturally_governed'` from AI context queries | Application (Context Broker) |
| Culturally governed records denied in public/search contexts | RLS: LifeBook-scoped + access_classification filter | DisplayPolicy default deny |
| Community account narrative creation gate | RLS: deny INSERT for community account type without authorization | Application |
| Cultural authority required for culturally governed access | Application (authority assignment check) | — |
| Signed URL for culturally governed artifacts | Application: cultural authority validation before URL generation | SECURITY DEFINER function |

### 11.3 SQL Mapping (Layer 3)

| Rule | Migration | Type |
|---|---|---|
| Cultural exclusion from AI context | 0003 | RLS |
| Cultural content access restriction | 0003 | RLS |
| Community account CREATE gate | 0003 | RLS |
| Cultural artifact signed URL protection | Application | SECURITY DEFINER function |

---

## 12. Dependency Table

The following table maps significant governance rules to their enforcement layer, implementation mechanism, and future SQL location.

| Governance Rule | Enforcement Layer | Implementation Mechanism | SQL Location |
|---|---|---|---|
| Claim must have at least one value field | Database schema | CHECK constraint | 0003 schema |
| AI submission → review_status = pending | Database schema | CHECK constraint | 0003 schema |
| AI records cannot promote to policy_approved | Database + Application | RLS deny UPDATE | 0003 RLS |
| dispute_status = disputed/contradicted requires ContestRecord | Database | BEFORE UPDATE trigger | 0003 trigger |
| AI may not change dispute_status | Database | RLS deny UPDATE (agent role) | 0003 RLS |
| Claim is permanent (no DELETE) | Database | RLS DELETE denied | 0003 RLS |
| DNA source → access_classification = restricted | Database | BEFORE INSERT trigger | 0003 trigger |
| Source.lifebook_id immutable | Database | BEFORE UPDATE trigger | 0003 trigger |
| Source.source_type immutable | Database | BEFORE UPDATE trigger | 0003 trigger |
| Source is permanent (no DELETE) | Database | RLS DELETE denied | 0003 RLS |
| Narrative translation_metadata required | Database schema | CHECK constraint | 0003 schema |
| Community account Narrative CREATE gate | Database | RLS deny INSERT | 0003 RLS |
| Culturally governed → excluded from AI context | Database | RLS (access_classification filter) | 0003 RLS |
| Culturally governed → default deny all display | Database | RLS | 0003 RLS |
| DisplayPolicy immutability (active/superseded/withdrawn) | Database | BEFORE UPDATE trigger + RLS | 0003 trigger + RLS |
| DisplayPolicyRule immutability (non-draft parent) | Database | BEFORE UPDATE/DELETE trigger | 0003 trigger |
| DisplayPolicy draft DELETE only | Database | BEFORE DELETE trigger + RLS | 0003 trigger + RLS |
| display_context_code governed vocabulary | Database schema | FK ON UPDATE RESTRICT ON DELETE RESTRICT | 0003 schema |
| UNIQUE (display_policy_id, display_context_code) | Database schema | UNIQUE constraint | 0003 schema |
| ApprovalRecord is permanent (no DELETE, no UPDATE) | Database | RLS DELETE denied + UPDATE denied | 0003 RLS |
| ContextManifest is permanent (no DELETE) | Database | RLS DELETE denied | 0003 RLS |
| AccessPolicyChangedEvent is permanent (no DELETE) | Database | RLS DELETE denied | 0003 RLS |
| AuthorityAssignment.basis_claim_id deferred FK | Database schema | ALTER TABLE deferred FK | 0003 schema (deferred) |
| display_policies.approval_record_id deferred FK | Database schema | ALTER TABLE deferred FK | 0003 schema (deferred) |
| ai_generated = true requires producing_agent_code, context_manifest_id | Database schema | CHECK constraint | 0003 schema |
| LifeBook-scoped content tables | Database | RLS (lifebook_id filter) | 0003 RLS |
| Numeric claim unit enforcement | Database | BEFORE INSERT/UPDATE trigger | 0003 trigger |
| LifeBookPersonContext completeness invariant | Database | Deferred constraint trigger | 0003 trigger |
| Subject authority overrides steward on subject-controlled attributes | Governance + Application | Application (authority lookup) | Application |
| Cultural authority required for culturally governed ApprovalRecord | Governance + Application | Application (policy lookup) | Application |
| AI may not create Events directly | Database | RLS deny INSERT (agent role) | 0003 RLS |
| AI may not create ApprovalRecords | Database | RLS deny INSERT (agent role) | 0003 RLS |
| Relationship versioning via superseded_by_relationship_id | Database schema | Inline nullable self-FK | 0003 schema |
| Event provenance via source_claim_id | Database schema | Inline nullable FK → claims(id) | 0003 schema |
| ContestRecord governed standing | Database + Governance | RLS INSERT rules + governance policy lookup | 0003 RLS |

---

## 13. Required RLS Policies

The following RLS policies must be designed in VOCABULARY_RLS_MATRIX.md before SQL is written for migration 0003. Each is identified by governed table and rule type. Policies are not written here.

### Content table LifeBook-scoped access (one per table)
1. `claims` — LifeBook-scoped: only users with LifeBook membership may read
2. `relationships` — LifeBook-scoped
3. `narratives` — LifeBook-scoped
4. `narrative_entities` — LifeBook-scoped via Narrative
5. `sources` — LifeBook-scoped (lifebook_id NOT NULL)
6. `artifacts` — LifeBook-scoped
7. `events` — LifeBook-scoped
8. `event_participants` — LifeBook-scoped via Event
9. `claim_evidence` — LifeBook-scoped via Claim + Source
10. `artifact_source_links` — LifeBook-scoped via Artifact + Source

### Permanent record DELETE denied
11. `claims` — DELETE denied for all roles
12. `narratives` — DELETE denied for all roles
13. `sources` — DELETE denied for all roles
14. `artifacts` — DELETE denied for all roles (record retained even if file removed)
15. `relationships` — DELETE denied for all roles
16. `events` — DELETE denied for all roles
17. `approval_records` — DELETE denied for all roles
18. `context_manifests` — DELETE denied for all roles
19. `access_policy_changed_events` — DELETE denied for all roles
20. `authority_assignments` — DELETE denied for all roles

### AI submission restrictions
21. `claims` — AI promotion restriction: deny UPDATE of `review_status` to `policy_approved` where `ai_generated = true` without valid ApprovalRecord
22. `claims` — AI dispute restriction: deny UPDATE of `dispute_status` for agent service role
23. `narratives` — Same AI promotion restriction
24. `events` — deny INSERT for agent service role
25. `approval_records` — deny INSERT for agent service role

### Culturally governed content
26. `claims` — exclude `access_classification = culturally_governed` from AI context reads
27. `narratives` — exclude culturally governed from AI context reads
28. `artifacts` — exclude culturally governed from AI context reads; default deny all non-steward access for culturally governed
29. `sources` — exclude culturally governed from AI context reads
30. `narratives` — deny INSERT for `narrative_type = community_account` without authorization

### Access classification filtering
31. `artifacts` — restricted access limited to steward and admin roles
32. `entity_match_candidates` — steward + system only; deny non-steward access
33. `sources` — DNA analysis: trigger-enforced at INSERT, but RLS also restricts read to appropriate roles

### DisplayPolicy lifecycle
34. `display_policies` — DELETE denied for all roles where `status IN ('active', 'superseded', 'withdrawn')`
35. `display_policies` — UPDATE denied for all roles where `status IN ('superseded', 'withdrawn')` (active record transitions handled by trigger)
36. `display_policies` — INSERT restricted: permitted only for roles that can hold valid `set_by_role` authority for the relevant record type
37. `display_policy_rules` — DELETE denied where parent policy `status != 'draft'`

### ApprovalRecord immutability
38. `approval_records` — UPDATE denied for all roles

---

## 14. Required Triggers

The following triggers must be designed in VOCABULARY_RLS_MATRIX.md before SQL is written. Triggers are not written here. Each is identified by table, timing, and invariant enforced.

### Content triggers
1. `claims` — BEFORE INSERT: validate at-least-one-value rule
2. `claims` — BEFORE INSERT/UPDATE: validate `ai_generated = true` requires `producing_agent_code` and `context_manifest_id`
3. `claims` — BEFORE INSERT: enforce `review_status = pending` for AI/system origins (`CHECK` handles this, but trigger handles edge cases)
4. `claims` — BEFORE UPDATE: enforce `dispute_status = disputed / contradicted` only when ContestRecord exists (`trg_claim_dispute_requires_contest_record`)
5. `claims` — BEFORE INSERT/UPDATE: enforce numeric unit check (`trg_claim_numeric_unit_check` — already defined in CONTENT_LAYER.md §3.5)

### Source triggers
6. `sources` — BEFORE INSERT: enforce `source_type = dna_analysis` → `access_classification = restricted` (`trg_source_dna_classification`)
7. `sources` — BEFORE UPDATE: reject changes to `source_type` (`trg_source_type_immutable`)
8. `sources` — BEFORE UPDATE: reject changes to `lifebook_id` (`trg_source_lifebook_immutable`)

### DisplayPolicy triggers
9. `display_policies` — BEFORE UPDATE: enforce status transition rules; reject all non-status updates on non-draft records (`trg_display_policies_lifecycle`)
10. `display_policies` — BEFORE DELETE: reject DELETE where `status != 'draft'` (`trg_display_policies_delete_guard`)
11. `display_policy_rules` — BEFORE UPDATE: reject UPDATE where parent policy `status != 'draft'` (`trg_display_policy_rules_update_guard`)
12. `display_policy_rules` — BEFORE DELETE: reject DELETE where parent policy `status != 'draft'` (`trg_display_policy_rules_delete_guard`)

### ApprovalRecord triggers
13. `approval_records` — BEFORE UPDATE: reject all UPDATEs (`trg_approval_records_immutable`)

### Governance triggers
14. `lifebook_entities` — AFTER INSERT: deferred constraint trigger verifying every person-type LifeBookEntity has a LifeBookPersonContext (`trg_lifebook_person_context_completeness`)

### Audit / invalidation
15. `source_derivatives` — AFTER UPDATE on `validity_state`: trigger AccessPolicyChangedEvent creation when a SourceDerivative is invalidated, or when an AccessPolicyChangedEvent requires cascading invalidation of all valid SourceDerivatives that were provided under the changed policy (`trg_source_derivative_invalidation_cascade`) — this trigger's exact design requires the Context Broker implementation to be specified; flag as a hybrid trigger/application responsibility

---

## 15. Resolved Blockers

The following three items were open at v0.1 and are now resolved by DP decision (2026-07-25).

### Blocker 1 — Relationship versioning model — RESOLVED

**DP Decision:** Approve Option B. Relationships follow the same historical model as Claims. Add `superseded_by_relationship_id UUID NULL` as an inline nullable self-FK to the `relationships` table. Relationships are superseded rather than overwritten.

**Schema consequence:** `superseded_by_relationship_id UUID NULL REFERENCES relationships(id)` added to the `relationships` table in migration 0003. Inline self-reference; not a deferred FK.

**Governance consequence:** Relationship governance now fully mirrors Claim governance. Historical Relationship records are permanent. Supersession creates a successor record; the predecessor's `dispute_status` transitions to `superseded`. No in-place mutation.

**Previous status:** Blocked `relationships` DDL and RLS. **Now unblocked.**

---

### Blocker 2 — Claim → Event back-reference — RESOLVED

**DP Decision:** Approve the recommendation. Add `source_claim_id UUID NULL` to `events`. This nullable FK references `claims(id)` and records the originating Claim whenever an Event is generated from a Claim. Manually authored Events leave this field NULL.

**Schema consequence:** `source_claim_id UUID NULL REFERENCES claims(id)` added to the `events` table in migration 0003. Inline nullable FK; not deferred (Claims are created in Batch 7.1, Events in Batch 7.10).

**Governance consequence:** Every Event generated from a governed Claim carries an auditable provenance back-reference. The originating Claim is traceable. Manually authored Events have no generating Claim.

**Previous status:** Blocked `events` DDL. **Now unblocked.**

---

### Blocker 3 — ContestRecord standing — RESOLVED

**DP Decision:** Approve the governed-standing model. Standing is determined by governance rules rather than RLS alone. RLS enforces standing; it does not define it. The seven recognized standing classes are:

1. **Subject** — the person the contested record is about
2. **Steward** — the LifeBook steward for the relevant LifeBook
3. **Asserting party** — the entity that created the contested record
4. **Affected party** — an entity directly named or referenced in the contested record
5. **Delegated authority** — a party holding an active AuthorityAssignment with a relevant action type for the record type
6. **Cultural authority** — a party holding an active `cultural_authority` AuthorityAssignment (applicable to culturally governed records)
7. **Review authority** — a party holding an active AuthorityAssignment with `review_authority` scope

**Schema consequence:** No new fields required. Standing classes are enforced at the RLS INSERT layer on `contest_records`. The ContestRecord must carry the `standing_class` of the initiating party as a governed field (enum or text FK to a reference table — to be specified in VOCABULARY_RLS_MATRIX.md).

**Governance consequence:** The `trg_claim_dispute_requires_contest_record` trigger design is now complete. The trigger validates that the ContestRecord exists and that the initiating party had recognized standing before allowing `dispute_status` to transition.

**Previous status:** Blocked ContestRecord INSERT RLS and `trg_claim_dispute_requires_contest_record`. **Now unblocked.**

---

## 16. Final Assessment — Updated

**Question:** After all DP decisions, will every remaining SQL implementation decision be architectural, or purely mechanical?

**Answer:** Purely mechanical. No architectural blockers remain.

### All content table governance is complete:

- **Claims:** table DDL, triggers, RLS — all rules specified
- **Relationships:** table DDL includes `superseded_by_relationship_id`; governance mirrors Claims; RLS rules specified
- **Narratives / NarrativeEntities:** governance rules, triggers, RLS — specified
- **Sources:** governance rules, triggers, RLS — specified
- **Artifacts:** governance rules, RLS — specified
- **Events:** table DDL includes `source_claim_id`; governance rules, RLS — specified
- **EventParticipants:** governance via parent Event — specified
- **display_policies / display_policy_rules:** fully designed (DISPLAY_POLICY_MODEL.md v0.1); triggers and RLS specified
- **ApprovalRecords:** immutability rules, RLS — specified
- **AuthorityAssignments:** governance rules, RLS — specified
- **ContestRecords:** standing model resolved; INSERT RLS and trigger design unblocked

### Architecture phase is complete:

After the RLS design session (VOCABULARY_RLS_MATRIX.md), all remaining work is implementation only:

- Migration 0002 SQL: enum DDL + `display_contexts` table + 9 seed records
- Migration 0003 SQL: all table DDL, constraints, deferred FKs, triggers, RLS policies, seed data, validation
- Testing and validation

No further architecture sessions are required.

---

## 17. Architectural Invariants

These are the fundamental principles that all future schema, RLS policies, triggers, and application workflows must preserve. They are architectural principles, not implementation requirements. Any future schema change, migration, or feature addition that would violate these invariants requires an explicit architectural decision and a new ADR.

### Invariant 1 — Governance records become permanent upon activation

A record that has entered an active governance state (status = active, review_status = policy_approved, or any equivalent activation state) becomes a permanent governance record. It may not be deleted, overwritten, or retroactively modified. The historical record must be preserved intact.

### Invariant 2 — Historical assertions are superseded rather than overwritten

When a governed assertion (Claim, Relationship, DisplayPolicy, or other versioned record) is corrected or replaced, the correction is achieved by creating a new record and marking the prior record as superseded. In-place mutation of the prior record's content is never permitted. The complete history of every assertion must be recoverable.

### Invariant 3 — Generated Events retain provenance

When an Event is generated from a Claim, the Event must carry a durable, structural reference to its originating Claim (`source_claim_id`). Provenance must be schema-enforced, not application-convention. Manually authored Events that have no generating Claim are not required to carry provenance.

### Invariant 4 — Governed actions require accountable authority

Every consequential governance action (creating or modifying a DisplayPolicy, approving an AI-generated record, publishing a living subject's record, cross-LifeBook sharing, merging, archiving) must be traceable to an authority holder whose assignment was active at the time of the action. No consequential action may proceed anonymously or without a valid AuthorityAssignment.

### Invariant 5 — DisplayPolicy evaluation is fail-closed

When a DisplayPolicy is absent, revoked, expired, or inapplicable to the requested display context, the result is denial. The absence of a policy is never interpreted as permission. All display defaults must be restrictive. An explicit allow rule is required for access to be granted.

### Invariant 6 — AI cannot bypass governance

AI agents may not create or modify records in ways that bypass the governance layer. AI-generated content begins at the lowest trust tier (`evidence_status = unreviewed`, `review_status = pending`) and may only be elevated through human-reviewed, policy-approved processes. AI agents may not self-approve, self-promote, or create records that require human authorization.

### Invariant 7 — Cultural governance overrides AI

Records with `access_classification = culturally_governed` are excluded from all AI context manifests without exception. No DisplayPolicy rule, application configuration, or operational override may supersede this exclusion. Cultural governance of Indigenous content takes precedence over any AI access or generation capability.

### Invariant 8 — Approvals remain historically traceable

Every ApprovalRecord is a permanent record of a governance event at a point in time. Revocation does not delete the original approval — it creates a new record. Any record that relied on an approval at the time of creation retains its auditable basis even if the approval is later revoked. The historical governance chain must be reconstructable from the database alone.

### Invariant 9 — Permanent records preserve immutable provenance

Every permanent record must carry non-nullable provenance: at minimum, the creator identity (`created_by_id` or `created_by_system`) and creation timestamp (`created_at`). For AI-generated records, `producing_agent_code` and `context_manifest_id` are additionally required. Provenance fields may never be set NULL after record creation.

---

*No SQL has been written. No RLS has been written. No triggers have been written. This document is the architectural input to VOCABULARY_RLS_MATRIX.md and to all migration 0002 and 0003 SQL authoring. Architecture phase is complete. SQL authoring remains unauthorized until the RLS design session is complete.*
