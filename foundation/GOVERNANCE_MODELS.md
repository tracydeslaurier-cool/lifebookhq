# LifeBook Governance Models
**Version:** 0.1 Draft  
**Status:** Pre-schema design document  
**Depends on:** PERSON_ATTRIBUTE_CATALOGUE.md  
**Produced:** 2026-07-23  

---

## 1. Corrected Confidence Model

The previous single `confidence` enum conflated four independent dimensions. Each attribute record now carries four separate fields.

### 1.1 evidence_status

How much external support exists for the claim.

| Value | Meaning |
|---|---|
| `unreviewed` | Just entered. No human has confirmed. System-extracted records begin here |
| `asserted` | A qualified asserting role has made the claim directly. No corroboration yet |
| `inferred` | AI or system derived this from other data. Not directly stated by any person |
| `supported` | One corroborating source exists beyond the original assertion |
| `corroborated` | Multiple independent sources confirm. Meets the threshold defined in the applicable ApprovalPolicy |

**AI boundary:** An AI agent may attach evidence_status up to `inferred`. It may recommend elevation to `supported` or `corroborated` but may not execute the elevation. The applicable ApprovalPolicy governs who must approve the transition and under what conditions.

### 1.2 precision_status

How precise the recorded value is.

| Value | Meaning |
|---|---|
| `exact` | Specific, verifiable value (a date: 1983-10-27; a full name) |
| `approximate` | Near a value but not exact (circa 1923; "in her forties") |
| `range` | Known to fall within bounds (born between 1880 and 1895) |
| `unknown` | No precision information available |

### 1.3 dispute_status

Whether the claim is contested.

| Value | Meaning |
|---|---|
| `uncontested` | No known challenge |
| `disputed` | One or more parties have raised a challenge; not resolved |
| `contradicted` | Another claim with equal or higher evidence_status directly conflicts |
| `retracted` | The original asserting party has withdrawn the claim |
| `superseded` | Replaced by a newer claim with a stronger or more recent basis |

**AI boundary:** AI must not independently change dispute_status. It may flag a potential contradiction for human review, which creates a `disputed` record for human resolution.

### 1.4 review_status

Where the claim is in the human review workflow.

| Value | Meaning |
|---|---|
| `pending` | Awaiting human review |
| `human_reviewed` | A human with the appropriate role has reviewed and accepted |
| `policy_approved` | Meets the formal ApprovalPolicy threshold for the applicable action |

**Transition rule:** A claim may not be used as the basis for a consequential action (publishing, exporting, merging) unless its review_status is `policy_approved` for that action type, as defined in the applicable ApprovalPolicy.

---

## 2. Structured Authority Basis

Free-text `legal_basis` is replaced with structured fields on every attribute record and authority assignment.

The documentary basis for an authority assignment is a sourced, evidenced, temporal, potentially disputed fact about a person — it belongs in the Claim layer (P2). `AuthorityBasisRecord` is therefore eliminated; the Claim record carrying the authority basis is referenced directly.

| Field | Type | Notes |
|---|---|---|
| `authority_basis_type` | Enum | See values below; quick discriminator for application logic without requiring a join to the Claim |
| `basis_claim_id` | UUID FK | FK to Claim; nullable. The referenced Claim carries full evidentiary detail: source, provenance, evidence_status, dispute_status, jurisdiction via source. Null for self-assertion or policy_default where no documentary basis exists |
| `basis_notes` | Text | Operational annotation distinct from evidentiary content of the Claim; nullable |

### authority_basis_type values

| Value | Description |
|---|---|
| `self_assertion` | Subject asserting their own information |
| `parental_guardianship` | Legal parent acting as guardian |
| `court_appointed_guardianship` | Guardian appointed by a court order |
| `supported_decision_making` | Formal SDM arrangement (subject retains authority; supporter assists) |
| `power_of_attorney_general` | General power of attorney |
| `power_of_attorney_personal` | Personal care power of attorney |
| `enduring_power_of_attorney` | Continuing after incapacity |
| `testamentary_executor` | Executor named in a will |
| `estate_administrator` | Court-appointed administrator (intestate) |
| `cultural_authority` | Community-recognized authority for cultural or ceremonial information |
| `institutional_authority` | Recognized institutional authority (church, government, etc.) |
| `legal_representative` | Lawyer acting under instruction |
| `stewardship_succession` | Authority transferred via LifeBook stewardship rules |
| `policy_default` | No specific authority assigned; LifeBook default rules apply |

---

## 3. AuthorityAssignment

AuthorityAssignment is a first-class model. It records who holds authority to perform specific actions regarding a specific person's information, under what terms, and for how long.

