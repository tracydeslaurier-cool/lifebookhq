# LifeBook PersonAttribute Catalogue
**Version:** 0.2 Draft  
**Status:** Pre-schema design document — G2 blocker resolved (confidence normalization applied 2026-07-25)  
**Produced:** 2026-07-22  
**Revised:** 2026-07-25

### Revision history

| Version | Date | Summary |
|---|---|---|
| 0.1 | 2026-07-22 | Initial catalogue; all four person attribute types defined |
| 0.2 | 2026-07-25 | G2 blocker resolved: replaced combined `confidence` enum on PersonName and PersonNameDerivative with separate `evidence_status`, `dispute_status`, `precision_status`, and `review_status` fields per GOVERNANCE_MODELS.md §1 and CONTENT_LAYER.md §18.5; `review_status` on PersonNameDerivative clarified as an independent field (not inherited from parent) — a derivative may remain pending after the parent name is approved |  

---

## Structural Decisions

### Names: One table, not fifteen types

All name-type attributes share the same structure. They are stored in a single `PersonName` table with a `usage_type` discriminator. Default policies per usage type are stored in a separate `NameUsageTypePolicy` configuration table, not hardcoded in application logic.

**`PersonName` usage types at launch:**
`legal` · `preferred` · `former` · `birth` · `married` · `nickname` · `stage` · `pen` · `religious` · `indigenous` · `ceremonial` · `institutional` · `pseudonym`

**Derivative name records** (transliterations, translations) are stored in `PersonNameDerivative` with a `parent_name_id` FK. They inherit sensitivity from the parent. They are not independent assertions.

**Name components** (honorific, name_suffix) are fields within `PersonName`, not separate attribute types. Appointed titles with independent provenance may become a `PersonTitle` table in a future version.

### Genuine separate attribute types at launch

- `PersonPronouns` — structurally distinct; subject-only authority; no documentary evidence appropriate
- `PersonGenderDescriptor` — structurally distinct; subject-only authority; excluded from default exports

### Authority model

No hierarchy scalar. Every attribute record references:
- `asserted_by_role` — the role of the person making the assertion
- `legal_basis` — the legal or documentary basis for the assertion (nullable)
- `approval_policy_id` — FK to `ApprovalPolicy` (handles named subject, any steward, quorum, policy condition)
- `conflict_resolution_policy_id` — FK to `ConflictResolutionPolicy`, keyed by attribute type and purpose (display / search / export)

### Display contexts

Not a bitmask. Each governed attribute record carries a nullable `display_policy_id` FK referencing `display_policies`. The policy contains one `DisplayPolicyRule` per applicable display context. The nine governed display contexts are: `public_ui`, `family_ui`, `steward_ui`, `historical_record`, `ordinary_search`, `identity_resolution_search`, `default_export`, `steward_export`, `ai_generation`. Each rule specifies `allow`, `deny`, or `conditional` for its context. See DISPLAY_POLICY_MODEL.md for the full two-table specification, lifecycle rules, and default evaluation rules.

---

## PersonName Catalogue

### Fields common to all PersonName records

