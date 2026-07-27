# M0004 Validation Report
**Migration:** `20260727120000_conversation_threading.sql`
**Disposable project:** `iximbhwsjmppsdiwdixl`
**PostgreSQL version:** 17.6
**Validated:** 2026-07-27
**Status: VALIDATION INCOMPLETE — three defects require remediation before Phase 0 can be accepted**

---

## 1. Passed Tests

### V1–V15: Embedded Validation Queries (All Pass)
All 15 queries embedded in M0004 passed against the disposable project after the full migration chain (M0001 → M0002 → M0002b → M0003 → M0004) was applied.

| Check | Result |
|---|---|
| V1: conversation_threads table exists | PASS |
| V2: thread_obligations table exists | PASS |
| V3: context_manifests table exists | PASS |
| V4: storage_providers table exists | PASS |
| V5: All 4 new tables have RLS enabled | PASS |
| V6: contributor_thread_view exists with 5 columns | PASS |
| V7: artifacts addendum columns present | PASS |
| V8: events addendum columns present | PASS |
| V9: storage_providers seed rows present | PASS |
| V10: context_manifests FK on artifacts | PASS |
| V11: trigger trg_event_review_status_auto_promote exists | PASS |
| V12: fn_thread_lookup_by_lifebook function exists | PASS |
| V13: conversation_threads RLS policies (all 5) | PASS |
| V14: thread_obligations RLS policies (all 4) | PASS |
| V15: governance_functions owns all fn_ and _fn_trg_ objects | PASS |

### R1–R3: Cumulative Regression Counts (All Pass)

| Check | Expected | Actual | Result |
|---|---|---|---|
| R1: Total public tables | 93 | 93 | PASS |
| R2: fn_* function count | 12 | 12 | PASS |
| R3: _fn_trg_* function count | 23 | 23 | PASS |

### R4–R5: Regression Discrepancies (Explained, Not Regressions)

**R4 — Trigger count:** `information_schema.triggers` returned 25; expected 23.
**Explanation:** `information_schema.triggers` emits one row per event per trigger. Two triggers are multi-event: `trg_claim_ai_provenance` (INSERT + UPDATE) and `trg_claim_numeric_unit_check` (INSERT + UPDATE). 23 pg_trigger rows + 2 extra event rows = 25 information_schema rows. No regression.

**R5 — RLS-enabled table count:** Got 68; expected 69 (65 M0003 baseline + 4 M0004).
**Explanation:** The M0003 baseline was 64 RLS-enabled tables, not 65. Confirmed: 93 total − 25 with `rowsecurity = FALSE` = 68. All 4 M0004 tables have RLS enabled (confirmed V5). The expected value was wrong. No regression.

### V11–V12: Trigger Behavioural Tests (Pass)

Both tests run via `BEGIN/INSERT/SELECT/ROLLBACK` to avoid persistent test data.

| Test | Input | Expected review_status | Actual | Result |
|---|---|---|---|---|
| V11: steward-authored event | `submission_origin = 'steward_direct'` | `steward_reviewed` | `steward_reviewed` | PASS |
| V12: AI-inferred event | `submission_origin = 'ai_assisted'` | `pending` | `pending` | PASS |

The `trg_event_review_status_auto_promote` trigger correctly implements Decision 5: only `steward_direct` events are auto-promoted; all AI-inferred events remain `pending` regardless of who initiated the session.

---

## 2. Defects Found

Three defects were discovered during contributor RLS boundary testing. All are described below with reproduction steps, root cause, and fix direction. **The migration has not been modified per DP instruction.**

---

### D-002 — `governance_functions` lacks USAGE on `auth` schema
**Origin:** M0003 (affects M0004)
**Severity:** Critical — entire RLS layer is non-functional from authenticated sessions

#### Observation
When an `authenticated` role session calls any `fn_*` SECURITY DEFINER function that internally invokes `auth.uid()`, the query fails:

```
ERROR: 42501: permission denied for schema auth
QUERY: SELECT membership_role FROM lifebook_memberships WHERE ... AND user_id = auth.uid()
CONTEXT: PL/pgSQL function fn_lb_membership_role(uuid) line 9 at SQL statement
```

