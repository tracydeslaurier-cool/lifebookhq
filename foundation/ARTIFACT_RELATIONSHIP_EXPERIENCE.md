# ARTIFACT_RELATIONSHIP_EXPERIENCE.md
## LifeBook HQ — Phase 1 Experience Validation
**Status:** Phase 1 Draft — experience specification  
**Milestone:** Conversation Experience v1  
**Date:** 2026-07-27  
**Companion documents:** UPLOAD_EXPERIENCE_DESIGN.md, CONTEXTUAL_UPLOAD_FLOW.md, LIFEBOOK_PRINCIPLES.md (Principles IX, X)

---

## 1. What This Document Is

This document defines the artifact relationship experience: how LifeBook presents, contextualizes, and governs the relationship between a person and their family artifacts.

It is not a schema document. The schema is in the migrations. It is not a technical upload specification. That is CONTEXTUAL_UPLOAD_FLOW.md.

This is the experience model: what the person understands about their artifacts, what the AI is allowed to do with them, and what the three-layer artifact model means in practice.

---

## 1.1 The Artifact Relationship Principle

LifeBook distinguishes between two fundamentally different things a person may be doing when they bring an artifact forward:

**Artifact Preservation:** "I have this photograph." The person is giving LifeBook something to hold. Their intent is safekeeping. They may have nothing more to say about it right now — and that is complete.

**Artifact Discovery:** "I wonder what this photograph can reveal." The person is inviting investigation. They want to understand the artifact more deeply — who is in it, what it connects to, what it might mean.

The same artifact may serve either purpose depending on the person and the moment. A person who uploads their grandmother's photograph on the day their grandmother died is doing something different from a person who uploads the same photograph six months later, curious about who the other people in it might be. The artifact is identical. The relationship the person wants with it is not.

**LifeBook never assumes discovery is wanted when preservation is offered.**

The question that governs every artifact interaction is not "What is this artifact?" It is: **"What relationship does the person want to have with this artifact right now?"**

That question is as important as anything the system could technically determine about the artifact itself. The artifact is only half the story. The other half is why the person brought it forward.

**The five modes of artifact engagement (person-determined, not AI-determined):**

A person may bring an artifact forward to:
- **Share** it — make it part of the LifeBook, no further action required
- **Remember** it — use it to prompt their own memory, without expecting the system to analyze it
- **Investigate** it — actively seek to understand what it contains or depicts
- **Connect** it — anchor it to a specific story, person, or event
- **Interpret** it — add meaning they have decided to attach to it

AI analysis is an invitation, not a default. The system may offer, once, a question that opens the door to any of these modes. The person's response — including silence — determines which mode they are in. The system follows. It does not lead.

---

## 2. The Three-Layer Model

Every artifact in LifeBook exists in relationship to three layers. Not every artifact has all three. The Original Artifact is always present. Restoration and Interpretation are added by humans — never automatically.

### Layer 1: Original Artifact

The thing as it was: a photograph taken in 1955, a handwritten letter, a certificate issued in a language the family no longer reads, an image of a gravestone taken on a phone.

The Original Artifact is what the person gives to LifeBook. It is received without modification, without automatic processing, and without interpretation. It is preserved as it is — in whatever state it arrives: faded, damaged, blurry, partially legible, in a language no one in the family can now read.

**Governing principle:** The Original Artifact is never automatically improved, enhanced, colourized, or translated by the system. Doing so without the steward's explicit instruction treats the original as inadequate. It is not inadequate. It is the record as it exists.

**What the AI may do with the Original Artifact:**
- Confirm it was received and is preserved
- Recognize its type (photograph, document, handwritten material)
- Detect the probable language of text (but not read or translate)
- Observe that it is linked to the active conversation thread
- Ask one contextualizing question

**What the AI may never do with the Original Artifact:**
- Modify or process it automatically
- Tell the person what it depicts, means, or represents
- Evaluate its quality, completeness, or historical significance
- Perform colourization, restoration, or enhancement without explicit request

---

### Layer 2: Restoration

A technical improvement to the artifact's accessibility. A digitized scan made from a deteriorating original. A colourized version of a black-and-white photograph. A transcription of a handwritten document. An enhanced copy of a blurry image.

Restoration changes the artifact's accessibility without changing its authenticity. A colourized photograph is more visually accessible, but it is not a better record of the original moment — the original moment was black-and-white. Both the Original and the Restoration coexist. Neither replaces the other.

**Who initiates Restoration:** The steward. Always. The system never initiates Restoration unprompted.

**How Restoration is offered:** As a specific, labelled option that the steward chooses to initiate — not as an automatic enhancement that appears alongside the original without acknowledgment.

**What Restoration does not do:**
- Replace the Original Artifact
- Become the "authoritative" version of the record
- Add interpretive value — a colourized photograph does not reveal new historical information

**The colourization case specifically:** Colourization is technically simple, visually dramatic, and emotionally complicated. Some family members will welcome it. Others will find it a falsification of the actual moment. The system does not express a preference. The steward initiates it or does not. If initiated, it is clearly labelled as a Restoration — not as "the photograph" but as "a colourized version of the photograph."

---

### Layer 3: Interpretation

What a human says the artifact means.

The caption: "This was taken the summer before he emigrated." The identification: "The woman on the left is my great-grandmother, Hanna." The story: "She kept this photograph for sixty years. She never talked about why." The context: "This was taken in the town she grew up in. The buildings in the background were destroyed in 1943."