| Field | Notes |
|---|---|
| `id` | UUID |
| `person_id` | FK to Person anchor |
| `usage_type` | Enum (see types below) |
| `honorific` | Nullable string (Dr., Mx., Chief, Rev.) |
| `given_names` | Array of strings |
| `middle_names` | Array of strings |
| `family_name` | Nullable string |
| `name_suffix` | Nullable string (Jr., III, PhD) |
| `full_name_string` | Denormalized display string; may differ from component concatenation |
| `name_script` | ISO 15924 script code (Latn, Cyrl, Arab, Deva, etc.) |
| `language_code` | BCP 47 language tag |
| `effective_from` | Date or approximate date; nullable |
| `effective_until` | Date or approximate date; nullable (null = currently active) |
| `asserted_by_role` | Role of asserting party |
| `asserted_by_id` | FK to User/Steward record |
| `legal_basis` | Nullable text (e.g., "Marriage certificate CA-ON-1987-04-12"); operational notation distinct from Claim evidentiary content |
| `source_id` | FK to Source record; nullable |
| `evidence_status` | Enum: `unreviewed` / `asserted` / `inferred` / `supported` / `corroborated` — see GOVERNANCE_MODELS.md §1.1. AI agents may set up to `inferred`; elevation to `supported` or `corroborated` requires human approval under the applicable ApprovalPolicy |
| `precision_status` | Enum: `exact` / `approximate` / `range` / `unknown` — see GOVERNANCE_MODELS.md §1.2 |
| `dispute_status` | Enum: `uncontested` / `disputed` / `contradicted` / `retracted` / `superseded` — see GOVERNANCE_MODELS.md §1.3. AI must not independently change dispute_status |
| `review_status` | Enum: `pending` / `human_reviewed` / `policy_approved` — see GOVERNANCE_MODELS.md §1.4. A PersonName record may not be used as the basis for a consequential action unless review_status is `policy_approved` for that action type |
| `approval_policy_id` | FK to ApprovalPolicy |
| `conflict_resolution_policy_id` | FK to ConflictResolutionPolicy |
| `imposition_context` | Nullable text; used for `institutional` type to record that name was imposed |
| `notes` | Internal provenance notes; not displayed |
| `created_at` | Timestamp |
| `created_by_id` | FK to User |

---

### `legal`

**Definition:** The name appearing on current or historical official government documents (passport, birth certificate, court order, national registry).

| Attribute | Specification |
|---|---|
| **Cardinality** | Multiple concurrent permitted (person may have legal names in more than one jurisdiction); each with independent temporal bounds |
| **Temporal** | Yes. `effective_from` = date of legal instrument; `effective_until` = date superseded or null |
| **Default sensitivity** | Medium. Public record by nature but may be sensitive if legal change has not been disclosed in personal contexts |
| **Permitted asserting roles** | Subject · legal_guardian (with documentation) · steward (post-death, with documentation) · legal_representative · system (from document extraction, lower confidence) |
| **Default display contexts** | `family_ui`: permitted · `historical_record`: permitted · `identity_resolution_search`: permitted · `public_ui`: denied (preferred_name governs) · `ordinary_search`: denied · `default_export`: denied · `steward_export`: permitted |
| **Ordinary search** | No. Use preferred_name for display-facing search |
| **Restricted search** | Yes. Available to stewards and identity-resolution processes with audit log |
| **Export** | Included in full steward export. Excluded from public and default exports. Redactable by living subject on request |
| **Conflict resolution** | Most recent documentary evidence takes precedence over unsupported oral assertion. Subject's assertion of their current legal name takes precedence over family assertion |
| **Posthumous treatment** | Preserved as historical record. Display governed by steward rules. Not automatically surfaced in public views |
| **Minor / guardian treatment** | Guardian asserts on behalf of minor. Subject may assert own legal name upon emancipation, court order or documented capacity. No fixed age |
| **Evidentiary expectations** | Government-issued document strongly preferred. Oral assertion accepted with `asserted` confidence. Document extraction accepted with `inferred` confidence pending review |

---

### `preferred`

**Definition:** The name the person has expressed a preference to be called in ordinary contexts. Takes precedence over all other name types for display in active views.

| Attribute | Specification |
|---|---|
| **Cardinality** | One active preferred name per display context at a time; may vary by context (professional vs. personal) |
| **Temporal** | Yes |
| **Default sensitivity** | Low |
| **Permitted asserting roles** | Subject (sole authority for living persons with capacity) · steward (post-death, based on documented preference) · family (if subject lacks capacity, with lower conflict-resolution priority) |
| **Default display contexts** | All contexts permitted by default: `public_ui`, `family_ui`, `ordinary_search`, `identity_resolution_search`, `default_export`, `steward_export`, `ai_generation` |
| **Ordinary search** | Yes |
| **Restricted search** | Yes |
| **Export** | Yes, in all exports |
| **Conflict resolution** | Subject assertion is authoritative over all other asserting roles for living persons with capacity. No family assertion overrides subject |
| **Posthumous treatment** | Subject's last documented preference is preserved and governs display. Steward may update only with evidence of expressed subject preference (e.g., documented instruction). Family assertion does not override |
| **Minor / guardian treatment** | Subject may assert from age of demonstrated self-identification (not a fixed age). Subject assertion takes precedence over guardian from point of subject's assertion |
| **Evidentiary expectations** | Subject oral or written assertion is sufficient. No documentary evidence required or appropriate |

