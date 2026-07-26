# DisplayPolicy Model
**Version:** 0.1  
**Status:** Field-complete — approved for core-schema migration (0003)  
**Produced:** 2026-07-25  
**Produced by:** Discovery Partner + Claude (architecture session)  
**Supersedes:** AttributeDisplayPolicy design intent referenced in SCHEMA_INVENTORY.md row 5.4  
**Governs:** `display_policies` and `display_policy_rules` tables in migration 0003

---

## Introduction

A DisplayPolicy is a governed versioned record that controls whether a specific LifeBook record may be shown in a given display context. Each governed record holds one nullable `display_policy_id` FK. The policy contains one `DisplayPolicyRule` per applicable display context.

This model replaces the former `AttributeDisplayPolicy` architectural concept. It is generic: the same two-table structure governs both person attribute records (PersonName, PersonPronouns, PersonGenderDescriptor) and content records (Claim, Relationship, Narrative, NarrativeEntity, Source, Artifact, Event, EventParticipant).

---

## 1. Design Decisions

**D1 — No `entity_id` on `display_policies`.** The referring record's `display_policy_id` FK identifies the governed object. `entity_id` is not semantically valid for multi-entity content records such as Narratives, Sources, Artifacts, and Events. The referring FK is sufficient.

**D2 — One DisplayPolicy per governed record.** A governed record holds exactly one `display_policy_id` (nullable). If a policy exists, all applicable display context decisions are expressed as `DisplayPolicyRule` rows under that policy.

**D3 — No discriminator field.** The referring FK column establishes whether the policy governs a person attribute or a content record. No `policy_type` column is needed. Reusable policy templates, if needed in a future version, must be modelled separately as `DisplayPolicyTemplate` rather than overloading operative `DisplayPolicy` records.

**D4 — `display_context` is a governed reference table, not unrestricted text.** All nine display context codes must exist in the `display_contexts` reference table (migration 0002) before the core-schema migration (0003) may be authored. No context value outside this table is permitted.

**D5 — `display_policy_status` and `display_policy_decision` are new governed enum types in migration 0002.**

**D6 — `approval_record_id` is a deferred FK.** `display_policies` is created before `approval_records` in the dependency chain. The FK is added via `ALTER TABLE` after `approval_records` is created. This is the same pattern used for `authority_assignments.basis_claim_id`.

**D7 — Authority depends on the governed record and applicable governance model.** Authority is not universally steward-controlled. Living subjects retain authority over subject-controlled information including pronouns, gender descriptors, former names, Indigenous names, and ceremonial names.

**D8 — Conditions must be structured, versioned JSONB.** Unrestricted free text is not permitted in the `conditions` field. V1 conditions are limited to a closed set of five condition types. The schema version field is required when conditions are present.

---

## 2. `display_policies` Table

| Column | Type | Nullable | Constraints | Notes |
|---|---|---|---|---|
| `id` | UUID | NOT NULL | PK, DEFAULT gen_random_uuid() | |
| `lifebook_id` | UUID | Nullable | FK → lifebooks(id) | Scopes the policy to a LifeBook; NULL only for system-level policies |
| `status` | `display_policy_status` | NOT NULL | — | `draft / active / superseded / withdrawn` |
| `effective_from` | TIMESTAMPTZ | Nullable | — | When policy becomes operative; NULL = immediate on activation |
| `effective_until` | TIMESTAMPTZ | Nullable | — | When policy expires; NULL = no expiry |
| `supersedes_policy_id` | UUID | Nullable | FK → display_policies(id) | Points to the prior policy version this record supersedes |
| `set_by_role` | TEXT | NOT NULL | FK → authority_roles(code) | Governance role that authorized this policy; e.g. `subject`, `steward`, `cultural_authority` |
| `set_by_id` | UUID | Nullable | FK → user_profiles(id) | Specific user who set this policy; NULL when set by external authority or system |
| `approval_record_id` | UUID | Nullable | FK → approval_records(id) — **DEFERRED FK** | Required by governance rules for certain record types; see §6 |
| `reason` | TEXT | Nullable | — | Human-readable rationale |
| `created_at` | TIMESTAMPTZ | NOT NULL | DEFAULT now() | |
| `created_by_id` | UUID | Nullable | FK → user_profiles(id) | NULL for system-migration-created records |
| `created_by_system` | TEXT | Nullable | — | Non-null for migration-seeded records; see §2.1 |

