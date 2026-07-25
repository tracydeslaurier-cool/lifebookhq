# LifeBook Semantic Collision Report
**Version:** 0.2  
**Status:** Closure approved pending Discovery Partner sign-off on §9  
**Produced from:** CLAIM_PREDICATE_CATALOGUE.md v0.1 · RELATIONSHIP_TYPE_CATALOGUE.md v0.1  
**Updated against:** CLAIM_PREDICATE_CATALOGUE.md v0.2 · CONTENT_LAYER.md v0.3  
**Produced:** 2026-07-23

### Revision history

| Version | Date | Summary | Supersedes |
|---|---|---|---|
| 0.1 | 2026-07-23 | Initial cross-check; 5 gaps identified (count later corrected) | — |
| 0.2 | 2026-07-23 | Count corrected to 6; §4.4 associated_with routing superseded; §5 gaps marked RESOLVED; §6 updated with completion status; §9 closure section added; revision history added | 0.1 |

---

## Purpose

This report cross-checks the claim predicate catalogue and the relationship type catalogue for:
1. Duplicate semantics between the two catalogues
2. Predicates that should instead be Events
3. Relationship types that should instead be state transitions
4. Gaps: facts that have no modelling path
5. Design decisions required before migration

---

## 1. Catalogue overlap map

The following table maps every predicate with `relationship_interaction ≠ none` to its corresponding RelationshipType, and flags where overlap may create ambiguity.

| Predicate | Relationship interaction | Corresponding RelationshipType | Ambiguity risk |
|---|---|---|---|
| `married_to` | proposes | `marriage` | LOW — rule is clear: Claim proposes, Relationship is durable record |
| `married_on` | supports | `marriage` | LOW |
| `married_at` | supports | `marriage` | LOW |
| `employed_by` | proposes | `employment` | LOW |
| `contracted_to` | proposes | `contractor` | LOW |
| `served_in` | proposes | `military_service` | LOW |
| `member_of` | proposes | `organizational_membership` or `community_membership` | MEDIUM — `member_of` predicate covers both; system must determine which RelationshipType to propose based on object entity_type |
| `enrolled_at` | proposes | `organizational_membership` | LOW |
| `ordained_in` | proposes | `organizational_membership` | LOW |
| `appointed_to` | proposes | `organizational_membership` | LOW |
| `owned` | proposes | `ownership` | LOW |
| `held_title_to` | proposes | `ownership` | MEDIUM — `held_title_to` implies formal legal instrument; `ownership` is broader. Are they the same Relationship type? |
| `custody_of` | proposes | `custody_of_person` | LOW |
| `relationship_commenced_on` | describes | any | LOW |
| `relationship_ended_on` | describes | any | LOW |
| `relationship_contested_on` | describes | any | LOW |
| `joined_on` | supports | `organizational_membership` | LOW |
| `left_on` | describes | any | LOW |
| `enlisted_on` | supports | `military_service` | LOW |
| `enlisted_at` | supports | `military_service` | LOW |
| `discharged_on` | describes | `military_service` | LOW |
| `held_rank` | describes | `military_service` | LOW |
| `held_position` | describes | `employment` or `organizational_membership` | MEDIUM — must be scoped to a Relationship context |

**Resolved rules:**

1. When `member_of` subject is a Person and object is a Community entity, the proposed RelationshipType is `community_membership`. When object is an Organization, the proposed type is `organizational_membership`. This determination is made by the system based on entity_type of the object.

2. `held_title_to` and `owned` both propose the `ownership` RelationshipType. They are differentiated by evidence: `held_title_to` requires a documentary instrument; `owned` is more general. A single `ownership` Relationship may be supported by both types of Claims simultaneously.

3. `held_position`, `held_rank`, and similar role-descriptive predicates always `describe` a Relationship; they do not create one. The application must require that a corresponding Relationship record exists (or is simultaneously created) when these Claims are submitted.

