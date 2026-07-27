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

### 2026-07-27 — AI-generated portrait from description

**Context:** Some subjects of LifeBook entries have no known photographs. During the Founder Acceptance Journey design, the scenario arose of a person born in 1890 whose family has no images.

**Why deferred:** AI image generation raises significant governance questions (Principle IV — the record is governed, not inferred) and cultural sensitivity issues (generating portraits of deceased persons whose communities may not consent to AI representation). This is not a v1 capability.

**What would trigger scoping:** A formal decision on whether AI-generated portrait imagery can ever be a governed artifact, and under what cultural governance constraints. This is a policy decision before a technical one.

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

*FUTURE_IDEAS.md — LifeBook HQ — append-only — last updated 2026-07-27*
