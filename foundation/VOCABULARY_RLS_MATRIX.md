# Vocabulary RLS Matrix
**Version:** 3.0  
**Status:** Implementation specification complete — approved for Migration 0002 and 0003 SQL authoring  
**Produced:** 2026-07-25  
**Produced by:** Discovery Partner + Claude (implementation specification session)  
**Supersedes:** v2.0 (pre-approval draft 2026-07-23)  
**Input documents:** GOVERNANCE_ENFORCEMENT_MODEL.md v0.2 · DISPLAY_POLICY_MODEL.md v0.1 · CONTENT_LAYER.md · SCHEMA_INVENTORY.md · MIGRATION_0003_PROPOSAL.md  
**Output target:** Migration 0003 SQL — RLS policies, triggers, helper functions, grants

---

## How to Read This Document

This document converts the approved governance architecture into implementation-ready specifications. It does not write SQL. Every policy, trigger, and helper function identified here must be implemented in the order specified in §9 before migration 0003 is considered complete.

**Actor classes used throughout:**
- `steward` — authenticated user with `steward` membership role in the LifeBook
- `contributor` — authenticated user with `contributor` membership role
- `viewer` — authenticated user with `viewer` membership role
- `subject` — authenticated user whose `user_person_links` record points to the entity in question
- `cultural_authority` — user holding an active `cultural_authority` AuthorityAssignment for the relevant record
- `agent_service` — AI agent connecting under the dedicated agent database role
- `system_service` — background service connecting under the system database role
- `admin` — platform administrator role

**Fail-closed:** Where not explicitly overridden, the default answer to any access question is **deny**.

---

## §1. Table-by-Table RLS Matrix

For each table, each operation row specifies: permitted actors, authority requirements, approval requirements, DisplayPolicy interaction, cultural governance, AI restrictions, fail-closed behaviour, primary enforcement mechanism, helper function required.

---

### 1.1 `claims`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward, contributor, viewer (LifeBook-scoped); subject (own claim); agent_service (restricted context) | LifeBook membership OR subject link | None to read; policy_approved required for AI context | Evaluated against display context; absent policy → deny for public/export contexts | Excluded from AI context; steward-only for culturally governed | Agent reads only policy_approved + non-culturally-governed records in ai_generation context | Yes | RLS (LifeBook scope + access_classification filter) | `fn_lb_membership_role` |
| INSERT | steward, contributor, subject (own LifeBook); agent_service (ai_extracted_submission only) | LifeBook membership (contributor or higher) OR subject link | None at creation; ai_generated = true triggers review_status = pending | Not evaluated at INSERT | Agent may not INSERT with access_classification = culturally_governed | Agent INSERT restricted to ai_extracted_submission; review_status must = pending | Yes | RLS + CHECK constraint | `fn_lb_membership_role` |
| UPDATE | steward (status fields only); subject (dispute_status on own claims); human users only for review_status → policy_approved | LifeBook membership (steward) OR subject link | policy_approved promotion requires valid ApprovalRecord linked externally | Not re-evaluated at UPDATE | Cultural authority required for UPDATE on culturally governed claims | Agent may not UPDATE dispute_status or review_status | Yes | RLS (UPDATE) + trigger (field immutability) | `fn_lb_membership_role`, `fn_user_is_agent` |
| DELETE | No actor | — | — | — | — | — | Yes — deny all | RLS DELETE denied | — |

**Notes:**
- Content fields (predicate_id, value_text, value_date, value_numeric, object_entity_id) are immutable after INSERT. The trigger `trg_claim_content_immutable` rejects any UPDATE that changes these fields.
- `superseded_by_claim_id` may only be set once (NULL → non-NULL) and only when the referenced claim exists. Trigger enforces.
- `review_status → policy_approved` is never permitted when `ai_generated = true` without an ApprovalRecord. RLS enforces via `fn_user_is_agent` + ApprovalRecord check.

---

### 1.2 `relationships`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward, contributor, viewer (LifeBook-scoped); agent_service (restricted context) | LifeBook membership | None | Evaluated for display context | Excluded from AI context if culturally governed | Agent reads only policy_approved + non-culturally-governed | Yes | RLS (LifeBook scope + access_classification) | `fn_lb_membership_role` |
| INSERT | steward, contributor (LifeBook-scoped); agent_service (ai_extracted_submission only) | LifeBook membership (contributor or higher) | None at creation | Not evaluated at INSERT | Agent may not INSERT culturally governed | Agent INSERT restricted to ai_extracted_submission | Yes | RLS + CHECK | `fn_lb_membership_role` |
| UPDATE | steward (status fields only); subject (dispute_status on own-entity relationships) | LifeBook membership (steward) | policy_approved requires ApprovalRecord | Not re-evaluated | Cultural authority required for culturally governed | Agent may not UPDATE | Yes | RLS + trigger (content immutability) | `fn_lb_membership_role`, `fn_user_is_agent` |
| DELETE | No actor | — | — | — | — | — | Yes — deny all | RLS DELETE denied | — |

**Notes:**
- Content fields are immutable after INSERT (same pattern as claims). Trigger `trg_relationship_content_immutable` enforces.
- `superseded_by_relationship_id` follows the same one-write-only pattern as `superseded_by_claim_id`. Trigger `trg_relationship_supersession_integrity` enforces.

---

### 1.3 `narratives`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward, contributor, viewer (LifeBook-scoped); agent_service (restricted context) | LifeBook membership | None | Evaluated for display context | Excluded from AI context if culturally governed | Agent reads policy_approved only; narrative_type = community_account excluded from agent context | Yes | RLS (LifeBook scope + access_classification) | `fn_lb_membership_role` |
| INSERT | steward, contributor (LifeBook-scoped); agent_service (ai_extracted_submission, non-community_account only) | LifeBook membership (contributor or higher) | community_account requires authorization ApprovalRecord | Not evaluated at INSERT | Deploy-disabled for narrative_type = community_account | Agent may not INSERT community_account narratives | Yes | RLS (deny INSERT for community_account without authorization) + RLS (deny INSERT for agent_service for community_account) | `fn_lb_membership_role`, `fn_user_is_agent` |
| UPDATE | steward (status fields only) | LifeBook membership (steward) | policy_approved requires ApprovalRecord | Not re-evaluated | Cultural authority required for culturally governed | Agent may not UPDATE | Yes | RLS + trigger | `fn_lb_membership_role`, `fn_user_is_agent` |
| DELETE | No actor | — | — | — | — | — | Yes — deny all | RLS DELETE denied | — |

---

### 1.4 `narrative_entities`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward, contributor, viewer (via parent Narrative LifeBook scope); agent_service (restricted context) | Derived from parent Narrative | None | Evaluated for the referenced entity's DisplayPolicy; is_restricted_mention = true denies display in non-permitted contexts | Excluded from AI context if parent narrative or referenced entity is culturally governed | Agent may not read is_restricted_mention = true records | Yes | RLS (join to narratives LifeBook scope) | `fn_lb_membership_role` |
| INSERT | steward, contributor (LifeBook-scoped) | Derived from parent Narrative | None | Not evaluated at INSERT | Agent may not INSERT culturally governed NarrativeEntities | Agent INSERT restricted | Yes | RLS | `fn_lb_membership_role`, `fn_user_is_agent` |
| UPDATE | steward (is_restricted_mention field only) | LifeBook membership (steward) | None | Not re-evaluated | Cultural authority required for culturally governed | Agent may not UPDATE | Yes | RLS | `fn_lb_membership_role` |
| DELETE | No actor | — | — | — | — | — | Yes — deny all | RLS DELETE denied | — |

---

### 1.5 `sources`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward (own LifeBook); contributor, viewer via LifeBookSourceAccess for cross-LifeBook; agent_service (non-restricted, non-culturally-governed) | LifeBook membership (own) OR LifeBookSourceAccess record | None | Not applicable to Source records directly | Excluded from AI context | DNA sources and restricted sources excluded from agent context | Yes | RLS (lifebook_id scope + LifeBookSourceAccess join + access_classification) | `fn_lb_membership_role`, `fn_has_source_access_grant` |
| INSERT | steward (own LifeBook only) | LifeBook membership (steward) | None | Not evaluated at INSERT | Agent may not INSERT culturally governed sources | Agent INSERT denied | Yes | RLS + trigger (DNA classification) | `fn_lb_membership_role`, `fn_user_is_agent` |
| UPDATE | steward (access_classification and metadata fields); source_type and lifebook_id are immutable | LifeBook membership (steward) | None | Not re-evaluated | Cultural authority for culturally governed sources | Agent may not UPDATE | Yes | RLS + trigger (type and lifebook_id immutability) | `fn_lb_membership_role` |
| DELETE | No actor | — | — | — | — | — | Yes — deny all | RLS DELETE denied | — |

---

### 1.6 `artifacts`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT (record) | steward; contributor, viewer (non-restricted, non-culturally-governed); cultural_authority (for culturally governed) | LifeBook membership | None | Evaluated; absent policy → deny for public contexts | Culturally governed artifacts: steward + cultural_authority only | Agent may not read culturally governed; agent may not read restricted | Yes | RLS (LifeBook scope + access_classification filter) | `fn_lb_membership_role`, `fn_has_active_authority` |
| SELECT (object_key) | Never exposed directly | — | — | — | — | — | Yes — column excluded | RLS column restriction (no direct column grant) | — |
| INSERT | steward (LifeBook-scoped) | LifeBook membership (steward) | None | Not evaluated at INSERT | Agent may not INSERT culturally governed | Agent may not INSERT | Yes | RLS | `fn_lb_membership_role`, `fn_user_is_agent` |
| UPDATE | steward (access_classification, file_storage_reference_id = NULL permitted); record retained permanently | LifeBook membership (steward) | None | Not re-evaluated | Cultural authority required for culturally governed | Agent may not UPDATE | Yes | RLS | `fn_lb_membership_role` |
| DELETE | No actor | — | — | — | — | — | Yes — deny all | RLS DELETE denied | — |

**Notes:**
- Signed URL generation for file access is a SECURITY DEFINER function (`fn_generate_artifact_signed_url`). It performs policy evaluation internally before issuing a URL. See §7.
- `object_key` in the referenced file_storage_reference record must not appear in any SELECT grant to non-admin roles.

---

### 1.7 `events`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward, contributor, viewer (LifeBook-scoped); agent_service (restricted context) | LifeBook membership | None | Evaluated for display context | Excluded from AI context if culturally governed | Agent reads policy_approved only | Yes | RLS (LifeBook scope + access_classification) | `fn_lb_membership_role` |
| INSERT | steward, contributor (LifeBook-scoped); agent_service NOT permitted | LifeBook membership (contributor or higher) | None at creation; source_claim_id must reference policy_approved Claim when set (application validates) | Not evaluated at INSERT | Agent may not INSERT | Agent INSERT denied | Yes | RLS (deny INSERT for agent_service) | `fn_lb_membership_role`, `fn_user_is_agent` |
| UPDATE | steward (status fields only); source_claim_id is immutable after INSERT | LifeBook membership (steward) | policy_approved requires ApprovalRecord | Not re-evaluated | Cultural authority required | Agent may not UPDATE | Yes | RLS + trigger | `fn_lb_membership_role` |
| DELETE | No actor | — | — | — | — | — | Yes — deny all | RLS DELETE denied | — |

**Notes:**
- `source_claim_id` is set at INSERT time when generated from a Claim. It may not be changed after INSERT. Trigger `trg_event_provenance_immutable` enforces.

---

