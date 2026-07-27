# INCIDENT_REPORT_gunkacvftnvwxcppqvxr.md
## LifeBook HQ — Migration History Inconsistency: Disposable Project gunkacvftnvwxcppqvxr

**Incident detected:** 2026-07-26  
**Reported by:** Discovery Partner  
**Status:** CLOSED — project paused, fresh project provisioned  
**Successor project:** `iximbhwsjmppsdiwdixl` (lifebook-disposable-3)

---

## 1. Incident Summary

CLI `supabase migration list` on disposable project `gunkacvftnvwxcppqvxr` revealed that
all four local migration version numbers (filename-derived) were absent from the remote
`schema_migrations` table. Three remote-only versions were present with timestamps that
did not correspond to any local migration filename.

The DP halted before executing `supabase db push` per the runbook stop condition.

No schema corruption occurred. M0003 was not applied at all. The inconsistency was
purely in the version field of `schema_migrations`, caused by a known behavioral
difference between the MCP `apply_migration` tool and the Supabase CLI.

---

## 2. Root Cause

The Supabase MCP `apply_migration` tool sets the `version` field in
`supabase_migrations.schema_migrations` to the **UTC timestamp of application**, not to
the migration filename prefix.

The Supabase CLI (`supabase db push`) sets `version` to the **filename timestamp prefix**
(e.g., `20260724153745`).

Because M0001, M0002, and M0002b were applied via MCP in a prior session, their
recorded versions are the MCP application times. The CLI sees these as unrecognised
remote versions with no matching local migration — a migration-history inconsistency
that cannot be resolved without either:
- Manipulating `schema_migrations` (prohibited by DP instruction), or
- Abandoning the project (DP decision).

---

## 3. Evidence — Preserved from gunkacvftnvwxcppqvxr

### 3.1 Project Identity

| Field | Value |
|---|---|
| Project ref | `gunkacvftnvwxcppqvxr` |
| Project name | lifebook-disposable-2 |
| Region | ca-central-1 |
| PostgreSQL version | 17.6 (x86_64-pc-linux-gnu, gcc 15.2.0, 64-bit) |
| Project status at evidence capture | ACTIVE_HEALTHY |
| Project status after DP decision | PAUSING (paused via MCP) |
| Created | 2026-07-26T17:48:33Z |
| Evidence captured | 2026-07-27T02:33Z (UTC) |

### 3.2 Exact Migration History Rows

| version | name | created_by |
|---------|------|-----------|
| `20260726213053` | `20260724153745_types_and_vocabularies` | tracy@cooltechshit.ca |
| `20260726213218` | `20260726083201_predicate_governance_types` | tracy@cooltechshit.ca |
| `20260726213248` | `20260726083202_application_roles` | tracy@cooltechshit.ca |

**Columns confirmed in schema_migrations:** `version`, `statements`, `name`, `created_by`,
`idempotency_key`, `rollback`

**Local migration versions (filename-derived) that were absent from remote:**
- `20260724153745` — types_and_vocabularies
- `20260726083201` — predicate_governance_types
- `20260726083202` — application_roles
- `20260726083203` — core_schema

### 3.3 Object Catalogue — What Each Remote Migration Created

The `name` field in `schema_migrations` correctly identifies which migration content
was applied, even though the version numbers are wrong.

| Remote version | Corresponds to | Objects created |
|---|---|---|
| `20260726213053` | M0001 (types_and_vocabularies) | 39 enum types, 39 reference tables (40 rows incl. display_contexts overlap) |
| `20260726213218` | M0002 (predicate_governance_types) | 3 enum types (relationship_interaction_type, display_policy_status, display_policy_decision); display_contexts table + 9 seed rows |
| `20260726213248` | M0002b (application_roles) | 4 NOLOGIN roles: agent_service, system_service, admin, governance_functions |

**Object counts confirmed by direct query:**

| Object type | Count | Expected | Match |
|---|---|---|---|
| Public BASE TABLEs | 40 | 40 (39 M0001 + 1 M0002) | ✓ |
| Public enum types | 42 | 42 (39 M0001 + 3 M0002) | ✓ |
| Custom roles | 4 | 4 (M0002b) | ✓ |
| Helper functions (fn\_) | 0 | 0 (M0003 not applied) | ✓ |
| Triggers | 0 | 0 (M0003 not applied) | ✓ |
| RLS policies | 39 | 39 (M0001 vocabulary table policies) | ✓ |
| M0003 core tables present | 0 | 0 (M0003 not applied) | ✓ |