**Provenance constraint:**
```sql
CHECK (created_by_id IS NOT NULL OR created_by_system IS NOT NULL)
```

**Deferred FK declaration:**
```
-- DEFERRED FK: display_policies.approval_record_id → approval_records(id)
-- Added via ALTER TABLE after approval_records table is created
-- Nullable FK; null is valid for policies that do not require formal approval
```

### 2.1 Provenance for application-created policies

Application-created policies carry:
- `created_by_id = <valid user_profiles UUID>`
- `created_by_system = NULL`

System-migration-seeded policies (if any) carry:
- `created_by_id = NULL`
- `created_by_system = 'migration:<actual_core_schema_filename>'`

### 2.2 `set_by_role` and subject authority

`set_by_role` is a TEXT FK to `authority_roles(code)` (migration 0001). The `authority_roles` table includes `subject`, `guardian_sole`, `guardian_joint`, `steward`, `cultural_authority`, and others.

Living subjects may set display policies on subject-controlled records using their `subject` authority role. This applies to: pronouns, gender descriptors, preferred names, Indigenous names, ceremonial names, and any other record designated subject-controlled by the applicable governance model.

Stewards may set policies on records within their steward authority scope. Cultural authorities may set policies on culturally governed records. The applicable governance model for each record type is the source of truth for which role may authorize a policy.

---

## 3. `display_policy_rules` Table

| Column | Type | Nullable | Constraints | Notes |
|---|---|---|---|---|
| `id` | UUID | NOT NULL | PK, DEFAULT gen_random_uuid() | |
| `display_policy_id` | UUID | NOT NULL | FK → display_policies(id) | |
| `display_context_code` | TEXT | NOT NULL | FK → display_contexts(code) ON UPDATE RESTRICT ON DELETE RESTRICT | Governed vocabulary; see §5 |
| `decision` | `display_policy_decision` | NOT NULL | — | `allow / deny / conditional` |
| `conditions` | JSONB | Nullable | — | Structured condition object; only valid when decision = `conditional`; see §4 |
| `condition_schema_version` | TEXT | Nullable | — | Required when conditions IS NOT NULL; e.g., `'v1'` |
| `reason` | TEXT | Nullable | — | Human-readable rationale for this rule |
| `created_at` | TIMESTAMPTZ | NOT NULL | DEFAULT now() | |

**Uniqueness constraint:**
```sql
UNIQUE (display_policy_id, display_context_code)
```

**Condition schema consistency constraint:**
```sql
CHECK (conditions IS NULL OR condition_schema_version IS NOT NULL)
```

**Condition type constraint (V1 enforcement):**
```sql
CHECK (
    conditions IS NULL
    OR conditions->>'type' IN (
        'subject_consent_required',
        'posthumous_only',
        'approval_record_required',
        'steward_authorization_required',
        'cultural_authorization_required'
    )
)
```

---

## 4. Condition Schema — V1

When `decision = 'conditional'`, the `conditions` JSONB must conform to this V1 schema:

```json
{
  "type": "<condition_type>",
  "params": {}
}
```

`condition_schema_version` must be `'v1'` for all V1 condition records.

### 4.1 V1 Condition Types

| `type` value | Meaning | `params` |
|---|---|---|
| `subject_consent_required` | The subject must have explicitly and actively consented to this display | `{}` (no params required) |
| `posthumous_only` | The record may be displayed only after the subject's death is recorded in the LifeBook | `{}` |
| `approval_record_required` | An approved ApprovalRecord of the relevant type must exist before display is permitted | `{"approval_type": "<optional type code>"}` |
| `steward_authorization_required` | The accessing steward must have specifically authorized this display event | `{}` |
| `cultural_authorization_required` | Authorization from the relevant cultural authority is required; must be on record | `{}` |

