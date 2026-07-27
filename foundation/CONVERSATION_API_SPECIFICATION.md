# CONVERSATION_API_SPECIFICATION.md
## LifeBook HQ — Conversation Experience v1
**Status:** Design — awaiting implementation  
**Milestone:** Conversation Experience v1  
**Date:** 2026-07-27  
**Companion documents:** CONVERSATION_STATE_ENGINE.md, CONTEXTUAL_UPLOAD_FLOW.md, THREAD_CONTINUATION_MODEL.md, AI_ORCHESTRATION_LAYER.md

---

## 1. Scope and Principles

This document specifies the REST API surface for the LifeBook Conversation Experience. It covers six endpoint groups: thread management, conversation turns, obligation management, upload flow, review queue, and invitations.

### 1.1 Authentication

All endpoints require a Supabase JWT in the `Authorization: Bearer <token>` header. The token is issued by Supabase Auth and carries the caller's user UUID. AI agents authenticate using service-role JWTs issued to their registered `agent_code` in `agent_registry`. Role determination is made at query time from `lifebook_memberships` via `fn_lb_membership_role(lifebook_id)`.

### 1.2 Authorization Model

The API layer does not re-implement role checks. All authorization is enforced by Supabase Row Level Security policies and governance functions (`fn_lb_membership_role`, `fn_user_is_agent`, SECURITY DEFINER functions) at the database layer. The API trusts the database's enforcement. Endpoint documentation states which role is *required* as a reference for consumers — the DB enforces it.

### 1.3 Conventions

- All paths are prefixed `/api/v1`
- All request and response bodies are `application/json`
- Timestamps are ISO 8601 UTC strings (`TIMESTAMPTZ`)
- UUIDs are lowercase hyphenated strings
- Pagination: cursor-based using `after` (UUID of last record seen) and `limit` (default 25, max 100)
- All mutating endpoints are idempotent where feasible; a `POST` with the same idempotency key (client-generated, passed as `Idempotency-Key` header) returns the original response if already processed

### 1.4 Common Error Shape

```json
{
  "error": {
    "code": "thread_not_found",
    "message": "No thread with that ID exists in this LifeBook.",
    "request_id": "req_01jz..."
  }
}
```

Standard HTTP status codes apply. `403` means the caller's role is insufficient. `404` means the record does not exist or the caller cannot see it (RLS-masked). `409` means a state conflict. `422` means the request body is structurally valid but semantically rejected.

---

## 2. Thread Management

Threads are the primary unit of conversation organization. A thread represents a bounded, persistent context anchored to a person, event, or topic. Threads are never deleted — only archived.

---

### 2.1 List Threads

**Purpose:** Return all threads for a given LifeBook, filterable by state. Used by the thread browser and by the Orchestrator when determining which paused contexts to surface to a returning user.

**Method:** `GET /api/v1/threads`

**Query Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `lifebook_id` | UUID | Yes | The LifeBook to query |
| `state` | string | No | Filter by ThreadState: `active`, `paused`, `pending_materials`, `complete`, `archived` |
| `after` | UUID | No | Cursor for pagination |
| `limit` | integer | No | Results per page (default 25, max 100) |

**Required Role:** viewer, contributor, or steward for the given `lifebook_id`

**Response 200:**

```json
{
  "threads": [
    {
      "id": "thr_...",
      "lifebook_id": "lb_...",
      "created_by_id": "usr_...",
      "created_at": "2026-07-27T14:00:00Z",
      "topic_label": "Wedding Day 1983",
      "anchor_entity_id": "ent_...",
      "anchor_event_id": null,
      "state": "paused",
      "last_activity_at": "2026-07-27T14:30:00Z",
      "dormant_since": null,
      "context_manifest_id": "mnf_...",
      "pending_obligations_count": 2,
      "thread_summary": "Discussion of the October 1983 wedding. Photos pending. Guest list incomplete."
    }
  ],
  "next_cursor": "thr_...",
  "has_more": true
}
```

**Error Responses:**
- `400` — missing `lifebook_id`
- `403` — caller has no membership in this LifeBook
- `422` — invalid `state` value

---

### 2.2 Create Thread

