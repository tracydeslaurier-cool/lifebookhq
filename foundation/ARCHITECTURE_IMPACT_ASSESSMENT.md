# ARCHITECTURE_IMPACT_ASSESSMENT.md
## LifeBook HQ — Conversation Experience v1
**Status:** Design — requires DP review before migration authoring  
**Milestone:** Conversation Experience v1  
**Date:** 2026-07-27

---

## 1. Assessment Method

The current schema (post M0001–M0003) was reviewed against the requirements in:
- CONVERSATION_STATE_ENGINE.md
- CONTEXTUAL_UPLOAD_FLOW.md
- THREAD_CONTINUATION_MODEL.md
- CONVERSATION_CONTROLS.md
- FOUNDER_ACCEPTANCE_JOURNEY.md

For each Conversation Experience requirement, the existing schema was checked for coverage. Gaps are documented below. All changes are proposed as a new migration (M0004) per the migration philosophy.

---

## 2. Verdict

**The Conversation Experience cannot be implemented without schema changes.**

The existing schema (M0001–M0003) provides excellent foundations — the governance model, claims, artifacts, context manifests, and agent registry are all load-bearing for the conversation layer. However, four categories of gaps exist:

1. No conversation threading tables — the core of the State Engine has no persistence layer
2. Artifacts lack provenance and storage columns — cannot safely track AI-assisted uploads
3. Narratives and events lack full AI provenance — claims got these in M0003 Addendum; narratives and events did not
4. `artifact_source_links` only links to `sources` — cannot attach artifacts to narratives or events

None of these require modifying existing migrations. All are additive.

---

## 3. Gap Analysis

### 3.1 New Tables Required

#### 3.1.1 `conversation_threads`

**Purpose:** Persists the ConversationThread model from the State Engine design.

