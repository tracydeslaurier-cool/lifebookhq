# ClaimPredicate Seed Specification
**Version:** 1.0  
**Status:** Pre-SQL — validated; awaiting SQL authoring authorization  
**Produced:** 2026-07-25  
**Produced by:** Tracy DesLaurier + Claude (Pre-Authoring Confirmation B)  
**Source of truth:** CLAIM_PREDICATE_CATALOGUE.md v0.2  
**Depends on:** CLAIM_PREDICATE_SEED_PLAN.md v0.3  
**Delivers:** Column-level specification for all 74 `claim_predicates` INSERT records (Pass 1 + Pass 2 inverse UPDATEs)

---

## Purpose

This document maps each of the 74 ClaimPredicates to its `claim_predicates` table column values. The SQL author uses this document to write the seed INSERT statements (Pass 1) and the inverse UPDATE statements (Pass 2) in migration 0003.

This is a specification document, not SQL. No SQL appears here.

---

## Validation Summary

All six pre-authoring checks pass:

| Check | Result |
|---|---|
| 1. Code uniqueness — 74 unique predicate_code values | PASS |
| 2. Unit validation — no numeric predicates; ClaimValueUnit trigger trivially satisfied | PASS |
| 3. generates_event_type — all 17 non-null values map to event_types.code from migration 0001 | PASS |
| 4. Inverse bidirectionality — 3 symmetric self-inverses; 3 documented non-required inverses | PASS |
| 5. No obsolete terminology — no confidence enum references | PASS |
| 6. Catalogue count corrections applied — F2: 16→17, F8: 8→7; total 74 unchanged | COMPLETE |

---

## Column Notation

Columns used in tables below:

| Abbreviation | Full column name | Notes |
|---|---|---|
| `code` | `predicate_code` | Machine identifier |
| `label` | `display_label` | Human-readable label |
| `subject_types` | `permitted_subject_entity_types` | Array of entity_type enum values |
| `val_type` | `permitted_value_type` | `entity` / `date` / `text` |
| `obj_types` | `permitted_object_entity_types` | NULL unless val_type = entity |
| `sym` | `is_symmetric` | Boolean |
| `trans` | `is_transitive` | Boolean |
| `temp` | `temporal_allowed` | Boolean |
| `rel_int` | `relationship_interaction` | `proposes` / `supports` / `describes` / `none` |
| `access` | `default_access_classification` | `public` / `family` / `steward` / `restricted` |
| `evt` | `generates_event_type` | event_types.code value or NULL |
| `inv_code` | Inverse predicate code | For Pass 2 reference only; NULL in Pass 1 INSERT |

**Fixed values for all 74 records (Pass 1):**

```
inverse_predicate_id = NULL           -- updated in Pass 2 for symmetric predicates
deprecated_at        = NULL
replaced_by_predicate_id = NULL
numeric_unit_required    = NULL       -- no numeric predicates in v0.2
permitted_unit_categories = NULL
permitted_unit_codes     = NULL
numeric_integer_only     = NULL
numeric_min_value        = NULL
numeric_max_value        = NULL
created_by_id            = NULL
created_by_system        = 'migration:<actual_core_schema_filename>'
```

**Descriptions:** Every predicate's `description` column value is its full `definition` text from CLAIM_PREDICATE_CATALOGUE.md v0.2. The SQL author must copy the full definition text verbatim (with formatting stripped to plain text).

---

## Family 1 — Identity and Naming (4 records)

Applies to non-person entities only. Persons use PersonName attribute tables.

| # | code | label | subject_types | val_type | obj_types | sym | trans | temp | rel_int | access | evt | inv_code |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `has_name` | Has name | `{organization,place,vessel,community,event_series}` | `text` | NULL | false | false | true | `none` | `public` | NULL | NULL |
| 2 | `also_known_as` | Also known as | `{organization,place,vessel,community,event_series}` | `text` | NULL | false | false | true | `none` | `public` | NULL | NULL |
| 3 | `founding_date_of` | Founding date of | `{organization,community,vessel}` | `date` | NULL | false | false | false | `none` | `public` | `institutional_event` | NULL |
| 4 | `dissolution_date_of` | Dissolution date of | `{organization,community,vessel}` | `date` | NULL | false | false | false | `none` | `public` | `institutional_event` | NULL |

---

## Family 2 — Vital Events (17 records)

