# M0004_DP_REVIEW.md
## LifeBook HQ — Pre-Migration Policy Decisions
**Status:** Awaiting DP decisions — M0004 authoring is blocked until all five are resolved  
**Milestone:** Conversation Experience v1 — M0004 Conversation Threading Layer  
**Date:** 2026-07-27  
**Source:** ARCHITECTURE_IMPACT_ASSESSMENT.md, Section 7

---

> These are policy decisions, not implementation details. Each one has downstream
> consequences for governance, security, and extensibility that cannot be easily reversed
> once the migration is applied. They are presented here for formal DP review and decision.

---

## Decision 1 — Foreign Key Strategy for `storage_provider_code`

### The Decision

When the `artifacts` table references the `storage_providers` vocabulary table, should the FK column reference `storage_providers(id)` (UUID primary key) or `storage_providers(code)` (short text identifier)?

### Why This Matters Architecturally

The FK strategy on a vocabulary reference is not merely a style preference. It determines:
- Whether the storage provider identifier is stable across renames and reconfigurations
- Whether the artifacts table can be read meaningfully without a join
- Whether RLS policies and audit queries can quickly identify storage provider context
- Whether future migrations can rename a storage provider code without cascading updates across potentially millions of artifact rows

LifeBook's established vocabulary table pattern uses UUID primary keys throughout (`id` columns), with human-readable `code` columns as display aliases. If we use `code` as a FK target, we introduce an inconsistency with that pattern and require a `UNIQUE` constraint on `storage_providers.code` to make it a valid FK target.

### The Options

**Option A — FK to `storage_providers(id)` (UUID)**

The artifact row stores `storage_provider_id UUID REFERENCES storage_providers(id)`. This is consistent with all other FK relationships in the schema. The human-readable provider name is obtained via join.

Requires renaming the proposed column from `storage_provider_code` to `storage_provider_id`.

**Option B — FK to `storage_providers(code)` (TEXT)**

The artifact row stores `storage_provider_code TEXT REFERENCES storage_providers(code)`. This makes the artifact row self-describing without a join — you can read `storage_provider_code = 'supabase_storage'` directly. Requires adding `UNIQUE (code)` to `storage_providers`.

**Option C — Denormalized TEXT column, no FK**

Store the provider identifier as a plain TEXT column with no referential constraint. Simple, but sacrifices integrity: nothing prevents a typo, and provider records can be deleted without cascade detection.

### Recommendation: Option A — FK to `storage_providers(id)`

The schema is UUID-primary throughout. Option A maintains that consistency without exception. The human-readable code is available in every query via a join and via the artifact's `context_manifest_id` if needed for audit purposes.

Option B would require explaining to every future contributor why this one table uses a text FK when nothing else does. That cognitive overhead compounds over time, and the "self-describing row" benefit is marginal: queries against the review queue and upload pipeline will always join to storage_providers anyway.

Option C should not be considered. Unguarded text columns for foreign entity references contradict Principle VII (the migration chain is the truth) and invite silent data corruption.

### Long-Term Implications

Choosing Option A means the column is renamed to `storage_provider_id`. All documentation referencing `storage_provider_code` as a column name should be updated. The `storage_providers` vocabulary table requires no change — its existing UUID primary key is the FK target.

If LifeBook ever supports multiple storage backends (Supabase Storage, S3, Azure Blob), the `storage_provider_id` FK is the correct anchor for that expansion. Provider-specific configuration (bucket names, regions, credential references) can live in the `storage_providers` table, not in artifact rows.

### Governance and Security Impact

RLS policies on artifacts do not need to read the storage provider identity — they enforce lifebook-scoped access, not provider-scoped access. So the FK strategy has no direct RLS consequence. From a security audit perspective, UUID FKs are opaque (which is appropriate — storage provider identity should not be exposed in client-facing API responses).

---

## Decision 2 — Upload State Cardinality on `artifacts`

### The Decision

How many states should the `upload_state` lifecycle on the `artifacts` table have? The proposed design has five: `pending_upload → received → processing → validated → failed`. Is that the right model, or should it be simpler?

### Why This Matters Architecturally

