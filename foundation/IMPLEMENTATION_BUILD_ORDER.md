# IMPLEMENTATION_BUILD_ORDER.md
## LifeBook HQ — Conversation Experience v1
Status: Design — awaiting implementation
Milestone: Conversation Experience v1
Date: 2026-07-27

---

## 1. Governing Principle

No feature is implemented against an unapplied migration.

This is not a process preference — it is an architecture constraint. LifeBook's schema is the single source of truth. Application code written against an undeployed schema is code written against a fiction. When the migration catches up, one of them changes. The right answer is always to make the schema real first.

The schema foundation is currently at M0003 (applied: `20260724153745_types_and_vocabularies.sql`, `20260726083201_predicate_governance_types.sql`, `20260726083202_application_roles.sql`, `20260726083203_core_schema.sql`). The next migration — M0004, covering conversation threading — is designed but not yet authored. Implementation of Conversation Experience v1 does not begin until M0004 is reviewed, authorized, and applied.

---

## 2. What Is Not Decided Here

This document sequences *how to build*, not *what to build*. The what is already decided in:

- `CONVERSATION_STATE_ENGINE.md` — threads, obligations, thread states
- `CONTEXTUAL_UPLOAD_FLOW.md` — upload triggers, inline flow, obligation tracking
- `THREAD_CONTINUATION_MODEL.md` — re-entry language, continuation patterns
- `CONVERSATION_CONTROLS.md` — three controls, one indicator
- `STORY_SEED_FRAMEWORK.md` (this milestone) — seed categories and Orchestrator integration
- `EMOTIONAL_CONVERSATION_MAP.md` (this milestone) — six states and Orchestrator behaviour
- `FOUNDER_ACCEPTANCE_JOURNEY.md` — the end-to-end first experience
- `CONVERSATION_TONE_GUIDE.md` — voice and language rules

This document answers: in what order do these become working software, and why does each phase come before the next?

---

## 3. Pre-Implementation Gate

Before any code is written, the following must be true:

| Gate | Condition |
|---|---|
| M0004 authored | Migration SQL for conversation threading tables is written |
| M0004 reviewed | Discovery Partner has reviewed the SQL — structure, constraints, RLS, seed data |
| M0004 applied | Migration is deployed to the development database |
| M0004 validated | Validation queries (per MIGRATION_PHILOSOPHY.md standards) pass |
| Conversation API spec drafted | Endpoint signatures, request/response shapes, and error contracts are agreed before any API code is written |

No phase in this document may begin until all five gates are cleared.

---

## 4. Phase Sequence

---

### Phase 0 — M0004: Conversation Threading Migration

**What gets built:** The database schema for Conversation Experience v1.

New tables (minimum required; final set determined during M0004 authoring session):

| Table | Purpose |
|---|---|
| `conversation_threads` | Thread record — state, anchor, obligations, summary |
| `conversation_turns` | Individual exchanges within a thread (transient-to-permanent bridge) |
| `thread_obligations` | Structured open promises — upload offers, pending facts, invited contributors |
| `artifact_provenance` | Provenance chain for artifacts: who uploaded, which thread, which agent session |
| `story_seed_log` | Which seeds were offered in which sessions; prevents repetition |

New enum types (added to existing enum infrastructure):

| Enum | Values |
|---|---|
| `thread_state` | `active`, `paused`, `pending_materials`, `complete`, `archived` |
| `obligation_type` | `artifact_upload`, `fact_confirmation`, `contributor_invitation`, `pending_claim` |
| `seed_category` | One value per seed category defined in STORY_SEED_FRAMEWORK.md |

**Why this phase comes first:** Nothing in Conversation Experience v1 can be written against a real schema until these tables exist. The conversation API, the AI Orchestration Layer, and the upload pipeline all write to or read from this schema. Writing them without it means writing against mock structures that will be discarded.