**LifeBook records authority determinations. LifeBook does not diagnose legal capacity.**  
Capacity is action-specific, not a global flag. A person may have capacity to assert their preferred name and not have capacity to approve a stewardship transfer. External determinations (court orders, medical assessments, SDM agreements) are recorded as sources; they are not generated by LifeBook.

### 3.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `person_id` | UUID FK | The person whose information is governed |
| `authority_holder_id` | UUID FK | FK to User or Entity record |
| `authority_role` | Enum | See values below |
| `scope` | Array\<ActionType\> | Which actions this assignment covers |
| `effective_from` | Date | Nullable |
| `effective_until` | Date | Nullable; null = currently active |
| `jurisdiction_id` | UUID FK | |
| `authority_basis_type` | Enum | From §2; quick discriminator |
| `basis_claim_id` | UUID FK | FK to Claim; nullable — see §2. Null for self_assertion and policy_default |
| `basis_notes` | Text | Nullable — operational annotation distinct from Claim evidentiary content |
| `is_contested` | Boolean | Default false |
| `contest_record_id` | UUID FK | FK to ContestRecord; nullable |
| `priority_order` | Integer | For ordering multiple authorities for the same action |
| `coordination_rule` | Enum | How this holder coordinates with others (see below) |
| `review_date` | Date | Scheduled review; nullable |
| `succession_behaviour` | Enum | What happens when this assignment ends (see below) |
| `succession_target_id` | UUID FK | FK to User/Entity; used with `transfer_to_named` |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | |
| `notes` | Text | Nullable |

### 3.2 authority_role values

| Value | Description |
|---|---|
| `subject` | The person themselves |
| `guardian_sole` | Sole legal guardian |
| `guardian_joint` | One of multiple joint guardians |
| `supported_decision_maker` | Person supporting subject's own decisions; does not substitute for subject |
| `legal_representative` | Lawyer or formal legal representative acting under instruction |
| `court_appointed_guardian` | Guardian appointed by a court |
| `steward` | LifeBook-designated steward |
| `executor` | Estate executor under a will |
| `estate_administrator` | Court-appointed administrator |
| `cultural_authority` | Community-recognized authority for cultural or ceremonial information |
| `institutional_authority` | Recognized institutional authority |
| `next_of_kin` | Statutory default when no other authority is assigned |

### 3.3 scope — ActionType values

| Action | Description |
|---|---|
| `assert_preferred_name` | Assert or change preferred display name |
| `assert_legal_name` | Record a legal name |
| `assert_former_name` | Record a former name |
| `assert_birth_name` | Record a birth name |
| `assert_pronouns` | Assert or change pronoun set |
| `assert_gender_descriptor` | Assert or change gender descriptor |
| `assert_indigenous_name` | Record an Indigenous name |
| `assert_ceremonial_name` | Record a ceremonial name |
| `modify_display_policy` | Change what displays in which context |
| `modify_export_policy` | Change what is included in exports |
| `modify_search_policy` | Change search eligibility |
| `approve_evidence_promotion` | Approve elevating a claim's evidence_status |
| `approve_ai_promotion` | Approve promoting an AI inference to accepted fact |
| `approve_merge` | Approve merging two Person records |
| `approve_split` | Approve splitting one Person record into two |
| `approve_publish_living` | Approve publishing information about a living person |
| `approve_contact` | Approve contacting another user or storyteller |
| `approve_share_sensitive` | Approve sharing sensitive identity information |
| `approve_posthumous_disclosure` | Approve disclosure after death |
| `transfer_stewardship` | Transfer stewardship to another party |
| `revoke_access` | Revoke another party's access |
| `archive_record` | Archive or suppress a record |
| `export_full` | Authorize a full steward-level export |

### 3.4 coordination_rule values

Governs how this authority holder coordinates with others holding the same action.

| Value | Meaning |
|---|---|
| `sole` | This holder acts alone; no coordination required |
| `joint_unanimous` | All joint holders must agree |
| `joint_majority` | Majority of joint holders must agree |
| `joint_any` | Any one joint holder may act |
| `escalate` | Cannot act without escalation to a named process or external authority |

### 3.5 succession_behaviour values

| Value | Meaning |
|---|---|
| `terminate` | Authority ends; no succession |
| `transfer_to_named` | Transfers to succession_target_id |
| `transfer_to_steward` | Transfers to current active steward |
| `transfer_to_court` | Flags for court determination |
| `policy_default` | Falls back to LifeBook default rules |

---

## 4. ApprovalPolicy

ApprovalPolicy defines what is required before a specific action may be taken, for a specific attribute type, under a specific lifecycle condition.