Upload state is a workflow state machine. Its cardinality determines:
- What the review queue UI needs to display
- Whether the system can distinguish "not yet uploaded" from "uploaded but pending virus scan" from "uploaded and cleared"
- How failures are categorised and surfaced to the steward
- Whether a processing step (virus scan, format validation, thumbnail generation) is architecturally acknowledged or hidden

If the state is too coarse (binary: received / failed), the system cannot communicate meaningful progress to the steward and cannot distinguish between "we haven't received the file yet" and "we received it but something went wrong after receipt." If the state is too granular, it exposes internal processing stages to the application layer and creates more states to keep consistent.

### The Options

**Option A — Five states (proposed)**
`pending_upload | received | processing | validated | failed`

Exposes the processing phase explicitly. The steward-facing review queue can show "Processing…" as a real state. Allows future processing steps to be added without changing the state machine.

**Option B — Three states**
`pending_upload | received | failed`

Collapses `processing` and `validated` into a single `received` terminal state. Processing is internal — the steward only sees "not yet" or "done." Simpler to implement and display.

**Option C — Four states (recommended)**
`pending_upload | received | validated | failed`

Removes `processing` (internal — the system handles it without surfacing a transient state) but retains `validated` as a meaningful terminal state distinct from `received`. A file can be `received` (the bytes are there) without yet being `validated` (format checked, virus scanned, thumbnailed). These are genuinely different: an artifact in `received` state may still fail validation.

### Recommendation: Option C — Four states

`processing` is an internal infrastructure state. It has no governance meaning — it simply means "our systems are working on it." Surfacing it to the steward creates UI obligations (what does "Processing" mean to someone uploading a family photo?) without corresponding value.

`validated`, however, is governance-meaningful: it is the state at which the artifact becomes eligible for steward review and promotion to `validity_state = 'valid'`. The distinction between received-but-not-validated and fully-validated is real and affects the review workflow.

Four states: `pending_upload → received → validated → failed`. The `failed` state can include a `notes` field explaining whether the failure occurred at receipt, validation, or some other stage.

### Long-Term Implications

Option C creates a clean handoff point: the upload pipeline moves artifacts to `validated`, then the steward review workflow promotes them to `validity_state = 'valid'`. These are two separate workflows with two separate actors (the system and the steward), and the state machine reflects that correctly.

If a future processing capability is added (e.g., AI-generated alt text, date extraction from photograph metadata), it can run as part of the `received → validated` transition without needing a new state. The state machine remains stable.

### Governance and Security Impact

The review queue query filters on `validity_state = 'pending_review'` for steward action, and `upload_state = 'validated'` as a precondition. This means no artifact enters the review queue until it has passed system validation — protecting the steward from being asked to review incomplete or malformed uploads. This is the correct governance behaviour and Option C supports it cleanly.

---

## Decision 3 — Thread Visibility for Contributors

### The Decision

When a family member (contributor role) is invited to contribute to a LifeBook thread, should they be able to see the thread state and conversation summary? Or should threads remain steward-private, with contributors only seeing the specific narrative or claim they've been asked to contribute to?

### Why This Matters Architecturally

This is fundamentally a question about what "contribution" means in LifeBook's model. It has direct consequences for:
- The RLS policies on `conversation_threads` and `thread_obligations`
- Whether the contributor-facing interface needs to render thread context
- Whether thread summaries contain steward-private information that must be filtered before sharing
- Whether invitation flows need to include a "what the contributor will see" scope

Principle V states: "Families Contribute, Stewards Decide." The question is not whether contributors can govern — they cannot. The question is how much context they receive about the thread they're contributing to.

### The Options

**Option A — Threads are steward-private**

Contributors never see `conversation_threads` rows or `thread_summary` content. When they accept an invitation, they see only the specific narrative, claim, or event they've been invited to add to. The invitation creates a bounded scope: "Add your memories of the 1992 immigration."

RLS: `pol_threads_select_contributor` does not exist. Contributors have no SELECT on `conversation_threads`.

**Option B — Contributors see thread summary only**

Contributors can read the `thread_summary` of threads they've been explicitly linked to via an obligation or invitation. They cannot see thread state, pending obligations for other contributors, or any information about other open threads.

RLS: `pol_threads_select_contributor` permits SELECT on `thread_summary` only for threads where the contributor has an active invitation obligation. (This may require a view rather than a direct table policy, since column-level RLS is not possible in PostgreSQL without additional mechanisms.)