---

## 2. Predicates that should be Events, not Claims

The following predicates generate Events when reviewed and promoted. This is intentional and correct. However, three predicates were initially considered as purely factual Claims and must be confirmed as Event-generating:

| Predicate | Generated event_type | Decision |
|---|---|---|
| `born_on` + `born_at` | `birth` | CONFIRMED — both claims generate a birth Event proposal |
| `died_on` + `died_at` | `death` | CONFIRMED — both generate a death Event proposal |
| `baptised_on` + `baptised_at` | `baptism` | CONFIRMED |
| `buried_on` + `buried_at` | `burial_interment` | CONFIRMED |
| `married_on` + `married_at` | `marriage` | CONFIRMED — these Claims support the Event; the Event is recorded separately |
| `naturalized_on` + `naturalized_at` | `naturalization` | CONFIRMED |
| `adopted_on` | `adoption` | CONFIRMED |
| `founding_date_of` | `institutional_event` | CONFIRMED — founding is also an Event |
| `dissolution_date_of` | `institutional_event` | CONFIRMED |
| `graduated_on` + `graduated_from` | `graduation` | CONFIRMED |
| `ordained_on` + `ordained_at` | `ordination` | CONFIRMED |
| `enlisted_on` + `enlisted_at` | `military_service` | CONFIRMED |

**Important:** These Claims generate *proposed* Events. The Event is not auto-accepted. All system-generated Event proposals carry `submission_origin = system_inferred_submission` and `review_status = pending`.

**One predicate flagged for removal or redesign:**

`named_on` + `named_at` generate a `naming_ceremony` Event. However, `naming_ceremony` is a valid event_type in CONTENT_LAYER.md §15.2. No change needed; this is correct.

---

## 3. Relationship types that should be state transitions

The RELATIONSHIP_TYPE_CATALOGUE.md explicitly excluded the following. This section confirms the decisions and documents any outstanding questions.

| Excluded concept | Correct modelling | Confirmed |
|---|---|---|
| Separation | `separation_divorce` Event + Relationship.is_ongoing = false | CONFIRMED |
| Divorce | `separation_divorce` Event + effective_until + is_ongoing = false | CONFIRMED |
| Annulment | Specific event + is_ongoing = false | CONFIRMED |
| Widowhood | Consequence of `death` Event for spouse | CONFIRMED |
| Resignation / Termination | `employment_end` Event + is_ongoing = false | CONFIRMED |
| Estrangement | Notes on Relationship or Narrative | CONFIRMED — no relationship type needed |
| Excommunication / Expulsion | `left_on` Claim + is_ongoing = false | CONFIRMED |

**Historical note — resolved:**

`in_civil_partnership_with` was identified as a gap because it was referenced in the `married_to` invalid example but not defined. This has been resolved.

- Predicate `in_civil_partnership_with` added in CLAIM_PREDICATE_CATALOGUE.md v0.2, Family 2 (Vital Events)
- Proposes a `civil_partnership` Relationship record
- May generate a `civil_partnership_registration` Event proposal when documentary registration evidence exists
- Must not route through `married_to`, `marriage`, or the `marriage` event_type
- `civil_partnership_registration` added to CONTENT_LAYER.md §15.2 as a distinct event_type

---

## 4. Semantic duplications identified

### 4.1 `owned` vs. `held_title_to`

Both predicates propose an `ownership` Relationship. The distinction:
- `owned` = legal ownership evidenced by any means
- `held_title_to` = legal ownership evidenced by a specific legal instrument (deed, grant, patent)

**Decision:** Both predicates are retained. They are not duplicates; they represent different levels of evidential specificity for the same underlying fact. A single `ownership` Relationship may be supported by Claims of both types. No change needed.

### 4.2 `resided_at` vs. `location_at_time`

These overlap when a person was at a place for an extended period.
- `resided_at` = primary or habitual residence (implies regularity and intent to dwell)
- `location_at_time` = documented presence at a specific time, without residential implication

