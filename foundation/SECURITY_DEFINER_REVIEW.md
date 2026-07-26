# SECURITY DEFINER Review
**Version:** 1.0  
**Status:** Accepted — pre-SQL closure review  
**Date:** 2026-07-25  
**Produced by:** Discovery Partner + Claude (architecture closure session)  
**Input:** VOCABULARY_RLS_MATRIX.md v3.0 §7  
**Required before:** Migration 0003 SQL authoring — helper function creation

---

## Purpose

This document reviews every helper function that requires (or considered but rejected) the SECURITY DEFINER privilege. SECURITY DEFINER causes a function to execute with the privileges of the function owner, not the calling user. In a database with Row-Level Security, this is necessary when a function called inside an RLS policy must read a table that itself has RLS, but the use introduces privilege escalation risks that must be explicitly reviewed and mitigated.

All SECURITY DEFINER functions must be:
- Owned by a dedicated governance role (not the migration runner)
- Set with `search_path = 'public', pg_temp` to prevent search path injection
- Granted EXECUTE only to the specific roles that invoke them
- Written to return only scoped results (never return data beyond what the caller is entitled to know exists)

---

## Review Table

| # | Function Name | SECURITY DEFINER Required? | Justification | Alternative Considered | Security Risk | Mitigation |
|---|---|---|---|---|---|---|
| 1 | `fn_user_is_agent` | **No** | Uses only `current_user` or `pg_has_role()` — built-in functions that require no table access. No RLS tables read. | N/A — no privilege elevation needed | None | None required |
| 2 | `fn_lb_membership_role` | **Yes** | Called from within RLS policies on content tables (e.g., `claims`, `events`). Reads `lifebook_memberships`. If `lifebook_memberships` also has RLS enabled, calling this function without SECURITY DEFINER would trigger RLS on that table, either denying the read or causing infinite recursion if memberships RLS also calls this function. | Disable RLS on `lifebook_memberships` | An attacker who compromises the function could read membership records for LifeBooks they do not belong to. | Function must return only the calling user's own role for the specified lifebook_id — never accept a user_id parameter; derive user from `current_user`. Minimise the column set returned (role only, not full membership row). Verify that `lifebook_memberships` RLS does NOT call `fn_lb_membership_role`. |
| 3 | `fn_is_subject_of` | **Yes** | Called from RLS policies to check whether the current user has a `user_person_links` record pointing to a given entity. `user_person_links` has RLS. Without SECURITY DEFINER, the lookup from within a policy would fail or recurse. | Use `current_user_id` as a join key directly in the policy predicate — viable but produces duplicated join logic across dozens of policies; maintenance risk exceeds privilege risk. | Function with SECURITY DEFINER can read all user_person_links rows if written incorrectly. A careless implementation could allow a user to check whether *another* user is the subject of an entity. | Function must derive the user from `current_user` internally — never accept a user_id parameter. The query must be `WHERE user_id = current_user_id AND entity_id = p_entity_id`. The return value is BOOLEAN — does not expose the user_person_links row. |
| 4 | `fn_has_active_authority` | **Yes** | Called from RLS policies on `artifacts` (culturally governed access), `display_policies` (INSERT check), `authority_assignments` SELECT scope. `authority_assignments` has RLS. A policy on `artifacts` that calls a non-DEFINER function to read `authority_assignments` would be denied by `authority_assignments` RLS or recurse. | Inline the authority check as a subquery within each RLS policy USING clause — technically possible but produces fragile, duplicated subqueries across 6+ policies that must all be updated if the authority_assignments schema changes. | A SECURITY DEFINER function reading `authority_assignments` can read all assignments if written incorrectly. An attacker gaining access to the function body could construct a query that bypasses the current-user scoping. | Function must filter by `current_user` internally: `WHERE assigned_to_user_id = current_user_id AND authority_role = p_role_code AND (effective_until IS NULL OR effective_until > now())`. Never accept a user_id parameter. Recursion risk: `authority_assignments` RLS must NOT call `fn_has_active_authority` (which would recurse). `authority_assignments` RLS must use only `fn_lb_membership_role` and `fn_is_subject_of`. Document this constraint explicitly in migration comments. |
| 5 | `fn_display_policy_allows` | **Yes** | Called from application layer and from RLS on `person_names`, `person_pronouns`, `person_gender_descriptors` (SELECT filtering for agent context). Reads `display_policies` and `display_policy_rules`. Both tables have RLS. Without SECURITY DEFINER, reading display_policies from within an RLS policy on another table would fail or recurse. | Evaluate DisplayPolicy context at application layer only (no database-layer enforcement of display context decisions) — rejected because it removes the fail-closed guarantee from database-enforced contexts. | A SECURITY DEFINER function reading `display_policies` can read any policy record if written incorrectly. This is the highest-information function — a policy record contains all access decisions for all display contexts. | Function must accept `p_policy_id UUID` and evaluate only that specific policy. It must NOT accept or use a lifebook_id or user_id to do an open-ended policy lookup. Query: `WHERE id = p_policy_id AND status = 'active'`. The return is BOOLEAN — does not expose the policy record content. Critical constraint: `display_policies` RLS and `display_policy_rules` RLS must NOT call `fn_display_policy_allows`. These tables use only role-based checks in their own RLS policies. |
| 6 | `fn_has_source_access_grant` | **Yes** | Called from `sources` SELECT RLS policy. Reads `lifebook_source_access` and `cross_lifebook_authorizations`. Both tables have RLS. The source access check requires joining across two tables with active RLS — not possible without SECURITY DEFINER inside an RLS context. | Alternative: grant the calling role direct SELECT on `lifebook_source_access` and `cross_lifebook_authorizations` without RLS — rejected because it would expose cross-LifeBook authorization records to any role that can select sources. | Can read any `lifebook_source_access` or `cross_lifebook_authorizations` record if written incorrectly. | Function must filter by current user's LifeBook membership: only check access grants where the requesting LifeBook is one the current user is a member of. Derive the user's LifeBook context from `fn_lb_membership_role` (which itself is SECURITY DEFINER and already trusted). Return BOOLEAN only. |
| 7 | `fn_has_community_authorization` | **Yes** | Called from `narratives` INSERT RLS policy (community_account gate). Reads `approval_records` and `approval_policies`. Both have RLS. Without SECURITY DEFINER, reading approval_records from an INSERT check on narratives would fail. | Accept only the risk of community_account narrative creation without authorization — rejected; this is a governed deployment gate, not an optional check. | Can read any `approval_records` row if written incorrectly. Approval records contain sensitive governance chain information. | Function accepts `p_lifebook_id UUID` only. Query must filter: `WHERE lifebook_id = p_lifebook_id AND purpose = 'community_authorization' AND status = 'active'` (exact fields to be confirmed against approval_records schema). Does not expose the ApprovalRecord content — returns BOOLEAN only. |
| 8 | `fn_has_contest_standing` | **Yes** | Called from `contest_records` INSERT and SELECT RLS policies. Must read `user_person_links`, `authority_assignments`, `lifebook_memberships`, and the contested record table. All have RLS. Without SECURITY DEFINER, none of these reads succeed from within a RLS context without recursion risk. | Validate standing at application layer only, not in database RLS — rejected because it removes the database-layer guarantee that only parties with standing can create ContestRecords. | Highest recursion risk of all functions. Reading the contested record table dynamically (the table name is a parameter) using dynamic SQL creates SQL injection risk if the table name is not validated. | **Critical mitigations:** (a) Table name parameter must be validated against a whitelist of governed content tables before dynamic SQL is executed. Any unrecognized table name → exception, not silent failure. (b) The function must not call itself recursively — the contested record table RLS must not call `fn_has_contest_standing`. (c) Return BOOLEAN only — do not expose row content. (d) Whitelist: claims, relationships, narratives, narrative_entities, sources, artifacts, events, event_participants, person_names, person_pronouns, person_gender_descriptors. |
| 9 | `fn_generate_artifact_signed_url` | **Yes** | Must read `artifacts`, `display_policies`, `display_policy_rules`, `file_storage_references` — all RLS-protected — and call the storage API to generate a URL. This cannot be done without elevated privilege because the object_key is column-restricted from all non-admin roles. The function is the only mechanism through which a URL is issued. | Issue signed URLs directly from the application, bypassing database policy evaluation — rejected because it removes the guarantee that policy is evaluated before URL issuance. | **Highest privilege function in the schema.** If it returns a URL incorrectly (e.g., for a record the caller is not entitled to access), the file is exposed. If it exposes `object_key` in an error message or return path on failure, the key is leaked. | **Critical mitigations:** (a) Function must evaluate ALL of the following before generating a URL: LifeBook membership check; `access_classification` not restricted or culturally_governed (unless caller is cultural_authority); DisplayPolicy allows the requested display context; display context is not `ai_generation` if caller is agent_service. (b) If ANY check fails, return NULL — not an error with the policy details. (c) Never include `object_key` in any error message, log, or non-URL return path. (d) This function must be audited independently before production deployment. (e) Marked VOLATILE — every call may produce a different URL with a different expiry. |