**Option C — Contributors see full thread state**

Contributors see the thread state, summary, and their own obligations. They cannot see obligations assigned to other contributors or steward-private threads.

### Recommendation: Option B — Contributors see thread summary only

Option A (threads fully steward-private) is safe but creates a poor contributor experience. If Andriy is invited to contribute his memories of the 1992 immigration and he can see nothing about what's already been captured, he's contributing blind. He may duplicate what Oksana has already recorded, or miss gaps that the thread summary would have surfaced.

Option C exposes too much. Thread state transitions, obligation counts, and the names of other pending contributors are governance information that belongs to the steward.

Option B — summary only — threads the needle. The thread summary (`thread_summary TEXT`) is a curated, auto-generated digest written in past-tense descriptive language. It contains no obligation metadata, no other contributor identities, and no raw conversation content. It is exactly what a contributor needs to orient themselves.

**Implementation note:** Since PostgreSQL RLS cannot restrict access to specific columns, Option B likely requires a view: `contributor_thread_view` that exposes only `id`, `topic_label`, `thread_summary`, and `anchor_entity_id` for threads where the contributor has an active invitation obligation. The underlying `conversation_threads` table retains full steward-only access.

### Long-Term Implications

The `contributor_thread_view` pattern establishes a precedent for data shaping at the view layer rather than the application layer. This is the correct approach for a governance-first system: the database enforces the access boundary, not application logic.

As LifeBook introduces more contributor-facing features (family-contributed narratives, contributor-created events), the view pattern scales: add columns to the view, update the RLS, without changing the underlying table structure.

### Governance and Security Impact

This decision directly determines whether thread summaries are treated as steward-private governance records or shareable context documents. Under Option B, thread summaries must be authored with the assumption that contributors may read them. This is a design constraint on the summary generation function (`fn_thread_continuation_prompt`): it must produce output that is safe for contributor visibility, meaning no obligation metadata, no raw conversation excerpts, and no reference to access-classified claims that the contributor may not be permitted to see.

The RLS impact: one additional view with its own SELECT policy, rather than a column-level policy on the base table.

---

## Decision 4 — `anchor_narrative_id` Timing and Retroactivity

### The Decision

The `conversation_threads` table includes `anchor_narrative_id UUID NULL REFERENCES narratives(id)`. Since narratives are typically created *during* a thread (not before it), should this column be set retroactively as the thread produces a narrative, or should threads only anchor to events and entities at creation time?

### Why This Matters Architecturally

Thread anchors serve a specific function: they let the system surface related material (prior claims, existing narratives, uploaded artifacts) as context for the ongoing conversation. The anchor is a pointer that says "this thread is about this governed record."

The timing question has two components:
1. **When can the anchor be set?** At creation only, or at any point during the thread's lifecycle?
2. **Who sets it?** The Orchestrator (AI), or the steward explicitly?

Entities (`anchor_entity_id`) and events (`anchor_event_id`) can reasonably be set at thread creation because they often exist before the thread begins, or can be created at the moment a thread opens. Narratives are different: a narrative is typically the *product* of a thread, not a pre-existing anchor for it.

### The Options

**Option A — Narrative anchor set retroactively, automatically**

When the Orchestrator creates a narrative from a thread's content, it sets `anchor_narrative_id` on the thread. The anchor points to the narrative this thread produced. This is a post-creation update triggered by the Claim Generator / narrative creation workflow.

Risk: the anchor represents a product of the thread, not a pre-existing subject. It conflates "what this thread produced" with "what this thread is about."

**Option B — Narrative anchor set retroactively, steward-initiated**

The `anchor_narrative_id` column exists but is only set when the steward explicitly links the thread to an existing narrative — typically a narrative that predates the thread and is being extended or enriched by it. The Orchestrator never sets this anchor automatically.

This is appropriate when a thread is opened specifically to add to an existing narrative (e.g., "Let's continue the immigration story started last week").

**Option C — No narrative anchor — threads anchor to entities and events only**

Remove `anchor_narrative_id` from the proposed schema. Threads are anchored to entities (the person the story is about) and events (the occasion being discussed). The relationship between a thread and the narratives it produced is captured through `narrative_artifact_links` and claim provenance (`context_manifest_id`), not through the thread anchor.

