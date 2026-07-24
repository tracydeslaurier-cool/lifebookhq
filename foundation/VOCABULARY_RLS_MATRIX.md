# VOCABULARY_RLS_MATRIX.md

**Status:** Pre-approval draft — awaiting Discovery Partner review  
**Date:** 2026-07-23  
**Version:** 2.0  
**Applies to:** All reference tables defined in `0001_types_and_vocabularies.sql` (v4 — 39 tables)

---

## Supabase Role Context

| Role | RLS Behaviour | Used For |
|------|--------------|----------|
| `service_role` | Bypasses RLS entirely (Supabase default) | Migrations, seed management, admin operations |
| `authenticated` | Subject to all RLS policies | Logged-in LifeBook users and API clients |
| `anon` | Subject to all RLS policies | Unauthenticated requests — no vocabulary access granted |

LifeBook is not a public application. Unauthenticated access (`anon`) is not granted SELECT on any vocabulary table. Vocabulary rows are read during authenticated sessions only (e.g., to populate dropdowns, validate submitted codes, display labels for historical records).

---

## Idempotency Note

The policies below are written as run-once DDL, consistent with Supabase's versioned migration model. The migration runner (`supabase db push` / `supabase migration up`) tracks execution history and will not re-run a migration. `CREATE POLICY` statements in a migration file do not require `IF NOT EXISTS`. If a development environment requires repeatable setup, the idempotent pattern is:

```sql
DROP POLICY IF EXISTS "vocab_read_authenticated" ON <table>;
CREATE POLICY "vocab_read_authenticated" ON <table> ...;
```

This pattern is appropriate for seed scripts or bootstrap procedures only, not for the production migration file.

---

## Supabase Default Grant Behavior and Overrides

Supabase projects grant certain default privileges when tables are created in the `public` schema. By default, Supabase grants:
- `USAGE` on the `public` schema to both `anon` and `authenticated`
- `SELECT`, `INSERT`, `UPDATE`, `DELETE` on tables created in `public` to both `anon` and `authenticated` (via the `postgres` role and grants propagated by Supabase init scripts)

**These defaults are explicitly overridden in 0001 for every vocabulary table:**

```sql
-- Applied to every vocabulary/reference table in 0001:
REVOKE ALL ON <table> FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON <table> FROM authenticated;
GRANT SELECT ON <table> TO authenticated;
ALTER TABLE <table> ENABLE ROW LEVEL SECURITY;
CREATE POLICY "vocab_read_authenticated" ON <table> AS PERMISSIVE FOR SELECT TO authenticated USING (TRUE);
```

The REVOKE statements must precede the GRANT and policy creation. RLS is a second layer of defense — the explicit REVOKE is the primary privilege control. An `authenticated` user who bypasses RLS (which `service_role` does, but `authenticated` does not) would still be blocked from DML by the explicit REVOKE.

---

## Protected View Plan

Several vocabulary tables contain internal policy metadata that should not be exposed to every authenticated client. For these tables, a future migration (0002 or a dedicated `views` migration) will create client-readable views exposing only: `code`, `display_label`, `description`, `is_active`, `deprecated_at`, `replaced_by_code`, `sort_order`. The underlying tables retain their full schema and are accessible to `service_role`.

| Table | Sensitive Columns (not for client view) | Priority |
|-------|----------------------------------------|---------|
| `erasure_regimes` | `permits_full_erasure`, `legal_review_required`, `reviewed_at` | HIGH — legal policy signals |
| `authority_context_policy_conditions` | `priority`, `jurisdiction_code`, `effective_from`, `effective_until`, `notes` | HIGH — governance policy signals |
| `data_conflict_types` | `default_resolution_rule`, `default_escalation_policy_code` | MEDIUM — resolution policy signals |
| `submission_origins` | `default_evidence_status`, `default_review_status` | MEDIUM — processing policy signals |
| `escalation_trigger_types` | `freezes_actions` | MEDIUM — operational policy flag |
| `action_types` | `requires_dual_approval` | MEDIUM — approval policy flag |
| `source_types` | `dna_restricted`, `default_access_classification_code` | MEDIUM — access policy signals |
| `evidence_roles` | `may_raise_evidence_status`, `is_contradictory`, `is_superseding` | MEDIUM — promotion rule signals (domain logic should read these; client UI typically does not need them) |

Until protected views are implemented: direct table access with RLS SELECT policy is the effective control. Clients can read the sensitive columns but cannot mutate them. The view migration will add the separation layer without requiring changes to the base tables.

---

## RLS Design Decisions

**Decision 1 — No `anon` SELECT.**  
Vocabulary tables contain governance and legal classification data (erasure regimes, authority contexts, escalation triggers). None of this should be readable without authentication, even though the rows themselves carry no personal data. `anon` SELECT is denied on all vocabulary tables.

**Decision 2 — Authenticated reads all rows (active and deprecated).**  
A policy restricted to `is_active = TRUE` would prevent displaying labels for historical records that reference deprecated codes. The `is_active` flag is a UI hint for new-record dropdowns, not an access control gate. Authenticated users may read all rows. Application code is responsible for filtering `is_active` when presenting vocabulary options for new records.

**Decision 3 — No DML from authenticated.**  
Vocabulary tables are write-protected for all client roles. No `INSERT`, `UPDATE`, or `DELETE` policy is defined for `authenticated`. An authenticated user who attempts a direct INSERT on a vocabulary table will receive a policy violation, not a permissions error. `service_role` manages vocabulary through migrations and seed scripts.