**Purpose:** Create a new conversation thread. In normal operation this is called automatically by the Orchestrator when a new topic is detected. It may also be called explicitly when a steward initiates a structured capture session.

**Method:** `POST /api/v1/threads`

**Required Role:** contributor or steward

**Request Body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `lifebook_id` | UUID | Yes | Target LifeBook |
| `topic_label` | string | Yes | Human-readable topic name; may be updated later |
| `anchor_entity_id` | UUID | No | Person entity this thread concerns |
| `anchor_event_id` | UUID | No | Event this thread concerns |
| `context_manifest_id` | UUID | No | Active agent session manifest; required if created by an AI agent |

**Response 201:**

```json
{
  "thread": {
    "id": "thr_...",
    "lifebook_id": "lb_...",
    "created_by_id": "usr_...",
    "created_at": "2026-07-27T14:00:00Z",
    "topic_label": "Wedding Day 1983",
    "anchor_entity_id": "ent_...",
    "anchor_event_id": null,
    "state": "active",
    "last_activity_at": "2026-07-27T14:00:00Z",
    "dormant_since": null,
    "context_manifest_id": "mnf_...",
    "pending_obligations": [],
    "thread_summary": null
  }
}
```

**Error Responses:**
- `403` — caller is a viewer; cannot create threads
- `404` — `lifebook_id`, `anchor_entity_id`, or `anchor_event_id` not found or not accessible
- `422` — `topic_label` is blank; or AI agent call missing `context_manifest_id`

---

### 2.3 Get Thread

**Purpose:** Retrieve the current state of a thread, including pending obligations and the thread summary used for continuation prompt generation.

**Method:** `GET /api/v1/threads/{thread_id}`

**Required Role:** viewer or above

**Response 200:**

```json
{
  "thread": {
    "id": "thr_...",
    "lifebook_id": "lb_...",
    "created_by_id": "usr_...",
    "created_at": "2026-07-27T14:00:00Z",
    "topic_label": "Wedding Day 1983",
    "anchor_entity_id": "ent_...",
    "anchor_event_id": null,
    "state": "pending_materials",
    "last_activity_at": "2026-07-27T14:30:00Z",
    "dormant_since": null,
    "context_manifest_id": "mnf_...",
    "pending_obligations": [
      {
        "id": "obl_...",
        "type": "artifact_upload",
        "label": "Wedding photograph",
        "offered_at": "2026-07-27T14:30:00Z",
        "declined_at": null,
        "fulfilled_at": null,
        "followup_after": "2026-08-10T00:00:00Z",
        "followup_count": 0,
        "max_followups": 2
      }
    ],
    "thread_summary": "Discussion of the October 1983 wedding. Photos pending."
  }
}
```

**Error Responses:**
- `404` — thread not found or not accessible to caller

---

### 2.4 Update Thread State

**Purpose:** Transition a thread between states. This is the primary state-machine endpoint. The Orchestrator calls this when the user pauses, completes, or reactivates a thread. Contributors may pause their own threads; only stewards may archive or complete.

**Method:** `PATCH /api/v1/threads/{thread_id}/state`

**Required Role:** contributor (for `paused`); steward (for `complete`, `archived`, reactivation)

**Request Body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `state` | string | Yes | Target state: `active`, `paused`, `pending_materials`, `complete`, `archived` |
| `reason` | string | No | Human-readable note; stored on the thread record for context |

**Valid Transitions:**

| From | To | Notes |
|---|---|---|
| `active` | `paused` | User-initiated or system-detected natural pause |
| `active` | `pending_materials` | Upload offered; awaiting receipt |
| `active` | `complete` | Steward only |
| `paused` | `active` | Reactivation |
| `paused` | `pending_materials` | Late upload offer added |
| `paused` | `complete` | Steward only |
| `pending_materials` | `active` | Material arrived; resuming |
| `pending_materials` | `paused` | Explicit pause while waiting |
| `pending_materials` | `complete` | Steward only |
| `complete` | `active` | Any state with new material or steward decision |
| `archived` | `active` | Steward reactivation only |
| `*` | `archived` | Steward only; dormancy threshold passed |

**Response 200:** Updated thread record (same shape as Get Thread).