**Decision:** Both predicates are retained. They are semantically distinct. Misapplication should be caught at review. No change needed.

### 4.3 `member_of` (predicate) vs. `organizational_membership` / `community_membership` (Relationship types)

`member_of` is a predicate that proposes one of two Relationship types depending on the object entity_type. This is a controlled ambiguity: the predicate is general; the Relationship type is specific.

**Decision:** Document the routing rule explicitly in the application layer: when `member_of` object is entity_type = community, propose `community_membership`; when entity_type = organization, propose `organizational_membership`. If entity_type is ambiguous (e.g., a religious organization that is also a community), the steward selects the appropriate Relationship type at review.

### 4.4 `professional_association` (Relationship) vs. `associated_with` (predicate)

The predicate `associated_with` was listed in the seed predicates table (§3.3 of CONTENT_LAYER.md) but not fully defined as an individual entry. The RelationshipType `professional_association` covers a specific subset of associations.

**Decision (revised):** `associated_with` is now defined as a full predicate entry in CLAIM_PREDICATE_CATALOGUE.md Family 8. It has `relationship_interaction = none` and does NOT automatically propose a `professional_association` or any other Relationship type. It is intentionally broad and intentionally toothless as a durable record. It is a placeholder that requires reviewer resolution. Automatically routing it to `professional_association` would be wrong: `associated_with` covers friendship, travel companionship, correspondence, event co-participation, and many other connection types that are not professional associations.

The reviewer prompt is: "Determine whether this association should be classified as friendship, professional association, employment, community membership, travel companionship, correspondence, or event co-participation."

### 4.5 `apprenticeship` (Relationship) and education predicates

`apprenticeship` is a RelationshipType in Group E. The predicate catalogue does not include an `apprenticed_to` predicate. The `enrolled_at` predicate notes "use apprenticed_to for apprenticeship" in its invalid example, but no `apprenticed_to` predicate is defined.

**Decision:** Add `apprenticed_to` to Family 5 (Education) or Family 6 (Employment) of the predicate catalogue, proposing the `apprenticeship` Relationship type. This is flagged as open item §5.1 below.

---

## 5. Gaps: facts with no current modelling path

Items marked **RESOLVED** have been implemented. Items marked **DEFERRED** are non-blocking for migration. No unresolved blocking gaps remain.

| Gap | Description | Status | Implementation |
|---|---|---|---|
| 5.1 `apprenticed_to` predicate | Referenced but not defined; `apprenticeship` Relationship had no proposing predicate | **RESOLVED** | Defined in CLAIM_PREDICATE_CATALOGUE.md v0.2, Family 6; proposes `apprenticeship`; object may be person or organization |
| 5.2 `associated_with` predicate | Listed in seed table but not fully specified | **RESOLVED** | Defined in CLAIM_PREDICATE_CATALOGUE.md v0.2, Family 8; `relationship_interaction = none`; does not propose a Relationship; promotion rule enforced; see §4.4 revised |
| 5.3 `in_civil_partnership_with` predicate | Referenced in married_to invalid example but not defined | **RESOLVED** | Defined in CLAIM_PREDICATE_CATALOGUE.md v0.2, Family 2; proposes `civil_partnership` Relationship; distinct from `married_to` |
| 5.4 `civil_partnership` Event type | No corresponding event_type existed for civil partnership registration | **RESOLVED** | `civil_partnership_registration` added to CONTENT_LAYER.md §15.2 v0.3; distinct from `marriage` |
| 5.5 Place historical names | Query spec for "name in use at time T" missing | **DEFERRED** | Non-blocking for migration. Required before display layer implementation. |
| 5.6 Person–Artifact depiction | `depicted_in` uses text; Artifact is not an Entity; consistency gap with NarrativeEntity | **DEFERRED** | Non-blocking for migration. Future design iteration. |
| 5.7 DNA / genetic evidence | No source_type for DNA analysis | **RESOLVED** | `dna_analysis` added to CONTENT_LAYER.md §9.2 v0.3; governance in §9.3; sub-type classification in §9.3.1; raw-DNA ingestion deploy-disabled |
| 5.8 Court records as source type | `legal_document` did not distinguish court records | **RESOLVED** | `court_record` added to CONTENT_LAYER.md §9.2 v0.3; `legal_document` description tightened |
| 5.9 Duration of employment | Duration-only numeric assertions had no unit support | **RESOLVED** | ClaimValueUnit with `year`, `month`, `day` units defined in CONTENT_LAYER.md §3.2; `employment_duration` predicate not added (use `employed_by` with temporal qualifiers and value_unit_code on numeric sub-claim, or notes on Relationship) |