### 1.8 `event_participants`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward, contributor, viewer (via parent Event LifeBook scope); agent_service (restricted context) | Derived from parent Event | None | Participant's DisplayPolicy evaluated; absent policy → deny for public contexts | Excluded from AI context if participant entity or parent Event is culturally governed | Agent reads policy_approved only | Yes | RLS (join to events LifeBook scope) | `fn_lb_membership_role` |
| INSERT | steward, contributor (LifeBook-scoped) | Derived from parent Event | None | Not evaluated at INSERT | Agent may not INSERT | Agent INSERT denied | Yes | RLS | `fn_lb_membership_role`, `fn_user_is_agent` |
| UPDATE | steward (display_policy_id field only) | LifeBook membership (steward) | None | Not re-evaluated | Cultural authority required | Agent may not UPDATE | Yes | RLS + trigger | `fn_lb_membership_role` |
| DELETE | No actor | — | — | — | — | — | Yes — deny all | RLS DELETE denied | — |

---

### 1.9 `person_names`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward, contributor, viewer (LifeBook-scoped); subject (own names); agent_service (identity_resolution context only, with allow policy) | LifeBook membership OR subject link | None | Evaluated for display context; `usage_type = preferred` exposed in public_ui if allow policy; legal name requires steward_ui minimum | No indigenous/ceremonial names in V1 (deferred); future: culturally governed by default | Agent reads non-restricted names in identity_resolution context only; preferred name in ai_generation context only with allow policy | Yes | RLS (LifeBook scope + usage_type filter for agent) | `fn_lb_membership_role`, `fn_display_policy_allows` |
| INSERT | steward (any type); subject (preferred, nickname, birth name only — not legal or other types requiring documentation) | LifeBook membership (steward) OR subject link (for permitted types) | Legal name change requires ApprovalRecord for living subjects with capacity | Not evaluated at INSERT | Agent INSERT denied for all name types | Agent INSERT denied | Yes | RLS | `fn_lb_membership_role`, `fn_user_is_agent` |
| UPDATE | steward (status fields); subject (dispute_status on own names); name content immutable (supersession creates new record) | LifeBook membership (steward) OR subject link | policy_approved requires ApprovalRecord | Not re-evaluated | Cultural authority required for culturally governed names | Agent may not UPDATE | Yes | RLS + trigger (content immutability) | `fn_lb_membership_role` |
| DELETE | No actor | — | — | — | — | — | Yes — deny all | RLS DELETE denied | — |

---

### 1.10 `person_pronouns`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward, contributor, viewer (LifeBook-scoped); subject (own); agent_service (with allow policy for ai_generation context) | LifeBook membership OR subject link | None | Evaluated; subject controls display policy for own pronouns | Not applicable to pronouns specifically | Agent reads with allow policy in ai_generation context only | Yes | RLS (LifeBook scope) | `fn_lb_membership_role`, `fn_display_policy_allows` |
| INSERT | steward; subject (own pronouns) | LifeBook membership (steward) OR subject link | None; subject may assert at any time | Not evaluated at INSERT | Agent may not INSERT | Agent INSERT denied | Yes | RLS | `fn_lb_membership_role`, `fn_user_is_agent` |
| UPDATE | steward (status fields); subject (dispute_status on own); pronoun content immutable | LifeBook membership (steward) OR subject link | None | Not re-evaluated | N/A | Agent may not UPDATE | Yes | RLS + trigger | `fn_lb_membership_role` |
| DELETE | No actor | — | — | — | — | — | Yes — deny all | RLS DELETE denied | — |

**Notes:**
- Subject authority over pronoun assertion overrides steward in case of conflict. Application enforces this authority hierarchy.

---

### 1.11 `person_gender_descriptors`

Same authority model as `person_pronouns`. Subject has primary authority. Steward may assert with documentation. Agent INSERT denied. Agent SELECT only with allow policy in ai_generation context.

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed |
|---|---|---|---|---|---|---|---|
| SELECT | steward, contributor, viewer (LifeBook-scoped); subject (own); agent_service (with allow policy) | LifeBook membership OR subject link | None | Evaluated; subject controls DisplayPolicy | Not applicable specifically | Agent reads with allow policy only | Yes |
| INSERT | steward; subject (own) | LifeBook membership OR subject link | None; subject may assert freely | Not evaluated | Agent may not INSERT | Agent INSERT denied | Yes |
| UPDATE | steward (status fields); subject (dispute_status on own); content immutable | LifeBook membership OR subject link | None | Not re-evaluated | N/A | Agent may not UPDATE | Yes |
| DELETE | No actor | — | — | — | — | — | Yes — deny all |

---

### 1.12 `display_policies`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward (own LifeBook); subject (policies set_by_role = subject for own entity); cultural_authority (culturally governed policies); system_service | `set_by_role` must match active authority | None | N/A — display_policies are governance records, not display-governed content | Cultural authority required for culturally governed policy records | Agent may not read display_policies | Yes | RLS (set_by_role authority scope) | `fn_lb_membership_role`, `fn_has_active_authority` |
| INSERT | steward; subject (own-entity policies); cultural_authority (culturally governed records) | Valid `set_by_role` authority for the record type | approval_record_id required for specific scenarios per DISPLAY_POLICY_MODEL.md §2.2 | N/A | Cultural authority must hold active assignment | Agent may not INSERT | Yes | RLS (authority scope check) | `fn_lb_membership_role`, `fn_has_active_authority`, `fn_user_is_agent` |
| UPDATE | Application-managed status transitions only (draft → active; active → superseded/withdrawn); all other UPDATE rejected by trigger | Via application service role | None for status transition; preceding workflow must have been authorized | N/A | Cultural authority required for status transition on culturally governed | Agent may not UPDATE | Yes | Trigger (lifecycle) + RLS (prohibit UPDATE on superseded/withdrawn) | — |
| DELETE | Application-managed draft deletion only; non-draft: trigger rejects | LifeBook membership (steward) for draft deletion | None | N/A | Cultural authority required | Agent may not DELETE | Yes | Trigger (delete guard) + RLS | — |

---

### 1.13 `display_policy_rules`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward (own LifeBook); subject (rules on own-entity policies); cultural_authority; system_service | Authority to read parent display_policy | None | N/A | Cultural authority required for culturally governed | Agent may not read | Yes | RLS (via parent display_policy authority) | `fn_lb_membership_role` |
| INSERT | steward; subject (own policies); cultural_authority; permitted only when parent display_policy.status = draft | Authority over parent policy | None | N/A | Cultural authority required | Agent may not INSERT | Yes | RLS + trigger (parent status check) | `fn_lb_membership_role` |
| UPDATE | Denied when parent policy status != draft; trigger rejects | — | — | N/A | — | Agent may not UPDATE | Yes | Trigger (rule immutability) | — |
| DELETE | Denied when parent policy status != draft; trigger rejects | — | — | N/A | — | Agent may not DELETE | Yes | Trigger (rule delete guard) | — |

---

### 1.14 `approval_records`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward; subject (approvals concerning own entity); cultural_authority (culturally governed approvals); system_service; admin | Authority relevant to the approval | N/A | N/A | Cultural authority for culturally governed | Agent may not SELECT | Yes | RLS (scoped to LifeBook or entity) | `fn_lb_membership_role` |
| INSERT | Application service role only (approval workflow completes all preconditions before INSERT) | All required approvers confirmed by application | Self-referential: approval IS the record | N/A | Cultural governance required if applicable policy has `cultural_governance_required = TRUE` | Agent may not INSERT | Yes | RLS (deny INSERT for agent_service) | `fn_user_is_agent` |
| UPDATE | No actor — immutable after creation | — | — | N/A | — | — | Yes — deny all | RLS UPDATE denied + trigger | — |
| DELETE | No actor — permanent record | — | — | N/A | — | — | Yes — deny all | RLS DELETE denied | — |

---

### 1.15 `authority_assignments`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward (own LifeBook); subject (own assignments); admin; system_service | LifeBook membership OR subject link | None | N/A | Cultural authority for culturally governed assignments | Agent may not SELECT | Yes | RLS (LifeBook scope or subject link) | `fn_lb_membership_role` |
| INSERT | Steward; admin; application workflow (following external documentation) | LifeBook membership (steward) or admin | None for basic assignments; complex legal authority requires documentation Claim (basis_claim_id) | N/A | Cultural authority assignment requires community determination (external) | Agent may not INSERT | Yes | RLS | `fn_lb_membership_role`, `fn_user_is_agent` |
| UPDATE | steward (effective_until for revocation; is_contested flag); otherwise immutable | LifeBook membership (steward) | None for revocation; contested flag triggers escalation review | N/A | Cultural authority required | Agent may not UPDATE | Yes | RLS + trigger (revocation-only update guard) | `fn_lb_membership_role` |
| DELETE | No actor — permanent record | — | — | N/A | — | — | Yes — deny all | RLS DELETE denied | — |

**Notes:**
- `effective_until` may only be set to a date; it may never be set NULL once populated. Trigger `trg_authority_assignment_revocation_guard` enforces this invariant.

---

### 1.16 `contest_records`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward; parties with standing in the dispute; admin; system_service | LifeBook membership OR recognized standing class | None | N/A | Cultural authority for culturally governed disputes | Agent may not SELECT | Yes | RLS (LifeBook scope + standing check) | `fn_lb_membership_role`, `fn_has_contest_standing` |
| INSERT | Parties with recognized standing (7 classes per GEM §15 Resolved Blocker 3); standing_class field required | Standing class must match verified authority | None at creation; dispute workflow may escalate to ApprovalRecord | N/A | Cultural authority class required for culturally governed disputes | Agent may not INSERT | Yes | RLS (standing class check) + trigger (standing validation) | `fn_has_contest_standing`, `fn_user_is_agent` |
| UPDATE | steward (resolution fields); contest_records are otherwise immutable | LifeBook membership (steward) | Resolution may require ApprovalRecord per escalation_policy | N/A | Cultural authority required | Agent may not UPDATE | Yes | RLS | `fn_lb_membership_role` |
| DELETE | No actor — permanent record | — | — | N/A | — | — | Yes — deny all | RLS DELETE denied | — |

---

### 1.17 `person_name_derivatives`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward; subject (own); agent_service (identity_resolution context, with allow policy, non-restricted parent name) | Derived from parent PersonName authority | None | Evaluated from parent PersonName DisplayPolicy | Excluded from AI context if parent name is culturally governed | Agent restricted to identity_resolution context with allow policy | Yes | RLS (via parent person_names scope) | `fn_lb_membership_role`, `fn_display_policy_allows` |
| INSERT | system_service (automated derivation); steward (manual derivation) | LifeBook membership (steward) for manual; system for automated | None; review_status = pending at creation | Not evaluated at INSERT | Agent may not INSERT | Agent INSERT denied | Yes | RLS | `fn_lb_membership_role`, `fn_user_is_agent` |
| UPDATE | system_service (validity_state only); steward (review_status fields) | System role OR steward membership | policy_approved requires ApprovalRecord | Not re-evaluated | Cultural authority required | Agent may not UPDATE | Yes | RLS | `fn_lb_membership_role` |
| DELETE | No actor | — | — | — | — | — | Yes — deny all | RLS DELETE denied | — |

---

### 1.18 `lifebook_entities`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward (all visibility_status); contributor/viewer (visibility_status IN ('visible','anonymized') only); subject (own record, any visibility_status) | LifeBook membership (steward/contributor/viewer) OR subject link | None | Not applicable — lifebook_entities is a governance participation record, not display-governed content | Not applicable | Agent denied entirely — participation metadata must not be exposed to AI | Yes | RLS (3 permissive policies; fail-closed excludes agents, hidden/restricted/pending_confirmation from non-stewards) | `fn_lb_membership_role`, `fn_is_subject_of`, `fn_user_is_agent` |
| INSERT | steward only | LifeBook membership (steward) | None | Not evaluated | Not applicable | Agent INSERT denied | Yes | RLS | `fn_lb_membership_role` |
| UPDATE | steward only | LifeBook membership (steward) | None | Not evaluated | Not applicable | Agent UPDATE denied | Yes | RLS | `fn_lb_membership_role` |
| DELETE | No actor — use `removed_at` (soft delete) | — | — | — | — | — | Yes — deny all | RLS DELETE denied (`USING (FALSE)`) | — |