**Error Responses:**
- `403` — invalid role for this transition
- `409` — transition not permitted from current state
- `422` — invalid target state

---

### 2.5 Update Thread

**Purpose:** Update mutable thread fields (topic label, anchor linkages, thread summary). The Orchestrator updates `thread_summary` after each session to preserve the auto-generated digest.

**Method:** `PATCH /api/v1/threads/{thread_id}`

**Required Role:** contributor (own threads); steward (any thread)

**Request Body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `topic_label` | string | No | Rename the thread |
| `anchor_entity_id` | UUID | No | Update or set entity anchor |
| `anchor_event_id` | UUID | No | Update or set event anchor |
| `thread_summary` | string | No | Updated digest; typically written by the Orchestrator |
| `context_manifest_id` | UUID | No | Update active manifest |

**Response 200:** Updated thread record.

**Error Responses:**
- `403` — caller cannot update this thread
- `404` — thread not found
- `422` — unknown anchor IDs

---

## 3. Conversation Turns

A conversation turn is a single user message and the AI response it produced. Turns are transient — they are processed by the AI orchestration layer and their structured outputs (claims, artifacts) are written to governed records. The turn itself is not stored as a permanent record in v1.

---

### 3.1 Post a Conversation Turn

**Purpose:** Submit a user message for processing. The Orchestrator receives this, builds context, invokes the language model, extracts claims, and returns the AI response. This is the core endpoint of the conversation experience.

**Method:** `POST /api/v1/threads/{thread_id}/messages`

**Required Role:** contributor or steward

**Request Body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `content` | string | Yes | User's message text |
| `context_manifest_id` | UUID | Yes | Active agent session manifest for this turn |
| `client_turn_id` | UUID | No | Client-generated ID for idempotency and UI correlation |

**Response 200:**

```json
{
  "turn_id": "trn_...",
  "client_turn_id": "...",
  "response": {
    "content": "That sounds like a meaningful day. Do you have any photos or documents from your wedding that you'd like to preserve?",
    "upload_offer": {
      "offered": true,
      "label": "Wedding photograph or document",
      "obligation_id": "obl_..."
    }
  },
  "extractions": {
    "claims_created": [
      {
        "id": "clm_...",
        "predicate_id": "pred_married_on",
        "value_date": "1983-10-27",
        "review_status": "pending"
      }
    ],
    "narratives_updated": [],
    "artifacts_pending": []
  },
  "thread_state": "active"
}
```

The `extractions` block is informational — it tells the client what the Orchestrator produced during this turn. All extracted records have already been written to the database by the time this response is returned. The client uses this to update local state without a separate fetch.

**Error Responses:**
- `403` — caller is a viewer; cannot post messages
- `404` — thread not found
- `409` — thread is in `archived` state; must be reactivated first
- `422` — `content` is empty; or `context_manifest_id` invalid or expired
- `503` — AI inference unavailable; message received but not yet processed (retry with same `client_turn_id`)

---

### 3.2 Get Continuation Prompt

**Purpose:** Generate the natural-language re-entry text for a paused or pending-materials thread. Called by the client when a user opens LifeBook with existing paused threads, or when the Orchestrator determines a continuation offer is appropriate. Returns a ready-to-display string; does not mutate state.

**Method:** `GET /api/v1/threads/{thread_id}/continuation-prompt`

**Required Role:** contributor or steward

**Response 200:**

```json
{
  "thread_id": "thr_...",
  "prompt": "Last time we were talking about your wedding day. You mentioned there might be some photos. We can come back to that now, or start somewhere new.",
  "thread_summary_used": "Discussion of the October 1983 wedding. Photos pending.",
  "obligations_surfaced": ["obl_..."]
}
```

**Error Responses:**
- `404` — thread not found
- `409` — thread is `active`; no continuation needed

---

## 4. Obligation Management

Obligations are open promises within a thread — unresolved items that may warrant future follow-up. They are stored in `thread_obligations` (M0004 schema). An obligation is never deleted; it is fulfilled, declined, or archived.

---

### 4.1 List Obligations for a Thread

**Purpose:** Return all obligations on a thread, optionally filtered by status. Used by the review panel and by the Orchestrator when building context for a returning user.

