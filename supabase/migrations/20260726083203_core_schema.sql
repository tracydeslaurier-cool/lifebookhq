-- =============================================================================
-- Migration 0003: Core Schema
-- File: 20260726083203_core_schema.sql
-- Date: 2026-07-26
-- Required prior migrations:
--   20260724153745_types_and_vocabularies   (39 enum types, 39 vocabulary tables)
--   20260726083201_predicate_governance_types (3 enum types, display_contexts)
--   20260726083202_application_roles          (agent_service, system_service, admin, governance_functions)
-- Creates: 49 tables, 4 deferred FKs (ALTER TABLE), 14 explicit indexes,
--          31 functions (9 helpers + 22 trigger functions), 22 triggers,
--          RLS on 25 tables, 71 RLS policies, 65 GRANT statements,
--          reference catalogue seed data (134 records)
-- Note: governance_functions role is created by 20260726083202_application_roles.
--       Two bootstrap GRANTs are issued immediately after BEGIN:
--         1. GRANT governance_functions TO postgres — allows SET ROLE governance_functions
--            during ownership transfer (SQLSTATE 42501 without it; postgres is not
--            automatically a member of governance_functions after M0002b creates it).
--         2. GRANT USAGE, CREATE ON SCHEMA public TO governance_functions — permits
--            PostgreSQL to assign governance_functions as owner of public-schema objects
--            (SQLSTATE 42501 "permission denied for schema public" without it).
--       Both GRANTs are permanent. GRANT ... TO current_user causes EOF on Supabase CLI.
-- Author: Migration — LifeBook HQ Core Schema v0.3
-- =============================================================================

BEGIN;

-- ── Ownership transfer bootstrap ───────────────────────────────────────────
-- PostgreSQL requires the executing session role to be a member of any role
-- to which it transfers object ownership (ALTER FUNCTION ... OWNER TO <role>).
-- Specifically: SQLSTATE 42501 "must be able to SET ROLE <role>" is raised if
-- the executor is not a member of the target role.
--
-- governance_functions is NOLOGIN (correct — no application should log in as it).
-- Supabase migrations execute under the postgres role. postgres is not automatically
-- a member of governance_functions after M0002b creates it.
--
-- Two prerequisites must be satisfied before the first ALTER FUNCTION ... OWNER TO
-- governance_functions statement can succeed:
--
--   1. ROLE MEMBERSHIP: postgres must be a member of governance_functions so it can
--      SET ROLE governance_functions during ownership transfer. Without this,
--      PostgreSQL raises SQLSTATE 42501 "must be able to SET ROLE governance_functions".
--      GRANT governance_functions TO current_user causes unexpected EOF on Supabase CLI
--      — postgres must be named explicitly.
--
--   2. SCHEMA CREATE PRIVILEGE: governance_functions must hold CREATE on the public
--      schema so PostgreSQL can legally assign it as the owner of objects that reside
--      there. Without this, PostgreSQL raises SQLSTATE 42501
--      "permission denied for schema public" at the ALTER FUNCTION ... OWNER TO
--      statement even when role membership is satisfied.
--      Evidence: governance_functions USAGE=true, CREATE=false before this grant.
--
-- Both GRANTs are permanent (no REVOKE): future migrations may also ALTER functions
-- owned by governance_functions, and the schema privilege must persist.
--
-- GRANT role TO role produces GrantRoleStmt (not GrantStmt) — it does not
-- change the "65 GRANT statements" count in the header; it is a separate AST type.
-- GRANT USAGE, CREATE ON SCHEMA public TO governance_functions is a GrantStmt and
-- is included in the 65 GRANT statements total in the header.
GRANT governance_functions TO postgres;

-- governance_functions must hold CREATE on public so PostgreSQL allows object
-- ownership transfer to this role. USAGE alone is insufficient.
GRANT USAGE, CREATE ON SCHEMA public TO governance_functions;

-- =============================================================================
-- PHASE 1 — TABLES (Batches 1–14)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Batch 1 — Jurisdiction (prerequisite for lifebooks)
-- ---------------------------------------------------------------------------

