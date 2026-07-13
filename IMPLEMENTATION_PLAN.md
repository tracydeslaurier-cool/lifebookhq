# Implementation Plan — The First Trust Loop

Status: PLAN — awaiting Tracy's approval. No code has been written.
Last updated: 2026-07-12
Governed by: foundation/ARCHITECTURE.md, foundation/PRODUCT_SPECIFICATION.md, foundation/DECISIONS.md

**Objective:** the smallest vertical slice proving the complete trust loop — Begin → anonymous conversation → one memory preserved permanently → leave → return (any device) → the Companion remembers naturally → continuity. Nothing else.

**Slice constraints (assumptions, flagged for the Director):**

- **Text input only.** The layered voice completion model ("Keep this") is the *next* slice; it depends on the voice-system directive. The trust loop is about continuity, not modality.
- **Existing browser speech output is temporarily retained** for the arrival lines. Provider TTS (AD-5) is a parallel evaluation track, not a slice dependency.
- **English only.** The Language module seam is preserved; the second language joins when language-engine.md is approved.
- **Email sign-in links are used as the slice's identity mechanism** behind the neutral Identity module interface, while the authentication decision remains officially open (spec §17.2). If passkeys win later, one module changes.
- Deletion self-service UI is not in this slice, but the *schema privileges* that make deletion a separate, audited, privileged path ship from day one — they cannot be retrofitted.

---

# 1. Database Schema

PostgreSQL, three schemas expressing the planes. The application role has INSERT/SELECT only on `entrusted`; no UPDATE anywhere in `entrusted`; DELETE exists only via a separate privileged role with audit. No speculative entities — every table below is exercised by the eight steps.

## Schema `identity`

```
storykeeper        (id, created_at)
credential         (id, storykeeper_id, kind, value_hash, verified_at)
                   -- kind = 'email' in this slice; table is method-neutral
signin_token       (id, credential_or_email, token_hash, expires_at, used_at)
                   -- single-use, short-lived; pre-storykeeper (first claim) or re-entry
session            (id, storykeeper_id NULLABLE, created_at, last_seen_at, expires_at)
                   -- NULL storykeeper_id = anonymous session (Decision: no fictional identity)
book               (id, created_at)
contributor        (id, book_id, storykeeper_id NULLABLE, role, created_at)
                   -- NULL storykeeper_id = the anonymous Contributor
book_claim         (id, book_id, storykeeper_id, claimed_at)
                   -- claiming is an INSERT — a new fact, never a rewrite
                   -- absence of claim + book.created_at drives the 30-day unclaimed expiry
```

Decision 012 (account ≠ life) is honoured by `book`/`contributor` existing as real tables. Subject and Legacy Steward columns/tables are **not** created in this slice — they are additive later precisely because the structure exists.

## Schema `entrusted` (append-only)

```
conversation       (id, book_id, contributor_id, began_at, language)
moment             (id, conversation_id, contributor_id, seq, submitted_at,
                    original_text, original_language, input_mode,
                    source_kind DEFAULT 'conversation',
                    supersedes_moment_id NULLABLE)
                   -- supersedes: a Storykeeper edit is a new row beside the original
companion_turn     (id, conversation_id, seq, spoken_at, text, language, model_id)
```

`source_kind` is a column, not a Source table — one value exists in this slice; the table arrives with the second source type (imports/media). Provenance for entrusted rows is intrinsic (who, when, where, how).

## Schema `provisional`

```
draft_contribution (id, conversation_id, text, updated_at, expires_at)
                   -- server-side draft; survives tab close (spec §15.3); promoted
                   -- atomically to one moment on submission, then deleted
```

## Deliberately absent

No understanding-plane tables in this slice. With one Storykeeper and a handful of conversations, Contextus retrieves by **loading the Book's entrusted record directly** into context — no embeddings, no Memory extraction. This is not a shortcut; it is the smallest correct Contextus. pgvector and the Interpretation Engine join when volume demands selection, and by P2 they can be added without touching anything above.

