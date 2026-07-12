# LifeBook Product Specification — Version 1

Status: APPROVED DRAFT — living document, evolves with the Foundation
Last updated: 2026-07-12
Governing documents: PRODUCT_CONSTITUTION.md, DIRECTORS_BIBLE.md, CONVERSATION_PRINCIPLES.md, DECISIONS.md

This document bridges philosophy and implementation. Where the Foundation describes what LifeBook must feel like, this specification describes what Version 1 must verifiably do. Anything not listed in MVP Scope is out of scope for V1, no matter how aligned with the long-term vision.

---

# 1. Product Definition

LifeBook V1 is a private, person-centric web experience in which a Storykeeper crosses a threshold, shares memories in conversation with a Companion that genuinely listens, and returns days or months later to find those memories safely kept — on any device.

V1 exists to prove one thing: **that a person will entrust a memory to LifeBook, feel heard, and come back.**

---

# 2. Initial Target Storykeeper

**LifeBook is optimized for Storykeepers who value conversation over technology.**

The product is not defined by age. The initial *commercial beachhead*, however, is expected to be older adults with family who have stories no one has written down — often introduced to LifeBook by an adult child or grandchild. Beachhead characteristics that constrain V1 design:

- may not be comfortable with technology; must never be made to feel incapable
- may prefer speaking to typing
- may use a shared computer, a tablet, or a phone interchangeably (Decision 008)
- may think in one language and speak another
- has no interest in "apps"; has deep interest in being understood

The younger family member who sets LifeBook up for them is a secondary audience but **not** a V1 user with their own experience. V1 serves one Storykeeper at a time.

---

# 3. Core Problem

When people die, their memories die undocumented — not because they didn't matter, but because every existing tool demands that they become a storyteller: write a memoir, fill in a form, organize an archive. Most people never begin.

LifeBook removes the demand. It asks only that a person remember, one moment at a time, in conversation.

---

# 4. First Shippable Experience

The complete V1 loop:

1. **Begin** — the threshold: darkness, the word "Begin" in the Storykeeper's language, the arrival voice.
2. **First conversation** — "What's on your mind today?" The Storykeeper speaks or types. The Companion acknowledges *what was actually said* and asks one gentle question.
3. **The memory is kept** — the original words are preserved permanently, in their original language, without the Storykeeper doing anything.
4. **Coming home** — the Storykeeper returns (any device, any day) and is recognized. The Companion can naturally weave a prior memory into conversation ("Last time you mentioned your granddaughter…").
5. **The story is theirs** — at any time, the Storykeeper can receive everything they have entrusted, in a readable form, and can leave with it.

If all five steps work and feel like the Director's Bible, V1 ships. Nothing else gates it.

---

# 5. MVP Scope (explicit)

- Person-centric accounts with cross-device continuity
- Text and voice input, seamlessly interchangeable, transcript always editable
- A model-driven Companion governed by CONVERSATION_PRINCIPLES.md
- Spoken Companion voice meeting the Decision 002 standard ("must feel like family")
- Immutable storage of every original memory (the Moment record)
- A separate, regenerable AI-interpretation layer (summary, people, places mentioned)
- Natural memory recall by the Companion in later conversations
- Two launch languages, culturally authored (proposed: English and Ukrainian — open decision)
- Full export (human-readable + machine-readable)
- True deletion on request, with a recovery grace period
- Accessibility: WCAG 2.1 AA, reduced-motion support, screen-reader support, low cognitive load
- The threshold and return experience per the arrival-experience directive

# 6. Explicit Exclusions (V1 will NOT include)

- Photographs, documents, or media of any kind (photo-engine deferred)
- Timeline / Life Journey visualization
- Family sharing, invitations, or the Future Reader experience
- Relationship engine automation beyond simple entity extraction
- Themes engine
- Patina
- Celebration of Life outputs
- Social-impact aggregation
- Native mobile apps (responsive web only)
- Monetization, pricing, or subscription mechanics
- More than two languages
- Search/"Remember" as a Storykeeper-facing feature (recall happens through the Companion only)

