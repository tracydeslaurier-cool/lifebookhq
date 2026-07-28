# PHASE_1_ARCHITECTURAL_FINDINGS.md
## LifeBook HQ — Phase 1 Experience Validation
**Status:** Phase 1 — pre-validation framework (no sessions completed yet)  
**Milestone:** Conversation Experience v1  
**Date:** 2026-07-27  
**Updated by:** Tracy (session findings) + Claude (architectural analysis)  
**Companion documents:** HUMAN_VALIDATION_PROTOCOL_V1.md, CONVERSATION_PROTOTYPE_V1.md, UPLOAD_EXPERIENCE_DESIGN.md

---

## Purpose

This document captures architectural findings that emerge from Phase 1 experience validation. It is a living document — updated after each validation session as findings are analyzed against the existing architecture.

A finding is architectural if it reveals a gap, constraint, or confirmation in how the system should be built — not just how it should feel. The feel is addressed in LIFEBOOK_VOICE_AND_CONVERSATION_GUIDE.md. The build is addressed here.

---

## Vocabulary-to-Architecture Review

*Requested by DP, 2026-07-27. Objective: evaluate whether role concepts represent permanent roles, contextual relationships, permissions, or provenance attributes — before any schema changes are considered. Do not recommend migration. Prevent terminology from prematurely constraining architecture.*

---

### The Governing Question

The DP's distinction is precise: **"Who is a person in relation to the LifeBook?"** is not the same question as **"What action did a person perform?"**

These must remain separate concepts in the architecture. When they are conflated — in vocabulary, in schema fields, or in application logic — the system loses the ability to answer either question accurately. Role becomes confused with action. Action becomes confused with state. State becomes confused with identity.

The six concepts under review fall into four categories. The goal of this analysis is to assign each concept cleanly, identify where conflation currently exists, and name the questions that follow — without pre-answering them with migrations.

---

### Category Definitions

**Permanent role:** A fixed designation that does not change based on what a person does in a session. Example: being married to the LifeBook subject is a permanent biographical fact.

**Contextual relationship:** A relationship that exists within a defined context (a specific LifeBook, a specific session, a specific event) and may differ across contexts. A person may be a StoryTeller in one LifeBook and a Contributor in another.

**Permission set:** A collection of authorized actions within the system. Permissions may derive from roles or relationships but are not the same as either.

**Provenance attribute:** A property of a piece of content that records its origin, how it was created, or by whom. Provenance attributes belong to content, not to people.

---

### Analysis: The Six Concepts

---

#### Steward

**What the current schema says:**
`lifebook_memberships.membership_role = 'steward'` — a permission-bearing designation attached to a specific lifebook membership record.

**What it actually is:**
Primarily a **contextual relationship** with a **permission set** attached. "Steward" describes a person's relationship to a specific LifeBook object — not a permanent attribute of the person. One person may be a Steward of some LifeBooks and not others. Stewardship is transferable. It is specific to a LifeBook, not to the person's identity.

The permission set that derives from Stewardship (review, access control, invitation, custody) is real and correctly modelled. But the permission set does not define what Steward *is* — it describes what a Steward *can do*.

**Conflation risk:**
None currently — the schema correctly scopes Steward to the membership record. The risk arises if "Steward" begins to absorb meaning-layer responsibilities (who can interpret artifacts, who controls meaning) that belong to the StoryTeller relationship. These are different and must not merge.

**Clean definition:** Steward = a contextual relationship granting custody and governance authority over a specific LifeBook. It is the answer to "Who holds this LifeBook?" not "Who carries meaning about this life?"

---

#### StoryTeller

**What the current schema says:**
`lifebook_entities.participation_role` includes `'storyteller'` as a valid value — alongside `'subject'`, `'family_member'`, `'witness'`, `'contributor'`, `'steward'`, and others.

**This is the most important finding of this analysis.** The StoryTeller concept already exists in the schema — but it lives in `participation_role` on `lifebook_entities`, which records a person's relationship to the *subject* of a LifeBook entry (an event, a period, an experience). It does not yet appear in `lifebook_memberships.membership_role` or in any conversation/experience layer construct.

**What it actually is:**
A **contextual relationship to the subject** — not to the LifeBook as an object. A StoryTeller carries meaning because of their relationship to the *person being remembered*, not because of their membership in the system. This is the schema's own implicit recognition: `participation_role` tracks what a person's relationship to the subject was, not what their permission level is.

