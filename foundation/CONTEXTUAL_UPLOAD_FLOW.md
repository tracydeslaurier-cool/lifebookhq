# CONTEXTUAL_UPLOAD_FLOW.md
## LifeBook HQ — Conversation Experience v1
**Status:** Design — awaiting implementation  
**Milestone:** Conversation Experience v1  
**Date:** 2026-07-27  
**Companion documents:** CONVERSATION_STATE_ENGINE.md, CONVERSATION_TONE_GUIDE.md

---

## 1. Principle

Upload is not a form. It is a moment in a conversation.

The upload offer emerges from what the person just said. It is brief, natural, and easy to decline. Whether the person accepts, declines, or defers, the thread continues and the intent is recorded.

The underlying artifact architecture — including the signed URL capability — already exists in the schema. This document defines how conversation triggers that architecture, not how to replace it.

---

## 2. Trigger Recognition

The upload offer is triggered when a conversation turn contains one or more of the following signal types:

### 2.1 Physical object signals
User mentions a document, photograph, certificate, recording, or other physical item:
- "I have their wedding certificate"
- "There's a photo from that day"
- "My grandfather kept a journal"
- "We have the immigration papers somewhere"

### 2.2 Digitized material signals
User implies they have something already digitized:
- "I scanned some old photos last year"
- "I took a picture of the gravestone"
- "It's in my phone"

### 2.3 Event-anchored materials
High-probability upload candidates based on event type:
- Weddings → photographs, invitations, certificates
- Military service → discharge papers, photographs, medals (document scan)
- Immigration → visas, travel documents, arrival photographs
- Births → birth certificates, hospital photographs
- Deaths → obituaries, death certificates, funeral photographs (if offered)

Event-anchored triggers are softer — offered only if the user is engaging actively with the event and has not already declined a recent upload offer for the same thread.

### 2.4 Explicit user signals
User directly mentions wanting to add something:
- "Can I add a photo?"
- "I want to include the document"
- "Should I upload it?"

These bypass all threshold logic and trigger the upload flow immediately.

---

## 3. Conversation Flow

### 3.1 Standard offer (material mentioned)

```
User:   "My wife and I were married on October 27, 1983."

System: "That sounds like a meaningful day. Do you have any photos, 
         documents, or keepsakes from your wedding that you'd like 
         to preserve?"

        [Add photo or document]  [Not right now]
```

### 3.2 User accepts

```
User:   [taps "Add photo or document"]

System: [Upload interface appears inline — no navigation away from thread]

        "You can add photos, scanned documents, or any file you'd like 
         to attach to your wedding story. We'll keep it linked to this 
         part of your LifeBook."

        [File picker / camera / drag-and-drop zone]
        [Cancel]
```

Upload completes:

```
System: "Got it. That's been added to your wedding story."
        [Continue conversation]
```

### 3.3 User declines — "Not right now"

```
System: "No problem. I've made a note — whenever you find them, 
         we can add them here."

        [Continue conversation — no upload prompt for this thread 
         until the follow-up interval has passed]
```

The obligation is recorded in the thread's `pending_obligations` with `declined_at` set and `followup_after` calculated.

### 3.4 User defers mid-conversation

```
User:   "I'll look for the photos this weekend."

System: "Sounds good. We'll be here when you find them."

        [Continue conversation]
```

System adds an obligation with a `followup_after` of approximately 7 days.

### 3.5 Upload arrives without active conversation

User uploads a file directly from the thread browser or from an upload link shared by a steward.

```
System: "Welcome back. You've added a photo — looks like it might be 
         related to your wedding story. Would you like to attach it there, 
         or place it somewhere else?"

        [Attach to wedding story]  [Choose a different story]  [Leave unattached for now]
```

---

## 4. What Gets Created

When a user uploads a file through the upload flow, the following records are created:

### 4.1 Artifact record

```sql
INSERT INTO artifacts (
  id,
  lifebook_id,
  artifact_type,         -- 'photograph', 'document', 'audio', 'video', etc.
  validity_state,        -- 'pending_review' initially
  access_classification, -- defaults to 'family' unless user chooses otherwise
  created_by_id,
  source_id,             -- if source exists (e.g., the upload is from a specific source)
  notes,
  created_at
)
```

### 4.2 Storage

The artifact's object key is generated and stored. Access is gated through `fn_generate_artifact_signed_url`, which is currently a stub and will be fulfilled in the storage integration migration. The upload flow must assume this function will eventually return a pre-signed URL — not a direct URL.

Upload URL acquisition:

```
GET /api/v1/artifacts/{id}/upload-url
→ { upload_url: "...", expires_at: "..." }   (from storage layer)
```

The file is uploaded directly to storage using the signed URL. LifeBook's server never handles the file bytes.

### 4.3 Artifact source link

If the artifact is associated with a narrative, source, or event, a record is created:

```sql
INSERT INTO artifact_source_links (
  artifact_id,
  source_id,             -- or narrative_id, event_id depending on anchor
  relationship_type,     -- 'primary_evidence', 'contextual', 'illustrative'
  notes
)
```

### 4.4 Thread obligation fulfilled

```json
PATCH /api/v1/threads/{id}/obligations/{obl_id}
{ "fulfilled_at": "2026-07-27T14:30:00Z", "artifact_id": "art_123" }
```

---

## 5. Provenance Handling

Every artifact uploaded through the conversation flow carries full provenance:

| Field | Value | Source |
|---|---|---|
| `created_by_id` | authenticated user UUID | session |
| `submission_origin` | `'steward_direct'` or `'ai_assisted'` | upload context |
| `producing_agent_code` | agent code if AI-initiated | `agent_registry` |
| `context_manifest_id` | active session manifest | `context_manifests` |
| `validity_state` | `'pending_review'` | default |

The distinction between `steward_direct` and `ai_assisted`:
- If the user chose to upload in response to an AI offer → `'ai_assisted'`
- If the user initiated the upload unprompted (e.g., from thread browser) → `'steward_direct'`

Both are held at `pending_review` initially, though the steward may configure auto-promotion for their own direct uploads.

---

## 6. Review Workflow

### 6.1 Artifacts pending review

A steward review queue surfaces all artifacts (and claims) where `validity_state = 'pending_review'` or `review_status = 'pending'`.

Steward actions on a pending artifact:
- **Approve:** `validity_state → 'valid'`; artifact is now part of the LifeBook
- **Reject:** `validity_state → 'invalid'`; artifact is retained for audit but excluded from display
- **Request information:** artifact stays at `pending_review`; a note is added
- **Promote to restricted:** `access_classification → 'restricted'`; controls display policy

### 6.2 Review is non-blocking

An artifact in `pending_review` is preserved and associated. It is simply not displayed to non-steward roles until approved. The conversation continues without waiting for review. This is consistent with the `review_status` model on claims.

---

## 7. API Endpoints

```
POST   /api/v1/artifacts
       body: { artifact_type, lifebook_id, access_classification, notes? }
       → { id, upload_url, upload_url_expires_at }

GET    /api/v1/artifacts/{id}/upload-url
       → { upload_url, expires_at }
       (wraps fn_generate_artifact_signed_url — stub in v1)

PATCH  /api/v1/artifacts/{id}
       body: { validity_state?, notes?, access_classification? }
       → artifact record

POST   /api/v1/artifact-source-links
       body: { artifact_id, source_id?, narrative_id?, event_id?, relationship_type }
       → link record

GET    /api/v1/artifacts?lifebook_id={id}&validity_state=pending_review
       → paginated list for review queue
```

---

## 8. Upload Interface Requirements

### 8.1 The upload UI must:
- Appear inline within the conversation — no full-page navigation
- Accept: image files (JPEG, PNG, HEIC, WEBP), PDF, common document formats
- Show clear progress (uploading → processing → added)
- Offer a note/caption field (optional)
- Allow the user to remove the attachment before finalizing

### 8.2 The upload UI must not:
- Require the user to categorize or tag the file before uploading
- Show technical metadata (file size, dimensions, object key)
- Block conversation continuation if upload fails
- Auto-share with family members without explicit steward action

### 8.3 Failure handling:
- Upload failure: "Something went wrong with that upload. Want to try again, or skip it for now?"
- Network timeout: Obligation is preserved; user is offered retry on next session open
- Unsupported file type: "We can't add that file type just yet. Photos, documents, and PDFs work best."

---

## 9. Future Considerations (out of scope for v1)

- **Bulk upload:** User has 40 photos from a box. Flow needs a multi-select mode with batch attachment to a thread.
- **External integration:** Upload from Google Photos, iCloud, or Dropbox without downloading first.
- **Translation capture:** User uploads a document in another language. Flow offers to record a translation alongside it.
- **Audio/video:** Family member records a voice memory. Stored and linked but transcription is a future capability.
- **QR code upload:** Physical artifact in a frame generates a QR code that opens the upload flow pre-anchored to the right story.

---

*CONTEXTUAL_UPLOAD_FLOW.md — LifeBook HQ — Conversation Experience v1 — 2026-07-27*