---

### `former`

**Definition:** A name previously used by the person that is no longer preferred. Includes deadnames, names used before transition, names abandoned for personal reasons.

| Attribute | Specification |
|---|---|
| **Cardinality** | Multiple |
| **Temporal** | Yes. `effective_until` is the defining feature |
| **Default sensitivity** | **HIGH.** Must be treated as potentially a deadname or a name deliberately abandoned. Default to most restrictive settings |
| **Permitted asserting roles** | Subject (to document own history) · steward (post-death) · system (from historical document extraction, requires review before acceptance) · family assertion **requires subject approval** for living persons |
| **Default display contexts** | `historical_record`: permitted · `identity_resolution_search`: permitted (steward-authorized only, with audit log) · `public_ui`: denied · `family_ui`: denied · `ordinary_search`: denied · `default_export`: denied · `steward_export`: permitted with sensitivity marker |
| **Ordinary search** | **No** |
| **Restricted search** | Yes, with steward authorization and mandatory audit log entry |
| **Export** | Excluded from all default and public exports. Included in steward-authorized full export with mandatory sensitivity marker and provenance |
| **Conflict resolution** | Subject controls whether former name is recorded at all. Family may not add a former name for a living person without subject approval. If subject objects to a family-asserted former name, subject assertion governs |
| **Posthumous treatment** | Preserved in identity-resolution index. Display governed by steward rules and any documented subject instruction. If subject documented a preference not to surface a former name, steward must honour that preference |
| **Minor / guardian treatment** | Guardian may document former names from before the minor's capacity. Subject may suppress or restrict upon reaching capacity |
| **Evidentiary expectations** | Source documentation preferred but not required. Subject assertion sufficient. System-extracted former names require human review before acceptance into the record |

---

### `birth`

**Definition:** The name recorded at birth, as it appears on the birth certificate or equivalent document. May differ from preferred, legal, and all other types.

| Attribute | Specification |
|---|---|
| **Cardinality** | One (rare exception: adoption from a different naming jurisdiction may produce two) |
| **Temporal** | `effective_from` = birth date; `effective_until` = first legal name change or adoption order, or null |
| **Default sensitivity** | Medium. May be highly sensitive for adoptees, for persons who have transitioned, for Indigenous persons whose birth certificate name differs from their community name |
| **Permitted asserting roles** | Subject · legal_guardian · steward · system (from birth record extraction) |
| **Default display contexts** | `historical_record`: permitted · `identity_resolution_search`: permitted · `public_ui`: denied · `family_ui`: denied by default (subject may enable) · `ordinary_search`: denied · `default_export`: denied · `steward_export`: permitted |
| **Ordinary search** | No |
| **Restricted search** | Yes |
| **Export** | Excluded from public export for living persons unless subject explicitly consents. Included in full steward export |
| **Conflict resolution** | Documentary evidence (birth certificate) takes precedence over oral assertion. Subject may mark as sensitive or restricted regardless of documentary evidence. Subject's restriction instruction governs display |
| **Posthumous treatment** | Preserved as genealogical record. Display governed by steward rules |
| **Minor / guardian treatment** | Guardian asserts and documents. Subject may annotate and restrict upon capacity |
| **Evidentiary expectations** | Birth certificate is the canonical source. Oral family recollection accepted at `asserted` confidence. Hospital record or equivalent accepted at `supported` confidence |

---

### `married`

**Definition:** A name adopted upon or following marriage, civil union, or equivalent legally recognized partnership.

