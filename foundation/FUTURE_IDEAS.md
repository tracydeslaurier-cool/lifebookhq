# FUTURE_IDEAS.md
## LifeBook HQ — Ideas Beyond Current Scope
**Status:** Ongoing — append as ideas arise  
**Date created:** 2026-07-27  
**Purpose:** Preserve good ideas that are not required for Conversation Experience v1.  
**Rule:** Nothing in this document is scheduled, committed to, or implied by the current roadmap. Ideas here are not scope creep — they are a disciplined record of what we thought of and chose not to do yet.

---

> "The architecture is now mature enough that our effort should shift from designing
> LifeBook to building LifeBook."
> — DP sign-off, 2026-07-27

---

## How to Use This Document

When an idea arises during implementation planning or conversation that is genuinely valuable but not required for the current milestone, it is recorded here rather than incorporated into the architecture.

To add an idea: append a section below with a date, brief description, and the context in which it arose. Do not elaborate beyond what is needed to understand the idea and why it was deferred. Full design work happens only when the idea is formally scoped into a future milestone.

Ideas in this document are not prioritised against each other. Prioritisation happens at milestone planning time.

---

## Ideas

### 2026-07-27 — Multi-format upload intake

**Context:** The upload flow (CONTEXTUAL_UPLOAD_FLOW.md) currently handles photographs and documents. During architecture review, the question arose whether LifeBook should eventually accept audio recordings (voice memos, recorded interviews) and video clips as artifact types.

**Why deferred:** Audio and video introduce format validation, transcription pipelines, and storage cost profiles that are out of scope for v1. The `artifacts` table schema is extensible to new `artifact_type` values — no schema change required to add audio/video later.

**What would trigger scoping:** A concrete Founding Member use case involving audio or video that cannot be served by uploading a document or photograph.

---

### 2026-07-27 — Authorship, Provenance, and AI Disclosure Layer

**Context:** During M0004 design and validation, the architectural and policy gaps between LifeBook's current partial provenance support (`submission_origin`, `ai_generated`, `producing_agent_code`, `context_manifest_id`) and a full, auditable provenance model were identified. The question is not whether LifeBook needs this layer — it does — but when.

**Why it matters:** LifeBook preserves records meant to last decades. Any claim, event, or narrative in the authoritative record must be traceable: where did this information originate, what AI operations were applied to it, who reviewed it, and what was the approval chain? The current schema partially supports this, but structured transformation type logging, reviewer identity on approvals, synthetic media labelling, source-to-output lineage, and user-facing provenance summaries are all absent.

**Why it is not part of M0004:** M0004 addresses conversation threading and the event review workflow. Provenance enrichment is architecturally adjacent but would substantially expand scope. More importantly, the right provenance model depends on operational experience — what transformations actually occur in practice — not on theoretical projections. Designing the layer before the conversation experience is in production risks building provenance fields for operations that never happen and missing the ones that matter.

**Current architectural foundations already in place:** `submission_origin`, `ai_generated`, `producing_agent_code`, `context_manifest_id` on claims, events, and artifacts; `review_status` governance chain; `contest_records` and `validity_state` for dispute and epistemic status; `superseded_by_id` lineage on claims; delete-denied policies ensuring the full audit trail is permanent. The policy governing this layer is established in `AUTHORSHIP_PROVENANCE_AND_AI_DISCLOSURE.md`.

**What would trigger formal milestone planning:** Completion of Conversation Experience v1 in production with Founding Members, with real producing agent code and context manifest data being generated. At that point, actual provenance patterns can be observed and the implementation scoped against them.

**Cross-reference:** The AI-generated portrait entry (below) is a specific instance of this broader milestone. When the Authorship, Provenance, and AI Disclosure Layer is formally scoped, the portrait governance question should be resolved within it rather than as a separate design effort.

---

### 2026-07-27 — AI-generated portrait from description

**Context:** Some subjects of LifeBook entries have no known photographs. During the Founder Acceptance Journey design, the scenario arose of a person born in 1890 whose family has no images.

**Why deferred:** AI image generation raises significant governance questions (Principle IV — the record is governed, not inferred) and cultural sensitivity issues (generating portraits of deceased persons whose communities may not consent to AI representation). This is not a v1 capability.

**What would trigger scoping:** Formal design of the Authorship, Provenance, and AI Disclosure Layer (see above), which will establish the governance framework for synthetic media — including permanent labelling requirements, cultural consent constraints, and separation from documentary artifacts. The portrait capability is a specific application of that framework, not a standalone decision.

---

### 2026-07-27 — Cross-lifebook family tree linking

**Context:** LifeBook currently treats each lifebook as the story of one subject entity. In extended family use, multiple lifebooks will share persons (e.g., Bohdan Shevchenko appears in both Marta's lifebook and Andriy's lifebook). The question arose whether shared persons should be linked across lifebooks.

**Why deferred:** Cross-lifebook references introduce complex permission questions: if Marta's lifebook contains private claims about Bohdan, does Andriy's lifebook inherit access to them? This is a governance architecture question that requires its own design milestone.

**What would trigger scoping:** Two Founding Members independently creating lifebooks that share a common ancestor, with a clear user-expressed desire to connect them.

---

### 2026-07-27 — Structured export for genealogical software (GEDCOM)

**Context:** LifeBook's entity/person/event model is structurally compatible with GEDCOM (the standard format for genealogical data exchange). During the IMPLEMENTATION_BUILD_ORDER design, the question arose whether LifeBook should support export to GEDCOM for use in tools like Ancestry or FamilySearch.