### 4.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `policy_code` | String | Human-readable (e.g., `PRONOUN_ASSERT_LIVING_ADULT`) |
| `action_type` | ActionType | From AuthorityAssignment scope |
| `attribute_type` | String | Nullable; if specific to a PersonName usage_type or attribute |
| `lifecycle_status` | Enum | See values below |
| `required_approvers` | JSONB | Structured approver specification (see below) |
| `notification_required` | Array\<AuthorityRole\> | Roles to notify even if not approving |
| `approval_expiry_days` | Integer | How long approval remains valid; nullable |
| `audit_required` | Boolean | Whether an audit log entry is mandatory |
| `escalation_policy_id` | UUID FK | FK to EscalationPolicy; nullable |
| `notes` | Text | Nullable |

### 4.2 lifecycle_status values

Eight values describing the person's governance situation — not the nature of the content being governed. Cultural governance crosscuts all lifecycle conditions and is captured separately (see §4.5).

| Value | Description |
|---|---|
| `living_with_capacity` | Living adult with documented or presumed capacity for this action |
| `minor_sole_guardian` | Minor with one legal guardian |
| `minor_joint_guardian` | Minor with multiple joint guardians |
| `supported_decision_making` | Formal SDM arrangement in effect for this action |
| `legal_representative` | Legal representative or court-appointed guardian holds authority for this action |
| `deceased_with_preferences` | Subject is deceased; documented identity preferences exist |
| `deceased_without_preferences` | Subject is deceased; no documented preferences for this action |
| `disputed_authority` | Authority for this action is actively contested |

**Architectural note — `cultural_governed` removed:** Cultural governance is not a person lifecycle condition. A living adult with capacity may have culturally governed content. A deceased person without preferences may have culturally governed content. Placing `cultural_governed` alongside `living_with_capacity` and `deceased_with_preferences` implies that cultural governance is a person-level lifecycle state, which it is not — it is a property of the content and the applicable governance context. Cultural governance requirements are captured via a separate ApprovalPolicy applicability dimension (§4.5). Scenario 9 (§6) describes the substantive governance rules; those rules are unchanged.

### 4.3 required_approvers JSONB structure

```json
{
  "rule": "named_subject | any_one_of | all_of | quorum | escalate",
  "roles": ["subject", "steward", "executor"],
  "named_person_id": null,
  "minimum_count": 1,
  "conditions": [
    {
      "condition_type": "evidence_status_minimum",
      "value": "supported"
    }
  ]
}
```

### 4.4 Representative ApprovalPolicy records

| policy_code | action | lifecycle | required_approvers rule | notes |
|---|---|---|---|---|
| `PREFERRED_NAME_LIVING_ADULT` | assert_preferred_name | living_with_capacity | named_subject | No other role may override |
| `PREFERRED_NAME_MINOR_SOLE` | assert_preferred_name | minor_sole_guardian | any_one_of [subject, guardian_sole] | Subject assertion takes precedence |
| `PREFERRED_NAME_DECEASED_WITH_PREFS` | assert_preferred_name | deceased_with_preferences | escalate | Only allowed if subject's documented prefs are insufficient |
| `PRONOUNS_LIVING_ADULT` | assert_pronouns | living_with_capacity | named_subject | Absolute; no override |
| `PRONOUNS_MINOR` | assert_pronouns | minor_sole_guardian | any_one_of [subject] | Subject assertion from age of self-identification; guardian assertion does not override subject |
| `PRONOUNS_DECEASED_WITH_PREFS` | assert_pronouns | deceased_with_preferences | steward | Steward preserves subject's last documented preference |
| `INDIGENOUS_NAME_ANY` | assert_indigenous_name | any | all_of [subject, cultural_authority] | Community authority co-required for all lifecycle states |
| `MERGE_LIVING` | approve_merge | living_with_capacity | all_of [subject, steward] | Both subject and steward must approve |
| `MERGE_DECEASED` | approve_merge | deceased_with_preferences | any_one_of [executor, steward] | Subject no longer available |
| `AI_PROMOTION_ANY` | approve_ai_promotion | any | any_one_of [steward, subject] | AI may never self-approve |
| `PUBLISH_LIVING` | approve_publish_living | living_with_capacity | named_subject | Absolute; subject must approve publication about themselves |
| `POSTHUMOUS_DISCLOSURE_WITH_PREFS` | approve_posthumous_disclosure | deceased_with_preferences | any_one_of [executor, steward] | Must respect documented subject preferences |
| `POSTHUMOUS_DISCLOSURE_NO_PREFS` | approve_posthumous_disclosure | deceased_without_preferences | all_of [steward] | Steward governs; escalation available |

### 4.5 Cultural Governance Applicability Dimension

Cultural governance is a content-level property, not a person-level lifecycle condition. The correct architectural representation is a separate applicability dimension on ApprovalPolicy that indicates whether the policy applies when the content in question carries cultural governance requirements.

**Why `cultural_governed` cannot be a lifecycle_status value:**

