# VALIDATION_LESSONS_LEARNED.md
## LifeBook HQ — M0004 Remediation Validation Post-Mortem
**Status:** Final  
**Date:** 2026-07-27  
**Scope:** D-002, D-003, D-004 defects identified in M0004_VALIDATION_REPORT.md  
**Author:** LifeBook HQ — post-remediation documentation

---

## Purpose

This document records what the M0004 validation cycle taught us about testing SECURITY DEFINER governance functions, RLS policy interactions, and view security in PostgreSQL 17.6 on Supabase. The goal is to prevent recurrence of the same defect classes in future migrations.

Each lesson is stated as a concrete rule, not a general observation.

---

## Lesson 1 — Test governance functions in authenticated sessions, not as postgres

**Defect class:** D-002 (governance_functions privilege chain failure)

**What happened:** The five M0003 SECURITY DEFINER functions (fn_lb_membership_role, fn_is_subject_of, fn_has_active_authority, fn_has_source_access_grant, fn_has_contest_standing) all appeared to work correctly during initial validation because they were tested by running queries as postgres (rolsuper=FALSE but rolbypassrls=TRUE via role membership). postgres bypasses RLS and has implicit access to most objects via superuser-adjacent privilege. The functions were never exercised from within an authenticated session with a real JWT context.

**Root cause stack:**
1. `auth.uid()` reads `request.jwt.claim.sub` GUC, which is only populated when the Supabase PostgREST layer sets it. In direct SQL sessions it returns NULL.
2. governance_functions had no GRANT USAGE on the auth schema (owned by supabase_admin; postgres cannot grant what it does not hold with GRANT OPTION).
3. governance_functions had no SELECT on any of the lookup tables its functions query.
4. governance_functions had no BYPASSRLS — so even if #3 were fixed, authenticated-role RLS would fire against governance_functions queries and potentially recurse.

**The fix:**
- Replace `auth.uid()` with direct GUC reads (`current_setting('request.jwt.claim.sub', true)`) in all affected functions. This eliminates the auth schema dependency.
- `ALTER ROLE governance_functions BYPASSRLS` — postgres has CREATEROLE which is sufficient.
- `GRANT SELECT ON TABLE <all lookup tables> TO governance_functions`.

**Rule for future migrations:**
> All SECURITY DEFINER functions owned by governance_functions must be tested inside a `BEGIN; SET LOCAL role = authenticated; SET LOCAL "request.jwt.claims" = ...` block before the migration is submitted for DP review. A function that passes as postgres but fails as authenticated is broken. Test the actual execution path.

---

## Lesson 2 — Denormalize lifebook_id rather than resolve it via subquery in RLS policies

**Defect class:** D-003 (circular RLS between conversation_threads and thread_obligations)

**What happened:** pol_threads_select_contributor used an EXISTS subquery on thread_obligations. pol_obligations_select_steward resolved lifebook_id via `(SELECT lifebook_id FROM conversation_threads WHERE id = thread_obligations.thread_id)`. When an authenticated user queries conversation_threads, PostgreSQL fires thread RLS → queries thread_obligations → fires obligation RLS → queries conversation_threads → infinite recursion (error 42P17).

**The fix:**
- Add a denormalized `lifebook_id` column (NOT NULL, FK to lifebooks) to thread_obligations at DDL time.
- Rewrite all thread_obligations RLS policies to use `fn_lb_membership_role(lifebook_id)` directly — no subquery on conversation_threads.
- Create `fn_thread_has_active_invitation(p_thread_id UUID)` as SECURITY DEFINER owned by governance_functions (BYPASSRLS). pol_threads_select_contributor calls this function instead of an inline EXISTS.
- Add pol_obligations_select_governance_functions as a defence-in-depth backstop.

**Rule for future migrations:**
> Any RLS policy that resolves a foreign key via subquery on a table that itself has RLS policies creates a potential circular dependency. When a new table has an FK to an existing RLS-protected table, ask: does the existing table's RLS query back to the new table? If yes, denormalize the FK column or use a SECURITY DEFINER function. Never rely on PostgreSQL to detect the cycle at authoring time — it only raises 42P17 at runtime.

**Corollary:**
> thread_obligations.lifebook_id must be populated on INSERT by the application layer or a trigger. A NOT NULL FK that is never explicitly set will fail silently if the application omits it. Document this at the API layer.

---

## Lesson 3 — Always set security_invoker = true on views that depend on RLS

**Defect class:** D-004 (contributor_thread_view bypassed RLS via owner BYPASSRLS)