Each vital event splits into place and date predicates. Each is independent.

| # | code | label | subject_types | val_type | obj_types | sym | trans | temp | rel_int | access | evt | inv_code |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 5 | `born_on` | Born on | `{person}` | `date` | NULL | false | false | false | `none` | `family` | `birth` | NULL |
| 6 | `born_at` | Born at | `{person}` | `entity` | `{place}` | false | false | false | `none` | `family` | `birth` | NULL |
| 7 | `died_on` | Died on | `{person}` | `date` | NULL | false | false | false | `none` | `family` | `death` | NULL |
| 8 | `died_at` | Died at | `{person}` | `entity` | `{place}` | false | false | false | `none` | `family` | `death` | NULL |
| 9 | `baptised_on` | Baptised on | `{person}` | `date` | NULL | false | false | false | `none` | `family` | `baptism` | NULL |
| 10 | `baptised_at` | Baptised at | `{person}` | `entity` | `{place}` | false | false | false | `none` | `family` | `baptism` | NULL |
| 11 | `named_on` | Named on | `{person}` | `date` | NULL | false | false | false | `none` | `family` | `naming_ceremony` | NULL |
| 12 | `named_at` | Named at | `{person}` | `entity` | `{place}` | false | false | false | `none` | `family` | `naming_ceremony` | NULL |
| 13 | `buried_on` | Buried on | `{person}` | `date` | NULL | false | false | false | `none` | `family` | `burial_interment` | NULL |
| 14 | `buried_at` | Buried at | `{person}` | `entity` | `{place}` | false | false | false | `none` | `family` | `burial_interment` | NULL |
| 15 | `married_on` | Married on | `{person}` | `date` | NULL | false | false | false | `supports` | `family` | `marriage` | NULL |
| 16 | `married_at` | Married at | `{person}` | `entity` | `{place}` | false | false | false | `supports` | `family` | `marriage` | NULL |
| 17 | `married_to` | Married to | `{person}` | `entity` | `{person}` | **true** | false | true | `proposes` | `family` | NULL | `married_to` ★ |
| 18 | `in_civil_partnership_with` | In civil partnership with | `{person}` | `entity` | `{person}` | **true** | false | true | `proposes` | `family` | `civil_partnership_registration` | `in_civil_partnership_with` ★ |
| 19 | `naturalized_on` | Naturalized on | `{person}` | `date` | NULL | false | false | false | `none` | `family` | `naturalization` | NULL |
| 20 | `naturalized_at` | Naturalized at | `{person}` | `entity` | `{place}` | false | false | false | `none` | `family` | `naturalization` | NULL |
| 21 | `adopted_on` | Adopted on | `{person}` | `date` | NULL | false | false | false | `supports` | `steward` | `adoption` | NULL |