**Notes:**
- `steward_notes` must not be exposed to non-steward actors; application-layer suppression required in V1. Column-level REVOKE is a future hardening item.
- `visibility_status = 'anonymized'`: row is visible to contributor/viewer via RLS, but application must not expose `entity_id` for anonymous entities.
- `visibility_status = 'restricted'`: steward-only in V1. Per-entity authorization model (via AuthorityAssignment) is a future extension.
- `entity_id`, `lifebook_id`, `entity_type`, `added_at`, `added_by_id` are immutable after INSERT; enforced at application layer in V1.

---

### 1.19 `lifebook_person_contexts`

| Operation | Permitted Actors | Authority Requirement | Approval Requirement | DisplayPolicy | Cultural Gov. | AI Restriction | Fail-Closed | Primary Mechanism | Helper Function |
|---|---|---|---|---|---|---|---|---|---|
| SELECT | steward (own LifeBook, via join to parent lifebook_entity); subject (own record) | LifeBook membership (steward) OR subject link | None | Not applicable — governance record | Not applicable | Agent denied entirely | Yes | RLS (2 permissive policies; contributor/viewer denied by absence from any SELECT grant) | `fn_lb_membership_role`, `fn_is_subject_of`, `fn_user_is_agent` |
| INSERT | steward only (system_service via role grants) | LifeBook membership (steward) | None; must be created in same transaction as parent lifebook_entity | Not evaluated | Not applicable | Agent INSERT denied | Yes | RLS | `fn_lb_membership_role` |
| UPDATE (governance fields) | steward only (`authority_context`, `contribution_status`) | LifeBook membership (steward) | None | Not evaluated | Not applicable | Agent UPDATE denied | Yes | RLS | `fn_lb_membership_role` |
| UPDATE (consent fields) | subject only (`has_accepted_terms`, `terms_accepted_at`, `cross_lifebook_linkage_*`) | Subject link (verified) | None; subject has sovereign authority over consent fields | Not evaluated | Not applicable | Agent UPDATE denied | Yes | RLS | `fn_is_subject_of` |
| UPDATE (cache fields) | system_service only (`cached_permission_summary`, `permission_cache_*`) | system_service role | None | Not evaluated | Not applicable | Agent UPDATE denied | Yes | Role grants (system_service) | — |
| DELETE | No actor — lifecycle managed via parent lifebook_entity.removed_at | — | — | — | — | — | Yes — deny all | RLS DELETE denied (`USING (FALSE)`) | — |

**Notes:**
- `authority_context = 'disputed'` transition is governed by the ContestRecord workflow; steward may not set this directly outside the dispute process.
- Subject consent fields (`cross_lifebook_linkage_authorized` and related) are immutable by steward — subject's cross-LifeBook authorization is sovereign.
- `permission_cache_policy_version_id` FK to `approval_policies` is Deferred FK 3; applied after Batch 5.
- RLS policy on UPDATE uses two separate permissive policies (steward UPDATE and subject UPDATE). PostgreSQL permissive policies combine with OR; the application must restrict field updates within the subject's UPDATE grant — the database cannot enforce field-level splits via RLS alone. Application-layer enforcement required.
- `lifebook_person_contexts` has no direct `lifebook_id` column; all policies requiring LifeBook-scoped authority use a subquery: `(SELECT lifebook_id FROM lifebook_entities WHERE id = lifebook_entity_id)`.

---

## §2. Complete RLS Policy Inventory

**Previous count (GEM §13):** 38 policies.  
**v3.0 count:** 53 policies.  
**Revised count:** 65 policies.  
**Final count:** 71 policies.

**Net additions from v3.0: +12** — 6 policies for `lifebook_entities` (SELECT ×3, INSERT, UPDATE, DELETE) and 6 policies for `lifebook_person_contexts` (SELECT ×2, INSERT, UPDATE ×2, DELETE); both tables omitted from v3.0 due to batch-list gap; gap resolved 2026-07-25.

**Net additions from revised (65→71): +6** — 3 SELECT policies for governance tables previously reachable only via SECURITY DEFINER (approval_records, display_policies, display_policy_rules); 1 INSERT policy for person_name_derivatives (previously missing); 2 policies for source_derivatives (SELECT + INSERT previously missing). Resolved 2026-07-25 pre-authoring blocker resolution pass.

### 2.1 Content Table LifeBook-Scoped SELECT (policies 1–15)

| # | Policy Name | Table | Operation | USING Responsibility | WITH CHECK | Actor Class | Dependencies | Rule Enforced |
|---|---|---|---|---|---|---|---|---|
| 1 | `pol_claims_select_lifebook` | `claims` | SELECT | `fn_lb_membership_role(lifebook_id) != 'none'` | N/A | steward, contributor, viewer | `fn_lb_membership_role` | LifeBook-scoped claim access |
| 2 | `pol_relationships_select_lifebook` | `relationships` | SELECT | `fn_lb_membership_role(lifebook_id) != 'none'` | N/A | steward, contributor, viewer | `fn_lb_membership_role` | LifeBook-scoped relationship access |
| 3 | `pol_narratives_select_lifebook` | `narratives` | SELECT | `fn_lb_membership_role(lifebook_id) != 'none'` | N/A | steward, contributor, viewer | `fn_lb_membership_role` | LifeBook-scoped narrative access |
| 4 | `pol_narrative_entities_select_lifebook` | `narrative_entities` | SELECT | Via join to narratives lifebook_id | N/A | steward, contributor, viewer | `fn_lb_membership_role` | LifeBook-scoped NarrativeEntity access |
| 5 | `pol_sources_select_lifebook` | `sources` | SELECT | `lifebook_id = current_user_lifebook OR fn_has_source_access_grant(id)` | N/A | steward, contributor, viewer | `fn_lb_membership_role`, `fn_has_source_access_grant` | LifeBook-scoped source access |
| 6 | `pol_artifacts_select_lifebook` | `artifacts` | SELECT | `fn_lb_membership_role(lifebook_id) != 'none' AND (access_classification NOT IN ('restricted','culturally_governed') OR fn_lb_membership_role(lifebook_id) = 'steward')` | N/A | steward, contributor, viewer | `fn_lb_membership_role` | LifeBook-scoped artifact access |
| 7 | `pol_events_select_lifebook` | `events` | SELECT | `fn_lb_membership_role(lifebook_id) != 'none'` | N/A | steward, contributor, viewer | `fn_lb_membership_role` | LifeBook-scoped event access |
| 8 | `pol_event_participants_select_lifebook` | `event_participants` | SELECT | Via join to events lifebook_id | N/A | steward, contributor, viewer | `fn_lb_membership_role` | LifeBook-scoped EventParticipant access |
| 9 | `pol_claim_evidence_select_lifebook` | `claim_evidence` | SELECT | Via join to claims lifebook_id | N/A | steward, contributor, viewer | `fn_lb_membership_role` | LifeBook-scoped ClaimEvidence access |
| 10 | `pol_artifact_source_links_select_lifebook` | `artifact_source_links` | SELECT | Via join to artifacts lifebook_id | N/A | steward, contributor, viewer | `fn_lb_membership_role` | LifeBook-scoped ArtifactSourceLink access |
| 11 | `pol_person_names_select_lifebook` | `person_names` | SELECT | USING: `EXISTS (SELECT 1 FROM lifebook_entities le JOIN entities e ON e.id = le.entity_id JOIN persons p ON p.entity_id = e.id WHERE p.id = person_names.person_id AND fn_lb_membership_role(le.lifebook_id) != 'none' AND NOT fn_user_is_agent()) OR fn_is_subject_of((SELECT entity_id FROM persons WHERE id = person_names.person_id))` — full join chain: person_names → persons → entities → lifebook_entities → lifebook_id; subject access is independent of LifeBook membership | N/A | steward, contributor, viewer, subject | `fn_lb_membership_role`, `fn_is_subject_of`, `fn_user_is_agent` | LifeBook-scoped PersonName access; agents excluded |
| 12 | `pol_person_pronouns_select_lifebook` | `person_pronouns` | SELECT | USING: same join chain as policy 11 — `EXISTS (SELECT 1 FROM lifebook_entities le JOIN entities e ON e.id = le.entity_id JOIN persons p ON p.entity_id = e.id WHERE p.id = person_pronouns.person_id AND fn_lb_membership_role(le.lifebook_id) != 'none' AND NOT fn_user_is_agent()) OR fn_is_subject_of((SELECT entity_id FROM persons WHERE id = person_pronouns.person_id))` | N/A | steward, contributor, viewer, subject | `fn_lb_membership_role`, `fn_is_subject_of`, `fn_user_is_agent` | LifeBook-scoped PersonPronouns access; agents excluded |
| 13 | `pol_person_gender_select_lifebook` | `person_gender_descriptors` | SELECT | USING: same join chain as policy 11 — `EXISTS (SELECT 1 FROM lifebook_entities le JOIN entities e ON e.id = le.entity_id JOIN persons p ON p.entity_id = e.id WHERE p.id = person_gender_descriptors.person_id AND fn_lb_membership_role(le.lifebook_id) != 'none' AND NOT fn_user_is_agent()) OR fn_is_subject_of((SELECT entity_id FROM persons WHERE id = person_gender_descriptors.person_id))` | N/A | steward, contributor, viewer, subject | `fn_lb_membership_role`, `fn_is_subject_of`, `fn_user_is_agent` | LifeBook-scoped PersonGenderDescriptor access; agents excluded |
| 14 | `pol_person_name_derivatives_select` | `person_name_derivatives` | SELECT | USING: `EXISTS (SELECT 1 FROM person_names pn JOIN persons p ON p.id = pn.person_id JOIN lifebook_entities le ON le.entity_id = p.entity_id WHERE pn.id = person_name_derivatives.source_name_id AND fn_lb_membership_role(le.lifebook_id) != 'none' AND NOT fn_user_is_agent()) OR fn_is_subject_of((SELECT p.entity_id FROM person_names pn JOIN persons p ON p.id = pn.person_id WHERE pn.id = person_name_derivatives.source_name_id))` — same chain extended through person_names → persons → lifebook_entities; agent restriction applied here; policy 53 further restricts agents with restricted classification | N/A | steward, subject | `fn_lb_membership_role`, `fn_is_subject_of`, `fn_user_is_agent` | LifeBook-scoped PersonNameDerivative access; agents excluded at policy 14; policy 53 applies additionally for restricted classification |
| 15 | `pol_authority_assignments_select` | `authority_assignments` | SELECT | `fn_lb_membership_role(lifebook_id) = 'steward' OR fn_is_subject_of(entity_id)` | N/A | steward, subject, admin | `fn_lb_membership_role`, `fn_is_subject_of` | Authority assignment visibility |

### 2.2 Permanent Record DELETE Denied (policies 16–29)