**Method:** `GET /api/v1/threads/{thread_id}/obligations`

**Query Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `status` | string | No | `open`, `fulfilled`, `declined`, `archived` |

**Required Role:** contributor (own threads); steward (any thread in the LifeBook)

**Response 200:**

```json
{
  "obligations": [
    {
      "id": "obl_...",
      "thread_id": "thr_...",
      "type": "artifact_upload",
      "label": "Wedding photograph",
      "claim_id": "clm_...",
      "offered_at": "2026-07-27T14:30:00Z",
      "declined_at": null,
      "fulfilled_at": null,
      "followup_after": "2026-08-10T00:00:00Z",
      "followup_count": 0,
      "max_followups": 2,
      "artifact_id": null
    }
  ]
}
```

---

### 4.2 Create Obligation

**Purpose:** Add a new obligation to a thread. Called by the Orchestrator when an upload offer is made, when a family member is mentioned but not yet invited, or when a fact is flagged as uncertain. In normal operation, the Orchestrator creates obligations automatically. Stewards may create obligations manually.

**Method:** `POST /api/v1/threads/{thread_id}/obligations`

**Required Role:** contributor or steward (also callable by AI agents with valid `context_manifest_id`)

**Request Body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | string | Yes | `artifact_upload`, `invitation`, `fact_verification`, `correction`, `continuation` |
| `label` | string | Yes | Human-readable description of the open item |
| `claim_id` | UUID | No | Claim this obligation relates to |
| `followup_after` | timestamptz | No | Earliest date for re-offer; defaults to 7 days from now |
| `max_followups` | integer | No | Maximum re-offer count; defaults to 2 |

**Response 201:**

```json
{
  "obligation": {
    "id": "obl_...",
    "thread_id": "thr_...",
    "type": "artifact_upload",
    "label": "Wedding photograph",
    "claim_id": "clm_...",
    "offered_at": "2026-07-27T14:30:00Z",
    "declined_at": null,
    "fulfilled_at": null,
    "followup_after": "2026-08-03T00:00:00Z",
    "followup_count": 0,
    "max_followups": 2,
    "artifact_id": null
  }
}
```

---

### 4.3 Fulfill Obligation

**Purpose:** Mark an obligation as fulfilled. Called when the user completes the action the obligation was tracking — typically when an upload completes or an invited family member joins. Fulfilling an obligation does not delete it; the record is retained for provenance.

**Method:** `PATCH /api/v1/threads/{thread_id}/obligations/{obligation_id}/fulfill`

**Required Role:** contributor or steward

**Request Body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `artifact_id` | UUID | No | If fulfilled by an upload, the artifact that satisfies it |
| `note` | string | No | Optional fulfillment note |

**Response 200:** Updated obligation record with `fulfilled_at` set.

**Error Responses:**
- `409` — obligation is already fulfilled or archived

---

### 4.4 Decline Obligation

**Purpose:** Mark an obligation as declined by the user. Declined obligations may be re-offered after `followup_after` if `followup_count < max_followups`. Once `max_followups` is reached, the obligation is archived.

**Method:** `PATCH /api/v1/threads/{thread_id}/obligations/{obligation_id}/decline`

**Required Role:** contributor or steward

**Request Body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `followup_after` | timestamptz | No | Override the next re-offer date; steward only |

**Response 200:** Updated obligation record with `declined_at` set and `followup_count` incremented.

**Error Responses:**
- `409` — obligation is already fulfilled or archived
- `422` — obligation has reached `max_followups`; no further decline tracking applies (transition to archived instead)

---

### 4.5 List Due Obligations

**Purpose:** Return all obligations across all threads for a LifeBook where `followup_after` has passed and `followup_count < max_followups`. Used by the Orchestrator at session open to determine whether any paused threads should be surfaced for continuation.

**Method:** `GET /api/v1/lifebooks/{lifebook_id}/obligations/due`

**Required Role:** steward

**Response 200:**

```json
{
  "obligations": [
    {
      "id": "obl_...",
      "thread_id": "thr_...",
      "thread_topic_label": "Wedding Day 1983",
      "type": "artifact_upload",
      "label": "Wedding photograph",
      "followup_after": "2026-08-03T00:00:00Z",
      "followup_count": 0
    }
  ]
}
```