**Dependencies:** M0001–M0003 applied. M0004 SQL not authored until M0003 is confirmed stable.

**Definition of Done:**
- Migration SQL passes MIGRATION_PHILOSOPHY.md strictness requirements: explicit transaction, no `IF NOT EXISTS`, no `ON CONFLICT DO NOTHING`, fails loudly on unexpected state
- All tables exist in the development database with correct column types, constraints, and FK relationships
- All enum types exist and contain the expected values
- RLS policies are in place on tables that carry user-scoped data (at minimum: `conversation_threads`, `thread_obligations`)
- Validation queries confirm table structure, seed counts, and FK integrity
- Discovery Partner has signed off on the applied migration

---

### Phase 1 — Conversation API (Backend Only)

**What gets built:** The HTTP API surface for conversation threading — no UI, no AI, no file storage. Backend only.

Endpoints (as specified in CONVERSATION_STATE_ENGINE.md §8 and CONTEXTUAL_UPLOAD_FLOW.md §4):

```
POST   /api/v1/threads
GET    /api/v1/threads
GET    /api/v1/threads/{id}
PATCH  /api/v1/threads/{id}/state
POST   /api/v1/threads/{id}/obligations
PATCH  /api/v1/threads/{id}/obligations/{obl_id}
POST   /api/v1/threads/{id}/messages
GET    /api/v1/threads/{id}/continuation-prompt
POST   /api/v1/artifacts
GET    /api/v1/artifacts/{id}/upload-url
PATCH  /api/v1/artifacts/{id}
```

This phase also implements:
- Thread state machine logic: valid transitions, guard conditions, side effects
- Obligation lifecycle: creation, fulfillment, decline, follow-up interval enforcement, archiving after `max_followups`
- Thread summary auto-generation (the `thread_summary` field on `conversation_threads`) — text synthesis from structured thread state, not from the verbatim transcript
- Continuation prompt generation: the language patterns in THREAD_CONTINUATION_MODEL.md §3, generated deterministically from thread state and pending obligations

**Why this phase comes before AI:** The AI Orchestration Layer writes to these endpoints. It does not own its own persistence. If the API is not real, the AI layer has nowhere to write. Building the AI without the API produces an AI that talks to mock storage — which means integration testing is deferred to the worst possible moment.

**Why no UI:** The API can be tested fully via direct HTTP calls. Building the UI before the API is stable ensures the UI is built against a moving target.

**Dependencies:** Phase 0 complete. M0004 applied.

**Definition of Done:**
- All listed endpoints return correct responses for happy-path requests (verified via automated tests or curl)
- Thread state transitions enforce guard conditions: e.g., `archived` threads cannot transition to `active` without an explicit reactivation call
- Obligation follow-up logic enforces `max_followups` cap — an obligation that has reached the cap is moved to `archived_obligations` and does not re-surface
- `thread_summary` and `continuation-prompt` return coherent, human-readable text from structured thread state (no hallucination — deterministic generation from state fields)
- RLS is enforced: a user cannot read or modify threads belonging to a different LifeBook
- No AI inference is invoked at any point in this phase

---

### Phase 2 — AI Orchestration Layer (No UI)

**What gets built:** The six AI components that drive the conversation, integrated with the Phase 1 API. No user interface. Testable via scripted inputs.

The six components (per the established architecture):

| Component | Responsibility |
|---|---|
| **Orchestrator** | Session state management, emotional state inference, seed offering logic, thread routing |
| **Context Manager** | Session context assembly — which thread is active, what has been discussed, what is pending |
| **Memory Extractor** | Claim candidate identification from conversation turns — entity recognition, predicate matching, confidence scoring |
| **Claim Generator** | Production of governed claim records with `submission_origin = 'ai_assisted'` and `review_status = 'pending'` |
| **Upload Coordinator** | Upload trigger detection, offer injection, obligation tracking |
| **Invitation Manager** | Family invitation logic — who to invite, what context to share, what thread access to grant |