These exclusions are deliberate. Each is philosophically core to LifeBook and each is deferred anyway, because V1 proves trust, not breadth.

---

# 7. Storykeeper Journey: Begin → Return

**First visit.** Threshold (darkness, "Begin," arrival voice in detected language; language selectable) → first thought → Companion acknowledgment + one question → conversation continues at the Storykeeper's pace → the Storykeeper simply stops when done; nothing demands a "save" or "logout." Before the first conversation ends, LifeBook gently invites the Storykeeper to establish identity so their story can find them again — framed as safekeeping, never as registration ("How do Storykeepers begin?" not "How do users register?").

**Identity moment.** Establishing identity must feel like safekeeping, not registration — a single gentle step that afterward brings the Storykeeper home on any device. (Mechanism to be determined; see §8.)

**Return visit.** No threshold ceremony repetition — returning should feel like *coming home*, quieter and warmer than arrival. The Companion greets naturally, may weave one prior memory in, and asks what's on their mind. The thousandth return matters more than the first.

**Leaving.** Export and deletion are reachable without hunting, phrased in Lexicon language, and never guilt the Storykeeper.

---

# 8. Person-Centric Identity and Cross-Device Continuity

- Identity is the person, never the device or browser (Decision 008).
- **Person-centric authentication. Implementation to be determined.** The specification does not commit to one authentication technology. Whatever is chosen must satisfy: no passwords to forget, works for a Storykeeper who is uncomfortable with technology, works across shared and personal devices, and preserves dignity throughout. Passwordless email links and passkeys are current candidates.
- Sessions are long-lived on personal devices; a clear, gentle "this isn't my device" path exists for shared computers (library, church).
- Everything the Storykeeper entrusts lives server-side. Browser storage may hold only ephemeral drafts and preferences, and any draft must survive by syncing once identity exists.
- The pre-identity gap: the very first thought is shared *before* an email exists. It must be held server-side against an anonymous session and permanently attached to the account the moment identity is established. **The first memory is never lost.** If the Storykeeper never provides an email and the anonymous session expires, the unclaimed memory is deleted after a defined period (proposed: 30 days) — we do not keep what was not entrusted.

# 9. Immutable Original Memory Storage

- The fundamental record is the **Moment**: the Storykeeper's original words, exactly as submitted, in the original language.
- Moments are **append-only**. Nothing updates or overwrites an original. An edit by the Storykeeper creates a new version linked to the original; the original remains.
- Companion turns are stored alongside, clearly attributed, so the conversation's meaning is preserved — but the Storykeeper's words and the Companion's words are never mingled in one record.
- Deletion is the sole exception to immutability: the Storykeeper's right to delete overrides preservation, always.

# 10. AI-Derived Interpretation Layer (separate)

- Everything the AI produces *about* a Moment — summaries, detected people, places, emotional tone, connections — lives in a distinct layer, physically separate from originals.
- Every interpretation is traceable to its source Moments (provenance).
- The entire interpretation layer is **regenerable**: it can be deleted and rebuilt from originals without loss of any entrusted material. This is the test of correct separation.
- Interpretations are never presented to the Storykeeper as fact. The Companion never invents a memory.

# 11. Memory, History, and Provenance Requirements

Every Moment records: timestamp, input mode (voice or text), original language, and the conversation it belongs to. Every interpretation records: which model produced it, when, and from which Moments. Every account records identity events (created, signed in, exported, deletion requested) — for the Storykeeper's benefit, not surveillance; this history is visible to them and to no one else.

---

# 12. Companion Behaviour

The Companion is model-driven in V1 — the scripted placeholder is retired. Its behaviour contract:

- CONVERSATION_PRINCIPLES.md is implemented as the Companion's standing instructions: listen first, acknowledge before responding, one question at a time, reflection before advice, gentle language, respect silence, leave space.
- It **must demonstrably respond to the content of what was said.** A reply that could have been generated without reading the Storykeeper's words is a defect.
- It weaves memory naturally ("Last time you mentioned…"), never announces it ("According to my memory…").
- It never: invents memories, diagnoses, lectures, flatters for engagement, pressures for more input, or presents assumptions as truth.
- The Compassion Principle: repeated difficult concerns may be gently acknowledged, resources offered only by invitation, declines accepted permanently.
- LifeBook V1 is not a crisis-response system and does not define itself as one (Director's decision, 2026-07-12). The Companion is compassionate, respectful, and safe; it never dismisses or ignores expressed distress, and it never diagnoses or counsels. The question of a formal crisis protocol is deferred and will be revisited before LifeBook is offered beyond a trusted circle.
- The Companion has no name and no fictional backstory in V1. It never claims to be human.

# 13. Language Requirements

- Two culturally authored launch languages (proposed: English and Ukrainian — chosen because the team can natively verify both; **open decision**).
- Every Storykeeper-facing string is authored per language, never mechanically translated (Decision 004). The existing voice-pack architecture continues.
- The Companion converses in the Storykeeper's language at native quality; the model must be validated for both launch languages before launch.
- Moments always preserve their original language. If the Storykeeper switches languages mid-conversation, each Moment keeps its own.
- The Lexicon applies in every language — each language needs its own authored equivalent of "Storykeeper," "Moment," "Companion."

# 14. Data Ownership, Export, Privacy, and Recovery

- The Storykeeper owns their story. LifeBook is steward, never owner.
- **Export:** available at any time, self-serve: a human-readable document of all Moments and conversations, plus a machine-readable archive (JSON) including provenance. No lock-in, no friction, no guilt.
- **Privacy:** private by default; no sharing exists in V1, so nothing can leak by design. Stories are never used to train models, never sold, never used for advertising. Third-party AI providers must be contractually barred from retaining or training on Storykeeper content — **provider choice is an open decision partly for this reason.**
- **Deletion:** real deletion of all originals and interpretations, with a grace period (proposed: 30 days) during which the Storykeeper can change their mind; then irrecoverable.
- **Recovery:** account recovery via email. Loss of email access is handled by a human process in V1 (we are small; dignity over automation).
- **Data residency:** proposed Canadian hosting, PIPEDA-compliant from day one. **Open decision.**

---

# 15. Acceptance Criteria

V1 is done only when all of the following pass, plus both Review Protocol gates (TEAM_CHARTER.md):

1. A first-time Storykeeper can go from "Begin" to a completed first conversation using only voice, and only text, on desktop and phone.
2. The first thought — shared before any account exists — is retrievable after account creation, verbatim, on a different device.
3. Closing the tab mid-conversation loses nothing that was submitted.
4. The Companion's first reply demonstrably references the content of the Storykeeper's thought.
5. In a returning conversation, the Companion can naturally reference a Moment from a previous conversation, without announcing that it is doing so.
6. Deleting the interpretation layer entirely and regenerating it produces no loss of any original Moment (immutability/separation test).
7. Export contains every Moment, verbatim, in original language, in both human- and machine-readable form.
8. Deletion request → grace period → verified irrecoverable removal.
9. Both languages pass native-speaker review of every string and of Companion conversation quality ("This was made for me," not "This was translated").
10. WCAG 2.1 AA audit passes; full experience works with a screen reader and with reduced motion.
11. The spoken voice in both languages passes the Decision 002 test with real listeners: it feels like family, not like a robot.
12. A trusted first Storykeeper (proposed: within Tracy's own family) completes two real conversations on different days and reports feeling heard — the Final Test, measured on a real person.

# 16. Known Architectural Decisions

- **AD-1** Next.js/React/Tailwind stays for V1. No rewrite; the foundation demands calm, not novelty.
- **AD-2** Server-side persistence in a relational database (PostgreSQL), schema shaped for the living graph: Moments, People, Places as entities with provenance-carrying edges. A dedicated graph database is deliberately deferred.
- **AD-3** Originals and interpretations are separated at the schema level, not by convention.
- **AD-4** All AI capabilities (conversation, extraction, speech) sit behind internal abstraction layers. Models will change; LifeBook must not care (First Principle 10).
- **AD-5** Browser `speechSynthesis` is retired for the Companion voice; a professional TTS provider is required to meet Decision 002. Speech-to-text likewise goes through the abstraction layer.
- **AD-6** Person-centric identity with server-side persistence is committed; the authentication technology is deliberately not (§8).
- **AD-7** The Lexicon governs identifiers in Storykeeper-facing code and copy (e.g., `moment`, `companion`, `storykeeper`) so the codebase cannot drift from the philosophy.

# 17. Open Decisions Requiring Tracy's Approval

1. **Launch languages** (§13) — English + Ukrainian proposed.
2. **Authentication technology** (§8) — candidates: passwordless email links, passkeys.
3. **AI conversation provider(s)** — with no-training/no-retention contractual terms; Claude notes its own conflict of interest in recommending a model vendor and defers this recommendation to a neutral evaluation Tracy directs.
4. **TTS/STT provider** — must pass the "feels like family" test in both launch languages.
5. **Hosting and data residency** — Canadian residency proposed.
6. **Unclaimed-memory retention window** (§8) and **deletion grace period** (§14) — 30 days proposed for both.
7. **First real Storykeeper** for acceptance criterion 15.12.
8. **Budget envelope** for providers (AI, TTS, hosting) — the foundation is silent on money; V1 cannot be specified into existence without it.

Resolved by the Director on 2026-07-12: target Storykeeper is defined by disposition, not age (§2); V1 is not a crisis-response system, formal protocol deferred (§12); Foundation consolidation intentionally deferred during the discovery period (§18).

---

# 18. Governance and Document Authority

The Foundation currently overlaps: PRODUCT_CONSTITUTION.md, FIRST_PRINCIPLES.md, and DIRECTORS_BIBLE.md restate each other substantially. Until Tracy consolidates them, the following authority map governs. **This section assigns authority; it does not rewrite any document.**

| Decision category | Governing document | Notes |
|---|---|---|
| Purpose, mission, values, red lines ("never do") | PRODUCT_CONSTITUTION.md | The constitution; others elaborate it |
| Tie-breaking between principles | FIRST_PRINCIPLES.md | Shortest, most fundamental; when two documents disagree, the First Principle wins |
| Experience, emotion, tone, sound, voice, "Does this sound like us?" | DIRECTORS_BIBLE.md | The most detailed authority on how anything should feel |
| Companion conversational behaviour | CONVERSATION_PRINCIPLES.md | Implemented directly as Companion instructions |
| Visual and interaction design | DESIGN_PRINCIPLES.md | |
| Naming and vocabulary | LEXICON.md | Binding on code identifiers and all copy |
| Data model direction | ARCHITECTURE_VISION.md | Direction, not specification; this document specifies |
| Ratified choices and their reasoning | DECISIONS.md | Binding record; conflicts with it require a new decision, not a workaround |
| Review-time questions | FOUNDATIONAL_QUESTIONS.md | Checklist, not authority |
| Branding | BRAND_EXPLORATION.md | Explicitly non-binding; "LifeBook" remains a working title |
| Team roles and protocol | TEAM_CHARTER.md | |
| V1 scope and acceptance | PRODUCT_SPECIFICATION.md (this document) | Subordinate to all of the above; where this spec contradicts the Foundation, the Foundation wins and the spec must be amended |

On consolidation of the three overlapping philosophy documents: the Director has intentionally deferred this during the discovery period — duplication is tolerated rather than compressing ideas before they mature. The governance table above manages conflicts in the meantime. Consolidation will happen; not yet.