---

## 5. Upload Flow

The upload flow follows a three-step pattern: create the artifact record, upload the file directly to storage using a signed URL, finalize the record once the upload is confirmed. LifeBook's server never handles file bytes.

---

### 5.1 Create Artifact

**Purpose:** Create an artifact record in `pending_upload` state and obtain a signed URL for direct-to-storage upload. This is the entry point for all uploads, whether initiated inline in conversation or from the thread browser.

**Method:** `POST /api/v1/artifacts`

**Required Role:** contributor or steward

**Request Body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `lifebook_id` | UUID | Yes | Target LifeBook |
| `artifact_type` | string | Yes | `photograph`, `document`, `audio`, `video`, `certificate`, `other` |
| `filename` | string | Yes | Original filename; used for storage key generation |
| `content_type` | string | Yes | MIME type of the file |
| `access_classification` | string | No | `family` (default), `restricted`, `private` |
| `notes` | string | No | Caption or contextual note from the user |
| `thread_id` | UUID | No | Thread this upload is associated with |
| `obligation_id` | UUID | No | Obligation this upload fulfills |
| `context_manifest_id` | UUID | No | Active agent manifest; required if upload is AI-assisted |
| `submission_origin` | string | No | `steward_direct` (default) or `ai_assisted` |

**Response 201:**

```json
{
  "artifact": {
    "id": "art_...",
    "lifebook_id": "lb_...",
    "artifact_type": "photograph",
    "upload_state": "pending_upload",
    "validity_state": "pending_review",
    "access_classification": "family",
    "created_by_id": "usr_...",
    "created_at": "2026-07-27T14:00:00Z",
    "notes": "Wedding photo, October 1983"
  },
  "upload": {
    "upload_url": "https://storage.example.com/...",
    "upload_url_expires_at": "2026-07-27T14:15:00Z",
    "object_key": "lb_xxx/art_yyy/original.jpg"
  }
}
```

The `upload_url` is a pre-signed PUT URL pointing directly to the storage layer. The client uploads the file bytes directly to this URL. The LifeBook server is not in the upload path.

**Error Responses:**
- `403` — caller is a viewer
- `404` — `lifebook_id` not found
- `422` — invalid `artifact_type` or `content_type`; `submission_origin = ai_assisted` without `context_manifest_id`

---

### 5.2 Get Upload URL

**Purpose:** Retrieve a fresh signed upload URL for an artifact that is still in `pending_upload` state. Used when the original URL has expired (15-minute TTL) and the user needs to retry.

**Method:** `GET /api/v1/artifacts/{artifact_id}/upload-url`

**Required Role:** contributor (own artifacts); steward (any artifact in the LifeBook)

**Response 200:**

```json
{
  "upload_url": "https://storage.example.com/...",
  "upload_url_expires_at": "2026-07-27T15:00:00Z",
  "object_key": "lb_xxx/art_yyy/original.jpg"
}
```

**Error Responses:**
- `404` — artifact not found
- `409` — artifact is not in `pending_upload` state (already finalized or failed)

---

### 5.3 Finalize Artifact

**Purpose:** Confirm that a file upload has completed and transition the artifact from `pending_upload` to `received`. In normal operation, this is called either by a storage webhook (preferred) or by the client after a successful PUT to the signed URL. Sets `upload_state = 'received'` and keeps `validity_state = 'pending_review'` until steward review.

**Method:** `POST /api/v1/artifacts/{artifact_id}/finalize`

**Required Role:** contributor (own artifacts); steward; or system (storage webhook)

**Request Body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `object_key` | string | Yes | Storage object key confirming where the file landed |
| `file_size_bytes` | integer | No | For audit record |
| `checksum_sha256` | string | No | For integrity verification |

**Response 200:**

```json
{
  "artifact": {
    "id": "art_...",
    "upload_state": "received",
    "validity_state": "pending_review",
    "object_key": "lb_xxx/art_yyy/original.jpg"
  }
}
```

The Finalize endpoint automatically fulfills any linked obligation (`obligation_id` from the Create step) by setting its `fulfilled_at`. The thread state is updated to reflect the upload's completion.