## Audit

```
audit.access_event   (actor, purpose, scope, at)      -- Decision 010 discipline
audit.deletion_event (what, requested_by, executed_at) -- the privileged path's trail
```

---

# 2. API Design

Next.js route handlers; JSON; httpOnly secure session cookie (anonymous sessions included). All Storykeeper-facing language in responses follows the Lexicon.

## Conversation

**`POST /api/conversation`** — begin (anonymous permitted).
Creates (if needed): anonymous session → unclaimed `book` → anonymous `contributor` → `conversation`.
→ `201 { conversationId, language }`

**`POST /api/conversation/:id/moment`** — the Archive's one door.
Body: `{ text, inputMode: "text" }`
Promotes any draft, inserts the `moment`, runs the thought-engine loop, inserts the `companion_turn`.
→ `200 { momentId, companion: { text } }` — streamed (SSE) so first words arrive quickly (P7).

**`PUT /api/conversation/:id/draft`** — provisional autosave (debounced).
→ `204`

**`GET /api/conversation/:id`** — transcript for resume (session must own the book).

## Identity (anonymous → identified)

**`POST /api/identity/begin`** — Body: `{ email }`.
Issues single-use `signin_token` (15-minute expiry), sends the sign-in email. Always `202` (no account enumeration).

**`POST /api/identity/complete`** — Body: `{ token }`.
First time: creates `storykeeper` + verified `credential`; **claims the session's unclaimed book via `book_claim` INSERT** — no entrusted row is touched. Returning: binds a fresh long-lived session to the existing storykeeper, on whatever device the link was opened.
→ `200 { returning: boolean }`

Cross-device continuity is this endpoint working from any device: the link *is* the doorway (Decision 008).

**`POST /api/identity/depart`** — end session on a shared device ("this isn't my device").

## Coming home

**`GET /api/home`** — the return payload.
Identified session → `{ recognized: true, greeting }` where the greeting is composed by the thought-engine loop over the Book's record — the Companion may weave one earlier memory, naturally, per CONVERSATION_PRINCIPLES.md ("Last time you mentioned…", never "According to my memory…"). Anonymous → `{ recognized: false }` and the threshold plays.

## Contract rules

- No endpoint ever updates or deletes an `entrusted` row; there is no such route to misuse.
- Every companion composition logs an `audit.access_event` with purpose `conversation` or `homecoming`.
- Errors speak Lexicon ("We couldn't reach your story just now") — never stack traces or jargon.

---

# 3. Module Implementation Order

Each module is built to its seam, even where the slice's internals are simple.

1. **Identity & Continuity** — sessions (anonymous first), storykeeper/book/contributor/claim, the expiry job for unclaimed books. *First because every other module needs to know who is speaking and which Book is open — and because anonymous-first identity is the slice's riskiest novelty.*
2. **The Archive** — the one door: moment/companion-turn writes, draft promotion, privilege enforcement, audit. *Second because the trust boundary must exist before anything can be entrusted; the Conversation Engine is built against it, not before it.*
3. **Conversation Engine + thought-engine loop v0** — Contextus (load the Book), Discoverus/Acceptus (disciplined composition per the directive; single model invocation in v0, which the directive deliberately permits), behaviour contract from CONVERSATION_PRINCIPLES.md, streaming. *The personality, built on preserved ground.*
4. **Arrival & Presence integration** — wire the existing threshold/opening experience to the real backend: drafts server-side, moments through the Archive, replies from the Engine; retire `sessionStorage`-as-memory; build the return experience (the quieter homecoming, `GET /api/home`).
5. **Identity claim flow UI** — the gentle in-conversation invitation ("so your story can find you again"), the email, the completion on any device.
6. **Continuity polish** — homecoming greeting quality, memory weaving, "this isn't my device," unclaimed-expiry verification.

Voice and Language modules: touched only at their seams (existing packs keep working; no new capability).

---

