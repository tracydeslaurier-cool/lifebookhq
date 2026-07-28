# ROLE_DEFINITIONS.md
## LifeBook HQ — Authoritative Role Vocabulary
**Status:** Approved — foundational vocabulary  
**Date:** 2026-07-27  
**Authority:** Discovery Partner  
**Referenced by:** All experience, architecture, and governance documents

---

## Overview

LifeBook defines three distinct human roles in relationship to a LifeBook. These roles may overlap in one person, but they represent different relationships with the LifeBook and must not be conflated in design, conversation, or implementation.

The reason the distinction matters: LifeBook is not a genealogy system.

Genealogy asks: *Who belongs where in the family tree?*  
LifeBook asks: *Who carries meaning about this life?*

Those are different questions. A granddaughter may hold more meaningful memories of a grandmother than a biological child. A neighbour may carry the only surviving story about someone. A friend may know the context behind a photograph that no family member can explain. Biological or legal relationship does not determine who is the StoryTeller.

This distinction is what makes LifeBook a richer human model than a genealogical record.

---

## The Three Roles

### Steward

**A governance role.**

The Steward is responsible for the LifeBook as an object: its permissions, access controls, continuity, and integrity. The Steward decides who can contribute, what is published, what is restricted, what is reviewed, and who may inherit the LifeBook's custody over time.

The Steward may or may not be the person the LifeBook is about. A granddaughter building a LifeBook for her grandmother is the Steward. The grandmother, if she participates, may be the primary StoryTeller. They are not the same role.

**What Stewards do:**
- Control who has access to the LifeBook
- Review and approve contributions from others
- Manage access classifications (private, family, culturally governed)
- Transfer stewardship if needed
- Make decisions about what enters the authoritative record

**Schema representation:** `lifebook_memberships.role = 'steward'`

**In experience documents:** Use "Steward" when the context is governance, access, permissions, review workflow, or custody.

---

### StoryTeller

**A meaning-bearing role.**

The StoryTeller is the person contributing memories, experiences, reflections, or personal knowledge about the life being recorded. The StoryTeller is the source of meaning in the LifeBook — not the manager of the LifeBook, but the person whose knowledge gives it depth.

The StoryTeller determines:
- What relationship they want with a given artifact right now (Preservation or Discovery)
- Which memories they are ready to share and which they are not
- What a piece of evidence means to them
- Whether they want to investigate, connect, or simply hold what they have

A StoryTeller cannot be automated. AI may invite the StoryTeller to speak. AI may not speak for them.

**Who may be a StoryTeller:**
- The subject of the LifeBook (if living and participating)
- A family member who holds memories
- A family friend who knew the subject in a way no relative did
- A neighbour who holds the only surviving account of something
- A community member with cultural knowledge
- The Steward themselves, in their personal-memory capacity

**What StoryTellers do:**
- Contribute memories, reflections, and personal accounts
- Identify people, places, and events in artifacts
- Add Interpretation to the artifact relationship (Layer 3)
- Decide what relationship they want with an artifact at any given moment
- Determine what their experience means — and share that meaning on their own terms

**Schema representation:** Currently not a distinct role value in `lifebook_memberships`. StoryTellers may enter the system as `steward` (when they are also the Steward) or as `contributor` (when they are participating without governance authority). The distinction between StoryTeller and Contributor within the `contributor` role is not currently captured in the schema — see Schema Gap note below.

**In experience documents:** Use "StoryTeller" when the context is memory, meaning, personal knowledge, artifact relationship, or contribution of lived experience. Do not substitute "steward" when the meaning-bearing function is what is being discussed.

---

### Contributor

**A supporting role.**

A Contributor adds information, context, or artifacts to a LifeBook but may not be the primary StoryTeller. A Contributor enriches understanding without necessarily carrying meaning about the life being recorded.

Distinctions from the StoryTeller:
- A Contributor may add factual context (a date, a place, a document) without having personal memory of the events
- A Contributor may upload artifacts without being able to interpret them
- A Contributor operates at a supporting level — their additions enter the review queue and require Steward approval before entering the authoritative record

**Examples of Contributors who are not StoryTellers:**
- A professional researcher providing genealogical data
- A community archivist uploading digitized records
- A family member adding photographs they found without personal memory of them

**Examples where Contributor and StoryTeller overlap:**
- A family member who both uploads photographs and shares memories of the events in them
- A neighbour who adds context documents and also contributes their own recollections

**Schema representation:** `lifebook_memberships.role = 'contributor'`

**In experience documents:** Use "Contributor" when the context is supporting enrichment without personal meaning-bearing. Use "StoryTeller" when the person is contributing from memory, personal knowledge, or lived experience.

---

## Role Overlap

One person may hold multiple roles simultaneously:

| Scenario | Steward | StoryTeller | Contributor |
|---|---|---|---|
| Granddaughter building Hanna's LifeBook | ✓ | ✓ (her own memories of Hanna) | — |
| Hanna herself, if she participates | — | ✓ (primary) | — |
| A neighbour who knew Hanna | — | ✓ (for specific stories) | ✓ |
| A professional researcher | — | — | ✓ |
| A family member with no memories but access to documents | — | — | ✓ |

The roles are not exclusive. They describe the type of relationship a person has with the LifeBook at a given moment, not a permanent classification.

---

## Implications for Design

### Conversation design
When the AI is speaking with someone in their **StoryTeller** capacity, the conversation is about memory, meaning, and personal experience. The voice, pacing, and questions should reflect that.

When the AI is supporting someone in their **Steward** capacity, the conversation is about decisions, review, and governance. Different tone, different questions.

When these overlap in one person (the most common case), the AI follows the context — not the formal role label.

### Artifact relationship
The five modes of artifact engagement (share, remember, investigate, connect, interpret) are **StoryTeller** functions. The Steward function is access classification and review approval. These happen in different parts of the experience.

### Schema gap (architectural decision pending)
The current schema's `lifebook_memberships.role` enum does not distinguish between StoryTeller and Contributor within the `contributor` value. This means:
- A neighbour with meaningful personal memories and a researcher with only documents are currently represented identically in the schema
- The system cannot currently distinguish a meaning-bearing contribution from an informational contribution

This gap was not visible before the StoryTeller role was formalized. Resolution options:
1. Add a `storyteller` role value to `lifebook_memberships.role` in a future migration
2. Add a `membership_intent` column to capture the relationship type alongside the governance role
3. Handle the distinction at the application layer without a schema change

**Decision deferred to post-validation.** The right approach depends on what Phase 1 validation reveals about how the distinction plays out in real sessions. No migration should be authored until that is known.

---

## What This Changes in Existing Documents

Documents that use "steward" in contexts where "StoryTeller" is the correct role will be updated. The change is not mechanical find-and-replace — it requires judgment about whether the context is governance (Steward correct) or meaning-bearing (StoryTeller correct).

Priority updates already applied:
- ARTIFACT_RELATIONSHIP_EXPERIENCE.md — five modes of artifact engagement now correctly attributed to StoryTeller
- UPLOAD_EXPERIENCE_DESIGN.md — Preservation vs. Discovery framed as StoryTeller decision

---

*ROLE_DEFINITIONS.md — LifeBook HQ — Foundational Vocabulary — 2026-07-27*
