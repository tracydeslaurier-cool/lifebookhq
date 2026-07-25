# LifeBook ApprovalRecord — Approval Instance Model
**Version:** 1.0  
**Status:** Pre-schema design document  
**Depends on:** GOVERNANCE_MODELS.md (ApprovalPolicy), OPERATIONAL_MODELS.md (EscalationRecord)  
**Produced:** 2026-07-23  
**Produced by:** Architecture session — Discovery Partner + Claude

### Revision history

| Version | Date | Summary | Supersedes |
|---|---|---|---|
| 1.0 | 2026-07-23 | Initial definition; separates ApprovalRecord (instance) from ApprovalPolicy (template); corrects conflation found in prior SCHEMA_INVENTORY.md FK references | — |

---

## 1. Purpose and distinction from ApprovalPolicy

**ApprovalPolicy** is a reusable governance template. It defines the rules for a category of action: which action type is governed, what lifecycle state applies, which roles must approve, what quorum is required, how long the approval window is, and what escalation path fires if the window lapses. ApprovalPolicy records are configuration; they are not decisions.

**ApprovalRecord** is a concrete decision instance. It captures that a specific action on a specific record was requested, under which policy, by whom, and what happened. It records every individual approval or rejection received, when the final decision was made, and the full audit trail. ApprovalRecord records are evidence; they are not configuration.

**Rule:** Consequential tables (MergeRecord, CrossLifeBookAuthorization, and any other table that cannot exist without explicit authorization) must reference an ApprovalRecord instance, not an ApprovalPolicy template. Referencing a policy template establishes that rules exist; it does not prove that those rules were satisfied for the specific action in question.

---

## 2. ApprovalRecord fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `policy_id` | UUID FK → ApprovalPolicy | NOT NULL — which policy template governs this instance |
| `target_record_type` | String | Table name of the record being approved (e.g., `entity_match_candidate`, `lifebook`) |
| `target_record_id` | UUID | The specific record for which approval is sought |
| `target_action` | ActionType | The specific action being approved (see GOVERNANCE_MODELS.md §3.3) |
| `lifebook_id` | UUID FK → LifeBook | Nullable — present when the approval is LifeBook-scoped |
| `requested_by_id` | UUID FK → user_profiles | NOT NULL |
| `requested_at` | Timestamp | NOT NULL |
| `status` | Enum | See §3 |
| `required_approver_count` | Integer | Snapshot of required count from policy at time of creation; NOT NULL |
| `received_approver_count` | Integer | Maintained count of approving decisions received; default 0 |
| `approvals_received` | JSONB | Append-only array of individual approver decisions; see §4 |
| `decided_at` | Timestamp | Nullable — when final status (`approved`, `rejected`, `expired`) was set |
| `expires_at` | Timestamp | Nullable — computed at creation: requested_at + policy.approval_expiry_days |
| `override_rationale` | Text | Nullable — required if approved via escalation path outside normal quorum |
| `override_by_id` | UUID FK → user_profiles | Nullable — the steward or authority who authorized the override |
| `escalation_record_id` | UUID FK → EscalationRecord | Nullable — set when an escalation has been opened for this approval |
| `audit_lineage` | JSONB | Append-only full event trail; see §5 |
| `created_at` | Timestamp | NOT NULL |
| `created_by_id` | UUID FK → user_profiles | NOT NULL |
| `superseded_by_id` | UUID FK → self | Nullable — set when a newer ApprovalRecord supersedes this one for the same target |

### 2.1 Immutability rules

ApprovalRecord is an audit record. Once created:

- `policy_id`, `target_record_type`, `target_record_id`, `target_action`, `requested_by_id`, `requested_at`, `required_approver_count`, `created_at`, `created_by_id` must never be modified.
- `approvals_received` and `audit_lineage` are append-only. Individual entries in these arrays must never be deleted or modified.
- `status` may advance through the lifecycle in §3. It may not revert except through supersession (`superseded_by_id` set; a new ApprovalRecord created).
- `decided_at` is set once, when `status` first reaches a terminal value.

---

## 3. status values

| Value | Description |
|---|---|
| `draft` | Created but not yet submitted. Used when the proposal is being assembled before formal submission |
| `pending` | Submitted; awaiting required approvals; within the approval window |
| `approved` | Required quorum (or override) satisfied; approval granted |
| `rejected` | At least one required approver has explicitly rejected; approval denied |
| `expired` | `expires_at` elapsed without sufficient approvals and without an override; approval failed |
| `superseded` | This record was replaced by a newer ApprovalRecord for the same target and action; `superseded_by_id` is set |

**Terminal states:** `approved`, `rejected`, `expired`. Once in a terminal state, `status` may not change. Supersession creates a new record; it does not revert the terminal state of the old one.

**Lifecycle rules:**
- `draft` → `pending`: when the requesting party formally submits
- `pending` → `approved`: when `received_approver_count` reaches `required_approver_count`, or override is applied
- `pending` → `rejected`: when a required approver rejects and no override path exists
- `pending` → `expired`: when `expires_at` is reached without quorum
- Any non-terminal → `superseded`: when `superseded_by_id` is set by a steward action

---

## 4. approvals_received JSONB structure

`approvals_received` is an append-only JSONB array. Each element represents one approver's decision:

```json
[
  {
    "approver_id": "uuid",
    "approver_role": "steward",
    "authority_assignment_id": "uuid",
    "decision": "approved | rejected | abstained | delegated",
    "decided_at": "2026-07-23T14:30:00Z",
    "delegation_to_id": null,
    "notes": "optional human-authored rationale; visible to steward only"
  }
]
```