### 4.2 V1 Constraints

- The `type` field must be one of the five values above. No other condition types are valid in V1.
- No executable expressions, application-defined scripts, or programmatic logic may appear in the `conditions` JSONB.
- A future V2 schema may extend the condition type set. V2 conditions must carry `condition_schema_version = 'v2'`. V1 and V2 records may coexist; each must be evaluated against its declared schema version.
- If a condition cannot be evaluated (e.g., subject death not yet recorded), the rule must be treated as `deny`, not `allow`.

---

## 5. Governed Display Contexts

The nine display context codes are defined in the `display_contexts` reference table (migration 0002):

| Code | Display label | Meaning |
|---|---|---|
| `public_ui` | Public UI | General public-facing display |
| `family_ui` | Family UI | Display to LifeBook contributors and family members |
| `steward_ui` | Steward UI | Display to the designated LifeBook steward |
| `historical_record` | Historical Record | Archival and historical research use |
| `ordinary_search` | Ordinary Search | General name and identity search |
| `identity_resolution_search` | Identity Resolution Search | Identity matching and disambiguation search |
| `default_export` | Default Export | Standard data export for the LifeBook owner |
| `steward_export` | Steward Export | Data export generated by the steward |
| `ai_generation` | AI Generation | Data provided to AI context for narrative generation |

No context value outside this table may appear in `display_policy_rules.display_context_code`.

### 5.1 Relationship to `conflict_resolution_purposes`

The `conflict_resolution_purposes` reference table (migration 0001) uses different codes (`display_public`, `display_family`, etc.) for a different purpose — resolving conflicts between competing attribute values for display. It is **not** the same vocabulary as `display_contexts`, and the two must not be conflated.

---

## 6. Authority Provenance and Approval Requirements

**`set_by_role`** records which governance role authorized the policy. Valid values are `authority_roles.code` from migration 0001.

**`set_by_id`** records the specific user who set the policy, when applicable. NULL when the authority is external to the LifeBook user system (e.g., a cultural authority acting through a documented off-system process).

**`approval_record_id`** records the ApprovalRecord that authorized the policy, where governance rules require formal approval. The applicable governance rules are:

| Scenario | `approval_record_id` |
|---|---|
| Subject setting their own policy on subject-controlled content | Not required (NULL) |
| Steward modifying a policy on content the subject no longer controls | Required — ApprovalRecord of applicable type |
| Cultural authority setting policy on culturally governed content | Required — ApprovalRecord of applicable type |
| Override of a default restrictive policy for a sensitive record type | Required — ApprovalRecord of applicable type |

The governance model for each record type (GOVERNANCE_MODELS.md) determines whether an ApprovalRecord is required.

---

## 7. Lifecycle Rules and Immutability

A DisplayPolicy becomes part of the permanent governance record when its status first transitions to `active`. Draft records are working copies with no governance standing; there is no requirement to track whether a draft has been evaluated.

| Status | Editable | Deletable | Description |
|---|---|---|---|
| `draft` | Yes | Yes | Working copy; not yet operative; no governance standing |
| `active` | No | No | Operative; governs display decisions; permanent governance record |
| `superseded` | No | No | Replaced by a newer version; retained for lineage |
| `withdrawn` | No | No | Manually deactivated; retained for lineage |

### 7.1 Application responsibilities

The application layer manages policy workflow. The database does not implement business workflow. Application responsibilities:

- Create a successor `display_policies` record in `draft` status
- Create `display_policy_rules` records for the successor policy
- Attach the successor to the governed record (`display_policy_id` FK updated to successor UUID)
- Transition the predecessor from `active` → `superseded` (one permitted status-only UPDATE)
- Transition the successor from `draft` → `active`

Versioning produces a chain: each active policy points backward via `supersedes_policy_id` to the policy it replaced. The governed record always holds the UUID of the current active policy.

### 7.2 Database enforcement responsibilities

The database enforces invariants. Triggers enforce these invariants only — no business workflow logic is implemented inside triggers.

**On `display_policies`:**