### Recommendation: Option B — Retroactive, steward-initiated only

Option A creates a semantic confusion: an anchor should identify the subject of a thread, not its output. If a thread produces narrative N, setting `anchor_narrative_id = N` means the thread points to its own product — which is circular and misleading when used to answer the question "what is this thread about?"

Option C is clean and defensible, but removes a capability that will genuinely be used: returning users who say "I want to add to that immigration story" are describing exactly the situation where `anchor_narrative_id` provides value — the thread is opened *about* an existing narrative.

Option B preserves the column's genuine use case (threading a conversation around a pre-existing narrative) without the circular-reference problem of Option A. The Orchestrator checks for `anchor_narrative_id` when building context: if set, it loads the existing narrative as context. If not set, the thread may produce a new narrative, which is linked via claim provenance but does not retroactively become the anchor.

**Schema implication:** The column remains `anchor_narrative_id UUID NULL REFERENCES narratives(id)`. No change to the proposed DDL. The change is in how the Orchestrator is instructed to use it: set only when the thread is explicitly opened against an existing narrative, never auto-set as output.

### Long-Term Implications

This decision separates two distinct patterns that should remain distinct throughout LifeBook's evolution:
- **Production pattern:** Thread → produces → narratives/claims (tracked via provenance columns)
- **Enrichment pattern:** Thread → extends → existing narrative (tracked via `anchor_narrative_id`)

Keeping these separate prevents the thread model from becoming an ambiguous record of both what was discussed and what was produced. Future thread browsing, search, and continuation logic can use the anchor to filter threads by subject without confusing "threads about the immigration story" with "threads that produced the immigration story."

### Governance and Security Impact

The steward-initiated requirement for Option B means that `anchor_narrative_id` can only be set by a steward-role user, not by the AI. This is consistent with Principle IV (the record is governed, not inferred) and Principle V (stewards decide). The AI may suggest an anchor ("This seems connected to the immigration story — shall I link them?"), but the write happens only on steward confirmation.

---

## Decision 5 — `review_status` Gate on Events

### The Decision

Claims and narratives both have `review_status` columns requiring steward promotion before they enter the authoritative record. M0004 proposes adding `review_status` to events for consistency. However, events in LifeBook are frequently created *implicitly* — the system creates an event record when a claim implies one (e.g., a birth date claim implies a birth event). Should implicit event creation require the same review gate?

### Why This Matters Architecturally

This is the sharpest governance question of the five. The answer defines where the boundary sits between "inferred structure" and "governed record" in LifeBook's data model.

If events require steward review before they are authoritative:
- Implicit events (created by the system from claim data) sit in `pending` status until a steward promotes them
- The event model is fully consistent with claims and narratives
- The review queue expands to include events, which can be numerous

If events are exempt from the review gate:
- Events created by the system are immediately authoritative
- This is a deliberate exception to the governance model for structural/inferential records
- It creates a two-tier system: governed records (claims, narratives, artifacts) and structural scaffolding (events, entities) that is auto-authorised

### The Options

**Option A — Full review gate on all events**

All events — whether created explicitly by a steward or implicitly by the system — require `review_status = 'pending'` until promoted. The review queue includes events.

Consistent with Principle IV. Administratively heavier: a session that generates 5 claims about a military service period may implicitly generate an event record, which then requires steward review. The steward may have to review both the claims and the structural record that organises them.

**Option B — Review gate on AI-generated events only**

Events created by a steward directly (`submission_origin = 'steward_direct'`) are immediately `review_status = 'steward_reviewed'`. Events created by the AI or implicitly from claim inference (`submission_origin = 'ai_assisted'`) require `review_status = 'pending'`.

This is the same rule applied to claims and narratives. The distinction is based on `submission_origin`, not on event type.

**Option C — No review gate on events — events are structural scaffolding**

Events carry `submission_origin` for provenance tracking but no `review_status`. They are structural records that organise claims and narratives, not governed facts in their own right. The review gate applies to claims and narratives because those carry factual assertions about the subject; events merely provide the organisational structure for those facts.

### Recommendation: Option B — Review gate on AI-generated events only