This distinction is architecturally significant:
- `lifebook_memberships.membership_role` answers: "What can this person do in the system?"
- `lifebook_entities.participation_role` answers: "What was this person's relationship to the subject of this event or record?"

These are different axes. StoryTeller belongs on the second axis, not the first.

**Conflation risk:**
The current vocabulary discussion has sometimes treated StoryTeller as an alternative `membership_role` value alongside Steward and Contributor. This would be wrong. If StoryTeller is added to `membership_role`, it becomes a permission level — and StoryTellers don't have distinct permissions from Contributors. What is distinct is their *epistemic relationship* to the subject, which is already captured by `participation_role`.

The question that follows is not "should StoryTeller be a membership role?" It is: "How does the experience layer surface the StoryTeller's `participation_role` relationship when it designs conversations and artifact interactions?" That is an application layer and conversation design question, not a schema question.

**Clean definition:** StoryTeller = a contextual relationship to the *subject* of a LifeBook, expressing that a person carries lived knowledge about that life. Already present in `lifebook_entities.participation_role`. Not a permission. Not a provenance attribute. Not a permanent role.

---

#### Contributor

**What the current schema says:**
`lifebook_memberships.membership_role = 'contributor'` — a permission level below Steward, allowing addition of content subject to Steward review.

**What it actually is:**
Currently doing double duty as both a **permission set** (less authority than Steward) and a **relationship descriptor** (someone who adds material). These are not the same thing.

The permission model is clean: Contributors can add content, which enters the review queue. That is correctly modelled.

The relationship model is incomplete: `participation_role = 'contributor'` on `lifebook_entities` also exists, meaning a person can be tagged as a Contributor to a specific event or record. But the meaning is different from the membership-level `contributor` — one describes what a person can do in the system; the other describes what their relationship to the subject was.

**Conflation currently present:**
A professional archivist uploading records and a family friend sharing personal memories are both `membership_role = 'contributor'` in the current schema. They have the same permissions. But their relationship to the subject — and therefore their epistemic standing in relation to what they're contributing — is completely different. The archivist is a Contributor in both senses. The family friend is a StoryTeller with Contributor-level permissions.

The schema conflates these because it doesn't yet have a way to record "this contributor is contributing from personal memory" vs "this contributor is contributing from documentary research."

**Clean definition:** Contributor (as permission) = a contextual relationship granting the ability to add content, subject to review. Contributor (as relationship) = a person whose connection to the subject is documentary or supporting rather than experiential. The schema currently uses one label for both. Separating them requires either a new field or a richer interpretation of `participation_role` in the application layer.

---

#### submission_origin

**What the current schema says:**
Two systems exist simultaneously:

1. M0001's `submission_origins` vocabulary table with codes: `subject_submission`, `authorized_representative_submission`, `steward_submission`, `executor_submission`, `family_submission`, `contributor_submission`, `institutional_submission`, `ai_extracted_submission`, `system_inferred_submission`.

2. M0004's inline `CHECK` constraint on `events.submission_origin`: `('steward_direct', 'ai_assisted', 'family_contribution')`.

**What it actually is:**
`submission_origin` is intended to be a **provenance attribute on content** — it records how a piece of content entered the system. But the current values mix three different things:

- **Process type** (how it entered): `ai_extracted_submission`, `system_inferred_submission`, `ai_assisted`
- **Actor's governance role** (who the actor was in the system): `steward_submission`, `steward_direct`, `contributor_submission`
- **Actor's social/familial relationship** (what the actor's relationship to the subject is): `family_submission`, `family_contribution`

These are three different questions encoded in one field. The result: `submission_origin` cannot cleanly answer "how did this enter the system?" without also implying "who is this person to the subject?" — which is not provenance, it's identity.

**The conflation stated plainly:**
`steward_submission` means "a person holding the Steward role submitted this." `family_submission` means "someone related to the subject submitted this." But a Steward could also be a family member. A family member could be a Contributor. The field forces a single label onto something that is actually two attributes.

A cleaner model would separate:
- **Process origin**: how content entered (direct human input, AI extraction, system inference, invited contribution)
- **Actor relationship**: what the submitting person's relationship to the LifeBook and subject was (derivable from their `membership_role` + `participation_role` at submission time)

**This analysis does not recommend changing the field.** The finding is that `submission_origin` currently conflates provenance with identity, and that conflation will create ambiguity as StoryTeller/Contributor distinctions become more precise. The resolution approach is a post-validation decision.

