# LifeBook Operational Models
**Version:** 0.1 Draft  
**Status:** Pre-schema design document  
**Depends on:** GOVERNANCE_MODELS.md, AI_CONTEXT_BROKER.md  
**Produced:** 2026-07-23  

Covers: EscalationPolicy · ContestRecord · Jurisdiction · JurisdictionPolicyVersion · EscalationRecord

---

## 1. EscalationPolicy

EscalationPolicy defines what happens when a governance process cannot complete through its normal pathway — because a required approver is unavailable, a conflict cannot be resolved, a validation step fails, or no authority assignment covers the requested action.

EscalationPolicy is referenced by ApprovalPolicy, ConflictResolutionPolicy, and the Context Broker's cannot-classify handler.

### 1.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `policy_code` | String | Human-readable (e.g., `APPROVAL_TIMEOUT_STEWARD_FALLBACK`) |
| `trigger_type` | Enum | See §1.2 |
| `description` | Text | What this policy handles |
| `initial_notification_targets` | Array\<AuthorityRole\> | Roles notified immediately when the trigger fires |
| `steps` | JSONB Array\<EscalationStep\> | Ordered steps; see §1.3 |
| `max_resolution_days` | Integer | SLA ceiling; nullable for open-ended cultural or legal processes |
| `default_action_if_unresolved` | Enum | See §1.4 |
| `freeze_actions_during_escalation` | Array\<ActionType\> | Actions that are blocked while this escalation is open |
| `audit_required` | Boolean | Default true |
| `notes` | Text | Nullable |

### 1.2 trigger_type values

| Value | Description |
|---|---|
| `approval_timeout` | A required approver has not responded within the ApprovalPolicy's approval_expiry_days |
| `no_authority_assigned` | A requested action has no applicable AuthorityAssignment |
| `unresolvable_conflict` | ConflictResolutionPolicy returned `escalate_external` or `steward_decides` but no active steward exists |
| `validation_violation` | Context Broker output validation detected restricted content in model output |
| `cannot_classify` | Sanitization Pipeline encountered content it could not safely classify |
| `dispute_opened` | A ContestRecord has been created; affected actions must be frozen |
| `dispute_unresolved` | A ContestRecord has exceeded its resolution SLA |
| `cultural_protocol_triggered` | An action requires culturally_governed_processing but no joint authorization exists |
| `agent_deprecated` | An active agent run was invalidated by agent deprecation |
| `capacity_change_mid_action` | A capacity change occurred while an approval workflow was in progress |
| `stewardship_gap` | Stewardship has ended with no succession record and no new steward assigned |

### 1.3 EscalationStep structure (JSONB)

Each step in the `steps` array:

```json
{
  "step_number": 1,
  "label": "Notify steward",
  "wait_period_hours": 48,
  "notify_roles": ["steward", "legal_representative"],
  "required_action": "approve_or_delegate",
  "action_options": ["approve", "delegate_to_named", "extend_deadline", "escalate_external"],
  "if_no_action": "proceed_to_next_step",
  "notes": null
}
```

| Field | Options |
|---|---|
| `required_action` | `approve_or_delegate` · `review_and_confirm` · `provide_documentation` · `designate_successor` · `external_referral` · `human_decision` |
| `if_no_action` | `proceed_to_next_step` · `freeze` · `deny` · `apply_policy_default` · `route_external` |

### 1.4 default_action_if_unresolved values

| Value | Meaning |
|---|---|
| `freeze` | Block the affected action indefinitely; preserve state; notify parties |
| `deny` | Reject the action; audit; notify parties |
| `apply_policy_default` | Apply the `policy_default` authority_basis_type rules |
| `route_to_steward` | Transfer to any available active steward |
| `route_external` | Flag for external legal or community process; LifeBook does not resolve |
| `terminate_agent_run` | For agent_deprecated trigger: safely terminate the in-progress agent run |

### 1.5 Representative EscalationPolicy records