| Attribute | Specification |
|---|---|
| **Cardinality** | Multiple (serial marriages, hyphenation choices) |
| **Temporal** | Yes. `effective_from` = date of marriage or legal name change |
| **Default sensitivity** | Low. Generally a public record |
| **Permitted asserting roles** | Subject · steward · system (from marriage record extraction) · family |
| **Default display contexts** | `historical_record`: permitted · `family_ui`: permitted · `identity_resolution_search`: permitted · `public_ui`: per subject preference · `ordinary_search`: only if overlaps with preferred_name period |
| **Ordinary search** | Yes if current. No if superseded |
| **Restricted search** | Yes |
| **Export** | Yes for historical record. Current married name follows preferred_name display rules |
| **Conflict resolution** | Documentary evidence (marriage certificate, court order) preferred. Subject controls current display name regardless of marital record |
| **Posthumous treatment** | Preserved as genealogical record |
| **Minor / guardian treatment** | Standard minor rules. Early marriage with guardian consent accepted with guardian assertion |
| **Evidentiary expectations** | Marriage certificate or legal name-change order preferred. Oral assertion accepted at `asserted` confidence |

---

### `nickname`

**Definition:** An informal name used in personal contexts, given by others or self-adopted.

| Attribute | Specification |
|---|---|
| **Cardinality** | Multiple concurrent |
| **Temporal** | Yes, though dates often approximate |
| **Default sensitivity** | Low |
| **Permitted asserting roles** | Subject · family · steward |
| **Default display contexts** | `family_ui`: permitted · `historical_record`: permitted · `public_ui`: per subject preference · `ordinary_search`: denied · `identity_resolution_search`: permitted (for narrative matching) |
| **Ordinary search** | No |
| **Restricted search** | Yes, for narrative matching |
| **Export** | Included in family export. Excluded from public export unless subject opts in |
| **Conflict resolution** | Subject preference governs display. Family assertion is suggestive, not authoritative |
| **Posthumous treatment** | Preserved. Display per steward rules |
| **Minor / guardian treatment** | Family assertion common for children. No special restrictions |
| **Evidentiary expectations** | Oral assertion sufficient. Documented use in correspondence or photographs acceptable corroboration |

---

### `stage`

**Definition:** A name used in professional performance contexts (acting, music, comedy, sport).

| Attribute | Specification |
|---|---|
| **Cardinality** | Multiple (person may have different stage names in different performance contexts) |
| **Temporal** | Yes |
| **Default sensitivity** | Low. Stage names are typically public by nature |
| **Permitted asserting roles** | Subject · steward · system (from public records) |
| **Default display contexts** | `public_ui`: permitted if subject consents · `family_ui`: permitted · `ordinary_search`: yes (public figures often known primarily by stage name) · `historical_record`: permitted · `default_export`: per subject preference |
| **Ordinary search** | Yes |
| **Restricted search** | Yes |
| **Export** | Yes |
| **Conflict resolution** | Subject assertion authoritative. Public documentation (credits, billing) corroborates |
| **Posthumous treatment** | Preserved. Publicly displayable per steward rules |
| **Minor / guardian treatment** | Guardian assertion for professional minors. Subject assertion from capacity |
| **Evidentiary expectations** | Subject assertion sufficient. Public record (credits, published billing) corroborates at `supported` confidence |

---

### `pen`

**Definition:** A name used for written works. Distinguished from stage name by its literary context and by the more common expectation of privacy separating the pen name from the legal identity.

