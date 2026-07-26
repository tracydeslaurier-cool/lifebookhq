# Legacy Role Audit — lifebook_app and lifebook_keeper
## LifeBook HQ — Production Project qrdoebsoviksdaxnjyak

**Audit date:** 2026-07-26  
**Method:** Read-only pg_catalog queries. No modifications made.  
**Scope:** Roles `lifebook_app` and `lifebook_keeper` in the production Supabase project.

---

## 1. Core Attributes

| Attribute        | lifebook_app | lifebook_keeper |
|---|---|---|
| OID              | 17815        | 17817           |
| LOGIN            | **true**     | **true**        |
| SUPERUSER        | false        | false           |
| INHERIT          | true         | true            |
| CREATEROLE       | false        | false           |
| CREATEDB         | false        | false           |
| REPLICATION      | false        | false           |
| BYPASSRLS        | false        | false           |
| CONNLIMIT        | -1 (unlimited) | -1 (unlimited) |
| VALID_UNTIL      | null         | null            |
| Password hash    | Not retrieved — not relevant to audit |

**No elevated capabilities.** Neither role is a superuser, has replication rights, or bypasses RLS. Both are standard login roles with no expiry and no connection limit.

---

## 2. Memberships

### 2a. Roles granted TO each role (what they are members of)

| Role | Member of |
|---|---|
| lifebook_app | (none) |
| lifebook_keeper | (none) |

Neither role inherits privileges from any group role. They hold their privileges as direct explicit grants only.

### 2b. Roles/users that are members of lifebook_app or lifebook_keeper

| Parent role | Member | admin_option |
|---|---|---|
| lifebook_app | postgres | false (member) |
| lifebook_app | postgres | true (administrator) |
| lifebook_keeper | postgres | false (member) |
| lifebook_keeper | postgres | true (administrator) |

Only `postgres` is a member of either role. The duplicate entries (member + administrator) reflect PostgreSQL 16+ membership model where admin rights are tracked separately. In practice: `postgres` can SET ROLE to either role and can grant/revoke membership in each. No application user or other service role is a member.

---

## 3. Object Ownership

**No objects owned by either role** — confirmed across tables, sequences, schemas, views, functions, and types.

All four non-platform schemas (audit, entrusted, identity, provisional) are owned by `postgres`, not by either legacy role.

---

## 4. Explicit Table Privileges

### lifebook_app

| Schema | Table | Privileges |
|---|---|---|
| audit | access_event | SELECT, INSERT |
| audit | deletion_event | SELECT, INSERT |
| audit | experiment_event | SELECT, INSERT |
| audit | session_recording | SELECT, INSERT |
| entrusted | companion_turn | SELECT, INSERT |
| entrusted | conversation | SELECT, INSERT |
| entrusted | moment | SELECT, INSERT |
| identity | book | SELECT, INSERT, UPDATE |
| identity | book_claim | SELECT, INSERT, UPDATE |
| identity | contributor | SELECT, INSERT, UPDATE |
| identity | credential | SELECT, INSERT, UPDATE |
| identity | session | SELECT, INSERT, UPDATE |
| identity | session_book | SELECT, INSERT, UPDATE |
| identity | signin_token | SELECT, INSERT, UPDATE |
| identity | storykeeper | SELECT, INSERT, UPDATE |
| provisional | draft_contribution | SELECT, INSERT, UPDATE, DELETE |

### lifebook_keeper

| Schema | Table | Privileges |
|---|---|---|
| audit | access_event | SELECT, INSERT |
| audit | deletion_event | SELECT, INSERT |
| entrusted | companion_turn | SELECT, DELETE |
| entrusted | conversation | SELECT, DELETE |
| entrusted | moment | SELECT, DELETE |
| identity | book | SELECT, INSERT, UPDATE, DELETE |
| identity | book_claim | SELECT, INSERT, UPDATE, DELETE |
| identity | contributor | SELECT, INSERT, UPDATE, DELETE |
| identity | credential | SELECT, INSERT, UPDATE, DELETE |
| identity | session | SELECT, INSERT, UPDATE, DELETE |
| identity | session_book | SELECT, INSERT, UPDATE, DELETE |
| identity | signin_token | SELECT, INSERT, UPDATE, DELETE |
| identity | storykeeper | SELECT, INSERT, UPDATE, DELETE |
| provisional | draft_contribution | SELECT, DELETE |

**Neither role has any privileges in the `public` schema.** All privileges are scoped exclusively to the prototype schemas (audit, entrusted, identity, provisional).

**No function privileges** were found for either role.

---

## 5. Default Privileges

`postgres` has configured `ALTER DEFAULT PRIVILEGES` for `lifebook_app` on the prototype schemas:

| Schema | Object type | Default grant to lifebook_app |
|---|---|---|
| identity | tables | INSERT, SELECT, UPDATE (arw) |
| entrusted | tables | INSERT, SELECT (ar) |
| provisional | tables | INSERT, SELECT, UPDATE, DELETE (arwd) |
| audit | tables | INSERT, SELECT (ar) |