**`APPROVAL_TIMEOUT_STEWARD_FALLBACK`**  
Trigger: `approval_timeout` · Max resolution: 14 days  
Steps: (1) Re-notify required approver, 48h wait → (2) Notify steward, 72h wait → (3) Freeze  
Default if unresolved: `freeze`

**`NO_AUTHORITY_STEWARD_NOTIFY`**  
Trigger: `no_authority_assigned` · Max resolution: 7 days  
Steps: (1) Notify steward immediately → (2) Apply policy_default if no steward response within 7 days  
Default if unresolved: `apply_policy_default`  
Note: For consequential actions (publish, merge, stewardship transfer), default_action_if_unresolved is `freeze`, not `apply_policy_default`

**`VALIDATION_VIOLATION_QUARANTINE`**  
Trigger: `validation_violation` · Max resolution: none (human must resolve)  
Steps: (1) Quarantine output immediately · (2) Notify steward within 1 hour  
Default if unresolved: `freeze`  
Note: Quarantined output is never released without explicit steward authorization and re-validation

**`CANNOT_CLASSIFY_REVIEW`**  
Trigger: `cannot_classify` · Max resolution: 30 days  
Steps: (1) Quarantine unclassified content · (2) Notify steward within 24h · (3) Steward classifies or discards  
Default if unresolved: `deny` (unclassified content is discarded after 30 days if no steward action)

**`CULTURAL_PROTOCOL_DENY`**  
Trigger: `cultural_protocol_triggered` · Max resolution: none (no SLA — community process governs)  
Steps: (1) Deny immediately · (2) Notify subject and appropriate community liaison (if known) · (3) Await joint authorization — no timeline imposed by LifeBook  
Default if unresolved: `freeze` indefinitely  
Note: LifeBook does not set a deadline for culturally governed processes

**`DISPUTE_OPENED_FREEZE`**  
Trigger: `dispute_opened` · Max resolution: 90 days (adjustable; external legal may exceed)  
Steps: (1) Freeze all actions in ContestRecord.freeze_actions immediately · (2) Notify all affected authority holders within 24h · (3) Route to dispute resolution process · (4) At 60 days: notify parties of SLA · (5) At 90 days: route_external if unresolved  
Default if unresolved: `route_external`

**`STEWARDSHIP_GAP_NOTIFY`**  
Trigger: `stewardship_gap` · Max resolution: 30 days  
Steps: (1) Notify next_of_kin and legal_representative if available · (2) Apply restricted read-only state · (3) At 30 days: freeze all write operations pending steward assignment  
Default if unresolved: `freeze`

---

## 2. ContestRecord

ContestRecord is the formal record of a dispute over authority, identity, access, or a specific governance decision. Opening a ContestRecord triggers the appropriate EscalationPolicy and freezes affected actions.

### 2.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `contest_type` | Enum | See §2.2 |
| `person_ids_involved` | Array\<UUID\> | Person anchors whose records are affected |
| `attribute_ids_contested` | Array\<UUID\> | Nullable; specific attribute records in dispute |
| `action_types_contested` | Array\<ActionType\> | Which actions are disputed |
| `initiated_by_id` | UUID FK | User who opened the contest |
| `initiated_at` | Timestamp | |
| `affected_authority_assignment_ids` | Array\<UUID\> | AuthorityAssignment records whose authority is in question |
| `claimant_positions` | JSONB | See §2.3 |
| `status` | Enum | See §2.4 |
| `freeze_actions` | Array\<ActionType\> | Actions frozen for the duration of this contest |
| `escalation_policy_id` | UUID FK | FK to EscalationPolicy (typically `DISPUTE_OPENED_FREEZE`) |
| `escalation_record_id` | UUID FK | The active EscalationRecord for this contest |
| `resolution_type` | Enum | See §2.5; nullable until resolved |
| `resolution_summary` | Text | Human-authored summary of resolution; nullable |
| `resolution_authority_role` | AuthorityRole | The role that resolved the contest; nullable |
| `resolution_authority_id` | UUID FK | The person or process that resolved; nullable |
| `resolved_at` | Timestamp | Nullable |
| `resulting_authority_assignment_ids` | Array\<UUID\> | New or modified AuthorityAssignment records created on resolution |
| `access_during_contest` | Enum | See §2.6 |
| `created_at` | Timestamp | |
| `notes` | Text | Internal record; not shown to disputing parties without steward authorization |