**Proposed definition:**
```sql
CREATE TABLE conversation_threads (
    id                  UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    lifebook_id         UUID        NOT NULL REFERENCES lifebooks(id),
    created_by_id       UUID        NULL REFERENCES user_profiles(id),
    topic_label         TEXT        NOT NULL,
    anchor_entity_id    UUID        NULL REFERENCES entities(id),
    anchor_event_id     UUID        NULL REFERENCES events(id),
    anchor_narrative_id UUID        NULL REFERENCES narratives(id),
    state               TEXT        NOT NULL DEFAULT 'active'
                            CHECK (state IN ('active','paused','pending_materials','complete','archived')),
    last_activity_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    dormant_since       TIMESTAMPTZ NULL,
    context_manifest_id UUID        NULL REFERENCES context_manifests(id),
    thread_summary      TEXT        NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**Notes:**
- `state` is a CHECK constraint rather than an ENUM because thread states are small and stable; no separate ENUM type is needed
- `anchor_*` columns are all nullable — a thread may not have a structured anchor when it begins
- `thread_summary` is auto-generated text used in continuation offers; updated periodically, not on every turn

#### 3.1.2 `thread_obligations`

**Purpose:** Persists pending obligations for each thread. Kept as a separate table (not JSONB on the thread) to support querying by type, state, and follow-up date.

**Proposed definition:**
```sql
CREATE TABLE thread_obligations (
    id                  UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    thread_id           UUID        NOT NULL REFERENCES conversation_threads(id),
    obligation_type     TEXT        NOT NULL
                            CHECK (obligation_type IN ('artifact_upload','invitation','fact_verification','correction','continuation')),
    obligation_state    TEXT        NOT NULL DEFAULT 'pending'
                            CHECK (obligation_state IN ('pending','offered','fulfilled','declined','archived')),
    label               TEXT        NOT NULL,
    claim_id            UUID        NULL REFERENCES claims(id),
    artifact_id         UUID        NULL REFERENCES artifacts(id),
    narrative_id        UUID        NULL REFERENCES narratives(id),
    offered_at          TIMESTAMPTZ NULL,
    declined_at         TIMESTAMPTZ NULL,
    fulfilled_at        TIMESTAMPTZ NULL,
    followup_after      TIMESTAMPTZ NULL,
    followup_count      SMALLINT    NOT NULL DEFAULT 0,
    max_followups       SMALLINT    NOT NULL DEFAULT 2,
    notes               TEXT        NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**Notes:**
- `obligation_type` and `obligation_state` use CHECK constraints for the same reason as thread state
- The nullable FKs (claim_id, artifact_id, narrative_id) allow an obligation to be anchored to the specific object it concerns
- `followup_count` and `max_followups` enforce the patience principle: obligations expire after max_followups re-offers

#### 3.1.3 `narrative_artifact_links`

**Purpose:** Attaches artifacts to narratives. The existing `artifact_source_links` only links to `sources`. The upload flow requires linking artifacts to the narrative they illustrate.

**Proposed definition:**
```sql
CREATE TABLE narrative_artifact_links (
    id              UUID    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    narrative_id    UUID    NOT NULL REFERENCES narratives(id),
    artifact_id     UUID    NOT NULL REFERENCES artifacts(id),
    link_role       TEXT    NULL,  -- 'primary', 'contextual', 'illustrative'
    link_note       TEXT    NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (narrative_id, artifact_id)
);
```

#### 3.1.4 `event_artifact_links`

**Purpose:** Attaches artifacts to events. Same rationale as narrative_artifact_links.

**Proposed definition:**
```sql
CREATE TABLE event_artifact_links (
    id              UUID    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    event_id        UUID    NOT NULL REFERENCES events(id),
    artifact_id     UUID    NOT NULL REFERENCES artifacts(id),
    link_role       TEXT    NULL,
    link_note       TEXT    NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (event_id, artifact_id)
);
```

---

### 3.2 New Columns Required on Existing Tables

#### 3.2.1 `artifacts` — provenance and storage

The artifacts table currently has no:
- `validity_state` (the ENUM `artifact_validity_state` exists in M0001 but was never applied to this table)
- `submission_origin` (claims have this; artifacts do not)
- `ai_generated` (claims have this; artifacts do not)
- `producing_agent_code` (claims have this; artifacts do not)
- `context_manifest_id` (claims have this; artifacts do not)
- `object_key` (no storage reference — required for signed URL generation)
- `storage_provider_code` (references `storage_providers` vocab table)
- `upload_state` (to track: pending_upload → received → validated)

**Proposed ALTER TABLE:**
```sql
ALTER TABLE artifacts
    ADD COLUMN validity_state        TEXT        NOT NULL DEFAULT 'pending_review'
                    CHECK (validity_state IN ('pending_review','valid','invalid','contested')),
    ADD COLUMN submission_origin     TEXT        NOT NULL DEFAULT 'steward_direct'
                    CHECK (submission_origin IN ('steward_direct','ai_assisted','family_contribution','external_import')),
    ADD COLUMN ai_generated          BOOLEAN     NOT NULL DEFAULT FALSE,
    ADD COLUMN producing_agent_code  TEXT        NULL,
    ADD COLUMN context_manifest_id   UUID        NULL REFERENCES context_manifests(id),
    ADD COLUMN object_key            TEXT        NULL,
    ADD COLUMN storage_provider_code TEXT        NULL REFERENCES storage_providers(code),
    ADD COLUMN upload_state          TEXT        NOT NULL DEFAULT 'pending_upload'
                    CHECK (upload_state IN ('pending_upload','received','processing','validated','failed'));
```

**Note on `artifact_validity_state` ENUM:** The ENUM type exists in M0001. However, for consistency with how claims/narratives handle their status fields (as TEXT with CHECK constraints, not typed ENUMs in the column definition), we use TEXT + CHECK here. The ENUM exists but is not the column type. This matches the established pattern.

#### 3.2.2 `narratives` — AI provenance

The Addendum in M0003 added `review_status` to narratives but not the full AI provenance set that claims received.

**Proposed ALTER TABLE:**
```sql
ALTER TABLE narratives
    ADD COLUMN submission_origin     TEXT        NOT NULL DEFAULT 'steward_direct'
                    CHECK (submission_origin IN ('steward_direct','ai_assisted','family_contribution')),
    ADD COLUMN ai_generated          BOOLEAN     NOT NULL DEFAULT FALSE,
    ADD COLUMN producing_agent_code  TEXT        NULL,
    ADD COLUMN context_manifest_id   UUID        NULL REFERENCES context_manifests(id);
```

#### 3.2.3 `events` — AI provenance

Events have no AI provenance columns at all.

**Proposed ALTER TABLE:**
```sql
ALTER TABLE events
    ADD COLUMN submission_origin     TEXT        NOT NULL DEFAULT 'steward_direct'
                    CHECK (submission_origin IN ('steward_direct','ai_assisted','family_contribution')),
    ADD COLUMN ai_generated          BOOLEAN     NOT NULL DEFAULT FALSE,
    ADD COLUMN producing_agent_code  TEXT        NULL,
    ADD COLUMN context_manifest_id   UUID        NULL REFERENCES context_manifests(id),
    ADD COLUMN review_status         TEXT        NOT NULL DEFAULT 'pending'
                    CHECK (review_status IN ('pending','steward_reviewed','policy_approved','rejected'));
```

---

### 3.3 New ENUM Values Required

No new ENUM types are required. The state fields use CHECK constraints per the established pattern. The existing `artifact_validity_state` ENUM type remains unused as a column type (but is retained in M0001 for future use if the pattern changes).

---

### 3.4 New Functions Required

#### 3.4.1 `fn_thread_continuation_prompt(p_thread_id UUID) RETURNS TEXT`

**Purpose:** Generates the natural-language continuation offer shown to a returning user. Reads thread state, pending obligations, and thread summary. Returns formatted text.

**Owner:** `governance_functions`  
**SECURITY DEFINER:** Yes (reads thread and obligation tables under consistent access rules)

#### 3.4.2 `fn_active_threads(p_lifebook_id UUID) RETURNS SETOF conversation_threads`

**Purpose:** Returns threads in `active` or `paused` state for a lifebook, ordered by last_activity_at. Used by the session-open continuation check.

**Owner:** `governance_functions`  
**SECURITY DEFINER:** Yes

#### 3.4.3 `fn_obligations_due(p_thread_id UUID) RETURNS SETOF thread_obligations`

**Purpose:** Returns obligations where `obligation_state IN ('pending','offered')` and `followup_after <= now()` and `followup_count < max_followups`. Drives re-offer logic.

**Owner:** `governance_functions`  
**SECURITY DEFINER:** Yes

---

### 3.5 New Indexes Required

```sql
-- Thread lookup by lifebook and state
CREATE INDEX idx_conversation_threads_lifebook_state
    ON conversation_threads(lifebook_id, state);

-- Thread lookup by last activity (for continuation ordering)
CREATE INDEX idx_conversation_threads_last_activity
    ON conversation_threads(lifebook_id, last_activity_at DESC);

-- Obligations due for followup
CREATE INDEX idx_thread_obligations_followup
    ON thread_obligations(thread_id, obligation_state, followup_after)
    WHERE obligation_state IN ('pending', 'offered');

-- Artifact upload state (for pending review queue)
CREATE INDEX idx_artifacts_upload_state
    ON artifacts(lifebook_id, upload_state)
    WHERE upload_state != 'validated';

-- Artifact validity state (for review queue)
CREATE INDEX idx_artifacts_validity_state
    ON artifacts(lifebook_id, validity_state)
    WHERE validity_state = 'pending_review';
```

---

### 3.6 New RLS Policies Required

All new tables require RLS. Pattern follows M0003.

#### `conversation_threads`
- `pol_threads_select_steward` — steward may select all threads for their lifebook
- `pol_threads_insert_steward` — steward may insert new threads
- `pol_threads_update_steward` — steward may update thread state and summary
- `pol_threads_delete_denied` — no deletion
- `pol_threads_select_contributor` — contributors may select threads they are anchored to (via entity/narrative participation)

#### `thread_obligations`
- `pol_obligations_select_steward` — steward may select obligations for their threads
- `pol_obligations_insert_steward` — steward (or AI agent via governance_functions) may create obligations
- `pol_obligations_update_steward` — steward may update obligation state
- `pol_obligations_delete_denied` — no deletion (archive instead)

#### `narrative_artifact_links`
- `pol_narrative_artifact_links_select_lifebook` — lifebook members may select
- `pol_narrative_artifact_links_insert_steward` — steward only
- `pol_narrative_artifact_links_delete_denied` — no deletion

#### `event_artifact_links`
- Same pattern as narrative_artifact_links

---

## 4. Migration Ordering

### M0004 — Conversation Threading Layer

**Migration file:** `20260727NNNNNN_conversation_threading.sql`  
**Depends on:** M0001, M0002, M0002b, M0003

**Phase order within M0004:**
1. New tables: `conversation_threads`, `thread_obligations`
2. New junction tables: `narrative_artifact_links`, `event_artifact_links`
3. Addendum — ALTER TABLE `artifacts` (add provenance + storage columns)
4. Addendum — ALTER TABLE `narratives` (add AI provenance)
5. Addendum — ALTER TABLE `events` (add AI provenance + review_status)
6. New functions: `fn_thread_continuation_prompt`, `fn_active_threads`, `fn_obligations_due`
7. OWNER TO governance_functions for all three functions
8. New indexes
9. RLS ENABLE and policy definitions
10. Seed data — none required (conversation threads are created at runtime)

**Estimated additions:**
- 4 new tables
- ~25 new columns across 3 existing tables
- 3 new functions
- 5 new indexes
- ~15 new RLS policies

---

## 5. What Does Not Require Schema Changes

The following Conversation Experience requirements are fully covered by the existing schema:

| Requirement | Covered by |
|---|---|
| Claim creation from conversation | `claims` with `submission_origin`, `context_manifest_id`, `review_status` |
| AI agent tracking | `agent_registry`, `context_manifests` |
| Artifact creation | `artifacts` (once M0004 columns are added) |
| Signed URL generation | `fn_generate_artifact_signed_url` (stub; ready for storage integration) |
| Family member linking | `user_person_links`, `lifebook_memberships` |
| Narrative creation | `narratives` (once M0004 columns are added) |
| Event creation | `events` (once M0004 columns are added) |
| Cultural governance | Existing policy set — no changes needed |
| Steward/contributor distinction | `lifebook_memberships.membership_role` |
| Permanent record enforcement | Existing delete-denied policies — no changes needed |

---

## 6. Schema Changes NOT Proposed

The following were considered and rejected:

**Thread state as a separate ENUM type:** Inconsistent with the established pattern of TEXT + CHECK for status fields. The existing pattern is correct.

**Conversation turn persistence:** Consistent with Principle I ("Conversation is Ephemeral"). Turns are session-scoped, not permanently stored. No turn log table.

**Emotional state on the thread record:** The Emotional Conversation Map is an inference layer, not a database field. Emotional state is detected at runtime from conversation signals, not stored as a fact about the thread. No column required.

**Merging `artifact_source_links` into a polymorphic table:** The LifeBook design avoids polymorphic FK patterns. Separate junction tables (`narrative_artifact_links`, `event_artifact_links`) are correct.

---

## 7. Open Questions for DP Review Before M0004 Authoring

1. **`storage_provider_code`:** Should this be a FK to `storage_providers(code)` or `storage_providers(id)`? The vocab table has a `code` column — using it as FK requires a UNIQUE constraint on `storage_providers.code` if not already present. Recommend: use `id` FK for consistency.

2. **`upload_state` on artifacts:** Is a four-state upload lifecycle (pending_upload → received → processing → validated → failed) appropriate, or should this be simpler (pending / received / failed)?

3. **Thread contributor access:** Should non-steward contributors (family members) be able to read thread state? Or should threads be steward-private with contributions surfaced through claims/narratives instead?

4. **`anchor_narrative_id` on threads:** Narratives are created after threads (typically). Should the anchor be set retroactively, or should threads anchor to events only at creation time?

5. **`review_status` on events:** Claims and narratives have review_status. Adding it to events is consistent — but events are often created implicitly (from claim data). Does implicit event creation need a review gate?

---

*ARCHITECTURE_IMPACT_ASSESSMENT.md — LifeBook HQ — Conversation Experience v1 — 2026-07-27*