**Clean definition:** submission_origin *should* be a pure provenance attribute describing process type. Currently it also encodes actor role and actor relationship. These are separate concepts that the current field does not fully separate.

---

#### validity_state

**What the current schema says:**
Two types: `claim_text_validity_state` (`valid`, `policy_superseded`, `invalidated`) and `artifact_validity_state` (`valid`, `policy_superseded`, `under_review`, `invalidated`, `expired`).

**What it actually is:**
A **content epistemic state** — a property of the content itself, not of the person who created it. `validity_state` answers: "Does the system currently consider this content to be an accurate, active record?" This has nothing to do with who submitted it.

**Conflation risk:** None currently. `validity_state` is cleanly scoped to content state. It does not encode identity or role. The risk arises only if application logic begins to infer `validity_state` from the submitter's role (e.g., "Steward submissions are automatically valid") — which would conflate the submitter's identity with the content's epistemic state.

**Clean definition:** validity_state = an epistemic state attribute on content. Records whether the content is currently considered accurate and active. Independent of who created it.

---

#### review_status

**What the current schema says:**
`review_status` ENUM: `pending`, `human_reviewed`, `policy_approved`. Applied to claims and events to track where in the governance workflow they sit.

**What it actually is:**
A **workflow state attribute on content** — not a property of people or roles. `review_status` answers: "Where is this piece of content in its lifecycle?" It is orthogonal to who submitted it, what their role is, and what the content means.

**One existing coupling:** `submission_origins.default_review_status` — some origin types have a default review status (e.g., `ai_extracted_submission` defaults to `unreviewed`). This is appropriate: the process by which content entered the system is a reasonable signal for what review it requires. This is not a conflation of role with state — it is a governance policy that maps process type to required oversight.

**Conflation risk:** The risk is if `review_status` defaults are derived from actor identity (e.g., "Steward submissions skip review") rather than process type. Stewards may have the authority to self-approve content — but that is a permission policy applied to the review workflow, not a merging of the Steward role with the review_status concept.

**Clean definition:** review_status = a workflow state attribute on content. Records where in the governance lifecycle a piece of content sits. Independent of who created it, though process type may inform the default.

---

### Summary: The Conceptual Map

| Concept | Category | Belongs to | Current conflation |
|---|---|---|---|
| Steward | Contextual relationship + Permission set | Person ↔ LifeBook object | None — clean |
| StoryTeller | Contextual relationship to subject | Person ↔ LifeBook subject | Already in schema as `participation_role`; not yet in experience layer |
| Contributor | Permission set (membership) + Relationship descriptor | Person ↔ LifeBook object | Double duty: permission level AND relationship type; epistemic standing not captured |
| submission_origin | Provenance attribute (content) | Content | Conflates process type, actor governance role, and actor social relationship in one field |
| validity_state | Epistemic state (content) | Content | None — clean |
| review_status | Workflow state (content) | Content | None — clean; process-type-based defaults are appropriate governance |

---

### The Central Insight

The DP's question — "Who is a person in relation to the LifeBook?" vs "What action did a person perform?" — resolves into a two-axis model the schema already partially implements:

**Axis 1: Relationship to the LifeBook as an object** (governance, access, custody)
→ `lifebook_memberships.membership_role`: Steward, Contributor, Viewer

**Axis 2: Relationship to the subject of the LifeBook** (epistemic, experiential, meaning-bearing)
→ `lifebook_entities.participation_role`: subject, storyteller, family_member, witness, contributor, steward, etc.

These axes are orthogonal. A person's position on Axis 1 does not determine their position on Axis 2. A Steward (Axis 1) may have no personal memory of the subject — they are managing the LifeBook on behalf of someone else. A StoryTeller (Axis 2) may have limited system access — they are a Contributor-level member with rich experiential knowledge.

The experience layer has been treating these as one axis (the membership role) when they are two. The schema already encodes both — they just haven't been connected to the conversation and artifact experience yet.

**What doesn't need a migration:**
The axis 2 concept (StoryTeller as `participation_role`) is already in M0003. The gap is not the schema — it's the bridge between the schema's participation role model and the experience layer's conversation design. That bridge is what Phase 1 validation should help design.

**What may eventually need reconsideration:**
The `submission_origin` field conflates process type with actor identity. This will surface as an operational question as soon as the system needs to answer "did a StoryTeller or a Contributor submit this, and does that affect how we present it?" The current field cannot answer that question cleanly.

---

### Open Decisions (no migration until post-validation)