#### Root Cause
Five functions created in M0003 are SECURITY DEFINER and owned by `governance_functions`:

- `fn_lb_membership_role`
- `fn_has_active_authority`
- `fn_has_contest_standing`
- `fn_has_source_access_grant`
- `fn_is_subject_of`

All five call `auth.uid()` within their bodies. SECURITY DEFINER functions execute with the function owner's privileges. `governance_functions` was never granted `USAGE` on the `auth` schema, so it cannot resolve the `auth.uid()` function at runtime.

Confirmed:
```sql
SELECT has_schema_privilege('governance_functions', 'auth', 'usage');
-- → false

SELECT has_schema_privilege('authenticated', 'auth', 'usage');
-- → true
```

`auth.uid()` is accessible to the `authenticated` role directly, but NOT when called from within a SECURITY DEFINER function owned by `governance_functions`.

#### Impact
All RLS policies across M0003 and M0004 that call `fn_lb_membership_role` or any other affected function are effectively broken when exercised from a live `authenticated` session. This was not detected in earlier M0003 validation because all prior RLS tests were run as `postgres` (service role), which bypasses RLS entirely.

#### Fix Direction
Two grants needed, either added to M0003 (preferred) or issued in a corrective addendum before M0004:
```sql
GRANT USAGE ON SCHEMA auth TO governance_functions;
GRANT EXECUTE ON FUNCTION auth.uid() TO governance_functions;
```

---

### D-003 — Circular RLS dependency between `conversation_threads` and `thread_obligations`
**Origin:** M0004
**Severity:** Critical — direct table access from `authenticated` sessions causes infinite recursion

#### Observation
When an `authenticated` role session directly queries `conversation_threads` or `thread_obligations`:

```
ERROR: 42P17: infinite recursion detected in policy for relation "conversation_threads"
ERROR: 42P17: infinite recursion detected in policy for relation "thread_obligations"
```

#### Root Cause
`pol_threads_select_contributor` on `conversation_threads` contains an EXISTS subquery against `thread_obligations`:

```sql
EXISTS (
    SELECT 1 FROM thread_obligations
     WHERE thread_id = conversation_threads.id
       AND obligation_type = 'invitation'
       AND obligation_state IN ('pending', 'offered')
)
```

`pol_obligations_select_steward` and `pol_obligations_update_steward_or_agent` on `thread_obligations` contain subqueries back into `conversation_threads`:

```sql
fn_lb_membership_role((SELECT conversation_threads.lifebook_id
                         FROM conversation_threads
                        WHERE conversation_threads.id = thread_obligations.thread_id))
```

This creates a cycle: any authenticated scan of `conversation_threads` triggers a scan of `thread_obligations`, which triggers a scan of `conversation_threads` → infinite recursion. PostgreSQL detects and aborts.

#### Fix Direction
The `thread_obligations` policies must be rewritten to obtain `lifebook_id` without querying `conversation_threads`. The cleanest solution is to add a `lifebook_id` column to `thread_obligations` (denormalized FK) and rewrite the policies to use `fn_lb_membership_role(lifebook_id)` directly:

```sql
ALTER TABLE thread_obligations ADD COLUMN lifebook_id UUID NOT NULL REFERENCES lifebooks(id);

-- Then rewrite:
pol_obligations_select_steward → fn_lb_membership_role(lifebook_id) = 'steward'
pol_obligations_update_steward_or_agent → fn_user_is_agent() OR fn_lb_membership_role(lifebook_id) = 'steward'
```

The `conversation_threads` contributor policy can remain as-is once D-002 is resolved and `pol_obligations_select_steward` no longer re-queries `conversation_threads`.

---

### D-004 — `contributor_thread_view` bypasses RLS due to superuser view ownership
**Origin:** M0004
**Severity:** Critical — contributors can read all threads through the view regardless of invitation status

