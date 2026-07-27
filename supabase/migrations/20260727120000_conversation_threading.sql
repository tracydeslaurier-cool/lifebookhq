-- =============================================================================
-- Migration 0004: Conversation Threading Layer
-- File: 20260727120000_conversation_threading.sql
-- Date: 2026-07-27
-- Required prior migrations:
--   20260724153745_types_and_vocabularies   (M0001 — ENUMs, vocabulary tables)
--   20260726083201_predicate_governance_types (M0002 — predicate types, display_contexts)
--   20260726083202_application_roles          (M0002b — governance_functions, agent_service)
--   20260726083203_core_schema                (M0003 — 89 tables, 9 functions, 110 policies)
-- Creates: 4 new tables, 1 view, 5 new functions, 1 new trigger, 5 new indexes,
--          17 new RLS policies, ~25 new columns on 3 existing tables
--          (17 = 16 original + 1 D-003 corrective: pol_obligations_select_governance_functions)
-- Remediation: D-002 (governance_functions privilege chain — auth.uid dependency,
--   missing BYPASSRLS, missing SELECT grants), D-003 (circular RLS between
--   conversation_threads and thread_obligations — denormalized lifebook_id +
--   fn_thread_has_active_invitation), D-004 (contributor_thread_view missing
--   security_invoker = true) — all applied 2026-07-27 post-validation.
-- Authorisation: DP review complete 2026-07-27. All five policy decisions approved.
--   Decision 1: storage_provider_code TEXT REFERENCES storage_providers(code) (code is PK)
--   Decision 2: 4-state upload lifecycle: pending_upload→received→validated→failed
--   Decision 3: Contributor thread access via contributor_thread_view + RLS policy
--   Decision 4: anchor_narrative_id — steward-initiated only; never auto-set by AI
--   Decision 5: review_status on events; auto-promote steward_direct only via trigger;
--               AI-inferred events remain pending even in steward-initiated sessions
-- Note: GRANT governance_functions TO postgres and
--       GRANT USAGE, CREATE ON SCHEMA public TO governance_functions
--       were issued permanently in M0003. They are NOT re-issued here.
-- Author: Migration — LifeBook HQ Conversation Threading Layer v0.1
-- =============================================================================

BEGIN;

-- =============================================================================
-- PHASE 1 — NEW TABLES: Conversation Threading Core
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1.1 conversation_threads
-- Persists the ConversationThread model from CONVERSATION_STATE_ENGINE.md.
-- Each thread represents a living narrative conversation within a LifeBook.
-- State machine: active → paused → pending_materials → complete → archived
-- ---------------------------------------------------------------------------