This means any new tables created by `postgres` in these schemas will automatically grant the listed privileges to `lifebook_app`. No default privileges are configured for `lifebook_keeper`.

---

## 6. Schema Inventory and Context

The production database contains four non-platform schemas with no migration ownership:

| Schema | Owner | Tables | Purpose (inferred) |
|---|---|---|---|
| audit | postgres | access_event, deletion_event, experiment_event, session_recording | Event logging for prototype application |
| entrusted | postgres | companion_turn, conversation, moment | AI companion conversation storage |
| identity | postgres | book, book_claim, contributor, credential, session, session_book, signin_token, storykeeper | User identity and session management |
| provisional | postgres | draft_contribution | Draft/temporary content storage |

These schemas represent a **prior prototype application** deployed directly to the production Supabase project outside the LifeBook migration system. They are structurally unrelated to the LifeBook governed schema being built in the `public` schema.

---

## 7. RLS Consequences

| Question | lifebook_app | lifebook_keeper |
|---|---|---|
| Bypasses RLS? | No (BYPASSRLS=false) | No (BYPASSRLS=false) |
| Owns tables in public schema? | No | No |
| Owns tables in prototype schemas? | No (postgres owns) | No (postgres owns) |
| Could trigger FORCE ROW LEVEL SECURITY concern? | No — does not own objects | No — does not own objects |
| Privileges overlap with proposed service roles? | See §8 | See §8 |
| Could safely become a member of a group role? | Yes, with DP approval | Yes, with DP approval |

---

## 8. Relationship to Proposed LifeBook Service Roles

The proposed LifeBook group roles operate exclusively in the `public` schema. The legacy login roles hold no privileges in `public`. There is no privilege overlap.

| Proposed role | Scope | Legacy role active in same scope? |
|---|---|---|
| agent_service | public schema tables | No |
| system_service | public schema tables | No |
| admin | public schema tables | No |
| governance_functions | public schema function ownership | No |

**Do not map:**
- `lifebook_app` → `agent_service` — no evidence of agent use
- `lifebook_keeper` → `system_service` — no evidence of system service use

Any mapping requires explicit DP approval based on confirmed application architecture.

---

## 9. Classification

| Role | Classification | Rationale |
|---|---|---|
| **lifebook_app** | **Active application login** | LOGIN=true, explicit table privileges across all prototype schemas, default privileges configured, SELECT+INSERT on audit/entrusted/identity tables consistent with a read-write application tier |
| **lifebook_keeper** | **Active application login — elevated** | LOGIN=true, broader privileges including DELETE on identity and entrusted tables, consistent with an administrative or data-management tier of the same prototype application |

Neither role is a migration/deployment login. Neither is obsolete based on available evidence. Both are active credentials for the running prototype application.

---

## 10. Recommendations

### lifebook_app

**Recommendation: Retain unchanged. Document as prototype application credential.**

- Do not alter privileges.
- Do not rename.
- Do not add to LifeBook group roles until the prototype schema and the governed schema are formally reconciled.
- Document in a deployment runbook as: *"Active login credential for the LifeBook prototype application. Operates in audit/entrusted/identity/provisional schemas only. No privileges in the public governed schema."*

### lifebook_keeper

**Recommendation: Retain unchanged. Document as prototype administrative credential.**

- Do not alter privileges.
- Do not rename.
- Do not add to LifeBook group roles.
- Document in a deployment runbook as: *"Active login credential for prototype administrative operations (DELETE-capable). Operates in audit/entrusted/identity/provisional schemas only. No privileges in the public governed schema."*

---

## 11. Canonical Role Model (as established by this audit)

```
Login roles (hold credentials, environment-specific):
  lifebook_app      — prototype application tier (audit/identity/entrusted/provisional)
  lifebook_keeper   — prototype admin tier (same schemas, DELETE-capable)
  [future]          — LifeBook governed schema application credentials (not yet created)

Privilege roles (NOLOGIN, migration-owned, public schema):
  agent_service         — AI agent tier read/write (Migration 20260726083202)
  system_service        — internal service tier (Migration 20260726083202)
  admin                 — administrative read-all (Migration 20260726083202)
  governance_functions  — SECURITY DEFINER function ownership (Migration 20260726083202)
```

Login identities for the LifeBook governed schema have not yet been provisioned. When they are, they should receive privileges through membership in the appropriate group role, not through direct grants. That provisioning is outside the migration system and requires a separate DP decision on naming, attributes, and scope.

---

## 12. Pre-Production Deployment Checklist

Before applying Migration 20260726083202 to the production project:

```sql
-- Run this pre-flight query. Expected result: 0 rows.
SELECT rolname, rolcanlogin, rolsuper, rolbypassrls
FROM pg_roles
WHERE rolname IN ('agent_service','system_service','admin','governance_functions');
```

If any row is returned, stop. Do not apply the migration. Investigate whether the role was created manually, what attributes it has, and whether it is safe to proceed.

---

*LEGACY_ROLE_AUDIT.md — LifeBook HQ — 2026-07-26*