1. Cultural governance is action/content-scoped, not person-scoped. The same person (living, with capacity) may have both ordinary content and culturally governed content. No single lifecycle condition can capture both states simultaneously.
2. Adding `cultural_governed` to the lifecycle_status enum implies it participates in the same state machine as `living_with_capacity` and `deceased_with_preferences`. It does not — a person does not transition into or out of `cultural_governed` as a lifecycle event.
3. The `authority_context_policy_conditions` table maps `authority_context_code` to `governance_lifecycle_condition`. Cultural governance is not an authority context condition — it is an additional policy selector applied after the lifecycle condition is determined.

**Chosen representation — `cultural_governance_required` flag on ApprovalPolicy:**

ApprovalPolicy gains a boolean field:

```
cultural_governance_required  BOOLEAN  NOT NULL DEFAULT FALSE
```

An ApprovalPolicy with `cultural_governance_required = TRUE` applies when (a) the lifecycle condition matches AND (b) the content in question involves culturally governed information. This creates a two-dimensional policy selector: lifecycle × cultural governance applicability.

**Effect on policy lookup:**

When an action is requested:
1. Determine the subject's `governance_lifecycle_condition` (from the active AuthorityAssignment)
2. Determine whether the content being acted on is culturally governed (from the content's `access_classification_code` or a forthcoming cultural governance flag on the content record)
3. Apply ApprovalPolicy rows where `lifecycle_status` matches AND `cultural_governance_required` matches

Policies with `cultural_governance_required = FALSE` apply to non-culturally-governed content under that lifecycle condition. Policies with `cultural_governance_required = TRUE` apply when the same lifecycle condition holds AND the content is culturally governed. This allows lifecycle-neutral cultural governance policies (i.e., `cultural_governance_required = TRUE` with `lifecycle_status` covering all conditions).

**Alternatives considered and rejected:**

- `required_access_classification_code TEXT FK → access_classifications(code)`: More general but couples cultural governance selection to the access classification system, which is designed for access control, not policy selection. Rejected for mixing concerns.
- `required_context_profile_code TEXT FK`: Would require a Context Profile model that is not yet designed. Deferred.
- Normalized policy-applicability table: Appropriate for multi-dimensional policy selection with more than two dimensions. May be adopted in a future migration if additional policy dimensions emerge. Current approach (boolean flag) is sufficient for v1.

**Implementation note:** The `cultural_governance_required` field will be added to the ApprovalPolicy table in the migration that creates that table. It is not part of `0001_types_and_vocabularies.sql`. The governance vocabulary tables in 0001 do not need to encode this dimension; the flag lives on the policy record.

---

## 5. ConflictResolutionPolicy

ConflictResolutionPolicy defines how competing assertions are resolved for a specific purpose when no clear authority hierarchy settles the question.

### 5.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `policy_code` | String | Human-readable |
| `attribute_type` | String | Applicable usage_type or attribute type |
| `conflict_type` | Enum | See below |
| `purpose` | Enum | See below |
| `resolution_rule` | Enum | See below |
| `priority_order` | JSONB | Ordered list of authority roles for priority resolution |
| `lifecycle_overrides` | JSONB | Different rules per lifecycle_status |
| `notes` | Text | Nullable |

### 5.2 conflict_type values

| Value | Description |
|---|---|
| `competing_assertions` | Two or more parties have asserted different values |
| `evidence_contradiction` | Documentary evidence conflicts with an oral assertion |
| `authority_dispute` | Two parties each claim authority to assert |
| `ai_vs_human` | AI inference conflicts with a human assertion |
| `historical_vs_current` | A historical record conflicts with the subject's current self-description |

### 5.3 purpose values

| Value | Description |
|---|---|
| `display_public` | What appears in public-facing views |
| `display_family` | What appears in family-facing views |
| `display_steward` | What is visible to stewards |
| `ordinary_search` | What is indexed for ordinary search |
| `identity_resolution_search` | What is indexed for restricted identity-resolution search |
| `default_export` | What is included in standard exports |
| `steward_export` | What is included in full steward exports |
| `ai_generation` | What the AI may use when generating content |
| `narrative_composition` | What a human narrator may reference |

### 5.4 resolution_rule values

| Value | Meaning |
|---|---|
| `subject_wins` | Subject's assertion is authoritative |
| `documented_preference_wins` | Subject's last documented preference governs (for deceased) |
| `highest_evidence_status` | Claim with higher evidence_status prevails |
| `most_recent` | Most recently asserted or most recently effective value |
| `documentary_over_oral` | Documentary source prevails over unsubstantiated oral assertion |
| `steward_decides` | Active steward makes the determination; audit log required |
| `freeze_pending_review` | No action until human review resolves the conflict |
| `escalate_external` | Escalate to external legal or community process |

### 5.5 Representative ConflictResolutionPolicy records

| attribute | conflict_type | purpose | resolution_rule | notes |
|---|---|---|---|---|
| preferred_name | competing_assertions | display_public | subject_wins | For living persons with capacity |
| preferred_name | historical_vs_current | display_public | subject_wins | Current preferred name prevails over historical usage |
| preferred_name | competing_assertions | display_public | documented_preference_wins | For deceased with preferences |
| preferred_name | competing_assertions | display_public | steward_decides | For deceased without preferences |
| pronoun_set | competing_assertions | ai_generation | subject_wins | AI must use subject's asserted pronouns |
| pronoun_set | historical_vs_current | ai_generation | subject_wins | AI uses current pronouns even when generating about past periods |
| former_name | competing_assertions | identity_resolution_search | steward_decides | Steward determines which former names appear in restricted search |
| former_name | competing_assertions | display_public | freeze_pending_review | Former name must not appear publicly without resolution |
| indigenous_name | competing_assertions | any | escalate_external | Community authority co-required; LifeBook does not resolve internally |
| legal_name | evidence_contradiction | identity_resolution_search | documentary_over_oral | Documentary evidence prevails for legal name matching |
| legal_name | ai_vs_human | display_public | subject_wins | Subject's stated legal name prevails over AI extraction |

---

## 6. Decision Matrix

Nine lifecycle scenarios. For each: who may assert, who must approve consequential actions, how conflicts resolve, and any special rules.

---

### Scenario 1: Capable Living Adult

**Definition:** A living person for whom no capacity determination limiting the relevant action is in effect. Presumed capable unless a documented determination exists for a specific action.

| Dimension | Rule |
|---|---|
| **Who may assert identity attributes** | Subject is sole authoritative asserter for all personal identity attributes (preferred name, pronouns, gender descriptor, former names). Other roles may contribute supporting information (historical records, family recollections) but cannot override subject |
| **Who approves consequential actions** | Subject for all actions affecting their own record. Steward co-approval required for stewardship transfers and merge/split operations |
| **Conflict resolution** | Subject wins for all personal identity attributes. Documentary evidence prevails for historical facts where subject has not made a conflicting assertion |
| **Display** | Subject's asserted preferred name and pronouns govern all views. Sensitive attributes hidden unless subject has enabled display |
| **AI generation** | Must use subject's current authorized display identity |
| **Former names** | Hidden from all display; accessible in identity-resolution search only with steward authorization and audit log |
| **Special rules** | Family assertions about the subject's identity are recorded as contributions, not as authoritative claims, and do not appear in conflict resolution as equals to subject assertion |

---

### Scenario 2: Minor with One Guardian

**Definition:** A person under the applicable age of majority, or without capacity for a specific action, with a single legal guardian assigned.

| Dimension | Rule |
|---|---|
| **Who may assert identity attributes** | Guardian asserts for the minor on legal and administrative attributes. Subject may assert personal identity attributes (preferred name, pronouns, gender descriptor) from age of demonstrated self-identification, which is not a fixed calendar age |
| **Who approves consequential actions** | Guardian for legal and administrative actions. Once subject has asserted personal identity attributes, subject's assertion governs those attributes regardless of guardian's position |
| **Conflict resolution** | For personal identity attributes after subject's assertion: subject wins. For legal/administrative attributes: guardian's documented basis prevails over oral assertion. For historical information contributed by guardian before subject reaches capacity: recorded with guardian as asserter; subject may annotate or restrict upon capacity |
| **Authority transfer** | When subject demonstrates capacity for a specific action, AuthorityAssignment for that action transfers from guardian to subject. This is action-specific and is not a single moment |
| **Special rules** | Guardian may not add a `former_name` record that the subject objects to once the subject has asserted capacity for that action. Guardian assertion of pronouns or gender descriptor does not override subject's own assertion from any age |

---

### Scenario 3: Minor with Multiple Guardians

**Definition:** A person under applicable age of majority with two or more joint guardians.

| Dimension | Rule |
|---|---|
| **Who may assert identity attributes** | As Scenario 2, but joint guardians operate under their coordination_rule (unanimous, majority, or any, per the AuthorityAssignment records) |
| **Who approves consequential actions** | Coordination_rule governs. Where coordination_rule is `joint_unanimous`, both must approve. Where `joint_majority`, majority suffices. Where `joint_any`, any one may act |
| **Conflict resolution between guardians** | Apply coordination_rule. If coordination_rule is `joint_unanimous` and guardians disagree: freeze_pending_review. Escalation available. Guardian disagreement on personal identity attributes that the subject has already asserted: subject wins |
| **Subject assertion** | Same as Scenario 2. Subject's assertion of personal identity attributes takes precedence over disagreeing guardians from the point of assertion |
| **Special rules** | Where guardians are in dispute about a consequential action, no action is taken until resolved. Read-only access is maintained. Each guardian's position is recorded with their respective AuthorityAssignment |

---

### Scenario 4: Supported Decision-Making Arrangement

**Definition:** A formal arrangement in which the subject retains decision-making authority but a supporter assists them in understanding information, communicating decisions, and exercising rights. The supported decision-maker does not substitute for the subject.

| Dimension | Rule |
|---|---|
| **Who may assert identity attributes** | Subject retains sole authority. The supported decision-maker may assist the subject in communicating an assertion but is recorded as a facilitator, not as an asserter. The asserted_by_role remains `subject` |
| **Who approves consequential actions** | Subject approves all actions, with supported decision-maker facilitating. The supported decision-maker may not approve on behalf of the subject |
| **Conflict resolution** | Subject wins. Supported decision-maker's independent view is not relevant to conflict resolution |
| **Documentation requirement** | The SDM agreement must be recorded as an AuthorityBasisRecord with authority_basis_type `supported_decision_making`. Scope must be specified. Any assertion facilitated through an SDM arrangement should note facilitation in basis_notes |
| **Special rules** | SDM is meaningfully different from guardianship. The system must not treat a supported decision-maker as a guardian. If a party claims to be acting under SDM but is asserting rather than facilitating, this is an authority dispute (see Scenario 8) |

---

### Scenario 5: Legal Representative or Court-Appointed Guardian

**Definition:** A person whose authority for specific actions has been transferred to a legal representative, attorney acting under power of attorney, or court-appointed guardian by a documented legal instrument.

| Dimension | Rule |
|---|---|
| **Who may assert identity attributes** | Scope of the legal instrument defines which actions are covered. Scope must be recorded explicitly in the AuthorityAssignment. Authority does not extend beyond documented scope |
| **Who approves consequential actions** | Legal representative or court-appointed guardian, within scope. Actions outside scope escalate |
| **Conflict resolution** | The legal instrument's scope governs. For personal identity attributes (pronouns, gender descriptor, preferred name): the system records that no subject assertion is available; legal representative's assertion is recorded with lower conflict-resolution priority than a subject assertion would hold. The system must not treat guardian assertion of personal identity attributes as equivalent to subject assertion |
| **Capacity determination** | LifeBook records the existence of the legal instrument, not a clinical capacity finding. If the subject's capacity for a specific action is disputed, that is treated as Scenario 8 |
| **Special rules** | A court-appointed guardian for financial decisions does not automatically have authority over identity attributes. Scope must be specified. Where scope is ambiguous, escalate. The system must not expand legal representative authority beyond what the instrument specifies |

---

### Scenario 6: Deceased Person with Documented Identity Preferences

**Definition:** Subject is deceased and has left documented instructions about how their identity should be represented, which attributes may be disclosed, and under what conditions.

| Dimension | Rule |
|---|---|
| **Who may assert identity attributes** | No new assertions of personal identity attributes. Steward may record historical information with appropriate provenance |
| **Who approves consequential actions** | Executor for estate matters. Steward for LifeBook governance. Documented subject preferences are authoritative and neither executor nor steward may override them |
| **Conflict resolution** | Documented subject preferences govern display and export. Steward decides for matters not addressed by documented preferences. Family assertion does not override documented preference |
| **Display** | Subject's last documented preferred name and pronoun set govern all display. AI generation must use the same. Former names and restricted attributes remain restricted per subject's instructions |
| **Posthumous disclosure** | Only permitted within scope documented by subject, or as approved by executor/steward within that scope |
| **Special rules** | If a documented preference conflicts with an executor's instruction, the subject's preference governs identity display. Executor authority covers estate and legal matters; it does not override subject's identity instructions. Community consultation required for Indigenous or ceremonial information regardless of steward/executor authority |

---

### Scenario 7: Deceased Person without Documented Identity Preferences

**Definition:** Subject is deceased. No instructions exist for the relevant attribute or action.

| Dimension | Rule |
|---|---|
| **Who may assert identity attributes** | Steward may record historical information. Family may contribute recollections. All contributions are recorded with asserter and evidence_status |
| **Who approves consequential actions** | Steward governs. Executor for estate matters. Escalation available |
| **Conflict resolution** | Steward decides. Family assertions are considered but are not automatically authoritative. Most recent known preferred name and pronoun set are used as the default until steward makes a determination |
| **Display default** | Most recent known preferred name and pronouns. If no preferred name on record, most recent legal name. No former names surfaced in display. Sensitive attributes remain restricted |
| **AI generation default** | Uses most recent known preferred name and pronouns. Does not expose restricted attributes |
| **Special rules** | The absence of documented preferences does not mean family claims are authoritative. It means steward must make a governance determination. Community consultation required for Indigenous or ceremonial information — steward authority does not extend to culturally governed information |

---

### Scenario 8: Disputed Authority

**Definition:** Two or more parties each claim authority to assert information or approve an action, and the dispute has not been resolved by an external legal process.

| Dimension | Rule |
|---|---|
| **Who may assert identity attributes** | No new assertions affecting the disputed attribute or action are accepted until the dispute is resolved. Each claimant's position is recorded with dispute_status `disputed` |
| **Who approves consequential actions** | Freeze. No consequential action may proceed under a disputed authority |
| **Read access** | Maintained for all parties holding pre-dispute access rights. No new access is granted during the dispute |
| **Audit** | All access during a disputed period is logged mandatorily |
| **Resolution** | External legal process or LifeBook dispute resolution process. LifeBook records the outcome; it does not adjudicate |
| **AI generation during dispute** | AI uses pre-dispute display identity only. Must not generate content that assumes the outcome of the dispute |
| **Special rules** | Where the subject is alive and has asserted personal identity attributes prior to the dispute, those assertions remain in effect. The dispute does not suspend or override the subject's prior valid assertions |

---

### Scenario 9: Culturally Governed or Restricted Information

**Definition:** The relevant information carries cultural protocols that govern its recording, access, use, and transmission. Includes Indigenous names, ceremonial names, and other culturally restricted information.

| Dimension | Rule |
|---|---|
| **Who may assert** | Subject plus designated community authority jointly. Neither may act without the other for culturally governed information. External parties (family, system extraction, other LifeBooks) may not assert culturally governed information without both subject and community authorization |
| **Who approves consequential actions** | Subject and community authority jointly for all actions. Steward authority does not extend to culturally governed information |
| **Recording** | The system must not record culturally governed information if the relevant cultural authority has indicated it should not be recorded in a digital system. A record that a name exists but is not recorded is acceptable. Forcing digital recording is not |
| **Display** | All contexts denied by default. Subject and community authority must jointly specify any permitted context |
| **Search** | All search denied by default. No culturally governed information is accessible through ordinary or restricted search without joint authorization |
| **Export** | Excluded from all exports by default. Joint authorization required |
| **AI generation** | Culturally governed information must not be passed to any AI model without joint authorization. This is an absolute boundary enforced at the data access layer, not only in the prompt |
| **Posthumous** | Does not transfer to steward automatically. Community consultation required. Community protocols may require that the information be retired or treated differently after death |
| **Pre-deployment requirement** | The `indigenous` and `ceremonial` name types, and any culturally governed attribute type, must not be deployed without direct engagement with relevant communities and an agreed governance policy. This is a pre-deployment blocker |

---

## 7. Content Type Distinction

Four content types that must be treated as fundamentally different, with different identity display rules and different handling of restricted attributes.

### 7.1 Archival Transcript

**Definition:** A verbatim reproduction of an original document, recording, or primary source exactly as it exists.

| Rule | Specification |
|---|---|
| **Modification** | Never. The archival transcript is fixed at the moment of capture |
| **Identity in content** | Names and pronouns appear exactly as in the original source, regardless of the subject's current identity. A former name in a 1972 document appears as it appears in the document |
| **Context requirement** | Must be accompanied by: source citation, date of original, capturing party, and a contextual note if the document uses a name or pronoun that differs from the subject's current authorized display identity |
| **Access** | Governed by the sensitivity of the underlying source. A document containing a former name does not inherit the former_name's display policy; it inherits the source's access policy. These are different |
| **AI** | Archival transcripts may be provided to an AI as source context. The AI must not reproduce restricted names from the transcript in generated output |
| **Search indexing** | A restricted name appearing in an archival transcript is not indexed in ordinary search. It may be indexed in identity-resolution search under steward authorization |

### 7.2 Historical Quotation

**Definition:** A specific excerpt from a source, presented within a contextual frame (timeline entry, annotation, story).

| Rule | Specification |
|---|---|
| **Modification** | Never. The quoted text is verbatim |
| **Framing** | The excerpt is presented within a frame that provides context: source, date, relationship to subject |
| **Former name handling** | If the excerpt contains a former name that the subject has marked restricted, the excerpt must be presented with a contextual annotation: "[name as it appears in the original document]" or equivalent. The name is not hidden because it is in a source; the source is displayed in context |
| **AI** | Historical quotations may be provided as source context. AI must not reproduce restricted names in generated output. The AI's output is governed by the AI generation rules, not by the quotation's content |

### 7.3 Respectful Presentation

**Definition:** A LifeBook-curated view of information about a person, intended for display to family, public, or other audiences. This is the default mode for person profiles, timeline views, and family-facing content.

| Rule | Specification |
|---|---|
| **Identity used** | Current authorized display identity: subject's active preferred name, current pronoun set, no restricted attributes |
| **Restricted attributes** | Must not appear. No former names in display, no gender descriptor unless subject has enabled it for this context, no Indigenous or ceremonial names unless subject has authorized |
| **AI generation** | Any AI-generated content within a respectful presentation follows the same identity rules. Current authorized display identity only |
| **Historical references** | If a respectful presentation references an archival source that contains a former name, the reference uses the subject's current authorized display identity. "See the 1972 document in which [Subject's preferred name] appears" — not the former name |
| **Narrative voice** | Pronouns in curatorial narrative use the subject's current active pronoun set |