1. How does the experience layer surface `participation_role = 'storyteller'` in conversation context? The schema has it. The conversation design doesn't reference it yet.

2. Should `submission_origin` be refactored into separate process-type and actor-relationship fields? If so, when? The current values work for Phase 1. The question is whether they work for the Founding Member experience.

3. How does a StoryTeller who is also a Contributor-level member signal their epistemic standing? The system currently has no way to record "this person contributed from personal memory" — it only records that they are a `contributor` membership role.

---

## Pre-Validation Baseline

Before sessions begin, the following architectural elements are considered validated by design:

**Validated by Phase 0:**
- M0001–M0004 migration chain: structurally validated, behaviourally validated, security-validated
- conversation_threads, thread_obligations, narrative_artifact_links, event_artifact_links: schema in place
- artifacts table: M0004 columns (upload_state, submission_origin, ai_generated, etc.) in place
- Governance function layer (fn_lb_membership_role, fn_thread_has_active_invitation, etc.): in place, tested
- RLS boundary between steward/contributor/agent: tested in authenticated sessions

**Assumed by design (not yet tested in prototype):**
- One-question-per-turn pacing: assumed to work; validation will confirm or challenge
- "That's fine" / "We'll keep it here" as adequate closure language: assumed; validation will confirm or challenge
- Single upload offer per thread per session: assumed; validation will surface if this is too restrictive
- Proxy steward model (granddaughter building for grandmother): assumed; validation will reveal if distinct handling is needed
- Language barrier handling (receive without translating): assumed; validation will reveal if participants expect more

---

## Finding Framework

Each finding, when added, will follow this structure:

**Finding [n]: [Short title]**  
Session: [date and participant profile]  
Type: [Confirmation / Gap / Constraint / Design Revision Required]  
Evidence: [Verbatim quote or observation that supports the finding]  
Architectural implication: [What this means for the build]  
Status: [Open / Resolved / Deferred]

---

## Pre-Validation Open Questions

The following questions are unresolved by design and expected to be answered by validation. They are organized by the architectural component they would affect.

---

### OQ-1: Does the proxy steward model need distinct conversation handling?

**Component affected:** Conversation API, Orchestrator prompt design  
**Question:** When the system knows it is talking to a proxy steward (someone building a LifeBook for another person rather than themselves), should the conversation be structured differently? Does the AI need to acknowledge the relationship explicitly, or does treating the proxy as the information source work naturally?  
**Validation scenario:** Ukrainian grandmother session (granddaughter building for Hanna)  
**Expected outcome:** Either (a) the proxy model works transparently — the participant naturally takes on the information-source role and the conversation proceeds, or (b) there is friction — the participant wants the system to acknowledge that she is speaking *about* her grandmother rather than *as* herself.

---

### OQ-2: Is "We'll keep it here" adequate closure for unknown or unidentifiable artifacts?

**Component affected:** Upload experience, artifact record, UI/UX  
**Question:** When a participant cannot identify an artifact (who is in the photograph, what a document says), does "We'll keep it here" feel like appropriate holding, or does it feel like the system is doing nothing useful?  
**Validation scenario:** Any session with an unidentified photograph or foreign-language document  
**Expected outcome:** Either (a) the phrase lands as intentional and respectful, or (b) participants expect more — a placeholder metadata structure, a way to flag it for future research, or a different kind of acknowledgment.

---

### OQ-3: What do participants expect when they encounter a document in another language?

**Component affected:** Upload experience, AI capability expectations  
**Question:** When a participant uploads a document in Ukrainian or Russian, what is their initial expectation? Do they expect the system to offer translation? Do they expect it to attempt identification? The current design explicitly rejects automatic translation — but will participants accept that, or will it feel like a broken feature?  
**Validation scenario:** Ukrainian grandmother session — the marriage certificate in Ukrainian  
**Expected outcome:** Either (a) participants accept receive-and-hold without translation, or (b) they expect translation and experience its absence as a significant gap. If (b), the architectural question is whether translation should be offered as an explicit human-initiated Restoration (not AI-automatic), not whether translation should happen automatically.

---

### OQ-4: Does the emotional boundary land correctly for loss and displacement?

**Component affected:** Orchestrator emotional state detection, prompt design, Principle IX enforcement  
**Question:** When a participant describes loss — a house destroyed, a city left behind, a person dead — and the system receives without reframing ("That was a hard time. Would you like to keep going?"), does this feel like respectful presence or like inadequate response?  
**Validation scenario:** Ukrainian grandmother session — the house in Kharkiv, the war  
**Expected outcome:** This is the highest-stakes validation question. If the response feels cold to a Ukrainian participant, the principle is sound but the execution is wrong. The question is where the line is between receiving and abandoning.

