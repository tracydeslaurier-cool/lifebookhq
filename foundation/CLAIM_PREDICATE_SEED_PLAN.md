# ClaimPredicate Seed Authoring Plan
**Version:** 0.3  
**Status:** DP decisions recorded — 4.1 and 4.2 approved with modifications; column names revised; vocabulary migration required; SQL NOT authorized  
**Produced:** 2026-07-25  
**Produced by:** Discovery Partner + Claude (architecture session)  
**Source of truth:** CLAIM_PREDICATE_CATALOGUE.md v0.2  
**Depends on:** ClaimValueUnit seed (authored first; predicates reference unit categories)  
**Delivers:** INSERT statements for `claim_predicates` table, embedded in migration 0003 (`<TIMESTAMP>_core_schema.sql`)

---

## 1. Scope

74 predicate records across 13 predicate families. All records are derived mechanically from CLAIM_PREDICATE_CATALOGUE.md v0.2. No new predicate may be added during seed authoring — predicate additions require a Discovery Partner review and a catalogue version bump before they appear in seed data.

The seed is authoritative at migration time. Any predicate not in the seed at migration application is not available as a valid `predicate_id` for Claim records.

---

## 2. Target Table Structure

The `claim_predicates` table will be created in migration 0003 (`<TIMESTAMP>_core_schema.sql`). Its columns, in seed-relevant order:

| Column | Type | Source in catalogue | Notes |
|---|---|---|---|
| `id` | UUID | Generated | `gen_random_uuid()` at INSERT time |
| `predicate_code` | Text | `predicate_code` | Machine identifier; immutable; unique constraint |
| `display_label` | Text | `label` | Human-readable; may be translated in a future migration |
| `description` | Text | `definition` | Full semantic definition |
| `permitted_subject_entity_types` | Array\<entity_type\> | `subject_types` | Validated against entity_type enum |
| `permitted_object_entity_types` | Array\<entity_type\> | `object_entity_types` | Nullable; only when range_type = entity |
| `permitted_value_type` | Enum | `range_type` | Maps catalogue range types to permitted_value_type enum values (see §4) |
| `inverse_predicate_id` | UUID FK | `inverse` | Self-referential; must be NULL at initial INSERT; updated in a second pass (see §6) |
| `is_symmetric` | Boolean | `symmetric` | `yes` → true; `no` → false |
| `is_transitive` | Boolean | `transitive` | `yes` → true; `no` → false |
| `temporal_allowed` | Boolean | `temporal` | `yes` → true; `no` → false |
| `deprecated_at` | Date | (none in current catalogue) | NULL for all v0.2 predicates |
| `replaced_by_predicate_id` | UUID FK | (none in current catalogue) | NULL for all v0.2 predicates |
| `numeric_unit_required` | Boolean | Derived (see §5) | True if range_type = numeric and the predicate requires a unit |
| `permitted_unit_categories` | Array\<Text\> | Derived (see §5) | Nullable |
| `permitted_unit_codes` | Array\<Text\> | Derived (see §5) | Nullable |
| `numeric_integer_only` | Boolean | Derived (see §5) | True for count predicates only |
| `numeric_min_value` | Decimal | Derived (see §5) | Nullable |
| `numeric_max_value` | Decimal | Derived (see §5) | Nullable |
| `created_at` | Timestamp | `NOW()` | Migration timestamp |
| `created_by_id` | UUID FK → user_profiles | NULL | Nullable for seed records; see §2.1 |
| `created_by_system` | Text | `'migration:<actual_core_schema_filename>'` | Non-null for seed records; see §2.1 |
| `relationship_interaction` | `relationship_interaction_type` enum | `relationship_interaction` | Governed predicate metadata; enum from migration 0002; see §2.2 |
| `default_access_classification` | access_classification enum | `default_access_classification` | Governed predicate metadata; see §2.2 |
| `generates_event_type` | Text FK → event_types(code) | `generates_event_type` | Governed predicate metadata; nullable FK to governed vocabulary; see §2.2 |

**Fields from the catalogue that remain documentation-only (not stored in DB):**

| Catalogue field | Disposition |
|---|---|
| `recommended_evidence` | Documentation only; not stored in the schema |
| `valid_example` / `invalid_example` / `notes` | Documentation only; not stored in the schema |