| Attribute | Specification |
|---|---|
| **Cardinality** | Multiple |
| **Temporal** | Yes |
| **Default sensitivity** | Medium. Some authors maintain deliberate separation between pen name and legal identity |
| **Permitted asserting roles** | Subject · steward |
| **Default display contexts** | `historical_record`: permitted · `public_ui`: only if subject has publicly connected pen name to legal identity · `ordinary_search`: only if subject has publicly connected names · `family_ui`: per subject preference |
| **Ordinary search** | Only if subject has publicly connected names |
| **Restricted search** | Yes |
| **Export** | Per subject preference |
| **Conflict resolution** | Subject controls the connection between pen name and legal identity. Third-party assertion of this connection requires subject approval for living persons |
| **Posthumous treatment** | May be revealed posthumously per steward rules and any documented subject preference or instruction |
| **Minor / guardian treatment** | Standard minor rules |
| **Evidentiary expectations** | Published works corroborate pen name at `supported` confidence. Subject assertion sufficient to establish |

---

### `religious`

**Definition:** A name taken upon religious initiation, ordination, conversion, or vocation.

| Attribute | Specification |
|---|---|
| **Cardinality** | One per religious tradition or initiation event; may have multiple across different traditions |
| **Temporal** | Yes. `effective_from` = initiation date |
| **Default sensitivity** | Medium. Not all religious names are publicly disclosed |
| **Permitted asserting roles** | Subject · religious institution (as a corroborating source, not an independent asserter) · steward |
| **Default display contexts** | `family_ui`: permitted · `historical_record`: permitted · `public_ui`: only if subject consents · `ordinary_search`: denied · `identity_resolution_search`: permitted |
| **Ordinary search** | No |
| **Restricted search** | Yes |
| **Export** | Per subject preference |
| **Conflict resolution** | Subject controls whether and how religious name is displayed. Institutional records corroborate but do not override subject's display preference |
| **Posthumous treatment** | Preserved. Display per steward rules |
| **Minor / guardian treatment** | Guardian may document religious names given to minors. Subject may update display preference upon capacity |
| **Evidentiary expectations** | Religious record preferred as corroboration. Subject assertion sufficient to establish |

---

### `indigenous`

**Definition:** A name given through a cultural or community naming process within an Indigenous nation, community, or tradition.

| Attribute | Specification |
|---|---|
| **Cardinality** | Multiple. A person may have names from different nations, or multiple names within one tradition given at different life stages |
| **Temporal** | May be given at birth, at coming-of-age, or at other culturally defined life events. Temporal fields may be approximate or ceremonial rather than calendar-based |
| **Default sensitivity** | **CRITICAL HIGH.** Indigenous names often carry cultural protocols governing who may know, use, record, or share them. Some names may not be appropriate to record in writing at all. The system must not assume that recording is appropriate |
| **Permitted asserting roles** | Subject (sole authority to assert their own name) · designated community authority (only with explicit permission from subject and community) · steward (only with documented subject consent and explicit cultural guidance) |
| **Default display contexts** | **All contexts: denied by default.** Subject-specified only. No context is permitted without explicit subject authorization |
| **Ordinary search** | **No** |
| **Restricted search** | Only with explicit subject or steward authorization. Every access creates an audit log entry |
| **Export** | Excluded from all default and public exports. Included only with explicit multi-party authorization (subject/steward + documented cultural guidance) |
| **Conflict resolution** | Subject and relevant cultural authority govern. Family assertion is not sufficient without community authorization. External genealogical sources do not constitute authority over Indigenous naming |
| **Posthumous treatment** | **Does not automatically transfer to steward authority.** Steward must seek community consultation. Community protocols may prohibit continued recording or display after death. This requires a separate governance policy, not only schema fields |
| **Minor / guardian treatment** | Community and family joint authority. Subject assertion recognized from culturally-defined age of naming capacity, which is not a fixed calendar age |
| **Evidentiary expectations** | Documentary evidence is inappropriate for many cultural contexts. Oral assertion from subject or community authority is authoritative. The system must not require documentary evidence for Indigenous names. Automated extraction from colonial records must not be accepted without community review |
| **Policy note** | LifeBook must not attempt to systematize, index, or analyze Indigenous naming practices without explicit, ongoing community consent and governance involvement. This attribute type requires a separate governance policy. |

---

### `ceremonial`

**Definition:** A name used in specific ritual or ceremonial contexts, including but not limited to Indigenous ceremonies. Distinct from `indigenous` in that it may apply to various cultural or religious traditions, but shares high sensitivity.