Implementation decisions:

- **Orchestrator emotional state inference** runs in-memory, session-scoped only. It writes nothing to the database. No state field, no flag, no log entry records the inferred state.
- **Memory Extractor** must be conservative by default. See Risk Register R1.
- **Claim Generator** may only write claims with `submission_origin = 'ai_assisted'` and `review_status = 'pending'`. It may not write claims with any other review status. Promotion is a steward action, not an AI action.
- **Context Manager** must limit what it retrieves to the minimum necessary for the current session. It does not load the full LifeBook on every exchange. Its access is governed by the context manifest pattern in `AI_CONTEXT_BROKER.md`.
- **Seed offering logic** (in the Orchestrator) reads from `story_seed_log` to avoid offering the same category in the same session. It writes to `story_seed_log` when a seed is offered.

**Why this phase comes before upload infrastructure:** The Upload Coordinator identifies upload trigger signals and creates obligations, but it does not need to complete uploads. In this phase, the coordinator produces an obligation record and notes that an upload was offered. Actual file handling — signed URLs, storage, artifact record completion — is Phase 3.

**Dependencies:** Phase 1 complete. AI provider selected (per AI_PROVIDER_EVALUATION.md). Context Broker integration points defined.

**Definition of Done:**
- Given a scripted conversation sequence (no browser, no user), the Orchestrator produces correct thread state transitions, obligation records, and claim candidates
- Claim Generator writes exactly one claim per claimed fact, with `submission_origin = 'ai_assisted'`, `review_status = 'pending'`, and a valid `context_manifest_id`
- A steward can retrieve the pending claim via the existing Claim API and promote it — the promoted claim has `review_status = 'approved'` and is retrievable in the governed record
- Memory Extractor does not produce claim candidates for statements qualified with uncertainty markers ("I think," "maybe," "I'm not sure") unless the predicate semantics explicitly accommodate imprecision (e.g., `born_on` with `precision_status = approximate`)
- Seed offering logic: given a session that has already offered a Smells seed, the Orchestrator does not offer another Smells seed in the same session — a different category is offered
- Orchestrator emotional state: given a scripted exchange where vocabulary signals shift to Emotional markers, the Orchestrator's next question is shorter, the exit offer appears, and no upload prompt is generated — verified against the conversation log, not against any database record

---

### Phase 3 — Upload Pipeline

**What gets built:** The complete artifact lifecycle — from signed URL generation through storage delivery, artifact record creation, source linking, and steward review queue.

Components:

- **Signed URL endpoint:** `GET /api/v1/artifacts/{id}/upload-url` — replaces the current stub (`fn_generate_artifact_signed_url`) with a real implementation backed by the storage provider (per CONTEXTUAL_UPLOAD_FLOW.md §4.2)
- **Upload completion webhook/handler:** receives confirmation from the storage provider that a file has been delivered; transitions the artifact record from `pending` to `received`
- **Artifact-source linking:** creates `artifact_source_links` records connecting the artifact to the relevant narrative, source, or event record
- **Artifact provenance:** populates the `artifact_provenance` table with the thread ID, agent session ID, and user ID at upload time
- **Steward review queue:** a list view (API-only in this phase) of artifacts with `validity_state = pending_review`, available to stewards for acceptance or rejection
- **Obligation fulfillment:** when an upload completes, the corresponding `thread_obligation` record is marked fulfilled

**Why this phase comes before UI:** The upload pipeline has external integration points — a storage provider, webhook callbacks, and signed URL generation. These are the most likely places for unexpected latency, auth complexity, and edge cases. Finding these in a UI-less context (where requests can be made via scripted HTTP calls) is faster and cheaper than finding them inside a browser interaction.

**Why this phase comes after AI Orchestration:** The Upload Coordinator (Phase 2) needs to create obligation records; it does not need to complete uploads. Separating the phases lets Phase 2 be tested against obligation creation without needing the storage pipeline to be real.