| # | Policy Name | Table | Operation | USING | Actor Class | Rule Enforced |
|---|---|---|---|---|---|---|
| 16 | `pol_claims_delete_denied` | `claims` | DELETE | `FALSE` | All | Claims are permanent |
| 17 | `pol_narratives_delete_denied` | `narratives` | DELETE | `FALSE` | All | Narratives are permanent |
| 18 | `pol_sources_delete_denied` | `sources` | DELETE | `FALSE` | All | Sources are permanent |
| 19 | `pol_artifacts_delete_denied` | `artifacts` | DELETE | `FALSE` | All | Artifact records are permanent |
| 20 | `pol_relationships_delete_denied` | `relationships` | DELETE | `FALSE` | All | Relationships are permanent |
| 21 | `pol_events_delete_denied` | `events` | DELETE | `FALSE` | All | Events are permanent |
| 22 | `pol_approval_records_delete_denied` | `approval_records` | DELETE | `FALSE` | All | Approval records are permanent |
| 23 | `pol_context_manifests_delete_denied` | `context_manifests` | DELETE | `FALSE` | All | Context manifests are permanent |
| 24 | `pol_access_policy_events_delete_denied` | `access_policy_changed_events` | DELETE | `FALSE` | All | Policy change events are permanent |
| 25 | `pol_authority_assignments_delete_denied` | `authority_assignments` | DELETE | `FALSE` | All | Authority assignments are permanent |
| 26 | `pol_contest_records_delete_denied` | `contest_records` | DELETE | `FALSE` | All | Contest records are permanent |
| 27 | `pol_person_names_delete_denied` | `person_names` | DELETE | `FALSE` | All | PersonNames are permanent |
| 28 | `pol_person_pronouns_delete_denied` | `person_pronouns` | DELETE | `FALSE` | All | PersonPronouns are permanent |
| 29 | `pol_person_gender_delete_denied` | `person_gender_descriptors` | DELETE | `FALSE` | All | PersonGenderDescriptors are permanent |

### 2.3 AI Agent Restrictions (policies 30–36)

**Policies 30, 31, 32 — USING vs WITH CHECK clarification:** These UPDATE policies require **both** USING and WITH CHECK clauses. USING determines which existing rows are eligible for UPDATE (pre-update row filter); WITH CHECK validates the new row state after UPDATE. The AI restriction is a NEW-state concern: we want to deny agent_service from setting specific status values. The USING clause must be permissive enough to allow agents to UPDATE rows they otherwise have access to (for allowed field changes); the WITH CHECK clause enforces the prohibited new states.

| # | Policy Name | Table | Operation | USING | WITH CHECK | Actor Class | Rule Enforced |
|---|---|---|---|---|---|---|---|
| 30 | `pol_claims_ai_promotion_denied` | `claims` | UPDATE | `fn_lb_membership_role(lifebook_id) != 'none'` — agent must be in LifeBook to UPDATE any row (existing row is accessible) | `NOT (fn_user_is_agent() AND NEW.review_status = 'policy_approved')` — prohibited new state: agent setting review_status to policy_approved | agent_service | Agent cannot set review_status = 'policy_approved' on any claim; human UPDATE path is unaffected |
| 31 | `pol_claims_ai_dispute_denied` | `claims` | UPDATE | `fn_lb_membership_role(lifebook_id) != 'none'` | `NOT (fn_user_is_agent() AND NEW.dispute_status IS DISTINCT FROM OLD.dispute_status)` — prohibited new state: agent changing dispute_status at all | agent_service | Agent cannot change dispute_status on any claim; agents may UPDATE other permitted fields without triggering this policy |
| 32 | `pol_narratives_ai_promotion_denied` | `narratives` | UPDATE | `fn_lb_membership_role(lifebook_id) != 'none'` | `NOT (fn_user_is_agent() AND NEW.review_status = 'policy_approved')` — same pattern as policy 30 | agent_service | Agent cannot set review_status = 'policy_approved' on any narrative |
| 33 | `pol_events_insert_agent_denied` | `events` | INSERT | WITH CHECK: `NOT fn_user_is_agent()` | agent_service | AI cannot create Events directly |
| 34 | `pol_approval_records_insert_agent_denied` | `approval_records` | INSERT | WITH CHECK: `NOT fn_user_is_agent()` | agent_service | AI cannot create ApprovalRecords |
| 35 | `pol_sources_insert_agent_denied` | `sources` | INSERT | WITH CHECK: `NOT fn_user_is_agent()` | agent_service | AI cannot create Source records |
| 36 | `pol_person_names_insert_agent_denied` | `person_names` | INSERT | WITH CHECK: `NOT fn_user_is_agent()` | agent_service | AI cannot create PersonName records |

### 2.4 Culturally Governed Content (policies 37–41)

| # | Policy Name | Table | Operation | USING Responsibility | Actor Class | Rule Enforced |
|---|---|---|---|---|---|---|
| 37 | `pol_claims_cultural_ai_excluded` | `claims` | SELECT | Deny if `fn_user_is_agent()` AND `access_classification = 'culturally_governed'` | agent_service | Culturally governed claims excluded from AI |
| 38 | `pol_narratives_cultural_ai_excluded` | `narratives` | SELECT | Same pattern | agent_service | Culturally governed narratives excluded from AI |
| 39 | `pol_artifacts_cultural_ai_excluded` | `artifacts` | SELECT | Same pattern | agent_service | Culturally governed artifacts excluded from AI |
| 40 | `pol_sources_cultural_ai_excluded` | `sources` | SELECT | Same pattern | agent_service | Culturally governed sources excluded from AI |
| 41 | `pol_narratives_community_account_gate` | `narratives` | INSERT | WITH CHECK: `narrative_type != 'community_account' OR fn_has_community_authorization(lifebook_id)` | All | Community account creation requires authorization |

### 2.5 Access Classification Filtering (policies 42–44)

| # | Policy Name | Table | Operation | USING Responsibility | Actor Class | Rule Enforced |
|---|---|---|---|---|---|---|
| 42 | `pol_artifacts_restricted_steward_only` | `artifacts` | SELECT | `access_classification = 'restricted' → fn_lb_membership_role(lifebook_id) = 'steward'` | steward | Restricted artifacts: steward only |
| 43 | `pol_artifacts_culturally_governed_authority` | `artifacts` | SELECT | `access_classification = 'culturally_governed' → fn_lb_membership_role = 'steward' OR fn_has_active_authority('cultural_authority', null)` | steward, cultural_authority | Culturally governed artifacts require authority |
| 44 | `pol_sources_restricted_steward_only` | `sources` | SELECT | `access_classification = 'restricted' → fn_lb_membership_role(lifebook_id) = 'steward'` | steward | Restricted sources: steward only |

### 2.6 DisplayPolicy Lifecycle (policies 45–48)

| # | Policy Name | Table | Operation | USING / WITH CHECK | Actor Class | Rule Enforced |
|---|---|---|---|---|---|---|
| 45 | `pol_display_policies_delete_non_draft_denied` | `display_policies` | DELETE | USING: `status = 'draft'` | steward | Only draft policies may be deleted |
| 46 | `pol_display_policies_update_frozen` | `display_policies` | UPDATE | USING: `status IN ('draft','active')` — trigger enforces field restriction for active | steward, system_service | Superseded/withdrawn policies completely immutable via RLS |
| 47 | `pol_display_policies_insert_authorized` | `display_policies` | INSERT | WITH CHECK: `fn_has_active_authority(set_by_role, null)` | steward, subject, cultural_authority | INSERT requires valid authority for set_by_role |
| 48 | `pol_display_policy_rules_non_draft_denied` | `display_policy_rules` | DELETE | USING: parent `display_policies.status = 'draft'` (via join) | steward, subject, cultural_authority | Rules on non-draft policies are immutable |

### 2.7 ApprovalRecord Immutability (policy 49)

| # | Policy Name | Table | Operation | USING | Actor Class | Rule Enforced |
|---|---|---|---|---|---|---|
| 49 | `pol_approval_records_update_denied` | `approval_records` | UPDATE | `FALSE` | All | Approval records are immutable |

### 2.8 Governance (policies 50–53)

| # | Policy Name | Table | Operation | USING / WITH CHECK | Actor Class | Rule Enforced |
|---|---|---|---|---|---|---|
| 50 | `pol_authority_assignments_update_revocation_only` | `authority_assignments` | UPDATE | USING: `lifebook_id IS NOT NULL AND fn_lb_membership_role(lifebook_id) = 'steward'`; trigger enforces field restriction to effective_until and is_contested only. **Note:** entity-scoped assignments where `lifebook_id IS NULL` are NOT covered by this policy — `fn_lb_membership_role(NULL)` returns 'none'. Revocation of entity-scoped authority assignments must be routed through a SECURITY DEFINER function (executed by system_service or admin) that bypasses RLS. No additional RLS UPDATE policy is provided for entity-scoped assignments at this time. | steward (LifeBook-scoped assignments only) | Only effective_until and is_contested may be updated; entity-scoped assignments revoked via SECURITY DEFINER path only |
| 51 | `pol_contest_records_insert_standing` | `contest_records` | INSERT | WITH CHECK: `fn_has_contest_standing(contested_record_table, contested_record_id, standing_class)` | All recognized standing classes | ContestRecord INSERT requires verified standing |
| 52 | `pol_contest_records_select_parties` | `contest_records` | SELECT | USING: `fn_lb_membership_role(lifebook_id) = 'steward' OR fn_has_contest_standing(contested_record_table, contested_record_id, standing_class)` | steward, parties with standing | ContestRecord visibility limited to parties |
| 53 | `pol_person_name_derivatives_agent_restricted` | `person_name_derivatives` | SELECT | Deny if `fn_user_is_agent()` AND `access_classification = 'restricted'` | agent_service | Agent cannot read restricted name derivatives |

### 2.9 LifeBook Entity Access (policies 54–59)

*6 policies | `lifebook_entities` | Requires: `fn_lb_membership_role`, `fn_is_subject_of`, `fn_user_is_agent`*

**Implementation note:** Three permissive SELECT policies combine with OR per PostgreSQL default. `agent_service` is excluded from all three SELECT USING clauses via `NOT fn_user_is_agent()`. This provides defense-in-depth against any agent_service LifeBook membership records that may exist.

| # | Policy Name | Table | Operation | USING / WITH CHECK | Actor Class | Rule Enforced |
|---|---|---|---|---|---|---|
| 54 | `pol_lifebook_entities_select_steward` | `lifebook_entities` | SELECT | USING: `fn_lb_membership_role(lifebook_id) = 'steward' AND NOT fn_user_is_agent()` | steward | Steward sees all lifebook_entity records in their LifeBook regardless of visibility_status |
| 55 | `pol_lifebook_entities_select_member_visible` | `lifebook_entities` | SELECT | USING: `fn_lb_membership_role(lifebook_id) IN ('contributor','viewer') AND visibility_status IN ('visible','anonymized') AND NOT fn_user_is_agent()` | contributor, viewer | Members see only visible and anonymized entities; hidden/restricted/pending_confirmation denied |
| 56 | `pol_lifebook_entities_select_subject_own` | `lifebook_entities` | SELECT | USING: `fn_is_subject_of(entity_id) AND NOT fn_user_is_agent()` | subject | Subject always sees their own lifebook_entity record regardless of visibility_status |
| 57 | `pol_lifebook_entities_insert_steward` | `lifebook_entities` | INSERT | WITH CHECK: `fn_lb_membership_role(lifebook_id) = 'steward'` | steward | Only steward may add entities to a LifeBook |
| 58 | `pol_lifebook_entities_update_steward` | `lifebook_entities` | UPDATE | USING: `fn_lb_membership_role(lifebook_id) = 'steward'` | steward | Only steward may update entity participation records |
| 59 | `pol_lifebook_entities_delete_denied` | `lifebook_entities` | DELETE | USING: `FALSE` | All | DELETE denied for all actors; use `removed_at` for soft delete |

### 2.10 LifeBook Person Context Access (policies 60–65)

*6 policies | `lifebook_person_contexts` | Requires: `fn_lb_membership_role`, `fn_is_subject_of`, `fn_user_is_agent`*