| Attribute | Specification |
|---|---|
| **Cardinality** | Multiple |
| **Temporal** | May be event-bound or ongoing |
| **Default sensitivity** | **HIGH** |
| **Permitted asserting roles** | Subject · community/religious authority (with explicit permission) · steward (with documented consent) |
| **Default display contexts** | Subject-specified only. All contexts denied by default |
| **Ordinary search** | No |
| **Restricted search** | Steward-authorized with audit log |
| **Export** | Excluded from default export. Explicit authorization required |
| **Conflict resolution** | Subject and relevant cultural or religious authority |
| **Posthumous treatment** | Community/cultural consultation required before any access or display |
| **Minor / guardian treatment** | Community, family, and guardian joint authority |
| **Evidentiary expectations** | Community or cultural authority assertion is sufficient. Documentary evidence inappropriate in many contexts |

---

### `institutional`

**Definition:** A name assigned by an institution without the subject's consent or chosen identity. Includes names assigned in slavery, colonial contexts, residential schools, orphanages, and similar institutions.

| Attribute | Specification |
|---|---|
| **Cardinality** | Multiple |
| **Temporal** | Yes. Bounded by period of institutional record or control |
| **Default sensitivity** | **HIGH.** These names were imposed, not chosen. They are ethically and historically distinct from all other name types |
| **Permitted asserting roles** | System (from historical document extraction, pending human review) · steward · family (as historical record) · **Subject should not be required to claim or assert an imposed name.** Subject may annotate and control display |
| **Default display contexts** | `historical_record`: permitted (with mandatory imposition_context) · `identity_resolution_search`: permitted (steward-authorized, with audit log, with mandatory imposition_context in search result) · **All other contexts: denied** |
| **Ordinary search** | **No** |
| **Restricted search** | Yes, with mandatory imposition_context always returned with the result. The name must never appear in a search result without its historical context |
| **Export** | With mandatory `imposition_context` and `imposed_by` fields. Not in default export |
| **Conflict resolution** | Documentary source establishes that the record existed. Subject or steward controls association and display. **The presence of a name in an institutional record does not establish that the person accepted the name as their own identity.** The data model must distinguish "appeared in record as" from "identified as" |
| **Posthumous treatment** | Preserved with historical context. Steward governs display. Community consultation appropriate where records relate to colonial or institutional violence |
| **Minor / guardian treatment** | Guardian or steward documents with historical provenance. Subject may add imposition_context annotation and control display upon capacity |
| **Evidentiary expectations** | Institutional source establishes that the record existed. Source confidence applies to the record's existence only, not to identity. Separate confidence applies to the association between the record and the Person anchor |

---

### `pseudonym`

**Definition:** Residual category for assumed names not clearly covered by other usage types.

| Attribute | Specification |
|---|---|
| **Cardinality** | Multiple |
| **Temporal** | Yes |
| **Default sensitivity** | Medium. Apply restrictive defaults pending reclassification |
| **Permitted asserting roles** | Subject · steward |
| **Default display contexts** | `historical_record`: permitted · all others: subject-specified |
| **Ordinary search** | No |
| **Restricted search** | Yes |
| **Export** | Per subject preference |
| **Policy note** | This type should be deprecated as more specific usage types are defined. Records entered as `pseudonym` should be periodically reviewed for reclassification |

---

## PersonNameDerivative Catalogue

Derivative records inherit all sensitivity, display, search, and export policies from their parent PersonName record. They add:

| Field | Notes |
|---|---|
| `parent_name_id` | FK to PersonName |
| `derivative_type` | Enum: `transliteration` · `translation` |
| `target_script` | ISO 15924 (for transliterations) |
| `target_language` | BCP 47 (for translations) |
| `derivation_method` | Enum: `subject_provided` · `community_provided` · `automated` · `scholarly` |
| `derivation_tool` | Nullable (for automated: tool name and version) |
| `derivation_notes` | Transliteration standard used (e.g., ISO 9, BGN/PCGN, Pinyin) |
| `evidence_status` | Inherits parent `evidence_status` as floor; may be lower if `derivation_method = automated`. Automated derivations begin at `inferred` and may not be promoted to `supported` without human review — see GOVERNANCE_MODELS.md §1.1 |
| `precision_status` | Inherits parent `precision_status` as a floor; reflects accuracy of the transliteration or translation specifically — see GOVERNANCE_MODELS.md §1.2 |
| `dispute_status` | Inherits parent `dispute_status` as a floor; must be updated if the parent name's dispute_status changes — see GOVERNANCE_MODELS.md §1.3 |
| `review_status` | **Independent field — not inherited from parent.** A derivative name has its own review lifecycle: `pending` / `human_reviewed` / `policy_approved`. A derivative may remain `pending` after the parent name reaches `policy_approved` — for example, an automated transliteration of a newly approved preferred name requires independent human review before it may be used in display or export. The parent's `review_status = policy_approved` does not propagate to derivatives; each derivative record must reach `policy_approved` independently under the applicable ApprovalPolicy — see GOVERNANCE_MODELS.md §1.4 |

**Transliteration policy note:** A transliteration of an Indigenous or ceremonial name is as sensitive as the original. Automated transliterations must be flagged with `evidence_status = inferred` and tool metadata, and must not be promoted to `evidence_status = supported` without human review. The independent `review_status` on each derivative record is what enforces this — a derivative cannot be used until it has been independently reviewed, regardless of the parent name's status.

**Translation policy note:** Meaning-based name translations may be interpretive. Multiple valid translations may exist. Translation records must record the translator's role and methodology.

---

## PersonPronouns Catalogue

### Fields

| Field | Notes |
|---|---|
| `id` | UUID |
| `person_id` | FK to Person anchor |
| `pronoun_set_type` | Enum: `she_her` · `he_him` · `they_them` · `she_they` · `he_they` · `custom` · `unspecified` |
| `custom_subject` | Nullable (e.g., "ze") |
| `custom_object` | Nullable (e.g., "zir") |
| `custom_possessive_adj` | Nullable |
| `custom_possessive_pro` | Nullable |
| `custom_reflexive` | Nullable |
| `usage_note` | Nullable (e.g., "uses she/her in professional contexts, they/them in personal") |
| `effective_from` | Nullable |
| `effective_until` | Nullable |
| `asserted_by_role` | Subject is the only authoritative role for living persons |
| `approval_policy_id` | FK to ApprovalPolicy |
| `conflict_resolution_policy_id` | FK to ConflictResolutionPolicy |

| Attribute | Specification |
|---|---|
| **Cardinality** | One active pronoun set; may vary by context (usage_note); multiple temporal records |
| **Temporal** | Yes |
| **Default sensitivity** | Context-dependent. **HIGH** for persons who have not publicly disclosed. Low for public figures who have disclosed. Default to HIGH |
| **Permitted asserting roles** | **Subject is sole authoritative asserting role for living persons with capacity.** Steward may assert post-death based on documented subject preference. Family assertion **does not constitute evidence** |
| **Default display contexts** | `public_ui`: denied unless subject explicitly consents · `family_ui`: denied unless subject consents · `steward_ui`: permitted · `ai_generation`: **always used** when generating content regardless of other display contexts |
| **Ordinary search** | No |
| **Restricted search** | No |
| **Export** | Per subject preference only. Excluded from all default exports |
| **Conflict resolution** | Subject is sole authority. No conflict resolution process for living persons with capacity. Family assertion is not considered in conflict resolution |
| **Posthumous treatment** | Subject's last documented preference governs. Steward may not modify. Family assertion does not override subject's documented preference |
| **Minor / guardian treatment** | Subject assertion recognized from age of self-identification (not a fixed age). Subject's assertion takes precedence over guardian's assertion from point of subject's assertion. Guardian assertion is **not** authoritative over subject's self-identification |
| **Evidentiary expectations** | Subject assertion is the sole authoritative source. No documentary evidence is required or appropriate. Medical or psychological documentation is supporting context for the subject's own use, not evidence for the LifeBook record. Clinical records must not be used to contradict or qualify subject's assertion |
| **AI generation rule** | When generating any narrative, summary, or other content referencing this person, the AI must use the most recently active pronoun set regardless of the narrative's context or period. The AI must not silently use a former pronoun set because the narrative describes a past period |