### 7.4 AI-Generated Summary or Narrative

**Definition:** Content generated by an AI agent — summaries, narrative drafts, questions, context packages, research outputs.

| Rule | Specification |
|---|---|
| **Identity** | Current authorized display identity only. AI must not use restricted attributes even if they are present in the AI's context window |
| **Context management** | Restricted attributes must not be passed to an AI model when the output will be used in a display context that does not permit those attributes. This is enforced at the data access layer. The prompt must not contain what the output may not produce |
| **Labeling** | All AI-generated content must be labeled as such. The label must not be removable before human review |
| **Review gate** | AI-generated content may not be promoted to an accepted narrative or factual record without human review and policy_approved review_status |
| **Pronouns in historical context** | When generating content about a past period in a person's life, the AI must use the subject's current active pronoun set. The AI must not reason "this narrative is set in 1972 therefore I should use the pronouns from that period." The subject's current self-identification governs the narrative voice, regardless of the period described |
| **Former name rule** | AI must not reproduce a former name in any generated output, even if the former name is in the source material the AI was given as context. If the former name is in a source and the AI needs to refer to it, the AI must use "[name in original document]" or equivalent placeholder |
| **Consequential actions** | AI may recommend consequential actions (suggest a merge, propose that two records may be the same person). It must not execute consequential actions. Every AI recommendation of a consequential action creates a pending approval record for the applicable policy |