**Implementation note:** `lifebook_person_contexts` has no direct `lifebook_id` column. All policies requiring LifeBook-scoped authority resolve it via subquery: `(SELECT lifebook_id FROM lifebook_entities WHERE id = lifebook_entity_id)`. Contributor and viewer roles have no SELECT grant on this table — denied by fail-closed default. PostgreSQL permissive UPDATE policies (63, 64) combine with OR; field-level split between steward and subject domains is enforced at the application layer (database layer cannot restrict specific columns within an UPDATE RLS policy).

| # | Policy Name | Table | Operation | USING / WITH CHECK | Actor Class | Rule Enforced |
|---|---|---|---|---|---|---|
| 60 | `pol_lifebook_person_contexts_select_steward` | `lifebook_person_contexts` | SELECT | USING: `fn_lb_membership_role((SELECT lifebook_id FROM lifebook_entities WHERE id = lifebook_entity_id)) = 'steward' AND NOT fn_user_is_agent()` | steward | Steward sees all person contexts in their LifeBook |
| 61 | `pol_lifebook_person_contexts_select_subject` | `lifebook_person_contexts` | SELECT | USING: `fn_is_subject_of(entity_id) AND NOT fn_user_is_agent()` | subject | Subject sees their own person context record |
| 62 | `pol_lifebook_person_contexts_insert_steward` | `lifebook_person_contexts` | INSERT | WITH CHECK: `fn_lb_membership_role((SELECT lifebook_id FROM lifebook_entities WHERE id = lifebook_entity_id)) = 'steward'` | steward | Only steward may create person context records (system_service via role grants) |
| 63 | `pol_lifebook_person_contexts_update_steward` | `lifebook_person_contexts` | UPDATE | USING: `fn_lb_membership_role((SELECT lifebook_id FROM lifebook_entities WHERE id = lifebook_entity_id)) = 'steward'` | steward | Steward UPDATE for governance fields: `authority_context`, `contribution_status` |
| 64 | `pol_lifebook_person_contexts_update_subject` | `lifebook_person_contexts` | UPDATE | USING: `fn_is_subject_of(entity_id)` | subject | Subject UPDATE for consent fields: `has_accepted_terms`, `terms_accepted_at`, `cross_lifebook_linkage_*`; subject cannot be overridden by steward for these fields |
| 65 | `pol_lifebook_person_contexts_delete_denied` | `lifebook_person_contexts` | DELETE | USING: `FALSE` | All | DELETE denied; lifecycle managed via parent lifebook_entity.removed_at |

### 2.11 Additional SELECT Policies — Governance Tables (policies 66–68)

*Resolves G1 (missing SELECT policies for governance tables accessible to stewards and subjects)*

**G1 — Intentionally no SELECT policy (SECURITY DEFINER access only, no direct application SELECT):**
- `context_manifests` — internal AI session state; application has no direct SELECT need
- `access_policy_changed_events` — audit trail; admin/backend access only
- `lifebook_memberships` — `fn_lb_membership_role` (SECURITY DEFINER) is the access path; direct SELECT by non-admin roles creates infinite recursion risk

**G1 — Requires SELECT policy (steward management UI needs direct access):**

| # | Policy Name | Table | Operation | USING | Actor Class | Rule Enforced |
|---|---|---|---|---|---|---|
| 66 | `pol_approval_records_select` | `approval_records` | SELECT | USING: `NOT fn_user_is_agent()` | steward, subject, system_service, admin | All non-agent authenticated roles may read approval records; agent exclusion prevents AI from learning approval thresholds |
| 67 | `pol_display_policies_select` | `display_policies` | SELECT | USING: `NOT fn_user_is_agent()` | steward, subject, cultural_authority | All non-agent authenticated roles may read display policies; agents use `fn_display_policy_allows` SECURITY DEFINER path |
| 68 | `pol_display_policy_rules_select` | `display_policy_rules` | SELECT | USING: `NOT fn_user_is_agent()` | steward, subject, cultural_authority | All non-agent authenticated roles may read display policy rules; same rationale as policy 67 |

### 2.12 Missing INSERT Policies — person_name_derivatives and source_derivatives (policies 69–71)

*Resolves G2 (person_name_derivatives INSERT) and G3 (source_derivatives SELECT + INSERT)*

| # | Policy Name | Table | Operation | USING / WITH CHECK | Actor Class | Rule Enforced |
|---|---|---|---|---|---|---|
| 69 | `pol_person_name_derivatives_insert` | `person_name_derivatives` | INSERT | WITH CHECK: `NOT fn_user_is_agent()` | system_service, steward | Agent INSERT denied; system_service (automated derivation) and steward (manual) permitted; fine-grained role distinction enforced via database role grants, not RLS |
| 70 | `pol_source_derivatives_select_lifebook` | `source_derivatives` | SELECT | USING: `EXISTS (SELECT 1 FROM sources s WHERE s.id = source_derivatives.source_id AND fn_lb_membership_role(s.lifebook_id) != 'none')` | steward, contributor, viewer, system_service, agent_service | LifeBook-scoped derivative access via parent source; all roles in the LifeBook may read derivative records; access_classification restrictions on the parent source govern AI access at the source layer |
| 71 | `pol_source_derivatives_insert_system` | `source_derivatives` | INSERT | WITH CHECK: `NOT fn_user_is_agent()` | system_service | Agent INSERT denied; source derivatives are created only by system_service automated processes |

**Final RLS policy count: 71**

---

## §3. Trigger Specification Inventory

**Previous count (GEM §14):** 15 triggers.  
**Revised count:** 22 triggers.

**Net additions: +7** — Relationship content immutability and supersession integrity (mirrors Claims pattern, required by DP Option B decision), Event provenance immutability (required by DP source_claim_id decision), authority assignment revocation guard (implied in GEM §9 but not named), ContestRecord standing validation (required by DP decision), and explicit naming of previously implied claim content immutability and supersession integrity triggers.

---

### Content Triggers (no cross-table dependencies)

| # | Trigger Name | Table | Timing | Event | Invariant Enforced | Fields Inspected | Permitted Transitions | Exception Conditions | Required 0003 | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `trg_claim_value_not_null` | `claims` | BEFORE | INSERT | At least one of value_text, value_date, value_numeric, object_entity_id must be non-null | value_text, value_date, value_numeric, object_entity_id | Any non-null combination | All four NULL → raise | Yes | None |
| 2 | `trg_claim_ai_provenance` | `claims` | BEFORE | INSERT, UPDATE | ai_generated = true requires producing_agent_code and context_manifest_id | ai_generated, producing_agent_code, context_manifest_id | ai_generated = false: fields may be null; ai_generated = true: both fields required | Violation → raise | Yes | None |
| 3 | `trg_claim_content_immutable` | `claims` | BEFORE | UPDATE | Content fields immutable: predicate_id, value_text, value_date, value_numeric, object_entity_id, lifebook_id, entity_id, submission_origin, ai_generated | All content fields vs OLD | None | Any content field change → raise; status field updates (dispute_status, review_status, display_policy_id, superseded_by_claim_id) permitted | Yes | None |
| 4 | `trg_relationship_content_immutable` | `relationships` | BEFORE | UPDATE | Content fields immutable: relationship_type_id, entity_a_id, entity_b_id, role_a, role_b, lifebook_id, submission_origin | All content fields vs OLD | None | Any content field change → raise | Yes | None |
| 5 | `trg_source_dna_classification` | `sources` | BEFORE | INSERT | source_type = 'dna_analysis' → access_classification = 'restricted' | source_type, access_classification | **Coerce silently if `NEW.access_classification IS NULL`** (field omitted or defaulted); **raise if `NEW.access_classification IS NOT NULL AND NEW.access_classification != 'restricted'`** (caller explicitly passed a non-restricted value — treat as intent conflict, not silent correction) | `NEW.access_classification IS NOT NULL AND != 'restricted'` → raise | Yes | None |
| 6 | `trg_source_type_immutable` | `sources` | BEFORE | UPDATE | source_type may not change after creation | source_type vs OLD.source_type | None | source_type changed → raise | Yes | None |
| 7 | `trg_source_lifebook_immutable` | `sources` | BEFORE | UPDATE | lifebook_id may not change after creation | lifebook_id vs OLD.lifebook_id | None | lifebook_id changed → raise | Yes | None |
| 8 | `trg_event_provenance_immutable` | `events` | BEFORE | UPDATE | source_claim_id is immutable after INSERT | source_claim_id vs OLD.source_claim_id | NULL → NULL only; non-NULL → same value only | source_claim_id changed → raise | Yes | None (FK constraint covers reference validity) |
| 9 | `trg_approval_records_immutable` | `approval_records` | BEFORE | UPDATE | No UPDATE permitted | All fields | None | Any UPDATE → raise | Yes | None |
| 10 | `trg_authority_assignment_revocation_guard` | `authority_assignments` | BEFORE | UPDATE | Only effective_until (NULL → date) and is_contested (FALSE → TRUE) may change; effective_until may never revert to NULL | effective_until, is_contested vs OLD values; all other fields | effective_until: NULL → date permitted; is_contested: any flip permitted; all other fields: unchanged | effective_until reverted to NULL → raise; any other field changed → raise | Yes | None |
| 11 | `trg_display_policies_lifecycle` | `display_policies` | BEFORE | UPDATE | Status transition rules; non-status field immutability for non-draft | status vs OLD.status; all non-status fields | draft → any field update; draft → active (status-only); active → superseded (status-only); active → withdrawn (status-only) | Non-status field changed on non-draft record → raise; invalid status transition → raise | Yes | None |
| 12 | `trg_display_policies_delete_guard` | `display_policies` | BEFORE | DELETE | DELETE only when status = draft | OLD.status | Draft deletion permitted | status != 'draft' → raise | Yes | None |

### Cross-Table Triggers (created after referenced tables exist)

| # | Trigger Name | Table | Timing | Event | Invariant Enforced | Fields Inspected | Permitted Transitions | Exception Conditions | Required 0003 | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| 13 | `trg_claim_supersession_integrity` | `claims` | BEFORE | UPDATE | superseded_by_claim_id: NULL → non-NULL (once); referenced claim must exist; no self-reference | superseded_by_claim_id vs OLD | NULL → UUID | Non-NULL changed → raise; self-reference → raise | Yes | claims (self-join) |
| 14 | `trg_relationship_supersession_integrity` | `relationships` | BEFORE | UPDATE | superseded_by_relationship_id: NULL → non-NULL (once); referenced relationship must exist; no self-reference | superseded_by_relationship_id vs OLD | NULL → UUID | Non-NULL changed → raise; self-reference → raise | Yes | relationships (self-join) |
| 15 | `trg_claim_dispute_requires_contest` | `claims` | BEFORE | UPDATE | dispute_status = 'disputed' or 'contradicted' only when ContestRecord exists for this claim | dispute_status vs OLD, contested_record_id join | pending → disputed (ContestRecord exists); pending → contradicted (ContestRecord exists); any → retracted (asserting party); any → superseded (supersession workflow) | Transition to disputed/contradicted without ContestRecord → raise | Yes | contest_records |
| 16 | `trg_relationship_dispute_requires_contest` | `relationships` | BEFORE | UPDATE | Same rule as claims: dispute_status disputed/contradicted requires ContestRecord | dispute_status vs OLD, join to contest_records | Same as trigger #15 | Same as trigger #15 | Yes | contest_records |
| 17 | `trg_display_policy_rules_update_guard` | `display_policy_rules` | BEFORE | UPDATE | UPDATE only when parent display_policies.status = draft | display_policy_id → join to display_policies.status | Update permitted on draft rules only | Parent status != 'draft' → raise | Yes | display_policies |
| 18 | `trg_display_policy_rules_delete_guard` | `display_policy_rules` | BEFORE | DELETE | DELETE only when parent display_policies.status = draft | display_policy_id → join to display_policies.status | Delete permitted on draft rules only | Parent status != 'draft' → raise | Yes | display_policies |
| 19 | `trg_contest_record_standing_validation` | `contest_records` | BEFORE | INSERT | standing_class must be recognized; initiating user must match claimed class | standing_class, initiated_by_id; joins to authority_assignments, user_person_links | INSERT when standing verified | Unrecognized standing_class → raise; initiating user does not match class → raise | Yes | authority_assignments, user_person_links |
| 20 | `trg_lifebook_person_context_completeness` | `lifebook_entities` | AFTER | INSERT | Every person-type LifeBookEntity must have a LifeBookPersonContext | entity_type, entity_id; **fires at COMMIT via DEFERRABLE INITIALLY DEFERRED** | **Must be created as `CREATE CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED`** — a plain AFTER INSERT trigger fires immediately and will block normal insert sequences; this trigger explicitly fires at transaction end so that `lifebook_person_contexts` can be inserted in the same transaction | LifeBookPersonContext missing at COMMIT → raise | Yes | lifebook_person_contexts |

