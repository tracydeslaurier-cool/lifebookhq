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
