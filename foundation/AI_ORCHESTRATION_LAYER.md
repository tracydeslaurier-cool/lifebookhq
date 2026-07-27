# AI_ORCHESTRATION_LAYER.md
## LifeBook HQ — Conversation Experience v1
**Status:** Design — awaiting implementation  
**Milestone:** Conversation Experience v1  
**Date:** 2026-07-27  
**Companion documents:** CONVERSATION_API_SPECIFICATION.md, CONVERSATION_STATE_ENGINE.md, AI_CONTEXT_BROKER.md, GOVERNANCE_ENFORCEMENT_MODEL.md, CONTEXTUAL_UPLOAD_FLOW.md

---

## 1. Overview

The AI Orchestration Layer is the set of components that sit between the conversation UI and the governed database. It receives raw user input, coordinates AI inference, extracts structured memory, manages thread state, and writes governed records — all without storing the conversation transcript as a permanent artifact.

The layer consists of six components. Each has a defined scope of responsibility and does not exceed it. No component has write access to governed records except through its designated path.

```
UI
 │
 ▼
Conversation Orchestrator      ◄── coordinates all components
 │         │         │
 ▼         ▼         ▼
Context   Upload    Invitation
Manager  Coordinator  Manager
 │
 ▼
LLM (via Context Manager prompt)
 │
 ▼
Memory Extractor
 │
 ▼
Claim Generator
 │
 ▼
Database (claims, narratives, artifacts, threads, obligations)
```

---

## 2. Governing Principle

> **"Conversation is Ephemeral. History is Permanent."**

This principle governs every architectural decision in this layer.

- The verbatim exchange between user and AI is transient. It is held in working memory for the duration of the session and used to generate structured outputs. It is not the product.
- The governed outputs — claims, narratives, artifacts, obligations — are permanent. They are the product.
- No component in this layer writes directly to the conversation transcript as a permanent record.
- Every governed write is traceable: it carries a `producing_agent_code`, a `context_manifest_id`, and a `submission_origin`.

---

## 3. Component: Conversation Orchestrator

The Orchestrator is the central coordinator. It receives user input from the API layer, determines what actions to take, coordinates the other components, and returns the AI response to the caller. All other components are invoked by the Orchestrator — none communicate with each other directly.

### 3.1 Responsibilities

- Receive incoming conversation turns from `POST /api/v1/threads/{id}/messages`
- Retrieve the current thread record and pending obligations to establish context
- Delegate prompt construction to the Context Manager
- Invoke the LLM with the prepared context
- Pass the LLM output to the Memory Extractor for claim extraction
- Decide, based on thread context and LLM output, whether an upload offer is appropriate; if so, trigger the Upload Coordinator
- Decide, based on user statement, whether an invitation should be created; if so, trigger the Invitation Manager
- Assemble the final API response: AI text, extraction summary, upload offer (if any), updated thread state
- Update the thread record: `last_activity_at`, `thread_summary` (post-turn digest), thread state transitions
- Write the context manifest entry for this turn via the Context Broker

### 3.2 What It Does NOT Do

- Does not write claims directly to the database. Claim creation is delegated exclusively to the Claim Generator.
- Does not construct storage upload URLs. That is the Upload Coordinator's responsibility.
- Does not store the verbatim user message or AI response as a permanent database record. Session-scoped buffering is permissible for multi-turn context; permanent storage is not.
- Does not apply role-based access control. The API layer and database RLS handle this. The Orchestrator operates as the authenticated agent and trusts the DB's enforcement.
- Does not invoke the LLM directly with user data that has not passed through the Context Manager.

### 3.3 Communication with Other Components

| Invokes | For |
|---|---|
| Context Manager | Build the LLM prompt context |
| Memory Extractor | Identify claim candidates in the completed turn |
| Claim Generator | Write extracted claim candidates to the database |
| Upload Coordinator | When upload offer decision is made |
| Invitation Manager | When user indicates a family member should be invited |