### After Seed Data

| # | Trigger Name | Table | Timing | Event | Invariant Enforced | Fields Inspected | Required 0003 | Dependencies |
|---|---|---|---|---|---|---|---|---|
| 21 | `trg_claim_numeric_unit_check` | `claims` | BEFORE | INSERT, UPDATE | Full unit enforcement per CONTENT_LAYER.md §3.4: non-numeric Claims must not carry unit fields; predicates requiring a unit must have `value_unit_code`; predicates forbidding a unit must not; unit must exist and not be deprecated; unit code and category must be in predicate whitelist if specified; units with `requires_qualifier=TRUE` require non-empty `value_unit_qualifier`; units with `requires_qualifier=FALSE` require qualifier IS NULL; integer-only, min, and max value constraints enforced; all failures RAISE EXCEPTION | `value_unit_code`, `value_unit_qualifier`, `predicate_id` (join to `claim_predicates`, `claim_value_units`) | Yes — after seed commit | claim_predicates, claim_value_units |

### Audit / Invalidation

| # | Trigger Name | Table | Timing | Event | Invariant Enforced | Fields Inspected | Required 0003 | Dependencies |
|---|---|---|---|---|---|---|---|---|
| 22 | `trg_source_derivative_invalidation_cascade` | `source_derivatives` | AFTER | UPDATE | validity_state → invalid triggers AccessPolicyChangedEvent; cascades invalidation of related derivatives | validity_state vs OLD | Yes — **STUB body:** `RAISE NOTICE 'trg_source_derivative_invalidation_cascade: stub — source_derivative % validity_state changed to invalid', NEW.id; RETURN NULL;` — does NOT insert into access_policy_changed_events in stub form; full cascade logic (AccessPolicyChangedEvent insert + ContextManifest invalidation) deferred to Context Broker specification and implemented via future migration body replacement | access_policy_changed_events, context_manifests (full impl); None (stub) |

**Final trigger count: 22**

---

## §4. DisplayPolicy Enforcement — Final Implementation Specification

### 4.1 Draft — Edit and Deletion

A DisplayPolicy in `status = 'draft'` is fully editable. All fields may be updated by an actor with valid `set_by_role` authority. Rules (`display_policy_rules`) may be created, updated, or deleted while the parent policy is in draft. Draft policies carry no governance standing and are not evaluated for display decisions.

Draft deletion: trigger `trg_display_policies_delete_guard` permits DELETE only when `status = 'draft'`. RLS policy 45 enforces the same constraint at the actor layer.

### 4.2 Activation (draft → active)

Trigger `trg_display_policies_lifecycle` permits this status-only UPDATE. Once active, the policy is a permanent governance record.

Application preconditions before activation:
- All required DisplayPolicyRules are present (at least one rule per required display context)
- If `approval_record_id` is required for the authority scenario, the ApprovalRecord must exist
- The governed record's `display_policy_id` FK must be updated to the new policy UUID before or simultaneously with activation

### 4.3 Active Immutability

No field of an active DisplayPolicy may be modified except `status`. Trigger `trg_display_policies_lifecycle` enforces: any non-status field UPDATE on a non-draft record → exception. DisplayPolicyRules belonging to an active policy are fully immutable: triggers 17 and 18 enforce UPDATE and DELETE prohibition.

### 4.4 Supersession Workflow (application responsibility)

The database enforces invariants; it does not orchestrate steps. The application must execute:

1. Create successor DisplayPolicy in draft status
2. Create all DisplayPolicyRules for the successor
3. Update governed record's `display_policy_id` to the successor UUID
4. UPDATE predecessor: status → superseded (trigger permits active → superseded)
5. UPDATE successor: status → active (trigger permits draft → active)

Steps 4 and 5 may be performed in a single transaction. The governed record must never simultaneously point to two active policies.

### 4.5 Withdrawal (active → withdrawn)

Trigger permits `active → withdrawn`. Used when a policy is revoked without replacement. After withdrawal, the governed record's `display_policy_id` must be set NULL or updated to a new policy. If left NULL, fail-closed defaults apply.

### 4.6 Fail-Closed Evaluation Defaults

**When display_policy_id IS NULL:**

| Display Context Code | Default Decision |
|---|---|
| `public_ui` | deny |
| `family_ui` | deny |
| `steward_ui` | allow (steward role only) |
| `historical_record` | deny |
| `ordinary_search` | deny |
| `identity_resolution_search` | deny |
| `default_export` | deny |
| `steward_export` | allow (steward role only) |
| `ai_generation` | deny |

**When a DisplayPolicy exists but has no rule for the requested context:** deny. Missing context = deny. The application (`fn_display_policy_allows`) must return FALSE in this case.

### 4.7 Missing Context Rule Behaviour

`fn_display_policy_allows(policy_id, context_code)` must return FALSE if:
- `policy_id` is NULL
- The policy's status != 'active'
- No DisplayPolicyRule exists for the given `display_context_code` in that policy
- The rule exists but decision = 'deny'
- The rule decision = 'conditional' and the condition is not satisfied (evaluated by application)

The function returns TRUE only for an explicit `decision = 'allow'` (or a satisfied conditional).

### 4.8 Authority Provenance

Every DisplayPolicy must carry at least one of `created_by_id` (non-null UUID) or `created_by_system` (non-null text). The CHECK constraint enforces this. `set_by_role` must be a valid `authority_roles.code` value.

### 4.9 `approval_record_id` Requirements

Required (governed by applicable ApprovalPolicy) when:
- A steward modifies a subject-controlled attribute DisplayPolicy
- A cultural authority sets policy on a culturally governed record
- A steward re-activates a previously withdrawn policy

Evaluated at the application layer before activation. The schema field is a nullable deferred FK (Deferred FK 2 in migration 0003).

### 4.10 Interaction with All 11 Governed Record Types

All 11 governed record types (`claims`, `relationships`, `narratives`, `narrative_entities`, `sources`, `artifacts`, `events`, `event_participants`, `person_names`, `person_pronouns`, `person_gender_descriptors`) carry a nullable `display_policy_id` FK. Display context evaluation is application-layer via `fn_display_policy_allows`. The database RLS layer handles coarse LifeBook scoping and access_classification filtering; it does not inline display-context evaluation. Fail-closed defaults apply when the FK is NULL.

---

## §5. Cultural Governance — Enforcement Path

### 5.1 Record Identification

A record is culturally governed when `access_classification = 'culturally_governed'`. This field is present on all governed content tables. DNA sources (`source_type = 'dna_analysis'`) are automatically set to `access_classification = 'restricted'`; if the subject is also Indigenous, the steward or cultural authority must additionally set `access_classification = 'culturally_governed'` — this is not automatic.

### 5.2 Cultural Authority Resolution

Resolved by querying `authority_assignments` for an active assignment with `authority_role = 'cultural_authority'` and `effective_until IS NULL OR effective_until > now()`, scoped to the relevant entity or lifebook. Helper function `fn_has_active_authority('cultural_authority', entity_id)` executes this lookup under SECURITY DEFINER. Platform administrators do not automatically hold cultural authority.

### 5.3 Access by Actor Class

| Actor | SELECT | INSERT | UPDATE | DELETE | Notes |
|---|---|---|---|---|---|
| `cultural_authority` | Yes (own cultural scope) | Yes — with ApprovalRecord backed by policy with cultural_governance_required = TRUE | Status fields only; content immutable | No — permanent records | Primary governance actor for culturally governed content |
| `steward` | Record metadata only; culturally governed content fields governed by cultural authority | No without cultural authority involvement | No without cultural authority | No | Steward may not override cultural governance |
| `contributor` | No | No | No | No | Excluded entirely |
| `viewer` | No | No | No | No | Excluded entirely |
| `subject` | Yes only if also cultural authority | Only if also cultural authority | Only if also cultural authority | No | Subject authority does not override cultural governance |
| `agent_service` | **No — absolute exclusion** | **No — absolute exclusion** | **No — absolute exclusion** | No | Invariant 7: cultural governance overrides AI |
| `system_service` | System governance actions only | No | No | No | Background process governance only |
| `admin` | Governance audit only | No | No | No | Audit access; not content access |

### 5.4 Approval Requirements

Any consequential action on a culturally governed record requires an ApprovalRecord backed by an ApprovalPolicy with `cultural_governance_required = TRUE`:
- Creating the record with `access_classification = culturally_governed`
- Activating a DisplayPolicy for the record
- Publishing or disclosing the record to any external party
- Cross-LifeBook sharing via CrossLifeBookAuthorization
- Export (steward_export context)

### 5.5 DisplayPolicy Interaction

A DisplayPolicy may grant access to a culturally governed record for specific display contexts, with one absolute exception: the `ai_generation` display context may never be granted for a culturally governed record, regardless of what any DisplayPolicy rule says. RLS policies 37–40 enforce this exclusion independently of and prior to DisplayPolicy evaluation. Cultural governance overrides DisplayPolicy.

### 5.6 Export Restrictions

`steward_export` and `default_export` contexts default to **deny** for culturally governed records. An explicit allow rule with an ApprovalRecord (`cultural_governance_required = TRUE` policy) is required. No automated export or data pipeline may include culturally governed records without this.

### 5.7 Fail-Closed Behaviour

Absent an active DisplayPolicy with an explicit allow rule and a valid ApprovalRecord: all display contexts for culturally governed records default to **deny**. Steward cannot override this without cultural authority involvement and an ApprovalRecord. The absence of a cultural authority assignment means no authorized party exists — the record remains inaccessible until cultural authority is established.

---

## §6. AI Enforcement Boundaries

### 6.1 AI Reading Records

Agent SELECT is permitted only when ALL of the following are true:
1. `access_classification NOT IN ('restricted', 'culturally_governed')` — RLS policies 37–40, 42–44
2. `review_status = 'policy_approved'` — Context Broker application query filter
3. A DisplayPolicy with an allow rule for `ai_generation` context exists OR the record type has a system-level identity_resolution allow — `fn_display_policy_allows` evaluation
4. The ContextManifest for the current session is valid — Context Broker validation

The database RLS handles conditions 1 and partial 4. Conditions 2 and 3 are enforced by the application (Context Broker) before assembling a ContextManifest.

### 6.2 AI Generating Candidate Content

Agent may INSERT into `claims` and `narratives` with: `submission_origin = 'ai_extracted_submission'`, `review_status = 'pending'` (CHECK enforced), `evidence_status <= 'inferred'` (application enforced), `ai_generated = true` with `producing_agent_code` and `context_manifest_id` (CHECK enforced). All other INSERT targets denied by RLS.

### 6.3 AI Promoting Claims