---

## Cross-Cutting Mitigations

The following requirements apply to ALL SECURITY DEFINER functions (functions 2–9):

### search_path

Every SECURITY DEFINER function must set an explicit, restricted search path:

```
SET search_path = 'public', pg_temp;
```

Without this, a malicious user who can create objects in a schema that appears before `public` in the default `search_path` can shadow system functions or tables and intercept the DEFINER function's queries. This is a well-documented attack vector against SECURITY DEFINER functions.

### Ownership

Every SECURITY DEFINER function must be owned by a dedicated governance role — not by the `postgres` superuser, not by the migration runner role, and not by the `authenticated` role. A dedicated `governance_functions` role should be created in the migration, own all SECURITY DEFINER functions, and have no other privileges.

Rationale: if a SECURITY DEFINER function is owned by `postgres`, any exploit that calls the function executes with full superuser privileges. A dedicated governance role has only the privileges needed to read the specific tables the function queries.

### EXECUTE grants

Each SECURITY DEFINER function should be granted EXECUTE only to the roles that invoke it:

| Function | Granted to |
|---|---|
| `fn_lb_membership_role` | `authenticated`, `agent_service`, `system_service` |
| `fn_is_subject_of` | `authenticated` |
| `fn_has_active_authority` | `authenticated`, `system_service` |
| `fn_display_policy_allows` | `authenticated`, `agent_service`, `system_service` |
| `fn_has_source_access_grant` | `authenticated` |
| `fn_has_community_authorization` | `authenticated`, `system_service` |
| `fn_has_contest_standing` | `authenticated` |
| `fn_generate_artifact_signed_url` | `authenticated` |
| `fn_user_is_agent` | `authenticated`, `agent_service`, `system_service` |