**Dependencies:** Phase 1 complete. Storage provider account and credentials available. Artifact tables in M0003 are the schema anchor — no new tables required in this phase (if M0004 includes `artifact_provenance`; otherwise M0004 must include it).

**Definition of Done:**
- A complete upload cycle works end to end: obligation created (Phase 2) → upload URL requested → file delivered to storage → completion confirmed → artifact record updated → obligation marked fulfilled → artifact appears in steward review queue
- The LifeBook server never handles file bytes — the upload goes directly to storage via signed URL
- An artifact that fails upload (timeout, bad file type) results in a correctly set `validity_state`, not a silent failure
- The steward review queue returns the correct set of artifacts (only those belonging to the steward's LifeBook, only those with `validity_state = pending_review`)
- Artifact provenance record exists for every artifact created via the upload pipeline, with correct `thread_id`, `context_manifest_id`, and `uploaded_by_user_id`
- A rejected artifact is not deleted — it is marked with the rejection and remains accessible to the steward for review

---

### Phase 4 — Conversation UI

**What gets built:** The user-facing conversation interface. This is the first phase with a browser.

The UI is thin. The intelligence is in the backend. The UI's responsibilities are:

- Render the conversation thread as a sequence of exchanges
- Submit user input to the conversation API
- Display the AI's response as it arrives (streaming or batched, per provider capability)
- Surface the three controls from CONVERSATION_CONTROLS.md: New topic, Come back later, Add something
- Trigger the upload flow inline when the Upload Coordinator signals that an upload offer should appear
- Show the open threads indicator (count and label, not a full browser)
- Handle session open: detect paused threads, render the continuation offer from the API's `continuation-prompt` endpoint

The UI is not responsible for:
- Any conversation logic — routing, obligation tracking, claim generation
- Any upload logic — signed URL acquisition, file delivery, artifact creation
- Any AI inference — emotional state, seed selection, Memory Extraction

All of these are handled by the backend. The UI consumes the results via API responses.

**Why this phase comes after the backend is complete:** A UI built against a complete, tested API is a UI with defined behaviour at every interaction point. A UI built earlier will require changes every time the API changes, and it will mask backend defects behind UI behaviour until integration testing. The investment in backend-first pays off in this phase.

**Dependencies:** Phases 1–3 complete. Design system and component library decisions made (not scoped here). The conversation API must return a streaming or polling-friendly response for AI turns.

**Definition of Done:**
- A person can start a new conversation, receive an Orchestrator response, submit a reply, and continue for 10 turns without a UI error or an unexpected state transition
- The continuation prompt for a returning user with one paused thread renders correctly using the text from `GET /api/v1/threads/{id}/continuation-prompt`
- The upload flow triggers inline when the Upload Coordinator produces an upload offer — the upload completes without navigating away from the thread
- "Come back later" transitions the thread to `paused` and closes the session — on next open, the continuation prompt appears
- "New topic" transitions the active thread to `paused` and opens a new thread — the open threads indicator increments
- The three controls appear only when relevant and do not dominate the visual hierarchy

---

### Phase 5 — Story Seeds and Emotional Map Integration

**What gets built:** Full integration of the Story Seed Framework and Emotional Conversation Map into the Orchestrator, with live conversation testing.

In Phase 2, the Orchestrator implements seed offering logic and emotional state inference as component behaviours. In this phase, the full seed library from STORY_SEED_FRAMEWORK.md is loaded, the seed selection logic is refined against real conversation data, and the emotional state calibrations in EMOTIONAL_CONVERSATION_MAP.md are validated against live sessions with human participants.

Specific work:

- **Seed library:** All 10 seed categories and their example prompts are loaded as governed content. The Orchestrator's selection logic is tuned against conversation logs from Phase 4 testing.
- **Seed-to-claim mapping:** The Memory Extractor's claim candidate logic is updated to recognize the claim patterns that emerge from each seed category (as defined in STORY_SEED_FRAMEWORK.md §4).
- **Emotional state calibration:** The detection signals in EMOTIONAL_CONVERSATION_MAP.md are validated against actual session data. Thresholds are adjusted based on false-positive and false-negative rates observed in testing.
- **`story_seed_log` logic:** Verify that the session-scoped repetition prevention works correctly across multi-session conversations (same person, different session — different seed history).

**Why this phase comes after UI:** Seeds and emotional state calibration can only be validated in real conversations with real people. Scripted inputs in Phase 2 confirm the logic structure; human conversations in Phase 5 refine it. The sequence is: build the mechanism (Phase 2), build the interface (Phase 4), then tune the behaviour with real data (Phase 5).

**Dependencies:** Phases 1–4 complete. At least one round of internal testing conversations complete. Conversation log access for analysis.

**Definition of Done:**
- In a 10-conversation test set with internal participants, the Orchestrator offers a seed at a natural conversation pause in at least 8 of 10 cases (i.e., not mid-story, not immediately after a difficult disclosure)
- In the same test set, no seed from the same category is offered twice in the same session
- Given a test conversation containing clear Emotional state signals (participant names a loss or difficult memory), the Orchestrator's next 3 turns conform to EMOTIONAL_CONVERSATION_MAP.md §2.4: exit offer included, no upload prompt, no topic pivot
- Seed-to-claim mapping: a conversation seeded with a Recipes prompt produces at least one correct claim candidate from the category list in STORY_SEED_FRAMEWORK.md §4.1, with `review_status = pending`

---

### Phase 6 — Family Invitations

**What gets built:** The contributor invitation flow — creating invitations, sending them, defining what a contributor can see and add, and handling contribution within an existing thread.

Components:

- **Invitation API:** create invitation, retrieve invitation by token, accept invitation, define contributor access (which threads, which access classification)
- **Contributor access model:** a contributor is not a steward. They can add to threads they are invited into; they cannot promote or govern claims; they cannot see restricted material
- **Contribution-to-thread flow:** a contributor accepts an invitation, sees the thread context appropriate to their access level, and adds a turn — their contribution creates claims with `submission_origin = 'contributor'` and `review_status = 'pending'`
- **Thread notification:** a single notification to the steward when a contributor has added material (this is news, not a reminder — per THREAD_CONTINUATION_MODEL.md §5.1's exception)
- **Invitation Manager integration:** the Invitation Manager (Phase 2 component) is connected to the real invitation API

**Why this phase comes after core conversation is working:** Invitations add a second class of user with a different permission model into an already-complex conversation system. Introducing that complexity before the core conversation is stable creates entanglement that is difficult to debug. The invitation flow is built on top of a stable foundation, not alongside it.

**Dependencies:** Phases 1–5 complete. Contributor role permissions defined in the existing RLS model (these are access classification rules on `conversation_threads` and `thread_obligations`).

**Definition of Done:**
- A steward can generate an invitation link for a specific thread
- A contributor follows the invitation link, authenticates, and sees only the thread content their access classification permits
- A contributor submits a turn; the Orchestrator (running as the contributor's session) produces a claim with `submission_origin = 'contributor'`, `review_status = 'pending'`, and the correct `lifebook_id`
- The steward receives a single notification that a contribution was made — no further notifications are sent for the same contribution
- A contributor cannot access threads they were not invited into — RLS enforces this, not application logic alone

---

### Phase 7 — Founder Journey

**What gets built:** The end-to-end first experience for a Founding Member, as specified in `FOUNDER_ACCEPTANCE_JOURNEY.md`.

The Founder Journey is the final integration test of everything built in Phases 1–6. It is not a separate feature — it is the validated experience of using all of them together, as a first-time user, from the first screen to the first complete milestone.

Milestones within the Founder Journey (per FOUNDER_ACCEPTANCE_JOURNEY.md §2):
1. First person record created (entity, person, names, birth claims)
2. First story completed (a narrative anchored to an event or period)
3. First uploaded photograph attached (or a pending obligation recorded for one)
4. First family invitation sent or declined

This phase requires:
- **Onboarding flow:** the first-screen experience, account setup, LifeBook creation
- **Journey state tracking:** the system knows where a Founding Member is in the journey and adapts the Orchestrator's prompts accordingly (e.g., the Orchestrator does not offer a Story Seed before a first person record exists)
- **Acceptance testing:** the complete journey is walked through by a human participant — not a developer — using the actual interface, with no assistance or guidance beyond what the product provides

**Why this phase is last:** The Founder Journey depends on every prior phase working correctly. It is not the first thing built because the Founder Journey without working threads, claims, uploads, and (optionally) invitations is not the Founder Journey — it is a prototype. The Founder Journey is the first fully real experience a founding-cohort participant has. It is validated last because it is the most complete test of the system.

**Dependencies:** Phases 1–6 complete. At least one Founding Member identified and ready to participate in acceptance testing. No developer present during the acceptance test.

**Definition of Done:**
- A Founding Member (not a developer, not a team member) completes all four journey milestones in a single session without requiring assistance
- The person's first person record is a valid entity in the schema with correctly attributed claims (`review_status = pending` where AI-assisted)
- At least one narrative is created and linked to an event or person
- At least one artifact is attached to the story (uploaded) or at least one upload obligation is recorded in `thread_obligations`
- The person's experience of the session — collected via a structured debrief, not an in-product survey — does not reveal any experience of pressure, interrogation, or system confusion
- Discovery Partner signs off: "The system behaves the way we said it would."

---

## 5. Risk Register

---

### R1 — Memory Extractor produces high steward review burden

**Risk:** The Memory Extractor is too aggressive. It produces claim candidates for hedged, uncertain, or conversational statements that should not become governed records. A steward who faces 50 pending claims per session to review will stop reviewing. Claims will pile up in `pending` state and the governed record will not be built.

**Specific failure mode:** A person says "I think my grandfather might have come over around 1910 or so, somewhere in that range." The Memory Extractor produces a claim with `born_on` predicate and value `1910`, `precision_status = approximate`. The claim is technically defensible — but multiplied across thousands of such statements, the steward queue becomes unmanageable.

**Mitigation:**
- During Phase 2, define an explicit confidence threshold below which the Memory Extractor does not produce a claim candidate. Statements with multiple uncertainty markers ("I think," "might," "or so") are below this threshold by default.
- The Memory Extractor may instead produce an obligation of type `pending_claim` — a note that says "we heard something that might be a fact about X; the steward should confirm" — which is lighter-weight than a full pending claim.
- During Phase 5 calibration, measure the ratio of claims promoted to claims rejected or abandoned. If the promotion rate is below 70%, the threshold is too low.

---

### R2 — Conversation threading migration (M0004) reveals a design gap requiring schema revision

**Risk:** When M0004 is authored, a concrete design gap is found — a FK relationship that doesn't work, an enum that is missing values, a table that needs a column that wasn't anticipated. This requires a revision cycle before M0004 can be applied, blocking all implementation phases.

**Specific failure mode:** The `thread_obligations` table is designed to carry a FK to `claims`. But a claim doesn't exist yet when the obligation is first created — it is created after the steward promotes the candidate. The FK cannot be NOT NULL at obligation creation time, but the schema design assumed it could be. The constraint must be revised before SQL can be authored.

**Mitigation:**
- Before M0004 authoring begins, run a design walkthrough of every FK in the new tables against the M0003 schema. Identify all deferred FKs (where the referenced record may not exist at creation time) and specify their constraints explicitly.
- Treat M0004 authoring as a design session, not a transcription session. The document specifies the intent; the authoring session validates the intent against the actual schema.
- Gate: M0004 design walkthrough complete before authoring begins.

---

### R3 — AI provider streaming behaviour is incompatible with the conversation UI's turn model

**Risk:** The Conversation UI is designed around a turn model — user sends, system responds, user sends again. The selected AI provider produces streaming output. If the streaming interface doesn't integrate cleanly with the thread API's `POST /api/v1/threads/{id}/messages` endpoint, the UI will display partial or unstable responses, or the thread record will be written before the response is complete.

**Specific failure mode:** The AI streams its response as a series of tokens. The thread API writes the full turn to `conversation_turns` only on completion. But the UI needs to display the response as it arrives. These two requirements (stream to UI, write on completion) are not conflicting — they require a specific integration pattern (stream to UI, buffer, write after final token) that must be explicitly designed and tested.

**Mitigation:**
- In Phase 1 (API), define the streaming contract explicitly: what the endpoint returns, how streaming is signalled, and when the conversation turn record is written.
- Do not assume a standard SSE or WebSocket pattern without testing it against the specific provider's SDK. The AI provider evaluation (AI_PROVIDER_EVALUATION.md) should include streaming behaviour as an evaluation criterion.
- In Phase 4 (UI), test streaming with a long (1000-token) simulated response before testing with real AI output.

---

### R4 — Emotional state detection misclassifies Excited as Fatigued during debrief-style conversations

**Risk:** The Emotional Conversation Map's detection signals for Fatigued — shortening responses, vague qualifiers, reduced entity density — overlap with signals produced by a person who is wrapping up a topic efficiently. A person who has just finished a complete account and is naturally winding down may be misclassified as Fatigued, prompting the Orchestrator to offer a stopping point when the person intended to continue.

**Specific failure mode:** A person shares a complete, vivid account of an event. Their final few sentences are short confirmations — "Yes, that's right," "That's about it." The Orchestrator reads this as Fatigued and offers to stop. The person is not fatigued; they are complete. The premature stop offer interrupts a natural continuation.

**Mitigation:**
- In Phase 5 calibration, distinguish Fatigued from Completed: Fatigued shows shortening plus reduced specificity plus increased hedging; Completed shows shortening alone after a period of high output.
- The stopping offer from a Fatigued detection should be gentler and more easily declined: "Would you like to take a break, or is there something else?" — not "You've done a lot today, let's stop here."
- Calibrate the Fatigued threshold to require at least 3–4 consecutive short responses, not 1–2, before triggering a stop offer.

---

### R5 — Founder Journey acceptance test fails not because the product is broken but because the first experience is confusing

**Risk:** A Founding Member completes the journey with no technical errors — all records are created correctly — but reports in the debrief that they weren't sure what was being asked of them, or that the AI felt impersonal, or that they didn't know how to stop. The product works but the experience doesn't.

**Specific failure mode:** The first screen says "Tell me about yourself." But the Founding Member is creating a LifeBook for their mother, not themselves. They don't know how to correct the frame. They spend the first five minutes talking about themselves before realising the system didn't understand their intent. The records created in those five minutes are attached to the wrong entity.

**Mitigation:**
- Before the acceptance test: walk one internal team member through the full journey, role-playing as a Founding Member with no product knowledge. Identify every moment of ambiguity and address it.
- The Orchestrator must handle the "this is for someone else" signal in the first exchange — as illustrated in FOUNDER_ACCEPTANCE_JOURNEY.md §3 Step 1. This must be explicitly tested in Phase 2 scripted inputs.
- After the acceptance test: structured debrief within 24 hours, specific questions, no leading prompts. The debrief is the test; the session is the data.
- If the acceptance test reveals experience failures that require product changes, those changes are made and the acceptance test is repeated. There is no partial pass.

---

*IMPLEMENTATION_BUILD_ORDER.md — LifeBook HQ — Conversation Experience v1 — 2026-07-27*