---

## 6. Required catalogue updates before migration

All six required updates have been completed. Status as of 2026-07-23:

| Priority | Update | Target document | Status |
|---|---|---|---|
| **Required** | Add `apprenticed_to` predicate | CLAIM_PREDICATE_CATALOGUE.md | ✓ Done (v0.2 Family 6) |
| **Required** | Add `associated_with` predicate (full entry, relationship_interaction = none) | CLAIM_PREDICATE_CATALOGUE.md | ✓ Done (v0.2 Family 8) |
| **Required** | Add `in_civil_partnership_with` predicate | CLAIM_PREDICATE_CATALOGUE.md | ✓ Done (v0.2 Family 2) |
| **Required** | Add `civil_partnership_registration` to event_type | CONTENT_LAYER.md §15.2 | ✓ Done (v0.3) |
| **Required** | Add `dna_analysis` to source_type + §9.3 governance note | CONTENT_LAYER.md §9.2–9.3 | ✓ Done (v0.3) |
| **Required** | Add `court_record` to source_type; split `legal_document` description | CONTENT_LAYER.md §9.2 | ✓ Done (v0.3) |
| **Superseded** | ~~`associated_with` → `professional_association` routing~~ | Superseded — see §4.4 revised | `relationship_interaction = none`; no auto-propose |
| **Recommended** | `member_of` routing rule (community vs. organizational) in application layer spec | SEMANTIC_COLLISION_REPORT.md §4.3 | Defined — routing rule documented in §4.3; application layer implementation required before feature ships (non-blocking before migration) |
| **Deferred** | Person–Artifact depiction gap (§5.6) | Future design iteration | Deferred |
| **Deferred** | Place historical name query specification (§5.5) | Before display layer implementation | Deferred |

---

## 7. SCHEMA_INVENTORY.md updates required

The following changes to SCHEMA_INVENTORY.md are required based on catalogue decisions:

1. **Group 1 (Enums):** Add `dna_analysis` and `court_record` to source_type (1.26). Add `civil_partnership_registration` to event_type (1.28).
2. **Group 13 (Deployment blockers):** Gate 13.7 (ClaimPredicate seed) and 13.8 (RelationshipType seed) both remain blocked pending addition of the three missing predicates and the civil_partnership event_type.
3. **Group 6 (Relationship and predicate catalogues):** Note that the three missing predicates must be added to the ClaimPredicate seed before the ClaimPredicate table is deployed.

---

## 8. No SQL until reviewed

Six required additions were identified. All six have been resolved. SQL migration remains blocked pending Discovery Partner review of this closure.

All other items in §5 are non-blocking for migration and may be addressed in subsequent design iterations.

---

## 9. Closure section

**Status:** All six required catalogue additions have been defined. The catalogue gate is provisionally cleared pending Discovery Partner approval of this closure section.

### 9.1 Required additions resolved

