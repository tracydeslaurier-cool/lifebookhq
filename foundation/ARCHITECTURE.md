# LifeBook Architecture

Status: APPROVED DRAFT — living document
Last updated: 2026-07-12
Governed by: PRODUCT_CONSTITUTION.md, ARCHITECTURE_VISION.md, PRODUCT_SPECIFICATION.md

This document describes how LifeBook should be built so that the architecture itself expresses the Foundation. Clarity is favoured over completeness; where the Foundation is silent, assumptions are stated and flagged for the Director.

Approved architectural direction (Director, 2026-07-12): the two-plane architecture, the modular monolith, the Archive as sole writer to the entrusted plane, the identity structure, and full regenerability of the understanding plane.

---

# 1. Core Architectural Principles

**P1 — Originals are sacred.**
The Storykeeper's words are stored append-only, enforced at the schema level, not by convention. Nothing in the system is *capable* of altering an original. "Never invent a memory" becomes a property of the database, not a policy.

**P2 — Interpretation is disposable.**
Everything the AI concludes lives in a separate layer that can be deleted and rebuilt from originals at any time. If we cannot regenerate it, it is stored in the wrong place.

**P3 — The graph grows quietly.**
People, places, relationships, and themes emerge from conversation as derived knowledge. The Storykeeper never performs clerical data maintenance. Structure is inferred, and confirmation is requested only when it creates meaningful control or prevents material error.

**P4 — Identity is the person.**
Every record hangs off the Storykeeper, never a device or session (Decision 008). Consent and access are modelled per-Storykeeper from day one, even though V1 has no sharing — because sharing added later must be an *opening of doors*, not a re-plumbing.

**P5 — Models change; LifeBook must not care.**
Every AI capability (conversation, extraction, embedding, speech) sits behind an internal boundary owned by us. No provider format is ever stored as truth. First Principle 10, expressed as code structure.

**P6 — Built for decades, so built boring.**
Proven, widely supported technology; open formats; export as a first-class capability. Novelty is a liability in a product that must outlive its frameworks.

**P7 — Calm is a performance requirement.**
Slow, intentional transitions are design; slow responses are anxiety. Anything that can be done after responding to the Storykeeper (interpretation, embedding, connection-building) is done asynchronously, invisibly.

**P8 — The Lexicon reaches the code.**
Domain types are named `Storykeeper`, `Moment`, `Companion`, `Conversation`, `Book`. A developer reading the schema should be reading the philosophy.

---

# 2. Domain Model

The model divides into an identity layer and two planes. The two-plane division is the single most important idea in this document.

## Identity and Structure (Director's decision: an account is not a life)

| Entity | Why it exists |
|---|---|
| **Storykeeper** | An authenticated person. The root of ownership, consent, and access. One Storykeeper may keep or contribute to multiple Books over time. |
| **Book** | A collection dedicated to one life. V1 presents exactly one, created invisibly, whose Subject is the Storykeeper — but the schema never equates account with life subject, so "my life" and "my mother as I remember her" are future rows, not future migrations. |
| **Subject** | The life a Book is about. Usually the Storykeeper; not necessarily. |
| **Contributor** | A Storykeeper's role within a Book (V1: owner only). Every entrusted record knows which Contributor gave it. |
| **Legacy Steward** | A dormant designation: whom the Storykeeper names to steward the Book after death. Modelled in V1; not exposed, not operational. Activation, consent, revocation, and legal policy are explicitly unresolved (Director's decision). |

### Pre-identity structure (Director's decision)

An anonymous first conversation may create an **unclaimed Book**, an **anonymous Contributor**, and their Conversation and Moments. It must never create a fictional authenticated Storykeeper identity. When identity is established, the temporary structure is attached to the new Storykeeper without rewriting any original Moment — attachment is a new fact, not an edit. The unclaimed retention window (spec §8) applies to the complete temporary structure.

## The Entrusted Plane (immutable, authored by people)

| Entity | Why it exists |
|---|---|
| **Conversation** | The scene in which memories surface. Preserves order and setting so meaning is never orphaned from context. |
| **Moment** | The fundamental unit. **A Moment is one intentional Storykeeper contribution within a conversation** (Director's decision): it may span several sentences and natural pauses. It records the original words verbatim, original language, time, input mode, Conversation, Book, and Contributor. Append-only; edits create versions beside the original. |
| **Companion Turn** | What the Companion said, preserved beside Moments but never mingled with them, and **never represented as the Storykeeper's biography or authored memory** (Director's decision). Kept because a memory's meaning often lives in what it was answering. |
| **Assertion** | A Storykeeper-authored confirmation or correction of the machine's understanding ("yes, Danylo is my grandson"). Carries provenance. It outranks machine inference *within that Storykeeper's account*; it does not become universal objective truth and does not erase other contributors' perspectives (Director's decision). |
| **Media** | (Post-V1) Photographs, audio, documents — binary originals, content-addressed, as immutable as words. Modelled now so the plane doesn't need reshaping later. |
| **Source** | Where an entrusted thing came from: this conversation, an upload, a future import (e.g., genealogy records). Every original has exactly one Source. |