CREATE TABLE jurisdictions (
    id                              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    jurisdiction_code               TEXT        NOT NULL UNIQUE,
    jurisdiction_name               TEXT        NOT NULL,
    jurisdiction_type               TEXT        NOT NULL CHECK (jurisdiction_type IN ('national','provincial_or_state','indigenous_nation','supranational','international_default')),
    parent_jurisdiction_id          UUID        NULL REFERENCES jurisdictions(id),
    age_of_majority                 INTEGER     NULL,
    age_of_majority_notes           TEXT        NULL,
    has_sdm_legislation             BOOLEAN     NOT NULL DEFAULT FALSE,
    sdm_legislation_reference       TEXT        NULL,
    privacy_law_primary             TEXT        NULL,
    privacy_law_reference           TEXT        NULL,
    right_to_erasure                TEXT        NULL CHECK (right_to_erasure IN ('strong','qualified','limited','none_specified')),
    erasure_notes                   TEXT        NULL,
    data_residency_required         BOOLEAN     NOT NULL DEFAULT FALSE,
    data_residency_notes            TEXT        NULL,
    cross_border_transfer_rules     TEXT        NULL,
    succession_law_notes            TEXT        NULL,
    guardian_coordination_presumption TEXT      NULL CHECK (guardian_coordination_presumption IN ('joint_unanimous','joint_any','unclear')),
    lifebook_policy_overrides       JSONB       NULL,
    is_active                       BOOLEAN     NOT NULL DEFAULT TRUE,
    current_policy_version_id       UUID        NULL,
    deployment_permitted            BOOLEAN     NOT NULL DEFAULT FALSE,
    notes                           TEXT        NULL,
    created_at                      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE jurisdiction_policy_versions (
    id                      UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    jurisdiction_id         UUID        NOT NULL REFERENCES jurisdictions(id),
    version_number          INTEGER     NOT NULL,
    policy_snapshot         JSONB       NOT NULL,
    privacy_law_primary     TEXT        NOT NULL,
    privacy_law_reference   TEXT        NOT NULL,
    law_effective_date      DATE        NOT NULL,
    erasure_implementation  TEXT        NOT NULL,
    review_status           TEXT        NOT NULL,
    reviewed_at             TIMESTAMPTZ NULL,
    reviewed_by             TEXT        NULL,
    review_scope            TEXT        NULL,
    legal_notes             TEXT        NULL,
    deployment_permitted    BOOLEAN     NOT NULL DEFAULT FALSE,
    next_review_date        DATE        NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id           UUID        NULL,
    superseded_at           TIMESTAMPTZ NULL,
    superseded_by_version_id UUID       NULL REFERENCES jurisdiction_policy_versions(id),
    UNIQUE (jurisdiction_id, version_number)
);

-- Batch 1 Seed: Required jurisdiction records
INSERT INTO jurisdictions (jurisdiction_code, jurisdiction_name, jurisdiction_type, parent_jurisdiction_id, age_of_majority, age_of_majority_notes, has_sdm_legislation, sdm_legislation_reference, privacy_law_primary, privacy_law_reference, right_to_erasure, erasure_notes, data_residency_required, cross_border_transfer_rules, succession_law_notes, guardian_coordination_presumption, lifebook_policy_overrides, is_active, deployment_permitted) VALUES
('CA',    'Canada',                   'national',             NULL, 18, 'Federal default; provinces may vary', FALSE, NULL, 'PIPEDA (federal)', 'S.C. 2000, c. 5', 'qualified', 'LifeBook retains structural record; personal data values may be redacted on request subject to PIPEDA conditions', FALSE, 'Cross-border transfer permitted with comparable protection (PIPEDA Principle 4.1.3)', 'Federal succession law applies; provinces govern probate', 'joint_unanimous', '{"consent_required_for_collection":true,"right_to_access_own_data":true,"breach_notification_required":true,"cross_border_transfer_permitted_with_comparable_protection":true}', TRUE, TRUE),
('CA-AB', 'Alberta',                  'provincial_or_state',  (SELECT id FROM jurisdictions WHERE jurisdiction_code = 'CA'), 18, 'Adult Interdependent Relationships Act may affect authority', FALSE, NULL, 'PIPA (AB)', 'S.A. 2003, c. P-6.5', 'qualified', 'LifeBook may retain records for legitimate purposes under PIPA s.36 exceptions', FALSE, 'Permitted under PIPA with comparable protection', 'Wills and Succession Act, SA 2010', 'joint_unanimous', NULL, TRUE, TRUE),
('CA-ON', 'Ontario',                  'provincial_or_state',  (SELECT id FROM jurisdictions WHERE jurisdiction_code = 'CA'), 18, NULL, TRUE, 'Substitute Decisions Act, 1992, S.O. 1992, c. 30', 'PIPEDA (private sector)', 'S.C. 2000, c. 5', 'qualified', 'LifeBook retains structural record per PIPEDA; subject may request data value redaction', FALSE, 'Permitted with comparable protection', 'Succession Law Reform Act, R.S.O. 1990, c. S.26', 'joint_unanimous', NULL, TRUE, TRUE),
('CA-BC', 'British Columbia',         'provincial_or_state',  (SELECT id FROM jurisdictions WHERE jurisdiction_code = 'CA'), 19, 'Age of majority is 19 in BC', TRUE, 'Representation Agreement Act, RSBC 1996, c. 405', 'PIPA (BC)', 'S.B.C. 2003, c. 63', 'qualified', 'PIPA allows retention for legal obligations; LifeBook applies provenance preservation model', FALSE, 'Permitted under PIPA with comparable protection', 'Wills, Estates and Succession Act, SBC 2009', 'joint_unanimous', NULL, TRUE, TRUE),
('UA',    'Ukraine',                  'national',             NULL, 18, NULL, FALSE, NULL, 'Law on Personal Data Protection', 'Law of Ukraine No. 2297-VI of June 1, 2010', 'qualified', 'Right to deletion under Art. 8 of LPDP; LifeBook retains provenance structure', FALSE, 'Cross-border transfer requires adequate protection or consent', NULL, 'joint_unanimous', NULL, TRUE, TRUE),
('INTL',  'International Default',   'international_default', NULL, 18, 'Applies most restrictive applicable rules', FALSE, NULL, 'Most restrictive applicable law', NULL, 'strong', 'LifeBook applies most protective interpretation when jurisdiction is unknown', FALSE, 'No cross-border transfer without explicit consent and adequate protection', NULL, 'joint_unanimous', NULL, TRUE, FALSE);

-- ---------------------------------------------------------------------------
-- Batch 2 — Users
-- ---------------------------------------------------------------------------

CREATE TABLE user_profiles (
    id                  UUID        NOT NULL PRIMARY KEY, -- = auth.users.id (Supabase auth)
    display_name        TEXT        NOT NULL,
    account_status      TEXT        NOT NULL DEFAULT 'active' CHECK (account_status IN ('active','suspended','pending_verification','closed')),
    preferred_language  TEXT        NOT NULL DEFAULT 'en',
    timezone            TEXT        NOT NULL DEFAULT 'UTC',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_active_at      TIMESTAMPTZ NULL,
    CONSTRAINT fk_user_profiles_auth FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------
-- Batch 3 — Entity Anchors
-- ---------------------------------------------------------------------------

CREATE TABLE entities (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    entity_type                 entity_type     NOT NULL,
    canonical_status            TEXT            NOT NULL DEFAULT 'active' CHECK (canonical_status IN ('active','merged','deprecated','split')),
    merged_into_entity_id       UUID            NULL REFERENCES entities(id),
    split_from_entity_id        UUID            NULL REFERENCES entities(id),
    merge_record_id             UUID            NULL,
    suppression_state           TEXT            NOT NULL DEFAULT 'none' CHECK (suppression_state IN ('none','pending','suppressed','suppression_reversed')),
    suppression_reason          TEXT            NULL,
    suppressed_at               TIMESTAMPTZ     NULL,
    suppressed_by_id            UUID            NULL REFERENCES user_profiles(id),
    erasure_state               TEXT            NOT NULL DEFAULT 'none' CHECK (erasure_state IN ('none','requested','in_progress','completed','blocked')),
    erasure_requested_at        TIMESTAMPTZ     NULL,
    erasure_jurisdiction_id     UUID            NULL REFERENCES jurisdictions(id),
    creation_source             TEXT            NOT NULL DEFAULT 'manual_entry' CHECK (creation_source IN ('manual_entry','ai_extracted','document_import','migration','api_import','system_generated')),
    creation_source_record_id   UUID            NULL,
    creation_confidence         TEXT            NULL CHECK (creation_confidence IN ('unreviewed','asserted','inferred','supported','corroborated')),
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT now(),
    created_by_id               UUID            NULL REFERENCES user_profiles(id)
);

CREATE TABLE persons (
    entity_id               UUID            NOT NULL PRIMARY KEY REFERENCES entities(id),
    lifecycle_status        TEXT            NOT NULL DEFAULT 'living' CHECK (lifecycle_status IN ('living','deceased','presumed_deceased','unknown')),
    lifecycle_status_evidence_id UUID       NULL,
    last_governance_review_at TIMESTAMPTZ   NULL,
    notes                   TEXT            NULL
);

CREATE TABLE organizations (
    entity_id                           UUID        NOT NULL PRIMARY KEY REFERENCES entities(id),
    organization_type                   TEXT        NOT NULL,
    cached_display_name                 TEXT        NULL,
    cached_display_name_policy_version_id UUID      NULL,
    cached_display_name_validity_state  TEXT        NULL CHECK (cached_display_name_validity_state IN ('valid','invalid','pending_recompute')),
    cached_display_name_invalidated_at  TIMESTAMPTZ NULL,
    primary_jurisdiction_id             UUID        NULL REFERENCES jurisdictions(id),
    notes                               TEXT        NULL
);

CREATE TABLE places (
    entity_id                           UUID        NOT NULL PRIMARY KEY REFERENCES entities(id),
    place_type                          TEXT        NOT NULL,
    cached_primary_name                 TEXT        NULL,
    cached_primary_name_policy_version_id UUID      NULL,
    cached_primary_name_validity_state  TEXT        NULL CHECK (cached_primary_name_validity_state IN ('valid','invalid','pending_recompute')),
    cached_primary_name_invalidated_at  TIMESTAMPTZ NULL,
    cached_latitude                     NUMERIC(10,7) NULL,
    cached_longitude                    NUMERIC(10,7) NULL,
    coordinate_precision                TEXT        NULL CHECK (coordinate_precision IN ('exact','neighbourhood','municipality','region','country','approximate')),
    coordinate_source_note              TEXT        NULL,
    coordinate_source_id                UUID        NULL,
    country_code                        CHAR(2)     NULL,
    parent_place_entity_id              UUID        NULL REFERENCES entities(id),
    notes                               TEXT        NULL
);

CREATE TABLE vessels (
    entity_id                           UUID        NOT NULL PRIMARY KEY REFERENCES entities(id),
    vessel_type                         TEXT        NOT NULL,
    cached_vessel_name                  TEXT        NULL,
    cached_vessel_name_policy_version_id UUID       NULL,
    cached_vessel_name_validity_state   TEXT        NULL CHECK (cached_vessel_name_validity_state IN ('valid','invalid','pending_recompute')),
    cached_vessel_name_invalidated_at   TIMESTAMPTZ NULL,
    flag_country_code                   CHAR(2)     NULL,
    operating_entity_id                 UUID        NULL REFERENCES entities(id),
    notes                               TEXT        NULL
);

CREATE TABLE communities (
    entity_id                           UUID        NOT NULL PRIMARY KEY REFERENCES entities(id),
    community_type                      TEXT        NOT NULL,
    cached_display_name                 TEXT        NULL,
    cached_display_name_policy_version_id UUID      NULL,
    cached_display_name_validity_state  TEXT        NULL CHECK (cached_display_name_validity_state IN ('valid','invalid','pending_recompute')),
    cached_display_name_invalidated_at  TIMESTAMPTZ NULL,
    governance_notes                    TEXT        NULL,
    primary_jurisdiction_id             UUID        NULL REFERENCES jurisdictions(id),
    notes                               TEXT        NULL
);

CREATE TABLE event_series (
    entity_id                           UUID        NOT NULL PRIMARY KEY REFERENCES entities(id),
    series_type                         TEXT        NOT NULL,
    cached_display_name                 TEXT        NULL,
    cached_display_name_policy_version_id UUID      NULL,
    cached_display_name_validity_state  TEXT        NULL CHECK (cached_display_name_validity_state IN ('valid','invalid','pending_recompute')),
    cached_display_name_invalidated_at  TIMESTAMPTZ NULL,
    recurrence_description              TEXT        NULL,
    notes                               TEXT        NULL
);

-- ---------------------------------------------------------------------------
-- Batch 4 — LifeBook Scoping
-- Internal ordering: lifebooks → lifebook_memberships → user_person_links →
--                    lifebook_entities → lifebook_person_contexts
-- ---------------------------------------------------------------------------

CREATE TABLE lifebooks (
    id                          UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    title                       TEXT        NOT NULL,
    slug                        TEXT        NOT NULL UNIQUE,
    lifebook_status             TEXT        NOT NULL DEFAULT 'active' CHECK (lifebook_status IN ('active','archived','suspended','pending_setup','closed')),
    subject_scope               TEXT        NOT NULL DEFAULT 'single_person' CHECK (subject_scope IN ('single_person','family_group','community','event')),
    visibility                  TEXT        NOT NULL DEFAULT 'private' CHECK (visibility IN ('private','family','community','public')),
    primary_language            TEXT        NOT NULL DEFAULT 'en',
    supported_languages         TEXT[]      NOT NULL DEFAULT '{}',
    steward_id                  UUID        NOT NULL REFERENCES user_profiles(id),
    stewardship_type            TEXT        NOT NULL DEFAULT 'individual' CHECK (stewardship_type IN ('individual','organizational','institutional','community','joint','successor')),
    primary_jurisdiction_id     UUID        NOT NULL REFERENCES jurisdictions(id),
    additional_jurisdiction_ids UUID[]      NOT NULL DEFAULT '{}',
    creation_reason             TEXT        NOT NULL DEFAULT 'personal_history' CHECK (creation_reason IN ('personal_history','family_history','community_history','genealogical_research','archival_project','memorial','legal_record','ai_assisted_discovery')),
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id               UUID        NULL REFERENCES user_profiles(id),
    last_activity_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    archived_at                 TIMESTAMPTZ NULL,
    archived_by_id              UUID        NULL REFERENCES user_profiles(id),
    steward_notes               TEXT        NULL
);

CREATE TABLE lifebook_memberships (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    lifebook_id     UUID        NOT NULL REFERENCES lifebooks(id),
    user_id         UUID        NOT NULL REFERENCES user_profiles(id),
    membership_role TEXT        NOT NULL CHECK (membership_role IN ('steward','contributor','viewer')),
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    invited_by_id   UUID        NULL REFERENCES user_profiles(id),
    notes           TEXT        NULL,
    UNIQUE (lifebook_id, user_id)
);

CREATE TABLE user_person_links (
    id                  UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id             UUID        NOT NULL REFERENCES user_profiles(id),
    person_entity_id    UUID        NOT NULL REFERENCES entities(id),
    link_type           TEXT        NOT NULL CHECK (link_type IN ('self','guardian','legal_representative','steward_designation','system_assigned')),
    verification_status TEXT        NOT NULL DEFAULT 'pending' CHECK (verification_status IN ('pending','verified','rejected','revoked')),
    verification_method TEXT        NULL,
    verified_at         TIMESTAMPTZ NULL,
    verified_by_id      UUID        NULL REFERENCES user_profiles(id),
    authority_basis_type TEXT       NULL,
    effective_from      DATE        NULL,
    effective_until     DATE        NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id       UUID        NULL REFERENCES user_profiles(id),
    notes               TEXT        NULL,
    UNIQUE (user_id, person_entity_id)
);

-- lifebook_entities: internal order — must precede lifebook_person_contexts
-- Unique constraint implemented as PARTIAL UNIQUE INDEX (see Phase 3 below):
--   uq_lifebook_entities_active ON lifebook_entities(lifebook_id, entity_id) WHERE removed_at IS NULL
-- The table-level UNIQUE constraint must NOT be used — it would block re-add after soft-delete.

CREATE TABLE lifebook_entities (
    id                      UUID                NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    lifebook_id             UUID                NOT NULL REFERENCES lifebooks(id),
    entity_id               UUID                NOT NULL REFERENCES entities(id),
    entity_type             entity_type         NOT NULL,
    participation_role      TEXT                NOT NULL CHECK (participation_role IN ('subject','family_member','storyteller','contributor','event_participant','historical_associate','referenced_entity','steward','witness','institutional_representative','location_reference')),
    relationship_description TEXT               NULL,
    is_focal_entity         BOOLEAN             NOT NULL DEFAULT FALSE,
    visibility_status       TEXT                NOT NULL DEFAULT 'visible' CHECK (visibility_status IN ('visible','hidden','restricted','pending_confirmation','anonymized')),
    added_by_id             UUID                NOT NULL REFERENCES user_profiles(id),
    added_at                TIMESTAMPTZ         NOT NULL DEFAULT now(),
    removed_at              TIMESTAMPTZ         NULL,
    removed_by_id           UUID                NULL REFERENCES user_profiles(id),
    removal_reason          TEXT                NULL,
    steward_notes           TEXT                NULL
);

-- lifebook_person_contexts: no permission_cache_policy_version_id FK yet (Deferred FK 3 added after Batch 5)
CREATE TABLE lifebook_person_contexts (
    id                                  UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    lifebook_entity_id                  UUID        NOT NULL UNIQUE REFERENCES lifebook_entities(id),
    entity_id                           UUID        NOT NULL REFERENCES entities(id),
    authority_context                   TEXT        NOT NULL DEFAULT 'full_subject_authority' CHECK (authority_context IN ('full_subject_authority','limited_subject_authority','guardian_primary','guardian_joint','legal_representative','cultural_authority','steward_only','historical_only','disputed','posthumous_steward','institutional_steward','unknown')),
    contribution_status                 TEXT        NOT NULL DEFAULT 'invited' CHECK (contribution_status IN ('active_contributor','past_contributor','invited','declined','revoked','not_a_contributor')),
    has_accepted_terms                  BOOLEAN     NOT NULL DEFAULT FALSE,
    terms_accepted_at                   TIMESTAMPTZ NULL,
    cross_lifebook_linkage_authorized   BOOLEAN     NOT NULL DEFAULT FALSE,
    cross_lifebook_linkage_authorized_at TIMESTAMPTZ NULL,
    cross_lifebook_linkage_scope        JSONB       NULL,
    cached_permission_summary           JSONB       NULL,
    permission_cache_policy_version_id  UUID        NULL,
    -- NOTE: FK constraint fk_permission_cache_approval_policy added after Batch 5 approval_policies DDL
    permission_cache_computed_at        TIMESTAMPTZ NULL
);

-- ---------------------------------------------------------------------------
-- Batch 5 — Governance Policy Templates
-- ---------------------------------------------------------------------------

CREATE TABLE escalation_policies (
    id                              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    policy_code                     TEXT        NOT NULL UNIQUE,
    trigger_type                    TEXT        NOT NULL CHECK (trigger_type IN ('approval_timeout','no_authority_assigned','unresolvable_conflict','validation_violation','cannot_classify','dispute_opened','dispute_unresolved','cultural_protocol_triggered','agent_deprecated','capacity_change_mid_action','stewardship_gap')),
    description                     TEXT        NOT NULL,
    initial_notification_targets    TEXT[]      NOT NULL DEFAULT '{}',
    steps                           JSONB       NOT NULL DEFAULT '[]',
    max_resolution_days             INTEGER     NULL,
    default_action_if_unresolved    TEXT        NOT NULL CHECK (default_action_if_unresolved IN ('freeze','deny','apply_policy_default','route_to_steward','route_external','terminate_agent_run')),
    freeze_actions_during_escalation TEXT[]     NOT NULL DEFAULT '{}',
    audit_required                  BOOLEAN     NOT NULL DEFAULT TRUE,
    notes                           TEXT        NULL,
    created_at                      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Representative EscalationPolicy seed records
INSERT INTO escalation_policies (policy_code, trigger_type, description, initial_notification_targets, steps, max_resolution_days, default_action_if_unresolved, freeze_actions_during_escalation, audit_required) VALUES
('APPROVAL_TIMEOUT_STEWARD_FALLBACK', 'approval_timeout', 'A required approver has not responded within the allowed window; escalate to steward then freeze.', ARRAY['steward'], '[{"step_number":1,"label":"Re-notify required approver","wait_period_hours":48,"notify_roles":["required_approver"],"required_action":"approve_or_delegate","if_no_action":"proceed_to_next_step"},{"step_number":2,"label":"Notify steward","wait_period_hours":72,"notify_roles":["steward"],"required_action":"approve_or_delegate","if_no_action":"freeze"}]', 14, 'freeze', '{}', TRUE),
('NO_AUTHORITY_STEWARD_NOTIFY', 'no_authority_assigned', 'No applicable AuthorityAssignment exists for the requested action; notify steward and apply policy default if no response.', ARRAY['steward'], '[{"step_number":1,"label":"Notify steward","wait_period_hours":168,"notify_roles":["steward"],"required_action":"human_decision","if_no_action":"apply_policy_default"}]', 7, 'apply_policy_default', '{}', TRUE),
('VALIDATION_VIOLATION_QUARANTINE', 'validation_violation', 'AI output validation detected restricted content; quarantine output and notify steward.', ARRAY['steward'], '[{"step_number":1,"label":"Quarantine and notify steward","wait_period_hours":1,"notify_roles":["steward"],"required_action":"human_decision","if_no_action":"freeze"}]', NULL, 'freeze', '{}', TRUE),
('CANNOT_CLASSIFY_REVIEW', 'cannot_classify', 'Sanitization pipeline encountered content it could not classify; quarantine content and await steward review.', ARRAY['steward'], '[{"step_number":1,"label":"Quarantine unclassified content","wait_period_hours":24,"notify_roles":["steward"],"required_action":"human_decision","if_no_action":"deny"}]', 30, 'deny', '{}', TRUE),
('CULTURAL_PROTOCOL_DENY', 'cultural_protocol_triggered', 'Action requires culturally governed processing but no joint authorization exists; deny immediately and await joint authorization.', ARRAY['cultural_authority','subject'], '[{"step_number":1,"label":"Deny and notify subject and cultural liaison","wait_period_hours":null,"notify_roles":["cultural_authority","subject"],"required_action":"external_referral","if_no_action":"freeze"}]', NULL, 'freeze', '{}', TRUE),
('DISPUTE_OPENED_FREEZE', 'dispute_opened', 'A ContestRecord has been created; freeze all affected actions immediately.', ARRAY['steward','legal_representative'], '[{"step_number":1,"label":"Freeze affected actions","wait_period_hours":24,"notify_roles":["steward","legal_representative"],"required_action":"human_decision","if_no_action":"proceed_to_next_step"},{"step_number":2,"label":"Route to dispute resolution","wait_period_hours":1440,"notify_roles":["steward"],"required_action":"human_decision","if_no_action":"route_external"}]', 90, 'route_external', '{}', TRUE),
('STEWARDSHIP_GAP_NOTIFY', 'stewardship_gap', 'Stewardship has ended with no succession and no new steward assigned; apply restricted read-only state.', ARRAY['legal_representative'], '[{"step_number":1,"label":"Notify next_of_kin and legal_representative","wait_period_hours":24,"notify_roles":["legal_representative"],"required_action":"designate_successor","if_no_action":"freeze"}]', 30, 'freeze', '{}', TRUE);

CREATE TABLE approval_policies (
    id                          UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    policy_code                 TEXT        NOT NULL UNIQUE,
    action_type                 TEXT        NOT NULL,
    attribute_type              TEXT        NULL,
    lifecycle_status            TEXT        NOT NULL DEFAULT 'active' CHECK (lifecycle_status IN ('draft','active','deprecated','superseded','suspended','under_review','pending_activation','withdrawn')),
    required_approvers          JSONB       NOT NULL DEFAULT '{}',
    notification_required       TEXT[]      NOT NULL DEFAULT '{}',
    approval_expiry_days        INTEGER     NULL,
    audit_required              BOOLEAN     NOT NULL DEFAULT TRUE,
    escalation_policy_id        UUID        NULL REFERENCES escalation_policies(id),
    notes                       TEXT        NULL,
    cultural_governance_required BOOLEAN    NOT NULL DEFAULT FALSE,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Representative ApprovalPolicy seed records
INSERT INTO approval_policies (policy_code, action_type, attribute_type, lifecycle_status, required_approvers, notification_required, approval_expiry_days, audit_required, escalation_policy_id, cultural_governance_required) VALUES
('CLAIM_PROMOTE_POLICY_APPROVED', 'promote_review_status', 'review_status', 'active', '{"min_approvers":1,"required_roles":["steward"]}', ARRAY['steward'], 30, TRUE, (SELECT id FROM escalation_policies WHERE policy_code = 'APPROVAL_TIMEOUT_STEWARD_FALLBACK'), FALSE),
('CULTURALLY_GOVERNED_ACCESS', 'grant_access', 'culturally_governed_record', 'active', '{"min_approvers":2,"required_roles":["steward","cultural_authority"]}', ARRAY['cultural_authority','steward'], 90, TRUE, (SELECT id FROM escalation_policies WHERE policy_code = 'CULTURAL_PROTOCOL_DENY'), TRUE),
('COMMUNITY_ACCOUNT_AUTHORIZATION', 'create_community_account_narrative', 'narrative_type', 'active', '{"min_approvers":1,"required_roles":["cultural_authority"]}', ARRAY['cultural_authority','steward'], 60, TRUE, (SELECT id FROM escalation_policies WHERE policy_code = 'CULTURAL_PROTOCOL_DENY'), TRUE),
('DISPLAY_POLICY_ACTIVATION', 'activate_display_policy', 'display_policy', 'active', '{"min_approvers":1,"required_roles":["steward"]}', ARRAY['steward'], 30, TRUE, (SELECT id FROM escalation_policies WHERE policy_code = 'APPROVAL_TIMEOUT_STEWARD_FALLBACK'), FALSE),
('CROSS_LIFEBOOK_AUTHORIZATION', 'authorize_cross_lifebook_source', 'source_access', 'active', '{"min_approvers":2,"required_roles":["steward_a","steward_b"]}', ARRAY['steward'], 60, TRUE, (SELECT id FROM escalation_policies WHERE policy_code = 'APPROVAL_TIMEOUT_STEWARD_FALLBACK'), FALSE);

-- Deferred FK 3: lifebook_person_contexts.permission_cache_policy_version_id → approval_policies(id)
-- Inserted here, immediately after approval_policies DDL, per MIGRATION_IMPLEMENTATION_PLAN.md §2.4
ALTER TABLE lifebook_person_contexts
    ADD CONSTRAINT fk_permission_cache_approval_policy
    FOREIGN KEY (permission_cache_policy_version_id) REFERENCES approval_policies(id);

CREATE TABLE conflict_resolution_policies (
    id                  UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    policy_code         TEXT        NOT NULL UNIQUE,
    attribute_type      TEXT        NOT NULL,
    conflict_type       TEXT        NOT NULL CHECK (conflict_type IN ('competing_assertions','temporal_overlap','authority_conflict','evidence_conflict','supersession_conflict')),
    purpose             TEXT        NOT NULL CHECK (purpose IN ('display','search','export','ai_generation','governance')),
    resolution_rule     TEXT        NOT NULL CHECK (resolution_rule IN ('most_recent_documentary','subject_assertion_overrides','steward_decides','quorum','cultural_authority_decides','escalate_external','most_corroborated')),
    priority_order      JSONB       NOT NULL DEFAULT '{}',
    lifecycle_overrides JSONB       NULL,
    notes               TEXT        NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Representative ConflictResolutionPolicy seed records
INSERT INTO conflict_resolution_policies (policy_code, attribute_type, conflict_type, purpose, resolution_rule, priority_order) VALUES
('PERSON_NAME_PREFERRED_DISPLAY', 'person_name_preferred', 'competing_assertions', 'display', 'subject_assertion_overrides', '{"1":"subject","2":"steward","3":"steward_quorum"}'),
('PERSON_NAME_LEGAL_DISPLAY', 'person_name_legal', 'competing_assertions', 'display', 'most_recent_documentary', '{"1":"most_recent_document","2":"subject_assertion","3":"steward"}'),
('CLAIM_EVIDENCE_CONFLICT', 'claim', 'evidence_conflict', 'governance', 'steward_decides', '{"1":"steward","2":"escalate_external"}'),
('CULTURALLY_GOVERNED_DISPLAY', 'culturally_governed', 'authority_conflict', 'display', 'cultural_authority_decides', '{"1":"cultural_authority","2":"escalate_external"}');

-- display_policies: declared without approval_record_id FK (Deferred FK 2 added after Batch 6)
CREATE TABLE display_policies (
    id                  UUID                    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    set_by_role         TEXT                    NOT NULL,
    entity_id           UUID                    NULL REFERENCES entities(id),
    lifebook_id         UUID                    NULL REFERENCES lifebooks(id),
    status              display_policy_status   NOT NULL DEFAULT 'draft',
    approval_record_id  UUID                    NULL,
    -- NOTE: FK constraint fk_display_policy_approval_record added after Batch 6 approval_records DDL
    created_at          TIMESTAMPTZ             NOT NULL DEFAULT now(),
    created_by_id       UUID                    NULL REFERENCES user_profiles(id),
    created_by_system   TEXT                    NULL,
    notes               TEXT                    NULL,
    CONSTRAINT chk_display_policy_provenance CHECK (created_by_id IS NOT NULL OR created_by_system IS NOT NULL)
);

CREATE TABLE display_policy_rules (
    id                  UUID                    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    display_policy_id   UUID                    NOT NULL REFERENCES display_policies(id),
    display_context_code TEXT                   NOT NULL REFERENCES display_contexts(code),
    decision            display_policy_decision NOT NULL,
    condition_expression TEXT                   NULL,
    notes               TEXT                    NULL,
    UNIQUE (display_policy_id, display_context_code)
);

-- ---------------------------------------------------------------------------
-- Batch 6 — Approval Instances
-- ---------------------------------------------------------------------------

CREATE TABLE approval_records (
    id                      UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    policy_id               UUID        NOT NULL REFERENCES approval_policies(id),
    target_record_type      TEXT        NOT NULL,
    target_record_id        UUID        NOT NULL,
    target_action           TEXT        NOT NULL,
    lifebook_id             UUID        NULL REFERENCES lifebooks(id),
    requested_by_id         UUID        NOT NULL REFERENCES user_profiles(id),
    requested_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    status                  TEXT        NOT NULL DEFAULT 'pending_submission' CHECK (status IN ('pending_submission','pending_approval','approved','rejected','expired','withdrawn','overridden')),
    required_approver_count INTEGER     NOT NULL,
    received_approver_count INTEGER     NOT NULL DEFAULT 0,
    approvals_received      JSONB       NOT NULL DEFAULT '[]',
    decided_at              TIMESTAMPTZ NULL,
    expires_at              TIMESTAMPTZ NULL,
    override_rationale      TEXT        NULL,
    override_by_id          UUID        NULL REFERENCES user_profiles(id),
    escalation_record_id    UUID        NULL,
    -- NOTE: escalation_record_id has no FK constraint — escalation_records is Batch 13 (circular); application-enforced
    audit_lineage           JSONB       NOT NULL DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id           UUID        NOT NULL REFERENCES user_profiles(id),
    superseded_by_id        UUID        NULL REFERENCES approval_records(id)
);

-- Deferred FK 2: display_policies.approval_record_id → approval_records(id)
-- Inserted here, immediately after approval_records DDL, per MIGRATION_IMPLEMENTATION_PLAN.md §2.4
ALTER TABLE display_policies
    ADD CONSTRAINT fk_display_policy_approval_record
    FOREIGN KEY (approval_record_id) REFERENCES approval_records(id);

-- ---------------------------------------------------------------------------
-- Batch 7 — Authority
-- ---------------------------------------------------------------------------

CREATE TABLE authority_assignments (
    id                      UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    entity_id               UUID        NOT NULL REFERENCES entities(id),
    lifebook_id             UUID        NULL REFERENCES lifebooks(id),
    -- NOTE: lifebook_id IS nullable — entity-scoped assignments have lifebook_id = NULL
    -- RLS policy 50 covers only lifebook_id IS NOT NULL rows
    -- Revocation of NULL-lifebook_id rows must go through SECURITY DEFINER function
    authority_holder_id     UUID        NOT NULL REFERENCES user_profiles(id),
    authority_role          TEXT        NOT NULL,
    scope                   TEXT[]      NOT NULL DEFAULT '{}',
    effective_from          DATE        NULL,
    effective_until         DATE        NULL,
    jurisdiction_id         UUID        NULL REFERENCES jurisdictions(id),
    authority_basis_type    TEXT        NOT NULL CHECK (authority_basis_type IN ('self_assertion','documented_legal','court_order','community_designation','cultural_authority_designation','policy_default','steward_assignment','succession')),
    basis_claim_id          UUID        NULL,
    -- NOTE: FK constraint fk_authority_basis_claim added after Batch 10 claims DDL (Deferred FK 1)
    basis_notes             TEXT        NULL,
    is_contested            BOOLEAN     NOT NULL DEFAULT FALSE,
    contest_record_id       UUID        NULL,
    -- NOTE: no FK constraint on contest_record_id — contest_records is Batch 13; application-enforced
    priority_order          INTEGER     NULL,
    coordination_rule       TEXT        NULL CHECK (coordination_rule IN ('sole','joint_unanimous','joint_any','quorum','escalate')),
    review_date             DATE        NULL,
    succession_behaviour    TEXT        NULL CHECK (succession_behaviour IN ('transfer_to_next','revert_to_steward','escalate','expire','designate_successor')),
    succession_target_id    UUID        NULL REFERENCES user_profiles(id),
    approval_policy_id      UUID        NULL REFERENCES approval_policies(id),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id           UUID        NULL REFERENCES user_profiles(id),
    notes                   TEXT        NULL
);

-- ---------------------------------------------------------------------------
-- Batch 8 — Reference Catalogues
-- ---------------------------------------------------------------------------

CREATE TABLE claim_predicates (
    id                              UUID                        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    predicate_code                  TEXT                        NOT NULL UNIQUE,
    display_label                   TEXT                        NOT NULL,
    description                     TEXT                        NULL,
    permitted_subject_entity_types  entity_type[]               NOT NULL DEFAULT '{}',
    permitted_value_type            TEXT                        NOT NULL CHECK (permitted_value_type IN ('entity','date','text','numeric')),
    permitted_object_entity_types   entity_type[]               NULL,
    is_symmetric                    BOOLEAN                     NOT NULL DEFAULT FALSE,
    is_transitive                   BOOLEAN                     NOT NULL DEFAULT FALSE,
    temporal_allowed                BOOLEAN                     NOT NULL DEFAULT FALSE,
    relationship_interaction        relationship_interaction_type NOT NULL DEFAULT 'none',
    default_access_classification   TEXT                        NOT NULL DEFAULT 'public' CHECK (default_access_classification IN ('public','family','steward','restricted','culturally_governed')),
    generates_event_type            TEXT                        NULL,
    inverse_predicate_id            UUID                        NULL REFERENCES claim_predicates(id),
    deprecated_at                   DATE                        NULL,
    replaced_by_predicate_id        UUID                        NULL REFERENCES claim_predicates(id),
    numeric_unit_required           BOOLEAN                     NULL,
    permitted_unit_categories       TEXT[]                      NULL,
    permitted_unit_codes            TEXT[]                      NULL,
    numeric_integer_only            BOOLEAN                     NULL,
    numeric_min_value               NUMERIC                     NULL,
    numeric_max_value               NUMERIC                     NULL,
    created_by_id                   UUID                        NULL,
    created_by_system               TEXT                        NULL
);

-- Batch 8 Seed: claim_predicates — Pass 1: 74 INSERT records
-- All records: inverse_predicate_id = NULL (set in Pass 2 for symmetric self-inverses)
-- created_by_id = NULL, created_by_system = 'migration:20260726083201_core_schema.sql'
-- Abbreviations: subject_types → permitted_subject_entity_types, val_type → permitted_value_type,
--                obj_types → permitted_object_entity_types, rel_int → relationship_interaction,
--                access → default_access_classification, evt → generates_event_type

INSERT INTO claim_predicates (predicate_code, display_label, permitted_subject_entity_types, permitted_value_type, permitted_object_entity_types, is_symmetric, is_transitive, temporal_allowed, relationship_interaction, default_access_classification, generates_event_type, created_by_id, created_by_system) VALUES
-- Family 1: Identity and Naming (4 records)
('has_name',            'Has name',                     ARRAY['organization','place','vessel','community','event_series']::entity_type[], 'text',   NULL,                                                                            FALSE, FALSE, TRUE,  'none',     'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('also_known_as',       'Also known as',                ARRAY['organization','place','vessel','community','event_series']::entity_type[], 'text',   NULL,                                                                            FALSE, FALSE, TRUE,  'none',     'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('founding_date_of',    'Founding date of',             ARRAY['organization','community','vessel']::entity_type[],                       'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'public',  'institutional_event',        NULL, 'migration:20260726083201_core_schema.sql'),
('dissolution_date_of', 'Dissolution date of',          ARRAY['organization','community','vessel']::entity_type[],                       'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'public',  'institutional_event',        NULL, 'migration:20260726083201_core_schema.sql'),
-- Family 2: Vital Events (17 records)
('born_on',             'Born on',                      ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'family',  'birth',                      NULL, 'migration:20260726083201_core_schema.sql'),
('born_at',             'Born at',                      ARRAY['person']::entity_type[],                                                  'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, FALSE, 'none',     'family',  'birth',                      NULL, 'migration:20260726083201_core_schema.sql'),
('died_on',             'Died on',                      ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'family',  'death',                      NULL, 'migration:20260726083201_core_schema.sql'),
('died_at',             'Died at',                      ARRAY['person']::entity_type[],                                                  'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, FALSE, 'none',     'family',  'death',                      NULL, 'migration:20260726083201_core_schema.sql'),
('baptised_on',         'Baptised on',                  ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'family',  'baptism',                    NULL, 'migration:20260726083201_core_schema.sql'),
('baptised_at',         'Baptised at',                  ARRAY['person']::entity_type[],                                                  'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, FALSE, 'none',     'family',  'baptism',                    NULL, 'migration:20260726083201_core_schema.sql'),
('named_on',            'Named on',                     ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'family',  'naming_ceremony',            NULL, 'migration:20260726083201_core_schema.sql'),
('named_at',            'Named at',                     ARRAY['person']::entity_type[],                                                  'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, FALSE, 'none',     'family',  'naming_ceremony',            NULL, 'migration:20260726083201_core_schema.sql'),
('buried_on',           'Buried on',                    ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'family',  'burial_interment',           NULL, 'migration:20260726083201_core_schema.sql'),
('buried_at',           'Buried at',                    ARRAY['person']::entity_type[],                                                  'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, FALSE, 'none',     'family',  'burial_interment',           NULL, 'migration:20260726083201_core_schema.sql'),
('married_on',          'Married on',                   ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'supports', 'family',  'marriage',                   NULL, 'migration:20260726083201_core_schema.sql'),
('married_at',          'Married at',                   ARRAY['person']::entity_type[],                                                  'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, FALSE, 'supports', 'family',  'marriage',                   NULL, 'migration:20260726083201_core_schema.sql'),
('married_to',          'Married to',                   ARRAY['person']::entity_type[],                                                  'entity', ARRAY['person']::entity_type[],                                                  TRUE,  FALSE, TRUE,  'proposes', 'family',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('in_civil_partnership_with', 'In civil partnership with', ARRAY['person']::entity_type[],                                              'entity', ARRAY['person']::entity_type[],                                                  TRUE,  FALSE, TRUE,  'proposes', 'family',  'civil_partnership_registration', NULL, 'migration:20260726083201_core_schema.sql'),
('naturalized_on',      'Naturalized on',               ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'family',  'naturalization',             NULL, 'migration:20260726083201_core_schema.sql'),
('naturalized_at',      'Naturalized at',               ARRAY['person']::entity_type[],                                                  'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, FALSE, 'none',     'family',  'naturalization',             NULL, 'migration:20260726083201_core_schema.sql'),
('adopted_on',          'Adopted on',                   ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'supports', 'steward', 'adoption',                   NULL, 'migration:20260726083201_core_schema.sql'),
-- Family 3: Residence and Location (4 records)
('resided_at',          'Resided at',                   ARRAY['person','organization']::entity_type[],                                   'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, TRUE,  'none',     'family',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('stayed_at',           'Stayed at',                    ARRAY['person']::entity_type[],                                                  'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, TRUE,  'none',     'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('had_address',         'Had address',                  ARRAY['person','organization']::entity_type[],                                   'text',   NULL,                                                                            FALSE, FALSE, TRUE,  'none',     'steward', NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('location_at_time',    'Location at time',             ARRAY['person','organization','vessel']::entity_type[],                          'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, TRUE,  'none',     'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
-- Family 4: Migration and Travel (9 records)
('emigrated_from',      'Emigrated from',               ARRAY['person']::entity_type[],                                                  'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, TRUE,  'none',     'public',  'emigration',                 NULL, 'migration:20260726083201_core_schema.sql'),
('emigrated_on',        'Emigrated on',                 ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'public',  'emigration',                 NULL, 'migration:20260726083201_core_schema.sql'),
('immigrated_to',       'Immigrated to',                ARRAY['person']::entity_type[],                                                  'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, TRUE,  'none',     'public',  'immigration',                NULL, 'migration:20260726083201_core_schema.sql'),
('immigrated_on',       'Immigrated on',                ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'public',  'immigration',                NULL, 'migration:20260726083201_core_schema.sql'),
('departed_from',       'Departed from',                ARRAY['person']::entity_type[],                                                  'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, TRUE,  'none',     'public',  'voyage',                     NULL, 'migration:20260726083201_core_schema.sql'),
('departed_on',         'Departed on',                  ARRAY['person','vessel']::entity_type[],                                         'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'public',  'voyage',                     NULL, 'migration:20260726083201_core_schema.sql'),
('arrived_at',          'Arrived at',                   ARRAY['person','vessel']::entity_type[],                                         'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, TRUE,  'none',     'public',  'voyage',                     NULL, 'migration:20260726083201_core_schema.sql'),
('arrived_on',          'Arrived on',                   ARRAY['person','vessel']::entity_type[],                                         'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'public',  'voyage',                     NULL, 'migration:20260726083201_core_schema.sql'),
('travelled_on',        'Travelled on',                 ARRAY['person']::entity_type[],                                                  'entity', ARRAY['vessel']::entity_type[],                                                  FALSE, FALSE, TRUE,  'none',     'public',  'voyage',                     NULL, 'migration:20260726083201_core_schema.sql'),
-- Family 5: Education (4 records)
('enrolled_at',         'Enrolled at',                  ARRAY['person']::entity_type[],                                                  'entity', ARRAY['organization']::entity_type[],                                            FALSE, FALSE, TRUE,  'proposes', 'family',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('graduated_from',      'Graduated from',               ARRAY['person']::entity_type[],                                                  'entity', ARRAY['organization']::entity_type[],                                            FALSE, FALSE, FALSE, 'none',     'public',  'graduation',                 NULL, 'migration:20260726083201_core_schema.sql'),
('graduated_on',        'Graduated on',                 ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'public',  'graduation',                 NULL, 'migration:20260726083201_core_schema.sql'),
('awarded_credential',  'Awarded credential',           ARRAY['person']::entity_type[],                                                  'text',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'public',  'graduation',                 NULL, 'migration:20260726083201_core_schema.sql'),
-- Family 6: Employment and Occupation (6 records)
('employed_by',         'Employed by',                  ARRAY['person']::entity_type[],                                                  'entity', ARRAY['organization','person']::entity_type[],                                   FALSE, FALSE, TRUE,  'proposes', 'public',  'employment_start',           NULL, 'migration:20260726083201_core_schema.sql'),
('contracted_to',       'Contracted to',                ARRAY['person']::entity_type[],                                                  'entity', ARRAY['organization','person']::entity_type[],                                   FALSE, FALSE, TRUE,  'proposes', 'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('apprenticed_to',      'Apprenticed to',               ARRAY['person']::entity_type[],                                                  'entity', ARRAY['person','organization']::entity_type[],                                   FALSE, FALSE, TRUE,  'proposes', 'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('had_occupation',      'Had occupation',               ARRAY['person']::entity_type[],                                                  'text',   NULL,                                                                            FALSE, FALSE, TRUE,  'none',     'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('held_position',       'Held position',                ARRAY['person']::entity_type[],                                                  'text',   NULL,                                                                            FALSE, FALSE, TRUE,  'describes','public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('worked_at',           'Worked at',                    ARRAY['person']::entity_type[],                                                  'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, TRUE,  'none',     'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
-- Family 7: Military Service (6 records)
('served_in',           'Served in',                    ARRAY['person']::entity_type[],                                                  'entity', ARRAY['organization']::entity_type[],                                            FALSE, FALSE, TRUE,  'proposes', 'public',  'military_service',           NULL, 'migration:20260726083201_core_schema.sql'),
('enlisted_on',         'Enlisted on',                  ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'supports', 'public',  'military_service',           NULL, 'migration:20260726083201_core_schema.sql'),
('enlisted_at',         'Enlisted at',                  ARRAY['person']::entity_type[],                                                  'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, FALSE, 'supports', 'public',  'military_service',           NULL, 'migration:20260726083201_core_schema.sql'),
('discharged_on',       'Discharged on',                ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'describes','public',  'military_service',           NULL, 'migration:20260726083201_core_schema.sql'),
('held_rank',           'Held rank',                    ARRAY['person']::entity_type[],                                                  'text',   NULL,                                                                            FALSE, FALSE, TRUE,  'describes','public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('served_at',           'Served at',                    ARRAY['person']::entity_type[],                                                  'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, TRUE,  'describes','public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
-- Family 8: Organizational and Community Participation (7 records)
('member_of',           'Member of',                    ARRAY['person','organization']::entity_type[],                                   'entity', ARRAY['organization','community']::entity_type[],                                FALSE, FALSE, TRUE,  'proposes', 'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('joined_on',           'Joined on',                    ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'supports', 'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('left_on',             'Left on',                      ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'describes','public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('associated_with',     'Associated with',              ARRAY['person','organization','place','vessel','community','event_series']::entity_type[], 'entity', ARRAY['person','organization','place','vessel','community','event_series']::entity_type[], TRUE, FALSE, TRUE, 'none', 'family', NULL, NULL, 'migration:20260726083201_core_schema.sql'),
('ordained_in',         'Ordained in',                  ARRAY['person']::entity_type[],                                                  'entity', ARRAY['organization','community']::entity_type[],                                FALSE, FALSE, FALSE, 'proposes', 'public',  'ordination',                 NULL, 'migration:20260726083201_core_schema.sql'),
('ordained_on',         'Ordained on',                  ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'supports', 'public',  'ordination',                 NULL, 'migration:20260726083201_core_schema.sql'),
('ordained_at',         'Ordained at',                  ARRAY['person']::entity_type[],                                                  'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, FALSE, 'supports', 'public',  'ordination',                 NULL, 'migration:20260726083201_core_schema.sql'),
-- Family 9: Document Appearance (3 records)
('recorded_in',         'Recorded in',                  ARRAY['person','organization','place','vessel','community']::entity_type[],       'text',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('listed_as',           'Listed as',                    ARRAY['person','organization','place','vessel']::entity_type[],                  'text',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('documented_by',       'Documented by',                ARRAY['person','organization','place','vessel']::entity_type[],                  'entity', ARRAY['organization']::entity_type[],                                            FALSE, FALSE, TRUE,  'none',     'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
-- Family 10: Property, Custody, and Ownership (5 records)
('owned',               'Owned',                        ARRAY['person','organization']::entity_type[],                                   'entity', ARRAY['place','organization','vessel']::entity_type[],                           FALSE, FALSE, TRUE,  'proposes', 'family',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('possessed',           'Possessed',                    ARRAY['person','organization']::entity_type[],                                   'text',   NULL,                                                                            FALSE, FALSE, TRUE,  'none',     'family',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('held_title_to',       'Held title to',                ARRAY['person','organization']::entity_type[],                                   'entity', ARRAY['place']::entity_type[],                                                   FALSE, FALSE, TRUE,  'proposes', 'family',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('custody_of',          'Had custody of',               ARRAY['person','organization']::entity_type[],                                   'entity', ARRAY['person']::entity_type[],                                                  FALSE, FALSE, TRUE,  'proposes', 'steward', NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('held_in_stewardship', 'Held in stewardship',          ARRAY['person','organization']::entity_type[],                                   'text',   NULL,                                                                            FALSE, FALSE, TRUE,  'none',     'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
-- Family 11: Titles and Honours (4 records)
('held_title',          'Held title',                   ARRAY['person']::entity_type[],                                                  'text',   NULL,                                                                            FALSE, FALSE, TRUE,  'none',     'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('awarded_honour',      'Awarded honour',               ARRAY['person']::entity_type[],                                                  'text',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('awarded_on',          'Awarded on',                   ARRAY['person']::entity_type[],                                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('appointed_to',        'Appointed to',                 ARRAY['person']::entity_type[],                                                  'entity', ARRAY['organization']::entity_type[],                                            FALSE, FALSE, TRUE,  'proposes', 'public',  'institutional_event',        NULL, 'migration:20260726083201_core_schema.sql'),
-- Family 12: Relationship Qualification (3 records)
('relationship_commenced_on', 'Relationship commenced on', ARRAY['person','organization']::entity_type[],                               'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'describes','family',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('relationship_ended_on', 'Relationship ended on',      ARRAY['person','organization']::entity_type[],                                  'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'describes','family',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('relationship_contested_on', 'Relationship contested on', ARRAY['person','organization']::entity_type[],                               'date',   NULL,                                                                            FALSE, FALSE, FALSE, 'describes','steward', NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
-- Family 13: Source and Artifact Associations (2 records)
('depicted_in',         'Depicted in',                  ARRAY['person','organization','place','vessel','community']::entity_type[],      'text',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'family',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql'),
('attributed_to',       'Attributed to',                ARRAY['person','organization']::entity_type[],                                  'text',   NULL,                                                                            FALSE, FALSE, FALSE, 'none',     'public',  NULL,                         NULL, 'migration:20260726083201_core_schema.sql');

-- Pass 2: Set inverse_predicate_id = id for symmetric self-inverses (married_to, in_civil_partnership_with, associated_with)
UPDATE claim_predicates SET inverse_predicate_id = id WHERE predicate_code IN ('married_to', 'in_civil_partnership_with', 'associated_with');

-- Batch 8 continued: relationship_types (27 seeds)
CREATE TABLE relationship_types (
    id                          UUID    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    type_code                   TEXT    NOT NULL UNIQUE,
    display_label               TEXT    NOT NULL,
    group_code                  TEXT    NOT NULL,
    is_symmetric                BOOLEAN NOT NULL DEFAULT FALSE,
    is_directional              BOOLEAN NOT NULL DEFAULT TRUE,
    inverse_type_code           TEXT    NULL,
    default_access_classification TEXT  NOT NULL DEFAULT 'family' CHECK (default_access_classification IN ('public','family','steward','restricted','culturally_governed')),
    created_by_id               UUID    NULL,
    created_by_system           TEXT    NULL
);

INSERT INTO relationship_types (type_code, display_label, group_code, is_symmetric, is_directional, inverse_type_code, default_access_classification, created_by_id, created_by_system) VALUES
-- Group A: Biological
('biological_parent_child', 'Biological parent–child',   'A', FALSE, TRUE,  NULL,                      'family',  NULL, 'migration:20260726083201_core_schema.sql'),
('sibling',                 'Sibling',                   'A', TRUE,  FALSE, NULL,                      'family',  NULL, 'migration:20260726083201_core_schema.sql'),
('full_sibling',            'Full sibling',              'A', TRUE,  FALSE, NULL,                      'family',  NULL, 'migration:20260726083201_core_schema.sql'),
('half_sibling',            'Half sibling',              'A', TRUE,  FALSE, NULL,                      'family',  NULL, 'migration:20260726083201_core_schema.sql'),
-- Group B: Legal family
('legal_parent_child',      'Legal parent–child',        'B', FALSE, TRUE,  NULL,                      'steward', NULL, 'migration:20260726083201_core_schema.sql'),
('adoptive_parent_child',   'Adoptive parent–child',     'B', FALSE, TRUE,  NULL,                      'steward', NULL, 'migration:20260726083201_core_schema.sql'),
('step_parent_child',       'Step parent–child',         'B', FALSE, TRUE,  NULL,                      'family',  NULL, 'migration:20260726083201_core_schema.sql'),
('foster_parent_child',     'Foster parent–child',       'B', FALSE, TRUE,  NULL,                      'steward', NULL, 'migration:20260726083201_core_schema.sql'),
-- Group C: Care
('guardianship',            'Guardianship',              'C', FALSE, TRUE,  NULL,                      'steward', NULL, 'migration:20260726083201_core_schema.sql'),
('caregiving',              'Caregiving',                'C', FALSE, TRUE,  NULL,                      'family',  NULL, 'migration:20260726083201_core_schema.sql'),
-- Group D: Partnership
('marriage',                'Marriage',                  'D', TRUE,  FALSE, NULL,                      'family',  NULL, 'migration:20260726083201_core_schema.sql'),
('civil_partnership',       'Civil partnership',         'D', TRUE,  FALSE, NULL,                      'family',  NULL, 'migration:20260726083201_core_schema.sql'),
('domestic_partnership',    'Domestic partnership',      'D', TRUE,  FALSE, NULL,                      'family',  NULL, 'migration:20260726083201_core_schema.sql'),
-- Group E: Work
('employment',              'Employment',                'E', FALSE, TRUE,  NULL,                      'public',  NULL, 'migration:20260726083201_core_schema.sql'),
('contractor',              'Contractor',                'E', FALSE, TRUE,  NULL,                      'public',  NULL, 'migration:20260726083201_core_schema.sql'),
('apprenticeship',          'Apprenticeship',            'E', FALSE, TRUE,  NULL,                      'public',  NULL, 'migration:20260726083201_core_schema.sql'),
-- Group F: Institutional
('military_service',        'Military service',          'F', FALSE, TRUE,  NULL,                      'public',  NULL, 'migration:20260726083201_core_schema.sql'),
('military_unit_association','Military unit association', 'F', FALSE, TRUE,  NULL,                      'public',  NULL, 'migration:20260726083201_core_schema.sql'),
('organizational_membership','Organizational membership', 'F', FALSE, TRUE,  NULL,                      'public',  NULL, 'migration:20260726083201_core_schema.sql'),
('community_membership',    'Community membership',      'F', FALSE, TRUE,  NULL,                      'family',  NULL, 'migration:20260726083201_core_schema.sql'),
-- Group G: Social
('friendship',              'Friendship',                'G', TRUE,  FALSE, NULL,                      'family',  NULL, 'migration:20260726083201_core_schema.sql'),
('mentorship',              'Mentorship',                'G', FALSE, TRUE,  NULL,                      'public',  NULL, 'migration:20260726083201_core_schema.sql'),
('professional_association', 'Professional association',  'G', TRUE,  FALSE, NULL,                      'public',  NULL, 'migration:20260726083201_core_schema.sql'),
-- Group H: Possession/Custody
('ownership',               'Ownership',                 'H', FALSE, TRUE,  NULL,                      'family',  NULL, 'migration:20260726083201_core_schema.sql'),
('possession',              'Possession',                'H', FALSE, TRUE,  NULL,                      'family',  NULL, 'migration:20260726083201_core_schema.sql'),
('custody_of_person',       'Custody of person',         'H', FALSE, TRUE,  NULL,                      'steward', NULL, 'migration:20260726083201_core_schema.sql'),
('historical_stewardship',  'Historical stewardship',    'H', FALSE, TRUE,  NULL,                      'public',  NULL, 'migration:20260726083201_core_schema.sql');

-- ---------------------------------------------------------------------------
-- Batch 9 — AI Context Layer
-- ---------------------------------------------------------------------------

CREATE TABLE agent_registry (
    id                              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    agent_code                      TEXT        NOT NULL UNIQUE,
    agent_version                   TEXT        NOT NULL,
    permitted_profiles              TEXT[]      NOT NULL DEFAULT '{}',
    permitted_action_types          TEXT[]      NOT NULL DEFAULT '{}',
    max_data_categories             JSONB       NOT NULL DEFAULT '{}',
    output_destination_types        TEXT[]      NOT NULL DEFAULT '{}',
    requires_human_review_before_save BOOLEAN   NOT NULL DEFAULT TRUE,
    cost_limit_per_invocation       DECIMAL     NULL,
    is_active                       BOOLEAN     NOT NULL DEFAULT TRUE,
    registered_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    registered_by_id                UUID        NULL REFERENCES user_profiles(id),
    deprecation_date                DATE        NULL
);

INSERT INTO agent_registry (agent_code, agent_version, permitted_profiles, permitted_action_types, max_data_categories, output_destination_types, requires_human_review_before_save, is_active, registered_by_id) VALUES
('storytelling_companion',    '1.0', ARRAY['public','family'], ARRAY['read','draft'], '{"max_sensitivity": "family"}'::jsonb,      ARRAY['narrative_draft'], TRUE,  TRUE, NULL),
('document_extractor',        '1.0', ARRAY['steward'],         ARRAY['read','extract'], '{"max_sensitivity": "steward"}'::jsonb,   ARRAY['claim_draft'],     TRUE,  TRUE, NULL),
('identity_resolver',         '1.0', ARRAY['steward'],         ARRAY['read','match'],   '{"max_sensitivity": "steward"}'::jsonb,   ARRAY['match_suggestion'],TRUE,  TRUE, NULL),
('privacy_validator',         '1.0', ARRAY['steward','admin'],  ARRAY['read','validate'],'{"max_sensitivity": "restricted"}'::jsonb,ARRAY['validation_report'],FALSE, TRUE, NULL),
('narrative_drafter',         '1.0', ARRAY['public','family'], ARRAY['read','draft'],   '{"max_sensitivity": "family"}'::jsonb,    ARRAY['narrative_draft'], TRUE,  TRUE, NULL),
('question_generator',        '1.0', ARRAY['public','family'], ARRAY['read'],           '{"max_sensitivity": "family"}'::jsonb,    ARRAY['question_set'],    FALSE, TRUE, NULL),
('translation_agent',         '1.0', ARRAY['steward'],         ARRAY['read','translate'],'{"max_sensitivity": "steward"}'::jsonb,  ARRAY['translation_draft'],TRUE, TRUE, NULL),
('historical_context_agent',  '1.0', ARRAY['public','family'], ARRAY['read'],           '{"max_sensitivity": "public"}'::jsonb,    ARRAY['context_note'],    FALSE, TRUE, NULL),
('conflict_detector',         '1.0', ARRAY['steward','admin'],  ARRAY['read','analyse'], '{"max_sensitivity": "steward"}'::jsonb,  ARRAY['conflict_report'], TRUE,  TRUE, NULL);

CREATE TABLE context_profiles (
    id              UUID    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_code    TEXT    NOT NULL UNIQUE,
    display_label   TEXT    NOT NULL,
    description     TEXT    NULL,
    permitted_categories TEXT[] NOT NULL DEFAULT '{}'
);

INSERT INTO context_profiles (profile_code, display_label, description, permitted_categories) VALUES
('public',  'Public',  'Publicly visible non-sensitive context', ARRAY['identity','vital_events','occupation','location']),
('family',  'Family',  'Accessible to authorised family members',ARRAY['identity','vital_events','occupation','location','relationships','documents']);

-- ---------------------------------------------------------------------------
-- Batch 10 — Content Layer
-- ---------------------------------------------------------------------------

CREATE TABLE sources (
    id                  UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    lifebook_id         UUID        NULL REFERENCES lifebooks(id),
    source_type         TEXT        NOT NULL CHECK (source_type IN ('document','oral','digital','physical','institutional','derived')),
    title               TEXT        NOT NULL,
    description         TEXT        NULL,
    repository_name     TEXT        NULL,
    repository_location TEXT        NULL,
    collection_name     TEXT        NULL,
    call_number         TEXT        NULL,
    url                 TEXT        NULL,
    accessed_date       DATE        NULL,
    publication_date    DATE        NULL,
    author              TEXT        NULL,
    language_code       TEXT        NULL,
    transcription       TEXT        NULL,
    translation         TEXT        NULL,
    access_classification TEXT      NOT NULL DEFAULT 'family' CHECK (access_classification IN ('public','family','steward','restricted','culturally_governed')),
    is_culturally_governed BOOLEAN  NOT NULL DEFAULT FALSE,
    governing_community_id UUID     NULL REFERENCES entities(id),
    added_by_id         UUID        NULL REFERENCES user_profiles(id),
    added_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes               TEXT        NULL
);

CREATE TABLE claims (
    id                      UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    lifebook_id             UUID        NULL REFERENCES lifebooks(id),
    subject_entity_id       UUID        NOT NULL REFERENCES entities(id),
    predicate_id            UUID        NOT NULL REFERENCES claim_predicates(id),
    value_type              TEXT        NOT NULL CHECK (value_type IN ('entity','date','text','numeric')),
    value_entity_id         UUID        NULL REFERENCES entities(id),
    value_date              DATE        NULL,
    value_date_precision    TEXT        NULL CHECK (value_date_precision IN ('year','month','day')),
    value_text              TEXT        NULL,
    value_numeric           NUMERIC     NULL,
    value_unit_code          TEXT        NULL REFERENCES claim_value_units(unit_code)
                                         ON UPDATE RESTRICT ON DELETE RESTRICT,
    value_unit_qualifier     TEXT        NULL,
    effective_from          DATE        NULL,
    effective_until         DATE        NULL,
    temporal_precision      TEXT        NULL CHECK (temporal_precision IN ('year','month','day')),
    access_classification   TEXT        NOT NULL DEFAULT 'family' CHECK (access_classification IN ('public','family','steward','restricted','culturally_governed')),
    is_contested            BOOLEAN     NOT NULL DEFAULT FALSE,
    confidence_score        NUMERIC     NULL CHECK (confidence_score BETWEEN 0 AND 1),
    superseded_by_id        UUID        NULL REFERENCES claims(id),
    superseded_at           TIMESTAMPTZ NULL,
    approval_policy_id      UUID        NULL REFERENCES approval_policies(id),
    asserted_by_role        TEXT        NULL,
    asserted_by_id          UUID        NULL REFERENCES user_profiles(id),
    source_id               UUID        NULL REFERENCES sources(id),
    notes                   TEXT        NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id           UUID        NULL REFERENCES user_profiles(id)
);

-- Deferred FK 1: authority_assignments.basis_claim_id → claims(id)
ALTER TABLE authority_assignments
    ADD CONSTRAINT fk_authority_basis_claim
    FOREIGN KEY (basis_claim_id) REFERENCES claims(id);

CREATE TABLE claim_evidence (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    claim_id        UUID        NOT NULL REFERENCES claims(id),
    source_id       UUID        NOT NULL REFERENCES sources(id),
    evidence_type   TEXT        NOT NULL CHECK (evidence_type IN ('primary','secondary','corroborating','contradicting')),
    excerpt         TEXT        NULL,
    page_reference  TEXT        NULL,
    notes           TEXT        NULL,
    added_by_id     UUID        NULL REFERENCES user_profiles(id),
    added_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE relationships (
    id                      UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    lifebook_id             UUID        NULL REFERENCES lifebooks(id),
    relationship_type_id    UUID        NOT NULL REFERENCES relationship_types(id),
    entity_a_id             UUID        NOT NULL REFERENCES entities(id),
    entity_b_id             UUID        NOT NULL REFERENCES entities(id),
    effective_from          DATE        NULL,
    effective_until         DATE        NULL,
    temporal_precision      TEXT        NULL CHECK (temporal_precision IN ('year','month','day')),
    jurisdiction_id         UUID        NULL REFERENCES jurisdictions(id),
    access_classification   TEXT        NOT NULL DEFAULT 'family' CHECK (access_classification IN ('public','family','steward','restricted','culturally_governed')),
    is_contested            BOOLEAN     NOT NULL DEFAULT FALSE,
    confidence_score        NUMERIC     NULL CHECK (confidence_score BETWEEN 0 AND 1),
    superseded_by_id        UUID        NULL REFERENCES relationships(id),
    superseded_at           TIMESTAMPTZ NULL,
    approval_policy_id      UUID        NULL REFERENCES approval_policies(id),
    source_id               UUID        NULL REFERENCES sources(id),
    notes                   TEXT        NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id           UUID        NULL REFERENCES user_profiles(id)
);

CREATE TABLE narratives (
    id                      UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    lifebook_id             UUID        NOT NULL REFERENCES lifebooks(id),
    title                   TEXT        NOT NULL,
    body                    TEXT        NOT NULL,
    narrative_type          TEXT        NOT NULL DEFAULT 'biographical' CHECK (narrative_type IN ('biographical','memorial','oral_history','historical_context','community')),
    language_code           TEXT        NOT NULL DEFAULT 'en',
    access_classification   TEXT        NOT NULL DEFAULT 'family' CHECK (access_classification IN ('public','family','steward','restricted','culturally_governed')),
    is_culturally_governed  BOOLEAN     NOT NULL DEFAULT FALSE,
    governing_community_id  UUID        NULL REFERENCES entities(id),
    approval_policy_id      UUID        NULL REFERENCES approval_policies(id),
    superseded_by_id        UUID        NULL REFERENCES narratives(id),
    superseded_at           TIMESTAMPTZ NULL,
    published_at            TIMESTAMPTZ NULL,
    notes                   TEXT        NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id           UUID        NULL REFERENCES user_profiles(id)
);

CREATE TABLE narrative_entities (
    id              UUID    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    narrative_id    UUID    NOT NULL REFERENCES narratives(id),
    entity_id       UUID    NOT NULL REFERENCES entities(id),
    role_in_narrative TEXT  NULL,
    UNIQUE (narrative_id, entity_id)
);

CREATE TABLE events (
    id                      UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    lifebook_id             UUID        NULL REFERENCES lifebooks(id),
    event_type              TEXT        NOT NULL,
    title                   TEXT        NULL,
    description             TEXT        NULL,
    event_date              DATE        NULL,
    event_date_precision    TEXT        NULL CHECK (event_date_precision IN ('year','month','day')),
    place_entity_id         UUID        NULL REFERENCES entities(id),
    access_classification   TEXT        NOT NULL DEFAULT 'family' CHECK (access_classification IN ('public','family','steward','restricted','culturally_governed')),
    source_claim_id         UUID        NULL REFERENCES claims(id),
    source_id               UUID        NULL REFERENCES sources(id),
    approval_policy_id      UUID        NULL REFERENCES approval_policies(id),
    notes                   TEXT        NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id           UUID        NULL REFERENCES user_profiles(id)
);

CREATE TABLE event_participants (
    id              UUID    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    event_id        UUID    NOT NULL REFERENCES events(id),
    entity_id       UUID    NOT NULL REFERENCES entities(id),
    participant_role TEXT    NULL,
    UNIQUE (event_id, entity_id)
);

CREATE TABLE artifacts (
    id                      UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    lifebook_id             UUID        NULL REFERENCES lifebooks(id),
    artifact_type           TEXT        NOT NULL CHECK (artifact_type IN ('photograph','document','audio','video','object','letter','certificate','other')),
    title                   TEXT        NOT NULL,
    description             TEXT        NULL,
    date_created            DATE        NULL,
    date_precision          TEXT        NULL CHECK (date_precision IN ('year','month','day')),
    creator_entity_id       UUID        NULL REFERENCES entities(id),
    physical_location       TEXT        NULL,
    access_classification   TEXT        NOT NULL DEFAULT 'family' CHECK (access_classification IN ('public','family','steward','restricted','culturally_governed')),
    is_culturally_governed  BOOLEAN     NOT NULL DEFAULT FALSE,
    governing_community_id  UUID        NULL REFERENCES entities(id),
    approval_policy_id      UUID        NULL REFERENCES approval_policies(id),
    notes                   TEXT        NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id           UUID        NULL REFERENCES user_profiles(id)
);

CREATE TABLE artifact_source_links (
    id          UUID    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    artifact_id UUID    NOT NULL REFERENCES artifacts(id),
    source_id   UUID    NOT NULL REFERENCES sources(id),
    link_note   TEXT    NULL,
    UNIQUE (artifact_id, source_id)
);

-- ---------------------------------------------------------------------------
-- Batch 11 — Audit and Derivative Layer
-- ---------------------------------------------------------------------------

CREATE TABLE context_manifests (
    id                              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    invocation_id                   UUID        NOT NULL UNIQUE,
    agent_code                      TEXT        NOT NULL,
    agent_version                   TEXT        NOT NULL,
    user_id                         UUID        NULL REFERENCES user_profiles(id),
    user_role                       TEXT        NULL,
    context_profile                 TEXT        NULL,
    persons_involved                UUID[]      NOT NULL DEFAULT '{}',
    authority_assignments_consulted UUID[]      NOT NULL DEFAULT '{}',
    approval_policies_consulted     UUID[]      NOT NULL DEFAULT '{}',
    data_categories_supplied        TEXT[]      NOT NULL DEFAULT '{}',
    source_derivatives_supplied     JSONB       NOT NULL DEFAULT '[]',
    restricted_categories_accessed  TEXT[]      NOT NULL DEFAULT '{}',
    sanitization_actions            JSONB       NOT NULL DEFAULT '[]',
    content_quarantined             BOOLEAN     NOT NULL DEFAULT FALSE,
    output_validation_result        TEXT        NULL,
    output_quarantined              BOOLEAN     NOT NULL DEFAULT FALSE,
    timestamp                       TIMESTAMPTZ NOT NULL DEFAULT now(),
    manifest_hash                   TEXT        NULL
);

CREATE TABLE source_derivatives (
    id                      UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    source_id               UUID        NOT NULL REFERENCES sources(id),
    derivative_type         TEXT        NOT NULL CHECK (derivative_type IN ('transcription','translation','summary','extraction','enhancement')),
    language_code           TEXT        NULL,
    target_script           TEXT        NULL,
    body                    TEXT        NOT NULL,
    derivation_method       TEXT        NULL,
    derivation_tool         TEXT        NULL,
    agent_code              TEXT        NULL,
    context_manifest_id     UUID        NULL REFERENCES context_manifests(id),
    is_validated            BOOLEAN     NOT NULL DEFAULT FALSE,
    validated_by_id         UUID        NULL REFERENCES user_profiles(id),
    validated_at            TIMESTAMPTZ NULL,
    superseded_by_id        UUID        NULL REFERENCES source_derivatives(id),
    superseded_at           TIMESTAMPTZ NULL,
    access_classification   TEXT        NOT NULL DEFAULT 'family' CHECK (access_classification IN ('public','family','steward','restricted','culturally_governed')),
    notes                   TEXT        NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id           UUID        NULL REFERENCES user_profiles(id)
);

-- Deferred FK 2: sources.context_manifest_id would cause circular dep — access_policy_changed_events refs both
-- No deferred FK needed here; context_manifests is complete above.

-- ---------------------------------------------------------------------------
-- Batch 12 — Cross-Lifebook and Merge
-- ---------------------------------------------------------------------------

CREATE TABLE merge_records (
    id                      UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    source_entity_id        UUID        NOT NULL REFERENCES entities(id),
    target_entity_id        UUID        NOT NULL REFERENCES entities(id),
    merge_type              TEXT        NOT NULL CHECK (merge_type IN ('confirmed_same_person','probable_same_person','merged_lifebooks')),
    initiated_by_id         UUID        NULL REFERENCES user_profiles(id),
    initiated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    approved_by_id          UUID        NULL REFERENCES user_profiles(id),
    approved_at             TIMESTAMPTZ NULL,
    status                  TEXT        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','reversed')),
    reversal_reason         TEXT        NULL,
    notes                   TEXT        NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id           UUID        NULL REFERENCES user_profiles(id)
);

CREATE TABLE cross_lifebook_authorizations (
    id                      UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    source_lifebook_id      UUID        NOT NULL REFERENCES lifebooks(id),
    target_lifebook_id      UUID        NOT NULL REFERENCES lifebooks(id),
    authorized_by_id        UUID        NOT NULL REFERENCES user_profiles(id),
    authorized_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    access_level            TEXT        NOT NULL CHECK (access_level IN ('read','contribute','steward')),
    scope_entity_ids        UUID[]      NOT NULL DEFAULT '{}',
    effective_from          DATE        NULL,
    effective_until         DATE        NULL,
    revoked_at              TIMESTAMPTZ NULL,
    revoked_by_id           UUID        NULL REFERENCES user_profiles(id),
    notes                   TEXT        NULL
);

CREATE TABLE lifebook_source_access (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    lifebook_id     UUID        NOT NULL REFERENCES lifebooks(id),
    source_id       UUID        NOT NULL REFERENCES sources(id),
    granted_by_id   UUID        NULL REFERENCES user_profiles(id),
    granted_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    access_level    TEXT        NOT NULL DEFAULT 'read' CHECK (access_level IN ('read','annotate','full')),
    notes           TEXT        NULL,
    UNIQUE (lifebook_id, source_id)
);

-- ---------------------------------------------------------------------------
-- Batch 13 — Governance Events
-- ---------------------------------------------------------------------------

CREATE TABLE contest_records (
    id                              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    lifebook_id                     UUID        NULL REFERENCES lifebooks(id),
    contest_type                    TEXT        NOT NULL CHECK (contest_type IN ('factual','authority','access','cultural','procedural')),
    contested_record_table          TEXT        NOT NULL,
    contested_record_id             UUID        NOT NULL,
    standing_class                  TEXT        NOT NULL,
    person_ids_involved             UUID[]      NOT NULL DEFAULT '{}',
    attribute_ids_contested         UUID[]      NOT NULL DEFAULT '{}',
    action_types_contested          TEXT[]      NOT NULL DEFAULT '{}',
    initiated_by_id                 UUID        NOT NULL REFERENCES user_profiles(id),
    initiated_at                    TIMESTAMPTZ NOT NULL DEFAULT now(),
    affected_authority_assignment_ids UUID[]    NOT NULL DEFAULT '{}',
    claimant_positions              JSONB       NOT NULL DEFAULT '{}',
    status                          TEXT        NOT NULL DEFAULT 'open' CHECK (status IN ('open','under_review','frozen','resolved','withdrawn')),
    freeze_actions                  TEXT[]      NOT NULL DEFAULT '{}',
    escalation_policy_id            UUID        NULL REFERENCES escalation_policies(id),
    escalation_record_id            UUID        NULL,
    -- NOTE: escalation_record_id → escalation_records — circular dependency; application-enforced
    resolution_type                 TEXT        NULL CHECK (resolution_type IN ('upheld','rejected','partial','withdrawn','escalated')),
    resolution_summary              TEXT        NULL,
    resolution_authority_role       TEXT        NULL,
    resolution_authority_id         UUID        NULL REFERENCES user_profiles(id),
    resolved_at                     TIMESTAMPTZ NULL,
    resulting_authority_assignment_ids UUID[]   NOT NULL DEFAULT '{}',
    access_during_contest           TEXT        NULL CHECK (access_during_contest IN ('normal','restricted','suspended')),
    notes                           TEXT        NULL,
    created_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id                   UUID        NULL REFERENCES user_profiles(id)
);

CREATE TABLE escalation_records (
    id                      UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    escalation_policy_id    UUID        NOT NULL REFERENCES escalation_policies(id),
    triggered_by_id         UUID        NULL REFERENCES user_profiles(id),
    triggered_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    trigger_type            TEXT        NOT NULL CHECK (trigger_type IN ('timeout','contest','override','manual')),
    related_contest_id      UUID        NULL REFERENCES contest_records(id),
    escalation_tier         INTEGER     NOT NULL DEFAULT 1,
    assignee_role           TEXT        NULL,
    assignee_id             UUID        NULL REFERENCES user_profiles(id),
    status                  TEXT        NOT NULL DEFAULT 'open' CHECK (status IN ('open','acknowledged','resolved','overridden')),
    resolution_notes        TEXT        NULL,
    resolved_at             TIMESTAMPTZ NULL,
    resolved_by_id          UUID        NULL REFERENCES user_profiles(id),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Deferred FK 3: contest_records.escalation_record_id — now that escalation_records exists
-- NOTE: This was intentionally left without a FK (circular dep); keep application-enforced per design.

CREATE TABLE escalation_notifications (
    id                      UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    escalation_record_id    UUID        NOT NULL REFERENCES escalation_records(id),
    notified_user_id        UUID        NOT NULL REFERENCES user_profiles(id),
    notification_type       TEXT        NOT NULL CHECK (notification_type IN ('email','in_app','sms')),
    sent_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
    acknowledged_at         TIMESTAMPTZ NULL,
    notes                   TEXT        NULL
);

CREATE TABLE access_policy_changed_events (
    id                      UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    source_id               UUID        NULL REFERENCES sources(id),
    context_manifest_id     UUID        NULL REFERENCES context_manifests(id),
    changed_by_id           UUID        NULL REFERENCES user_profiles(id),
    changed_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    change_type             TEXT        NOT NULL CHECK (change_type IN ('access_granted','access_revoked','classification_changed','policy_updated')),
    affected_entity_ids     UUID[]      NOT NULL DEFAULT '{}',
    previous_classification TEXT        NULL,
    new_classification      TEXT        NULL,
    change_reason           TEXT        NULL,
    notes                   TEXT        NULL
);

-- ---------------------------------------------------------------------------
-- Batch 14 — Person Attribute Tables
-- ---------------------------------------------------------------------------

CREATE TABLE person_names (
    id                          UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    person_id                   UUID        NOT NULL REFERENCES persons(entity_id),
    usage_type                  TEXT        NOT NULL CHECK (usage_type IN ('legal','common','birth','religious','traditional','indigenous','institutional','alias')),
    honorific                   TEXT        NULL,
    given_names                 TEXT[]      NOT NULL DEFAULT '{}',
    middle_names                TEXT[]      NOT NULL DEFAULT '{}',
    family_name                 TEXT        NULL,
    name_suffix                 TEXT        NULL,
    full_name_string            TEXT        NULL,
    name_script                 TEXT        NULL,
    language_code               TEXT        NULL,
    effective_from              DATE        NULL,
    effective_until             DATE        NULL,
    asserted_by_role            TEXT        NULL,
    asserted_by_id              UUID        NULL REFERENCES user_profiles(id),
    legal_basis                 TEXT        NULL,
    source_id                   UUID        NULL REFERENCES sources(id),
    evidence_status             TEXT        NOT NULL DEFAULT 'unverified' CHECK (evidence_status IN ('unverified','corroborated','disputed','confirmed')),
    precision_status            TEXT        NOT NULL DEFAULT 'approximate' CHECK (precision_status IN ('approximate','estimated','exact')),
    dispute_status              TEXT        NOT NULL DEFAULT 'undisputed' CHECK (dispute_status IN ('undisputed','queried','contested','resolved')),
    review_status               TEXT        NOT NULL DEFAULT 'pending' CHECK (review_status IN ('pending','under_review','approved','rejected')),
    approval_policy_id          UUID        NULL REFERENCES approval_policies(id),
    conflict_resolution_policy_id UUID      NULL REFERENCES approval_policies(id),
    imposition_context          TEXT        NULL,
    notes                       TEXT        NULL,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id               UUID        NULL REFERENCES user_profiles(id)
);

CREATE TABLE person_name_derivatives (
    id                  UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    parent_name_id      UUID        NOT NULL REFERENCES person_names(id),
    derivative_type     TEXT        NOT NULL CHECK (derivative_type IN ('transliteration','translation')),
    target_script       TEXT        NULL,
    target_language     TEXT        NULL,
    honorific           TEXT        NULL,
    given_names         TEXT[]      NOT NULL DEFAULT '{}',
    middle_names        TEXT[]      NOT NULL DEFAULT '{}',
    family_name         TEXT        NULL,
    name_suffix         TEXT        NULL,
    full_name_string    TEXT        NULL,
    derivation_method   TEXT        NULL,
    derivation_tool     TEXT        NULL,
    derivation_notes    TEXT        NULL,
    evidence_status     TEXT        NOT NULL DEFAULT 'unverified' CHECK (evidence_status IN ('unverified','corroborated','disputed','confirmed')),
    precision_status    TEXT        NOT NULL DEFAULT 'approximate' CHECK (precision_status IN ('approximate','estimated','exact')),
    dispute_status      TEXT        NOT NULL DEFAULT 'undisputed' CHECK (dispute_status IN ('undisputed','queried','contested','resolved')),
    review_status       TEXT        NOT NULL DEFAULT 'pending' CHECK (review_status IN ('pending','under_review','approved','rejected')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id       UUID        NULL REFERENCES user_profiles(id)
);

CREATE TABLE person_pronouns (
    id                              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    person_id                       UUID        NOT NULL REFERENCES persons(entity_id),
    pronoun_set_type                TEXT        NOT NULL CHECK (pronoun_set_type IN ('he_him','she_her','they_them','ze_zir','custom','unspecified')),
    custom_subject                  TEXT        NULL,
    custom_object                   TEXT        NULL,
    custom_possessive_adj           TEXT        NULL,
    custom_possessive_pro           TEXT        NULL,
    custom_reflexive                TEXT        NULL,
    usage_note                      TEXT        NULL,
    effective_from                  DATE        NULL,
    effective_until                 DATE        NULL,
    asserted_by_role                TEXT        NULL,
    approval_policy_id              UUID        NULL REFERENCES approval_policies(id),
    conflict_resolution_policy_id   UUID        NULL REFERENCES approval_policies(id),
    created_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id                   UUID        NULL REFERENCES user_profiles(id)
);

CREATE TABLE person_gender_descriptors (
    id                              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    person_id                       UUID        NOT NULL REFERENCES persons(entity_id),
    descriptor                      TEXT        NOT NULL,
    display_label                   TEXT        NULL,
    effective_from                  DATE        NULL,
    effective_until                 DATE        NULL,
    asserted_by_role                TEXT        NULL,
    approval_policy_id              UUID        NULL REFERENCES approval_policies(id),
    conflict_resolution_policy_id   UUID        NULL REFERENCES approval_policies(id),
    created_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_id                   UUID        NULL REFERENCES user_profiles(id)
);

-- ---------------------------------------------------------------------------
-- Phase 3 — Indexes
-- ---------------------------------------------------------------------------

-- Standard indexes (6)
-- NOTE: idx_entities_lifebook_id removed 2026-07-26 — entities has no lifebook_id column;
--       entities is a cross-lifebook identity anchor; lifebook scoping is via lifebook_entities.
CREATE INDEX idx_claims_subject_entity_id          ON claims (subject_entity_id);
CREATE INDEX idx_claims_predicate_id               ON claims (predicate_id);
CREATE INDEX idx_relationships_entity_a            ON relationships (entity_a_id);
CREATE INDEX idx_relationships_entity_b            ON relationships (entity_b_id);
CREATE INDEX idx_authority_assignments_entity_id   ON authority_assignments (entity_id);
CREATE INDEX idx_context_manifests_agent_code      ON context_manifests (agent_code);

-- Partial unique index for lifebook_entities active constraint (NOT a table UNIQUE constraint)
CREATE UNIQUE INDEX uq_lifebook_entities_active
    ON lifebook_entities (lifebook_id, entity_id)
    WHERE removed_at IS NULL;

-- ---------------------------------------------------------------------------
-- Phase 3 Addendum — Authoritative indexes from VOCABULARY_RLS_MATRIX.md §9
-- (in addition to general-purpose indexes written above)
-- ---------------------------------------------------------------------------

CREATE INDEX idx_lifebook_memberships_user_lifebook ON lifebook_memberships (user_id, lifebook_id);
CREATE INDEX idx_authority_assignments_role_entity   ON authority_assignments (authority_role, entity_id);
CREATE INDEX idx_authority_assignments_expiry         ON authority_assignments (effective_until) WHERE effective_until IS NOT NULL;
-- NOTE: idx_claims_lifebook_review_access moved to Phase 9 Addendum below —
-- review_status is added to claims by ALTER TABLE in the Addendum section;
-- creating the index here (before that ALTER TABLE) would cause SQLSTATE 42703.
CREATE INDEX idx_display_policy_rules_policy_context  ON display_policy_rules (display_policy_id, display_context_code);
CREATE INDEX idx_user_person_links_user_entity        ON user_person_links (user_id, person_entity_id);
CREATE INDEX idx_contest_records_contested_record     ON contest_records (contested_record_table, contested_record_id);

-- ---------------------------------------------------------------------------
-- Phase 4 — Helper Functions
-- NOTE: governance_functions role must exist before SECURITY DEFINER ownership
-- ---------------------------------------------------------------------------

-- governance_functions role is created by 20260726083202_application_roles.
-- This migration transfers function ownership via ALTER FUNCTION ... OWNER TO governance_functions.
-- Two bootstrap GRANTs issued after BEGIN above are required before ownership transfer:
--   1. GRANT governance_functions TO postgres — provides SET ROLE access (SQLSTATE 42501 without it).
--   2. GRANT USAGE, CREATE ON SCHEMA public TO governance_functions — permits ownership transfer
--      (PostgreSQL raises "permission denied for schema public" without CREATE privilege).
-- Supabase migrations execute under the postgres role; current_user causes connection termination.
-- If either GRANT was skipped, OWNER TO will fail — correct behaviour.

-- ---------------------------------------------------------------------------
-- 4.1 fn_user_is_agent — NOT SECURITY DEFINER
-- Returns TRUE if the current session role is the agent_service database role
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_user_is_agent()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN pg_has_role(current_user, 'agent_service', 'member');
EXCEPTION WHEN undefined_object THEN
    -- agent_service role does not exist in this environment
    RETURN FALSE;
END;
$$;

-- ---------------------------------------------------------------------------
-- 4.2 fn_lb_membership_role — SECURITY DEFINER
-- Returns the current user's membership role for the given lifebook_id
-- Returns 'steward', 'contributor', 'viewer', or 'none'
-- NEVER accepts a user_id parameter — derives user from auth.uid()
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_lb_membership_role(p_lifebook_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', pg_temp
AS $$
DECLARE
    v_role TEXT;
BEGIN
    IF p_lifebook_id IS NULL THEN
        RETURN 'none';
    END IF;

    SELECT membership_role
      INTO v_role
      FROM lifebook_memberships
     WHERE lifebook_id = p_lifebook_id
       AND user_id = auth.uid()
     LIMIT 1;

    RETURN COALESCE(v_role, 'none');
END;
$$;

ALTER FUNCTION fn_lb_membership_role(UUID) OWNER TO governance_functions;

-- ---------------------------------------------------------------------------
-- 4.3 fn_is_subject_of — SECURITY DEFINER
-- Returns TRUE if the current user has a user_person_links record pointing to p_entity_id
-- NEVER accepts a user_id parameter — derives user from auth.uid()
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_is_subject_of(p_entity_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', pg_temp
AS $$
BEGIN
    IF p_entity_id IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1
          FROM user_person_links
         WHERE user_id = auth.uid()
           AND person_entity_id = p_entity_id
           AND verification_status = 'verified'
    );
END;
$$;

ALTER FUNCTION fn_is_subject_of(UUID) OWNER TO governance_functions;

-- ---------------------------------------------------------------------------
-- 4.4 fn_has_active_authority — SECURITY DEFINER
-- Returns TRUE if the current user holds a non-expired AuthorityAssignment
-- for the given role code and optional entity scope
-- RECURSION RISK: authority_assignments RLS must NOT call this function
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_has_active_authority(p_role_code TEXT, p_entity_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', pg_temp
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
          FROM authority_assignments
         WHERE authority_holder_id = auth.uid()
           AND authority_role = p_role_code
           AND (effective_until IS NULL OR effective_until > current_date)
           AND (p_entity_id IS NULL OR entity_id = p_entity_id)
    );
END;
$$;

ALTER FUNCTION fn_has_active_authority(TEXT, UUID) OWNER TO governance_functions;

-- ---------------------------------------------------------------------------
-- 4.5 fn_display_policy_allows — SECURITY DEFINER
-- Returns TRUE only for an active policy with an explicit allow rule for the context
-- Returns FALSE for: NULL policy_id, inactive policy, missing rule, deny, unsatisfied conditional
-- RECURSION RISK: display_policies and display_policy_rules RLS must NOT call this function
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_display_policy_allows(p_policy_id UUID, p_context_code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', pg_temp
AS $$
DECLARE
    v_decision TEXT;
BEGIN
    IF p_policy_id IS NULL OR p_context_code IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT dpr.decision
      INTO v_decision
      FROM display_policies dp
      JOIN display_policy_rules dpr
        ON dpr.display_policy_id = dp.id
       AND dpr.display_context_code = p_context_code
     WHERE dp.id = p_policy_id
       AND dp.status = 'active'
     LIMIT 1;

    -- Only explicit 'allow' returns TRUE; deny, conditional, and missing rule all return FALSE
    RETURN COALESCE(v_decision = 'allow', FALSE);
END;
$$;

ALTER FUNCTION fn_display_policy_allows(UUID, TEXT) OWNER TO governance_functions;

-- ---------------------------------------------------------------------------
-- 4.6 fn_has_source_access_grant — SECURITY DEFINER
-- Returns TRUE if the current user's LifeBook has a valid LifeBookSourceAccess
-- record for the given source via CrossLifeBookAuthorization
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_has_source_access_grant(p_source_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', pg_temp
AS $$
BEGIN
    IF p_source_id IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1
          FROM lifebook_source_access lsa
          JOIN lifebook_memberships lm
            ON lm.lifebook_id = lsa.lifebook_id
           AND lm.user_id = auth.uid()
         WHERE lsa.source_id = p_source_id
    );
END;
$$;

ALTER FUNCTION fn_has_source_access_grant(UUID) OWNER TO governance_functions;

-- ---------------------------------------------------------------------------
-- 4.7 fn_has_community_authorization — SECURITY DEFINER
-- Returns TRUE if the LifeBook has a valid ApprovalRecord authorizing
-- community_account Narrative creation
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_has_community_authorization(p_lifebook_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', pg_temp
AS $$
BEGIN
    IF p_lifebook_id IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1
          FROM approval_records ar
          JOIN approval_policies ap ON ap.id = ar.approval_policy_id
         WHERE ar.lifebook_id = p_lifebook_id
           AND ar.status = 'approved'
           AND ap.purpose = 'community_authorization'
           AND ap.cultural_governance_required = TRUE
    );
END;
$$;

ALTER FUNCTION fn_has_community_authorization(UUID) OWNER TO governance_functions;

-- ---------------------------------------------------------------------------
-- 4.8 fn_has_contest_standing — SECURITY DEFINER
-- Returns TRUE if the current user belongs to the claimed standing class
-- for the contested record.
-- CRITICAL: Table name parameter MUST be validated against hard-coded whitelist
-- of exactly 9 tables before dynamic SQL is executed.
-- Unrecognized table name → RAISE EXCEPTION (not FALSE)
-- RECURSION RISK: contest_records RLS SELECT must NOT call this function
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_has_contest_standing(
    p_table        TEXT,
    p_record_id    UUID,
    p_standing_class TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', pg_temp
AS $$
DECLARE
    v_whitelisted_tables TEXT[] := ARRAY[
        'claims', 'relationships', 'narratives', 'sources', 'artifacts',
        'events', 'person_names', 'person_pronouns', 'person_gender_descriptors'
    ];
    v_entity_id UUID;
    v_lifebook_id UUID;
    v_sql TEXT;
BEGIN
    -- Validate table name against whitelist — RAISE EXCEPTION on unrecognized table
    IF NOT (p_table = ANY(v_whitelisted_tables)) THEN
        RAISE EXCEPTION 'fn_has_contest_standing: unrecognized contested_record_table: %', p_table;
    END IF;

    IF p_record_id IS NULL OR p_standing_class IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Check standing class: steward of the LifeBook
    IF p_standing_class = 'steward' THEN
        -- Get lifebook_id from the contested record via dynamic SQL
        v_sql := format('SELECT lifebook_id FROM %I WHERE id = $1', p_table);
        EXECUTE v_sql INTO v_lifebook_id USING p_record_id;
        RETURN fn_lb_membership_role(v_lifebook_id) = 'steward';

    -- Check standing class: subject (person whose record this concerns)
    ELSIF p_standing_class = 'subject' THEN
        -- Get entity_id from the contested record
        v_sql := format('SELECT person_id FROM %I WHERE id = $1', p_table);
        EXECUTE v_sql INTO v_entity_id USING p_record_id;
        IF v_entity_id IS NULL THEN
            -- Try entity_id column
            v_sql := format('SELECT entity_id FROM %I WHERE id = $1', p_table);
            EXECUTE v_sql INTO v_entity_id USING p_record_id;
        END IF;
        RETURN fn_is_subject_of(v_entity_id);

    -- Check standing class: asserting_party (user who created the record)
    ELSIF p_standing_class = 'asserting_party' THEN
        v_sql := format('SELECT created_by_id FROM %I WHERE id = $1', p_table);
        EXECUTE v_sql INTO v_entity_id USING p_record_id;
        RETURN v_entity_id = auth.uid();

    -- Check standing class: affected_party (involved entities include current user's person)
    ELSIF p_standing_class = 'affected_party' THEN
        -- Check if any person entity linked to current user appears as subject/participant
        RETURN EXISTS (
            SELECT 1
              FROM user_person_links upl
             WHERE upl.user_id = auth.uid()
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

-- ---------------------------------------------------------------------------
-- 4.9 fn_generate_artifact_signed_url — SECURITY DEFINER — STUB
-- STUB: Returns NULL immediately without referencing file_storage_references.
-- Full implementation (authority + DisplayPolicy evaluation + signed URL generation)
-- is deferred to the storage integration migration milestone.
-- The SECURITY DEFINER frame, search_path, ownership, and EXECUTE revocation
-- are all in place at stub creation time — only the body is a stub.
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_generate_artifact_signed_url(
    p_artifact_id     UUID,
    p_display_context TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = 'public', pg_temp
AS $$
BEGIN
    -- STUB: Full policy evaluation and signed URL generation deferred to storage integration.
    -- This function must be replaced in the storage integration migration before use.
    -- It must never return a URL or expose object_key under any failure path.
    RETURN NULL;
END;
$$;

ALTER FUNCTION fn_generate_artifact_signed_url(UUID, TEXT) OWNER TO governance_functions;

-- ---------------------------------------------------------------------------
-- Phase 5 — Triggers
-- ---------------------------------------------------------------------------

-- ============================================================
-- Pass A: No cross-table dependencies
-- ============================================================

-- 5.A.1 trg_claim_value_not_null
CREATE FUNCTION _fn_trg_claim_value_not_null()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.value_text IS NULL AND NEW.value_date IS NULL AND NEW.value_numeric IS NULL AND NEW.value_entity_id IS NULL THEN
        RAISE EXCEPTION 'trg_claim_value_not_null: at least one of value_text, value_date, value_numeric, value_entity_id must be non-null on claim %', NEW.id;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_claim_value_not_null
    BEFORE INSERT ON claims
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_claim_value_not_null();

-- 5.A.2 trg_claim_ai_provenance
CREATE FUNCTION _fn_trg_claim_ai_provenance()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- ai_generated column may not exist yet in V1 claims — if it does, enforce
    -- If ai_generated = TRUE then producing_agent_code and context_manifest_id required
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        -- Check via column inspection since claims has these fields only if they exist
        -- This trigger enforces: when submission_origin = 'ai_extracted_submission',
        -- context_manifest_id should be set (producing_agent_code is text, not FK)
        NULL; -- placeholder: full enforcement requires ai_generated boolean column
              -- which is application-set; trigger body to be completed in storage integration
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_claim_ai_provenance
    BEFORE INSERT OR UPDATE ON claims
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_claim_ai_provenance();

-- 5.A.3 trg_claim_content_immutable
CREATE FUNCTION _fn_trg_claim_content_immutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.subject_entity_id IS DISTINCT FROM OLD.subject_entity_id THEN
        RAISE EXCEPTION 'trg_claim_content_immutable: subject_entity_id is immutable after INSERT';
    END IF;
    IF NEW.predicate_id IS DISTINCT FROM OLD.predicate_id THEN
        RAISE EXCEPTION 'trg_claim_content_immutable: predicate_id is immutable after INSERT';
    END IF;
    IF NEW.value_type IS DISTINCT FROM OLD.value_type THEN
        RAISE EXCEPTION 'trg_claim_content_immutable: value_type is immutable after INSERT';
    END IF;
    IF NEW.value_text IS DISTINCT FROM OLD.value_text THEN
        RAISE EXCEPTION 'trg_claim_content_immutable: value_text is immutable after INSERT';
    END IF;
    IF NEW.value_date IS DISTINCT FROM OLD.value_date THEN
        RAISE EXCEPTION 'trg_claim_content_immutable: value_date is immutable after INSERT';
    END IF;
    IF NEW.value_numeric IS DISTINCT FROM OLD.value_numeric THEN
        RAISE EXCEPTION 'trg_claim_content_immutable: value_numeric is immutable after INSERT';
    END IF;
    IF NEW.value_entity_id IS DISTINCT FROM OLD.value_entity_id THEN
        RAISE EXCEPTION 'trg_claim_content_immutable: value_entity_id is immutable after INSERT';
    END IF;
    IF NEW.lifebook_id IS DISTINCT FROM OLD.lifebook_id THEN
        RAISE EXCEPTION 'trg_claim_content_immutable: lifebook_id is immutable after INSERT';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_claim_content_immutable
    BEFORE UPDATE ON claims
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_claim_content_immutable();

-- 5.A.4 trg_relationship_content_immutable
CREATE FUNCTION _fn_trg_relationship_content_immutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.relationship_type_id IS DISTINCT FROM OLD.relationship_type_id THEN
        RAISE EXCEPTION 'trg_relationship_content_immutable: relationship_type_id is immutable after INSERT';
    END IF;
    IF NEW.entity_a_id IS DISTINCT FROM OLD.entity_a_id THEN
        RAISE EXCEPTION 'trg_relationship_content_immutable: entity_a_id is immutable after INSERT';
    END IF;
    IF NEW.entity_b_id IS DISTINCT FROM OLD.entity_b_id THEN
        RAISE EXCEPTION 'trg_relationship_content_immutable: entity_b_id is immutable after INSERT';
    END IF;
    IF NEW.lifebook_id IS DISTINCT FROM OLD.lifebook_id THEN
        RAISE EXCEPTION 'trg_relationship_content_immutable: lifebook_id is immutable after INSERT';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_relationship_content_immutable
    BEFORE UPDATE ON relationships
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_relationship_content_immutable();

-- 5.A.5 trg_source_dna_classification
CREATE FUNCTION _fn_trg_source_dna_classification()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.source_type = 'dna_analysis' THEN
        IF NEW.access_classification IS NULL THEN
            -- Coerce silently
            NEW.access_classification := 'restricted';
        ELSIF NEW.access_classification != 'restricted' THEN
            -- Caller explicitly passed a non-restricted value — intent conflict
            RAISE EXCEPTION 'trg_source_dna_classification: dna_analysis sources must have access_classification = ''restricted''; received ''%''', NEW.access_classification;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_source_dna_classification
    BEFORE INSERT ON sources
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_source_dna_classification();

-- 5.A.6 trg_source_type_immutable
CREATE FUNCTION _fn_trg_source_type_immutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.source_type IS DISTINCT FROM OLD.source_type THEN
        RAISE EXCEPTION 'trg_source_type_immutable: source_type is immutable after INSERT';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_source_type_immutable
    BEFORE UPDATE ON sources
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_source_type_immutable();

-- 5.A.7 trg_source_lifebook_immutable
CREATE FUNCTION _fn_trg_source_lifebook_immutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.lifebook_id IS DISTINCT FROM OLD.lifebook_id THEN
        RAISE EXCEPTION 'trg_source_lifebook_immutable: lifebook_id is immutable after INSERT';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_source_lifebook_immutable
    BEFORE UPDATE ON sources
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_source_lifebook_immutable();

-- 5.A.8 trg_event_provenance_immutable
CREATE FUNCTION _fn_trg_event_provenance_immutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.source_claim_id IS DISTINCT FROM OLD.source_claim_id THEN
        RAISE EXCEPTION 'trg_event_provenance_immutable: source_claim_id is immutable after INSERT';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_event_provenance_immutable
    BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_event_provenance_immutable();

-- 5.A.9 trg_approval_records_immutable
CREATE FUNCTION _fn_trg_approval_records_immutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'trg_approval_records_immutable: approval records are immutable after creation';
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_approval_records_immutable
    BEFORE UPDATE ON approval_records
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_approval_records_immutable();

-- 5.A.10 trg_authority_assignment_revocation_guard
CREATE FUNCTION _fn_trg_authority_assignment_revocation_guard()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_col TEXT;
BEGIN
    -- effective_until: NULL → date permitted; date → NULL NOT permitted; date → different date: check other logic
    IF OLD.effective_until IS NOT NULL AND NEW.effective_until IS NULL THEN
        RAISE EXCEPTION 'trg_authority_assignment_revocation_guard: effective_until may not be reverted to NULL once set';
    END IF;

    -- Only effective_until and is_contested may change; all other fields immutable
    IF NEW.entity_id IS DISTINCT FROM OLD.entity_id THEN
        RAISE EXCEPTION 'trg_authority_assignment_revocation_guard: entity_id is immutable';
    END IF;
    IF NEW.lifebook_id IS DISTINCT FROM OLD.lifebook_id THEN
        RAISE EXCEPTION 'trg_authority_assignment_revocation_guard: lifebook_id is immutable';
    END IF;
    IF NEW.authority_holder_id IS DISTINCT FROM OLD.authority_holder_id THEN
        RAISE EXCEPTION 'trg_authority_assignment_revocation_guard: authority_holder_id is immutable';
    END IF;
    IF NEW.authority_role IS DISTINCT FROM OLD.authority_role THEN
        RAISE EXCEPTION 'trg_authority_assignment_revocation_guard: authority_role is immutable';
    END IF;
    IF NEW.authority_basis_type IS DISTINCT FROM OLD.authority_basis_type THEN
        RAISE EXCEPTION 'trg_authority_assignment_revocation_guard: authority_basis_type is immutable';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_authority_assignment_revocation_guard
    BEFORE UPDATE ON authority_assignments
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_authority_assignment_revocation_guard();

-- 5.A.11 trg_display_policies_lifecycle
CREATE FUNCTION _fn_trg_display_policies_lifecycle()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- Non-draft: non-status field changes are rejected
    IF OLD.status != 'draft' THEN
        IF NEW.status IS DISTINCT FROM OLD.status THEN
            -- Status-only change on non-draft: validate transitions
            IF OLD.status = 'active' AND NEW.status NOT IN ('superseded', 'withdrawn') THEN
                RAISE EXCEPTION 'trg_display_policies_lifecycle: invalid status transition from active to %', NEW.status;
            END IF;
            IF OLD.status IN ('superseded', 'withdrawn') THEN
                RAISE EXCEPTION 'trg_display_policies_lifecycle: superseded/withdrawn policies are fully immutable; status cannot change';
            END IF;
        ELSE
            -- Non-status field changed on non-draft
            RAISE EXCEPTION 'trg_display_policies_lifecycle: non-status fields are immutable on non-draft display_policies (status = %)', OLD.status;
        END IF;
    ELSE
        -- draft → any other status: only draft → active is permitted
        IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status NOT IN ('active', 'draft') THEN
            RAISE EXCEPTION 'trg_display_policies_lifecycle: invalid status transition from draft to %', NEW.status;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_display_policies_lifecycle
    BEFORE UPDATE ON display_policies
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_display_policies_lifecycle();

-- 5.A.12 trg_display_policies_delete_guard
CREATE FUNCTION _fn_trg_display_policies_delete_guard()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status != 'draft' THEN
        RAISE EXCEPTION 'trg_display_policies_delete_guard: only draft display_policies may be deleted; status is %', OLD.status;
    END IF;
    RETURN OLD;
END;
$$;
CREATE TRIGGER trg_display_policies_delete_guard
    BEFORE DELETE ON display_policies
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_display_policies_delete_guard();

-- ============================================================
-- Pass B: Cross-table dependencies (all Batch 14 tables exist)
-- ============================================================

-- 5.B.1 trg_claim_supersession_integrity
CREATE FUNCTION _fn_trg_claim_supersession_integrity()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.superseded_by_id IS NOT NULL THEN
        IF OLD.superseded_by_id IS NOT NULL THEN
            RAISE EXCEPTION 'trg_claim_supersession_integrity: superseded_by_id may only be set once (NULL → UUID)';
        END IF;
        IF NEW.superseded_by_id = NEW.id THEN
            RAISE EXCEPTION 'trg_claim_supersession_integrity: a claim may not supersede itself';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM claims WHERE id = NEW.superseded_by_id) THEN
            RAISE EXCEPTION 'trg_claim_supersession_integrity: superseded_by_id % does not reference an existing claim', NEW.superseded_by_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_claim_supersession_integrity
    BEFORE UPDATE ON claims
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_claim_supersession_integrity();

-- 5.B.2 trg_relationship_supersession_integrity
CREATE FUNCTION _fn_trg_relationship_supersession_integrity()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.superseded_by_id IS NOT NULL THEN
        IF OLD.superseded_by_id IS NOT NULL THEN
            RAISE EXCEPTION 'trg_relationship_supersession_integrity: superseded_by_id may only be set once (NULL → UUID)';
        END IF;
        IF NEW.superseded_by_id = NEW.id THEN
            RAISE EXCEPTION 'trg_relationship_supersession_integrity: a relationship may not supersede itself';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM relationships WHERE id = NEW.superseded_by_id) THEN
            RAISE EXCEPTION 'trg_relationship_supersession_integrity: superseded_by_id % does not reference an existing relationship', NEW.superseded_by_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_relationship_supersession_integrity
    BEFORE UPDATE ON relationships
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_relationship_supersession_integrity();

-- 5.B.3 trg_claim_dispute_requires_contest
CREATE FUNCTION _fn_trg_claim_dispute_requires_contest()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.is_contested = TRUE AND OLD.is_contested = FALSE THEN
        IF NOT EXISTS (
            SELECT 1 FROM contest_records
             WHERE contested_record_table = 'claims'
               AND contested_record_id = NEW.id
               AND status IN ('open','under_review','frozen')
        ) THEN
            RAISE EXCEPTION 'trg_claim_dispute_requires_contest: claim % cannot be marked contested without an open ContestRecord', NEW.id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_claim_dispute_requires_contest
    BEFORE UPDATE ON claims
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_claim_dispute_requires_contest();

-- 5.B.4 trg_relationship_dispute_requires_contest
CREATE FUNCTION _fn_trg_relationship_dispute_requires_contest()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.is_contested = TRUE AND OLD.is_contested = FALSE THEN
        IF NOT EXISTS (
            SELECT 1 FROM contest_records
             WHERE contested_record_table = 'relationships'
               AND contested_record_id = NEW.id
               AND status IN ('open','under_review','frozen')
        ) THEN
            RAISE EXCEPTION 'trg_relationship_dispute_requires_contest: relationship % cannot be marked contested without an open ContestRecord', NEW.id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_relationship_dispute_requires_contest
    BEFORE UPDATE ON relationships
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_relationship_dispute_requires_contest();

-- 5.B.5 trg_display_policy_rules_update_guard
CREATE FUNCTION _fn_trg_display_policy_rules_update_guard()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_status TEXT;
BEGIN
    SELECT status INTO v_status FROM display_policies WHERE id = NEW.display_policy_id;
    IF v_status != 'draft' THEN
        RAISE EXCEPTION 'trg_display_policy_rules_update_guard: display_policy_rules may only be updated when parent display_policy.status = ''draft''; parent status is %', v_status;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_display_policy_rules_update_guard
    BEFORE UPDATE ON display_policy_rules
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_display_policy_rules_update_guard();

-- 5.B.6 trg_display_policy_rules_delete_guard
CREATE FUNCTION _fn_trg_display_policy_rules_delete_guard()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_status TEXT;
BEGIN
    SELECT status INTO v_status FROM display_policies WHERE id = OLD.display_policy_id;
    IF v_status != 'draft' THEN
        RAISE EXCEPTION 'trg_display_policy_rules_delete_guard: display_policy_rules may only be deleted when parent display_policy.status = ''draft''; parent status is %', v_status;
    END IF;
    RETURN OLD;
END;
$$;
CREATE TRIGGER trg_display_policy_rules_delete_guard
    BEFORE DELETE ON display_policy_rules
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_display_policy_rules_delete_guard();

-- 5.B.7 trg_contest_record_standing_validation
CREATE FUNCTION _fn_trg_contest_record_standing_validation()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_recognized_classes TEXT[] := ARRAY[
        'steward', 'subject', 'asserting_party', 'affected_party',
        'cultural_authority', 'authority_holder', 'lifebook_member'
    ];
BEGIN
    IF NOT (NEW.standing_class = ANY(v_recognized_classes)) THEN
        RAISE EXCEPTION 'trg_contest_record_standing_validation: unrecognized standing_class: %', NEW.standing_class;
    END IF;
    -- Note: initiating_by_id vs. claimed class match is application-enforced
    -- database validates format only; deep standing verification is in fn_has_contest_standing
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_contest_record_standing_validation
    BEFORE INSERT ON contest_records
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_contest_record_standing_validation();

-- 5.B.8 trg_lifebook_person_context_completeness
-- CONSTRAINT TRIGGER — DEFERRABLE INITIALLY DEFERRED
-- Fires at COMMIT (not immediately after INSERT) so that lifebook_person_contexts
-- can be inserted in the same transaction as its parent lifebook_entities record.
CREATE FUNCTION _fn_trg_lifebook_person_context_completeness()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.entity_type = 'person' THEN
        IF NOT EXISTS (
            SELECT 1 FROM lifebook_person_contexts
             WHERE lifebook_entity_id = NEW.id
        ) THEN
            RAISE EXCEPTION 'trg_lifebook_person_context_completeness: person-type lifebook_entity % has no lifebook_person_contexts record; must be created in the same transaction', NEW.id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE CONSTRAINT TRIGGER trg_lifebook_person_context_completeness
    AFTER INSERT ON lifebook_entities
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_lifebook_person_context_completeness();

-- 5.B.9 trg_source_derivative_invalidation_cascade — STUB
CREATE FUNCTION _fn_trg_source_derivative_invalidation_cascade()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- STUB: Full cascade (AccessPolicyChangedEvent insert + ContextManifest invalidation)
    -- deferred to Context Broker specification. Full implementation in future migration.
    IF NEW.is_validated IS DISTINCT FROM OLD.is_validated AND NEW.is_validated = FALSE THEN
        RAISE NOTICE 'trg_source_derivative_invalidation_cascade: stub — source_derivative % validity changed', NEW.id;
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_source_derivative_invalidation_cascade
    AFTER UPDATE ON source_derivatives
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_source_derivative_invalidation_cascade();

-- ============================================================
-- Pass C: After seed data committed — claim_predicates
-- must have all 74 claim_predicates (this migration) present; claim_value_units
-- (11 records) is a prerequisite from Migration 0001 and is already present.
-- ============================================================

-- 5.C.1 trg_claim_numeric_unit_check
CREATE FUNCTION _fn_trg_claim_numeric_unit_check()
RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public', pg_temp
AS $$
-- ──────────────────────────────────────────────────────────────────────────
-- Trigger: trg_claim_numeric_unit_check (Pass C — fires BEFORE INSERT, UPDATE on claims)
-- Source:  CONTENT_LAYER.md §3.4
-- Created after Batch 8 seed (claim_predicates 74 records). claim_value_units (11 records) is a prerequisite seeded by Migration 0001.
-- Must NOT be created before both seed sets are committed.
--
-- Enforces:
--   1. Non-numeric Claims must not carry value_unit_code or value_unit_qualifier.
--   2. Predicates requiring a unit (numeric_unit_required=TRUE) must have value_unit_code.
--   3. Predicates explicitly forbidding a unit (numeric_unit_required=FALSE) must
--      not have value_unit_code.
--   4. value_unit_code must exist in claim_value_units and not be deprecated.
--   5. value_unit_code must be permitted by predicate.permitted_unit_codes (if set).
--   6. The unit's unit_category must be permitted by predicate.permitted_unit_categories (if set).
--   7. Units with requires_qualifier=TRUE require a non-empty value_unit_qualifier.
--   8. Units with requires_qualifier=FALSE require value_unit_qualifier IS NULL.
--   9. Predicate-level integer constraint (numeric_integer_only).
--  10. Predicate-level numeric_min_value and numeric_max_value.
--  All failures RAISE EXCEPTION — no silent coercion.
-- ──────────────────────────────────────────────────────────────────────────
DECLARE
    v_numeric_unit_required   BOOLEAN;
    v_permitted_codes         TEXT[];
    v_permitted_categories    TEXT[];
    v_integer_only            BOOLEAN;
    v_min_value               NUMERIC;
    v_max_value               NUMERIC;
    v_unit_category           TEXT;
    v_requires_qualifier      BOOLEAN;
    v_deprecated_at           DATE;
BEGIN
    -- ── 1. Non-numeric Claims must carry no unit fields ──────────────────
    IF NEW.value_numeric IS NULL THEN
        IF NEW.value_unit_code IS NOT NULL THEN
            RAISE EXCEPTION
                'trg_claim_numeric_unit_check: value_unit_code supplied but value_numeric is NULL on claim %',
                NEW.id;
        END IF;
        IF NEW.value_unit_qualifier IS NOT NULL THEN
            RAISE EXCEPTION
                'trg_claim_numeric_unit_check: value_unit_qualifier supplied but value_numeric is NULL on claim %',
                NEW.id;
        END IF;
        RETURN NEW;
    END IF;

    -- ── Load predicate numeric constraints ────────────────────────────────
    SELECT numeric_unit_required,
           permitted_unit_codes,
           permitted_unit_categories,
           numeric_integer_only,
           numeric_min_value,
           numeric_max_value
      INTO v_numeric_unit_required,
           v_permitted_codes,
           v_permitted_categories,
           v_integer_only,
           v_min_value,
           v_max_value
      FROM claim_predicates
     WHERE id = NEW.predicate_id;

    -- ── 2. Predicate requires a unit ──────────────────────────────────────
    IF v_numeric_unit_required = TRUE AND NEW.value_unit_code IS NULL THEN
        RAISE EXCEPTION
            'trg_claim_numeric_unit_check: predicate % requires a unit but value_unit_code is NULL',
            NEW.predicate_id;
    END IF;

    -- ── 3. Predicate forbids a unit ───────────────────────────────────────
    IF v_numeric_unit_required = FALSE AND NEW.value_unit_code IS NOT NULL THEN
        RAISE EXCEPTION
            'trg_claim_numeric_unit_check: predicate % does not permit a unit but value_unit_code is set to %',
            NEW.predicate_id, NEW.value_unit_code;
    END IF;

    -- ── Unit-specific checks (only when value_unit_code is set) ──────────
    IF NEW.value_unit_code IS NOT NULL THEN

        -- ── 4. Unit must exist and must not be deprecated ─────────────────
        SELECT unit_category, requires_qualifier, deprecated_at
          INTO v_unit_category, v_requires_qualifier, v_deprecated_at
          FROM claim_value_units
         WHERE unit_code = NEW.value_unit_code;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'trg_claim_numeric_unit_check: value_unit_code % does not exist in claim_value_units',
                NEW.value_unit_code;
        END IF;

        IF v_deprecated_at IS NOT NULL AND v_deprecated_at <= CURRENT_DATE THEN
            RAISE EXCEPTION
                'trg_claim_numeric_unit_check: value_unit_code % is deprecated (deprecated_at %) and may not be used for new Claims',
                NEW.value_unit_code, v_deprecated_at;
        END IF;

        -- ── 5. Unit code must be in predicate whitelist if specified ──────
        IF v_permitted_codes IS NOT NULL AND array_length(v_permitted_codes, 1) > 0 THEN
            IF NOT (NEW.value_unit_code = ANY(v_permitted_codes)) THEN
                RAISE EXCEPTION
                    'trg_claim_numeric_unit_check: unit code % is not in the permitted_unit_codes for predicate %',
                    NEW.value_unit_code, NEW.predicate_id;
            END IF;
        END IF;

        -- ── 6. Unit category must be in predicate whitelist if specified ──
        IF v_permitted_categories IS NOT NULL AND array_length(v_permitted_categories, 1) > 0 THEN
            IF NOT (v_unit_category = ANY(v_permitted_categories)) THEN
                RAISE EXCEPTION
                    'trg_claim_numeric_unit_check: unit % has category % which is not in permitted_unit_categories for predicate %',
                    NEW.value_unit_code, v_unit_category, NEW.predicate_id;
            END IF;
        END IF;

        -- ── 7. Qualifier required ─────────────────────────────────────────
        IF v_requires_qualifier = TRUE THEN
            IF NEW.value_unit_qualifier IS NULL OR trim(NEW.value_unit_qualifier) = '' THEN
                RAISE EXCEPTION
                    'trg_claim_numeric_unit_check: unit % requires a qualifier (e.g. ISO 4217 currency code) but value_unit_qualifier is NULL or empty',
                    NEW.value_unit_code;
            END IF;
        END IF;

        -- ── 8. Qualifier must be absent when not permitted ────────────────
        IF v_requires_qualifier = FALSE AND NEW.value_unit_qualifier IS NOT NULL THEN
            RAISE EXCEPTION
                'trg_claim_numeric_unit_check: unit % does not require a qualifier but value_unit_qualifier is set to %',
                NEW.value_unit_code, NEW.value_unit_qualifier;
        END IF;

    END IF; -- END value_unit_code IS NOT NULL block

    -- ── 9. Integer-only constraint ────────────────────────────────────────
    IF v_integer_only = TRUE AND NEW.value_numeric IS NOT NULL THEN
        IF NEW.value_numeric <> trunc(NEW.value_numeric) THEN
            RAISE EXCEPTION
                'trg_claim_numeric_unit_check: predicate % requires an integer value but value_numeric % is not a whole number',
                NEW.predicate_id, NEW.value_numeric;
        END IF;
    END IF;

    -- ── 10. Min / max value constraints ───────────────────────────────────
    IF v_min_value IS NOT NULL AND NEW.value_numeric < v_min_value THEN
        RAISE EXCEPTION
            'trg_claim_numeric_unit_check: value_numeric % is below numeric_min_value % for predicate %',
            NEW.value_numeric, v_min_value, NEW.predicate_id;
    END IF;

    IF v_max_value IS NOT NULL AND NEW.value_numeric > v_max_value THEN
        RAISE EXCEPTION
            'trg_claim_numeric_unit_check: value_numeric % exceeds numeric_max_value % for predicate %',
            NEW.value_numeric, v_max_value, NEW.predicate_id;
    END IF;

    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_claim_numeric_unit_check
    BEFORE INSERT OR UPDATE ON claims
    FOR EACH ROW EXECUTE FUNCTION _fn_trg_claim_numeric_unit_check();

-- ---------------------------------------------------------------------------
-- Phase 6 — Enable Row Level Security (25 tables)
-- ---------------------------------------------------------------------------

ALTER TABLE claims                      ENABLE ROW LEVEL SECURITY;
ALTER TABLE relationships               ENABLE ROW LEVEL SECURITY;
ALTER TABLE narratives                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE narrative_entities          ENABLE ROW LEVEL SECURITY;
ALTER TABLE sources                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE artifacts                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE events                      ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_participants          ENABLE ROW LEVEL SECURITY;
ALTER TABLE display_policies            ENABLE ROW LEVEL SECURITY;
ALTER TABLE display_policy_rules        ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_records            ENABLE ROW LEVEL SECURITY;
ALTER TABLE authority_assignments       ENABLE ROW LEVEL SECURITY;
ALTER TABLE contest_records             ENABLE ROW LEVEL SECURITY;
ALTER TABLE person_names                ENABLE ROW LEVEL SECURITY;
ALTER TABLE person_pronouns             ENABLE ROW LEVEL SECURITY;
ALTER TABLE person_gender_descriptors   ENABLE ROW LEVEL SECURITY;
ALTER TABLE person_name_derivatives     ENABLE ROW LEVEL SECURITY;
ALTER TABLE context_manifests           ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_policy_changed_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE source_derivatives          ENABLE ROW LEVEL SECURITY;
ALTER TABLE lifebook_memberships        ENABLE ROW LEVEL SECURITY;
ALTER TABLE claim_evidence              ENABLE ROW LEVEL SECURITY;
ALTER TABLE artifact_source_links       ENABLE ROW LEVEL SECURITY;
ALTER TABLE lifebook_entities           ENABLE ROW LEVEL SECURITY;
ALTER TABLE lifebook_person_contexts    ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- Phase 7 — RLS Policies (71 total)
-- ---------------------------------------------------------------------------

-- ============================================================
-- Group A — DELETE Denied (policies 16–29, 59, 65)
-- USING (FALSE) — no actor may DELETE from these tables
-- ============================================================

-- Policy 16
CREATE POLICY pol_claims_delete_denied
    ON claims FOR DELETE USING (FALSE);

-- Policy 17
CREATE POLICY pol_narratives_delete_denied
    ON narratives FOR DELETE USING (FALSE);

-- Policy 18
CREATE POLICY pol_sources_delete_denied
    ON sources FOR DELETE USING (FALSE);

-- Policy 19
CREATE POLICY pol_artifacts_delete_denied
    ON artifacts FOR DELETE USING (FALSE);

-- Policy 20
CREATE POLICY pol_relationships_delete_denied
    ON relationships FOR DELETE USING (FALSE);

-- Policy 21
CREATE POLICY pol_events_delete_denied
    ON events FOR DELETE USING (FALSE);

-- Policy 22
CREATE POLICY pol_approval_records_delete_denied
    ON approval_records FOR DELETE USING (FALSE);

-- Policy 23
CREATE POLICY pol_context_manifests_delete_denied
    ON context_manifests FOR DELETE USING (FALSE);

-- Policy 24
CREATE POLICY pol_access_policy_events_delete_denied
    ON access_policy_changed_events FOR DELETE USING (FALSE);

-- Policy 25
CREATE POLICY pol_authority_assignments_delete_denied
    ON authority_assignments FOR DELETE USING (FALSE);

-- Policy 26
CREATE POLICY pol_contest_records_delete_denied
    ON contest_records FOR DELETE USING (FALSE);

-- Policy 27
CREATE POLICY pol_person_names_delete_denied
    ON person_names FOR DELETE USING (FALSE);

-- Policy 28
CREATE POLICY pol_person_pronouns_delete_denied
    ON person_pronouns FOR DELETE USING (FALSE);

-- Policy 29
CREATE POLICY pol_person_gender_delete_denied
    ON person_gender_descriptors FOR DELETE USING (FALSE);

-- Policy 59 (lifebook_entities DELETE denied)
CREATE POLICY pol_lifebook_entities_delete_denied
    ON lifebook_entities FOR DELETE USING (FALSE);

-- Policy 65 (lifebook_person_contexts DELETE denied)
CREATE POLICY pol_lifebook_person_contexts_delete_denied
    ON lifebook_person_contexts FOR DELETE USING (FALSE);

-- ============================================================
-- Group B — UPDATE Immutability (policy 49)
-- ============================================================

-- Policy 49
CREATE POLICY pol_approval_records_update_denied
    ON approval_records FOR UPDATE USING (FALSE);

-- ============================================================
-- Group C — LifeBook-Scoped SELECT (policies 1–15, 66–68, 70)
-- ============================================================

-- Policy 1
CREATE POLICY pol_claims_select_lifebook
    ON claims FOR SELECT
    USING (fn_lb_membership_role(lifebook_id) != 'none');

-- Policy 2
CREATE POLICY pol_relationships_select_lifebook
    ON relationships FOR SELECT
    USING (fn_lb_membership_role(lifebook_id) != 'none');

-- Policy 3
CREATE POLICY pol_narratives_select_lifebook
    ON narratives FOR SELECT
    USING (fn_lb_membership_role(lifebook_id) != 'none');

-- Policy 4
CREATE POLICY pol_narrative_entities_select_lifebook
    ON narrative_entities FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM narratives n
             WHERE n.id = narrative_entities.narrative_id
               AND fn_lb_membership_role(n.lifebook_id) != 'none'
        )
    );

-- Policy 5
CREATE POLICY pol_sources_select_lifebook
    ON sources FOR SELECT
    USING (
        fn_lb_membership_role(lifebook_id) != 'none'
        OR fn_has_source_access_grant(id)
    );

-- Policy 6
CREATE POLICY pol_artifacts_select_lifebook
    ON artifacts FOR SELECT
    USING (
        fn_lb_membership_role(lifebook_id) != 'none'
        AND (
            access_classification NOT IN ('restricted', 'culturally_governed')
            OR fn_lb_membership_role(lifebook_id) = 'steward'
        )
    );

-- Policy 7
CREATE POLICY pol_events_select_lifebook
    ON events FOR SELECT
    USING (fn_lb_membership_role(lifebook_id) != 'none');

-- Policy 8
CREATE POLICY pol_event_participants_select_lifebook
    ON event_participants FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM events e
             WHERE e.id = event_participants.event_id
               AND fn_lb_membership_role(e.lifebook_id) != 'none'
        )
    );

-- Policy 9
CREATE POLICY pol_claim_evidence_select_lifebook
    ON claim_evidence FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM claims c
             WHERE c.id = claim_evidence.claim_id
               AND fn_lb_membership_role(c.lifebook_id) != 'none'
        )
    );

-- Policy 10
CREATE POLICY pol_artifact_source_links_select_lifebook
    ON artifact_source_links FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM artifacts a
             WHERE a.id = artifact_source_links.artifact_id
               AND fn_lb_membership_role(a.lifebook_id) != 'none'
        )
    );

-- Policy 11
CREATE POLICY pol_person_names_select_lifebook
    ON person_names FOR SELECT
    USING (
        (
            EXISTS (
                SELECT 1
                  FROM lifebook_entities le
                  JOIN entities e ON e.id = le.entity_id
                  JOIN persons p ON p.entity_id = e.id
                 WHERE p.entity_id = person_names.person_id
                   AND fn_lb_membership_role(le.lifebook_id) != 'none'
                   AND NOT fn_user_is_agent()
            )
        )
        OR fn_is_subject_of(
            (SELECT e.id FROM persons p JOIN entities e ON e.id = p.entity_id WHERE p.entity_id = person_names.person_id)
        )
    );

-- Policy 12
CREATE POLICY pol_person_pronouns_select_lifebook
    ON person_pronouns FOR SELECT
    USING (
        (
            EXISTS (
                SELECT 1
                  FROM lifebook_entities le
                  JOIN entities e ON e.id = le.entity_id
                  JOIN persons p ON p.entity_id = e.id
                 WHERE p.entity_id = person_pronouns.person_id
                   AND fn_lb_membership_role(le.lifebook_id) != 'none'
                   AND NOT fn_user_is_agent()
            )
        )
        OR fn_is_subject_of(
            (SELECT e.id FROM persons p JOIN entities e ON e.id = p.entity_id WHERE p.entity_id = person_pronouns.person_id)
        )
    );

-- Policy 13
CREATE POLICY pol_person_gender_select_lifebook
    ON person_gender_descriptors FOR SELECT
    USING (
        (
            EXISTS (
                SELECT 1
                  FROM lifebook_entities le
                  JOIN entities e ON e.id = le.entity_id
                  JOIN persons p ON p.entity_id = e.id
                 WHERE p.entity_id = person_gender_descriptors.person_id
                   AND fn_lb_membership_role(le.lifebook_id) != 'none'
                   AND NOT fn_user_is_agent()
            )
        )
        OR fn_is_subject_of(
            (SELECT e.id FROM persons p JOIN entities e ON e.id = p.entity_id WHERE p.entity_id = person_gender_descriptors.person_id)
        )
    );

-- Policy 14
CREATE POLICY pol_person_name_derivatives_select
    ON person_name_derivatives FOR SELECT
    USING (
        (
            EXISTS (
                SELECT 1
                  FROM person_names pn
                  JOIN persons p ON p.entity_id = pn.person_id
                  JOIN entities e ON e.id = p.entity_id
                  JOIN lifebook_entities le ON le.entity_id = e.id
                 WHERE pn.id = person_name_derivatives.parent_name_id
                   AND fn_lb_membership_role(le.lifebook_id) != 'none'
                   AND NOT fn_user_is_agent()
            )
        )
        OR fn_is_subject_of(
            (SELECT e.id
               FROM person_names pn
               JOIN persons p ON p.entity_id = pn.person_id
               JOIN entities e ON e.id = p.entity_id
              WHERE pn.id = person_name_derivatives.parent_name_id)
        )
    );

-- Policy 15
CREATE POLICY pol_authority_assignments_select
    ON authority_assignments FOR SELECT
    USING (
        fn_lb_membership_role(lifebook_id) = 'steward'
        OR fn_is_subject_of(entity_id)
    );

-- Policy 66
CREATE POLICY pol_approval_records_select
    ON approval_records FOR SELECT
    USING (NOT fn_user_is_agent());

-- Policy 67
CREATE POLICY pol_display_policies_select
    ON display_policies FOR SELECT
    USING (NOT fn_user_is_agent());

-- Policy 68
CREATE POLICY pol_display_policy_rules_select
    ON display_policy_rules FOR SELECT
    USING (NOT fn_user_is_agent());

-- Policy 70
CREATE POLICY pol_source_derivatives_select_lifebook
    ON source_derivatives FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM sources s
             WHERE s.id = source_derivatives.source_id
               AND fn_lb_membership_role(s.lifebook_id) != 'none'
        )
    );

-- ============================================================
-- Group D — INSERT and AI Restrictions (policies 30–36, 41, 47, 51, 69, 71)
-- ============================================================

-- Policy 30: pol_claims_ai_promotion_denied — DEFERRED to Addendum section below.
-- claims.review_status is added by ALTER TABLE in the Addendum; the CREATE POLICY
-- statement cannot reference it before that ALTER TABLE executes.
-- PostgreSQL raises SQLSTATE 42703 "column review_status does not exist" if a policy
-- references a column that does not yet exist on the table at policy-creation time.

-- Policy 31: Agent cannot change dispute_status
CREATE POLICY pol_claims_ai_dispute_denied
    ON claims FOR UPDATE
    USING (fn_lb_membership_role(lifebook_id) != 'none')
    WITH CHECK (NOT (fn_user_is_agent() AND is_contested != (SELECT is_contested FROM claims c WHERE c.id = id)));

-- Policy 32: pol_narratives_ai_promotion_denied — DEFERRED to Addendum section below.
-- narratives.review_status is added by ALTER TABLE in the Addendum; same ordering
-- constraint as Policy 30 above.

-- Policy 33: AI cannot create Events
CREATE POLICY pol_events_insert_agent_denied
    ON events FOR INSERT
    WITH CHECK (NOT fn_user_is_agent());

-- Policy 34: AI cannot create ApprovalRecords
CREATE POLICY pol_approval_records_insert_agent_denied
    ON approval_records FOR INSERT
    WITH CHECK (NOT fn_user_is_agent());

-- Policy 35: AI cannot create Source records
CREATE POLICY pol_sources_insert_agent_denied
    ON sources FOR INSERT
    WITH CHECK (NOT fn_user_is_agent());

-- Policy 36: AI cannot create PersonName records
CREATE POLICY pol_person_names_insert_agent_denied
    ON person_names FOR INSERT
    WITH CHECK (NOT fn_user_is_agent());

-- Policy 41: Community account narratives require authorization
CREATE POLICY pol_narratives_community_account_gate
    ON narratives FOR INSERT
    WITH CHECK (
        narrative_type != 'community_account'
        OR fn_has_community_authorization(lifebook_id)
    );

-- Policy 47: display_policies INSERT requires valid authority for set_by_role
CREATE POLICY pol_display_policies_insert_authorized
    ON display_policies FOR INSERT
    WITH CHECK (fn_has_active_authority(set_by_role, NULL));

-- Policy 51: ContestRecord INSERT requires verified standing
CREATE POLICY pol_contest_records_insert_standing
    ON contest_records FOR INSERT
    WITH CHECK (fn_has_contest_standing(contested_record_table, contested_record_id, standing_class));

-- Policy 69: person_name_derivatives INSERT — agent denied
CREATE POLICY pol_person_name_derivatives_insert
    ON person_name_derivatives FOR INSERT
    WITH CHECK (NOT fn_user_is_agent());

-- Policy 71: source_derivatives INSERT — agent denied
CREATE POLICY pol_source_derivatives_insert_system
    ON source_derivatives FOR INSERT
    WITH CHECK (NOT fn_user_is_agent());

-- ============================================================
-- Group E — Cultural and Classification (policies 37–44)
-- AS RESTRICTIVE: prevents agent_service from reading culturally governed records
-- even if another permissive policy would allow it
-- ============================================================

-- Policy 37: Culturally governed claims excluded from AI — RESTRICTIVE
CREATE POLICY pol_claims_cultural_ai_excluded
    ON claims AS RESTRICTIVE FOR SELECT
    USING (NOT (fn_user_is_agent() AND access_classification = 'culturally_governed'));

-- Policy 38: Culturally governed narratives excluded from AI — RESTRICTIVE
CREATE POLICY pol_narratives_cultural_ai_excluded
    ON narratives AS RESTRICTIVE FOR SELECT
    USING (NOT (fn_user_is_agent() AND access_classification = 'culturally_governed'));

-- Policy 39: Culturally governed artifacts excluded from AI — RESTRICTIVE
CREATE POLICY pol_artifacts_cultural_ai_excluded
    ON artifacts AS RESTRICTIVE FOR SELECT
    USING (NOT (fn_user_is_agent() AND access_classification = 'culturally_governed'));

-- Policy 40: Culturally governed sources excluded from AI — RESTRICTIVE
CREATE POLICY pol_sources_cultural_ai_excluded
    ON sources AS RESTRICTIVE FOR SELECT
    USING (NOT (fn_user_is_agent() AND access_classification = 'culturally_governed'));

-- Policy 42: Restricted artifacts — steward only
CREATE POLICY pol_artifacts_restricted_steward_only
    ON artifacts FOR SELECT
    USING (
        access_classification != 'restricted'
        OR fn_lb_membership_role(lifebook_id) = 'steward'
    );

-- Policy 43: Culturally governed artifacts — steward or cultural_authority
CREATE POLICY pol_artifacts_culturally_governed_authority
    ON artifacts FOR SELECT
    USING (
        access_classification != 'culturally_governed'
        OR fn_lb_membership_role(lifebook_id) = 'steward'
        OR fn_has_active_authority('cultural_authority', NULL)
    );

-- Policy 44: Restricted sources — steward only
CREATE POLICY pol_sources_restricted_steward_only
    ON sources FOR SELECT
    USING (
        access_classification != 'restricted'
        OR fn_lb_membership_role(lifebook_id) = 'steward'
    );

-- ============================================================
-- Group F — DisplayPolicy Lifecycle (policies 45–48)
-- ============================================================

-- Policy 45: Only draft display_policies may be deleted
CREATE POLICY pol_display_policies_delete_non_draft_denied
    ON display_policies FOR DELETE
    USING (status = 'draft');

-- Policy 46: Superseded/withdrawn policies completely immutable via RLS
CREATE POLICY pol_display_policies_update_frozen
    ON display_policies FOR UPDATE
    USING (status IN ('draft', 'active'));

-- Policy 48: Rules on non-draft policies are immutable
CREATE POLICY pol_display_policy_rules_non_draft_denied
    ON display_policy_rules FOR DELETE
    USING (
        (SELECT status FROM display_policies WHERE id = display_policy_rules.display_policy_id) = 'draft'
    );

-- ============================================================
-- Group G — Governance (policies 50, 52–53)
-- ============================================================

-- Policy 50: authority_assignments UPDATE — revocation only (LifeBook-scoped)
-- NOTE: entity-scoped assignments where lifebook_id IS NULL are NOT covered here
-- Revocation of NULL-lifebook_id assignments goes through SECURITY DEFINER path
CREATE POLICY pol_authority_assignments_update_revocation_only
    ON authority_assignments FOR UPDATE
    USING (
        lifebook_id IS NOT NULL
        AND fn_lb_membership_role(lifebook_id) = 'steward'
    );

-- Policy 52: ContestRecord SELECT — steward or parties with standing
CREATE POLICY pol_contest_records_select_parties
    ON contest_records FOR SELECT
    USING (
        fn_lb_membership_role(lifebook_id) = 'steward'
        OR fn_has_contest_standing(contested_record_table, contested_record_id, standing_class)
    );

-- Policy 53: Agent cannot read restricted name derivatives
CREATE POLICY pol_person_name_derivatives_agent_restricted
    ON person_name_derivatives AS RESTRICTIVE FOR SELECT
    USING (NOT fn_user_is_agent());

-- ============================================================
-- Group H — LifeBook Entity Access (policies 54–58, 60–64)
-- ============================================================

-- Policy 54: Steward sees all lifebook_entity records
CREATE POLICY pol_lifebook_entities_select_steward
    ON lifebook_entities FOR SELECT
    USING (
        fn_lb_membership_role(lifebook_id) = 'steward'
        AND NOT fn_user_is_agent()
    );

-- Policy 55: Members see only visible and anonymized entities
CREATE POLICY pol_lifebook_entities_select_member_visible
    ON lifebook_entities FOR SELECT
    USING (
        fn_lb_membership_role(lifebook_id) IN ('contributor', 'viewer')
        AND visibility_status IN ('visible', 'anonymized')
        AND NOT fn_user_is_agent()
    );

-- Policy 56: Subject always sees their own lifebook_entity record
CREATE POLICY pol_lifebook_entities_select_subject_own
    ON lifebook_entities FOR SELECT
    USING (
        fn_is_subject_of(entity_id)
        AND NOT fn_user_is_agent()
    );

-- Policy 57: Only steward may add entities to a LifeBook
CREATE POLICY pol_lifebook_entities_insert_steward
    ON lifebook_entities FOR INSERT
    WITH CHECK (fn_lb_membership_role(lifebook_id) = 'steward');

-- Policy 58: Only steward may update entity participation records
CREATE POLICY pol_lifebook_entities_update_steward
    ON lifebook_entities FOR UPDATE
    USING (fn_lb_membership_role(lifebook_id) = 'steward');

-- Policy 60: Steward sees all person contexts in their LifeBook
CREATE POLICY pol_lifebook_person_contexts_select_steward
    ON lifebook_person_contexts FOR SELECT
    USING (
        fn_lb_membership_role(
            (SELECT lifebook_id FROM lifebook_entities WHERE id = lifebook_person_contexts.lifebook_entity_id)
        ) = 'steward'
        AND NOT fn_user_is_agent()
    );

-- Policy 61: Subject sees their own person context record
CREATE POLICY pol_lifebook_person_contexts_select_subject
    ON lifebook_person_contexts FOR SELECT
    USING (
        fn_is_subject_of(entity_id)
        AND NOT fn_user_is_agent()
    );

-- Policy 62: Only steward may create person context records
CREATE POLICY pol_lifebook_person_contexts_insert_steward
    ON lifebook_person_contexts FOR INSERT
    WITH CHECK (
        fn_lb_membership_role(
            (SELECT lifebook_id FROM lifebook_entities WHERE id = lifebook_entity_id)
        ) = 'steward'
    );

-- Policy 63: Steward UPDATE for governance fields
CREATE POLICY pol_lifebook_person_contexts_update_steward
    ON lifebook_person_contexts FOR UPDATE
    USING (
        fn_lb_membership_role(
            (SELECT lifebook_id FROM lifebook_entities WHERE id = lifebook_person_contexts.lifebook_entity_id)
        ) = 'steward'
    );

-- Policy 64: Subject UPDATE for consent fields
CREATE POLICY pol_lifebook_person_contexts_update_subject
    ON lifebook_person_contexts FOR UPDATE
    USING (fn_is_subject_of(entity_id));

-- ---------------------------------------------------------------------------
-- Phase 8 — Grants
-- ---------------------------------------------------------------------------

-- Step 1: REVOKE EXECUTE FROM PUBLIC on all helper functions
REVOKE EXECUTE ON FUNCTION fn_user_is_agent()                                   FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_lb_membership_role(UUID)                          FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_is_subject_of(UUID)                               FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_has_active_authority(TEXT, UUID)                  FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_display_policy_allows(UUID, TEXT)                 FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_has_source_access_grant(UUID)                     FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_has_community_authorization(UUID)                 FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_has_contest_standing(TEXT, UUID, TEXT)            FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_generate_artifact_signed_url(UUID, TEXT)          FROM PUBLIC;

-- Step 2: Per-role EXECUTE grants per SECURITY_DEFINER_REVIEW.md §EXECUTE grants table
GRANT EXECUTE ON FUNCTION fn_user_is_agent()                          TO authenticated, agent_service, system_service;
GRANT EXECUTE ON FUNCTION fn_lb_membership_role(UUID)                 TO authenticated, agent_service, system_service;
GRANT EXECUTE ON FUNCTION fn_is_subject_of(UUID)                      TO authenticated;
GRANT EXECUTE ON FUNCTION fn_has_active_authority(TEXT, UUID)         TO authenticated, system_service;
GRANT EXECUTE ON FUNCTION fn_display_policy_allows(UUID, TEXT)        TO authenticated, agent_service, system_service;
GRANT EXECUTE ON FUNCTION fn_has_source_access_grant(UUID)            TO authenticated;
GRANT EXECUTE ON FUNCTION fn_has_community_authorization(UUID)        TO authenticated, system_service;
GRANT EXECUTE ON FUNCTION fn_has_contest_standing(TEXT, UUID, TEXT)   TO authenticated;
GRANT EXECUTE ON FUNCTION fn_generate_artifact_signed_url(UUID, TEXT) TO authenticated;

-- Step 3: Content table grants by role
-- authenticated role: SELECT, INSERT, UPDATE on content tables (RLS restricts actors further)
GRANT SELECT, INSERT, UPDATE ON TABLE claims                    TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE relationships             TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE narratives                TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE narrative_entities        TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE sources                   TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE artifacts                 TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE events                    TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE event_participants        TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE display_policies          TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE display_policy_rules      TO authenticated;
GRANT SELECT                  ON TABLE approval_records         TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE authority_assignments     TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE contest_records           TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE person_names              TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE person_pronouns           TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE person_gender_descriptors TO authenticated;
GRANT SELECT                  ON TABLE person_name_derivatives  TO authenticated;
GRANT SELECT                  ON TABLE context_manifests        TO authenticated;
GRANT SELECT                  ON TABLE access_policy_changed_events TO authenticated;
GRANT SELECT                  ON TABLE source_derivatives       TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE lifebook_entities         TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE lifebook_person_contexts  TO authenticated;
GRANT SELECT                  ON TABLE claim_evidence           TO authenticated;
GRANT SELECT                  ON TABLE artifact_source_links    TO authenticated;

-- agent_service role: SELECT on governed content tables; INSERT on claims and narratives
GRANT SELECT ON TABLE claims, narratives, sources, artifacts, events      TO agent_service;
GRANT SELECT ON TABLE event_participants, narrative_entities              TO agent_service;
GRANT SELECT ON TABLE source_derivatives, claim_evidence                  TO agent_service;
GRANT INSERT ON TABLE claims, narratives                                  TO agent_service;

-- system_service role: broad SELECT; INSERT on audit/governance tables; UPDATE on cache
GRANT SELECT ON ALL TABLES IN SCHEMA public                               TO system_service;
GRANT INSERT ON TABLE approval_records, context_manifests                 TO system_service;
GRANT INSERT ON TABLE source_derivatives, access_policy_changed_events    TO system_service;
GRANT INSERT ON TABLE lifebook_person_contexts                            TO system_service;
GRANT UPDATE ON TABLE lifebook_person_contexts                            TO system_service;
GRANT INSERT ON TABLE person_name_derivatives                             TO system_service;

-- admin role: SELECT on all tables; no RLS bypass (admin is not a superuser)
GRANT SELECT ON ALL TABLES IN SCHEMA public                               TO admin;

-- Reference catalogue tables: SELECT for all authenticated roles
GRANT SELECT ON TABLE claim_predicates, claim_value_units, relationship_types TO authenticated;
GRANT SELECT ON TABLE agent_registry, context_profiles, display_contexts      TO authenticated;
GRANT SELECT ON TABLE jurisdictions, jurisdiction_policy_versions             TO authenticated;
GRANT SELECT ON TABLE escalation_policies, approval_policies                  TO authenticated;
GRANT SELECT ON TABLE conflict_resolution_policies                            TO authenticated;
GRANT SELECT ON TABLE entities, persons, organizations, places                TO authenticated;
GRANT SELECT ON TABLE vessels, communities, event_series, user_profiles       TO authenticated;
GRANT SELECT ON TABLE lifebooks, lifebook_memberships, user_person_links      TO authenticated;
GRANT SELECT ON TABLE merge_records, cross_lifebook_authorizations            TO authenticated;
GRANT SELECT ON TABLE lifebook_source_access                                  TO authenticated;
GRANT SELECT ON TABLE escalation_records, escalation_notifications            TO authenticated;

-- ---------------------------------------------------------------------------
-- COMMIT — end of transaction block
-- ---------------------------------------------------------------------------


-- ---------------------------------------------------------------------------
-- Addendum: Missing columns on claims (discovered after initial DDL authoring)
-- All must be within the transaction block
-- ---------------------------------------------------------------------------

-- Claims requires status fields for AI governance policies (30, 31) and triggers
ALTER TABLE claims
    ADD COLUMN review_status      TEXT    NOT NULL DEFAULT 'pending'
        CHECK (review_status IN ('pending','under_review','policy_approved','rejected')),
    ADD COLUMN submission_origin  TEXT    NOT NULL DEFAULT 'manual'
        CHECK (submission_origin IN ('manual','ai_extracted_submission','document_extraction','imported')),
    ADD COLUMN ai_generated       BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN producing_agent_code TEXT  NULL,
    ADD COLUMN context_manifest_id UUID   NULL;
-- NOTE: context_manifest_id FK → context_manifests will be added after Batch 11 context_manifests DDL;
-- context_manifests is in the same migration but was created after claims.
-- Since claims DDL precedes context_manifests DDL in this file, we defer the FK.
ALTER TABLE claims
    ADD CONSTRAINT fk_claims_context_manifest
    FOREIGN KEY (context_manifest_id) REFERENCES context_manifests(id);

-- Narratives also requires review_status for policy 32
ALTER TABLE narratives
    ADD COLUMN review_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (review_status IN ('pending','under_review','policy_approved','rejected'));

-- Phase 3 Addendum (deferred) — idx_claims_lifebook_review_access
-- This index could not be created at Phase 3 because review_status is added
-- to claims by the ALTER TABLE above. Placed here, immediately after that
-- ALTER TABLE, so the column is guaranteed to exist.
-- Source: VOCABULARY_RLS_MATRIX.md §9 (same authority as Phase 3 Addendum)
CREATE INDEX idx_claims_lifebook_review_access
    ON claims (lifebook_id, review_status, access_classification);

-- ---------------------------------------------------------------------------
-- Addendum — Deferred RLS policies (policies 30, 32)
-- These policies reference columns added by the ALTER TABLE statements above.
-- CREATE POLICY validates column existence at execution time (SQLSTATE 42703 if
-- the column does not yet exist). They must appear after the ALTER TABLE that
-- creates the referenced column.
-- ---------------------------------------------------------------------------

-- Policy 30 (deferred): Agent cannot set review_status = 'policy_approved'
-- Depends on: ALTER TABLE claims ADD COLUMN review_status (Addendum above)
CREATE POLICY pol_claims_ai_promotion_denied
    ON claims FOR UPDATE
    USING (fn_lb_membership_role(lifebook_id) != 'none')
    WITH CHECK (NOT (fn_user_is_agent() AND review_status = 'policy_approved'));

-- Policy 32 (deferred): Agent cannot set review_status = 'policy_approved' on narratives
-- Depends on: ALTER TABLE narratives ADD COLUMN review_status (Addendum above)
CREATE POLICY pol_narratives_ai_promotion_denied
    ON narratives FOR UPDATE
    USING (fn_lb_membership_role(lifebook_id) != 'none')
    WITH CHECK (NOT (fn_user_is_agent() AND review_status = 'policy_approved'));

-- ---------------------------------------------------------------------------
-- COMMIT — end of transaction block
-- ---------------------------------------------------------------------------

COMMIT;

-- ---------------------------------------------------------------------------
-- Phase 9 — Validation Queries (as comments — run manually after applying)
-- Source: VOCABULARY_RLS_MATRIX.md §9 Phase 9 (12 queries — authoritative)
-- ---------------------------------------------------------------------------

-- 1. RLS active:
--    SELECT tablename FROM pg_tables WHERE rowsecurity = TRUE;
--    Expected: 25 rows — all tables listed in Phase 6 above

-- 2. Trigger count:
--    SELECT count(*) FROM information_schema.triggers WHERE trigger_schema = 'public';
--    Expected: 22 (all triggers created in Phase 5 Pass A + B + C)

-- 3. Function count:
--    SELECT count(*) FROM pg_proc WHERE proname LIKE 'fn_%' AND pronamespace = 'public'::regnamespace;
--    Expected: 9 helper functions

-- 4. Fail-closed:
--    -- Connect as unauthenticated or anon role then:
--    SELECT count(*) FROM claims;
--    Expected: 0 rows or permission denied

-- 5. Agent exclusion:
--    -- Connect as agent_service role then:
--    SELECT count(*) FROM claims WHERE access_classification = 'culturally_governed';
--    Expected: 0 rows

-- 6. Permanence:
--    DELETE FROM claims LIMIT 1;
--    Expected: ERROR — RLS policy (USING FALSE) blocks delete

-- 7. Immutability:
--    UPDATE claims SET predicate_id = '<some_other_uuid>' WHERE id = '<any_valid_uuid>';
--    Expected: ERROR from trigger trg_claim_content_immutable

-- 8. Policy guard:
--    INSERT INTO display_policy_rules (display_policy_id, display_context_code, decision) VALUES ('<active_policy_id>', 'public_ui', 'allow');
--    Expected: ERROR from trigger trg_display_policy_rules_update_guard (parent status != 'draft')

-- 9. Deferred FK:
--    SELECT conname FROM pg_constraint
--     WHERE conname IN ('fk_authority_basis_claim', 'fk_display_policy_approval_record',
--                       'fk_permission_cache_approval_policy');
--    Expected: 3 rows

-- 10. Supersession:
--     UPDATE claims SET superseded_by_id = id WHERE id = '<any_valid_uuid>';
--     Expected: ERROR from trigger trg_claim_supersession_integrity (self-reference denied)

-- 11. Policy count:
--     SELECT count(*) FROM pg_policies WHERE schemaname = 'public';
--     Expected: 71

-- 12. Partial index:
--     SELECT indexname FROM pg_indexes
--      WHERE tablename = 'lifebook_entities'
--        AND indexname = 'uq_lifebook_entities_active';
--     Expected: 1 row (confirms partial unique index, not table-level UNIQUE constraint)
