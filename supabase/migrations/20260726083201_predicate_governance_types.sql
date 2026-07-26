-- ============================================================
-- Migration: 0002 — predicate_governance_types
-- LifeBook — Predicate governance enum types and display_contexts reference table
-- ============================================================
-- Status:   APPROVED — SQL authoring authorized by Discovery Partner 2026-07-25
-- Authored: 2026-07-26
-- Applied:  Pending
--
-- Contents:
--   §1  relationship_interaction_type enum
--   §2  display_policy_status enum
--   §3  display_policy_decision enum
--   §4  display_contexts reference table + 9 seed records
--   §5  Validation queries (post-application verification)
--
-- Source documents:
--   MIGRATION_IMPLEMENTATION_PLAN.md §1 (scope, seed, validation)
--   MIGRATION_PHILOSOPHY.md (execution semantics)
--   DISPLAY_POLICY_MODEL.md (display context codes and descriptions)
--
-- Migration philosophy (LifeBook migrations from 0002 onward):
--   One migration, one logical purpose. This migration is a vocabulary migration —
--   it extends the type system begun in 0001 with types and reference data required
--   by the core schema migration (0003).
--
--   Schema DDL uses no IF NOT EXISTS guards. If a type or table already exists when
--   this migration runs, it must fail — schema drift must be surfaced, not silently
--   ignored. Seed INSERT statements use plain INSERT INTO with no ON CONFLICT guards.
--   If a seed record already exists, the migration fails with a unique constraint
--   violation — a pre-existing seed record indicates a lineage or governance problem
--   that must be investigated before proceeding.
--
--   All migration SQL is wrapped in an explicit transaction. Any failure aborts
--   the entire migration. There is no partial success.
--
-- Dependency context:
--   Requires: 0001 (20260724153745_types_and_vocabularies.sql) — applied
--   Required by: 0003 (_core_schema.sql) — pending
--
-- Rollback (before 0003 is applied):
--   DROP TABLE display_contexts;
--   DROP TYPE display_policy_decision;
--   DROP TYPE display_policy_status;
--   DROP TYPE relationship_interaction_type;
--   After 0003 is applied, rollback of 0002 requires a dedicated rollback migration.
-- ============================================================

BEGIN;

-- ============================================================
-- §1 — ENUM: relationship_interaction_type
-- Source: MIGRATION_IMPLEMENTATION_PLAN.md §1.2
-- Purpose: Classifies how a Claim or set of Claims interacts with a
--          Relationship record (used in claim_predicates.generates_interaction_type).
-- ============================================================

CREATE TYPE relationship_interaction_type AS ENUM (
    'proposes',   -- Claim proposes the existence of the Relationship
    'supports',   -- Claim provides supporting evidence for an existing Relationship
    'describes',  -- Claim provides descriptive detail about the Relationship
    'none'        -- Claim has no interaction with Relationship records
);


-- ============================================================
-- §2 — ENUM: display_policy_status
-- Source: MIGRATION_IMPLEMENTATION_PLAN.md §1.2
-- Purpose: Governs the lifecycle state of DisplayPolicy records.
--          Only 'active' policies are evaluated. Lifecycle transitions are
--          guarded by trg_display_policies_lifecycle and trg_display_policies_delete_guard.
-- ============================================================

CREATE TYPE display_policy_status AS ENUM (
    'draft',        -- Policy is being authored; not yet active
    'active',       -- Policy is in effect and evaluated for all display context decisions
    'superseded',   -- Policy has been replaced by a newer version; retained for audit
    'withdrawn'     -- Policy was retired before being superseded; retained for audit
);


-- ============================================================
-- §3 — ENUM: display_policy_decision
-- Source: MIGRATION_IMPLEMENTATION_PLAN.md §1.2
-- Purpose: Represents the decision outcome in a display_policy_rules row.
--          fn_display_policy_allows evaluates rules and returns BOOLEAN.
-- ============================================================

CREATE TYPE display_policy_decision AS ENUM (
    'allow',        -- Content is permitted in this display context
    'deny',         -- Content is denied in this display context
    'conditional'   -- Decision requires further evaluation (e.g., caller role, time, authority)
);