### 3.4 M0003 Application Status

**M0003 (`20260726083203_core_schema`) was NEVER applied to `gunkacvftnvwxcppqvxr`.**

Direct confirmation: query for 24 core schema tables (entities, persons, claims,
relationships, narratives, sources, artifacts, events, approval_records,
authority_assignments, contest_records, person_names, person_pronouns,
person_gender_descriptors, and others) returned 0 rows.

The version mismatch was detected before `supabase db push` was executed.
No partial application occurred.

### 3.5 Production Confirmation

Production project `qrdoebsoviksdaxnjyak` (LifeBookHQ, ca-central-1) was queried
directly during evidence capture.

**Production migration history:**

| version | name |
|---|---|
| `20260724153745` | `types_and_vocabularies` |

Production contains exactly one migration. M0002, M0002b, and M0003 have NOT been
applied to production. Production is unaffected by this incident.

---

## 4. Disposal

The MCP `apply_migration` tool does not generate version numbers compatible with
the Supabase CLI. Continuing to apply migrations via MCP to this project would
permanently corrupt the migration history from the CLI's perspective, because no
mechanism exists to retroactively correct version numbers without directly editing
`schema_migrations` (prohibited).

**Action taken:** Project `gunkacvftnvwxcppqvxr` paused via MCP `pause_project`.

**Note on full deletion:** The MCP tooling does not expose a `delete_project`
endpoint. Full deletion of `gunkacvftnvwxcppqvxr` must be performed manually
through the Supabase Dashboard at https://supabase.com/dashboard/project/gunkacvftnvwxcppqvxr.
The project contains no sensitive data — all content is reproducible from committed
migration files.

---

## 5. Contributing Factors

| Factor | Description |
|---|---|
| MCP version-stamp behavior | `apply_migration` uses current-time UTC as `version`, not the filename prefix. This is undocumented behavior discovered through CLI mismatch. |
| Tooling incompatibility | MCP and CLI write to the same `schema_migrations` table but use incompatible `version` strategies. |
| Prior session context loss | M0001–M0002b were applied via MCP in an earlier session before the version-stamp behavior was understood. |
| No pre-CLI state check | The approved runbook (Step 3) required verifying migration status before push, which correctly surfaced the inconsistency. The stop condition worked as designed. |

---

## 6. Corrective Action

Per DP Decision 2026-07-26:

1. **Fresh project provisioned:** `iximbhwsjmppsdiwdixl` (lifebook-disposable-3),
   ca-central-1, PostgreSQL 17.6, organisation `zetfgvdfonhkwyeozqjo` (LifeBookHQ).

2. **Pre-flight passed:** All four checks confirm clean state:
   - `supabase_migrations.schema_migrations` does not exist (expected — no migrations yet)
   - Public tables: 0
   - Custom roles: 0
   - Public enum types: 0

3. **CLI-only execution required:** All four migrations must be applied through
   `supabase db push` only. The MCP `apply_migration` tool must NOT be used for any
   migration on this project. This ensures CLI-compatible `version` values in
   `schema_migrations`.

4. **Updated runbook target:** The `LIVE_EXECUTION_RUNBOOK.md` link step must use
   `--project-ref iximbhwsjmppsdiwdixl`.

---

## 7. Updated Runbook Diff

The `LIVE_EXECUTION_RUNBOOK.md` requires one change: the project ref in Step 2.

**Step 2 — old:**
```bash
supabase link --project-ref gunkacvftnvwxcppqvxr
```

**Step 2 — new:**
```bash
supabase link --project-ref iximbhwsjmppsdiwdixl
```

All other runbook steps, validation queries, expected outputs, and rollback guidance
remain unchanged.

---

## 8. Lessons Learned

The MCP `apply_migration` tool and the Supabase CLI are **not interchangeable** for
migration history purposes. Any project whose migration history is seeded via MCP cannot
subsequently be managed by the CLI without version-number conflicts. For all future
LifeBook disposable validation projects:

- Apply migrations via CLI only (`supabase db push`), or
- Apply migrations via MCP only (for MCP-only validation workflows).

Never mix both tools on the same project's migration history.

---

*End of INCIDENT_REPORT_gunkacvftnvwxcppqvxr.md*