| Item | Resolution | Document |
|---|---|---|
| 5.1 `apprenticed_to` predicate | Defined in CLAIM_PREDICATE_CATALOGUE.md Family 6; proposes `apprenticeship` Relationship; object may be person or organization | v0.2 |
| 5.2 `associated_with` predicate | Defined in CLAIM_PREDICATE_CATALOGUE.md Family 8; `relationship_interaction = none`; does NOT propose a Relationship; see §9.2 | v0.2 |
| 5.3 `in_civil_partnership_with` predicate | Defined in CLAIM_PREDICATE_CATALOGUE.md Family 2; proposes `civil_partnership` Relationship; distinct from `married_to` and `marriage` | v0.2 |
| 5.4 `civil_partnership_registration` event type | Defined in CONTENT_LAYER.md §15.2; distinct from `marriage` event type | v0.3 |
| 5.7 `dna_analysis` source type | Defined in CONTENT_LAYER.md §9.2; restricted by default; §9.3 governance note added; raw-DNA ingestion deploy-disabled | v0.3 |
| 5.8 `court_record` source type | Defined in CONTENT_LAYER.md §9.2; `legal_document` description updated to exclude court records | v0.3 |

### 9.2 `associated_with` does not create a Relationship

`associated_with` has `relationship_interaction = none`. It does not and must not independently create a durable Relationship record. It is a placeholder Claim that requires human reviewer resolution before it can be considered complete. A steward who approves an `associated_with` Claim without a corresponding determination note (reclassification to a specific predicate, or a documented decision that no Relationship is warranted) has not completed the review obligation.

This overrides the earlier collision report recommendation (§4.4) that `associated_with` should `proposes` a `professional_association` Relationship. That recommendation has been superseded.

### 9.3 Numeric Claims have unit support

`Claim.value_unit_code` (FK → ClaimValueUnit) and `Claim.value_unit_qualifier` have been added to CONTENT_LAYER.md §2.1. ClaimValueUnit is defined at §3.2 with 11 seed units. The constraint rule is: any numeric Claim whose predicate does not explicitly define a unitless value must carry `value_unit_code`. Currency Claims must also carry `value_unit_qualifier` (ISO 4217 code). Enforcement is at the application layer; a DB check constraint may follow after ClaimValueUnit is seeded.

`employment_duration` is not added as a predicate. Duration-only assertions about employment should use `value_numeric` + `value_unit_code = year` or `month` on an `employed_by` Claim with temporal qualifiers, or in a note on the Relationship record. A dedicated predicate is not warranted unless specific evidence requirements emerge.

### 9.4 DNA processing remains deploy-disabled

Raw-DNA ingestion and processing is deploy-disabled per CONTENT_LAYER.md §9.3. The `dna_analysis` source_type is defined in the schema and may be used to record source records describing DNA analysis results. It may not be used to trigger automatic Relationship creation, AI context supply, or search indexing. A separate genetic-data governance policy is required before any of those restrictions are lifted.

### 9.5 No unresolved predicate references

A predicate reference audit confirmed:
- `enrolled_at` invalid example references `apprenticed_to` — now defined. ✓
- `married_to` invalid example references `in_civil_partnership_with` — now defined. ✓
- Seed predicate table in CONTENT_LAYER.md §3.3 lists `associated_with` — now defined. ✓
- `apprenticeship` RelationshipType in RELATIONSHIP_TYPE_CATALOGUE.md — proposing predicate (`apprenticed_to`) now defined. ✓
- `civil_partnership` RelationshipType — proposing predicate (`in_civil_partnership_with`) now defined. ✓

No orphaned predicate references remain in the catalogues.

### 9.6 Remaining non-blocking gaps (deferred)

Items §5.5, §5.6, §5.9 are deferred:
- §5.5 Place historical name query: query specification needed before display layer implementation.
- §5.6 Person–Artifact depiction: deferred to future design iteration.
- §5.9 Employment duration: covered by numeric Claim with `value_unit_code` on `employed_by`; no dedicated predicate needed.

**Do not write SQL until this closure section is reviewed and approved.**