**Error Responses:**
- `404` — artifact not found
- `409` — artifact is not in `pending_upload` state

---

### 5.4 Attach Artifact to Narrative or Event

**Purpose:** Create an `artifact_source_link` record associating an artifact with a narrative, event, or source. An artifact may be attached to multiple targets. Called after finalization when the conversational context has determined where the artifact belongs.

**Method:** `POST /api/v1/artifact-links`

**Required Role:** contributor or steward

**Request Body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `artifact_id` | UUID | Yes | The artifact to link |
| `narrative_id` | UUID | No | Target narrative |
| `event_id` | UUID | No | Target event |
| `source_id` | UUID | No | Target source record |
| `relationship_type` | string | Yes | `primary_evidence`, `contextual`, `illustrative` |
| `notes` | string | No | Notes on the relationship |

At least one of `narrative_id`, `event_id`, or `source_id` is required.

**Response 201:**

```json
{
  "link": {
    "id": "lnk_...",
    "artifact_id": "art_...",
    "narrative_id": "nar_...",
    "event_id": null,
    "source_id": null,
    "relationship_type": "primary_evidence",
    "created_at": "2026-07-27T14:00:00Z"
  }
}
```

**Error Responses:**
- `404` — artifact or target not found
- `409` — this exact link already exists
- `422` — no target specified; or both `narrative_id` and `event_id` specified for a single link (use separate calls)

---

## 6. Review Queue

The review queue surfaces all governed records awaiting steward review: claims with `review_status = 'pending'`, artifacts with `validity_state = 'pending_review'`, and narratives with `review_status = 'pending'`. Only stewards may perform review actions.

---

### 6.1 List Pending Review Items

**Purpose:** Return all items awaiting review for a LifeBook. Supports filtering by record type. This is the primary view for the steward review panel.

**Method:** `GET /api/v1/lifebooks/{lifebook_id}/review-queue`

**Query Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `type` | string | No | `claim`, `artifact`, `narrative`; omit for all |
| `after` | UUID | No | Cursor for pagination |
| `limit` | integer | No | Default 25, max 100 |

**Required Role:** steward

**Response 200:**

```json
{
  "items": [
    {
      "type": "claim",
      "id": "clm_...",
      "predicate_id": "pred_married_on",
      "value_date": "1983-10-27",
      "subject_entity_id": "ent_...",
      "review_status": "pending",
      "submission_origin": "ai_assisted",
      "producing_agent_code": "conversation_orchestrator_v1",
      "context_manifest_id": "mnf_...",
      "created_at": "2026-07-27T14:00:00Z",
      "thread_id": "thr_..."
    },
    {
      "type": "artifact",
      "id": "art_...",
      "artifact_type": "photograph",
      "validity_state": "pending_review",
      "access_classification": "family",
      "created_by_id": "usr_...",
      "notes": "Wedding photo, October 1983",
      "created_at": "2026-07-27T14:05:00Z",
      "thread_id": "thr_..."
    }
  ],
  "next_cursor": "clm_...",
  "has_more": false
}
```

---

### 6.2 Review a Claim

**Purpose:** Approve or reject a pending claim. Approval sets `review_status = 'human_reviewed'`. Rejection transitions the claim to a rejected state; it is not deleted. A steward may also request more information, which leaves the claim at `pending` with a note.

**Method:** `PATCH /api/v1/claims/{claim_id}/review`

**Required Role:** steward

**Request Body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `decision` | string | Yes | `approve`, `reject`, `request_information` |
| `note` | string | No | Required if `decision = request_information` |

**Response 200:**

```json
{
  "claim": {
    "id": "clm_...",
    "review_status": "human_reviewed",
    "reviewed_by_id": "usr_...",
    "reviewed_at": "2026-07-27T15:00:00Z"
  }
}
```

**Error Responses:**
- `403` — caller is not a steward
- `404` — claim not found
- `409` — claim is not in `pending` review status
- `422` — `decision = request_information` without `note`

---

### 6.3 Review an Artifact

