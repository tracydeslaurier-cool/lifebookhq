# Terminology Audit — ApprovalPolicy vs. ApprovalRecord
**Version:** 1.0  
**Produced:** 2026-07-23  
**Produced by:** Architecture session — Discovery Partner + Claude

---

## 1. Definitions (canonical, frozen)

**ApprovalPolicy** — a reusable governance template. It defines rules for a category of action: which action is governed, which lifecycle state applies, which roles must approve, what quorum is required, how long the approval window lasts, and what escalation path fires if the window lapses. ApprovalPolicy records are configuration, not decisions. Authoritative source: GOVERNANCE_MODELS.md §4.

**ApprovalRecord** — a concrete approval instance. It records that a specific action on a specific record was proposed, under which ApprovalPolicy, by whom, and what happened: every individual approver decision received, when the final decision was reached, and the complete audit trail. ApprovalRecord records are evidence, not configuration. Authoritative source: APPROVAL_INSTANCE_MODEL.md v1.0.

---

## 2. Conflation found in prior documents

The following FK references were found using `grep` across all governed documents. Each references `ApprovalPolicy` in a position that must reference `ApprovalRecord`.

| Document | Table | Field | Found reference | Required reference |
|---|---|---|---|---|
| SCHEMA_INVENTORY.md row 3.8 | `MergeRecord` | `approval_record_id` | → ApprovalPolicy | → ApprovalRecord (NOT NULL) |
| SCHEMA_INVENTORY.md row 9.1 | `CrossLifeBookAuthorization` | `approval_a_id` | → ApprovalPolicy | → ApprovalRecord (NOT NULL) |
| SCHEMA_INVENTORY.md row 9.1 | `CrossLifeBookAuthorization` | `approval_b_id` | → ApprovalPolicy | → ApprovalRecord (NOT NULL) |
| SCHEMA_INVENTORY.md row 9.1 | `CrossLifeBookAuthorization` | `person_authorization_id` | → ApprovalPolicy | → ApprovalRecord (nullable) |
| OPERATIONAL_MODELS.md §6.1 | `EscalationRecord` | `approval_workflow_id` | (undefined/unnamed) | renamed: `approval_record_id` → ApprovalRecord (nullable) |

Note: ANCHOR_MODELS.md was not re-read in this session. It likely also contains MergeRecord and CrossLifeBookAuthorization field definitions with the same errors. ANCHOR_MODELS.md must be checked and corrected before MergeRecord or CrossLifeBookAuthorization migration files are written.

---

## 3. Correct usages confirmed

The following references correctly use `ApprovalPolicy` as a template reference and do not require correction:

| Document | Table / record | Field | Use | Assessment |
|---|---|---|---|---|
| GOVERNANCE_MODELS.md §4 | ApprovalPolicy | (definition) | Template definition | Correct |
| GOVERNANCE_MODELS.md §1.1 | evidence_status | — | No approval reference | Correct |
| PERSON_ATTRIBUTE_CATALOGUE.md | PersonName | `approval_policy_id` | → ApprovalPolicy (template) | Correct — this is a governance template reference, not an instance |
| PERSON_ATTRIBUTE_CATALOGUE.md | PersonPronouns | `approval_policy_id` | → ApprovalPolicy (template) | Correct |
| PERSON_ATTRIBUTE_CATALOGUE.md | PersonGenderDescriptor | `approval_policy_id` | → ApprovalPolicy (template) | Correct |
| OPERATIONAL_MODELS.md §1 | EscalationPolicy | `escalation_policy_id` FK from ApprovalPolicy | Template-to-template | Correct |
| OPERATIONAL_MODELS.md §2.1 | ContestRecord | `escalation_policy_id` | → EscalationPolicy | Correct — not an approval reference |
| CONTENT_LAYER.md §7 | AI_CONTEXT_BROKER reference | "pending approval record" | ApprovalRecord concept (unnamed) | The phrase "pending approval record" in the AI generation rule refers to an ApprovalRecord instance; consistent with the model |

---

## 4. Resolution status

| Conflation instance | Resolution | Status |
|---|---|---|
| MergeRecord.approval_record_id → ApprovalPolicy | Must be updated to → ApprovalRecord (NOT NULL) in SCHEMA_INVENTORY.md and ANCHOR_MODELS.md | **Pending** — MIGRATION_SCOPE_MATRIX.md G3 blocker |
| CrossLifeBookAuthorization.approval_a_id → ApprovalPolicy | Must be updated to → ApprovalRecord (NOT NULL) | **Pending** — G3 blocker |
| CrossLifeBookAuthorization.approval_b_id → ApprovalPolicy | Must be updated to → ApprovalRecord (NOT NULL) | **Pending** — G3 blocker |
| CrossLifeBookAuthorization.person_authorization_id → ApprovalPolicy | Must be updated to → ApprovalRecord (nullable) | **Pending** — G3 blocker |
| EscalationRecord.approval_workflow_id (unnamed) | Rename to `approval_record_id` → ApprovalRecord (nullable) in OPERATIONAL_MODELS.md | **Pending** — G3 blocker |
| ApprovalRecord model absent | Defined in APPROVAL_INSTANCE_MODEL.md v1.0 | **Resolved** |
| Architecture freeze missing P12 principle | P12 added to ARCHITECTURE_FREEZE_V1.md v1.1 | **Resolved** |

All five pending items are tracked as Blocker G3 in PRE_MIGRATION_CLOSURE.md v1.2 and MIGRATION_SCOPE_MATRIX.md v1.1. No migration file for MergeRecord, CrossLifeBookAuthorization, LifeBookSourceAccess, or EscalationRecord may be written until G3 is resolved.

---

## 5. Terminology rule (frozen)

Going forward, the following rule applies to all governed documents, migration files, and application code:

- Use **`ApprovalPolicy`** when referring to a governance rule template that defines who must approve a category of action.
- Use **`ApprovalRecord`** when referring to the record of an actual approval decision on a specific action on a specific record.
- Never use `ApprovalPolicy` as the referent of a FK on a consequential table (MergeRecord, CrossLifeBookAuthorization, or any future table that is created as the result of a completed approval workflow).
- Never use `approval_workflow_id` or `approval_record_id` as a pointer to `ApprovalPolicy`.