### 2.2 contest_type values

| Value | Description |
|---|---|
| `authority_dispute` | Two or more parties each claim authority to assert or approve an action |
| `identity_claim_dispute` | A party disputes the accuracy of an identity attribute (e.g., family claims the subject's recorded preferred name is wrong) |
| `merge_dispute` | Parties disagree on whether two Person records represent the same individual |
| `split_dispute` | A party claims a merged Person record incorrectly combines two different individuals |
| `access_dispute` | A party believes they should have access rights they do not currently hold |
| `posthumous_disclosure_dispute` | Disagreement about what may be disclosed or displayed after the subject's death |
| `cultural_authority_dispute` | Disagreement about whether a community authority legitimately governs specific information, or about which community authority applies |
| `capacity_determination_dispute` | A party disputes a capacity determination that is restricting or granting authority |
| `stewardship_dispute` | Disagreement about who holds or should hold stewardship |

### 2.3 claimant_positions JSONB structure

```json
[
  {
    "claimant_id": "uuid",
    "claimant_role": "guardian_joint",
    "authority_assignment_id": "uuid",
    "position_summary": "Claimant asserts that...",
    "evidence_ids": ["uuid", "uuid"],
    "submitted_at": "2026-07-23T10:00:00Z"
  }
]
```

Each party to the dispute submits their position independently. Positions are recorded verbatim and are not accessible to other disputing parties without steward authorization, to prevent escalation of the dispute within the system.

### 2.4 status values

| Value | Description |
|---|---|
| `open` | Dispute is active; frozen actions are blocked |
| `under_review` | A steward or designated reviewer is actively evaluating |
| `pending_external` | Routed to an external legal, cultural, or community process; LifeBook is awaiting outcome |
| `resolved` | Resolution recorded; frozen actions may resume per the resolution terms |
| `closed_without_resolution` | Dispute closed without a definitive resolution (e.g., both parties withdrew); state preserved; frozen actions remain frozen until a steward makes a separate determination |
| `superseded` | A later ContestRecord or external determination has superseded this one |

### 2.5 resolution_type values

| Value | Description |
|---|---|
| `authority_determination` | LifeBook governance determined which party holds authority |
| `consent_agreement` | Disputing parties reached agreement |
| `external_legal` | Resolved by court order or equivalent legal instrument |
| `community_decision` | Resolved by community authority (for cultural_authority_dispute) |
| `steward_decision` | Steward made a governance determination within their scope |
| `withdrawn` | All disputing parties withdrew their contest |
| `subject_asserts` | For identity_claim_dispute: subject's own assertion resolved the dispute per ConflictResolutionPolicy |

### 2.6 access_during_contest values

| Value | Meaning |
|---|---|
| `read_only_all_parties` | All pre-contest access rights maintained as read-only; no new write access granted |
| `read_only_steward_only` | Only the steward may access during contest; other parties restricted |
| `frozen` | No access to contested records except by system for preservation |
| `per_party_isolation` | Each party may access only their own view; parties cannot see each other's records or positions |

Default for all contest_types is `per_party_isolation` unless the EscalationPolicy specifies otherwise.

### 2.7 What ContestRecord does not do

- ContestRecord does not adjudicate disputes. It records them and freezes affected actions.
- ContestRecord does not assess legal capacity. It records that capacity is disputed.
- ContestRecord does not expose one party's position to another without explicit steward authorization.
- ContestRecord does not automatically resolve. Resolution requires a human action or an external determination, recorded in resolution_type and resolution_summary.

---

## 3. Jurisdiction

Jurisdiction captures the legal and regulatory context that governs how LifeBook handles data for persons associated with that jurisdiction. Multiple jurisdictions may apply to a single person or interaction.

### 3.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `jurisdiction_code` | String | ISO 3166-1 or ISO 3166-2 code (e.g., `CA`, `CA-AB`, `UA`, `EU`) |
| `jurisdiction_name` | String | Human-readable name |
| `jurisdiction_type` | Enum | See §3.2 |
| `parent_jurisdiction_id` | UUID FK | Nullable; for provincial → national hierarchy |
| `age_of_majority` | Integer | Default age in years; nullable if jurisdiction-specific rules apply |
| `age_of_majority_notes` | Text | Exceptions, emancipation rules, context dependencies |
| `has_sdm_legislation` | Boolean | Whether supported decision-making is recognized in legislation |
| `sdm_legislation_reference` | Text | Citation; nullable |
| `privacy_law_primary` | String | Primary applicable privacy law (e.g., PIPEDA, GDPR, PIPA-AB) |
| `privacy_law_reference` | Text | Citation and version |
| `right_to_erasure` | Enum | See §3.3 |
| `erasure_notes` | Text | How right_to_erasure interacts with LifeBook's provenance preservation model |
| `data_residency_required` | Boolean | Whether data must reside within this jurisdiction |
| `data_residency_notes` | Text | Nullable |
| `cross_border_transfer_rules` | Text | Conditions under which data may leave this jurisdiction |
| `succession_law_notes` | Text | Relevant succession rules for deceased persons' data |
| `guardian_coordination_presumption` | Enum | Default joint guardian coordination rule if no AuthorityAssignment specifies otherwise |
| `lifebook_policy_overrides` | JSONB | Jurisdiction-specific overrides to LifeBook default policies |
| `is_active` | Boolean | |
| `notes` | Text | Nullable |

### 3.2 jurisdiction_type values

| Value | Description |
|---|---|
| `national` | A sovereign nation |
| `provincial_or_state` | A subnational unit with its own privacy or personal information legislation |
| `indigenous_nation` | A First Nation, Métis nation, or equivalent sovereign or self-governing entity |
| `supranational` | A multi-national legal framework (e.g., EU GDPR applies across member states) |
| `international_default` | The fallback when no more specific jurisdiction applies |

### 3.3 right_to_erasure values

| Value | Meaning for LifeBook |
|---|---|
| `strong` | Subject may require deletion of personal data; LifeBook must accommodate while preserving mandatory provenance records |
| `qualified` | Subject may request erasure subject to conditions; LifeBook may retain certain records for legitimate purposes |
| `limited` | No general right to erasure; subject may request correction only |
| `none_specified` | Jurisdiction has not specified a right to erasure in applicable law |

**Erasure and provenance:** LifeBook's provenance model requires that all changes be logged and that original records not be silently destroyed. In jurisdictions with `strong` erasure rights, LifeBook must implement erasure as: redact the personal data values; retain the structural record (that a record existed, that an action occurred) without the personal data content. The log of the erasure action itself is retained. This interpretation must be validated against applicable law per jurisdiction.

### 3.4 guardian_coordination_presumption values

Default applied when no AuthorityAssignment specifies a coordination_rule for joint guardians in this jurisdiction.

| Value | Description |
|---|---|
| `joint_unanimous` | All joint guardians must agree (default for most Canadian jurisdictions) |
| `joint_any` | Any guardian may act alone (some jurisdictions presume this for day-to-day decisions) |
| `unclear` | No statutory presumption; LifeBook applies `escalate` if coordination_rule is unspecified |

### 3.5 Launch jurisdiction records

The following jurisdictions must be populated before the migration is run. Entries marked `REQUIRED` are blocking; entries marked `RECOMMENDED` may be added post-launch.

| Code | Name | Type | Privacy law | Right to erasure | Age of majority | SDM | Priority |
|---|---|---|---|---|---|---|---|
| `CA` | Canada | national | PIPEDA (federal) | qualified | 18 (federal default) | No federal legislation | REQUIRED |
| `CA-AB` | Alberta | provincial | PIPA (AB) | qualified | 18 | No provincial legislation | REQUIRED |
| `CA-ON` | Ontario | provincial | PIPEDA (private sector) | qualified | 18 | SDM legislation: Substitute Decisions Act, 1992 | REQUIRED |
| `CA-BC` | British Columbia | provincial | PIPA (BC) | qualified | 19 | SDM: Representation Agreement Act | REQUIRED |
| `CA-QC` | Quebec | provincial | Law 25 (Bill 64) | strong | 18 | No specific SDM legislation | REQUIRED |
| `CA-MB` | Manitoba | provincial | PIPEDA (private sector) | qualified | 18 | The Vulnerable Persons Living with a Mental Disability Act (limited) | RECOMMENDED |
| `UA` | Ukraine | national | Law on Personal Data Protection | qualified | 18 | No specific SDM legislation | REQUIRED |
| `EU` | European Union | supranational | GDPR | strong | 16–18 (varies by member state) | Varies by member state | REQUIRED |
| `US-CA` | California | provincial_or_state | CCPA / CPRA | qualified | 18 | No specific SDM legislation | RECOMMENDED |
| `INTL` | International Default | international_default | Most restrictive applicable | strong | 18 | Assume none | REQUIRED |

### 3.6 Jurisdiction-specific policy overrides (lifebook_policy_overrides)

The `lifebook_policy_overrides` JSONB field captures where a jurisdiction requires different default behavior from LifeBook's general policy.

Examples:

**CA-QC (Quebec — Law 25):**
```json
{
  "default_export_requires_explicit_consent": true,
  "ai_profiling_requires_disclosure": true,
  "right_to_erasure_applies_to_inferred_data": true,
  "retention_limit_deceased_years": null
}
```

**EU (GDPR):**
```json
{
  "right_to_erasure_applies_to_inferred_data": true,
  "data_portability_required": true,
  "automated_decision_disclosure_required": true,
  "cross_border_transfer_requires_adequacy_or_sccs": true,
  "dpo_notification_required_for_breach": true
}
```

**CA (PIPEDA federal):**
```json
{
  "consent_required_for_collection": true,
  "right_to_access_own_data": true,
  "breach_notification_required": true,
  "cross_border_transfer_permitted_with_comparable_protection": true
}
```

### 3.7 Jurisdiction and the provenance–erasure tension

The fundamental tension: LifeBook's provenance model requires an append-only audit record so that the history of every change is traceable. Several jurisdictions grant a right to erasure that appears to conflict with this.

LifeBook's resolution, which must be validated per jurisdiction before deployment:

1. Personal data values are redacted (replaced with a redaction marker).
2. The structural record remains: a claim existed, an action occurred, a change was made.
3. The redaction action itself is recorded in the audit log with timestamp and authority basis.
4. The audit log of the redaction does not contain the redacted value.
5. Embeddings, search indexes, sanitized summaries, and identity-resolution tokens derived from the redacted data are invalidated via the `AccessPolicyChanged` event (trigger: `deletion_or_redaction`).

This interpretation treats the right to erasure as a right to erasure of the personal data content, not a right to erasure of the fact that the person interacted with the system. Whether this interpretation is legally sufficient must be confirmed per jurisdiction before launch.

---

## 4. Open Questions Requiring Resolution Before Migration

### From EscalationPolicy

1. **EscalationRecord table:** EscalationPolicy defines the template; an EscalationRecord captures a specific instance of an escalation in progress (which policy, which trigger, which step is active, what actions have been taken). This table is referenced but not yet designed.

2. **Notification infrastructure:** EscalationPolicy specifies who to notify; the notification mechanism (email, in-app, SMS) is not yet defined. The notification system must itself respect the access classification of the escalation — a notification about a restricted dispute must not expose the restricted content.

3. **SLA enforcement:** `max_resolution_days` implies a scheduled job or timer that fires when the SLA is breached. This has implications for the background job architecture.

### From ContestRecord

4. **Party isolation in dispute UI:** `per_party_isolation` is the default access mode during a contest. The UI and data access layer must enforce that disputing parties cannot see each other's positions without explicit steward authorization. This is a non-trivial access control requirement that must be designed before implementation.

5. **External resolution integration:** When a ContestRecord is routed to an external legal process, LifeBook receives the outcome but has no automated integration with external legal systems. The mechanism for recording external determinations must be defined (manual steward entry, document upload, etc.).

### From Jurisdiction

6. **Legal review requirement:** The jurisdiction-specific policy overrides and the provenance–erasure resolution (§3.7) must be reviewed by legal counsel before launch in any jurisdiction where they apply. These are design decisions, not legal opinions.

7. **Indigenous nation jurisdictions:** Indigenous nations with self-governance over personal information within their territory may have applicable laws or protocols that supersede provincial legislation. These must be identified in consultation with the Indigenous governance process (GOVERNANCE_MODELS.md §9 open question 6) and registered as `indigenous_nation` jurisdiction records before any data involving those communities is held.

8. **GDPR adequacy for Canadian data transferred to EU users:** If LifeBook allows EU-based users to contribute to or access Canadian persons' LifeBooks, GDPR cross-border transfer rules apply. Canada has an adequacy finding under GDPR for PIPEDA, but Quebec's Law 25 may require separate analysis. Legal review required before EU launch.

---

---

## 5. JurisdictionPolicyVersion

Jurisdiction records hold structural configuration. JurisdictionPolicyVersion holds the legal-policy lifecycle for that configuration. Every deployed jurisdiction must have an approved version before data for persons governed by that jurisdiction may be held.

### 5.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `jurisdiction_id` | UUID FK | FK to Jurisdiction |
| `version_number` | Integer | Monotonically increasing per jurisdiction |
| `policy_snapshot` | JSONB | Copy of Jurisdiction.lifebook_policy_overrides at the time of this version |
| `privacy_law_primary` | String | The law this version was reviewed against |
| `privacy_law_reference` | Text | Citation, version, and effective date of the law |
| `law_effective_date` | Date | When this version of the law came into effect |
| `erasure_implementation` | Text | How LifeBook implements erasure under this jurisdiction: describes the redact-values / retain-structure / audit-erasure approach and any jurisdiction-specific adjustments |
| `review_status` | Enum | `draft` / `legally_reviewed` / `approved` / `superseded` |
| `reviewed_at` | Timestamp | Nullable; when legal review was completed |
| `reviewed_by` | Text | Reviewer name, firm, and bar number (free text; not a FK — reviewers are external) |
| `review_scope` | Text | What specifically was reviewed (e.g., "erasure implementation, consent model, cross-border transfer rules") |
| `legal_notes` | Text | May contain privileged observations; access restricted to steward and legal_representative roles |
| `deployment_permitted` | Boolean | **Only `true` when review_status is `approved`.** Set manually after review, not automatically |
| `next_review_date` | Date | Nullable; when this version should be re-reviewed (e.g., on law amendment) |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | |
| `superseded_at` | Timestamp | Nullable |
| `superseded_by_version_id` | UUID FK | Self-referential; nullable |

### 5.2 Jurisdiction.current_policy_version_id

The Jurisdiction table gains two additional fields:

| Field | Type | Notes |
|---|---|---|
| `current_policy_version_id` | UUID FK | FK to JurisdictionPolicyVersion; nullable |
| `deployment_permitted` | Boolean | Computed from current version's deployment_permitted; may also be manually blocked |

`deployment_permitted` on Jurisdiction is the authoritative gate. If false, LifeBook must not hold, process, or transfer personal data for persons governed by this jurisdiction.

### 5.3 Blocked jurisdictions at initial deployment

The following jurisdictions must have `deployment_permitted = false` until legal review is completed:

| Jurisdiction | Reason for block |
|---|---|
| `CA-QC` | Quebec Law 25 imposes stronger erasure, AI disclosure, and consent requirements than PIPEDA. Implementation must be reviewed before deployment |
| `EU` | GDPR right to erasure, data portability, adequacy, and DPO requirements. Implementation must be reviewed before deployment |
| Any jurisdiction with `right_to_erasure = strong` not explicitly approved | Default block; opt-in by legal review |

All other launch jurisdictions begin in `review_status = draft`. They may be used in development and staging but require `review_status = approved` before production data is held.

### 5.4 Erasure capability (provisional)

The erasure implementation carries forward from §3.7 as a provisioned capability, not a legal conclusion:

1. Redact personal data values from attribute records; replace with a redaction marker.
2. Retain non-identifying structural records where legally permitted (that a record existed, that an action occurred, that an attribute was held).
3. Retain an audit record of the erasure action including timestamp, authority basis, and scope — without retaining the erased value.
4. Invalidate all derived artifacts via `AccessPolicyChanged` (trigger: `deletion_or_redaction`).

Whether retaining structural records satisfies a right to erasure under any specific jurisdiction's law is a question for legal review. The implementation capability exists; its legal sufficiency is jurisdiction-specific and must be confirmed before deployment in strong-erasure jurisdictions.

---

## 6. EscalationRecord

EscalationRecord is the instance table for escalations in progress. EscalationPolicy defines the template; EscalationRecord captures a specific running instance, tracking which step is active, what actions have been taken, and when timers expire.

### 6.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `escalation_policy_id` | UUID FK | The policy being applied |
| `trigger_type` | Enum | Must match the policy's trigger_type |
| `trigger_record_type` | String | The table name of the record that caused the escalation |
| `trigger_record_id` | UUID | The specific record ID |
| `triggered_by_id` | UUID FK | User or system process that initiated the trigger; nullable for automated triggers |
| `triggered_at` | Timestamp | |
| `person_ids_involved` | Array\<UUID\> | Person anchors affected |
| `contest_record_id` | UUID FK | Nullable; if this escalation was triggered by a ContestRecord |
| `approval_workflow_id` | UUID FK | Nullable; if this escalation was triggered by an approval workflow timeout |
| `freeze_actions_in_effect` | Array\<ActionType\> | Actions currently blocked by this escalation |
| `current_step_number` | Integer | Which step is currently active (1-indexed) |
| `current_step_started_at` | Timestamp | |
| `current_step_expires_at` | Timestamp | Nullable; when the step's wait_period ends and the next step fires |
| `status` | Enum | See §6.2 |
| `notifications_sent` | JSONB Array | Record of each notification: role, recipient_id, sent_at, channel |
| `actions_taken` | JSONB Array | See §6.3 |
| `resolution_type` | Enum | See §6.4; nullable until resolved |
| `resolution_summary` | Text | Human-authored; nullable |
| `resolved_at` | Timestamp | Nullable |
| `resolved_by_id` | UUID FK | Nullable |
| `default_action_applied` | Enum | EscalationPolicy.default_action_if_unresolved value applied if timed out; nullable |
| `default_action_applied_at` | Timestamp | Nullable |
| `notes` | Text | Nullable |

### 6.2 status values

| Value | Description |
|---|---|
| `active` | Escalation is running; current step is waiting |
| `step_advancing` | Timer expired; transitioning to next step |
| `awaiting_external` | Routed to external legal, cultural, or community process; no LifeBook timer |
| `resolved` | Escalation completed with a resolution |
| `default_applied` | Timed out; default_action_if_unresolved was applied automatically |
| `cancelled` | Cancelled by a steward or by resolution of the underlying trigger |
| `failed` | Escalation pipeline itself encountered an error; requires manual intervention |

### 6.3 actions_taken JSONB array

Each action taken during the escalation:

```json
[
  {
    "step_number": 1,
    "action_type": "notification_sent",
    "action_by": "system",
    "action_by_id": null,
    "action_at": "2026-07-23T10:00:00Z",
    "action_detail": "Notified steward via in-app notification",
    "notes": null
  },
  {
    "step_number": 1,
    "action_type": "steward_responded",
    "action_by": "user",
    "action_by_id": "uuid",
    "action_at": "2026-07-23T14:30:00Z",
    "action_detail": "delegate_to_named",
    "delegated_to_id": "uuid",
    "notes": "Delegated to legal representative pending steward return"
  }
]
```

action_type values:
`notification_sent` · `reminder_sent` · `step_advanced` · `steward_responded` · `approver_responded` · `external_referral_sent` · `external_outcome_received` · `default_applied` · `manual_resolution` · `cancelled`

### 6.4 resolution_type values

| Value | Description |
|---|---|
| `step_resolved` | A required action was completed at one of the steps |
| `default_action_applied` | SLA expired; policy default was applied automatically |
| `external_resolution` | External legal or community process produced a determination |
| `manual_steward_resolution` | Steward resolved outside the normal step flow |
| `cancelled_by_resolution_of_trigger` | The underlying trigger record was resolved; escalation is no longer needed |
| `cancelled_by_steward` | Steward cancelled the escalation directly |

### 6.5 Timer and scheduling requirement

`current_step_expires_at` implies a background scheduling mechanism that fires when the timer ends. The scheduler must:

1. Check whether the escalation is still in `active` status (it may have been resolved in the interim).
2. If active: advance to the next step; update `current_step_number`, `current_step_started_at`, `current_step_expires_at`; send notifications specified in the new step; append to `actions_taken`.
3. If the last step has been reached and `if_no_action` is `deny` or `freeze`: apply the EscalationPolicy's `default_action_if_unresolved`; set `status = default_applied`.
4. Write an audit record for every timer event.

Notification content must respect the access classification of the escalation. A notification about a restricted dispute must not include the restricted content. Notifications contain only: escalation reference number, action required, deadline, and a link to the steward interface.

---

## 7. Candidate Operational Safety Events — Deferred

The following are candidate safety events identified during architecture sessions. They are **not** finalized `trigger_type` values and must not be added to the `EscalationPolicy.trigger_type` vocabulary or any enum until the relevant subsystem state machines are designed and approved.

They are documented here for preservation. No schema object, migration, or enum value is created by this section.

### 7.1 `atmosphere_safety_retreat` — Candidate

**Source subsystem:** Memory Atmosphere Engine (see `MEMORY_ATMOSPHERE_ENGINE.md`)

**Candidate behaviour (not finalized):**

| Action | Description |
|---|---|
| Suppress new atmosphere generation | No new AtmosphereProfile is computed until conditions clear |
| Freeze motion | All animation stops immediately |
| Return toward neutral | Luminance and colour transition toward Level 0 through a controlled, safety-bounded fade (not an instantaneous cut — see MEMORY_ATMOSPHERE_ENGINE.md §6.4) |
| Record the safety event | An AtmosphereAuditLog entry is written (deferred schema object) |
| Escalate to human review | Only if a separately defined policy requires it — not automatic |

**Why this is deferred:**  
The EscalationRecord state machine has not yet been designed for the Memory Atmosphere Engine. It is not established whether an atmosphere retreat constitutes an escalation in the governance sense, a deterministic safety action, or a simple session event. Until the engine's operational model is designed, adding `atmosphere_safety_retreat` to the finalized trigger_type vocabulary would create schema drift with completed migrations and undefined semantics.

**Design dependencies before finalization:**
- Memory Atmosphere Engine implementation review
- Decision on whether atmosphere retreats are auditable session events, escalations, or both
- AtmosphereAuditLog schema design (currently deferred — see MEMORY_ATMOSPHERE_ENGINE.md §11)

---

*Next step: Person, LifeBook, and LifeBookPerson anchors — see ANCHOR_MODELS.md.*