---

### OQ-5: Is one upload offer per thread per session the right threshold?

**Component affected:** thread_obligations table, Orchestrator trigger logic  
**Question:** The design specifies that the system makes one upload offer per thread per session and does not revisit the offer if declined. Is this threshold correct? Do participants want the option to revisit mid-session, or does the single offer feel appropriately non-pressuring?  
**Validation scenario:** Any session where a participant initially declines an upload offer  
**Expected outcome:** Either (a) single offer feels right — the participant knows the option exists and can initiate if they change their mind, or (b) the threshold is too rigid — a natural moment arises mid-session where a second offer would be welcome.

---

### OQ-6: How does the system handle a session that produces no uploadable content?

**Component affected:** Thread state, obligation model, session close  
**Question:** Some people will have a rich conversation but no artifacts to upload — no photographs, no documents, nothing physical. Does the experience feel complete without an upload? Or does the absence of a concrete output make the session feel like it accomplished nothing?  
**Validation scenario:** Any session where participant has no artifacts  
**Expected outcome:** Either (a) the conversation itself feels like a sufficient output — the person feels like they preserved something — or (b) the session feels ephemeral without a tangible artifact to anchor it.

---

### OQ-7: How does the schema represent the StoryTeller role?

**Component affected:** `lifebook_memberships.role` enum, application layer, future migration  
**Question:** The DP has formalized three distinct human roles: Steward (governance), StoryTeller (meaning-bearing), and Contributor (supporting enrichment). The current schema has `steward` and `contributor` in `lifebook_memberships.role`. The distinction between StoryTeller and Contributor within the `contributor` value is not captured.

This means a neighbour who holds the only surviving memory of a person is represented identically to a professional archivist uploading documents — both are `contributor`. The system cannot distinguish a meaning-bearing contribution from an informational one.

**Resolution options (decision deferred to post-validation):**
1. Add `storyteller` as a distinct role value to `lifebook_memberships.role` in a future migration
2. Add a `membership_intent` column (`text` or enum) to capture the relationship type alongside the governance role, without changing the existing role values
3. Handle the distinction at the application layer only — role label remains `contributor`, but the application marks certain contributor sessions as StoryTeller-mode based on session context

**Why deferred:** The right schema representation depends on what Phase 1 validation reveals about how StoryTellers actually differ from Contributors in practice — what different capabilities they need, how the AI should behave differently toward them, and whether the distinction appears in conversation or only in governance.

**What must not happen:** The schema change should not be authored before validation establishes the use cases. Building a `storyteller` role value before understanding how it will be used in the conversation experience risks building the wrong model.

**Cross-reference:** ROLE_DEFINITIONS.md — the authoritative vocabulary reference.

---

## Confirmed Architectural Constraints (Pre-Validation)

The following are established by Principles IX and X and are not subject to revision by validation findings. They may be implemented differently, but they may not be removed:

1. The AI does not assign meaning to artifacts, events, or narratives. This is non-negotiable regardless of what participants expect.

2. AI colourization is not offered unprompted. If validation reveals that participants universally want this, the correct response is to make it a human-initiated, clearly labelled Restoration option — not to make it AI-automatic.

3. AI translation is not performed automatically. If validation reveals participants expect translation, the correct response is a human-initiated Restoration with clear Original Artifact preservation.

4. Meaning Actions (interpreting significance, characterizing the subject, reframing emotional experience) remain human-only regardless of participant expectations or requests.

5. Upload offers are invitations, not requirements. No session structure may make an artifact upload a prerequisite for advancing.

---

## Post-Validation Sections

The following sections will be populated after sessions are completed:

### Session Findings

*[To be added after each session — following the finding framework above]*

### Resolved Questions

*[Open questions answered by validation — including what the answer was and what the architectural implication is]*

### Design Revisions Required

*[Any element of the experience design that validation requires changing — with specific reference to which sessions produced the evidence]*

### Confirmed Design Elements

*[Elements that validation confirmed are working — candidates for the stable implementation spec]*

### Architectural Decisions Made

*[New architectural decisions that emerged from findings — in ADR format where appropriate]*

---

*PHASE_1_ARCHITECTURAL_FINDINGS.md — LifeBook HQ — Phase 1 — pre-validation framework — 2026-07-27*