**Decision 4 — No explicit policy for `service_role`.**  
`service_role` bypasses RLS by default in Supabase. No policy is required. This means service-role seed operations are not RLS-audited at the database level — audit must be enforced at the application deployment layer.

**Decision 5 — `authority_context_policy_conditions` is governance-sensitive.**  
This mapping table controls which lifecycle condition governs a person's authority context. It uses the same policy as other vocabulary tables (authenticated read, service_role write) but must not be mutated by application administrators. The DP note "policy-changing tables must not be mutated by normal administrators" applies here: only a deployment-role migration may alter this table's rows.

**Decision 6 — `erasure_regimes` is legally sensitive.**  
The `erasure_regimes` table determines what deletion is permitted under each legal regime. A misconfiguration could result in non-compliant data handling. The same RLS policy applies (authenticated read, service_role write), but changes to erasure regime rows require legal review (`legal_review_required` flag) tracked separately. RLS alone is not a sufficient control here — process controls are required.

---

## Policy SQL (per table)

All 39 reference/mapping tables receive the following statements. The SQL is listed once as a template and then tabulated by table.

```sql
-- Template (substitute <table_name>):
-- Step 1: Revoke Supabase default grants
REVOKE ALL ON <table_name> FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON <table_name> FROM authenticated;

-- Step 2: Grant SELECT to authenticated
GRANT SELECT ON <table_name> TO authenticated;

-- Step 3: Enable RLS and create SELECT policy
ALTER TABLE <table_name> ENABLE ROW LEVEL SECURITY;

CREATE POLICY "vocab_read_authenticated"
  ON <table_name>
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (TRUE);

-- Notes:
-- REVOKE is the primary privilege control. RLS is a second defense layer.
-- service_role bypasses RLS; it manages vocabulary through migrations only.
-- anon has no privileges after REVOKE ALL. No anon SELECT policy is created.
-- No INSERT/UPDATE/DELETE policy is created for authenticated; REVOKE covers this.
```

---

## Per-Table Policy Matrix (39 tables)

Explicit REVOKE/GRANT applied to all tables per template above. `anon SELECT: DENY` means REVOKE ALL has been executed. `authenticated DML: DENY` means explicit REVOKE of INSERT/UPDATE/DELETE/TRUNCATE has been executed — not merely absence of a DML policy.

| Table | RLS Enabled | anon SELECT | authenticated SELECT | authenticated DML | service_role | Governance Note |
|-------|-------------|-------------|---------------------|-------------------|--------------|-----------------|
| `access_classifications` | YES | DENY | PERMIT (all rows) | DENY | BYPASS | Row codes drive content access routing; the row itself is not sensitive |
| `participation_roles` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `authority_contexts` | YES | DENY | PERMIT | DENY | BYPASS | Contains governance context labels; codes used in policy selection |
| `link_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `submission_origins` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `narrative_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `content_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `source_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `artifact_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `storage_providers` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `file_storage_roles` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `artifact_source_relationships` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `participant_roles` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `event_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `authority_basis_types` | YES | DENY | PERMIT | DENY | BYPASS | Legal authority classifications; read-only for clients |
| `conflict_resolution_purposes` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `escalation_trigger_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `contest_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `jurisdiction_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `person_name_usage_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `source_derivative_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `data_conflict_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `erasure_regimes` | YES | DENY | PERMIT | DENY | BYPASS | **Legally sensitive** — row changes require legal review; process control required beyond RLS |
| `authority_context_policy_conditions` | YES | DENY | PERMIT | DENY | BYPASS | **Governance-sensitive** — changes alter which policies govern persons; service_role only via migration |
| `claim_value_units` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `organization_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `creation_sources` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `place_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `coordinate_precisions` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `vessel_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `community_types` | YES | DENY | PERMIT | DENY | BYPASS | Indigenous community classifications; expand only via governed process |
| `series_types` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `creation_reasons` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `mention_roles` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `authority_roles` | YES | DENY | PERMIT | DENY | BYPASS | **Governance-sensitive** — legal role classifications; jurisdiction-specific behavior may vary |
| `action_types` | YES | DENY | PERMIT | DENY | BYPASS | **Governance-sensitive** — governed action list; additions require policy coverage |
| `person_name_derivation_methods` | YES | DENY | PERMIT | DENY | BYPASS | — |
| `pronoun_set_types` | YES | DENY | PERMIT | DENY | BYPASS | Subject identity vocabulary; additions must be subject-led |
| `evidence_roles` | YES | DENY | PERMIT | DENY | BYPASS | **Policy-sensitive** — semantic policy columns (may_raise_evidence_status, is_contradictory, is_superseding) drive promotion rules; protected view planned to expose only display columns to client |

---

## What RLS Does Not Cover

RLS on vocabulary tables controls access to the vocabulary rows themselves. It does **not** control:

1. **Whether a classified content record is accessible** — e.g., a row in `access_classifications` with code `culturally_governed` being readable does not grant access to content records bearing that classification. Content access control is handled by RLS on content tables in later migrations.

2. **Whether a vocabulary code may be used for a new record** — application code must validate that `is_active = TRUE` before accepting a code on a new record. The database does not enforce this via FK alone.

3. **Whether an administrator may trigger a seed update** — service_role bypasses RLS. Deployment procedures must enforce that vocabulary changes to tables like `authority_context_policy_conditions` and `erasure_regimes` go through a formal change-control process, not a direct psql session.

4. **Audit of vocabulary reads** — RLS does not produce audit logs. If vocabulary access must be audited (e.g., for `erasure_regimes` reads during erasure processing), application-layer logging is required.
