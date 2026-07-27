# CONVERSATION_STATE_ENGINE.md
## LifeBook HQ — Conversation Experience v1
**Status:** Design — awaiting implementation  
**Milestone:** Conversation Experience v1  
**Date:** 2026-07-27  
**Companion documents:** CONVERSATION_TONE_GUIDE.md, THREAD_CONTINUATION_MODEL.md, CONTEXTUAL_UPLOAD_FLOW.md

---

## 1. Core Premise

A LifeBook conversation is not a session. It is a **thread**.

A session ends when the browser closes. A thread persists for as long as the story is incomplete — which may be days, weeks, or never. Two people may contribute to the same thread at different times. An upload may arrive three weeks after the conversation that prompted it. A memory shared by a grandparent may be continued by their child after the grandparent is gone.

The Conversation State Engine (CSE) treats each thread as a living, governed record — not a transcript to be searched, but a context to be resumed.

---

## 2. What Is a Thread?

A **ConversationThread** is a named, bounded context anchored to one or more of the following:

- A specific **person** (e.g., "Grandma Iryna")
- A specific **event** or time period (e.g., "Wedding Day 1983")
- A specific **claim cluster** (e.g., military service, immigration)
- A **free-form topic** when no structured anchor exists yet

A thread is created the first time a user meaningfully engages with a topic. It is never deleted — only archived. Threads accumulate references to claims, narratives, artifacts, and pending obligations over their lifetime.

### 2.1 Thread Record

```
ConversationThread {
  id                    UUID
  lifebook_id           UUID
  created_by_id         UUID (user)
  created_at            TIMESTAMPTZ
  topic_label           TEXT        -- human-readable, user-editable
  anchor_entity_id      UUID?       -- optional: a specific entity this thread is about
  anchor_event_id       UUID?       -- optional: a specific event
  state                 ThreadState
  last_activity_at      TIMESTAMPTZ
  dormant_since         TIMESTAMPTZ?
  context_manifest_id   UUID?       -- links to agent session context
  pending_obligations   JSONB       -- list of open promises/pending items
  thread_summary        TEXT?       -- auto-generated digest for continuation prompts
}
```

### 2.2 Thread States

```
ThreadState:
  active              -- conversation is live or recently touched
  paused              -- user explicitly paused; expect return
  pending_materials   -- waiting on uploads, invitees, or external input
  complete            -- user or system has marked the topic resolved
  archived            -- dormant beyond the retention threshold; preserved but not surfaced
```

State transitions:

```
active ──────────────────────────────────────────────────► complete
   │                                                           ▲
   │                 (user says "come back later")             │
   ▼                                                           │
paused ──────────────────────────────────────────────────────►│
   │                                                           │
   │           (upload offered, not yet received)              │
   ▼                                                           │
pending_materials ─────────────────────────────────────────►  │
   │                                                           │
   │   (no activity for dormancy threshold, e.g. 30 days)     │
   ▼                                                           │
archived ─────────────────────────────────── (reactivated) ─► active
```

No state is permanent except `archived`. Even `complete` threads can be reopened if new material arrives or the user returns with corrections.

---

## 3. Pending Obligations

An **obligation** is an open promise in a thread — something that was mentioned but not yet captured. Obligations are the engine's primary mechanism for offering continuation without pestering.

Obligations arise from:
- Explicit offers ("Would you like to add a photo?") that received "Not right now"
- Partial information ("I think it was around 1967, but I'm not sure")
- Mentioned-but-not-recorded facts ("She had two brothers — I'll tell you about them later")
- Invited-but-not-joined family members

Each obligation is stored in `pending_obligations` as a structured entry:

```json
{
  "id": "obl_123",
  "type": "artifact_upload",
  "label": "Wedding photograph",
  "thread_id": "thr_456",
  "claim_id": "clm_789",
  "offered_at": "2026-07-27T14:30:00Z",
  "declined_at": "2026-07-27T14:31:00Z",
  "fulfilled_at": null,
  "followup_after": "2026-08-10T00:00:00Z",
  "followup_count": 0,
  "max_followups": 2
}
```

Rules:
- An obligation that has been declined may be gently re-offered after `followup_after`
- `max_followups` caps the total number of re-offers; after that, it moves to `archived_obligations`
- The system never re-offers an obligation for a difficult topic without checking `ThreadState` and the user's `context_profile`

---

## 4. Thread Lifecycle

### 4.1 Thread Creation

A thread is created automatically when:
- The user begins discussing a new topic with no existing thread
- A family member is invited and creates their own continuation
- An inbound upload (photo, document) arrives without a thread anchor — a new thread is opened around the material

Thread creation is always silent. The user never sees "Thread created." They see natural conversation.

### 4.2 Thread Naming

Default names are generated from the first meaningful exchange:
- "Your wedding day" (not "Thread 14")
- "Military service, 1943–1946"
- "Growing up in Kharkiv"

Names are editable by the steward. They appear in the thread browser (a private view, not the main conversation).

### 4.3 Thread Suspension

When a user says "come back later" or closes the conversation mid-story, the thread moves to `paused`. The system notes any outstanding obligations.

No nudge is sent immediately. The minimum dormancy interval before any continuation offer is configurable — default 3 days, minimum 1 day, no maximum cap.

### 4.4 Thread Reactivation