- BEFORE UPDATE: Permitted only if `OLD.status = 'draft'` (any field), OR if `OLD.status = 'active'` and the update is a status-only change to `superseded` or `withdrawn`. All other updates to `active`, `superseded`, or `withdrawn` records are rejected.
- BEFORE DELETE: Permitted only if `OLD.status = 'draft'`. Rejected for all other statuses.

**On `display_policy_rules`:**

- BEFORE UPDATE: Rejected if the parent `display_policies.status != 'draft'`.
- BEFORE DELETE: Rejected if the parent `display_policies.status != 'draft'`.

**RLS:** DELETE denied for all roles where `status IN ('active', 'superseded', 'withdrawn')`. UPDATE denied for all roles where `status IN ('superseded', 'withdrawn')` (the trigger handles `active` → permitted status transitions). Both triggers and RLS are authored in migration 0003 and documented in VOCABULARY_RLS_MATRIX.md before SQL is written.

---

## 8. Default Evaluation Rules

When a display context decision is needed for a governed record:

1. **No active DisplayPolicy:** Apply the record type's documented default display rules. Each record type's defaults are documented in the governing catalogue or model document (PERSON_ATTRIBUTE_CATALOGUE.md for person attributes; CONTENT_LAYER.md for content records).

2. **Active DisplayPolicy exists, rule present for requested context:** Apply the rule decision (`allow`, `deny`, or evaluate `conditional`).

3. **Active DisplayPolicy exists, no rule for requested context:** **Deny.** The absence of a rule for a context is not permission.

4. **Highly sensitive record types:** Certain record types (e.g., `indigenous_name`, `ceremonial_name`, records with `access_classification = 'restricted'`) must not rely on permissive defaults. These types require an explicit active DisplayPolicy with a rule for every display context in which they may appear. Access in the absence of an explicit active policy must be denied.

---

## 9. Migration Dependencies

### 9.1 Governed types required in migration 0002

Before the core-schema migration (0003) can be authored, migration 0002 must create:

| Type | Kind | Values |
|---|---|---|
| `relationship_interaction_type` | PostgreSQL enum | `proposes / supports / describes / none` |
| `display_policy_status` | PostgreSQL enum | `draft / active / superseded / withdrawn` |
| `display_policy_decision` | PostgreSQL enum | `allow / deny / conditional` |
| `display_contexts` | Reference table | 9 seeded records (see §5) |

### 9.2 Table dependency order in migration 0003

`display_policies` must be created after:
- `lifebooks` (FK: `lifebook_id`)
- `user_profiles` (FK: `set_by_id`, `created_by_id`)
- `authority_roles` (FK: `set_by_role`) — exists from migration 0001

`display_policies.approval_record_id` → `approval_records(id)` is a **deferred FK**, added via ALTER TABLE after `approval_records` is created.

`display_policy_rules` must be created after `display_policies`.

`display_contexts` exists from migration 0002; the FK in `display_policy_rules.display_context_code` is valid at core-schema migration time.

### 9.3 Tables that depend on `display_policies`

All of the following must be created after `display_policies` in migration 0003:

| Table | FK column |
|---|---|
| `claims` | `display_policy_id` (nullable) |
| `relationships` | `display_policy_id` (nullable) |
| `narratives` | `display_policy_id` (nullable) |
| `narrative_entities` | `display_policy_id` (nullable) |
| `sources` | `display_policy_id` (nullable) |
| `artifacts` | `display_policy_id` (nullable) |
| `events` | `display_policy_id` (nullable) |
| `event_participants` | `display_policy_id` (nullable) |
| `person_names` | `display_policy_id` (nullable) |
| `person_pronouns` | `display_policy_id` (nullable) |
| `person_gender_descriptors` | `display_policy_id` (nullable) |

---

## 10. Discovery Partner Decisions — Recorded 2026-07-25

### 10.1 Authority model for content records

**Decision C — Approved.**

`display_policies` records provenance via `set_by_role` (FK → authority_roles, validated at schema layer), `set_by_id` (FK → user_profiles, nullable), and `approval_record_id` (nullable deferred FK → approval_records). The schema validates existence of referenced records; it does not enforce which specific role may create or modify a DisplayPolicy for a given governed record type.