-- ============================================================
-- §4 — TABLE: display_contexts (reference table)
-- Source: MIGRATION_IMPLEMENTATION_PLAN.md §1.2, §1.4
--         DISPLAY_POLICY_MODEL.md (code definitions and descriptions)
-- Purpose: Canonical set of named display contexts used as FK targets by
--          display_policy_rules.display_context_code. This table is authoritative;
--          no context code outside this table may appear in display_policy_rules.
--          Governed by DISPLAY_POLICY_MODEL.md v0.1 and PRE_SQL_READINESS_REVIEW.md.
-- ============================================================

CREATE TABLE display_contexts (
    code       TEXT         NOT NULL,
    label      TEXT         NOT NULL,
    description TEXT        NOT NULL,
    sort_order INT          NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT pk_display_contexts PRIMARY KEY (code),
    CONSTRAINT uq_display_contexts_sort_order UNIQUE (sort_order)
);

COMMENT ON TABLE display_contexts IS
    'Canonical display context registry. Each code names one context in which '
    'LifeBook content may be displayed or exported. Codes are stable — they are '
    'referenced as TEXT FKs in display_policy_rules. Do not add codes without a '
    'Discovery Partner session and a new migration.';

-- Seed: 9 canonical display contexts in sort_order sequence
-- Source: DISPLAY_POLICY_MODEL.md (codes, labels, descriptions)
--         MIGRATION_IMPLEMENTATION_PLAN.md §1.4 (sort_order)
-- Plain INSERT — no ON CONFLICT guard. Migration must fail if records already exist.

INSERT INTO display_contexts (code, label, description, sort_order)
VALUES
    ('public_ui',
     'Public UI',
     'General public-facing display',
     1),

    ('family_ui',
     'Family UI',
     'Display to LifeBook contributors and family members',
     2),

    ('steward_ui',
     'Steward UI',
     'Display to the designated LifeBook steward',
     3),

    ('historical_record',
     'Historical Record',
     'Archival and historical research use',
     4),

    ('ordinary_search',
     'Ordinary Search',
     'General name and identity search',
     5),

    ('identity_resolution_search',
     'Identity Resolution Search',
     'Identity matching and disambiguation search',
     6),

    ('default_export',
     'Default Export',
     'Standard data export for the LifeBook owner',
     7),

    ('steward_export',
     'Steward Export',
     'Data export generated by the steward',
     8),

    ('ai_generation',
     'AI Generation',
     'Data provided to AI context for narrative generation',
     9);

COMMIT;

-- ============================================================
-- §5 — VALIDATION QUERIES (run manually after COMMIT)
-- Source: MIGRATION_IMPLEMENTATION_PLAN.md §1.5
--
-- Run each query in a Supabase SQL editor or psql session connected
-- to the target database after the migration is applied.
-- All expected results must match before Migration 0003 authoring begins.
-- ============================================================

-- V1: Three new enum types exist
--   SELECT typname FROM pg_type
--   WHERE typname IN ('relationship_interaction_type', 'display_policy_status', 'display_policy_decision')
--   ORDER BY typname;
--   Expected: 3 rows — display_policy_decision, display_policy_status, relationship_interaction_type

-- V2: display_contexts table exists with PK on code
--   \d display_contexts
--   Expected: PRIMARY KEY on code; TEXT NOT NULL; sort_order INT NOT NULL

-- V3: Exactly 9 seed records
--   SELECT count(*) FROM display_contexts;
--   Expected: 9

-- V4: All 9 codes in sort_order sequence
--   SELECT code FROM display_contexts ORDER BY sort_order;
--   Expected: public_ui, family_ui, steward_ui, historical_record, ordinary_search,
--             identity_resolution_search, default_export, steward_export, ai_generation

-- V5: No duplicate sort_orders
--   SELECT sort_order, count(*) FROM display_contexts
--   GROUP BY sort_order HAVING count(*) > 1;
--   Expected: 0 rows