# 4. Technical Risks

1. **Model latency vs the calm (P7).** A Companion that answers in 12 seconds breaks presence. Mitigations: streaming from the first token, composed pacing in the UI (the pause can *feel* intentional up to a point), provider choice partly judged on latency. If latency proves incompatible with calm, the scene design must absorb it — that's a design negotiation, not a retrofit, so it's tested in Week 2, not Week 5.
2. **Email deliverability.** For the beachhead Storykeeper, a sign-in link in the spam folder is not an inconvenience — it is "LifeBook lost my story." Sender domain, SPF/DKIM/DMARC, and a reputable transactional sender must be set up in Week 1, and the failure mode (link never arrives) needs a humane path.
3. **Provider terms before real memories.** Until no-training/no-retention terms are signed with the AI provider, all testing uses synthetic memories. If contracting drags, this gates the Week 4/5 real-person test — flagging now.
4. **Hosting/residency is on the critical path.** The schema deploys nowhere until decided (spec §17.5). Needed before Week 1 ends.
5. **"Remembers naturally" is a quality bar, not a feature flag.** Acceptance (spec §15.5) needs the weaving to feel like family, not like a database join. This is prompt-and-evaluation work with the Discovery Partner; schedule risk if treated as an afterthought.
6. **The unclaimed-expiry job deletes entrusted data.** It is the first user of the privileged deletion path; a bug here either deletes claimed stories (catastrophic) or never deletes (dishonest). Built with the same care as the Archive itself, with audit and dry-run modes.
7. **Prompt injection via Moments.** Storykeeper text enters model context. Low stakes in this slice (no tools, no other users), but the boundary between "the Storykeeper's words" and "instructions" is designed now, cheaply, rather than after tools exist.
8. **Redesign-forcing candidates:** moment versioning shape (`supersedes` — locked by immutability once real data exists); session/cookie strategy vs shared computers; SSE vs alternatives for streaming. All three are decided in Weeks 1–2 deliberately, not by drift.

---

# 5. Development Milestones

Each ends in a demonstrable capability — something Tracy can experience, not a code report.

**Week 0 (decision gate, days not weeks):** hosting/residency and AI provider chosen; sender domain configured; provider terms in motion.

**Week 1 — "The story survives the tab."**
Hosted Postgres with the three-schema privilege model (UPDATE on `entrusted` provably impossible); anonymous session → unclaimed Book → conversation; server-side drafts.
*Demo: begin anonymously, type half a thought, kill the tab, reopen — the conversation and draft are exactly where they were. Attempt an UPDATE on a moment as the app role; watch the database refuse.*

**Week 2 — "The Companion listens."**
The Archive's door; thought-engine loop v0 streaming real replies under the Conversation Principles.
*Demo: share a memory; the reply demonstrably responds to what was said (spec §15.4), arrives with calm pacing, asks one question. The scripted `respond.ts` placeholder is retired.*

**Week 3 — "The story finds you."**
Identity begin/complete; claiming; cross-device.
*Demo: converse anonymously on the laptop, give an email, open the link on a phone — the same story, verbatim, on the second device (spec §15.2). Sign out on a "library computer"; nothing lingers.*

**Week 4 — "Coming home."**
Return experience; natural memory weaving; the full eight steps.
*Demo: the complete trust loop across two devices and two days — the Companion greets the returning Storykeeper and weaves the granddaughter from Tuesday into Thursday's conversation without announcing it (spec §15.5).*

**Week 5 — "Worthy of trust."**
Unclaimed expiry live (audited, dry-run first); provisional expiry; access auditing verified; accessibility pass over the loop (keyboard, screen reader, reduced motion); synthetic-data soak; then both Charter gates: technical review, and "Does this sound like us?" with Tracy and the Discovery Partner.
*Demo: the loop passes both gates, and a first trusted Storykeeper is invited to try it — the real acceptance test.*