★ Symmetric self-inverse. Pass 2 sets `inverse_predicate_id = id` (the record's own UUID).

---

## Family 3 — Residence and Location (4 records)

| # | code | label | subject_types | val_type | obj_types | sym | trans | temp | rel_int | access | evt | inv_code |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 22 | `resided_at` | Resided at | `{person,organization}` | `entity` | `{place}` | false | false | true | `none` | `family` | NULL | NULL |
| 23 | `stayed_at` | Stayed at | `{person}` | `entity` | `{place}` | false | false | true | `none` | `public` | NULL | NULL |
| 24 | `had_address` | Had address | `{person,organization}` | `text` | NULL | false | false | true | `none` | `steward` | NULL | NULL |
| 25 | `location_at_time` | Location at time | `{person,organization,vessel}` | `entity` | `{place}` | false | false | true | `none` | `public` | NULL | NULL |

---

## Family 4 — Migration and Travel (9 records)

| # | code | label | subject_types | val_type | obj_types | sym | trans | temp | rel_int | access | evt | inv_code |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 26 | `emigrated_from` | Emigrated from | `{person}` | `entity` | `{place}` | false | false | true | `none` | `public` | `emigration` | NULL |
| 27 | `emigrated_on` | Emigrated on | `{person}` | `date` | NULL | false | false | false | `none` | `public` | `emigration` | NULL |
| 28 | `immigrated_to` | Immigrated to | `{person}` | `entity` | `{place}` | false | false | true | `none` | `public` | `immigration` | NULL |
| 29 | `immigrated_on` | Immigrated on | `{person}` | `date` | NULL | false | false | false | `none` | `public` | `immigration` | NULL |
| 30 | `departed_from` | Departed from | `{person}` | `entity` | `{place}` | false | false | true | `none` | `public` | `voyage` | NULL |
| 31 | `departed_on` | Departed on | `{person,vessel}` | `date` | NULL | false | false | false | `none` | `public` | `voyage` | NULL |
| 32 | `arrived_at` | Arrived at | `{person,vessel}` | `entity` | `{place}` | false | false | true | `none` | `public` | `voyage` | NULL |
| 33 | `arrived_on` | Arrived on | `{person,vessel}` | `date` | NULL | false | false | false | `none` | `public` | `voyage` | NULL |
| 34 | `travelled_on` | Travelled on | `{person}` | `entity` | `{vessel}` | false | false | true | `none` | `public` | `voyage` | NULL |

---

## Family 5 — Education (4 records)

| # | code | label | subject_types | val_type | obj_types | sym | trans | temp | rel_int | access | evt | inv_code |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 35 | `enrolled_at` | Enrolled at | `{person}` | `entity` | `{organization}` | false | false | true | `proposes` | `family` | NULL | NULL |
| 36 | `graduated_from` | Graduated from | `{person}` | `entity` | `{organization}` | false | false | false | `none` | `public` | `graduation` | NULL |
| 37 | `graduated_on` | Graduated on | `{person}` | `date` | NULL | false | false | false | `none` | `public` | `graduation` | NULL |
| 38 | `awarded_credential` | Awarded credential | `{person}` | `text` | NULL | false | false | false | `none` | `public` | `graduation` | NULL |

---

## Family 6 — Employment and Occupation (6 records)

| # | code | label | subject_types | val_type | obj_types | sym | trans | temp | rel_int | access | evt | inv_code |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 39 | `employed_by` | Employed by | `{person}` | `entity` | `{organization,person}` | false | false | true | `proposes` | `public` | `employment_start` | NULL |
| 40 | `contracted_to` | Contracted to | `{person}` | `entity` | `{organization,person}` | false | false | true | `proposes` | `public` | NULL | NULL |
| 41 | `apprenticed_to` | Apprenticed to | `{person}` | `entity` | `{person,organization}` | false | false | true | `proposes` | `public` | NULL | NULL |
| 42 | `had_occupation` | Had occupation | `{person}` | `text` | NULL | false | false | true | `none` | `public` | NULL | NULL |
| 43 | `held_position` | Held position | `{person}` | `text` | NULL | false | false | true | `describes` | `public` | NULL | NULL |
| 44 | `worked_at` | Worked at | `{person}` | `entity` | `{place}` | false | false | true | `none` | `public` | NULL | NULL |

---

## Family 7 — Military Service (6 records)

| # | code | label | subject_types | val_type | obj_types | sym | trans | temp | rel_int | access | evt | inv_code |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 45 | `served_in` | Served in | `{person}` | `entity` | `{organization}` | false | false | true | `proposes` | `public` | `military_service` | NULL |
| 46 | `enlisted_on` | Enlisted on | `{person}` | `date` | NULL | false | false | false | `supports` | `public` | `military_service` | NULL |
| 47 | `enlisted_at` | Enlisted at | `{person}` | `entity` | `{place}` | false | false | false | `supports` | `public` | `military_service` | NULL |
| 48 | `discharged_on` | Discharged on | `{person}` | `date` | NULL | false | false | false | `describes` | `public` | `military_service` | NULL |
| 49 | `held_rank` | Held rank | `{person}` | `text` | NULL | false | false | true | `describes` | `public` | NULL | NULL |
| 50 | `served_at` | Served at | `{person}` | `entity` | `{place}` | false | false | true | `describes` | `public` | NULL | NULL |

---

## Family 8 — Organizational and Community Participation (7 records)

| # | code | label | subject_types | val_type | obj_types | sym | trans | temp | rel_int | access | evt | inv_code |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 51 | `member_of` | Member of | `{person,organization}` | `entity` | `{organization,community}` | false | false | true | `proposes` | `public` | NULL | NULL |
| 52 | `joined_on` | Joined on | `{person}` | `date` | NULL | false | false | false | `supports` | `public` | NULL | NULL |
| 53 | `left_on` | Left on | `{person}` | `date` | NULL | false | false | false | `describes` | `public` | NULL | NULL |
| 54 | `associated_with` | Associated with | `{person,organization,place,vessel,community,event_series}` | `entity` | `{person,organization,place,vessel,community,event_series}` | **true** | false | true | `none` | `family` | NULL | `associated_with` ★ |
| 55 | `ordained_in` | Ordained in | `{person}` | `entity` | `{organization,community}` | false | false | false | `proposes` | `public` | `ordination` | NULL |
| 56 | `ordained_on` | Ordained on | `{person}` | `date` | NULL | false | false | false | `supports` | `public` | `ordination` | NULL |
| 57 | `ordained_at` | Ordained at | `{person}` | `entity` | `{place}` | false | false | false | `supports` | `public` | `ordination` | NULL |

★ Symmetric self-inverse. Pass 2 sets `inverse_predicate_id = id` (the record's own UUID).

---

## Family 9 — Document Appearance (3 records)

| # | code | label | subject_types | val_type | obj_types | sym | trans | temp | rel_int | access | evt | inv_code |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 58 | `recorded_in` | Recorded in | `{person,organization,place,vessel,community}` | `text` | NULL | false | false | false | `none` | `public` | NULL | NULL |
| 59 | `listed_as` | Listed as | `{person,organization,place,vessel}` | `text` | NULL | false | false | false | `none` | `public` | NULL | NULL |
| 60 | `documented_by` | Documented by | `{person,organization,place,vessel}` | `entity` | `{organization}` | false | false | true | `none` | `public` | NULL | NULL |

---

## Family 10 — Property, Custody, and Ownership (5 records)

| # | code | label | subject_types | val_type | obj_types | sym | trans | temp | rel_int | access | evt | inv_code |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 61 | `owned` | Owned | `{person,organization}` | `entity` | `{place,organization,vessel}` | false | false | true | `proposes` | `family` | NULL | NULL |
| 62 | `possessed` | Possessed | `{person,organization}` | `text` | NULL | false | false | true | `none` | `family` | NULL | NULL |
| 63 | `held_title_to` | Held title to | `{person,organization}` | `entity` | `{place}` | false | false | true | `proposes` | `family` | NULL | NULL |
| 64 | `custody_of` | Had custody of | `{person,organization}` | `entity` | `{person}` | false | false | true | `proposes` | `steward` | NULL | NULL |
| 65 | `held_in_stewardship` | Held in stewardship | `{person,organization}` | `text` | NULL | false | false | true | `none` | `public` | NULL | NULL |

---

## Family 11 — Titles and Honours (4 records)

| # | code | label | subject_types | val_type | obj_types | sym | trans | temp | rel_int | access | evt | inv_code |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 66 | `held_title` | Held title | `{person}` | `text` | NULL | false | false | true | `none` | `public` | NULL | NULL |
| 67 | `awarded_honour` | Awarded honour | `{person}` | `text` | NULL | false | false | false | `none` | `public` | NULL | NULL |
| 68 | `awarded_on` | Awarded on | `{person}` | `date` | NULL | false | false | false | `none` | `public` | NULL | NULL |
| 69 | `appointed_to` | Appointed to | `{person}` | `entity` | `{organization}` | false | false | true | `proposes` | `public` | `institutional_event` | NULL |

---

## Family 12 — Relationship Qualification (3 records)

These predicates qualify Relationship records and require a corresponding Relationship record to be meaningful.

| # | code | label | subject_types | val_type | obj_types | sym | trans | temp | rel_int | access | evt | inv_code |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 70 | `relationship_commenced_on` | Relationship commenced on | `{person,organization}` | `date` | NULL | false | false | false | `describes` | `family` | NULL | NULL |
| 71 | `relationship_ended_on` | Relationship ended on | `{person,organization}` | `date` | NULL | false | false | false | `describes` | `family` | NULL | NULL |
| 72 | `relationship_contested_on` | Relationship contested on | `{person,organization}` | `date` | NULL | false | false | false | `describes` | `steward` | NULL | NULL |

---

## Family 13 — Source and Artifact Associations (2 records)

| # | code | label | subject_types | val_type | obj_types | sym | trans | temp | rel_int | access | evt | inv_code |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 73 | `depicted_in` | Depicted in | `{person,organization,place,vessel,community}` | `text` | NULL | false | false | false | `none` | `family` | NULL | NULL |
| 74 | `attributed_to` | Attributed to | `{person,organization}` | `text` | NULL | false | false | false | `none` | `public` | NULL | NULL |

---

## Pass 2 — Inverse UPDATE Specification

After all 74 Pass 1 INSERTs are committed, apply the following UPDATEs.

**Pattern (all three are symmetric self-inverses):**

```
UPDATE claim_predicates
SET inverse_predicate_id = id
WHERE predicate_code IN ('married_to', 'in_civil_partnership_with', 'associated_with');
```

This is valid: for a symmetric predicate, the predicate is its own inverse. Each record's `inverse_predicate_id` points to itself.

**Documented non-required inverses (no UPDATE needed):**

These inverse relationships exist semantically but the inverse predicate is not defined as a required catalogue entry. The Relationship record carries the inverse. No UPDATE is written.

| Predicate | Notes inverse | Disposition |
|---|---|---|
| `employed_by` | Notes `employs` | Not a required predicate; Relationship carries inverse |
| `owned` | Notes `owned_by` | Not a required predicate; Relationship carries inverse |
| `member_of` | Notes `has_member` | Not a required predicate; Relationship carries inverse |

---

## generates_event_type Validation

All non-null `generates_event_type` values used in this specification, confirmed against migration 0001 `event_types` seed:

| Value | Count | Migration 0001 confirmation |
|---|---|---|
| `birth` | 2 | ✓ |
| `death` | 2 | ✓ |
| `baptism` | 2 | ✓ |
| `naming_ceremony` | 2 | ✓ |
| `burial_interment` | 2 | ✓ |
| `marriage` | 2 | ✓ |
| `civil_partnership_registration` | 1 | ✓ |
| `naturalization` | 2 | ✓ |
| `adoption` | 1 | ✓ |
| `emigration` | 2 | ✓ |
| `immigration` | 2 | ✓ |
| `voyage` | 4 | ✓ |
| `graduation` | 3 | ✓ |
| `employment_start` | 1 | ✓ |
| `military_service` | 4 | ✓ |
| `ordination` | 3 | ✓ |
| `institutional_event` | 3 | ✓ |

Total non-null generates_event_type values: 38 across 74 predicates. All values confirmed valid.

---

## Record Count Verification

| Family | Expected | Spec count | Match |
|---|---|---|---|
| 1 — Identity and Naming | 4 | 4 (#1–4) | ✓ |
| 2 — Vital Events | 17 | 17 (#5–21) | ✓ |
| 3 — Residence and Location | 4 | 4 (#22–25) | ✓ |
| 4 — Migration and Travel | 9 | 9 (#26–34) | ✓ |
| 5 — Education | 4 | 4 (#35–38) | ✓ |
| 6 — Employment and Occupation | 6 | 6 (#39–44) | ✓ |
| 7 — Military Service | 6 | 6 (#45–50) | ✓ |
| 8 — Organizational and Community Participation | 7 | 7 (#51–57) | ✓ |
| 9 — Document Appearance | 3 | 3 (#58–60) | ✓ |
| 10 — Property, Custody, and Ownership | 5 | 5 (#61–65) | ✓ |
| 11 — Titles and Honours | 4 | 4 (#66–69) | ✓ |
| 12 — Relationship Qualification | 3 | 3 (#70–72) | ✓ |
| 13 — Source and Artifact Associations | 2 | 2 (#73–74) | ✓ |
| **Total** | **74** | **74** | **✓** |

---

## Pre-Authoring Confirmation B — Status

**SATISFIED.** The following actions were taken and all validation checks pass:

**Files modified:**
- `CLAIM_PREDICATE_CATALOGUE.md` — Family 2 count corrected (16 → 17); Family 8 count corrected (8 → 7). Total unchanged at 74.
- `CLAIM_PREDICATE_SEED_PLAN.md` — §3 family table updated to match current catalogue (family names and counts were stale from a superseded catalogue design). §9 predicate code reference list replaced with the actual 74 codes from the current catalogue.

**Files created:**
- `CLAIM_PREDICATE_SEED_SPEC.md` — This document. Complete 74-record seed specification.

**Remaining action before SQL authoring:** None for this confirmation. SQL authoring for migration 0002 is already authorized. Migration 0003 SQL authoring is authorized after 0002 is applied and verified.

---

*SQL authoring may not begin for migration 0003 without explicit Discovery Partner authorization following 0002 application.*