### 2.1 System-Seed Provenance Model — created_by_id / created_by_system
**Decision recorded 2026-07-25 (PRE_SQL_READINESS_REVIEW.md §4.1) — Approved with modification**

Reference and catalogue tables created by migration seed — `claim_predicates`, `claim_value_units`, `relationship_types`, `agent_registry`, and `context_profiles` — are governed catalogues, not user assertions. The `created_by_id` concept as it applies to user-created content does not apply to seed records authored by the migration itself.

**Approved model:**

Catalogue tables carry two companion provenance fields:
- `created_by_id` — nullable UUID FK → user_profiles. NULL for seed records.
- `created_by_system` — TEXT. Non-null for seed records; null for application-created records.

Seed records inserted by migration 0003 must carry:
```
created_by_id    = NULL
created_by_system = 'migration:<actual_core_schema_filename>'
```

Application-created records (e.g., a new predicate added by the team via the admin interface) must carry:
```
created_by_id    = <valid user_profiles UUID>
created_by_system = NULL
```

A CHECK constraint must enforce that at least one is non-null:
```sql
CHECK (created_by_id IS NOT NULL OR created_by_system IS NOT NULL)
```

This convention applies consistently to all seed tables in migration 0003: ClaimPredicate, ClaimValueUnit, RelationshipType, AgentRegistry, ContextProfile.

### 2.2 Governed Predicate Metadata Columns — relationship_interaction, default_access_classification, generates_event_type
**Decision recorded 2026-07-25 (PRE_SQL_READINESS_REVIEW.md §4.2) — Approved with modifications**

Storing these as governed, data-driven predicate metadata columns on `claim_predicates` is approved. Do not hard-code these behaviours in application logic.

**Approved column definitions (revised names):**

| Column | Type | Nullable | Values |
|---|---|---|---|
| `relationship_interaction` | `relationship_interaction_type` enum (from migration 0002) | NOT NULL | `proposes` / `supports` / `describes` / `none` |
| `default_access_classification` | `access_classification` enum (from migration 0001) | NOT NULL | Any valid `access_classification` value |
| `generates_event_type` | `TEXT REFERENCES event_types(code)` | Nullable | NULL = no event generated; non-null = governed `event_types.code` FK |

**`relationship_interaction_type` enum — vocabulary migration 0002 required:**

This is a new enum type not present in migration 0001. Per MIGRATION_PHILOSOPHY.md §8, it cannot be inserted into the applied migration. It must be introduced in a separate vocabulary migration before the core-schema migration:

- **Migration 0002 (`<TIMESTAMP>_predicate_governance_types.sql`):** Creates `relationship_interaction_type` enum with values `proposes | supports | describes | none`.
- **Migration 0003 (`<TIMESTAMP>_core_schema.sql`):** References the enum in `claim_predicates` DDL.

**`generates_event_type` — governed FK, not unrestricted text:**

`event_types` is a governed reference table created in migration 0001 with 21 seeded codes. The `generates_event_type` column is typed as `TEXT REFERENCES event_types(code)` (nullable FK). The governed vocabulary is `event_types.code` — unrestricted text is not approved for this column.

No circular dependency exists: `event_types` was created in 0001 and `claim_predicates` is created in 0003. The FK is straightforward.

**Seed records:** For predicates with no event generation, `generates_event_type = NULL`. For predicates that generate events (e.g., `married_to` → `marriage`, `born_on` → `birth`), the value must be a valid code from the `event_types` seed in migration 0001.

---

## 3. Predicate Families and Record Count

| Family | Name | Records |
|---|---|---|
| 1 | Identity and Naming | 4 |
| 2 | Vital Events | 17 |
| 3 | Residence and Location | 4 |
| 4 | Migration and Travel | 9 |
| 5 | Education | 4 |
| 6 | Employment and Occupation | 6 |
| 7 | Military Service | 6 |
| 8 | Organizational and Community Participation | 7 |
| 9 | Document Appearance | 3 |
| 10 | Property, Custody, and Ownership | 5 |
| 11 | Titles and Honours | 4 |
| 12 | Relationship Qualification | 3 |
| 13 | Source and Artifact Associations | 2 |
| **Total** | | **74** |