---

## 8. Interaction Rules — Preventing Identity Leakage

The four content types create four isolation boundaries. The following leakage paths must be prevented at the data access layer, not only by UI controls.

| Leakage risk | Prevention |
|---|---|
| Restricted name in archival transcript surfaces in ordinary search | Archival transcript text is indexed under the source's access policy. Restricted name strings in transcripts are not added to the ordinary search index regardless of source access level |
| AI provided a restricted former name as context generates output using that name | Restricted attributes are stripped from AI context before model call when output will be used in any context that does not permit those attributes. This is enforced in the data access layer before the model call, not by prompt instruction alone |
| AI-generated content promoted to accepted narrative before review | review_status `pending` blocks promotion. Policy_approved status requires human action. No automated pathway from AI output to accepted record |
| Former name added by a family member surfaces in family-facing view | `former_name` usage_type default display policy denies family_ui. This cannot be overridden by the asserting party; only by the subject |
| Steward export includes culturally governed attributes without joint authorization | Culturally governed attributes are excluded from steward export by default. Joint subject + community_authority authorization is required to override. Steward authority alone is insufficient |
| A merge operation exposes a restricted former identity | Merge operations require policy_approved approval. The merge audit record must include which identity attributes were consolidated and which remain restricted in the merged record |

---

## 9. Open Questions Requiring Resolution Before Migration