Prohibited. RLS policy 30 denies UPDATE setting `review_status = 'policy_approved'` when `fn_user_is_agent()` is TRUE. Promotion requires a human actor and an ApprovalRecord.

### 6.4 AI Generating Events

Prohibited. RLS policy 33 denies INSERT on `events` for agent_service. A human steward must create the Event after reviewing the triggering Claim.

### 6.5 AI Using Culturally Governed Records

Absolutely prohibited. RLS policies 37–40 deny SELECT on any `access_classification = 'culturally_governed'` record for agent_service. No DisplayPolicy rule, configuration, or override may supersede this. Defense-in-depth: both database RLS and Context Broker enforce independently.

### 6.6 AI Using Denied DisplayPolicy Contexts

If a record's DisplayPolicy has decision = 'deny' for `ai_generation`, the record must not appear in any ContextManifest. Enforced by the Context Broker application via `fn_display_policy_allows`. Not enforced inline by database RLS (display context evaluation is application-layer).

### 6.7 AI Export or Summarisation

Agent output is governed by the ContextManifest. Agent may only reference records that were validly included per conditions in §6.1. ContextManifest is permanent (DELETE denied RLS policy 23). AccessPolicyChangedEvents invalidate SourceDerivatives when policy changes.

### 6.8 Human Approval Requirements

Required before AI-derived content takes effect:
- evidence_status: inferred → supported or corroborated
- review_status: human_reviewed → policy_approved
- Any AI Claim used as basis_claim_id for an AuthorityAssignment
- Any AI-generated Narrative promoted to policy_approved

**Invariant:** AI may assist, propose, derive, or draft, but may not bypass human, cultural, approval, or DisplayPolicy governance.

---

## §7. Helper Function Requirements

All helper functions must be created before RLS policies are enabled. SECURITY DEFINER functions must set `search_path = 'public', pg_temp` and be owned by a dedicated governance role.

| # | Function Name | Inputs | Return Type | Responsibility | Tables Read | SECURITY DEFINER | Volatility | Recursion Risk | Privilege Risk | Migration |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `fn_lb_membership_role` | `p_lifebook_id UUID` | `TEXT` | Returns current user's membership role ('steward','contributor','viewer','none') for the given LifeBook | `lifebook_memberships` | **Yes** — reads RLS-protected table | STABLE | None: lifebook_memberships RLS must not call this function | Low — reads only own membership rows | 0003 |
| 2 | `fn_user_is_agent` | (none) | `BOOLEAN` | Returns TRUE if current session connects as the designated agent service database role | None — uses `current_user` or `pg_has_role()` | No | STABLE | None | None | 0003 |
| 3 | `fn_is_subject_of` | `p_entity_id UUID` | `BOOLEAN` | Returns TRUE if current user has a user_person_links record pointing to the given entity | `user_person_links` | **Yes** — reads RLS-protected table | STABLE | None | Scoped to current user — low risk | 0003 |
| 4 | `fn_has_active_authority` | `p_role_code TEXT, p_entity_id UUID` | `BOOLEAN` | Returns TRUE if current user holds a non-expired AuthorityAssignment for the given role code and entity scope | `authority_assignments` | **Yes** — reads RLS-protected table | STABLE | **Risk:** if authority_assignments RLS calls fn_has_active_authority, infinite recursion results. Mitigation: authority_assignments RLS must use only fn_lb_membership_role and fn_is_subject_of — not this function | Reads authority data; scoped to current user; medium risk | 0003 |
| 5 | `fn_display_policy_allows` | `p_policy_id UUID, p_context_code TEXT` | `BOOLEAN` | Returns TRUE only for an active policy with an explicit allow rule for the context; returns FALSE for NULL policy_id, inactive policy, missing context rule, or deny/unsatisfied conditional | `display_policies`, `display_policy_rules` | **Yes** — reads RLS-protected tables | STABLE | **Risk:** if display_policies RLS calls fn_display_policy_allows, infinite recursion. Mitigation: display_policies and display_policy_rules RLS must not call this function — they use role-based checks only | Reads policy records; medium risk; scoped to provided UUID | 0003 |
| 6 | `fn_has_source_access_grant` | `p_source_id UUID` | `BOOLEAN` | Returns TRUE if current user's LifeBook has a LifeBookSourceAccess record for the given source via valid CrossLifeBookAuthorization | `lifebook_source_access`, `cross_lifebook_authorizations` | **Yes** — reads RLS-protected tables | STABLE | None | Cross-LifeBook check; sensitive data; medium risk | 0003 |
| 7 | `fn_has_community_authorization` | `p_lifebook_id UUID` | `BOOLEAN` | Returns TRUE if the LifeBook has a valid ApprovalRecord backing community authorization for community_account narrative creation | `approval_records`, `approval_policies` | **Yes** — reads RLS-protected tables | STABLE | None | Reads approval chain; medium risk | 0003 |
| 8 | `fn_has_contest_standing` | `p_table TEXT, p_record_id UUID, p_standing_class TEXT` | `BOOLEAN` | Returns TRUE if current user belongs to the claimed standing class for the contested record; validates subject link, steward membership, asserting party, affected party, or authority assignment | `user_person_links`, `authority_assignments`, `lifebook_memberships`; targeted join to contested record table | **Yes** — reads multiple RLS-protected tables | STABLE | **Risk:** contested record table read could trigger RLS calling this function. Mitigation: use targeted parameterized lookup that does not trigger full RLS evaluation | Complex; reads multiple tables; must be carefully audited before deployment | 0003 |
| 9 | `fn_generate_artifact_signed_url` | `p_artifact_id UUID, p_display_context TEXT` | `TEXT` | Validates actor authority + DisplayPolicy for the artifact and display context; if allowed, generates and returns a signed storage URL; returns NULL if any check fails; never returns object_key | `artifacts`, `display_policies`, `display_policy_rules`, `file_storage_references`, storage API | **Yes** — reads multiple RLS-protected tables + calls storage API | VOLATILE | None | Highest privilege function; must never return URL if access check fails; must not expose object_key under any failure path | 0003 (stub) — full implementation requires storage integration |

**Total helper functions: 9**

**SECURITY DEFINER count:** 8 of 9 (all except `fn_user_is_agent`).

**Recursion risk summary:** Three functions carry recursion risk (fn_has_active_authority, fn_display_policy_allows, fn_has_contest_standing). In each case, the mitigation is that the RLS policies on the tables they read must not call those functions. This constraint must be verified during RLS policy authoring.

---

## §8. Enforcement Ownership

| Governance Rule | Primary Owner | Secondary (Defense-in-Depth) | Secondary Justification |
|---|---|---|---|
| Claim at-least-one-value | CHECK constraint | Trigger #1 | Explicit error message; belt-and-suspenders for constraint violation |
| AI provenance fields required | CHECK constraint | Application | CHECK is authoritative |
| Claim content immutability | Trigger #3 | RLS (actor scope) | Trigger enforces field-level; RLS enforces actor-level |
| Relationship content immutability | Trigger #4 | RLS | Same as Claims |
| Claim dispute requires ContestRecord | Trigger #15 | Application | Trigger is authoritative; application pre-validates |
| Claim supersession integrity | Trigger #13 | Application | Trigger enforces FK integrity |
| Relationship supersession integrity | Trigger #14 | Application | Same as Claims |
| DNA source classification | Trigger #5 | — | Single enforcer; coercion is sufficient |
| Source type immutability | Trigger #6 | — | Single enforcer |
| Source lifebook immutability | Trigger #7 | — | Single enforcer |
| Event source_claim_id immutability | Trigger #8 | Application | Trigger is authoritative |
| DisplayPolicy lifecycle (activation, supersession, withdrawal) | Trigger #11 | RLS #46 | Trigger enforces transitions; RLS enforces actor scope |
| DisplayPolicy draft delete only | Trigger #12 + RLS #45 | — | Delete is irreversible; defense-in-depth required |
| DisplayPolicyRule immutability | Triggers #17, #18 | — | Single enforcer sufficient |
| ApprovalRecord immutability | RLS #49 + Trigger #9 | — | Approval chain is the audit basis; defense-in-depth required |
| Authority assignment revocation only | Trigger #10 + RLS #50 | — | Revocation is consequential; defense-in-depth required |
| LifeBook scoping (content tables) | RLS policies #1–14 | Application | RLS is primary; application adds additional scoping |
| Permanent records (no DELETE) | RLS policies #16–29 | — | Single enforcer; universal deny |
| AI promotion restriction | RLS #30, #32 | Application | Database + workflow both enforce |
| AI dispute restriction | RLS #31 | Application | Same |
| AI Event creation denied | RLS #33 | Application | Events have governance consequences; defense-in-depth |
| AI ApprovalRecord denied | RLS #34 | Application | Critical boundary; defense-in-depth required |
| AI source creation denied | RLS #35 | Application | Same |
| Culturally governed AI exclusion | RLS #37–40 + Application (Context Broker) | — | **Defense-in-depth mandatory** per Invariant 7 |
| Restricted artifact access | RLS #42 | — | Single enforcer |
| Culturally governed artifact access | RLS #43 + fn_has_active_authority | Application | Cultural boundary warrants defense-in-depth |
| ContestRecord standing | Trigger #19 + RLS #51 | Application | Trigger validates at write; RLS restricts actor |
| Fail-closed DisplayPolicy evaluation | Application (fn_display_policy_allows) | Documented defaults (§4.6) | DB cannot inline display context evaluation; documented defaults are authoritative fallback |
| Subject authority over own attributes | Application (authority hierarchy) | — | Schema cannot enforce authority hierarchy; application is sole enforcer |
| Cultural authority requirement for ApprovalRecord | Application (policy lookup before INSERT) | — | Governance rule; application is sole enforcer |
| Signed URL policy evaluation | SECURITY DEFINER fn_generate_artifact_signed_url | Application | Function is sole gatekeeper for URL issuance; never expose object_key |

---

## §9. Implementation Order

The following is the authoritative implementation sequence for Migration 0003. Do not deviate from this order.

### Phase 1 — Tables

Execute in dependency batch order per MIGRATION_0003_PROPOSAL.md:

```
Batch 1:  jurisdictions, persons, user_profiles, organizations
Batch 2:  entities (LifeBookEntity subtypes), entity_match_candidates
Batch 3:  event_series
Batch 4:  lifebooks, lifebook_memberships, user_person_links,
          lifebook_entities, lifebook_person_contexts (no permission_cache_approval_policy FK yet)
          [Internal order: lifebook_entities first, lifebook_person_contexts second]
Batch 5:  escalation_policies, approval_policies, conflict_resolution_policies,
          display_policies (no approval_record_id FK yet), display_policy_rules
Batch 6:  approval_records
Batch 7:  authority_assignments (no basis_claim_id FK yet)
Batch 8:  claim_predicates, claim_value_units, relationship_types
Batch 9:  agent_registry, context_profiles
Batch 10: sources, claims (superseded_by_claim_id inline self-FK),
          claim_evidence,
          relationships (superseded_by_relationship_id inline self-FK),
          narratives, narrative_entities,
          events (source_claim_id inline FK → claims),
          event_participants, artifacts, artifact_source_links
Batch 11: context_manifests, source_derivatives
Batch 12: merge_records, cross_lifebook_authorizations, lifebook_source_access
Batch 13: contest_records, escalation_records, escalation_notifications,
          access_policy_changed_events
Batch 14: person_names, person_name_derivatives, person_pronouns,
          person_gender_descriptors
```

### Phase 2 — Deferred Foreign Keys