> **Note:** §3 was updated 2026-07-25 to match CLAIM_PREDICATE_CATALOGUE.md v0.2 (current). The family names and counts in the earlier draft of this plan were written against a superseded catalogue design and did not match the published catalogue.

---

## 4. Range Type → permitted_value_type Mapping

The catalogue's `range_type` field maps to the `permitted_value_type` enum as follows:

| Catalogue range_type | permitted_value_type enum value | Notes |
|---|---|---|
| `entity` | `entity` | |
| `date` | `date` | |
| `date_range` | `date` | `temporal_allowed = true` captures the range semantics |
| `text` | `text` | |
| `numeric` | `numeric` | Requires `numeric_unit_required` derivation (§5) |
| `boolean` | (see note) | No boolean predicates exist in v0.2 catalogue; if added, map to `text` with controlled_value |
| `controlled_value` | `text` | Controlled vocabulary constraint is application-layer; `text` is the stored type |

When `range_type = entity`, the `permitted_object_entity_types` array is populated from the catalogue's `object_entity_types` field. When `range_type` is any other value, `permitted_object_entity_types` is NULL.

---

## 5. Numeric Predicate Field Derivation

For each predicate where `permitted_value_type = numeric`, derive the following fields from the catalogue's notes and definition:

| Predicate pattern | `numeric_unit_required` | `permitted_unit_categories` | `numeric_integer_only` | `numeric_min_value` | `numeric_max_value` |
|---|---|---|---|---|---|
| Duration predicates (years of employment, years of membership, etc.) | true | `['duration']` | false | NULL | NULL |
| Distance predicates | true | `['distance']` | false | NULL | NULL |
| Age-at-event predicates | true | `['duration']` with permitted_unit_codes = `['age_years']` | false | 0 | NULL |
| Currency predicates | true | `['currency']` | false | NULL | NULL |
| Count predicates (number of children, etc.) | false (unitless) | NULL | true | 0 | NULL |
| Percentage predicates | true | `['ratio']` with permitted_unit_codes = `['percentage']` | false | 0 | 100 |

**For each numeric predicate in the catalogue:** review the definition and notes to confirm the correct derivation before writing the INSERT. Do not assume — check.

---

## 6. Inverse Predicate — Two-Pass Strategy

The `inverse_predicate_id` column is a self-referential FK. A predicate that is the inverse of another predicate cannot reference that predicate's UUID until both predicates exist.

**Two-pass authoring approach:**

**Pass 1 — Initial INSERT (inverse_predicate_id = NULL for all records):**
All 74 predicates are inserted with `inverse_predicate_id = NULL`. This satisfies FK constraints (the column is nullable).

**Pass 2 — UPDATE (set inverse_predicate_id where applicable):**
After all 74 records are inserted, a series of UPDATE statements sets `inverse_predicate_id` for each pair:

```sql
-- Pattern (not actual SQL — do not execute):
UPDATE claim_predicates
SET inverse_predicate_id = (SELECT id FROM claim_predicates WHERE predicate_code = 'inverse_code')
WHERE predicate_code = 'original_code';
```

**Pairs requiring inverse UPDATE:**
Review each predicate's `inverse` field in the catalogue. Pairs where `inverse ≠ none` require bidirectional UPDATEs (both predicates in the pair must be updated).

Catalogue v0.2 contains approximately 18 inverse pairs. The exact list must be compiled during Pass 1 authoring and confirmed against the catalogue before Pass 2 is written.

**Symmetric predicates:** When `is_symmetric = true`, the predicate is its own inverse (A→B implies B→A). For symmetric predicates, `inverse_predicate_id` should be set to the predicate's own `id`. This is not a FK constraint violation — the column simply points to itself. Confirm this with Discovery Partner before implementing.

---

## 7. Authoring Sequence Across Migrations

**Migration 0002 (`<TIMESTAMP>_predicate_governance_types.sql`) — vocabulary-only:**

1. `relationship_interaction_type` enum DDL: `CREATE TYPE relationship_interaction_type AS ENUM ('proposes', 'supports', 'describes', 'none');`

No tables, seed data, or constraints in this migration.

**Migration 0003 (`<TIMESTAMP>_core_schema.sql`) — predicate-relevant ordering:**

The predicate seed must appear at a specific point within the core-schema migration file:

1. `claim_predicates` table DDL — includes `relationship_interaction` (references `relationship_interaction_type` enum from 0002), `default_access_classification`, `generates_event_type` (FK → `event_types(code)` from 0001), `created_by_id` (nullable FK → user_profiles), `created_by_system` (TEXT NOT NULL for seed records via CHECK constraint)
2. `claim_value_units` table DDL and seed (ClaimValueUnit seed before ClaimPredicate seed — predicates reference unit categories)
3. ClaimPredicate seed — Pass 1 (all 74 records, `inverse_predicate_id = NULL`, `created_by_id = NULL`, `created_by_system = 'migration:<actual_core_schema_filename>'`)
4. ClaimPredicate seed — Pass 2 (UPDATE for inverse pairs)
5. `trg_claim_numeric_unit_check` trigger (must appear after both seed INSERT blocks in migration execution order)

This ordering must be respected. The trigger cannot be created before the seeds it validates against.

---

## 8. Quality Checks Before Final SQL

Before the seed INSERT statements are finalized, the following checks must be performed:

**Check 1 — Completeness:** Count of predicates in the seed equals 74. Any discrepancy is an error.

**Check 2 — Code uniqueness:** No two predicates share a `predicate_code`. Run a deduplication check against the catalogue list.

**Check 3 — Subject type validity:** All values in `permitted_subject_entity_types` arrays are valid `entity_type` enum values: `person / organization / place / vessel / community / event_series`. Any other value is an error.

**Check 4 — Object type validity (for entity predicates):** All values in `permitted_object_entity_types` arrays are valid `entity_type` enum values. Null for non-entity predicates.

**Check 5 — Inverse completeness:** Every predicate with `inverse ≠ none` in the catalogue has a corresponding UPDATE statement in Pass 2. No inverse references an undefined predicate code.

**Check 6 — Symmetric predicates:** All predicates where `is_symmetric = true` in the catalogue have `is_symmetric = true` in the seed. Confirmed against the catalogue list.

**Check 7 — Numeric unit derivation:** For all numeric predicates, the `numeric_unit_required` and `permitted_unit_categories` values are consistent with the CONTENT_LAYER.md §3.2.2 seed units. No predicate references a unit category that does not exist in the ClaimValueUnit seed.

**Check 8 — No catalogue drift:** The 74 predicate codes in the seed exactly match the 74 predicate codes in CLAIM_PREDICATE_CATALOGUE.md v0.2. No additions, no omissions, no substitutions. If the catalogue is revised between the start of authoring and the delivery of SQL, the seed must be re-derived from the updated catalogue.

**Check 9 — relationship_interaction completeness:** Every predicate record has a non-null `relationship_interaction` value. Valid values: `proposes`, `supports`, `describes`, `none`. Confirm each value against the catalogue's `relationship_interaction` field.

**Check 10 — default_access_classification completeness:** Every predicate record has a non-null `default_access_classification` value that is a valid `access_classification` enum value from migration 0001. Confirm against catalogue's `default_access_classification` field.

**Check 11 — generates_event_type validity:** For every predicate where the catalogue specifies a `generates_event_type` value other than null/none, the `generates_event_type` column in the seed carries a code that exists in the `event_types` reference table from migration 0001. For predicates with no event generation, the column is NULL. Confirm each non-null value against the 21 seeded `event_types.code` values.

**Check 12 — System-seed provenance fields:** All 74 seed records must carry `created_by_id = NULL` and `created_by_system = 'migration:<actual_core_schema_filename>'`. Any record with `created_by_id IS NOT NULL` or `created_by_system IS NULL` is an authoring error.

---

## 9. Predicate Code Reference List

The following 74 predicate codes must appear in the seed, grouped by family. This list is the authoritative check against the catalogue during authoring. Do not add, remove, or rename any code without a Discovery Partner session and a catalogue version bump.

> **Note:** This list was updated 2026-07-25 to match CLAIM_PREDICATE_CATALOGUE.md v0.2 (current). The predicate codes in the earlier draft of this plan were written against a superseded catalogue design with a different family taxonomy and different predicate codes. The catalogue is the authoritative source.

**Family 1 — Identity and Naming (4):**
`has_name`, `also_known_as`, `founding_date_of`, `dissolution_date_of`