Sequencing after this slice (not planned here): layered voice completion (voice-system.md), second language (language-engine.md), Interpretation Engine + understanding plane (memory-engine.md), export and deletion self-service — each a new slice over the same unchanged foundation.

---

# 6. Success Metrics

Not analytics. Experience. (Constitution: "We measure meaningful moments, not engagement.")

## Implementation philosophy (Director, 2026-07-12)

**Persistence preserves information. Continuity preserves relationships.** LifeBook is not trying to prove that data survived; it is trying to make the Storykeeper feel the conversation never really stopped. Every implementation choice in this plan is judged against continuity, with persistence merely its precondition.

**The number serves the observation, never the reverse.** Metrics exist to illuminate people, not to optimize them. We measure trust to understand whether we are becoming worthy of it — never to manipulate behaviour. This is engineering culture, binding on all future instrumentation decisions.

*(Candidates for elevation into FIRST_PRINCIPLES.md — Discovery Partner and Director to decide.)*

## Technical — verified by test, binary, no judgment required

- ✓ A Moment survives browser restart, crash, and tab close — including a draft mid-thought.
- ✓ Cross-device continuity works: the same story, verbatim, on a second device after claiming.
- ✓ No UPDATE is possible on entrusted records — proven by the database refusing, not by code review.
- ✓ The unclaimed Book expires on schedule; a claimed Book provably never does.
- ✓ The Companion's first words begin within **3 seconds** of submission (streamed), and the complete reply within **10** — beyond that, silence stops feeling intentional and starts feeling broken. (Thresholds are proposals; the real bar is the experience metric below.)
- ✓ Every access to entrusted content appears in the audit log with a purpose.

## Experience — observed with a real person, small numbers, honest answers

These are measured the only way LifeBook may measure anything: by sitting with a trusted first Storykeeper, with their knowledge, and by asking — never by instrumenting their behaviour behind their back.

- ✓ The Storykeeper smiles — during the conversation, unprompted. (The Foundational Question, applied literally.)
- ✓ The Storykeeper reports feeling heard, in their own words, when asked afterward — not prompted with a rating scale.
- ✓ The Storykeeper voluntarily returns — without a reminder, notification, or invitation from us. One unprompted return is worth more than any retention curve.
- ✓ **Time to First Trust decreases.** Working definition: the time from "Begin" until the Storykeeper first shares something they didn't have to — something personal rather than procedural. Each revision of the experience should shorten it. Measured by observation and the Storykeeper's own account, not by classifying their words with a machine.
- ✓ **Time to First Homecoming (TTFH).** The elapsed time between a Storykeeper's first entrusted Moment and their first voluntary return to continue their story — unprompted by any reminder or notification, because LifeBook sends none. Known from two timestamps we already hold; no instrumentation added.
  Positive indicators: the Storykeeper returns to *continue* — picking up a thread, adding to a memory, answering a question that stayed with them — rather than to check on their data; they mention having thought about the conversation in between; the return conversation begins more easily than the first (trust carrying over, not restarting).
  Negative indicators: the return happens only when a family member sits them down again; they return but begin from zero, re-explaining themselves as if meeting a stranger (continuity failed even though persistence worked); they return only to verify the memory is still there — that is checking on a deposit, not coming home. A short TTFH with negative indicators is worth less than a long TTFH with positive ones; the number serves the observation, never the reverse.
- ✓ Returning feels like coming home — the Storykeeper's description of their return, in their words, sounds like recognition ("it remembered me," "it was waiting") rather than resumption ("I logged back in").
- ✓ The Storykeeper never asks "did it save?" — the question itself would mean trust hasn't formed.
- ✗ Fail conditions, recorded as seriously as the passes: the Storykeeper apologizes to the software, asks permission, hesitates because they feel incapable (Director's Bible: that is failure), or performs for the machine instead of remembering for themselves.

Pass/fail on the experience metrics is judged at the Week 5 gate by Tracy and the Discovery Partner — not by Claude, who will be too close to the machinery to hear its tone.