Option A is consistent but adds review burden without proportionate value. Event records — especially implicit ones — are structural. An event record that says "military service period, approximately 1943–1946" is less an assertion of fact and more an organisational label. Requiring a steward to explicitly promote every structural record created during a conversation creates friction that conflicts with Principle III (the person sets the pace) and risks making the review queue unmanageable.

Option C goes too far in the other direction. If events carry no review gate, then an AI agent could create an event record asserting that a subject was in a particular place at a particular time, and that record would immediately be authoritative — bypassing the governance model entirely for structural records.

Option B resolves the tension correctly: it applies the same rule as claims and narratives (the gate is based on `submission_origin`), but makes steward-created events immediately authoritative. A steward opening LifeBook and explicitly creating a "Marriage in Kyiv, 1971" event has asserted that fact with their own authority. An AI-created event from conversation inference has not.

**Boundary clarification (including DP refinement, 2026-07-27):** Option B means the `review_status` column is added to `events` as proposed in M0004. The default is `pending`. Events created with `submission_origin = 'steward_direct'` have their `review_status` set to `steward_reviewed` at insert time via a BEFORE INSERT trigger.

**Critical distinction (DP-refined):** Steward initiation of a session or workflow does NOT make AI-inferred events authoritative. Only events explicitly authored by a steward — where the steward directly creates the event record — qualify for `submission_origin = 'steward_direct'`. When the AI creates an event record from conversation inference during a steward-initiated session, that event must carry `submission_origin = 'ai_assisted'` and therefore remains `review_status = 'pending'`. The authorship rule is about the record's creator, not the session's initiator. This is enforced in two places: the Claim Generator (which assigns `submission_origin` at write time) and the trigger (which auto-promotes only `steward_direct` events).

### Long-Term Implications

Option B means the review queue expands from (claims + narratives + artifacts) to (claims + narratives + artifacts + AI-generated events). The review queue UI must handle event records. In practice, AI-generated events will typically be few and clearly described — a well-run conversation about a period of someone's life produces a handful of event records, not dozens. The review burden is manageable.

The trigger approach for auto-promoting steward-direct events creates a pattern that can be extended: future tables that require the same distinction can use the same trigger pattern. This is a reusable governance mechanism, not a one-off fix.

### Governance and Security Impact

Option B produces a fully consistent governance model: every record in LifeBook that carries a factual assertion (claims, narratives, events) requires steward promotion if AI-generated. The only exception is structural scaffolding created directly by the steward (entities, explicitly-created events), which is self-governing by virtue of steward authority.

This also eliminates a potential attack surface: if events had no review gate, a compromised AI agent could create event records that implicitly assert facts about a subject — facts that would be structurally authoritative without steward review. Option B prevents this. The `fn_user_is_agent()` check and the trigger-based `review_status` assignment work together to enforce the boundary.

---

## Summary Table

| # | Decision | Recommendation | Key Constraint |
|---|---|---|---|
| 1 | FK strategy for storage provider reference | Option A — FK to `storage_providers(id)` (UUID) | Rename column `storage_provider_code` → `storage_provider_id` |
| 2 | Upload state cardinality | Option C — 4 states: `pending_upload → received → validated → failed` | Drop `processing` state; `failed` notes explain failure stage |
| 3 | Thread visibility for contributors | Option B — Summary-only via a `contributor_thread_view` | View layer, not column-level RLS; summary must be safe for contributor reading |
| 4 | `anchor_narrative_id` timing | Option B — Retroactive, steward-initiated only | AI never sets this anchor; steward-initiated enrichment pattern only |
| 5 | `review_status` gate on events | Option B — Gate on AI-generated events; steward-direct events auto-promoted | Trigger-based auto-promotion at insert for `submission_origin = 'steward_direct'` |

---

## What Happens After DP Decision

Once all five decisions are recorded by the DP:

1. The column rename in Decision 1 is reflected in M0004 DDL before authoring
2. The four-state model in Decision 2 replaces the five-state model in all references
3. The `contributor_thread_view` is added as a Migration Phase within M0004
4. The `anchor_narrative_id` usage constraint is documented in AI_ORCHESTRATION_LAYER.md (Orchestrator section)
5. The trigger for event `review_status` auto-promotion is added as a Migration Phase within M0004

M0004 authoring may then proceed.

---

*M0004_DP_REVIEW.md — LifeBook HQ — 2026-07-27*