CREATE TABLE conversation_threads (
    id                  UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    lifebook_id         UUID        NOT NULL REFERENCES lifebooks(id),
    created_by_id       UUID        NULL REFERENCES user_profiles(id),
    topic_label         TEXT        NOT NULL,
    anchor_entity_id    UUID        NULL REFERENCES entities(id),
    anchor_event_id     UUID        NULL REFERENCES events(id),
    -- Decision 4: anchor_narrative_id is set only when a thread is explicitly
    -- opened to extend an existing narrative. Never auto-set by the AI from
    -- a thread's own output. See AI_ORCHESTRATION_LAYER.md §6.1.1.
    anchor_narrative_id UUID        NULL REFERENCES narratives(id),
    state               TEXT        NOT NULL DEFAULT 'active'
                            CHECK (state IN ('active','paused','pending_materials','complete','archived')),
    last_activity_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    dormant_since       TIMESTAMPTZ NULL,
    context_manifest_id UUID        NULL REFERENCES context_manifests(id),
    thread_summary      TEXT        NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON COLUMN conversation_threads.anchor_narrative_id IS
    'Set only when this thread is explicitly opened to extend a pre-existing narrative. '
    'Never set automatically by the AI Orchestration Layer as output of the thread. '
    'See Decision 4 — M0004_DP_REVIEW.md.';

-- ---------------------------------------------------------------------------
-- 1.2 thread_obligations
-- Pending promises within a thread. Kept as a separate table (not JSONB) to
-- support querying by type, state, and follow-up schedule.
-- Patience model: followup_count / max_followups caps re-offers (Principle III).
-- ---------------------------------------------------------------------------

CREATE TABLE thread_obligations (
    id                  UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    thread_id           UUID        NOT NULL REFERENCES conversation_threads(id),
    -- D-003 corrective: denormalized lifebook_id for direct RLS lookups.
    -- Without this column, thread_obligations RLS policies must subquery
    -- conversation_threads to obtain lifebook_id. That subquery triggers RLS
    -- on conversation_threads, which itself queries thread_obligations —
    -- producing infinite recursion (PostgreSQL error 42P17).
    -- The application MUST supply lifebook_id on INSERT, consistent with
    -- the thread's own lifebook_id. A FK check to lifebooks(id) enforces
    -- referential integrity; no trigger is required for the denormalization
    -- because INSERT always has both thread_id and lifebook_id in scope.
    lifebook_id         UUID        NOT NULL REFERENCES lifebooks(id),
    obligation_type     TEXT        NOT NULL
                            CHECK (obligation_type IN (
                                'artifact_upload',
                                'invitation',
                                'fact_verification',
                                'correction',
                                'continuation'
                            )),
    obligation_state    TEXT        NOT NULL DEFAULT 'pending'
                            CHECK (obligation_state IN (
                                'pending',
                                'offered',
                                'fulfilled',
                                'declined',
                                'archived'
                            )),
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

-- =============================================================================
-- PHASE 2 — NEW JUNCTION TABLES: Artifact Attachment
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 2.1 narrative_artifact_links
-- Attaches artifacts to the narratives they illustrate or support.
-- The existing artifact_source_links links only to sources; this table
-- enables the upload flow to attach artifacts directly to narratives.
-- ---------------------------------------------------------------------------

CREATE TABLE narrative_artifact_links (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    narrative_id    UUID        NOT NULL REFERENCES narratives(id),
    artifact_id     UUID        NOT NULL REFERENCES artifacts(id),
    -- link_role: describes the artifact's relationship to the narrative
    link_role       TEXT        NULL CHECK (link_role IN ('primary','contextual','illustrative')),
    link_note       TEXT        NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (narrative_id, artifact_id)
);

-- ---------------------------------------------------------------------------
-- 2.2 event_artifact_links
-- Attaches artifacts to the events they document.
-- Same rationale as narrative_artifact_links. Separate tables per
-- LifeBook's policy of avoiding polymorphic FK patterns.
-- ---------------------------------------------------------------------------

CREATE TABLE event_artifact_links (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    event_id        UUID        NOT NULL REFERENCES events(id),
    artifact_id     UUID        NOT NULL REFERENCES artifacts(id),
    link_role       TEXT        NULL CHECK (link_role IN ('primary','contextual','illustrative')),
    link_note       TEXT        NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (event_id, artifact_id)
);

-- =============================================================================
-- PHASE 3 — ADDENDUM: ALTER TABLE artifacts
-- Adds AI provenance, storage, upload lifecycle, and validity tracking.
-- =============================================================================

ALTER TABLE artifacts
    -- Validity state: steward-governed. The artifact_validity_state ENUM type
    -- exists in M0001 but per established pattern we use TEXT + CHECK.
    ADD COLUMN validity_state           TEXT        NOT NULL DEFAULT 'pending_review'
                    CHECK (validity_state IN ('pending_review','valid','invalid','contested')),

    -- AI provenance (mirrors claims and narratives per M0003 Addendum)
    ADD COLUMN submission_origin        TEXT        NOT NULL DEFAULT 'steward_direct'
                    CHECK (submission_origin IN (
                        'steward_direct',
                        'ai_assisted',
                        'family_contribution',
                        'external_import'
                    )),
    ADD COLUMN ai_generated             BOOLEAN     NOT NULL DEFAULT FALSE,
    ADD COLUMN producing_agent_code     TEXT        NULL,
    ADD COLUMN context_manifest_id      UUID        NULL REFERENCES context_manifests(id),

    -- Storage: Decision 1 — storage_provider_code references storage_providers(code).
    -- storage_providers uses code TEXT PRIMARY KEY (vocabulary table pattern).
    -- This is a FK to the primary key of the vocabulary table.
    ADD COLUMN object_key               TEXT        NULL,
    ADD COLUMN storage_provider_code    TEXT        NULL REFERENCES storage_providers(code),

    -- Upload lifecycle: Decision 2 — four states.
    -- pending_upload: artifact record exists; file not yet received
    -- received:       file bytes received by storage layer; not yet validated
    -- validated:      format checked, virus scanned, processing complete; eligible for review
    -- failed:         upload or validation failed; notes column describes failure stage
    ADD COLUMN upload_state             TEXT        NOT NULL DEFAULT 'pending_upload'
                    CHECK (upload_state IN (
                        'pending_upload',
                        'received',
                        'validated',
                        'failed'
                    ));

COMMENT ON COLUMN artifacts.storage_provider_code IS
    'FK to storage_providers(code) — the primary key of the vocabulary table. '
    'Identifies which storage backend holds this artifact (e.g., supabase_storage, s3).';

COMMENT ON COLUMN artifacts.upload_state IS
    'Four-state upload lifecycle per Decision 2 (M0004_DP_REVIEW.md). '
    'pending_upload→received→validated→failed. '
    'Processing is an internal transition; validated is the first governance-visible terminal state.';

-- =============================================================================
-- PHASE 4 — ADDENDUM: ALTER TABLE narratives
-- Adds full AI provenance to narratives (M0003 Addendum added only review_status).
-- =============================================================================

ALTER TABLE narratives
    ADD COLUMN submission_origin        TEXT        NOT NULL DEFAULT 'steward_direct'
                    CHECK (submission_origin IN (
                        'steward_direct',
                        'ai_assisted',
                        'family_contribution'
                    )),
    ADD COLUMN ai_generated             BOOLEAN     NOT NULL DEFAULT FALSE,
    ADD COLUMN producing_agent_code     TEXT        NULL,
    ADD COLUMN context_manifest_id      UUID        NULL REFERENCES context_manifests(id);

-- =============================================================================
-- PHASE 5 — ADDENDUM: ALTER TABLE events
-- Adds full AI provenance and review_status gate.
-- Decision 5: Auto-promotion trigger (Phase 6.4) fires on INSERT.
-- Only events with submission_origin = 'steward_direct' are auto-promoted to
-- review_status = 'steward_reviewed'. All AI-inferred events remain 'pending'
-- even in steward-initiated sessions. Authorship is the criterion, not session origin.
-- =============================================================================

ALTER TABLE events
    ADD COLUMN submission_origin        TEXT        NOT NULL DEFAULT 'steward_direct'
                    CHECK (submission_origin IN (
                        'steward_direct',
                        'ai_assisted',
                        'family_contribution'
                    )),
    ADD COLUMN ai_generated             BOOLEAN     NOT NULL DEFAULT FALSE,
    ADD COLUMN producing_agent_code     TEXT        NULL,
    ADD COLUMN context_manifest_id      UUID        NULL REFERENCES context_manifests(id),
    ADD COLUMN review_status            TEXT        NOT NULL DEFAULT 'pending'
                    CHECK (review_status IN (
                        'pending',
                        'steward_reviewed',
                        'policy_approved',
                        'rejected'
                    ));

COMMENT ON COLUMN events.review_status IS
    'Governance gate consistent with claims and narratives. '
    'AI-inferred events (submission_origin = ''ai_assisted'') start as ''pending'' and '
    'require steward promotion. Events explicitly authored by a steward '
    '(submission_origin = ''steward_direct'') are auto-promoted to ''steward_reviewed'' '
    'by trg_event_review_status_auto_promote. '
    'Decision 5 (M0004_DP_REVIEW.md): steward session initiation ≠ steward record authorship.';

-- =============================================================================
-- PHASE 5.5 — D-002 CORRECTIVE: Rewrite M0003 SECURITY DEFINER functions
-- Root cause: governance_functions SECURITY DEFINER context cannot call auth.uid()
-- because the auth schema is owned by supabase_admin. postgres holds USAGE on auth
-- only via authenticated role membership, without GRANT OPTION — it cannot extend
-- that privilege to governance_functions. auth.uid() is a thin GUC-reader; replacing
-- calls to it with direct GUC reads eliminates the schema dependency entirely.
-- Affected: fn_lb_membership_role, fn_is_subject_of, fn_has_active_authority,
--   fn_has_source_access_grant, fn_has_contest_standing (all originally in M0003).
-- These CREATE OR REPLACE statements are additive corrections in M0004.
-- M0003 is not modified.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_lb_membership_role(p_lifebook_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $$
DECLARE
    v_role TEXT;
    v_uid  UUID;
BEGIN
    IF p_lifebook_id IS NULL THEN
        RETURN 'none';
    END IF;

    -- D-002 corrective: direct GUC read replaces auth.uid().
    -- auth.uid() = COALESCE(NULLIF(current_setting('request.jwt.claim.sub',...), ''),
    --   NULLIF(current_setting('request.jwt.claims',...), '')::jsonb ->> 'sub')::uuid
    v_uid := COALESCE(
        NULLIF(current_setting('request.jwt.claim.sub', true), ''),
        NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
    )::uuid;

    SELECT membership_role
      INTO v_role
      FROM lifebook_memberships
     WHERE lifebook_id = p_lifebook_id
       AND user_id = v_uid
     LIMIT 1;

    RETURN COALESCE(v_role, 'none');
END;
$$;
ALTER FUNCTION fn_lb_membership_role(UUID) OWNER TO governance_functions;

CREATE OR REPLACE FUNCTION fn_is_subject_of(p_entity_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID;
BEGIN
    IF p_entity_id IS NULL THEN
        RETURN FALSE;
    END IF;

    v_uid := COALESCE(
        NULLIF(current_setting('request.jwt.claim.sub', true), ''),
        NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
    )::uuid;

    RETURN EXISTS (
        SELECT 1
          FROM user_person_links
         WHERE user_id = v_uid
           AND person_entity_id = p_entity_id
           AND verification_status = 'verified'
    );
END;
$$;
ALTER FUNCTION fn_is_subject_of(UUID) OWNER TO governance_functions;

CREATE OR REPLACE FUNCTION fn_has_active_authority(
    p_role_code TEXT,
    p_entity_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID;
BEGIN
    v_uid := COALESCE(
        NULLIF(current_setting('request.jwt.claim.sub', true), ''),
        NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
    )::uuid;

    RETURN EXISTS (
        SELECT 1
          FROM authority_assignments
         WHERE authority_holder_id = v_uid
           AND authority_role = p_role_code
           AND (effective_until IS NULL OR effective_until > current_date)
           AND (p_entity_id IS NULL OR entity_id = p_entity_id)
    );
END;
$$;
ALTER FUNCTION fn_has_active_authority(TEXT, UUID) OWNER TO governance_functions;

CREATE OR REPLACE FUNCTION fn_has_source_access_grant(p_source_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $$
DECLARE
    v_uid UUID;
BEGIN
    IF p_source_id IS NULL THEN
        RETURN FALSE;
    END IF;

    v_uid := COALESCE(
        NULLIF(current_setting('request.jwt.claim.sub', true), ''),
        NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
    )::uuid;

    RETURN EXISTS (
        SELECT 1
          FROM lifebook_source_access lsa
          JOIN lifebook_memberships lm
            ON lm.lifebook_id = lsa.lifebook_id
           AND lm.user_id = v_uid
         WHERE lsa.source_id = p_source_id
    );
END;
$$;
ALTER FUNCTION fn_has_source_access_grant(UUID) OWNER TO governance_functions;

CREATE OR REPLACE FUNCTION fn_has_contest_standing(
    p_table          TEXT,
    p_record_id      UUID,
    p_standing_class TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $$
DECLARE
    v_whitelisted_tables TEXT[] := ARRAY[
        'claims', 'relationships', 'narratives', 'sources', 'artifacts',
        'events', 'person_names', 'person_pronouns', 'person_gender_descriptors'
    ];
    v_entity_id   UUID;
    v_lifebook_id UUID;
    v_sql         TEXT;
    v_uid         UUID;
    v_created_by  UUID;
BEGIN
    -- Validate table name against whitelist — RAISE EXCEPTION on unrecognized table
    IF NOT (p_table = ANY(v_whitelisted_tables)) THEN
        RAISE EXCEPTION 'fn_has_contest_standing: unrecognized contested_record_table: %', p_table;
    END IF;

    IF p_record_id IS NULL OR p_standing_class IS NULL THEN
        RETURN FALSE;
    END IF;

    v_uid := COALESCE(
        NULLIF(current_setting('request.jwt.claim.sub', true), ''),
        NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
    )::uuid;

    -- Check standing class: steward of the LifeBook
    IF p_standing_class = 'steward' THEN
        v_sql := format('SELECT lifebook_id FROM %I WHERE id = $1', p_table);
        EXECUTE v_sql INTO v_lifebook_id USING p_record_id;
        RETURN fn_lb_membership_role(v_lifebook_id) = 'steward';

    -- Check standing class: subject (person whose record this concerns)
    ELSIF p_standing_class = 'subject' THEN
        v_sql := format('SELECT person_id FROM %I WHERE id = $1', p_table);
        EXECUTE v_sql INTO v_entity_id USING p_record_id;
        IF v_entity_id IS NULL THEN
            v_sql := format('SELECT entity_id FROM %I WHERE id = $1', p_table);
            EXECUTE v_sql INTO v_entity_id USING p_record_id;
        END IF;
        RETURN fn_is_subject_of(v_entity_id);

    -- Check standing class: asserting_party (user who created the record)
    ELSIF p_standing_class = 'asserting_party' THEN
        v_sql := format('SELECT created_by_id FROM %I WHERE id = $1', p_table);
        EXECUTE v_sql INTO v_created_by USING p_record_id;
        RETURN v_created_by = v_uid;

    -- Check standing class: affected_party (involved entities include current user's person)
    ELSIF p_standing_class = 'affected_party' THEN
        RETURN EXISTS (
            SELECT 1
              FROM user_person_links upl
             WHERE upl.user_id = v_uid
               AND upl.verification_status = 'verified'
               AND EXISTS (
                   SELECT 1
                     FROM contest_records cr
                    WHERE cr.contested_record_table = p_table
                      AND cr.contested_record_id = p_record_id
                      AND upl.person_entity_id = ANY(cr.person_ids_involved)
               )
        );

    -- Check standing class: cultural_authority
    ELSIF p_standing_class = 'cultural_authority' THEN
        RETURN fn_has_active_authority('cultural_authority', NULL);

    -- Check standing class: authority_holder (holds active AuthorityAssignment for entity)
    ELSIF p_standing_class = 'authority_holder' THEN
        v_sql := format('SELECT entity_id FROM %I WHERE id = $1', p_table);
        EXECUTE v_sql INTO v_entity_id USING p_record_id;
        RETURN fn_has_active_authority('steward', v_entity_id)
            OR fn_has_active_authority('cultural_authority', v_entity_id);

    -- Check standing class: lifebook_member (any member of the LifeBook)
    ELSIF p_standing_class = 'lifebook_member' THEN
        v_sql := format('SELECT lifebook_id FROM %I WHERE id = $1', p_table);
        EXECUTE v_sql INTO v_lifebook_id USING p_record_id;
        RETURN fn_lb_membership_role(v_lifebook_id) != 'none';

    ELSE
        RAISE EXCEPTION 'fn_has_contest_standing: unrecognized standing_class: %', p_standing_class;
    END IF;
END;
$$;
ALTER FUNCTION fn_has_contest_standing(TEXT, UUID, TEXT) OWNER TO governance_functions;

-- =============================================================================
-- PHASE 6 — NEW FUNCTIONS
-- All helper functions: SECURITY DEFINER, search_path pinned.
-- All owned by governance_functions.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 6.1 _fn_trg_event_review_status_auto_promote — trigger function
-- Decision 5: Auto-promotes events with submission_origin = 'steward_direct'
-- to review_status = 'steward_reviewed' at INSERT time.
-- All other events (ai_assisted, family_contribution) remain at default 'pending'.
-- IMPORTANT: The Claim Generator must NEVER assign submission_origin = 'steward_direct'
-- to any event it creates from conversation inference. See AI_ORCHESTRATION_LAYER.md §6.1.1.
-- ---------------------------------------------------------------------------

CREATE FUNCTION _fn_trg_event_review_status_auto_promote()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public', pg_temp
AS $$
BEGIN
    -- Auto-promote events explicitly authored by a steward.
    --
    -- "Steward initiation of a workflow does not make inferred events authoritative."
    -- DP decision, 2026-07-27.
    --
    -- submission_origin = 'steward_direct' means the steward directly created this
    -- event record through the steward authorship path (e.g., direct API call or UI form).
    -- It does NOT mean the steward initiated the session in which an AI inferred the event.
    -- AI-inferred events always carry submission_origin = 'ai_assisted' regardless of
    -- who initiated the session. The Claim Generator enforces this invariant.
    IF NEW.submission_origin = 'steward_direct' THEN
        NEW.review_status := 'steward_reviewed';
    END IF;
    -- All other submission_origin values leave review_status = 'pending' (the column default).
    RETURN NEW;
END;
$$;

ALTER FUNCTION _fn_trg_event_review_status_auto_promote() OWNER TO governance_functions;

-- ---------------------------------------------------------------------------
-- 6.2 fn_thread_continuation_prompt — SECURITY DEFINER
-- Generates the natural-language continuation offer for a returning user.
-- Reads thread state, thread summary, and first pending obligation.
-- Returns NULL if thread does not exist or user lacks access.
-- ---------------------------------------------------------------------------

CREATE FUNCTION fn_thread_continuation_prompt(p_thread_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', pg_temp
AS $$
DECLARE
    v_thread        conversation_threads%ROWTYPE;
    v_obligation    thread_obligations%ROWTYPE;
    v_prompt        TEXT;
BEGIN
    IF p_thread_id IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT * INTO v_thread
      FROM conversation_threads
     WHERE id = p_thread_id
       AND state IN ('paused', 'pending_materials');

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- Base prompt: topic + optional summary context
    IF v_thread.thread_summary IS NOT NULL THEN
        v_prompt := 'Last time we were talking about your ' || v_thread.topic_label
                    || '. ' || v_thread.thread_summary;
    ELSE
        v_prompt := 'Last time we were talking about your ' || v_thread.topic_label || '.';
    END IF;

    -- Append brief for the first eligible pending obligation
    SELECT * INTO v_obligation
      FROM thread_obligations
     WHERE thread_id = p_thread_id
       AND obligation_state IN ('pending', 'offered')
       AND (followup_after IS NULL OR followup_after <= now())
       AND followup_count < max_followups
     ORDER BY created_at ASC
     LIMIT 1;

    IF FOUND THEN
        v_prompt := v_prompt || ' ' || v_obligation.label;
    END IF;

    v_prompt := v_prompt
        || ' Would you like to pick up where we left off, or is there something else on your mind?';

    RETURN v_prompt;
END;
$$;

ALTER FUNCTION fn_thread_continuation_prompt(UUID) OWNER TO governance_functions;

-- ---------------------------------------------------------------------------
-- 6.3 fn_active_threads — SECURITY DEFINER
-- Returns all threads in active or paused state for a lifebook,
-- ordered by most recent activity. Used at session-open to surface
-- continuation offers. RLS on conversation_threads filters by role.
-- ---------------------------------------------------------------------------

CREATE FUNCTION fn_active_threads(p_lifebook_id UUID)
RETURNS SETOF conversation_threads
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', pg_temp
AS $$
BEGIN
    IF p_lifebook_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
        SELECT *
          FROM conversation_threads
         WHERE lifebook_id = p_lifebook_id
           AND state IN ('active', 'paused', 'pending_materials')
         ORDER BY last_activity_at DESC;
END;
$$;

ALTER FUNCTION fn_active_threads(UUID) OWNER TO governance_functions;

-- ---------------------------------------------------------------------------
-- 6.4 fn_obligations_due — SECURITY DEFINER
-- Returns obligations that are eligible for re-offer:
--   - State is pending or offered (not fulfilled/declined/archived)
--   - followup_after is in the past or null (no scheduled delay)
--   - followup_count has not reached max_followups (patience cap)
-- Used by the Orchestrator at session-open and mid-session checks.
-- ---------------------------------------------------------------------------

CREATE FUNCTION fn_obligations_due(p_thread_id UUID)
RETURNS SETOF thread_obligations
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', pg_temp
AS $$
BEGIN
    IF p_thread_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
        SELECT *
          FROM thread_obligations
         WHERE thread_id = p_thread_id
           AND obligation_state IN ('pending', 'offered')
           AND (followup_after IS NULL OR followup_after <= now())
           AND followup_count < max_followups
         ORDER BY created_at ASC;
END;
$$;

ALTER FUNCTION fn_obligations_due(UUID) OWNER TO governance_functions;

-- =============================================================================
-- PHASE 6.5 — D-003 NEW FUNCTION: fn_thread_has_active_invitation
-- =============================================================================

-- ---------------------------------------------------------------------------
-- fn_thread_has_active_invitation — SECURITY DEFINER
-- D-003 corrective: breaks circular RLS dependency between conversation_threads
-- and thread_obligations.
--
-- Problem: pol_threads_select_contributor previously used an EXISTS subquery on
-- thread_obligations. When the authenticated role queries thread_obligations,
-- thread_obligations RLS fires — and pol_obligations_select_steward originally
-- subqueried conversation_threads, completing the cycle. PostgreSQL raises
-- "infinite recursion detected in policy" (error 42P17).
--
-- Solution: this SECURITY DEFINER function runs as governance_functions, which
-- has BYPASSRLS (set in Phase 11) and SELECT on thread_obligations (granted in
-- Phase 11). It checks obligation state without triggering authenticated-role RLS.
-- pol_threads_select_contributor now calls fn_thread_has_active_invitation(id)
-- instead of the inline EXISTS subquery.
--
-- pol_obligations_select_governance_functions (Phase 10.2) was also added as a
-- defence-in-depth backstop: ensures this function's queries succeed even if
-- BYPASSRLS were ever removed from governance_functions.
-- ---------------------------------------------------------------------------

CREATE FUNCTION fn_thread_has_active_invitation(p_thread_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $$
    SELECT EXISTS (
        SELECT 1 FROM thread_obligations
         WHERE thread_id = p_thread_id
           AND obligation_type = 'invitation'
           AND obligation_state IN ('pending', 'offered')
    )
$$;
ALTER FUNCTION fn_thread_has_active_invitation(UUID) OWNER TO governance_functions;

-- =============================================================================
-- PHASE 7 — TRIGGER: Event auto-promotion
-- =============================================================================

CREATE TRIGGER trg_event_review_status_auto_promote
    BEFORE INSERT ON events
    FOR EACH ROW
    EXECUTE FUNCTION _fn_trg_event_review_status_auto_promote();

-- =============================================================================
-- PHASE 8 — VIEW: contributor_thread_view
-- Decision 3: Contributors may read thread summary and topic for threads
-- where they have an active invitation obligation. This view provides
-- a column-scoped projection of conversation_threads for contributor consumption.
-- The underlying RLS policy (Phase 9) controls row access.
-- =============================================================================

-- Decision 3 conformance note:
-- state is deliberately excluded. pending_materials signals outstanding invitation
-- obligations and reveals stewardship activity. No defined contributor-facing use case
-- requires thread state. Contributors receive topic, summary, and subject entity only.
-- DP conformance review, 2026-07-27.
--
-- D-004 corrective: security_invoker = true ensures RLS is evaluated as the querying
-- user, not as the view owner (postgres, rolbypassrls = true). Without this option,
-- the view owner's BYPASSRLS bypasses all RLS on conversation_threads — every row is
-- visible regardless of the contributor policy. Validated: C1 test (contributor sees
-- Thread A only) passed after adding this option.
CREATE VIEW contributor_thread_view
WITH (security_invoker = true) AS
    SELECT
        ct.id,
        ct.lifebook_id,
        ct.topic_label,
        ct.thread_summary,
        ct.anchor_entity_id
    FROM conversation_threads ct;

COMMENT ON VIEW contributor_thread_view IS
    'Curated contextual projection of conversation_threads for contributor access. '
    'security_invoker = true: RLS evaluated as the querying user (not the view owner). '
    'Without this, view owner postgres (rolbypassrls = true) bypasses all row security. '
    'Columns: id, lifebook_id, topic_label, thread_summary, anchor_entity_id. '
    'state excluded: pending_materials reveals steward obligation activity not required '
    'by any contributor-facing use case. '
    'Row access governed by pol_threads_select_contributor on conversation_threads. '
    'thread_summary must never contain obligation metadata, raw conversation excerpts, '
    'or references to access-classified claims the contributor may not be permitted to see. '
    'Decision 3 + D-004 corrective — M0004_DP_REVIEW.md, 2026-07-27.';

-- =============================================================================
-- PHASE 9 — INDEXES
-- =============================================================================

-- Thread lookup by lifebook and state (primary session-open query)
CREATE INDEX idx_conversation_threads_lifebook_state
    ON conversation_threads(lifebook_id, state);

-- Thread ordering by last activity (continuation offer ordering)
CREATE INDEX idx_conversation_threads_last_activity
    ON conversation_threads(lifebook_id, last_activity_at DESC);

-- Obligations eligible for re-offer (partial — avoids scanning fulfilled/archived)
CREATE INDEX idx_thread_obligations_followup
    ON thread_obligations(thread_id, obligation_state, followup_after)
    WHERE obligation_state IN ('pending', 'offered');

-- Artifact upload queue (pending upload pipeline — partial)
CREATE INDEX idx_artifacts_upload_state
    ON artifacts(lifebook_id, upload_state)
    WHERE upload_state != 'validated';

-- Artifact review queue (steward review queue — partial)
CREATE INDEX idx_artifacts_validity_state
    ON artifacts(lifebook_id, validity_state)
    WHERE validity_state = 'pending_review';

-- =============================================================================
-- PHASE 10 — ROW LEVEL SECURITY
-- All new tables require RLS. Pattern follows M0003.
-- Delete-denied policies are PERMISSIVE (not RESTRICTIVE) per M0003 convention —
-- they use USING (FALSE) to block all deletes. No RESTRICTIVE policies are introduced.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 10.1 conversation_threads
-- ---------------------------------------------------------------------------

ALTER TABLE conversation_threads ENABLE ROW LEVEL SECURITY;

-- Policy T-1: No deletions — threads are archived, not deleted (Principle VIII)
CREATE POLICY pol_threads_delete_denied
    ON conversation_threads FOR DELETE
    USING (FALSE);

-- Policy T-2: Steward may select all threads in their lifebook
CREATE POLICY pol_threads_select_steward
    ON conversation_threads FOR SELECT
    USING (fn_lb_membership_role(lifebook_id) = 'steward');

-- Policy T-3: Steward may create new threads in their lifebook
CREATE POLICY pol_threads_insert_steward
    ON conversation_threads FOR INSERT
    WITH CHECK (fn_lb_membership_role(lifebook_id) = 'steward');

-- Policy T-4: Steward may update thread state and summary
CREATE POLICY pol_threads_update_steward
    ON conversation_threads FOR UPDATE
    USING (fn_lb_membership_role(lifebook_id) = 'steward');

-- Policy T-5: Agent may select threads (needed to build continuation context)
-- Contributors access via contributor_thread_view + T-6 below; not directly.
CREATE POLICY pol_threads_select_agent
    ON conversation_threads FOR SELECT
    USING (fn_user_is_agent());

-- Policy T-6: Contributor may select threads where they have an active invitation
-- Decision 3: Contributor sees thread summary via contributor_thread_view;
-- this RLS policy controls which rows that view exposes to contributors.
-- D-003 corrective: original policy used an inline EXISTS subquery on
-- thread_obligations, causing circular RLS (pol_obligations_select_steward
-- subqueried conversation_threads → infinite recursion, PostgreSQL error 42P17).
-- Replaced with fn_thread_has_active_invitation(id): SECURITY DEFINER running
-- as governance_functions (BYPASSRLS), breaks the cycle entirely.
CREATE POLICY pol_threads_select_contributor
    ON conversation_threads FOR SELECT
    USING (
        fn_lb_membership_role(lifebook_id) = 'contributor'
        AND fn_thread_has_active_invitation(id)
    );

-- ---------------------------------------------------------------------------
-- 10.2 thread_obligations
-- ---------------------------------------------------------------------------

ALTER TABLE thread_obligations ENABLE ROW LEVEL SECURITY;

-- Policy O-1: No deletions — obligations are archived, not deleted (Principle VIII)
CREATE POLICY pol_obligations_delete_denied
    ON thread_obligations FOR DELETE
    USING (FALSE);

-- Policy O-2: Steward may select all obligations for threads in their lifebook
-- D-003 corrective: original policy resolved lifebook_id via subquery on
-- conversation_threads. pol_threads_select_contributor also subqueried
-- thread_obligations, creating circular RLS (error 42P17). Fix: denormalize
-- lifebook_id onto thread_obligations (added in table DDL above) and use it
-- directly — no subquery on conversation_threads, no cycle.
CREATE POLICY pol_obligations_select_steward
    ON thread_obligations FOR SELECT
    USING (fn_lb_membership_role(lifebook_id) = 'steward');

-- Policy O-3: Steward or AI agent may create obligations
-- D-003 corrective: same subquery removed; lifebook_id used directly.
CREATE POLICY pol_obligations_insert_steward_or_agent
    ON thread_obligations FOR INSERT
    WITH CHECK (
        fn_user_is_agent()
        OR fn_lb_membership_role(lifebook_id) = 'steward'
    );

-- Policy O-4: Steward or AI agent may update obligation state
-- D-003 corrective: same subquery removed; lifebook_id used directly.
CREATE POLICY pol_obligations_update_steward_or_agent
    ON thread_obligations FOR UPDATE
    USING (
        fn_user_is_agent()
        OR fn_lb_membership_role(lifebook_id) = 'steward'
    );

-- Policy O-5: governance_functions role may select all obligations
-- D-003 corrective: defence-in-depth backstop. fn_thread_has_active_invitation
-- runs as SECURITY DEFINER / governance_functions with BYPASSRLS, so this policy
-- is not strictly required. It ensures the query succeeds even if BYPASSRLS is
-- ever removed from governance_functions — a policy-based safety net independent
-- of the privilege chain.
CREATE POLICY pol_obligations_select_governance_functions
    ON thread_obligations FOR SELECT
    USING (current_user = 'governance_functions');

-- ---------------------------------------------------------------------------
-- 10.3 narrative_artifact_links
-- ---------------------------------------------------------------------------

ALTER TABLE narrative_artifact_links ENABLE ROW LEVEL SECURITY;

-- Policy N-1: No deletions (Principle VIII)
CREATE POLICY pol_nal_delete_denied
    ON narrative_artifact_links FOR DELETE
    USING (FALSE);

-- Policy N-2: Any lifebook member may select narrative-artifact links
CREATE POLICY pol_nal_select_lifebook
    ON narrative_artifact_links FOR SELECT
    USING (
        fn_lb_membership_role(
            (SELECT lifebook_id FROM narratives WHERE id = narrative_artifact_links.narrative_id)
        ) != 'none'
    );

-- Policy N-3: Only steward may create narrative-artifact links
CREATE POLICY pol_nal_insert_steward
    ON narrative_artifact_links FOR INSERT
    WITH CHECK (
        fn_lb_membership_role(
            (SELECT lifebook_id FROM narratives WHERE id = narrative_id)
        ) = 'steward'
    );

-- ---------------------------------------------------------------------------
-- 10.4 event_artifact_links
-- ---------------------------------------------------------------------------

ALTER TABLE event_artifact_links ENABLE ROW LEVEL SECURITY;

-- Policy E-1: No deletions (Principle VIII)
CREATE POLICY pol_eal_delete_denied
    ON event_artifact_links FOR DELETE
    USING (FALSE);

-- Policy E-2: Any lifebook member may select event-artifact links
CREATE POLICY pol_eal_select_lifebook
    ON event_artifact_links FOR SELECT
    USING (
        fn_lb_membership_role(
            (SELECT lifebook_id FROM events WHERE id = event_artifact_links.event_id)
        ) != 'none'
    );

-- Policy E-3: Only steward may create event-artifact links
CREATE POLICY pol_eal_insert_steward
    ON event_artifact_links FOR INSERT
    WITH CHECK (
        fn_lb_membership_role(
            (SELECT lifebook_id FROM events WHERE id = event_id)
        ) = 'steward'
    );

-- =============================================================================
-- PHASE 11 — GRANTS
-- =============================================================================

-- Step 1: REVOKE EXECUTE FROM PUBLIC on new helper functions
REVOKE EXECUTE ON FUNCTION fn_thread_continuation_prompt(UUID)   FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_active_threads(UUID)               FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_obligations_due(UUID)              FROM PUBLIC;

-- Step 2: Per-role EXECUTE grants on new helper functions
GRANT EXECUTE ON FUNCTION fn_thread_continuation_prompt(UUID)   TO authenticated, agent_service;
GRANT EXECUTE ON FUNCTION fn_active_threads(UUID)               TO authenticated, agent_service;
GRANT EXECUTE ON FUNCTION fn_obligations_due(UUID)              TO authenticated, agent_service;

-- Step 3: Table grants on new content tables
-- authenticated: full DML on threading tables (RLS restricts further)
GRANT SELECT, INSERT, UPDATE ON TABLE conversation_threads      TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE thread_obligations        TO authenticated;
GRANT SELECT, INSERT         ON TABLE narrative_artifact_links  TO authenticated;
GRANT SELECT, INSERT         ON TABLE event_artifact_links      TO authenticated;

-- agent_service: SELECT on threads (context reading), full DML on obligations
GRANT SELECT                  ON TABLE conversation_threads     TO agent_service;
GRANT SELECT, INSERT, UPDATE  ON TABLE thread_obligations       TO agent_service;
GRANT SELECT                  ON TABLE narrative_artifact_links TO agent_service;
GRANT SELECT                  ON TABLE event_artifact_links     TO agent_service;

-- Step 4: View grant
-- Decision 3: contributor_thread_view provides column-scoped thread access.
-- Row access is still controlled by RLS on the underlying conversation_threads table
-- via pol_threads_select_contributor.
GRANT SELECT ON contributor_thread_view TO authenticated;

-- Step 5: D-002 corrective — governance_functions privilege chain
-- governance_functions is a NOLOGIN SECURITY DEFINER role. It has no role
-- memberships and receives no default grants. Without explicit table grants it
-- cannot read the lookup tables its functions query, even with BYPASSRLS.
-- BYPASSRLS bypasses row-level security but NOT table-level privilege checks.
--
-- ALTER ROLE … BYPASSRLS: postgres has CREATEROLE (confirmed in M0002b), which
-- is sufficient to set BYPASSRLS on a non-superuser role even when postgres
-- itself is not superuser. This removes authenticated-role RLS from all
-- governance_functions queries, preventing any accidental recursive policy fire.
--
-- GRANT SELECT: the minimum privilege set required for all five SECURITY DEFINER
-- functions in M0003 (fn_lb_membership_role, fn_is_subject_of,
-- fn_has_active_authority, fn_has_source_access_grant, fn_has_contest_standing)
-- plus the new fn_thread_has_active_invitation added in this migration.
ALTER ROLE governance_functions BYPASSRLS;

GRANT SELECT ON TABLE
    lifebook_memberships,
    user_person_links,
    authority_assignments,
    lifebook_source_access,
    conversation_threads,
    thread_obligations,
    contest_records
TO governance_functions;

-- Step 6: D-003 corrective — fn_thread_has_active_invitation grants
-- REVOKE from PUBLIC first (defence-in-depth; PUBLIC has EXECUTE by default).
-- GRANT to authenticated so pol_threads_select_contributor can call it from
-- within an authenticated-role RLS context. agent_service included per
-- standard pattern for governance helper functions.
REVOKE EXECUTE ON FUNCTION fn_thread_has_active_invitation(UUID) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_thread_has_active_invitation(UUID) TO authenticated, agent_service;

-- =============================================================================
-- COMMIT — end of transaction block
-- =============================================================================

COMMIT;

-- =============================================================================
-- Phase 12 — Validation Queries (as comments — run manually after applying)
-- =============================================================================

-- 1. New tables exist:
--    SELECT tablename FROM pg_tables
--     WHERE tablename IN ('conversation_threads','thread_obligations',
--                         'narrative_artifact_links','event_artifact_links')
--       AND schemaname = 'public';
--    Expected: 4 rows

-- 2. New functions exist (includes D-003 corrective fn_thread_has_active_invitation):
--    SELECT proname FROM pg_proc
--     WHERE proname IN ('fn_thread_continuation_prompt','fn_active_threads',
--                       'fn_obligations_due','_fn_trg_event_review_status_auto_promote',
--                       'fn_thread_has_active_invitation')
--       AND pronamespace = 'public'::regnamespace;
--    Expected: 5 rows

-- 3. Function ownership (includes D-003 corrective fn_thread_has_active_invitation):
--    SELECT proname, pg_get_userbyid(proowner) AS owner
--      FROM pg_proc
--     WHERE proname IN ('fn_thread_continuation_prompt','fn_active_threads',
--                       'fn_obligations_due','_fn_trg_event_review_status_auto_promote',
--                       'fn_thread_has_active_invitation')
--       AND pronamespace = 'public'::regnamespace;
--    Expected: all 5 rows — owner = governance_functions

-- 4. Trigger exists:
--    SELECT tgname, tgrelid::regclass FROM pg_trigger
--     WHERE tgname = 'trg_event_review_status_auto_promote';
--    Expected: 1 row — tgrelid = events

-- 5. RLS enabled on new tables:
--    SELECT tablename FROM pg_tables
--     WHERE rowsecurity = TRUE
--       AND tablename IN ('conversation_threads','thread_obligations',
--                         'narrative_artifact_links','event_artifact_links');
--    Expected: 4 rows

-- 6. Policy count for new tables (D-003 adds pol_obligations_select_governance_functions):
--    SELECT tablename, count(*) FROM pg_policies
--     WHERE tablename IN ('conversation_threads','thread_obligations',
--                         'narrative_artifact_links','event_artifact_links')
--     GROUP BY tablename;
--    Expected: conversation_threads=6, thread_obligations=5,
--              narrative_artifact_links=3, event_artifact_links=3

-- 7. New indexes:
--    SELECT indexname FROM pg_indexes
--     WHERE indexname IN (
--         'idx_conversation_threads_lifebook_state',
--         'idx_conversation_threads_last_activity',
--         'idx_thread_obligations_followup',
--         'idx_artifacts_upload_state',
--         'idx_artifacts_validity_state'
--     );
--    Expected: 5 rows

-- 8. artifacts new columns:
--    SELECT column_name FROM information_schema.columns
--     WHERE table_name = 'artifacts'
--       AND column_name IN ('validity_state','submission_origin','ai_generated',
--                           'producing_agent_code','context_manifest_id',
--                           'object_key','storage_provider_code','upload_state');
--    Expected: 8 rows

-- 9. narratives new columns:
--    SELECT column_name FROM information_schema.columns
--     WHERE table_name = 'narratives'
--       AND column_name IN ('submission_origin','ai_generated',
--                           'producing_agent_code','context_manifest_id');
--    Expected: 4 rows

-- 10. events new columns:
--     SELECT column_name FROM information_schema.columns
--      WHERE table_name = 'events'
--        AND column_name IN ('submission_origin','ai_generated',
--                            'producing_agent_code','context_manifest_id','review_status');
--     Expected: 5 rows

-- 11. Auto-promote trigger — steward_direct inserts become steward_reviewed:
--     INSERT INTO events (lifebook_id, event_type, title, submission_origin)
--         VALUES ('<lifebook_id>', 'marriage', 'Test steward event', 'steward_direct')
--         RETURNING review_status;
--     Expected: review_status = 'steward_reviewed'

-- 12. Auto-promote trigger — ai_assisted inserts remain pending:
--     INSERT INTO events (lifebook_id, event_type, title, submission_origin)
--         VALUES ('<lifebook_id>', 'birth', 'Test AI event', 'ai_assisted')
--         RETURNING review_status;
--     Expected: review_status = 'pending'

-- 13. View exists with correct columns (state excluded per conformance review):
--     SELECT column_name FROM information_schema.columns
--      WHERE table_name = 'contributor_thread_view'
--      ORDER BY ordinal_position;
--     Expected: 5 rows — id, lifebook_id, topic_label, thread_summary, anchor_entity_id
--     (state is intentionally absent — it reveals obligation metadata)

-- 14. Cumulative policy count (was 110 post M0003 — now 110 + 16 + 1 D-003 = 127):
--     D-003 adds pol_obligations_select_governance_functions (+1 beyond original 16).
--     SELECT count(*) FROM pg_policies WHERE schemaname = 'public';
--     Expected: 127

-- 15. storage_provider_code FK valid:
--     SELECT kcu.column_name, ccu.table_name AS foreign_table
--       FROM information_schema.key_column_usage kcu
--       JOIN information_schema.referential_constraints rc
--         ON kcu.constraint_name = rc.constraint_name
--       JOIN information_schema.constraint_column_usage ccu
--         ON rc.unique_constraint_name = ccu.constraint_name
--      WHERE kcu.table_name = 'artifacts'
--        AND kcu.column_name = 'storage_provider_code';
--     Expected: 1 row — foreign_table = storage_providers
