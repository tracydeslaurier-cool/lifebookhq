# Post-Application Integrity Report
## LifeBook HQ — Migration Chain M0001 → M0002 → M0002b → M0003
**Project:** iximbhwsjmppsdiwdixl (disposable)
**Date:** 2026-07-26
**Phases completed:** 1 through 6
**Status: PASS WITH ONE DISCREPANCY — requires DP review before proceeding**

---

## Phase 1 — Migration History

All four migrations confirmed present and in correct order:

| Timestamp | File | Status |
|-----------|------|--------|
| 20260724153745 | 0001_types_and_vocabularies | ✓ |
| 20260726083201 | 0002_application_roles | ✓ |
| 20260726083202 | 0002b_display_contexts | ✓ |
| 20260726083203 | 0003_core_schema | ✓ |

**Phase 1: PASS**

---

## Phase 2 — Catalogue Integrity

### Object Counts

| Object type | Expected | Actual | Result |
|-------------|----------|--------|--------|
| ENUM types | 42 | 42 | ✓ PASS |
| Tables | 89 | 89 | ✓ PASS |
| Helper functions (fn_*) | 9 | 9 | ✓ PASS |
| Trigger functions (_fn_trg_*) | 22 | 22 | ✓ PASS |
| Triggers (distinct names) | 22 | 22 | ✓ PASS |
| Explicit indexes | 14 | 14 | ✓ PASS |
| RLS-enabled tables | 65 | 65 | ✓ PASS |
| RLS policies | 110 | 110 | ✓ PASS |
| Custom roles | 4 | 4 | ✓ PASS |
| Constraint triggers (deferrable) | 1 | 1 | ✓ PASS |
| **Deferrable FK constraints** | **4** | **0** | **⚠ DISCREPANCY** |

### RLS-Enabled Table Breakdown
65 tables confirmed (39 M0001 vocab + 1 M0002b display_contexts + 25 M0003 core tables). Breakdown is consistent with migration ownership matrix.

### RLS Policy Names
All 110 policies confirmed present. Both deferred policies (DEF-0004) confirmed in live catalogue:
- `pol_claims_ai_promotion_denied` on `claims` (UPDATE) ✓
- `pol_narratives_ai_promotion_denied` on `narratives` (UPDATE) ✓

### Custom Roles
All 4 confirmed with correct attributes:

| Role | rolcanlogin | rolsuper | rolcreaterole | rolcreatedb | rolbypassrls |
|------|-------------|----------|---------------|-------------|--------------|
| admin | false | false | false | false | false |
| agent_service | false | false | false | false | false |
| governance_functions | false | false | false | false | false |
| system_service | false | false | false | false | false |

### Seed Records
Total: **488** ✓

| Migration | Table(s) | Count |
|-----------|----------|-------|
| M0001 | 38 vocab tables + authority_context_policy_conditions | 345 |
| M0002b | display_contexts | 9 |
| M0003 | claim_predicates | 74 |
| M0003 | relationship_types | 27 |
| M0003 | agent_registry | 9 |
| M0003 | escalation_policies | 7 |
| M0003 | jurisdictions | 6 |
| M0003 | approval_policies | 5 |
| M0003 | conflict_resolution_policies | 4 |
| M0003 | context_profiles | 2 |
| **Total** | | **488** |

### D-001: Deferrable FK Constraints — RESOLVED

**Expected (runbook):** 4 DEFERRABLE FK constraints  
**Actual:** 0 SQL-DEFERRABLE FKs (condeferrable=false on all 4 ALTER TABLE FKs)

**Resolution (2026-07-26, DP Option A):** The 4 FKs added via ALTER TABLE in M0003 are "file-order deferred" (positioned after both referenced tables exist to resolve circular creation ordering). They are intentionally NOT SQL-DEFERRABLE. The runbook V6 query incorrectly expected `condeferrable=true`. The live database correctly reflects the design.

The 4 file-order ALTER TABLE FKs are confirmed present:
- `fk_authority_basis_claim`: authority_assignments.basis_claim_id → claims(id)
- `fk_display_policy_approval_record`: display_policies.approval_record_id → approval_records(id)
- `fk_permission_cache_approval_policy`: lifebook_person_contexts.permission_cache_policy_version_id → approval_policies(id)
- `fk_claims_context_manifest`: claims.context_manifest_id → context_manifests(id) (Addendum)

**Classification:** Specification drift — terminology confusion between "file-order deferred FK" (ALTER TABLE ordering) and "SQL-DEFERRABLE FK" (PostgreSQL DEFERRABLE clause). No schema correction required. LIVE_EXECUTION_RUNBOOK.md V6, FINAL_STATIC_VALIDATION_REPORT.md, and MIGRATION_PHILOSOPHY.md updated to disambiguate.

**Phase 2: PASS**

---

## Phase 3 — Ownership and Privilege Validation

### Table Ownership
All 89 tables: owned by `postgres` ✓

### Function Ownership

**fn_* helper functions (9 total):**

| Function | Owner | SECURITY DEFINER | search_path pinned |
|----------|-------|------------------|--------------------|
| fn_display_policy_allows | governance_functions | ✓ | ✓ |
| fn_generate_artifact_signed_url | governance_functions | ✓ | ✓ |
| fn_has_active_authority | governance_functions | ✓ | ✓ |
| fn_has_community_authorization | governance_functions | ✓ | ✓ |
| fn_has_contest_standing | governance_functions | ✓ | ✓ |
| fn_has_source_access_grant | governance_functions | ✓ | ✓ |
| fn_is_subject_of | governance_functions | ✓ | ✓ |
| fn_lb_membership_role | governance_functions | ✓ | ✓ |
| fn_user_is_agent | postgres | ✗ (by design) | n/a |