REVOKE EXECUTE FROM PUBLIC must be issued for all functions before individual grants are made. PostgreSQL grants EXECUTE to PUBLIC by default.

### No user_id parameters

No SECURITY DEFINER function accepts a `user_id` or equivalent parameter that allows the caller to query data on behalf of another user. All user context is derived from `current_user` or `auth.uid()` (Supabase) internally within the function. Accepting a user_id parameter would allow any authenticated user to invoke the function as if they were another user.

---

## Recursion Risk Summary

Three functions carry documented recursion risk. The mitigation in each case is a constraint on the RLS policies of the tables those functions read:

| Risk | Function | Table with Recursion Risk | Constraint Required |
|---|---|---|---|
| 1 | `fn_has_active_authority` | `authority_assignments` | `authority_assignments` RLS must NOT call `fn_has_active_authority`; may only use `fn_lb_membership_role` and `fn_is_subject_of` |
| 2 | `fn_display_policy_allows` | `display_policies`, `display_policy_rules` | Neither table's RLS may call `fn_display_policy_allows`; use role-based checks only |
| 3 | `fn_has_contest_standing` | `contest_records` + any contested table | `contest_records` RLS SELECT policy may not call `fn_has_contest_standing` for LifeBook-scope check; use `fn_lb_membership_role` instead. The contested record table itself (e.g., `claims`) must not call `fn_has_contest_standing` in its own RLS. |

These constraints must be verified during SQL authoring by reading each RLS policy on the affected tables and confirming the call chain is acyclic.

---

## Pre-Deployment Audit Requirement

`fn_generate_artifact_signed_url` (function 9) must be audited independently before production deployment. The audit must confirm:

1. Every code path that does not produce a URL returns NULL, not an error with policy details
2. `object_key` does not appear in any return value, error message, or log entry
3. All five policy checks (membership, access_classification, culturally_governed, DisplayPolicy, ai_generation context) are evaluated sequentially and all must pass before URL generation proceeds
4. The function is VOLATILE and generates URLs with appropriate expiry
5. The function is not callable from any publicly accessible API endpoint without authentication

---

## Status

All 9 helper functions reviewed. 8 require SECURITY DEFINER. Mitigations are specified. No function was rejected — all 8 SECURITY DEFINER uses are justified and alternatives were considered and rejected.

The SECURITY DEFINER review is complete. SQL authoring of helper functions may proceed subject to the constraints in this document.