**Family 2 — Vital Events (17):**
`born_on`, `born_at`, `died_on`, `died_at`, `baptised_on`, `baptised_at`, `named_on`, `named_at`, `buried_on`, `buried_at`, `married_on`, `married_at`, `married_to`, `in_civil_partnership_with`, `naturalized_on`, `naturalized_at`, `adopted_on`

**Family 3 — Residence and Location (4):**
`resided_at`, `stayed_at`, `had_address`, `location_at_time`

**Family 4 — Migration and Travel (9):**
`emigrated_from`, `emigrated_on`, `immigrated_to`, `immigrated_on`, `departed_from`, `departed_on`, `arrived_at`, `arrived_on`, `travelled_on`

**Family 5 — Education (4):**
`enrolled_at`, `graduated_from`, `graduated_on`, `awarded_credential`

**Family 6 — Employment and Occupation (6):**
`employed_by`, `contracted_to`, `apprenticed_to`, `had_occupation`, `held_position`, `worked_at`

**Family 7 — Military Service (6):**
`served_in`, `enlisted_on`, `enlisted_at`, `discharged_on`, `held_rank`, `served_at`

**Family 8 — Organizational and Community Participation (7):**
`member_of`, `joined_on`, `left_on`, `associated_with`, `ordained_in`, `ordained_on`, `ordained_at`

**Family 9 — Document Appearance (3):**
`recorded_in`, `listed_as`, `documented_by`

**Family 10 — Property, Custody, and Ownership (5):**
`owned`, `possessed`, `held_title_to`, `custody_of`, `held_in_stewardship`

**Family 11 — Titles and Honours (4):**
`held_title`, `awarded_honour`, `awarded_on`, `appointed_to`

**Family 12 — Relationship Qualification (3):**
`relationship_commenced_on`, `relationship_ended_on`, `relationship_contested_on`

**Family 13 — Source and Artifact Associations (2):**
`depicted_in`, `attributed_to`

---

## 10. Authoring Work Estimate

| Task | Estimated records | Complexity |
|---|---|---|
| Pass 1 INSERTs — Family 1 | 2 | Low |
| Pass 1 INSERTs — Families 2–3 (relationships, life events) | 19 | Medium — entity predicates with object type arrays |
| Pass 1 INSERTs — Families 4–5 (places, organizations) | 11 | Low to medium |
| Pass 1 INSERTs — Families 6–7 (work, education) | 11 | Low to medium |
| Pass 1 INSERTs — Families 8–13 (social through military) | 31 | Low to medium |
| Pass 2 UPDATEs — inverse pairs | ~18 pairs | Low — mechanical |
| Numeric derivation review | ~8 predicates | Medium — requires catalogue review |
| Quality checks | — | Medium — requires careful comparison against catalogue |
| **Total** | **74 predicates** | **One dedicated authoring session** |

Estimated time for a focused authoring session: 2–3 hours, not including Discovery Partner review of the resulting SQL.

---

## 11. Relationship to Other Seed Authoring

The ClaimPredicate seed is the largest seed dataset in the core-schema migration (0003). The following smaller seeds do not require dedicated planning documents and may be authored inline during the migration session:

| Seed | Source | Records |
|---|---|---|
| ClaimValueUnit | CONTENT_LAYER.md §3.2.2 | 10 |
| RelationshipType | RELATIONSHIP_TYPE_CATALOGUE.md | 27 |
| Jurisdiction | OPERATIONAL_MODELS.md §4 | 6 minimum |
| AgentRegistry | AI_CONTEXT_BROKER.md §3.2 | ~6 |
| ContextProfile | AI_CONTEXT_BROKER.md | ~4 |
| Representative ApprovalPolicy | GOVERNANCE_MODELS.md §4.4 | ~13 |
| Representative ConflictResolutionPolicy | GOVERNANCE_MODELS.md §5.5 | ~11 |
| Representative EscalationPolicy | OPERATIONAL_MODELS.md §2 | ~4 |

All of the above seed datasets can be authored directly from their source documents in a single session without pre-planning. The ClaimPredicate seed is the exception due to its size, complexity, and the inverse pair two-pass requirement.

---

*Seed authoring may begin once this plan is reviewed by the Discovery Partner. No predicate seed SQL may be written before this plan is confirmed.*