#### Observation
When an `authenticated` role session queries `contributor_thread_view`, it returns ALL threads — including threads with no invitation obligation — instead of only threads where the contributor holds a pending or offered invitation:

```sql
-- As contributor bbb00000-...:
SELECT visible_thread_count FROM contributor_thread_view;
-- → 2   (both Thread A [invited] and Thread B [steward-only] visible)
-- Expected: 1 (Thread A only)
```

No error is raised. The RLS policies on `conversation_threads` are silently bypassed.

#### Root Cause
`contributor_thread_view` is owned by `postgres`. `postgres` has `rolbypassrls = true`.

```sql
SELECT c.relname, r.rolname AS owner
  FROM pg_class c JOIN pg_roles r ON r.oid = c.relowner ...
 WHERE c.relname = 'contributor_thread_view';
-- → owner: postgres

SELECT rolbypassrls FROM pg_roles WHERE rolname = 'postgres';
-- → true
```

In PostgreSQL 15+, views created without `security_invoker = true` use the view owner's security context for RLS evaluation. Since the view owner (`postgres`) has BYPASSRLS, no RLS policies are applied when any user queries the view. All rows are returned.

This is a known PostgreSQL behaviour: non-security-invoker views effectively inherit the row security posture of their owner. Because all Supabase migrations run as `postgres`, every view created by a migration inherits this bypass unless explicitly corrected.

#### Fix Direction
Recreate the view with `security_invoker = true` (available in PostgreSQL 15+, confirmed running 17.6):

```sql
CREATE OR REPLACE VIEW contributor_thread_view
WITH (security_invoker = true) AS
    SELECT ct.id, ct.lifebook_id, ct.topic_label, ct.thread_summary, ct.anchor_entity_id
    FROM conversation_threads ct;
```

**Note:** D-004 cannot be fixed in isolation. Once `security_invoker = true` is set, queries through the view will trigger the RLS policies on `conversation_threads` using the caller's identity. At that point, D-002 and D-003 must also be resolved or the view queries will fail with permission errors and infinite recursion respectively.

All three defects must be fixed together.

---

## 3. Remediation Scope

All three defects require migration-level fixes. None can be resolved at the application layer.

| Defect | Origin Migration | Fix Migration |
|---|---|---|
| D-002: governance_functions lacks auth schema USAGE | M0003 | M0003 correction or M0004b addendum |
| D-003: Circular RLS (conversation_threads ↔ thread_obligations) | M0004 | M0004 revision |
| D-004: contributor_thread_view missing security_invoker | M0004 | M0004 revision |

D-002's fix can be issued as a targeted addendum (a new migration that issues two GRANT statements), since M0003 is already deployed to the disposable project and modifying M0003 directly would require a full teardown and rebuild. D-003 and D-004 are M0004-internal and should be corrected in the M0004 file before M0004 is accepted.

---

## 4. Status Summary

| Area | Result |
|---|---|
| Schema objects (V1–V15) | ✓ PASS |
| Catalogue counts (R1–R3) | ✓ PASS |
| Count discrepancies (R4–R5) | ✓ EXPLAINED (not regressions) |
| Trigger behaviour (V11–V12) | ✓ PASS |
| Contributor RLS — view isolation | ✗ FAIL (D-004) |
| Contributor RLS — direct table block | ✗ FAIL (D-003) |
| Authenticated fn_ function execution | ✗ FAIL (D-002) |

**Phase 0 is not complete. The DP constraint remains in force: no frontend, API, orchestration, or Phase 1 implementation may begin until M0004 validation is formally accepted.**

---

## 5. What Passed That Matters

Despite the RLS failures, two architectural decisions introduced by M0004 are validated and correct:

1. The event auto-promote trigger correctly encodes Decision 5: `steward_direct` events auto-promote to `steward_reviewed`; AI-inferred events always remain `pending`. This boundary is structurally sound.

2. The contributor_thread_view correctly excludes `state` (per conformance review). The column restriction is enforced at the view definition level and will hold once ownership and security_invoker are corrected.

The defects are in the RLS plumbing, not in the architectural decisions. All three have clear, targeted fixes.