| Field | Notes |
|---|---|
| `approver_id` | FK to user_profiles; the identity of the approver |
| `approver_role` | The authority_role under which this person is acting (from GOVERNANCE_MODELS.md §3.2) |
| `authority_assignment_id` | The specific AuthorityAssignment record that authorizes this approver to act for this action |
| `decision` | `approved` — affirmative; `rejected` — explicit denial; `abstained` — noted but not counted toward quorum; `delegated` — approver has delegated to delegation_to_id |
| `decided_at` | Timestamp of this individual decision |
| `delegation_to_id` | Nullable UUID FK to user_profiles; set when decision = delegated |
| `notes` | Nullable; visible to steward and audit; not exposed to requesting party by default |

**Invariant:** No two entries in `approvals_received` may have the same `approver_id` and `decision != abstained`. A person may submit one decision per ApprovalRecord. If an approver changes their position, the escalation path governs; the original decision is not overwritten.

---

## 5. audit_lineage JSONB structure

`audit_lineage` is an append-only JSONB array recording every status transition and significant event:

```json
[
  {
    "event_type": "submitted | approval_received | rejection_received | escalation_opened | override_applied | status_changed | superseded",
    "occurred_at": "2026-07-23T10:00:00Z",
    "actor_id": "uuid or null for system events",
    "from_status": "draft",
    "to_status": "pending",
    "notes": "optional"
  }
]
```

---

## 6. Consequential record rules

The following tables must reference an ApprovalRecord instance, not an ApprovalPolicy template. In all cases the FK is NOT NULL on the completed record — a completed consequential record without an explicit approval instance must not exist.

| Table | Field | Required approval status |
|---|---|---|
| `MergeRecord` | `approval_record_id` → ApprovalRecord | `approved` |
| `CrossLifeBookAuthorization` | `approval_a_id` → ApprovalRecord | `approved` |
| `CrossLifeBookAuthorization` | `approval_b_id` → ApprovalRecord | `approved` |
| `CrossLifeBookAuthorization` | `person_authorization_id` → ApprovalRecord | `approved` (when person consent is required) |

**MergeRecord lifecycle:**
1. `EntityMatchCandidate` is created identifying two potentially identical Person records.
2. An `ApprovalRecord` is created with `target_action = approve_merge` under the applicable `ApprovalPolicy`.
3. Required approvers are notified and submit their decisions to `approvals_received`.
4. When `ApprovalRecord.status` reaches `approved`, a `MergeRecord` is created with `approval_record_id = [that ApprovalRecord.id]`.
5. `MergeRecord.approval_record_id` is NOT NULL and may not be set to a record in any status other than `approved`.
6. A reversal (split) creates its own `ApprovalRecord` with `target_action = approve_split` and its own `MergeRecord` with `reversed_merge_record_id` pointing to the original.

**CrossLifeBookAuthorization lifecycle:**
Each of the three approval FKs (`approval_a_id`, `approval_b_id`, `person_authorization_id`) references a separate `ApprovalRecord` instance representing:
- `approval_a_id`: approval from the steward of LifeBook A
- `approval_b_id`: approval from the steward of LifeBook B
- `person_authorization_id`: approval from the person (or their authority holder) whose records will be shared

A `CrossLifeBookAuthorization` record may not be created until all three applicable `ApprovalRecord` instances have `status = approved`.

---

## 7. Migration dependency

`ApprovalRecord` must be created in the migration sequence after:

- `ApprovalPolicy` (FK policy_id)
- `user_profiles` (FK requested_by_id, created_by_id, override_by_id)
- `EscalationRecord` (nullable FK escalation_record_id)
- `LifeBook` (nullable FK lifebook_id)

`MergeRecord` and `CrossLifeBookAuthorization` must be created after `ApprovalRecord`.

`EntityMatchCandidate` must be created after `MergeRecord`.

`EscalationRecord.approval_record_id` (renamed from `approval_workflow_id`) is a nullable FK back to `ApprovalRecord`. To resolve the circular reference:

1. Create `EscalationRecord` without `approval_record_id` column.
2. Create `ApprovalRecord`.
3. `ALTER TABLE escalation_records ADD COLUMN approval_record_id UUID REFERENCES approval_records(id)`.

This is the only circular FK between these two tables. It is nullable and deferred; no bootstrap problem.

---

## 8. Open questions

1. **ApprovalRecord scope for non-LifeBook actions:** Some approval actions may be system-wide (e.g., approve_merge on two Person records that appear in different LifeBooks). How is `lifebook_id` populated for cross-LifeBook approval instances? Current answer: nullable, with both LifeBook IDs recorded in `audit_lineage`. Confirm before migration.

2. **Draft-to-pending submission mechanism:** How does a requesting party formally submit? Is this an API call that changes status from `draft` to `pending`, or are all ApprovalRecords created directly in `pending`? Draft status may be unnecessary if proposals always originate as pending. Confirm whether `draft` status is required at launch.

3. **Delegated approvals and quorum counting:** If an approver delegates, does the delegation count toward the approver's slot in the quorum, or does the delegate need to approve independently? Current answer: delegate's approval fills the original approver's slot. Confirm.

4. **Parallel vs. sequential approval:** ApprovalPolicy.required_approvers specifies the quorum rule but not whether approvals are collected in parallel (all notified simultaneously) or sequentially (each approver is notified only after the prior approves). Current design assumes parallel. If sequential is required for some action types, `steps` must be added to ApprovalPolicy similar to EscalationPolicy. Confirm.