Reactivation is offered naturally when:
- The user opens LifeBook and has no active thread
- A pending obligation has passed its `followup_after` date
- A new contribution arrives that references the thread's anchor

Reactivation language is covered in `THREAD_CONTINUATION_MODEL.md`.

### 4.5 Thread Completion

Completion is user-driven. The system may offer completion ("It sounds like we've captured the main story — would you like to mark your wedding day complete?") but never forces it. Completion simply suppresses unsolicited continuation prompts. The thread remains accessible and editable.

---

## 5. Non-Linear Navigation

The CSE is explicitly designed for non-linear conversations. Users do not need to finish one thing before starting another. Supported patterns:

### 5.1 Continuation
User returns to a thread where they left off. System offers brief recap and resumes.

### 5.2 Pause and Jump
User says "actually, let me tell you about something else first." System creates or activates a new thread. Old thread moves to `paused`. Both remain accessible.

### 5.3 Upload Mid-Thread
User shares a file during conversation. Upload flow is triggered inline without leaving the thread context. After upload, conversation resumes exactly where it was.

### 5.4 Correction
User says "I got that wrong — it was 1968, not 1967." System creates a superseding claim (`superseded_by_id` on the original), doesn't delete the old record, and notes the correction in the thread.

### 5.5 Invitation
User says "actually my daughter would know more about this part." System creates an invitation. Thread moves to `pending_materials` with an obligation for the invitee's contribution. When they join, they inherit thread context appropriate to their role (not necessarily the full thread).

### 5.6 Long Return (weeks or months)
User returns after an extended absence. System offers a gentle, non-presumptuous entry: "Last time we were talking about your wedding day. Would you like to continue, start somewhere new, or take a look at what's been added since you were away?"

---

## 6. Thread and Governance Architecture Integration

Every thread participates in the existing governance model:

### 6.1 Claims created via conversation

Claims generated during a conversation thread carry:
- `submission_origin = 'ai_assisted'` or `'steward_direct'`
- `producing_agent_code` — the registered agent code from `agent_registry`
- `context_manifest_id` — the agent session that produced the claim
- `review_status = 'pending'` until the steward reviews and promotes

This means no AI-assisted claim enters the LifeBook as authoritative without steward review.

### 6.2 Artifacts created via conversation

Artifacts created inline in a thread:
- Have `artifact_source_links` attaching them to any relevant source or narrative
- Use `fn_generate_artifact_signed_url` for all storage access (currently stub — will be fulfilled in the storage integration migration)
- Carry provenance: who uploaded, what thread, when, what agent session

### 6.3 Context Manifests

Each active agent conversation session is associated with a `context_manifest` record. This record carries:
- The agent code used
- Permitted data categories for that session
- Output destination (which threads/claims the session may write to)

Thread IDs are not stored in `context_manifests` directly, but the `context_manifest_id` on claims and artifacts is sufficient to trace back to the thread.

---

## 7. Thread Browser

A thread browser is the user's private view of their active and paused threads. It is not a transcript viewer. It shows:

- Thread name and topic
- Last activity date
- Pending obligations summary ("2 photos pending, 1 story incomplete")
- Quick actions: Continue / Review / Archive

The browser is visible only to the LifeBook steward and designated members with appropriate access classification. It is not the primary interface — conversation is. The browser is a safety net for managing complexity.

---

## 8. State Engine API Surface

These endpoints are required for the CSE. Full specification in the API design document.

```
POST   /api/v1/threads                          -- create thread (usually auto)
GET    /api/v1/threads                          -- list threads for a LifeBook
GET    /api/v1/threads/{id}                     -- thread state and obligations
PATCH  /api/v1/threads/{id}/state              -- pause, complete, reactivate
POST   /api/v1/threads/{id}/obligations         -- add obligation
PATCH  /api/v1/threads/{id}/obligations/{obl}  -- fulfill or decline obligation
POST   /api/v1/threads/{id}/messages            -- append conversation turn
GET    /api/v1/threads/{id}/continuation-prompt -- get natural re-entry text
```

---

## 9. What the CSE Is Not

The CSE is not a chat history store. It does not store the full verbatim transcript for LLM retrieval. What it stores is **structured context**: which claims were discussed, which artifacts are pending, what the user has agreed to and declined, and where the story has gaps.

The verbatim turn-by-turn exchange may be held transiently (session-scoped) for inference but is not the authoritative record. The authoritative record is the claims, narratives, and artifacts — governed objects in the LifeBook schema.

This design is intentional. LifeBook's long-term value is in the governed, curated record, not in the chat log.

---

## 10. Open Questions for DP Review

- **Dormancy threshold:** 30 days before thread moves to `archived`? Should this be per-lifebook-configurable?
- **max_followups default:** 2 re-offers before obligation is archived. Is this appropriate for difficult topics vs. routine uploads?
- **Thread visibility:** Should contributors (non-stewards) see thread state? Or only their own contributions?
- **Thread merging:** If two separate threads are discovered to be about the same event, can they be merged? (Not designed yet.)
- **Cross-LifeBook threads:** If a memory involves two LifeBooks (e.g., a shared family event), which thread owns it?

---

*CONVERSATION_STATE_ENGINE.md — LifeBook HQ — Conversation Experience v1 — 2026-07-27*