---

## PersonGenderDescriptor Catalogue

### Fields

| Field | Notes |
|---|---|
| `id` | UUID |
| `person_id` | FK to Person anchor |
| `descriptor` | Free text, from a suggested vocabulary but not constrained to it |
| `display_label` | How the descriptor should be rendered in UI (may differ from raw descriptor value) |
| `effective_from` | Nullable |
| `effective_until` | Nullable |
| `asserted_by_role` | Subject only for living persons with capacity |
| `approval_policy_id` | FK to ApprovalPolicy |
| `conflict_resolution_policy_id` | FK to ConflictResolutionPolicy |

| Attribute | Specification |
|---|---|
| **Cardinality** | One or more active descriptors; some people have multiple valid descriptors simultaneously |
| **Temporal** | Yes |
| **Default sensitivity** | **HIGH** for living persons who have not publicly disclosed. Lower for public figures who have disclosed. Default to HIGH |
| **Permitted asserting roles** | **Subject only** for living persons with capacity. Steward based on documented subject preference post-death |
| **Default display contexts** | Subject-specified only. **All contexts denied by default** |
| **Ordinary search** | No |
| **Restricted search** | No |
| **Export** | Per subject preference only. Excluded from all default exports |
| **Conflict resolution** | Subject is sole authority. No conflict resolution process exists for living persons with capacity |
| **Posthumous treatment** | Subject's documented preference governs. Steward may not modify. Family assertion does not override |
| **Minor / guardian treatment** | Subject assertion recognized from age of self-identification. Subject's assertion takes precedence over guardian assertion from point of subject's assertion |
| **Evidentiary expectations** | Subject assertion is sole authoritative source. Medical, clinical, or administrative classification records must not be used to contradict or qualify subject's assertion |

---

## Open Questions for Resolution Before Schema

1. **Capacity:** Who determines when a subject lacks capacity? What is the governance process? What documentation is required? This has direct consequences for the `asserted_by_role` validation logic.

2. **Guardian multiplicity:** How are conflicts between multiple guardians resolved? Is a quorum required? Is there a priority order?

3. **Jurisdiction table:** Which jurisdictions require explicit legal-basis fields? Where does PIPEDA's right-to-erasure intersect with historical record preservation for former_name and institutional_name?

4. **Indigenous governance policy:** Must be developed in consultation with Indigenous communities before any Indigenous name attribute types are deployed. This is a pre-deployment blocker, not a post-launch concern.

5. **AI generation rule for historical narratives:** When a narrative was composed at a time when different pronouns were appropriate, should the AI regenerate it using current pronouns? Current recommendation is no — the original narrative is preserved as composed; any AI-generated content uses current pronouns. This rule needs explicit documentation and a content policy.

6. **Confidence transitions:** ~~What triggers a claim moving from `asserted` to `supported` to `corroborated`? Who authorizes the transition? Is it automated, human-reviewed, or both?~~ **Resolved 2026-07-25** — GOVERNANCE_MODELS.md §1.1 defines the AI boundary (AI may set evidence_status up to `inferred`; elevation to `supported` or `corroborated` requires human action under the applicable ApprovalPolicy). GOVERNANCE_MODELS.md §1.4 defines review_status transition requirement: `policy_approved` status required before a record may be used as the basis for a consequential action. Transition authorization mechanism is an application-layer implementation detail, not a schema blocker.

---

*Next step: Define the ApprovalPolicy and ConflictResolutionPolicy tables, then the Person anchor with operational lifecycle fields, then write the Supabase migration.*