Interpretation is the only layer that belongs exclusively to humans. It cannot be generated by the AI. It can only be invited by the AI and provided by the person.

**What the AI may do:**
- Ask one question that invites Interpretation ("Can you tell me who's in it?" / "What can you tell me about this?")
- Receive the Interpretation and record it
- Connect the Interpretation to the active thread as governed content

**What the AI may not do:**
- Generate Interpretation (identify the people, suggest what the scene depicts, propose what the artifact represents)
- Treat the AI's visual analysis as equivalent to human Interpretation
- Accept AI-generated Interpretation as a substitute for human Interpretation, even temporarily

**On AI-assisted identification:** If future capability allows the AI to detect that a person in a photograph resembles a known entity in the LifeBook's person graph, this remains Discovery, not Interpretation. The AI may surface the potential match ("This might be related to your grandfather's thread — do you recognize this person?"). The human confirms or rejects. The human's decision is Interpretation. The AI's observation is not.

---

## 3. What the Experience Looks Like

### For the steward

A steward managing their LifeBook sees their artifacts in three states:

**Received:** The artifact has been uploaded and is in the governed record as a pending artifact. It is preserved. It awaits context.

**Contextualized:** The artifact has at least one piece of human-provided Interpretation — a name, a date, a caption, a story anchor. It is linked to a thread.

**Complete:** The artifact has an Original, is anchored to a thread, has at least one piece of Interpretation, and has been reviewed by the steward. It is part of the authoritative LifeBook record.

The experience should never imply that a Received artifact is broken or incomplete. It is simply waiting. Many artifacts will wait for months or years. That is expected and normal.

### For a contributor

A contributor (a family member invited to add material) sees artifacts in the threads they have access to. They can add Interpretation to artifacts — captions, identifications, stories — and those additions enter the review queue as `submission_origin = 'family_contribution'` and `review_status = 'pending'`.

Contributors cannot initiate Restoration. They cannot modify the Original Artifact. They can only add to the Interpretation layer, which the steward then reviews.

### For the AI

The AI sees artifacts as objects to contextualize, not to improve. Its role in the artifact relationship is:

1. Trigger the upload offer when appropriate (CONTEXTUAL_UPLOAD_FLOW.md §2)
2. Receive the artifact — confirm receipt, link to thread, create artifact record
3. Ask one question that invites Interpretation
4. Receive whatever Interpretation the person provides (including "I don't know")
5. Hold the artifact and the conversation state for future sessions

The AI does not evaluate artifacts. It does not see an artifact of a destroyed house and recognize the loss. It sees an artifact and asks what the person can tell it. The loss, if named, is received — not interpreted.

---

## 4. Naming This Experience

The experience defined in this document is called the **Artifact Relationship Experience** — not "Artifact Intelligence" and not "AI-assisted preservation."

The name matters because it describes what the product does: it creates a relationship between the person and their artifacts, mediated by a conversation system that is careful, restrained, and governed.

"Artifact Intelligence" implies the AI is the intelligent actor analyzing the artifact. It is not. The human is the intelligent actor. The AI facilitates.

"AI-assisted preservation" is accurate but generic. The name "Artifact Relationship Experience" names the distinctiveness: LifeBook's contribution is not technical processing of artifacts. It is the conversation and governance layer that makes the relationship between a person and their family's artifacts intentional, permanent, and governed.

---

## 5. Schema Foundation (Reference)

The artifact relationship experience is built on the M0004 artifact columns, which already exist in the schema:

| Column | Layer | Purpose |
|---|---|---|
| `object_key` | Original | Storage pointer for the artifact file |
| `upload_state` | Original | Tracks upload completion |
| `submission_origin` | All layers | 'steward_direct', 'ai_assisted', 'family_contribution' |
| `ai_generated` | Restoration / Interpretation | Flags AI-produced content |
| `producing_agent_code` | All layers | Records which agent produced the content |
| `context_manifest_id` | All layers | Links to the session context |
| `validity_state` | Original | Governs whether the artifact is in the published record |
| `access_classification` | Original | Steward-controlled visibility |

Restoration and Interpretation content will be associated with the artifact via:
- `artifact_source_links` (connecting artifacts to sources, narratives, events)
- Future annotation model: an `artifact_interpretations` table or `claims` on artifact entities — to be designed when Phase 1 validation establishes what Interpretation content looks like in practice

The absence of a formal Interpretation table in the current schema is intentional. The right structure for Interpretation depends on what kinds of Interpretation people actually provide. Designing the table before seeing real sessions would be premature.

---

## 6. What This Document Does Not Decide

The following questions are open and will be resolved by Phase 1 validation findings:

1. **What does "Contextualized" look like in the UI?** The statuses are defined here conceptually. The visual representation is a Phase 1 build decision.

2. **Should the system surface uncontextualized artifacts as a standing invitation?** The design assumes yes — a steward can see their received artifacts and contextualize them over time. Whether this is a list, a notification, or something else is a UI decision.

3. **Does the Interpretation layer need its own table, or can it live in `claims` + artifact source links?** The architectural decision will be made after validation reveals what Interpretation content actually looks like. No schema migration should be authored until that is known.

4. **What happens when two family members provide conflicting Interpretation?** (OQ pending — not yet addressed in Phase 1 scope)

---

*ARTIFACT_RELATIONSHIP_EXPERIENCE.md — LifeBook HQ — Phase 1 Experience Validation — 2026-07-27*