**What happened:** contributor_thread_view was owned by postgres. In PostgreSQL 15+, views owned by a role with rolbypassrls=true execute their underlying queries as that role. postgres has rolbypassrls=true (as a Supabase-granted privilege). Without security_invoker, querying contributor_thread_view as an authenticated contributor bypassed all RLS on conversation_threads — every row was visible regardless of pol_threads_select_contributor.

**The fix:**
- `CREATE VIEW contributor_thread_view WITH (security_invoker = true) AS ...`
- This causes the view to evaluate RLS as the querying user (the contributor), not as the view owner.

**Rule for future migrations:**
> Any view that is intended to provide row-filtered access to a table with RLS policies must include `WITH (security_invoker = true)` in its CREATE VIEW statement. This is not optional — omitting it produces a view that silently leaks rows to any user who can query it, regardless of RLS. This applies to all views in public schema on Supabase, where the view owner is postgres (rolbypassrls=true).

**Corollary:**
> This defect is invisible in standard structural validation (V checks). It only manifests in authenticated session testing. The C-test suite (role-bound sessions with JWT simulation) is the only validation path that would have caught it. Always include contributor/agent authenticated session tests in the validation matrix.

---

## Lesson 4 — Validate auth schema access separately from functional testing

**Defect class:** D-002 (auth schema privilege chain — silent GRANT failure)

**What happened:** `GRANT USAGE ON SCHEMA auth TO governance_functions` was issued and appeared to succeed (returned no error, returned `[]`). `has_schema_privilege('governance_functions', 'auth', 'usage')` returned false. The GRANT silently had no effect.

**Root cause:** The auth schema is owned by supabase_admin (rolsuper=true). postgres has USAGE on auth only via its membership in the authenticated role — not via a direct GRANT with GRANT OPTION. A role without GRANT OPTION cannot re-grant a privilege it received via role inheritance. PostgreSQL does not raise an error for a GRANT that has no effect.

**Rule for future migrations:**
> Never assume a GRANT succeeded because it raised no error. Always verify privilege grants with `has_schema_privilege()`, `has_table_privilege()`, or `has_function_privilege()` immediately after issuing them. Supabase's auth schema has a non-obvious ownership chain. Do not attempt to GRANT auth schema access to governance_functions or any non-superuser custom role — instead, replace auth.uid() calls with direct GUC reads.

---

## Lesson 5 — The C-test suite is mandatory, not optional

**What the original M0004 validation missed:** The V1–V15 structural checks confirmed objects existed and had correct counts, types, and owners. They said nothing about whether the functions actually worked when called by the authenticated role. D-002, D-003, and D-004 were all completely invisible to structural validation. All three defects were caught only by the C1–C6 authenticated session tests.

**Rule for future migrations:**
> The validation matrix for any migration that touches governance_functions, RLS policies, or views must include authenticated session tests (equivalent to C1–C6). Structural validation alone is insufficient. Minimum test matrix for a migration containing SECURITY DEFINER functions and RLS policies:
> 1. Structural checks (V series) — confirm objects exist and have correct properties
> 2. Trigger behavioral tests (V11/V12 equivalent) — confirm trigger logic fires correctly
> 3. Authenticated session tests (C series) — confirm RLS boundaries hold under real role contexts
> 4. Regression checks (R series) — confirm no prior baseline was disrupted

---

## Summary of Defect Root Causes

| Defect | Root Cause | Missed By | Caught By |
|--------|-----------|-----------|-----------|
| D-002 | governance_functions lacked auth.uid() substitution, BYPASSRLS, and table SELECT grants | V1–V15 | C1 (permission denied at runtime) |
| D-003 | Circular RLS via cross-table subqueries; no denormalized lifebook_id | V1–V15 | C2/C3 (42P17 infinite recursion) |
| D-004 | contributor_thread_view missing security_invoker; postgres owner has BYPASSRLS | V1–V15, V13 column check | C1 (contributor saw all rows) |

---

## Remediation Outcome

All three defects were resolved as a single remediation set per DP instruction. Post-remediation validation:
- V1–V15: All pass
- V11–V12: Trigger behavioral tests pass (steward_direct → steward_reviewed; ai_assisted → pending)
- D-002/D-003/D-004 specific checks: All pass
- C1–C6: All authenticated boundary tests pass
- R1–R5: All regression tests pass
- Total policy count: 127 (110 M0003 + 17 M0004, including D-003 governance_functions backstop)
- Total table count: 93 (89 M0003 + 4 M0004)

Commit hash: c5af501 — M0004 remediation + KNOWLEDGE_ARCHITECTURE.md

---

*VALIDATION_LESSONS_LEARNED.md — LifeBook HQ — Final — 2026-07-27*