```
ALTER TABLE authority_assignments ADD CONSTRAINT fk_authority_basis_claim
  FOREIGN KEY (basis_claim_id) REFERENCES claims(id);
-- [Deferred FK 1 — inserted after Batch 10 claims DDL]

ALTER TABLE display_policies ADD CONSTRAINT fk_display_policy_approval_record
  FOREIGN KEY (approval_record_id) REFERENCES approval_records(id);
-- [Deferred FK 2 — inserted after Batch 6 approval_records DDL]

ALTER TABLE lifebook_person_contexts ADD CONSTRAINT fk_permission_cache_approval_policy
  FOREIGN KEY (permission_cache_policy_version_id) REFERENCES approval_policies(id);
-- [Deferred FK 3 — inserted after Batch 5 approval_policies DDL]
```

### Phase 3 — Indexes

Create before helper functions (functions depend on efficient lookups):

```
idx_lifebook_memberships_user_lifebook    ON lifebook_memberships(user_id, lifebook_id)
idx_authority_assignments_role_entity     ON authority_assignments(authority_role, entity_id)
idx_authority_assignments_expiry          ON authority_assignments(effective_until) WHERE effective_until IS NOT NULL
idx_claims_lifebook_review_access         ON claims(lifebook_id, review_status, access_classification)
idx_display_policy_rules_policy_context   ON display_policy_rules(display_policy_id, display_context_code)
idx_user_person_links_user_entity         ON user_person_links(user_id, entity_id)
idx_contest_records_contested_record      ON contest_records(contested_record_table, contested_record_id)
```

### Phase 4 — Helper Functions

Create in dependency order:

```
1. fn_user_is_agent            (no table dependencies)
2. fn_lb_membership_role       (reads lifebook_memberships)
3. fn_is_subject_of            (reads user_person_links)
4. fn_has_active_authority     (reads authority_assignments)
5. fn_display_policy_allows    (reads display_policies, display_policy_rules)
6. fn_has_source_access_grant  (reads lifebook_source_access, cross_lifebook_authorizations)
7. fn_has_community_authorization (reads approval_records, approval_policies)
8. fn_has_contest_standing     (reads multiple tables)
9. fn_generate_artifact_signed_url (reads artifacts + storage API)
```

Verify SECURITY DEFINER, search_path, and ownership on functions 1, 3–9 before proceeding.

### Phase 5 — Triggers

Create in two passes:

**Pass A — no cross-table dependencies:**
```
trg_claim_value_not_null
trg_claim_ai_provenance
trg_claim_content_immutable
trg_relationship_content_immutable
trg_source_dna_classification
trg_source_type_immutable
trg_source_lifebook_immutable
trg_event_provenance_immutable
trg_approval_records_immutable
trg_authority_assignment_revocation_guard
trg_display_policies_lifecycle
trg_display_policies_delete_guard
```

**Pass B — after all referenced tables exist:**
```
trg_claim_supersession_integrity
trg_relationship_supersession_integrity
trg_claim_dispute_requires_contest
trg_relationship_dispute_requires_contest
trg_display_policy_rules_update_guard
trg_display_policy_rules_delete_guard
trg_contest_record_standing_validation
trg_lifebook_person_context_completeness
trg_source_derivative_invalidation_cascade
```

**Pass C — after seed data committed:**
```
trg_claim_numeric_unit_check
```

### Phase 6 — Enable RLS

```
ALTER TABLE claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE narratives ENABLE ROW LEVEL SECURITY;
ALTER TABLE narrative_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE artifacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE display_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE display_policy_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE authority_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE contest_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE person_names ENABLE ROW LEVEL SECURITY;
ALTER TABLE person_pronouns ENABLE ROW LEVEL SECURITY;
ALTER TABLE person_gender_descriptors ENABLE ROW LEVEL SECURITY;
ALTER TABLE person_name_derivatives ENABLE ROW LEVEL SECURITY;
ALTER TABLE context_manifests ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_policy_changed_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE source_derivatives ENABLE ROW LEVEL SECURITY;
ALTER TABLE lifebook_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE claim_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE artifact_source_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE lifebook_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE lifebook_person_contexts ENABLE ROW LEVEL SECURITY;
```

Total: 25 tables with RLS enabled.

### Phase 7 — RLS Policies

Create in groups to respect function dependencies:

```
Group A: DELETE denied (policies 16–29, 59, 65) — no function dependencies
Group B: UPDATE immutability (policy 49) — no function dependencies
Group C: LifeBook-scoped SELECT (policies 1–15, 66–68, 70) — after fn_lb_membership_role
         Policies 1–15: content and attribute tables
         Policy 66: approval_records SELECT (NOT fn_user_is_agent())
         Policy 67: display_policies SELECT (NOT fn_user_is_agent())
         Policy 68: display_policy_rules SELECT (NOT fn_user_is_agent())
         Policy 70: source_derivatives SELECT (EXISTS join to sources via fn_lb_membership_role)
Group D: INSERT and AI restrictions (policies 30–36, 41, 47, 51, 69, 71) — after fn_user_is_agent, fn_lb_membership_role
         Policy 69: person_name_derivatives INSERT (NOT fn_user_is_agent())
         Policy 71: source_derivatives INSERT (NOT fn_user_is_agent())
Group E: Cultural and classification (policies 37–44) — after fn_has_active_authority
Group F: DisplayPolicy lifecycle (policies 45–48) — after fn_has_active_authority
Group G: Governance (policies 50, 52–53) — after fn_lb_membership_role, fn_has_contest_standing
Group H: LifeBook entity access (policies 54–58, 60–64) — after fn_lb_membership_role, fn_is_subject_of, fn_user_is_agent
```

### Phase 8 — Grants

Minimum-privilege grants after RLS is active:

```
authenticated role: SELECT, INSERT, UPDATE on content tables (RLS restricts actors further)
agent_service role: SELECT on claims, narratives, sources, artifacts, events; INSERT on claims, narratives
system_service role: SELECT all; INSERT on approval_records, context_manifests, source_derivatives, access_policy_changed_events, lifebook_person_contexts; UPDATE on lifebook_person_contexts (cache fields only)
admin role: SELECT all; no RLS bypass (admin is not a superuser)
```

Column restriction on `file_storage_references.object_key` is deferred to the storage integration migration (W11 — DP Decision 2026-07-25). This restriction is not authored in Migration 0003.

### Phase 9 — Validation Queries

```
1.  RLS active:      SELECT tablename FROM pg_tables WHERE rowsecurity = TRUE
                     — must include all 25 governed tables listed in Phase 6
2.  Trigger count:   SELECT count(*) FROM information_schema.triggers
                     — must equal 22 (all triggers created)
3.  Function count:  SELECT count(*) FROM pg_proc WHERE proname LIKE 'fn_%'
                     — must equal 9 helper functions
4.  Fail-closed:     SELECT count(*) FROM claims -- as unauthenticated role
                     — must return 0 rows or permission denied
5.  Agent exclusion: SELECT count(*) FROM claims WHERE access_classification = 'culturally_governed'
                     -- as agent_service role
                     — must return 0 rows
6.  Permanence:      DELETE FROM claims LIMIT 1 -- must fail with RLS error
7.  Immutability:    UPDATE claims SET predicate_id = predicate_id WHERE id = <any_id>
                     -- must fail with trigger error
8.  Policy guard:    INSERT INTO display_policy_rules (display_policy_id, ...) VALUES (<active_policy_id>, ...)
                     -- must fail with trigger error
9.  Deferred FK:     SELECT conname FROM pg_constraint WHERE conname IN
                     ('fk_authority_basis_claim', 'fk_display_policy_approval_record',
                      'fk_permission_cache_approval_policy')
                     — must return 3 rows
10. Supersession:    UPDATE claims SET superseded_by_claim_id = id WHERE id = <any_id>
                     — must fail with trigger error (self-reference)
11. Policy count:    SELECT count(*) FROM pg_policies WHERE schemaname = 'public'
                     — must equal 71
12. Partial index:   SELECT indexname FROM pg_indexes WHERE tablename = 'lifebook_entities'
                     AND indexname = 'uq_lifebook_entities_active'
                     — must return 1 row (confirms partial unique index, not table-level UNIQUE)
```

### Phase 10 — Migration Verification

- Record migration hash in migration_log
- Confirm Supabase migration applied cleanly with no errors
- Commit migration file per MIGRATION_PHILOSOPHY.md §7 format
- Update PRE_SQL_READINESS_REVIEW.md gate status to: MIGRATION 0003 COMPLETE

---

## §10. Final Readiness Assessment

### Unresolved Implementation Decisions

None.

### Unresolved Architectural Decisions

None. Architecture is complete per GOVERNANCE_ENFORCEMENT_MODEL.md v0.2 §16.

### Counts

| Item | Count | Notes |
|---|---|---|
| RLS policies | **71** | 53 (v3.0) → 65 (Group H addition) → 71 (pre-authoring blocker resolution: +6) |
| Triggers | **22** | |
| Helper functions | **9** | |

### Migration Readiness

| Migration | Ready | Notes |
|---|---|---|
| Migration 0002 | **Yes — ready to author** | enum DDL + display_contexts table + 9 seed records; no blockers |
| Migration 0003 | **Yes — ready to author after 0002 is applied** | Full implementation specification complete; authoring sequence in §9 is authoritative |

### SQL Authoring Status

Pre-authoring blocker resolution complete as of 2026-07-25. The following items are now resolved in this document and in DATABASE_OBJECT_REGISTRY.md:

- **B1 resolved:** `trg_lifebook_person_context_completeness` specified as CONSTRAINT TRIGGER DEFERRABLE INITIALLY DEFERRED (§3)
- **S1 resolved:** Policies 30, 31, 32 now have explicit USING and WITH CHECK clauses (§2.3)
- **S2 resolved:** Policies 11–14 now have full multi-hop correlated subquery join path (§2.1)
- **R1 resolved:** `lifebook_entities` UNIQUE constraint is a partial index (`WHERE removed_at IS NULL`) — permits re-add after soft-delete (DATABASE_OBJECT_REGISTRY.md §DDL)
- **R3 resolved:** `fn_has_contest_standing` whitelist enumerated — 9 tables (DATABASE_OBJECT_REGISTRY.md §Functions)
- **R4 resolved:** `fn_generate_artifact_signed_url` stub body returns NULL immediately; does not reference `file_storage_references` (DATABASE_OBJECT_REGISTRY.md §Functions)
- **R5 resolved:** Policy 50 updated for NULL lifebook_id; entity-scoped revocation routed through SECURITY DEFINER (§2.8)
- **R6 resolved:** `trg_source_derivative_invalidation_cascade` stub body specified — RAISE NOTICE only, no AccessPolicyChangedEvent insert (§3)
- **G1 resolved:** 3 intentional no-SELECT tables documented; 4 SELECT policies added (66–68, 70)
- **G2 resolved:** Policy 69 added — person_name_derivatives INSERT
- **G3 resolved:** Policies 70–71 added — source_derivatives SELECT and INSERT
- **DNA trigger coerce/raise condition resolved:** `trg_source_dna_classification` now specifies coerce-on-NULL vs raise-on-explicit-non-restricted (§3)

**Remaining blocked items (require DP decision before those specific SQL sections):**
- B2: Batch 14 SQL blocked — Pre-Authoring Confirmation A (PERSON_ATTRIBUTE_CATALOGUE.md G2 update)
- B3: Batch 8 seed blocked — ClaimPredicate 74-record file not yet authored

**Architecture remains complete. Remaining work is SQL authoring.**

---

*No SQL has been written. No RLS syntax has been written. No trigger function bodies have been written. This document is the complete implementation specification for Migration 0003. Migration 0002 SQL authoring may begin immediately. Migration 0003 SQL authoring may begin after Migration 0002 is applied and verified. Batch 14 and Batch 8 seed sections require pre-authoring confirmations B2 and B3 respectively.*