**Why deferred:** Export formats are not required for v1. GEDCOM compatibility requires mapping LifeBook's governed claims model to GEDCOM's flatter fact structure, which involves design choices about which claims are exported and how contested or pending-review claims are handled.

**What would trigger scoping:** Founding Member feedback requesting interoperability with a specific genealogical tool.

---

### 2026-07-27 — Steward-to-steward handoff (custody transfer)

**Context:** A lifebook's primary steward may eventually need to transfer stewardship — illness, death, or a decision to hand the responsibility to an adult child. The current schema has one steward role per lifebook but no formal custody transfer mechanism.

**Why deferred:** This is a governance and legal question as much as a technical one. What does it mean for a steward to transfer custody? Is it revocable? Does the original steward retain read access? These questions require formal policy design.

**What would trigger scoping:** A Founding Member explicitly requesting a handoff mechanism, or a legal/estate-planning context that makes it a near-term requirement.

---

### 2026-07-27 — Periodic narrative auto-digest

**Context:** As a lifebook accumulates claims and threads over months and years, a periodic "digest" narrative — automatically generated from the current state of all governed claims — could serve as a living summary of the person's story. This is distinct from thread summaries, which are conversation-scoped.

**Why deferred:** Auto-generated narrative digests raise Principle IV concerns: they are AI-produced narratives that would require steward review before entering the authoritative record. The workflow for generating, reviewing, and promoting a whole-lifebook digest is a meaningful design effort in its own right. It also presupposes that the governed claims layer is rich enough to generate something meaningful — which requires implementation maturity.

**What would trigger scoping:** Post-v1, when the review workflow is stable and a cohort of Founding Members has populated their lifebooks with enough content to make digest generation worthwhile.

---

### 2026-07-27 — Interpretation as a distinct architectural layer

**Context:** During preparation of Phase 0 policy documentation, a conceptual distinction emerged between Evidence and Representation that the current four-layer model (Reality / Evidence / Governance / Representation) does not explicitly capture: Interpretation.

**Definition candidate:** Interpretation includes human conclusions, contextual explanations, thematic analysis, inferred meaning, and narrative framing that is derived from evidence but not identical to it. A photograph is Evidence. The caption "This was taken the summer before he emigrated" is Interpretation. A claim that "Bohdan valued education above all else" derived from multiple source documents is Interpretation. The current architecture has no layer or type that clearly distinguishes Interpretation from raw Evidence or from AI-generated Representation.

**Why it may matter:** If Interpretation is treated as Evidence, it inherits Evidence's epistemological weight — but it is actually a step removed, carrying the interpreter's perspective and context. If it is treated as Representation (narrative output), it loses traceability back to the underlying evidence chain. A distinct Interpretation layer could support: interpreter attribution (who drew this conclusion?), evidence anchoring (which sources support this interpretation?), contestability (interpretations may be challenged without challenging the underlying evidence), and cultural framing (the same evidence may yield different interpretations across family branches or cultural contexts).

**Why deferred:** The current four-layer model is sufficient for Phase 0 and Phase 1. Adding an Interpretation layer before implementation experience would risk over-engineering a distinction that may or may not prove necessary in practice. The right time to evaluate this is when real conversations with Founding Members produce content that the current model cannot cleanly classify.

**What would trigger scoping:** A concrete case during Phase 1 or early Founding Member sessions where a steward or interviewer produces content that is clearly neither raw Evidence nor authored Representation — content that is derived, framed, and attributed to a human interpreter, requiring distinct governance treatment.

**Cross-reference:** If scoped, this would interact with the Authorship, Provenance, and AI Disclosure Layer (above), since AI-generated interpretations would require the same disclosure and review chain as any other AI-produced content.

---

### 2026-07-28 — Authenticated Expression Provenance Model

**Context:** Principle XII (Authentic Expression) and its AI-Assisted Expression ruling establish that AI-drafted content may qualify as authenticated StoryTeller expression, provided the StoryTeller knowingly reviews, revises, and explicitly adopts the final result. That ruling creates a future implementation obligation: the system must be able to demonstrate, for any given expression, that authentication was properly established.

**What future implementation must preserve:**

- The StoryTeller's original spoken or written input
- Each AI-assisted draft
- Subsequent human revisions
- The final adopted expression
- The identity of the person authenticating it
- The date, time, and method of authentication
- The relationship between all versions
- Any later withdrawal, supersession, or correction of that authentication

**Why this is more than version history:** This is a chain of expressive provenance culminating in an explicit authentication event. The provenance trail does not diminish the authenticity of the final expression — it demonstrates how authenticity was established. The distinction the system must preserve: source material / editorial assistance / revision / adoption / authenticated StoryTeller expression. These are not interchangeable categories.

**Implementation shorthand:** "Version history tied to an authentication event."

**Why deferred:** No current implementation involves AI-assisted first-person expression. The schema requirements cannot be correctly specified until the interaction patterns, consent flows, and review UX are designed. Designing the data model before the workflow is known would produce wrong columns.

**What would trigger scoping:** Formal design of first-person narration, voice synthesis, or AI drafting workflows — any capability that produces content intended to be attributed to the StoryTeller in the first person.

**Reference:** Principle XII — Authentic Expression (LIFEBOOK_PRINCIPLES.md).

**Note:** This belongs in FUTURE_IDEAS.md rather than DEFERRED_TYPE_REGISTER.md. This is a future capability and architectural obligation — not yet a known type or resolvable domain entity. The type register captures unresolved schema-level concepts; this is an unimplemented capability milestone.

---

*FUTURE_IDEAS.md — LifeBook HQ — append-only — last updated 2026-07-28 (added Authenticated Expression Provenance Model)*