`fn_user_is_agent` is owned by `postgres` and is explicitly NOT SECURITY DEFINER. Migration comment at line 1235 states this is intentional: the function evaluates only JWT session state and requires no privileged table access. No `OWNER TO governance_functions` statement for this function exists anywhere in M0003, consistent with the design intent. No corrective action required.

**_fn_trg_* trigger functions (22 total):**
All 22 owned by `postgres` ✓ (trigger functions are not in the governance_functions ownership model).

### Privilege Leaks
`lifebook_app` and `lifebook_keeper`: **0 table privileges** in public schema ✓ — no leakage to legacy login roles.

**Phase 3: PASS**

---

## Phase 4 — SECURITY DEFINER Audit

9 SECURITY DEFINER functions confirmed. All have `search_path` pinned to `'public', 'pg_temp'` — no search_path injection risk.

| Function | Owner | Notes |
|----------|-------|-------|
| _fn_trg_claim_numeric_unit_check | postgres | Trigger; needs RLS bypass to read claim_value_units |
| fn_display_policy_allows | governance_functions | Stable; reads display_policies/rules |
| fn_generate_artifact_signed_url | governance_functions | Stub body; returns NULL |
| fn_has_active_authority | governance_functions | Stable; reads authority_assignments |
| fn_has_community_authorization | governance_functions | Stable; reads approval_records/policies |
| fn_has_contest_standing | governance_functions | Stable; dynamic SQL over whitelist |
| fn_has_source_access_grant | governance_functions | Stable; reads lifebook_source_access |
| fn_is_subject_of | governance_functions | Stable; reads user_person_links |
| fn_lb_membership_role | governance_functions | Stable; reads lifebook_memberships |

All 8 governance_functions-owned SECURITY DEFINER functions: search_path = `'public', 'pg_temp'` ✓  
`_fn_trg_claim_numeric_unit_check` (postgres-owned): search_path = `'public', 'pg_temp'` ✓

**Phase 4: PASS**

---

## Phase 5 — Boundary Checks

### claim_value_units (11 records)

| unit_code | unit_category | requires_qualifier | deprecated_at |
|-----------|---------------|--------------------|---------------|
| age_years | duration | false | null |
| day | duration | false | null |
| month | duration | false | null |
| year | duration | false | null |
| km | distance | false | null |
| mile | distance | false | null |
| acre | area | false | null |
| hectare | area | false | null |
| currency | currency | **true** | null |
| count | count | false | null |
| percentage | ratio | false | null |

11 records confirmed, 0 deprecated, `currency` correctly requires_qualifier=true (ISO 4217 code) ✓

### claims Table — Addendum Columns
All 5 Addendum columns confirmed present with correct types and defaults:

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| review_status | text | NOT NULL | 'pending' |
| submission_origin | text | NOT NULL | 'manual' |
| ai_generated | boolean | NOT NULL | false |
| producing_agent_code | text | nullable | — |
| context_manifest_id | uuid | nullable | — |

### narratives Table — Addendum Column
`review_status`: text, NOT NULL, default 'pending' ✓

**Phase 5: PASS**

---

## Phase 6 — W11 Validation

W11 describes the governance_functions ownership prerequisite chain.

| Check | Query | Result |
|-------|-------|--------|
| postgres is member of governance_functions | pg_has_role('postgres', 'governance_functions', 'MEMBER') | **true** ✓ |
| governance_functions has USAGE on public | has_schema_privilege(..., 'USAGE') | **true** ✓ |
| governance_functions has CREATE on public | has_schema_privilege(..., 'CREATE') | **true** ✓ |

Both prerequisites (DEF-0003 Part 1: role membership; DEF-0003 Part 2: schema CREATE) are satisfied in the live database. OWNER TO governance_functions succeeded for all 8 target functions.

**Phase 6: PASS**

---

## Overall Summary

| Phase | Description | Result |
|-------|-------------|--------|
| 1 | Migration history | ✓ PASS |
| 2 | Catalogue integrity | ⚠ PASS — D-001 pending DP review |
| 3 | Ownership and privilege | ✓ PASS |
| 4 | SECURITY DEFINER audit | ✓ PASS |
| 5 | Boundary checks | ✓ PASS |
| 6 | W11 validation | ✓ PASS |

### Discrepancy Register

| ID | Phase | Severity | Description | Action required |
|----|-------|----------|-------------|-----------------|
| D-001 | 2 | Medium | 0 deferrable FK constraints found; runbook expected 4. No DEFERRABLE keyword on any FK in any migration. | DP must confirm: (a) FKs intentionally non-deferrable → update runbook to 0; or (b) DDL omission → author corrective migration before production |

### Not Yet Executed (awaiting DP authorization)
- Trigger behavioural tests (trg_claim_numeric_unit_check 6 valid + 13 rejected)
- Deferred constraint tests (trg_lifebook_person_context_completeness)
- RLS matrix tests (role-by-role operational validation)
- Reproducibility rebuild (apply from zero, compare inventories)

---

*Report produced: 2026-07-26 | Disposable project: iximbhwsjmppsdiwdixl | M0003 SHA-256: 136b1f255b019ce97bbd7f62e868c0f411f941ebde1658a638d21d19276a54cc*
