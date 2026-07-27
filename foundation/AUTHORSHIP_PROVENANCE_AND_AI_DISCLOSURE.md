# AUTHORSHIP_PROVENANCE_AND_AI_DISCLOSURE.md
## LifeBook HQ — Policy: Authorship, Provenance, and AI Disclosure
**Status:** Policy — approved as governing document  
**Date:** 2026-07-27  
**Authority:** Discovery Partner  
**Classification:** Architecture governance — does not modify or extend the current implementation roadmap

---

> **A life is never generated. LifeBook may help a person remember, research, organize, translate, interpret, and express a life — but every preserved assertion must retain its human or documentary origin, its AI involvement, and its path to approval.**

> **AI may organize the record. AI may never silently change the record.**

These are not product goals. They are enforceable product constraints that govern every architectural decision involving AI involvement in LifeBook's governed content.

---

## 1. Policy Scope

This policy applies to all LifeBook objects in which content is authored, derived, transformed, or reviewed. It governs both the **origin** of information and the **transformations** applied to it before it enters or modifies the authoritative record.

Objects in scope include:

- Claims (assertions about a person's life)
- Events (structured life events)
- Narratives (composed textual accounts)
- Artifacts (uploaded documents, photographs, audio, video, and other media)
- Conversation turns and thread summaries (as sources for extraction, not as permanent records)
- Transcripts (of audio, video, or recorded testimony)
- Translations (of text or speech in a non-primary language)
- Summaries (AI-generated or steward-composed digests)
- Generated media (portrait images, synthetic voice, reconstructed scenes)
- Corrections and amendments (changes to previously governed records)
- Contributor submissions (material submitted by non-steward participants)
- Exports (structured or narrative exports of lifebook content)

This policy is not limited to AI-generated content. It applies to human-authored content as well, because provenance is a property of all governed records, not only those produced with AI assistance.

---

## 2. Authorship Taxonomy

LifeBook distinguishes five categories of authorship. These categories are not a spectrum — they are discrete, and a record's authorship category does not change based on who later approves or reviews it.

### 2.1 Human-Authored

Content intentionally composed or stated by a person, in their own words, with deliberate expressive intent.

Examples:
- Spoken testimony captured in a conversation session
- A narrative composed by the steward in the LifeBook interface
- A handwritten letter uploaded as an artifact with content extracted by the steward
- A correction explicitly authored by the steward
- A contributor submission describing their own memory

**Designation:** `submission_origin = 'steward_direct'` or `submission_origin = 'family_contribution'`

A record is human-authored only if a human independently composed or stated its content. Approval, editing, or promotion of AI-generated content does not make that content human-authored.

### 2.2 Documentary-Derived

Information extracted from an existing artifact or external record, where the artifact or record itself is the authoritative source and the human's role is curatorial rather than expressive.

Examples:
- A birth date extracted from a birth certificate
- An address transcribed from a ship manifest
- A death record extracted from a church register
- Metadata interpreted from a photograph
- A family relationship inferred from a census record by the steward (not by AI)

**Designation:** The claim carries a source reference (`source_id`, `source_claim_id`) linking to the documentary artifact.

Documentary-derived material carries the epistemic weight of its source document. The source document may itself be erroneous, incomplete, or contested — which is why provenance and epistemic status are separate concerns (see Section 4).

### 2.3 AI-Assisted

AI changes the presentation of existing human or documentary material without independently introducing a new factual assertion. The factual content originates entirely from the human or source document; the AI's role is transformation only.

Examples:
- Transcription of a spoken conversation turn
- Spelling correction of a steward-written narrative
- Translation of a claim from Ukrainian to English
- Audio noise reduction on a recorded interview
- Structural editing of a narrative draft
- Summarization of a conversation thread
- Reformatting or reorganization without content change

**Designation:** `submission_origin = 'ai_assisted'`, `ai_generated = FALSE`

AI-assisted content requires steward review (`review_status = 'pending'`) before promotion to the authoritative record unless the transformation is trivially invertible and carries no factual interpretation risk. The distinction between "transformation" and "interpretation" is where human judgment is required — this cannot be automated.

### 2.4 AI-Inferred

AI proposes a factual or structural interpretation that is not explicitly stated in the source material. The AI is introducing a new assertion based on reasoning over existing content.

Examples:
- Inferring that a conversation described a birth event and creating a structured event record
- Suggesting that two persons mentioned across different threads may be the same entity
- Estimating a probable date range from contextual references
- Identifying a likely family relationship not directly stated
- Proposing that a photograph depicts a specific person based on appearance

**Designation:** `submission_origin = 'ai_assisted'`, `ai_generated = TRUE`, `review_status = 'pending'`

AI-inferred records are the highest-risk category from an accuracy standpoint. They must never enter the authoritative record without explicit steward review and promotion. The inference itself — the reasoning or evidence chain — should be preserved as context for the steward's decision.

### 2.5 AI-Generated

AI creates expressive, representational, or compositional material that goes beyond direct transformation of an existing source. The AI is the originating author of the form, not merely a processing intermediary.

Examples:
- A narrative paragraph drafted from a set of approved claims
- A reconstructed scene description based on an approved event record
- A synthetic voice rendering of a steward-approved narrative
- A generated portrait from a physical description
- A colourised or restored photograph
- A speculative historical visualisation

**Designation:** `submission_origin = 'ai_assisted'`, `ai_generated = TRUE`, `producing_agent_code` recorded

AI-generated content occupies a distinct category with additional obligations beyond review. It requires permanent labelling, is never presented as authentic historical evidence, and is governed under the additional requirements in Section 7.

### 2.6 Human-Approved

A human has explicitly reviewed a record and confirmed it for a specific governed purpose.

**Critical distinction:** Human-approved is a governance action, not an authorship category. Human approval does not convert AI-generated or AI-inferred material into human-authored material. The authorship category is determined at the point of origin and does not change. A steward who approves an AI-drafted narrative has made a governance decision — they have not become the author of that narrative.

**Designation:** `review_status = 'steward_reviewed'` or `review_status = 'policy_approved'`

These two concepts must never be conflated in user interface language, export formats, or analytical functions. Approved provenance chains must carry both the authorship origin and the approval history separately.

---

## 3. Provenance Dimensions

LifeBook should eventually retain the following provenance information for every governed record. Not all dimensions are currently implemented. The implemented subset is identified below. Gaps are deferred to the future milestone described in Section 9.

### 3.1 Provenance of Origin

The circumstances under which the raw information first entered LifeBook's possession.

| Dimension | Description | Current Support |
|---|---|---|
| Originating person or source | Who stated it or which document it came from | `source_id`, `source_claim_id` on claims; `created_by_id` on events and threads |
| Submitting person | The user who initiated entry into the system | `created_by_id` on most governed tables |
| Capture method | How the information was received (spoken, typed, uploaded, imported) | Not yet implemented |
| Date and time of capture | When it entered the system | `created_at` on all governed tables |
| Source artifact or external record | The physical or digital document it was derived from | `artifacts` table; linked via `source_id`, `source_claim_id` |
| Confidence or evidentiary status | How certain the origin assertion is | Not yet implemented as a structured field |

### 3.2 Provenance of Transformation

The operations applied to the content between its origin and its current form.

| Dimension | Description | Current Support |
|---|---|---|
| Submission origin | Structural category of how the record was created | `submission_origin` on claims, events, artifacts |
| AI involvement flag | Whether an AI system contributed to producing this record | `ai_generated` on claims, events, artifacts |
| Producing agent | The specific AI component or service that generated the content | `producing_agent_code` on claims, events, artifacts |
| Context manifest | The session context in which the AI operation occurred | `context_manifest_id` on claims, events, artifacts, threads |
| AI operation performed | The specific transformation type (transcription, translation, summarization, inference) | Not yet implemented as a structured field |
| Model or service used | The LLM or AI service identity and version | Not yet implemented |
| Output version | Which iteration of a generated output this record represents | Not yet implemented |
| Correction history | A record of amendments to this content | `claim_supersession_integrity` trigger; `superseded_by_id` lineage on claims |

### 3.3 Provenance of Approval

The governance decisions that determined this record's authority status.

| Dimension | Description | Current Support |
|---|---|---|
| Review status | Current approval stage | `review_status` on claims, events |
| Human reviewer | Who approved or rejected the record | Not yet implemented as a structured field |
| Approval decision | What was decided, and on what date | `review_status` values; timestamp not yet structured |
| Dispute status | Whether the record is currently contested | `contest_records` table; `validity_state` on artifacts |
| Relationship to prior versions | What this record supersedes | `superseded_by_id` lineage on claims |

---

## 4. Truth, Authenticity, and Provenance

Provenance is evidence of origin and handling. It is not proof that the underlying statement is factually true.

LifeBook operates in a domain where this distinction is not theoretical — it is a daily reality.

- A genuine memory may be mistaken. A person can sincerely recall an event that did not happen as they remember it.
- An authentic document may contain an error. Birth records in the nineteenth century regularly contain misspellings, wrong ages, and misattributed parentage.
- Two sincere witnesses to the same event may disagree. Both may be honest. Neither may be fully correct.
- An AI transcription may faithfully preserve an incorrect statement. The transcription is accurate; the statement is not.
- A steward-approved narrative may still contain uncertainty. Approval is a governance decision, not a factual verification.

LifeBook must therefore retain and separately expose two properties for every governed record:

**Chain of custody** — origin, transformation, and approval history. This answers: *Where did this come from, and who handled it?*

**Epistemic status** — confidence, corroboration, dispute, and uncertainty. This answers: *How certain is this, and is it contested?*

These are independent. A record can have clear provenance and low confidence (a truthfully remembered uncertain event). A record can have disputed provenance and high apparent confidence (a contested document in a probate dispute). Neither property substitutes for the other.

---

## 5. Disclosure Rules

When AI involvement must be visible depends on what the AI did and what consequence that action has for the record's authority.

### 5.1 Disclosure Tiers

**Tier 1 — Detailed provenance only**

AI involvement is recorded in the provenance record and is accessible to the steward on request but does not require a persistent visible label in standard views.

Applies to:
- Minor spelling and grammar correction where no factual content was altered
- Structural reformatting with no content change
- Automated language detection

**Tier 2 — Visible label in the user interface**

AI involvement is displayed alongside the record in all standard views without requiring the user to request it.

Applies to:
- Transcription of spoken content
- Translation between languages
- Summarization of a conversation thread
- Audio or image enhancement that does not alter content

**Tier 3 — Explicit consent before use**

The steward must confirm before the output enters any governed record, even transiently.

Applies to:
- Inferring a new claim from conversation content
- Inferring a new event from conversation content
- Suggesting an entity match across threads
- Narrative draft generation
- Image reconstruction or colourisation
- Automated research suggestions that propose new claims

**Tier 4 — Steward approval required; cannot enter the authoritative record otherwise**

The AI output may be staged as a pending record but may not be promoted to the authoritative record by any means other than explicit steward review and confirmation.

Applies to:
- All AI-inferred claims and events (`review_status = 'pending'` enforced by schema)
- All AI-generated narrative prose
- All synthetic or reconstructed media
- Any record produced by an AI agent acting without direct human instruction in the current session

### 5.2 What "Labelling" Means

A label on an AI-involved record must distinguish between the authorship category (what the AI did) and the approval status (whether a human has reviewed it). A single label such as "AI-generated" is insufficient. The policy requires that disclosure reflect at minimum:

- What kind of AI involvement occurred (transcription, inference, generation, etc.)
- Whether the record has been reviewed by a human steward
- What the source of the underlying information was

This is a disclosure architecture, not a badge. It must be legible to the steward and eventually to any person whose story is being told.

---

## 6. Human Authority and Approval

The following principles govern the relationship between human actions and the authority of governed records.

**Human initiation is not equivalent to human authorship.** A steward who opens a conversation session and asks the AI a question has not authored any records that the AI subsequently generates or infers. The session context is human-initiated; the records produced from AI inference within that session remain AI-inferred.

**Human approval is not equivalent to human origin.** A steward who approves an AI-drafted narrative has accepted it for governance purposes. The narrative remains AI-generated in its authorship category. The approval is recorded separately as a governance action.

**Steward approval is a governance action with specific scope.** Approving a claim does not approve all claims. Approving a narrative does not validate the underlying claims. Approving an artifact does not validate the claims derived from it. Each governed object carries its own approval status.

**Contributor submission does not automatically create authority.** Material submitted by a contributor enters the system with `submission_origin = 'family_contribution'` and `review_status = 'pending'`. The steward governs what is promoted. A contributor who submits material is not asserting authoritative fact — they are offering testimony.

**AI may suggest, but may not silently act.** AI systems operating within LifeBook may recommend, propose, draft, and offer. They may never silently promote a pending record to authoritative status, merge entities without steward confirmation, overwrite an existing governed record, delete or archive content, or reinterpret a previously approved record. Every action that changes the authoritative record requires a human trigger.

This section ties directly to the steward and contributor model established in Principle V (LIFEBOOK_PRINCIPLES.md). The AI's role in the governance chain is advisory. The steward's role is determinative.

---

## 7. Synthetic and Reconstructed Media

Synthetic and reconstructed media — including generated portraits, reconstructed photographs, colourised images, synthetic voice, and recreated scenes — require additional governance beyond the standard AI-inferred and AI-generated categories.

### 7.1 Permanent Labelling

Any synthetic or reconstructed media artifact carries a permanent label identifying it as such. This label cannot be removed by steward action, contributor action, or export. It persists in all views, all exports, and all downstream uses.

### 7.2 Source Preservation

The original source material — the photograph before reconstruction, the text before voice synthesis, the claim set before portrait generation — is preserved as a separate artifact in the system. Synthetic output does not replace its source.

### 7.3 Separation from Documentary Artifacts

Synthetic and reconstructed media are stored and classified separately from documentary artifacts. A generated portrait is never filed alongside or treated as equivalent to a historical photograph. A synthetic voice rendering is never treated as an authentic audio recording. The schema classification (`artifact_type`, `validity_state`) must enforce this separation.

### 7.4 Explicit Approval

No synthetic or reconstructed media enters any governed record without explicit steward approval. An AI system may generate a draft synthetic artifact; it may never promote it.

### 7.5 Not Historical Evidence

Synthetic and reconstructed media may never be described, presented, or exported as authentic historical evidence. In any context where the artifact could be encountered without the full provenance record — a family sharing platform, an export, a printed book — the synthetic nature must be visible.

### 7.6 Posthumous and Cultural Consent

Generating synthetic representations of deceased persons, or persons from communities with specific cultural governance over how their images and voices are used, raises concerns that exceed the technical scope of the current architecture. The following minimum constraints apply:

- Steward acknowledgement is required before generating any synthetic representation of a deceased person
- Cultural governance flags (`is_culturally_governed`) apply to synthetic media as fully as they apply to other artifacts
- LifeBook makes no determination about whether a steward has appropriate cultural or familial authority to commission a synthetic representation — this judgment belongs to the steward and must be made with the understanding that it cannot be undone by deleting the generated artifact

The full design of consent frameworks for synthetic media is deferred to the future milestone described in Section 9.

---

## 8. Cultural and Community Authority

Some material in LifeBook belongs not only to the individual whose story is being told but to a community or cultural tradition with its own governance over how that material may be held, shared, transformed, or represented.

Technical possession of a document, a photograph, or a recorded account does not establish cultural authority over it. A family that holds a photograph of a ceremonial event does not automatically have the right to publish it, reproduce it, share it with an AI system, or generate synthetic representations from it.

LifeBook's current architecture provides structural support for cultural governance through:
- `access_classification = 'culturally_governed'` on claims and narratives
- The `cultural_authority` role in the authority assignment model
- RLS policies that prevent AI agent access to culturally governed content

This architectural support is load-bearing, not decorative (Principle VI). However, the policy layer for cultural and community authority is not yet fully articulated in LifeBook's documentation. The following preliminary constraints apply:

**AI systems must not access, process, or transform culturally governed material.** This is currently enforced by RLS and must remain enforced as new AI capabilities are added. Any new capability that involves AI processing of governed artifacts must be reviewed against cultural governance boundaries before implementation.

**Community authority structures are not reducible to individual steward authority.** Where a lifebook intersects with material that has collective cultural significance, the steward's individual approval is a necessary but potentially insufficient condition. LifeBook's architecture should eventually support community-level governance for such material.

**Cultural sensitivity applies to synthetic media, AI inference, and AI-assisted transformation equally.** The cultural governance framework does not apply only to content access. It applies to any operation that touches governed content, including transcription, translation, summarization, entity matching, and narrative generation.

The design of community governance structures is deferred. The constraints above are immediate and apply under the current architecture.

---

## 9. Proposed Future Implementation Milestone

### Authorship, Provenance, and AI Disclosure Layer

This milestone addresses the gap between LifeBook's current partial provenance support and the full provenance model described in this policy.

**Why this is not part of M0004:** M0004 addresses conversation threading, thread obligations, and the event review workflow. Provenance enrichment is architecturally adjacent but would substantially expand the scope and surface area of the migration. More importantly, the provenance layer depends on operational experience with the conversation layer — understanding which transformations actually occur in practice before designing structured provenance fields for them.

**What the milestone would likely address:**

- Structured provenance event records (logging each transformation applied to a governed record)
- Transformation type fields on AI-assisted and AI-generated records (transcription, translation, summarization, inference, generation)
- Model or service identity logging (`producing_agent_code` is the current partial implementation)
- Human reviewer identity on approval records (currently only captured as a status, not a person reference)
- Approval timestamps (currently structural, not timestamped independently)
- Source-to-output lineage (explicit chains linking a documentary source to the claims and events derived from it)
- Synthetic media labels (immutable attribute on artifact records)
- User-facing provenance summary (a read model for presenting provenance to stewards and potentially to subjects)
- Confidence and corroboration fields on claims and events (partial support exists; not yet structured for provenance purposes)

**Dependencies on current architecture:**

The Authorship, Provenance, and AI Disclosure Layer depends on the completion of:
- M0004 (conversation threading and the full event review workflow) — establishes the session context model
- The Conversation Experience API — establishes the producing agent code and context manifest chain in practice
- Operational data from Founding Member use — identifies which provenance dimensions are actually needed vs. theoretical

**What triggers milestone planning:**

When the Conversation Experience v1 is in production with Founding Members and the producing agent code and context manifest chain are generating real data, the provenance layer can be designed against actual operational patterns rather than theoretical ones.

---

## 10. Relationship to Current Architecture

### 10.1 What Already Supports This Policy

The following current architectural elements directly support the policy goals:

| Element | How it supports this policy |
|---|---|
| `submission_origin` on claims, events, artifacts | Implements the authorship taxonomy at the record level |
| `ai_generated` boolean on claims, events, artifacts | Distinguishes AI-assisted transformation from AI-generative creation |
| `producing_agent_code` on claims, events, artifacts | Begins the model identity tracking required by the disclosure framework |
| `context_manifest_id` on claims, events, artifacts, threads | Anchors records to the session context in which they were produced |
| `review_status` on claims and events | Implements the human approval governance structure |
| `trg_event_review_status_auto_promote` | Enforces that only `steward_direct` events auto-promote; AI-inferred events remain pending |
| `validity_state` on artifacts | Provides the epistemic status dimension for artifact records |
| `contest_records` table | Implements the dispute layer required by Section 4 |
| `claim_supersession_integrity` trigger and `superseded_by_id` lineage | Supports correction history and the permanent record requirement |
| `access_classification` including `culturally_governed` | Enforces cultural governance boundaries |
| `is_culturally_governed` flag and `cultural_authority` role | Provides structural support for Section 8 |
| RLS policy blocking AI access to culturally governed content | Mechanically enforces the cultural boundary |
| Delete-denied RLS policies (Principle VIII) | Ensures provenance chains cannot be destroyed |

### 10.2 What Partially Supports This Policy

| Element | Gap |
|---|---|
| `submission_origin` values | The value `'external_import'` on artifacts is present but not yet defined in operational terms within this policy. Its disclosure requirements should be determined when import flows are designed. |
| `context_manifest_id` chain | The context manifest structure exists but the content model for what a manifest records about an AI operation is not yet fully defined. |
| `review_status` on claims and events | Captures the approval state but not the reviewer identity or approval timestamp. Section 3.3 identifies this as a gap. |
| `producing_agent_code` | Records which agent produced a record but not which model or service version was used. |
| `validity_state` on artifacts | Provides epistemic status for artifacts but no equivalent exists on narratives. |

### 10.3 What Is Currently Absent

The following are not present in the current architecture and are deferred to the future milestone:

- Structured transformation type field (what specific AI operation was performed)
- Model and service version logging
- Separate reviewer identity field on governed records
- Structured confidence and corroboration fields on claims and events
- Synthetic media labelling attribute on artifacts
- Source-to-output provenance chain (explicit ancestry across derived records)
- User-facing provenance summary read model

### 10.4 Terminology Conflicts

One potential conflation was identified during review:

**`submission_origin` is not authorship.** The field name implies a submission pathway, and its values (`steward_direct`, `ai_assisted`, `family_contribution`, `external_import`) do describe pathways. However, `steward_direct` is currently used to mean both "submitted by the steward directly" and implicitly "authored by the steward." These are not the same thing. A steward could, in principle, mark as `steward_direct` a claim that they are copying from a document without citation. This policy recommends that documentation describing `submission_origin` always use the phrase "submission pathway" rather than "authorship" to prevent conflation, and that any future UI presenting `steward_direct` records be careful not to represent them as human-authored without additional context.

No modification to the current schema is required for this. It is a documentation and UI language concern.

**Recommended future amendment:** When the Authorship, Provenance, and AI Disclosure Layer is formally scoped, consider whether a separate structured `authorship_type` field would be more precise than relying on `submission_origin` for authorship attribution, or whether explicit documentation of the mapping is sufficient.

---

*AUTHORSHIP_PROVENANCE_AND_AI_DISCLOSURE.md — LifeBook HQ — 2026-07-27*