The Orchestrator is the only component that speaks to the API layer and to the database thread/obligation tables. Other components have no direct contact with the API layer.

### 3.4 Failure Handling

- **LLM unavailable:** Return `503` to the API caller with `client_turn_id` preserved for retry. The user's message is not lost — the obligation to process it survives the session. On retry with the same `client_turn_id`, the Orchestrator re-runs the full turn.
- **Context Manager fails:** Fail the entire turn. Return `503`. Do not invoke the LLM with incomplete context — a partial context is worse than no context.
- **Memory Extractor fails:** Log the failure. Return the AI response to the user. The turn is not re-run, but the failed extraction is flagged so a human can review the turn's thread summary for any missed facts. The conversation is not blocked.
- **Claim Generator fails:** Same pattern as Memory Extractor failure. Response is returned; extraction failure is noted in the thread summary audit log.
- **Thread state conflict:** If the thread is `archived` when a message arrives, return `409` to the API caller without invoking any component. Do not silently drop the message.

---

## 4. Component: Context Manager

The Context Manager is responsible for what the LLM knows when it speaks. It builds the complete prompt context from governed sources, enforces data access boundaries, and ensures that no restricted data enters the model invocation unless the active context manifest explicitly permits it.

### 4.1 Responsibilities

- Retrieve the thread's `thread_summary` from the database — the persistent digest of what has been established
- Retrieve the thread's pending obligations — what has been promised but not yet delivered
- Retrieve known claims about the anchor entity (subject of the conversation) at the access classification permitted by the context manifest
- Retrieve the active context manifest and verify it is valid, unexpired, and scoped to this thread
- Compose the system prompt by combining: conversation persona (from CONVERSATION_TONE_GUIDE.md), the thread summary, the pending obligations, the permitted entity facts, and the current turn
- Apply the AI Context Broker's data access rules: no attribute may be included in the prompt that is not permitted by the context manifest's `data_categories` and the caller's `fn_lb_membership_role`
- Apply the sanitization pipeline to any retrieved source text before including it in the prompt
- Return the composed prompt context to the Orchestrator for LLM invocation

### 4.2 What It Does NOT Do

- Does not invoke the LLM. That is the Orchestrator's responsibility.
- Does not make decisions about what to extract or what to write. It provides context, not analysis.
- Does not store the constructed prompt. The prompt is ephemeral; it exists only for the current invocation.
- Does not pass the verbatim conversation history to the LLM beyond the current session's turns. Thread summary is the persistence mechanism; raw history is not replayed.
- Does not include steward-private attributes (access_classification `restricted` or `private`) in prompts for sessions operating under the `respectful_generation` context profile, regardless of what the thread contains.

### 4.3 Context Window Management

The context window budget is managed by the Context Manager. Priority order when space is constrained:

1. System prompt and conversation persona (non-negotiable)
2. Current user turn
3. Thread summary (truncated at 500 tokens if necessary)
4. Pending obligations (full — compact format)
5. Recent turns from this session (most recent first, dropped as needed)
6. Entity claims (most recent and highest-confidence first, dropped as needed)

The Context Manager never silently truncates governed data. If a mandatory component cannot fit, it returns an error to the Orchestrator rather than proceeding with incomplete context.

### 4.4 Communication with Other Components

The Context Manager is invoked by the Orchestrator and returns a composed prompt context. It queries the database directly for thread summary, obligations, and entity claims. It calls the AI Context Broker to validate the context manifest and to obtain the permitted data categories for this invocation.

### 4.5 Failure Handling

- **Context manifest invalid or expired:** Return error to Orchestrator. Do not build context. A new manifest must be issued before conversation can continue.
- **Entity facts query fails:** Log the failure. Build context without entity facts. Note the omission in the context manifest audit record. Do not fail the entire turn — the conversation can continue without structured fact context.
- **Sanitization pipeline error on a specific attribute:** Exclude that attribute from the prompt. Note the omission. Do not fail the turn for a single attribute sanitization failure.
- **Thread summary unavailable (first turn or corrupt):** Proceed with empty summary. The LLM operates in "first meeting" mode with no presumed knowledge of prior context.

