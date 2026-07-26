-- ============================================================
-- Migration: 20260726083202_application_roles.sql
-- LifeBook — Application database role provisioning
-- ============================================================
-- Status:   APPROVED — authorized by Discovery Partner 2026-07-26
-- Authored: 2026-07-26
-- Applied:  Pending
--
-- Contents:
--   §1  agent_service    — read/limited-write role for the AI agent tier
--   §2  system_service   — privileged internal service role
--   §3  admin            — administrative read-all role
--   §4  governance_functions — ownership role for SECURITY DEFINER functions
--
-- Migration philosophy:
--   This migration is the single authoritative owner of all LifeBook
--   application database roles. No other migration creates these roles.
--   Role provisioning is separated from schema DDL so that:
--     (a) roles can be audited independently of schema objects;
--     (b) role definitions can be reviewed before schema privileges are granted;
--     (c) deployment preflight can compare role attributes before applying.
--
--   All four roles are NOLOGIN privilege-group roles. They hold no credentials.
--   Login identities (application service accounts) receive privileges through
--   membership in these group roles via a separate, environment-specific
--   credential-provisioning step that is NOT part of this migration.
--
--   Migration must fail loudly if a role already exists unexpectedly.
--   PostgreSQL will raise ERROR 42710 (duplicate_object) and the transaction
--   will roll back. This is correct behaviour — a pre-existing role with
--   the same name and unknown attributes must be investigated before proceeding.
--
--   No IF NOT EXISTS guard.
--   No EXCEPTION WHEN duplicate_object suppression.
--   No passwords assigned.
--   No schema or table privileges granted here — that is Migration 0003's scope.
--   No memberships assigned to login roles here.
--
-- Dependency context:
--   Requires: 20260724153745_types_and_vocabularies (applied)
--             20260726083201_predicate_governance_types (applied)
--   Required by: 20260726083203_core_schema (pending)
--
-- Pre-flight check before applying to any environment:
--   Verify that none of the following role names already exist:
--     SELECT rolname FROM pg_roles
--     WHERE rolname IN ('agent_service','system_service','admin','governance_functions');
--   Expected: 0 rows. If any row is returned, stop and investigate.
--
-- Rollback (before core_schema is applied):
--   DROP ROLE governance_functions;
--   DROP ROLE admin;
--   DROP ROLE system_service;
--   DROP ROLE agent_service;
--   After core_schema is applied, rollback requires a dedicated rollback migration.
-- ============================================================

BEGIN;

-- ============================================================
-- §1 — agent_service
-- Purpose: Privilege-group role for the AI agent service tier.
--          Receives read access and limited write access to content
--          tables required for agent operations (claims, narratives,
--          sources, artifacts). Granted by Migration 0003.
-- Attributes: Non-login, no elevated PostgreSQL capabilities,
--             no RLS bypass, inherits from granted roles.
-- ============================================================

CREATE ROLE agent_service
    NOLOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS;

COMMENT ON ROLE agent_service IS
    'LifeBook AI agent service privilege role. NOLOGIN — no credentials held. '
    'Login identities receive privileges through membership in this role. '
    'Owned by migration 20260726083202_application_roles.';


-- ============================================================
-- §2 — system_service
-- Purpose: Privilege-group role for internal system services
--          (approval workflows, context manifests, derivation pipeline,
--          access-policy change events). Receives broad SELECT and
--          targeted INSERT/UPDATE rights granted by Migration 0003.
-- Attributes: Non-login, no elevated PostgreSQL capabilities,
--             no RLS bypass, inherits from granted roles.
-- ============================================================

CREATE ROLE system_service
    NOLOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS;

COMMENT ON ROLE system_service IS
    'LifeBook internal system service privilege role. NOLOGIN — no credentials held. '
    'Login identities receive privileges through membership in this role. '
    'Owned by migration 20260726083202_application_roles.';


-- ============================================================
-- §3 — admin
-- Purpose: Privilege-group role for administrative tooling.
--          Receives SELECT ON ALL TABLES IN SCHEMA public granted
--          by Migration 0003. Does not receive write privileges
--          through this role.
-- Attributes: Non-login, no elevated PostgreSQL capabilities,
--             no RLS bypass, inherits from granted roles.
-- ============================================================

CREATE ROLE admin
    NOLOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS;

COMMENT ON ROLE admin IS
    'LifeBook administrative read-all privilege role. NOLOGIN — no credentials held. '
    'Login identities receive privileges through membership in this role. '
    'Owned by migration 20260726083202_application_roles.';


-- ============================================================
-- §4 — governance_functions
-- Purpose: Ownership role for SECURITY DEFINER governance functions.
--          Functions that require elevated internal access are owned
--          by this role so that callers gain only what the function
--          explicitly permits, not the owner's full privilege set.
--          No ordinary application credential should receive membership
--          in this role unless an approved security design explicitly
--          requires SET ROLE access.
-- Attributes: Non-login, no elevated PostgreSQL capabilities,
--             no RLS bypass, inherits from granted roles.
-- ============================================================

CREATE ROLE governance_functions
    NOLOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS;

COMMENT ON ROLE governance_functions IS
    'LifeBook SECURITY DEFINER function ownership role. NOLOGIN — no credentials held. '
    'No application login should be a member of this role. '
    'Owned by migration 20260726083202_application_roles.';

COMMIT;

-- ============================================================
-- POST-APPLICATION VALIDATION QUERIES
-- Run after COMMIT to verify role creation.
--
-- V1: All four roles exist with correct attributes
--   SELECT rolname, rolcanlogin, rolsuper, rolcreaterole, rolcreatedb,
--          rolreplication, rolbypassrls
--   FROM pg_roles
--   WHERE rolname IN ('agent_service','system_service','admin','governance_functions')
--   ORDER BY rolname;
--   Expected: 4 rows, all: LOGIN=false, SUPERUSER=false, CREATEROLE=false,
--             CREATEDB=false, REPLICATION=false, BYPASSRLS=false
--
-- V2: No memberships yet assigned
--   SELECT r.rolname AS group_role, mr.rolname AS member
--   FROM pg_auth_members m
--   JOIN pg_roles r  ON r.oid = m.roleid
--   JOIN pg_roles mr ON mr.oid = m.member
--   WHERE r.rolname IN ('agent_service','system_service','admin','governance_functions');
--   Expected: 0 rows
--
-- V3: No table privileges yet assigned
--   SELECT grantee, table_name, privilege_type
--   FROM information_schema.role_table_grants
--   WHERE grantee IN ('agent_service','system_service','admin','governance_functions');
--   Expected: 0 rows
-- ============================================================