### Intentional submission vs technical chunking

The Moment boundary is the Storykeeper's intent, never the transport's. Speech-recognition partials, streaming fragments, autosaved drafts, and network-level chunks are plumbing — they are never stored as Moments. Pauses for thought within one contribution do not split it.

**Layered voice completion (Director's decision):** the Storykeeper speaks naturally → a generous silence indicates *possible* completion but commits nothing → the interface enters a quiet transcript-review state → the Storykeeper may continue speaking, use a gentle completion control (working language: **"Keep this"**), speak a natural completion phrase, or allow acceptance after a visible grace period. The immutable Moment is created only upon intentional completion.

**Provisional capture requirements.** Between first word and completion, the contribution exists in a provisional state that the architecture must protect:

- Provisional transcripts and audio are held **server-side**, keyed to the Conversation — never only in browser storage. A crash, dropped connection, or closed tab must not lose an uncommitted thought (spec §15.3).
- The provisional store is a distinct area: not the entrusted plane (nothing there is committed), not the understanding plane (nothing there is derived). It carries the same encryption, purpose-scoping, and audit discipline as entrusted content — provisional does not mean less private.
- Finalization is **atomic promotion**: the reviewed contribution becomes exactly one Moment, provenance-stamped, via the Archive's single door. Provisional artifacts (partial chunks, silence boundaries, superseded transcript revisions) are discarded after promotion — they are transport, not history.
- Abandoned provisional content follows a defined expiry, and deletion rights apply to it fully.
- Whether the finalized Moment retains its **source audio** as an entrusted Media original in V1, or transcript-only, is an open decision (§8) — it affects storage cost, export shape, and the voice-system directive.

## The Understanding Plane (derived, regenerable, provenance-carrying)

| Entity | Why it exists |
|---|---|
| **Memory** | A unit of understanding built *from* Moments — "the summer at the lake" may span five Moments across three conversations. Distinct from Moment: a Moment is what was said; a Memory is what is understood. |
| **Person** | Someone who appears in the story. Emerges from mentions; never a contact record. Accumulates identity gradually. (Distinct from Storykeeper, which is an identity-layer entity.) |
| **Relationship** | A living edge between people in the story, carrying time: when it began, how it changed. Preserved without judgment. |
| **Place** | Meaning, not coordinates. "The farmhouse" is a Place even if no address is ever known. |
| **Event** | A happening in lived time ("the wedding," "the move to Canada") that anchors Moments to the chronology of a life rather than the chronology of data entry. |
| **Theme** | Emergent threads (grief, migration, faith). Never forced, never shown as labels — used by the Companion to understand, not to categorize the Storykeeper. |
| **Provenance** | The record binding every derived entity to its source Moments and Assertions, the model that produced it, and when. Nothing in this plane exists without it. |

Where an Assertion and a machine inference conflict, the Assertion governs for that account. Understanding is perspective-carrying by design: two Contributors may remember one Event differently, and both perspectives are preserved rather than reconciled into a single "truth."

### Epistemic standing (Director's decision)

The understanding plane never reduces to true/false. Every piece of understanding carries an epistemic standing, with vocabulary such as:

- **documented fact** — supported by an entrusted Source (a record, a certificate, a dated photograph)
- **authored assertion** — the Storykeeper's own confirmation or correction
- **corroborated recollection** — remembered consistently, by one voice over time or by multiple contributors
- **contested recollection** — remembered differently by different perspectives; both preserved, neither judged
- **unresolved inference** — the machine's working guess, awaiting support or correction

Contextus maintains these standings; it never adjudicates a single canonical truth between differing lived perspectives.

## Projections (views, not entities)

**Timeline / Life Journey** and future **Artifacts** (exports, memory books, Celebration of Life documents, films, the Future Reader's book) are *projections*: composed from the two planes, owning no data of their own. The export required by V1 is the first artifact and proves the pattern.

---

# 3. Service Boundaries

V1 is a **modular monolith**: one deployable, strict internal boundaries. Small team, one product, no scaling pressure — but the module seams are where future services would split, so the seams matter more than the deployment.

| Module | Responsibility | Why it stands alone |
|---|---|---|
| **Arrival & Presence** | Threshold, scenes, transitions, the return experience. | Pure experience; knows nothing of storage or AI. The existing opening code lives here. |
| **Conversation Engine** | Turn-taking and the Companion behaviour contract (CONVERSATION_PRINCIPLES.md); hosts the thought-engine loop (§5) during conversation. | The personality of the product. Must be testable against the Bible in isolation. |
| **Context Engine** | Assembles what the Companion should know right now: relevant Memories, People, Assertions, the conversational past. Contextus's instrument (§5). | Retrieval quality and conversation quality fail differently; separate them and each can be fixed alone. |
| **The Archive** | The only module permitted to write the entrusted plane. Ingestion, versioning, provenance stamping, export, deletion. A module, not a mind — the thought engines use it; none of them is it. | The trust boundary. One narrow door into the sacred plane makes P1 auditable. |
| **Interpretation Engine** | Asynchronous extraction: Memories, People, Places, Events, Themes, embeddings, connections. Writes only the understanding plane. | Runs after the response, can fail without the Storykeeper ever noticing, can be re-run wholesale (P2). |
| **Identity & Continuity** | Person-centric auth (spec §8), sessions, devices, the pre-identity first-memory hold, Book/Contributor structure, dormant Legacy Steward records. | Security-sensitive; changes rarely; must never entangle with conversation logic. |
| **Voice** | STT and TTS behind one interface. | Provider will change (Decision 002 pressure); nothing else may know which provider is speaking. |
| **Language** | Voice packs, culturally authored strings, per-language Lexicon. | Languages are first-class citizens; adding one must touch exactly one module. |

Photo Engine, Timeline Engine, Relationship curation, and Artifact Engine are **not V1 modules**. Photos will join as a new Source type into the Archive; Timeline and Artifacts as new projections; richer relationship reasoning as growth of the Interpretation Engine. None requires a new architecture — that is the test of this design.

---

# 4. Storage Model

**System of record: PostgreSQL.** Boring, durable, transactional (P6).

- **Entrusted plane:** append-only tables in their own schema. The application role has INSERT and SELECT only — no UPDATE, no DELETE. Deletion (the Storykeeper's right, the sole exception) is performed by a separate privileged path with its own audit trail.
- **Understanding plane:** a separate schema. Every row carries provenance (source Moment/Assertion IDs, model identifier, timestamp). The regeneration test from the spec (§15.6) — drop this schema, rebuild, lose nothing — is run routinely, not hoped about.
- **Embeddings:** pgvector, inside the understanding plane. Embeddings are derived data and provider-shaped, so they are regenerable by definition; a model change means re-embedding, never migration pain in the entrusted plane.
- **Relationships/graph:** edges as relational tables with temporal validity (began, changed, as-of). A dedicated graph database is deliberately deferred until real traversal needs prove relational edges insufficient. The living graph is a *model*, not a mandated engine.
- **Media (post-V1):** S3-compatible object storage, content-addressed by hash, immutable blobs; Postgres holds metadata and Source records. Region choice follows the data-residency decision.
- **Backups:** point-in-time recovery; backup retention aligned with the deletion grace period so "irrecoverable" is true, not approximately true.

## Encryption (Director's decision, 2026-07-12)

LifeBook uses **Companion-readable storage** — not end-to-end encryption — with strong encryption at rest and in transit, strict access controls, comprehensive access auditing, and plain-language disclosure to the Storykeeper. LifeBook will never claim end-to-end encryption while retaining server-side Companion access.

Binding principle: **LifeBook may read only what is necessary to provide the service the Storykeeper has asked for, and may never repurpose that access** — not for analytics, not for training, not for anything the Storykeeper did not invite. Architecturally this means: access to entrusted content is mediated through audited service paths scoped to a purpose; there is no general-purpose read path for humans or systems.

---

# 5. AI Architecture — The Thought Engines

Three faculties of one Companion — the Storykeeper experiences one presence; the separation is ours, not theirs. Responsibilities confirmed by the Director (2026-07-12); the committed directive lives at `foundation/directives/thought-engines.md`.

- **Discoverus — discovers.** Identifies the emotional, associative, or curious thread worth following. It notices what has never been asked, senses where a memory wants to go next, and finds the one gentle question (Hypermemory Principle: one memory awakens another).
- **Contextus — retrieves and verifies.** The librarian and the archivist's conscience. It retrieves and verifies relevant material — provenance, support, identity resolution, corroboration, contradiction, perspective, and uncertainty — maintaining the epistemic standings of §2. It retrieves; it does not speak, and it never adjudicates between lived perspectives.
- **Acceptus — integrates and composes.** Determines how verified material should be expressed faithfully for the person, audience, purpose, and moment. **Acceptus composes both conversational replies and future artifacts** (Director's decision): one expressive voice across conversation, memory books, Celebrations of Life, and films — **without ever imposing a narrative**. Fidelity to the Storykeeper's own words and meaning is its discipline. Acceptus *uses* the Archive; it is not the Archive.
- **The Conversation Engine** enforces turn-taking, pacing, safety, and the Conversation Principles. It is Acceptus's stage and disciplinarian — never a separate composer.

**The conversational loop:** the Storykeeper speaks → the Archive preserves the Moment → Contextus recalls and verifies what matters now → Discoverus senses the living thread and the question worth asking → Acceptus composes the response faithfully, under the Conversation Principles → later, asynchronously, the Interpretation Engine deepens the understanding plane for next time.

**The artifact loop (future):** a purpose and audience are declared (an export, a memory book, a Celebration of Life) → Contextus gathers and verifies the relevant material and perspectives → Acceptus composes the expression faithful to the Storykeeper's voice → the result is a projection; the planes remain untouched.

Each faculty is independently replaceable (P5), and every conclusion any of them produces carries provenance. None of them writes the entrusted plane — only the Archive does, and the Archive is a module, not a mind.

---

# 6. Future Scalability

The design bets on one mechanism: **future capabilities are new readers of the past — and new appenders to it — but never rewriters of it.**

The entrusted plane grows: future features may append new entrusted instructions, permissions, perspectives, and material (a sharing consent, a legacy activation, a sister's recollection of the same summer). What is already entrusted is never rewritten. Everything else is regenerable projection. So new capabilities arrive as new interpreters, new projections, and new kinds of entrusted records — not as migrations:

- **Photos** → new Source type + Media into the Archive; the Interpretation Engine learns to look as well as read.
- **Timeline / Life Journey** → a projection over Events and Moments that exist already.
- **Family sharing / Future Reader** → new entrusted permission records over the Book/Contributor structure that exists from day one.
- **Multiple Books** ("my mother as I remember her") → new rows in structures V1 already has (Director's decision, §2).
- **Legacy stewardship** → activation of a designation the identity model already carries, once policy is resolved.
- **Celebration of Life, printed books, films** → Artifact projections composed by Acceptus.
- **New languages** → one module (Language) plus model validation.
- **Better models** → re-run interpretation; the past improves without being touched. LifeBook literally *becomes more valuable with age*.
- **Scale itself** → module seams become service boundaries only if genuinely needed.

What this bet requires in V1: getting the entrusted plane's shape right, and tolerating no shortcuts through the Archive's one door.

---

# 7. Risks — decisions that are hard to reverse

1. **Moment granularity in practice.** The definition and the layered completion model are decided; the residual risk is execution: the grace-period auto-acceptance path (§2) is the one route by which a Moment can be committed without an explicit act. Its timing and visibility must be generous enough that acceptance is genuinely intentional-by-consent, not a timeout wearing a costume. Err toward fewer, larger Moments (the Memory layer can span them; nothing can un-split them).
2. **Purity of the entrusted plane.** The failure mode is quiet: a "cleanup" migration, a well-meant edit feature writing in place, transcript "correction" overwriting the original. One breach and immutability becomes a claim rather than a property. Hence the single door and revoked privileges — but it stays a standing risk under deadline pressure.
3. **Honouring the encryption disclosure.** The decision is made (Companion-readable, plainly disclosed). The residual risk is drift: an analytics need, a debugging session, a future integration quietly widening access beyond "only what the requested service requires." The purpose-scoped, audited access paths in §4 exist to make such drift loud. This discipline must survive every future hire and provider.
4. **Perspective-carrying truth.** The decision that Assertions outrank inference *per account* without becoming universal truth is right — and it commits us to a perspective-relative model that most software never attempts. The risk is lazy implementation collapsing perspectives into one "facts table" because it is easier. Contextus's verification duty must be built perspective-aware from the first schema.
5. **Provider shapes leaking into truth.** Storing model-specific formats (raw provider transcripts, provider message schemas, embedding dimensions) in the entrusted plane welds us to today's vendors. Everything provider-shaped belongs in the understanding plane.
6. **Data residency.** Moving jurisdictions later is a legal and trust event, not a technical one. Choose once, correctly.
7. **Deletion that isn't.** Backups, logs, and provider retention can silently outlive "deletion." Designing true deletion after launch is retrofitting honesty. It ships in V1 or it effectively never does. Deletion semantics now also span Books and Contributors: deleting a Storykeeper's account must be defined against Books they contributed to but do not own (V1 sidesteps this — one owner, no sharing — but the definition should be written before the structure is used).

---

# 8. Questions Requiring Decision Before Implementation

**Resolved by the Director (2026-07-12):** encryption stance; Moment definition; dormant Legacy Steward; account ≠ life subject (Book/Subject/Contributor); Storykeeper Assertions; Companion Turn status; thought-engine responsibilities and composer boundary; epistemic standings; pre-identity structure; layered voice completion ("Keep this"); directive authorship (memory-engine: Claude leads; language-engine: Discovery Partner leads; voice-system: joint; Tracy approves all).

**Still open:**

1. **Source audio retention:** does a finalized voice Moment keep its audio as an entrusted Media original in V1, or transcript-only? Affects storage cost, export shape, deletion semantics, and the voice-system directive. Recommendation to follow in the voice-system draft.
2. **Directive sequence:** `memory-engine.md` is next (Claude leads), after thought-engines.md approval; then `language-engine.md` and `voice-system.md` before schema implementation.
3. **Carried forward from PRODUCT_SPECIFICATION.md §17:** launch languages, authentication technology, AI provider, TTS/STT provider, hosting and residency, retention windows, first Storykeeper, budget envelope. Of these, **hosting/residency and the AI provider block schema implementation** — the schema cannot be deployed nowhere, and provisional capture design touches provider retention terms.