---

## 5. Component: Memory Extractor

The Memory Extractor analyzes the completed LLM output (and, where helpful, the user's raw input) to identify facts that should be preserved in the governed record. It produces structured claim candidates — it does not write anything.

### 5.1 Responsibilities

- Receive the full conversation turn: user input and AI response
- Identify declarative statements that contain extractable facts: dates, names, relationships, places, events, attributes
- Produce one or more claim candidates per fact, each with:
  - `subject_entity_id` — the entity the fact is about
  - `predicate_id` — from `claim_predicates` (or flagged for review if no match is found)
  - `value` — extracted value, typed appropriately (text, date, numeric)
  - `confidence` — `high`, `medium`, or `low`
  - `certainty_qualifier` — whether the value was stated definitively (`definite`) or with uncertainty (`approximate`, `uncertain`)
  - `source_quote` — the verbatim excerpt from the user's statement that the candidate is drawn from
- Flag cases where a candidate conflicts with an existing claim on the same predicate for the same entity
- Pass candidates to the Claim Generator

### 5.2 Certainty Classification

The Memory Extractor distinguishes between definite and uncertain statements. This is not cosmetic — it determines how the Claim Generator writes the record.

| User Statement | Certainty | Value Handling |
|---|---|---|
| "She was born on July 14, 1947." | `definite` | Write `value_date = 1947-07-14` |
| "I think it was around 1947." | `uncertain` | Write `value_text = "circa 1947"`, note uncertainty |
| "Sometime in the late forties." | `approximate` | Write `value_text = "late 1940s"`, no date field |
| "I'm not sure — maybe 1947 or 1948." | `uncertain` | Two candidates with `low` confidence each |

Approximate and uncertain claims are still written — they are valuable incomplete knowledge. They are flagged in the review queue so the steward is aware they need corroboration.

### 5.3 What It Does NOT Do

- Does not write to the database. All database writes go through the Claim Generator.
- Does not determine whether a predicate is valid. That is the Claim Generator's validation step.
- Does not access data outside of the current conversation turn. It has no database access of its own.
- Does not make narrative judgments. "She seemed sad when she talked about it" is not a claim candidate. Emotional and contextual observations are not extracted.
- Does not extract information about people who were not explicitly discussed. It does not infer that person B exists because person A mentioned them without elaboration.

### 5.4 Communication with Other Components

The Memory Extractor is invoked by the Orchestrator after LLM response generation. It receives the user turn and AI response as input and returns a list of claim candidates to the Orchestrator, which passes them to the Claim Generator.

### 5.5 Failure Handling

- **No claims identified:** Return an empty candidates list. This is a valid outcome for turns that are purely conversational (greetings, emotional reflection, clarification requests).
- **Predicate cannot be determined:** Mark the candidate with `predicate_id = null` and `confidence = low`. The Claim Generator will create the record with a flagged-for-review predicate rather than dropping it.
- **Conflicting candidate detected:** Include the candidate with a `conflict_flag = true` and the ID of the existing claim that it conflicts with. Do not attempt to resolve the conflict. Conflict resolution is a human review action.

---

## 6. Component: Claim Generator

The Claim Generator receives structured claim candidates from the Memory Extractor and is the only component authorized to write to the `claims` table. It validates each candidate before writing and handles supersession when a correction is involved.

### 6.1 Responsibilities

- Receive claim candidates from the Memory Extractor (via Orchestrator)
- For each candidate:
  - Validate that `predicate_id` exists in `claim_predicates` and that the value type is consistent with the predicate's expected type
  - Validate that `subject_entity_id` exists and is accessible within this LifeBook
  - Determine whether this is a new claim or a correction of an existing one
- For new claims: insert into `claims` with:
  - `submission_origin = 'ai_assisted'`
  - `review_status = 'pending'`
  - `ai_generated = true`
  - `producing_agent_code` — from the active context manifest's agent code
  - `context_manifest_id` — the active manifest ID
  - `certainty_qualifier` — from the Memory Extractor's classification
  - `source_quote` — the verbatim excerpt
- For corrections (conflict_flag = true or explicit user correction): create the new claim as above, then set `superseded_by_id` on the prior claim and transition its `dispute_status` to `superseded`
- Return written claim IDs to the Orchestrator for inclusion in the turn response

### 6.1.1 Event Records Created from Conversation Inference

When a conversation turn implies an event (e.g., a birth date claim implies a birth event, a wedding story implies a marriage event), the Claim Generator may create event records in the `events` table as a structural byproduct of claim writing.

**All such event records must carry `submission_origin = 'ai_assisted'` regardless of who initiated the session.**

This is a firm governance constraint approved by the DP (2026-07-27). A steward-initiated session does not transfer steward authorship to AI-inferred records. The authorship rule is about who created the record, not who initiated the session.

Specifically:
- A steward opens a conversation and says "Marta was born July 14, 1947 in Poltava." The Claim Generator creates a birth date claim AND a birth event record. Both carry `submission_origin = 'ai_assisted'` and `review_status = 'pending'` — because both were created by the AI from inference, not by the steward directly.
- A steward directly creates an event through the API (`POST /api/v1/events` with explicit steward authorship) — that event carries `submission_origin = 'steward_direct'` and is auto-promoted to `review_status = 'steward_reviewed'` by a database trigger.

The Claim Generator must never assign `submission_origin = 'steward_direct'` to any record it creates. That designation belongs exclusively to records created through the direct steward authorship path, not the AI conversation path.

### 6.2 What It Does NOT Do

- Does not analyze conversation turns. It receives pre-analyzed candidates; it does not re-interpret user input.
- Does not promote `review_status` beyond `pending`. A claim written by AI is always `pending` until a human reviews it. The Claim Generator has no authority to approve its own output.
- Does not write claims with `evidence_status` above `inferred`. Elevation to `supported` or `corroborated` requires human review.
- Does not delete or overwrite existing claims. Corrections are handled via supersession only.
- Does not write claims for predicates that do not exist in `claim_predicates`. Unknown predicates are flagged for steward attention rather than silently creating invalid records.
- Does not assign `submission_origin = 'steward_direct'` to any record it creates. This designation is reserved for records created through direct steward authorship paths, never through AI conversation inference.

### 6.3 Communication with Other Components

The Claim Generator is invoked by the Orchestrator. It queries `claim_predicates` and `entities` tables for validation. It writes to `claims`. It returns written IDs to the Orchestrator.

### 6.4 Failure Handling

- **Predicate not found:** Do not write the claim. Log the unknown predicate text. Create a steward notification (or add to the thread summary note) that a potential fact could not be captured due to an unmapped predicate.
- **Entity not found:** Do not write the claim. Log the entity reference. Flag for steward review — the entity may need to be created first.
- **Database write fails:** Log the failure. Return the error to the Orchestrator. The Orchestrator notes the failed extraction in the turn response. The conversation is not blocked.
- **Supersession target not found:** Write the new claim without setting supersession. Flag the orphaned supersession for steward review.

---

## 7. Component: Upload Coordinator

The Upload Coordinator manages the full lifecycle of an artifact upload triggered by the conversation: from generating the artifact record and signed URL, through monitoring completion, to attaching the artifact to the appropriate thread and narrative records.

### 7.1 Responsibilities

- Receive the upload trigger from the Orchestrator (invoked when an upload offer is appropriate)
- Create an artifact record in `pending_upload` state via the Artifacts API
- Return the signed upload URL to the Orchestrator for inclusion in the turn response
- Receive upload completion notification via the storage webhook (`POST /api/v1/webhooks/storage`)
- On completion: call `POST /api/v1/artifacts/{id}/finalize` to set `upload_state = 'received'`
- Attach the artifact to the thread and any relevant narrative or event via `POST /api/v1/artifact-links`
- Mark the associated obligation as fulfilled
- Emit an internal event to the Orchestrator notifying that the thread should resume if it was in `pending_materials` state
- On upload failure: keep the obligation open; note the failure in the thread summary

### 7.2 What It Does NOT Do

- Does not handle file bytes. Files go directly from client to storage using the signed URL. The Upload Coordinator only manages record state.
- Does not approve or validate the artifact's content. Uploaded artifacts enter at `validity_state = 'pending_review'` and wait for steward review. The Upload Coordinator does not bypass this.
- Does not determine where an artifact belongs narratively. Attachment decisions are made by the Orchestrator based on conversation context; the Upload Coordinator executes them.
- Does not generate or store the signed URL beyond the duration of the upload offer. The URL is passed through the turn response and is not retained.

### 7.3 Communication with Other Components

The Upload Coordinator is invoked by the Orchestrator. It calls the Artifacts API endpoints directly. It receives webhook callbacks from the storage layer. On completion or failure, it notifies the Orchestrator so thread state can be updated.

### 7.4 Failure Handling

- **Signed URL generation fails:** Return error to Orchestrator. The upload offer is withdrawn from the turn response. The obligation remains open.
- **Upload timeout (no webhook received within TTL):** Mark the artifact as `upload_failed`. Keep the obligation open with an updated `followup_after`. On the user's next session, the Orchestrator will surface the unfulfilled obligation naturally.
- **Finalize call fails:** Retry up to 3 times with exponential backoff. If all retries fail, mark the artifact for manual review. Do not mark the obligation as fulfilled until finalization succeeds.
- **Attachment fails:** Log the failure. The artifact exists in the database (finalized) but is not linked to the narrative or event. The Orchestrator is notified; the steward is flagged to attach it manually from the review queue.

---

## 8. Component: Invitation Manager

The Invitation Manager handles the creation and provisioning of invitations for family members or contributors. It operates at the boundary between the conversation and the membership/access model.

### 8.1 Responsibilities

- Receive the invitation trigger from the Orchestrator
- Create an invitation record via `POST /api/v1/threads/{id}/invitations`
- Send the invitation email (v1: transactional email via configured provider)
- Create a pending `invitation` obligation on the thread
- Update thread state to `pending_materials` if appropriate
- When an invitee accepts and joins:
  - Provision `contributor` role (or `viewer` per invitation configuration) in `lifebook_memberships`
  - Brief the invitee on thread context: provide the thread summary appropriate to their role — this is the Context Manager's thread summary for `contributor` profiles, which excludes steward-private information
  - Surface the contribution prompt (if one was specified in the invitation)
  - Mark the invitation obligation as fulfilled

### 8.2 What It Does NOT Do

- Does not grant invitees access to the full LifeBook without steward configuration. Access is scoped to the thread and the LifeBook at the `contributor` role level. Contributors do not inherit steward access.
- Does not surface steward-private information (claims, narratives, or artifacts with `access_classification = restricted` or `private`) to invitees. The thread summary delivered to an invitee is constructed under the `respectful_generation` context profile, which excludes restricted data.
- Does not create membership records without an accepted invitation. Provisioning is triggered by the invitee's explicit acceptance, not by the invitation's creation.
- Does not send follow-up reminders to invitees beyond the configured expiry period. Expired invitations must be reissued by the steward.

### 8.3 Communication with Other Components

The Invitation Manager is invoked by the Orchestrator. It calls the Invitations API endpoints. When an invitee joins, it calls the Context Manager to produce the role-appropriate thread summary for the briefing. It notifies the Orchestrator when the obligation is fulfilled so the thread can resume.

### 8.4 Failure Handling

- **Email delivery fails:** Create the invitation record. Note delivery failure. Return the invitation ID to the steward — they can share the invitation link directly if needed. Obligation remains open.
- **Invitee joins but membership provisioning fails:** Do not allow access. Log the failure. Alert the steward. Do not mark the obligation as fulfilled until provisioning is confirmed.
- **Thread summary generation fails for briefing:** Invitee is onboarded with a minimal, safe briefing: "You've been invited to contribute to a LifeBook story." The full briefing is retried asynchronously.
- **Invitation expires without acceptance:** Transition the obligation to archived. Do not delete the invitation record. The steward may reissue.

---

## 9. Component Interaction Flow

The following describes a complete turn from user input to AI response with claim extraction. This is the standard case for a productive conversation turn.

```
USER INPUT: "My wife and I were married on October 27, 1983."

  1. API Layer
     └─ POST /api/v1/threads/{id}/messages
        body: { content: "My wife...", context_manifest_id, client_turn_id }
        │
        ▼
  2. Conversation Orchestrator
     ├─ Retrieves thread record (state: active)
     ├─ Retrieves pending obligations (none due)
     ├─ Delegates to: Context Manager
     │
     ▼
  3. Context Manager
     ├─ Validates context manifest (agent: conversation_orchestrator_v1)
     ├─ Retrieves thread summary: "First conversation — no prior context"
     ├─ Retrieves entity claims for anchor entity: minimal (first turn)
     ├─ Composes system prompt:
     │     [persona] + [thread summary] + [obligations: none] + [entity facts: minimal]
     └─ Returns composed prompt context to Orchestrator
        │
        ▼
  4. Conversation Orchestrator
     └─ Invokes LLM with composed context + user input
        │
        ▼
  5. LLM Response
     └─ "That sounds like a meaningful day. Do you have any photos or documents 
         from your wedding that you'd like to preserve?"
        │
        ▼
  6. Conversation Orchestrator
     ├─ Evaluates response for upload offer signal: YES (wedding mentioned, no prior offer)
     ├─ Delegates extraction to: Memory Extractor
     │
     ▼
  7. Memory Extractor
     ├─ Identifies: "married on October 27, 1983" → claim candidate
     │     subject_entity_id: ent_xxx (wife), predicate_id: pred_married_on
     │     value_date: 1983-10-27, confidence: high, certainty_qualifier: definite
     │     source_quote: "My wife and I were married on October 27, 1983."
     └─ Returns: [1 candidate] to Orchestrator
        │
        ▼
  8. Conversation Orchestrator
     └─ Passes candidates to: Claim Generator
        │
        ▼
  9. Claim Generator
     ├─ Validates predicate: pred_married_on exists ✓
     ├─ Validates entity: ent_xxx accessible ✓
     ├─ No existing claim on this predicate for this entity → new claim
     ├─ Writes to claims: {
     │     subject_entity_id: ent_xxx,
     │     predicate_id: pred_married_on,
     │     value_date: 1983-10-27,
     │     submission_origin: 'ai_assisted',
     │     review_status: 'pending',
     │     ai_generated: true,
     │     producing_agent_code: 'conversation_orchestrator_v1',
     │     context_manifest_id: mnf_xxx
     │   }
     └─ Returns: { claim_id: clm_xxx } to Orchestrator
        │
        ▼
 10. Conversation Orchestrator
     ├─ Triggers: Upload Coordinator (upload offer for wedding materials)
     │     Upload Coordinator creates obligation: obl_xxx (type: artifact_upload)
     ├─ Updates thread: last_activity_at, thread_summary digest
     └─ Assembles API response
        │
        ▼
 11. API Response:
     {
       "turn_id": "trn_...",
       "response": {
         "content": "That sounds like a meaningful day...",
         "upload_offer": { "offered": true, "obligation_id": "obl_xxx" }
       },
       "extractions": {
         "claims_created": [{ "id": "clm_xxx", "review_status": "pending" }]
       },
       "thread_state": "active"
     }
```

The entire flow from POST to response completes in a single synchronous request. Upload completion arrives asynchronously via webhook.

---

## 10. Governing Constraints

### 10.1 Why the Orchestrator Does Not Write Claims

The Orchestrator could, in principle, write claims directly after extracting them. It does not, because:

1. **Separation of validation:** The Claim Generator validates predicate existence, entity existence, type correctness, and supersession logic. These rules are not the Orchestrator's concern. Mixing them creates a single point of failure where a logic bug in the Orchestrator could write invalid records.

2. **Single write authority:** Having one component (Claim Generator) as the exclusive writer to `claims` makes provenance auditing unambiguous. Every claim has a single authoring path.

3. **Testability:** The Claim Generator can be tested independently against the full spectrum of predicate and entity cases without invoking the LLM. The Orchestrator can be tested without a live database.

4. **Future extensibility:** Claims may in future arrive from non-conversation sources (document scanning, bulk import). The Claim Generator is the single governance-enforcing writer regardless of origin.

### 10.2 How Each Component Respects "Conversation is Ephemeral. History is Permanent."

| Component | How the Principle Applies |
|---|---|
| **Orchestrator** | Does not persist conversation turns. Manages `last_activity_at` and `thread_summary` — structured state, not transcript. |
| **Context Manager** | Builds prompts from governed records (thread summary, claims) — not from stored chat history. Recent in-session turns are buffered transiently; they are not stored. |
| **Memory Extractor** | Operates on the current turn only. Has no access to prior turns except through the thread summary. The conversation is ephemeral to it. |
| **Claim Generator** | Writes only to governed records with full provenance. The claim is the permanent artifact; the conversation that produced it is not. |
| **Upload Coordinator** | The artifact is the permanent record. The conversation turn that prompted the upload is not stored with it — only the `context_manifest_id` for traceability. |
| **Invitation Manager** | The obligation and membership are the permanent records. The conversational exchange that produced the invitation is not retained. |

### 10.3 Context Manifests as the Traceability Spine

Every governed write from this layer carries a `context_manifest_id`. This is not optional. A claim, artifact, or obligation created without a manifest is a governance violation.

The manifest records: which agent, which permitted data categories, which output destinations, and the time window of the session. It is the chain of custody between the conversation (ephemeral) and the governed record (permanent). Without it, provenance cannot be established and the record cannot be fully trusted in a review context.

### 10.4 No AI Self-Promotion

No component in this layer has the authority to promote a record past `review_status = pending` or `evidence_status = inferred`. This is a hard constraint, not a convention. The AI writes candidates; the steward decides what is true. The orchestration layer is in service of that decision, not a substitute for it.

---

## 11. Open Questions for Implementation

- **Session boundaries:** What is the correct strategy for the transient turn buffer when a user's session spans multiple browser tabs or devices? The thread summary is the persistence mechanism, but turns in progress on one device should not be lost if a second device opens.
- **Context manifest lifecycle:** Should a context manifest cover one turn or one session? A per-session manifest is more efficient; a per-turn manifest provides finer-grained audit trails. Design decision pending.
- **Memory Extractor model:** Should the extraction step use the same LLM as the conversational response, or a separate, smaller extraction-specific model? A dedicated extraction model reduces cost and provides cleaner separation, but requires two inference calls per turn.
- **Thread summary generation:** Who generates the updated `thread_summary` after a turn — the Orchestrator (using the LLM) or a separate summarization step? If the Orchestrator generates it, it adds latency to every turn. If deferred, there is a window where the summary is stale.
- **Conflict escalation:** When the Memory Extractor flags a conflict between a new candidate and an existing claim, the current design flags it for human review. Should the Orchestrator also surface the conflict inline in the conversation ("I noticed this might differ from what you told me before — would you like to correct it?")? That is a UX question with architecture implications.

---

*AI_ORCHESTRATION_LAYER.md — LifeBook HQ — Conversation Experience v1 — 2026-07-27*