**Purpose:** Approve or reject a pending artifact. Approval sets `validity_state = 'valid'`. Rejection sets `validity_state = 'invalid'` — the artifact is retained but excluded from display. A steward may also change the access classification during review.

**Method:** `PATCH /api/v1/artifacts/{artifact_id}/review`

**Required Role:** steward

**Request Body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `decision` | string | Yes | `approve`, `reject`, `request_information` |
| `access_classification` | string | No | Override at review time: `family`, `restricted`, `private` |
| `note` | string | No | Required if `decision = request_information` |

**Response 200:**

```json
{
  "artifact": {
    "id": "art_...",
    "validity_state": "valid",
    "access_classification": "family",
    "reviewed_by_id": "usr_...",
    "reviewed_at": "2026-07-27T15:00:00Z"
  }
}
```

**Error Responses:**
- `403` — caller is not a steward
- `404` — artifact not found
- `409` — artifact is not in `pending_review` state

---

### 6.4 Review a Narrative

**Purpose:** Approve or reject a pending AI-generated or contributor-submitted narrative. Follows the same decision pattern as claims and artifacts.

**Method:** `PATCH /api/v1/narratives/{narrative_id}/review`

**Required Role:** steward

**Request Body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `decision` | string | Yes | `approve`, `reject`, `request_information` |
| `note` | string | No | Required if `decision = request_information` |

**Response 200:**

```json
{
  "narrative": {
    "id": "nar_...",
    "review_status": "human_reviewed",
    "reviewed_by_id": "usr_...",
    "reviewed_at": "2026-07-27T15:00:00Z"
  }
}
```

**Error Responses:**
- `403` — caller is not a steward
- `404` — narrative not found
- `409` — narrative is not in `pending` review status

---

## 7. Invitations

An invitation allows a steward to bring a family member or contributor into a specific thread. The invitee receives limited access scoped to the LifeBook and thread they have been invited to contribute to. Steward-private data is never surfaced to contributors without explicit steward action.

---

### 7.1 Create Invitation

**Purpose:** Invite a person to contribute to a specific thread. Creates an invitation record, sends the invitation communication (email in v1), creates a pending `invitation` obligation on the thread, and transitions the thread to `pending_materials` state if it is currently `active`.

**Method:** `POST /api/v1/threads/{thread_id}/invitations`

**Required Role:** steward

**Request Body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `invitee_email` | string | Yes | Email address of the person being invited |
| `invitee_name` | string | Yes | Display name; used in the invitation message |
| `message` | string | No | Personal message from the steward; included in the invitation |
| `role` | string | No | Role to assign on join: `contributor` (default) or `viewer` |
| `contribution_prompt` | string | No | Specific question or topic to present to the invitee on join |

**Response 201:**

```json
{
  "invitation": {
    "id": "inv_...",
    "thread_id": "thr_...",
    "lifebook_id": "lb_...",
    "invitee_email": "family@example.com",
    "invitee_name": "Margaret",
    "role": "contributor",
    "state": "pending",
    "obligation_id": "obl_...",
    "created_at": "2026-07-27T14:00:00Z",
    "expires_at": "2026-08-10T14:00:00Z"
  }
}
```

The invitation expires after 14 days by default. Expired invitations may be reissued.

**Error Responses:**
- `403` — caller is not a steward
- `404` — thread not found
- `409` — an active invitation for this email and thread already exists
- `422` — invalid email; invalid `role` value

---

### 7.2 List Invitations for a Thread

**Purpose:** Return all invitations on a thread and their status. Used by the steward to track who has been invited and whether they have joined.

**Method:** `GET /api/v1/threads/{thread_id}/invitations`

**Required Role:** steward

**Response 200:**

```json
{
  "invitations": [
    {
      "id": "inv_...",
      "invitee_email": "family@example.com",
      "invitee_name": "Margaret",
      "role": "contributor",
      "state": "pending",
      "created_at": "2026-07-27T14:00:00Z",
      "expires_at": "2026-08-10T14:00:00Z",
      "accepted_at": null
    }
  ]
}
```

---

### 7.3 Resend Invitation

**Purpose:** Resend the invitation communication for an invitation that is still `pending`. Does not create a new record; resends from the existing one and extends the expiry by 14 days.