Authority rules for specific record types belong to governance rules, RLS policies, and application workflow. These are authored in VOCABULARY_RLS_MATRIX.md and GOVERNANCE_MODELS.md, not in the `display_policies` table DDL.

`display_policies` table DDL is unblocked. The RLS policy for `display_policies` (INSERT permissions by role and record type) depends on GOVERNANCE_MODELS.md authority coverage and is authored in the RLS design session.

### 10.2 Draft lifecycle

**Decision A — Approved with simplification.**

A DisplayPolicy becomes part of the permanent governance record when status first transitions to `active`. Draft records have no governance standing. There is no requirement to track whether a draft has been evaluated.

Draft records are editable and deletable. Active, superseded, and withdrawn records are immutable. No evaluation-tracking mechanism (`has_been_evaluated` flag or equivalent) is required.

### 10.3 Lifecycle enforcement boundary

**Decision B — Option D approved with clarification.**

Application layer manages workflow. Database layer enforces invariants only.

See §7.1 (application responsibilities) and §7.2 (database enforcement). Triggers implement status-transition validation and field immutability only. No business workflow logic belongs in database triggers.

### 10.4 Cardinality

**Decision D — Option A approved for V1.**

Operative DisplayPolicies are record-specific by application invariant. A single DisplayPolicy UUID must not be attached to more than one governed record in operative use. This is a V1 application invariant, not enforced at the schema layer.

Future database hardening (if the invariant requires schema enforcement): add `UNIQUE (display_policy_id)` as a partial unique index on each governed table where `display_policy_id IS NOT NULL`. This is a V1.1 item, not in migration 0003 scope.

---

## 11. `display_contexts` — Reference Table Rationale

The `display_contexts` vocabulary is modelled as a reference table rather than a PostgreSQL enum. The decision was reviewed against the criterion: if the only rationale is hypothetical future metadata, an enum is preferable.

The rationale stands on three concrete V1 requirements:

**Governance metadata columns (V1-required).** The reference table carries `sort_order INT NOT NULL` — a governance parameter specifying evaluation priority when multiple contexts are evaluated in sequence (e.g., a batch export or context-bundle evaluation). This is not hypothetical. The policy evaluation engine needs a canonical ordering to process contexts consistently. An enum cannot carry `sort_order`; a reference table can.

**UI label and description (V1-required).** The steward UI presents display contexts to users who are creating or reviewing DisplayPolicy records. Each context must have a human-readable `label` and `description` in the steward's language. These must be stored somewhere; hardcoding them in application code bypasses the schema's governed-vocabulary pattern. The reference table carries `label TEXT NOT NULL` and `description TEXT NOT NULL` as first-class fields.

**Extensibility without schema migration.** New display contexts (e.g., a `legal_review_ui` context for a regulatory jurisdiction, or a `partner_api_export` context for a specific integration) can be added via a governed INSERT in a new migration without ALTER TYPE. An enum addition requires an ALTER TYPE statement, which is a schema change that must be explicitly governed. The reference-table pattern allows jurisdiction-specific or integration-specific context additions to be scoped to the migrations that introduce the features they support.

**Consistency with existing pattern.** The established schema pattern uses reference tables — not enums — for all governed vocabularies where the code is used as a FK target by operative records: `event_types`, `conflict_resolution_purposes`, `authority_roles`, `claim_value_units`. Display contexts follow the same pattern.

**Verdict:** Reference table. The rationale is not hypothetical. Three of the four reasons are V1-required, not speculative.

---

*This model is approved and complete. The AttributeDisplayPolicy blocker (ARCHITECTURE_FREEZE_V1.md §5; PRE_SQL_READINESS_REVIEW.md §4.3) is fully resolved. Table DDL for `display_policies` and `display_policy_rules` may be authored. RLS policies and triggers for these tables must be documented in VOCABULARY_RLS_MATRIX.md before SQL is written, per MIGRATION_PHILOSOPHY.md §7.*