1. **EscalationPolicy table:** Referenced in ApprovalPolicy but not yet designed. Must define escalation paths, timelines, and notification rules before the migration is written.

2. **ContestRecord table:** Referenced in AuthorityAssignment. Must define how disputes are formally opened, what information is captured, who is notified, and what the resolution pathway is.

3. **Jurisdiction table:** Referenced throughout. Must be populated for at minimum: Canada (federal), Ontario, Alberta, British Columbia, Ukraine (for Iryna-related records), and a generic international default. PIPEDA provisions must be mapped to jurisdiction-specific policy overrides.

4. **CapacityDetermination records:** The system records authority determinations. Where a formal capacity determination exists (court order, assessed SDM agreement), it should be captured as a separate record type that qualifies AuthorityAssignment scope. Design needed before migration.

5. **AuthorityBasisRecord table:** Referenced as the target of `authority_basis_record_id`. Must define what is stored (document metadata, not document content), how external documents are referenced, and how they are validated.

6. **Indigenous governance policy:** Must be developed before any deployment of culturally governed attribute types. This is an external engagement requirement, not a design task.

7. **AI context management specification:** The rule that restricted attributes must be stripped before model calls must be specified as a formal access-layer behaviour, not only as a policy document. This defines the interface between the data layer and the AI agent layer.

8. **review_status transition authorization:** Who may move a claim from `pending` to `human_reviewed` to `policy_approved`? This depends on the applicable ApprovalPolicy, but the transition mechanism itself must be specified before the migration.

---

*Next step: Design EscalationPolicy and ContestRecord, resolve open questions 3–5 above, then produce the Person anchor fields and the Supabase migration.*