**Method:** `POST /api/v1/invitations/{invitation_id}/resend`

**Required Role:** steward

**Response 200:**

```json
{
  "invitation": {
    "id": "inv_...",
    "state": "pending",
    "expires_at": "2026-08-24T14:00:00Z",
    "resent_at": "2026-08-10T09:00:00Z"
  }
}
```

**Error Responses:**
- `409` — invitation has already been accepted or has been revoked
- `422` — invitation has expired; issue a new one instead

---

### 7.4 Revoke Invitation

**Purpose:** Cancel a pending invitation before it is accepted. The obligation is moved to `archived` state. The thread state is not automatically changed; the steward must update it separately if appropriate.

**Method:** `DELETE /api/v1/invitations/{invitation_id}`

**Required Role:** steward

**Response 200:**

```json
{
  "invitation": {
    "id": "inv_...",
    "state": "revoked",
    "revoked_at": "2026-07-27T15:00:00Z"
  }
}
```

**Error Responses:**
- `409` — invitation has already been accepted; role must be changed via membership management instead

---

## 8. Endpoint Index

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/v1/threads` | List threads for a LifeBook |
| `POST` | `/api/v1/threads` | Create a thread |
| `GET` | `/api/v1/threads/{id}` | Get thread |
| `PATCH` | `/api/v1/threads/{id}` | Update thread fields |
| `PATCH` | `/api/v1/threads/{id}/state` | Transition thread state |
| `POST` | `/api/v1/threads/{id}/messages` | Post a conversation turn |
| `GET` | `/api/v1/threads/{id}/continuation-prompt` | Get continuation prompt text |
| `GET` | `/api/v1/threads/{id}/obligations` | List obligations |
| `POST` | `/api/v1/threads/{id}/obligations` | Create obligation |
| `PATCH` | `/api/v1/threads/{id}/obligations/{obl_id}/fulfill` | Fulfill obligation |
| `PATCH` | `/api/v1/threads/{id}/obligations/{obl_id}/decline` | Decline obligation |
| `GET` | `/api/v1/lifebooks/{id}/obligations/due` | List due obligations |
| `POST` | `/api/v1/artifacts` | Create artifact and get upload URL |
| `GET` | `/api/v1/artifacts/{id}/upload-url` | Refresh signed upload URL |
| `POST` | `/api/v1/artifacts/{id}/finalize` | Confirm upload complete |
| `PATCH` | `/api/v1/artifacts/{id}/review` | Review an artifact |
| `POST` | `/api/v1/artifact-links` | Attach artifact to narrative/event |
| `GET` | `/api/v1/lifebooks/{id}/review-queue` | List pending review items |
| `PATCH` | `/api/v1/claims/{id}/review` | Review a claim |
| `PATCH` | `/api/v1/narratives/{id}/review` | Review a narrative |
| `GET` | `/api/v1/threads/{id}/invitations` | List invitations |
| `POST` | `/api/v1/threads/{id}/invitations` | Create invitation |
| `POST` | `/api/v1/invitations/{id}/resend` | Resend invitation |
| `DELETE` | `/api/v1/invitations/{id}` | Revoke invitation |

---

## 9. Implementation Notes

**Rate limiting:** Conversation turn endpoints (`POST /messages`) are rate-limited to 60 requests per user per minute. Other endpoints: 300 per user per minute. Limits are per authenticated user UUID, not per IP.

**Idempotency:** `POST /api/v1/threads/{id}/messages` is idempotent within a 10-minute window on `client_turn_id`. A repeated call with the same `client_turn_id` returns the original response without re-invoking the AI.

**Webhook endpoint for storage:** `POST /api/v1/webhooks/storage` accepts storage layer callbacks when an upload completes. This endpoint is authenticated by a shared secret (not a JWT) and is not part of the consumer API surface. Its effect is equivalent to `POST /api/v1/artifacts/{id}/finalize`.

**Versioning:** This is v1. Breaking changes require a new version prefix (`/api/v2/`). Additive changes (new optional fields, new endpoints) are non-breaking and deployed without version increment.

---

*CONVERSATION_API_SPECIFICATION.md — LifeBook HQ — Conversation Experience v1 — 2026-07-27*
