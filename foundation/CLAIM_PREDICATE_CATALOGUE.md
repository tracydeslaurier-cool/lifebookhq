# LifeBook Claim Predicate Catalogue
**Version:** 0.2  
**Status:** Pre-migration governed specification

### Revision history

| Version | Date | Summary | Supersedes |
|---|---|---|---|
| 0.1 | 2026-07-23 | Initial catalogue; 71 predicates in 13 families | — |
| 0.2 | 2026-07-23 | Added `in_civil_partnership_with` (Family 2), `apprenticed_to` (Family 6), `associated_with` (Family 8); total 74; `associated_with` restricted to relationship_interaction = none with promotion rule | 0.1 |  
**Depends on:** ANCHOR_MODELS.md, CONTENT_LAYER.md, RELATIONSHIP_TYPE_CATALOGUE.md  
**Produced:** 2026-07-23

---

## Governance rules

### One predicate, one semantic relationship

Every predicate expresses exactly one relationship between a subject entity and one value or object entity. If a natural-language phrase could accept two different value types (a place or a date), it must be split into two predicates with distinct codes. `born_at` accepts only a Place entity. `born_on` accepts only a Date value. Neither accepts the other's type.

### Relationship interaction rule

A relational Claim proposes, supports, describes, or qualifies a Relationship record. It does not independently constitute the durable record of a connection. When a relational Claim is reviewed and promoted, it may create or support a Relationship record. The Claim and the Relationship are both retained and linked. Neither supersedes the other.

Each predicate entry specifies one of four interaction values:

| Value | Meaning |
|---|---|
| `proposes` | Asserting this Claim may generate a pending Relationship record for review |
| `supports` | This Claim adds evidence to an existing or pending Relationship |
| `describes` | This Claim qualifies, dates, or annotates a Relationship without creating one |
| `none` | This predicate has no interaction with the Relationship model |

### Event generation rule

Some predicates assert facts that, when reviewed, may generate a pending Event record (e.g., `born_on` may generate a `birth` Event). The `generates_event` field specifies whether this applies, and which event_type would be generated. Generated Events always begin with `submission_origin = system_inferred_submission` and `review_status = pending`.

### Temporal qualifiers

When `temporal = yes`, the Claim record may carry `value_date` (start) and `value_date_end` (end), representing the period during which the assertion was true. The `value_date_precision` field applies to both. Temporal Claims that have ended must not be treated as currently true without examining the effective dates.

### Sensitivity defaults

The default `access_classification` for a Claim carrying this predicate. This is the starting value; stewards may set a more restrictive classification. Sensitivity defaults reflect the typical privacy exposure of information of this type, not a legal guarantee.

### PersonName exception

For Person entities, names are governed by the attribute tables defined in PERSON_ATTRIBUTE_CATALOGUE.md (PersonName, PersonNameDerivative, PersonPronouns, PersonGenderDescriptor). The `has_name` and `also_known_as` predicates in this catalogue apply to Organization, Place, Vessel, Community, and EventSeries entities. For Person entities, use PersonName attribute records, not Claim records, for identity attribute facts.

### Range type definitions

| Range type | Description |
|---|---|
| `entity` | The object must be an Entity.id (a named entity in the system) |
| `date` | A single point in time; may carry precision_status |
| `date_range` | A period with start and optional end; both may carry precision |
| `text` | A free-text or controlled-vocabulary text value |
| `numeric` | A numeric value |
| `boolean` | True/false |
| `controlled_value` | A value from a defined list; list specified per predicate |

---

## Entry format

Each predicate is specified using the following fields:

```
predicate_code       — machine identifier; immutable
label                — human-readable label
definition           — precise semantic definition
subject_types        — which entity types may be the subject
range_type           — value type accepted
object_entity_types  — if range_type = entity, which entity types
inverse              — inverse predicate code, or none
symmetric            — yes | no
transitive           — yes | no
temporal             — yes | no
relationship_interaction — proposes | supports | describes | none
generates_event      — none | event_type value
sensitivity_default  — public | family | steward | restricted
recommended_evidence — list of source_type values
valid_example        — one or more concrete examples
invalid_example      — one or more concrete misuses
notes                — additional governance notes
```

---

## Family 1 — Identity and Naming

Predicates in this family assert names, aliases, and designations of non-person entities. For persons, use PersonName attribute records.

---

### `has_name`

```
predicate_code:       has_name
label:                Has name
definition:           The entity had or has a name by which it was or is identified. For non-person
                      entities only. Temporal qualifiers record when the name was in use.
subject_types:        organization, place, vessel, community, event_series
range_type:           text
object_entity_types:  n/a
inverse:              none (names are not typically symmetric)
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      none
sensitivity_default:  public
recommended_evidence: official_document, institutional_record, newspaper
valid_example:        The City of Königsberg has_name "Königsberg" (effective 1255–1946)
                      The City of Königsberg has_name "Kaliningrad" (effective 1946–present)
invalid_example:      Using has_name for a Person (use PersonName table instead)
                      Using has_name for a name with no temporal context when the name has changed
notes:                The cached_display_name on entity subtype tables is derived from the most
                      recently policy_approved has_name Claim. When no Claim exists, the cached
                      field may be null.
```

---

### `also_known_as`

```
predicate_code:       also_known_as
label:                Also known as
definition:           The entity was also referred to by this name, alias, abbreviation, or
                      colloquial designation in addition to its primary name. Does not replace
                      has_name; describes alternative designations.
subject_types:        organization, place, vessel, community, event_series
range_type:           text
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      none
sensitivity_default:  public
recommended_evidence: newspaper, institutional_record, personal_recollection
valid_example:        The Royal Canadian Mounted Police also_known_as "RCMP"
                      The vessel SS Imperator also_known_as "Leviathan" (after 1919 transfer)
invalid_example:      Using also_known_as for a name that was the primary name at a given time
                      (use has_name with temporal qualifiers instead)
notes:                Preferred for abbreviations, colloquialisms, and short-lived designations
                      that are not worth recording as primary names.
```

---

### `founding_date_of`

```
predicate_code:       founding_date_of
label:                Founding date of
definition:           The date on which this organization, community, or vessel was formally
                      established, incorporated, chartered, launched, or commissioned.
subject_types:        organization, community, vessel
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      institutional_event
sensitivity_default:  public
recommended_evidence: official_document, institutional_record, newspaper
valid_example:        The Hudson's Bay Company founding_date_of 1670-05-02
invalid_example:      Using founding_date_of for a Place (places are not founded in the same
                      sense; use has_name temporal start instead for when a place was named)
notes:                Precision uncertainty is common for historical organizations. Use
                      value_date_precision to record approximate or century-level confidence.
```

---

### `dissolution_date_of`

```
predicate_code:       dissolution_date_of
label:                Dissolution date of
definition:           The date on which this organization, community, or vessel ceased to exist
                      as an operating entity, was decommissioned, dissolved, or wound up.
subject_types:        organization, community, vessel
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      institutional_event
sensitivity_default:  public
recommended_evidence: official_document, newspaper
valid_example:        The Austro-Hungarian Empire dissolution_date_of 1918-11-03
invalid_example:      Using dissolution_date_of for a Place. Places are not dissolved
                      (they may be renamed or become uninhabited; use has_name or
                      subject-specific claims)
notes:                A dissolution does not automatically end all Relationship records
                      referencing the organization; those require explicit end dates.
```

---

## Family 2 — Vital Events

Predicates in this family assert facts about the key life events of persons: birth, death, baptism, burial, marriage-related events, naturalization, and adoption. Each vital event is split into place and date components so that each component can carry independent evidence and precision.

**Critical splitting rule:** Do not use a single predicate for both a place and a date. `born_at` accepts only a Place entity. `born_on` accepts only a Date. If both are known, create two separate Claim records.

---

### `born_on`

```
predicate_code:       born_on
label:                Born on
definition:           The date on which this person was born.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      birth
sensitivity_default:  family
recommended_evidence: vital_record, church_register, census_record
valid_example:        Alice born_on 1945-03-12
invalid_example:      Using born_on with a Place value (use born_at)
                      Recording a baptism date as born_on (use baptised_on)
notes:                For persons whose exact date of birth is unknown, use precision_status
                      to indicate the level of uncertainty (year_only, decade, etc.).
                      born_on and born_at are independent claims with independent evidence.
```

---

### `born_at`

```
predicate_code:       born_at
label:                Born at
definition:           The place where this person was born.
subject_types:        person
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      birth
sensitivity_default:  family
recommended_evidence: vital_record, church_register, census_record, personal_recollection
valid_example:        Alice born_at [Place: Warsaw, Poland]
invalid_example:      Using born_at with a date value (use born_on)
                      Using a text description of a place rather than a Place entity record
                      (create or reference the Place entity first)
notes:                If the Place entity does not yet exist, create it before creating this
                      Claim. Do not use value_text as a substitute for a proper Place entity.
```

---

### `died_on`

```
predicate_code:       died_on
label:                Died on
definition:           The date on which this person died.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      death
sensitivity_default:  family
recommended_evidence: vital_record, newspaper, church_register
valid_example:        Robert died_on 1918-11-03
invalid_example:      Using died_on for a date of presumed death without evidence
                      (use evidence_status = reported or unconfirmed)
notes:                Person.lifecycle_status should be updated to deceased when a
                      died_on Claim reaches review_status = policy_approved.
                      These are separate operations; the Claim does not automatically
                      update the Person record.
```

---

### `died_at`

```
predicate_code:       died_at
label:                Died at
definition:           The place where this person died.
subject_types:        person
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      death
sensitivity_default:  family
recommended_evidence: vital_record, church_register, military_record
valid_example:        Robert died_at [Place: Ypres, Belgium]
invalid_example:      Using died_at with a date value (use died_on)
notes:                None.
```

---

### `baptised_on`

```
predicate_code:       baptised_on
label:                Baptised on
definition:           The date on which this person was baptised, christened, or underwent an
                      equivalent religious rite of initiation or naming.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      baptism
sensitivity_default:  family
recommended_evidence: church_register
valid_example:        Maria baptised_on 1901-06-15
invalid_example:      Using baptised_on as a proxy for born_on when the birth date is unknown
                      (record them as separate Claims with appropriate evidence_status)
notes:                Baptism date and birth date are distinct facts with distinct evidence.
                      Conflating them is a common genealogical error.
```

---

### `baptised_at`

```
predicate_code:       baptised_at
label:                Baptised at
definition:           The place (typically a church, chapel, or temple) where this person was
                      baptised or underwent the equivalent initiation rite.
subject_types:        person
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      baptism
sensitivity_default:  family
recommended_evidence: church_register
valid_example:        Maria baptised_at [Place: St. Michael's Church, Vienna]
invalid_example:      Using baptised_at for a secular naming ceremony (use named_at)
notes:                None.
```

---

### `named_on`

```
predicate_code:       named_on
label:                Named on
definition:           The date of a formal secular or cultural naming ceremony.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      naming_ceremony
sensitivity_default:  family
recommended_evidence: personal_recollection, institutional_record
valid_example:        David named_on 1988-02-04 (baby naming ceremony)
invalid_example:      Using named_on for a baptism (use baptised_on)
notes:                Distinct from baptised_on. Use for non-religious naming traditions.
```

---

### `named_at`

```
predicate_code:       named_at
label:                Named at
definition:           The place where a formal secular or cultural naming ceremony occurred.
subject_types:        person
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      naming_ceremony
sensitivity_default:  family
recommended_evidence: personal_recollection
valid_example:        David named_at [Place: Community Hall, Saddle Lake]
invalid_example:      Using named_at for a baptism location (use baptised_at)
notes:                None.
```

---

### `buried_on`

```
predicate_code:       buried_on
label:                Buried on
definition:           The date of burial, interment, or cremation.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      burial_interment
sensitivity_default:  family
recommended_evidence: vital_record, church_register, newspaper
valid_example:        James buried_on 1942-08-10
invalid_example:      Using buried_on to imply a death date (these are separate claims)
notes:                None.
```

---

### `buried_at`

```
predicate_code:       buried_at
label:                Buried at
definition:           The place of burial, interment, or deposit of remains.
subject_types:        person
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      burial_interment
sensitivity_default:  family
recommended_evidence: vital_record, church_register, newspaper
valid_example:        James buried_at [Place: Brookwood Cemetery, Surrey]
invalid_example:      Using buried_at for the location where a death occurred (use died_at)
notes:                None.
```

---

### `married_on`

```
predicate_code:       married_on
label:                Married on
definition:           The date on which this person was married. This predicate is directional:
                      the subject is one party to the marriage. A separate married_to Claim
                      names the other party. A separate married_at Claim names the place.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no (each party may have a separate dated claim)
transitive:           no
temporal:             no
relationship_interaction: supports (supports a Marriage Relationship record)
generates_event:      marriage
sensitivity_default:  family
recommended_evidence: vital_record, church_register, official_document
valid_example:        Tracy married_on 2024-10-11
invalid_example:      Using married_on to record the date a marriage ended
                      (use relationship_ended_on on the Relationship record)
notes:                married_on does not create a Marriage Relationship by itself.
                      It supports an existing or pending Marriage Relationship record.
                      See RELATIONSHIP_TYPE_CATALOGUE.md for the Marriage Relationship type.
```

---

### `married_at`

```
predicate_code:       married_at
label:                Married at
definition:           The place where this person's marriage ceremony or civil registration
                      occurred.
subject_types:        person
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: supports
generates_event:      marriage
sensitivity_default:  family
recommended_evidence: vital_record, church_register
valid_example:        Tracy married_at [Place: Edmonton, Alberta]
invalid_example:      Using married_at with a date value (use married_on)
notes:                None.
```

---

### `married_to`

```
predicate_code:       married_to
label:                Married to
definition:           The person to whom this person was married. This predicate names the other
                      party to a marriage. It proposes a Marriage Relationship if none exists,
                      or supports an existing one.
subject_types:        person
range_type:           entity
object_entity_types:  person
inverse:              married_to (the predicate is semantically symmetric; model both directions
                      as separate Claims if needed, or use the Relationship as the canonical
                      record)
symmetric:            yes
transitive:           no
temporal:             yes
relationship_interaction: proposes
generates_event:      none (the event is captured via married_on / married_at)
sensitivity_default:  family
recommended_evidence: vital_record, church_register, personal_recollection
valid_example:        Tracy married_to [Person: Iryna Pikul] (effective 2024-10-11)
invalid_example:      Using married_to for a civil partnership (use in_civil_partnership_with)
                      Using married_to without temporal qualifiers when the marriage has ended
notes:                When this Claim is promoted to policy_approved, the system should verify
                      or create a Marriage Relationship record linking the two persons.
                      The Claim and the Relationship are retained and linked.
                      married_to is symmetric but recording both directions as Claims is
                      optional; the Relationship record carries the symmetric connection.
```

---

### `in_civil_partnership_with`

```
predicate_code:       in_civil_partnership_with
label:                In civil partnership with
definition:           The person with whom this person has or had a legally registered civil
                      partnership or equivalent (e.g., domestic partnership, registered
                      partnership, civil union). Civil partnerships must not be recorded using
                      married_to or the marriage RelationshipType.
subject_types:        person
range_type:           entity
object_entity_types:  person
inverse:              in_civil_partnership_with (symmetric; no separate inverse needed)
symmetric:            yes
transitive:           no
temporal:             yes
relationship_interaction: proposes (proposes a civil_partnership Relationship record)
generates_event:      civil_partnership_registration (proposed when documentary registration
                      evidence exists; always submission_origin = system_inferred_submission,
                      review_status = pending)
sensitivity_default:  family
recommended_evidence: vital_record, official_document, legal_document
valid_example:        Alex in_civil_partnership_with [Person: Jordan] (effective 2018-03-04)
invalid_example:      Using in_civil_partnership_with for a marriage
                      (use married_to for marriage, this predicate for civil partnership)
                      Routing civil partnerships through the marriage RelationshipType
notes:                The civil_partnership Relationship and the marriage Relationship are
                      distinct types. They must not be merged. The governing legal instrument,
                      jurisdiction, and recognition rules differ across jurisdictions and time
                      periods. The Claim carries temporal qualifiers to record the period during
                      which the partnership was registered and (if applicable) ended.
                      When promoted to policy_approved, the system should verify or create a
                      civil_partnership Relationship record. Do not use married_to as a
                      substitute even in jurisdictions that treat civil partnerships as marriages
                      for legal purposes; the factual distinction must be preserved in the record.
```

---

### `naturalized_on`

```
predicate_code:       naturalized_on
label:                Naturalized on
definition:           The date on which this person acquired citizenship or nationality through
                      a formal naturalization process.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      naturalization
sensitivity_default:  family
recommended_evidence: official_document, vital_record
valid_example:        Iryna naturalized_on 2026-04-01
invalid_example:      Using naturalized_on for a person who was born a citizen
notes:                None.
```

---

### `naturalized_at`

```
predicate_code:       naturalized_at
label:                Naturalized at
definition:           The jurisdiction or location where this person's naturalization was
                      formally processed or granted.
subject_types:        person
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      naturalization
sensitivity_default:  family
recommended_evidence: official_document
valid_example:        Iryna naturalized_at [Place: Edmonton, Alberta, Canada]
invalid_example:      Using naturalized_at with a date (use naturalized_on)
notes:                None.
```

---

### `adopted_on`

```
predicate_code:       adopted_on
label:                Adopted on
definition:           The date on which a legal or formal adoption was finalized.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: supports
generates_event:      adoption
sensitivity_default:  steward
recommended_evidence: official_document, legal_document
valid_example:        Samuel adopted_on 1978-03-21
invalid_example:      Using adopted_on for an informal fostering arrangement
                      (fostering is a Relationship type; adoption is a legal event)
notes:                Adoption is a legally significant event. Default sensitivity is steward
                      because adoption records carry elevated privacy risk. Steward may
                      downgrade to family for display to family members.
```

---

## Family 3 — Residence and Location

---

### `resided_at`

```
predicate_code:       resided_at
label:                Resided at
definition:           The place where this person or organization had their primary or
                      habitual residence during a given period.
subject_types:        person, organization
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      none
sensitivity_default:  family
recommended_evidence: census_record, vital_record, official_document, personal_recollection
valid_example:        Ivan resided_at [Place: Kyiv, Ukraine] (1990–2022)
invalid_example:      Using resided_at for a brief stay (use stayed_at for temporary presence)
                      Using resided_at without temporal qualifiers when residence is historical
notes:                Distinct from visited or stayed. Implies habitual, not temporary, presence.
```

---

### `stayed_at`

```
predicate_code:       stayed_at
label:                Stayed at
definition:           The place where this person was temporarily present, lodged, or
                      stationed during travel or displacement, without establishing residence.
subject_types:        person
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      none
sensitivity_default:  public
recommended_evidence: personal_recollection, institutional_record, ship_manifest
valid_example:        Refugees stayed_at [Place: Displaced Persons Camp, Linz] (1946–1948)
invalid_example:      Using stayed_at for a long-term residence (use resided_at)
notes:                Often relevant for immigration and wartime displacement records.
```

---

### `had_address`

```
predicate_code:       had_address
label:                Had address
definition:           A specific street or postal address at which this person or organization
                      was officially registered or located during a given period.
subject_types:        person, organization
range_type:           text
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      none
sensitivity_default:  steward
recommended_evidence: census_record, official_document, vital_record
valid_example:        Alice had_address "14 Elm Street, Toronto ON M4B 1A1" (1954–1963)
invalid_example:      Using had_address for a general area or city (use resided_at)
notes:                Specific addresses carry elevated privacy risk for living persons.
                      Default is steward; may be downgraded to family or public for
                      historical addresses of deceased persons at steward discretion.
```

---

### `location_at_time`

```
predicate_code:       location_at_time
label:                Location at time
definition:           The known or reported location of this entity at a specific point in time,
                      without implying residence or habitual presence.
subject_types:        person, organization, vessel
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      none
sensitivity_default:  public
recommended_evidence: ship_manifest, census_record, newspaper, personal_recollection
valid_example:        SS Metagama location_at_time [Place: Quebec City] on 1925-06-04
                      Anna location_at_time [Place: Auschwitz] in 1942 (approximate)
invalid_example:      Using location_at_time when the person established residence
                      (use resided_at); when the entity was there routinely (use resided_at
                      or member_of for organizations)
notes:                Useful for voyage ports of call, census snapshots, wartime locations.
```

---

## Family 4 — Migration and Travel

---

### `emigrated_from`

```
predicate_code:       emigrated_from
label:                Emigrated from
definition:           The place, country, or region that this person departed with intent to
                      resettle elsewhere.
subject_types:        person
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      emigration
sensitivity_default:  public
recommended_evidence: ship_manifest, official_document, personal_recollection
valid_example:        Hanna emigrated_from [Place: Galicia, Austria-Hungary] (circa 1905)
invalid_example:      Using emigrated_from for domestic relocation (no national border crossed)
notes:                emigrated_from and immigrated_to describe the same journey from different
                      reference points. Both may be recorded as separate Claims with separate
                      evidence.
```

---

### `emigrated_on`

```
predicate_code:       emigrated_on
label:                Emigrated on
definition:           The date of departure from the country or region of origin.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      emigration
sensitivity_default:  public
recommended_evidence: ship_manifest, official_document
valid_example:        Hanna emigrated_on 1905-04-17
invalid_example:      Using emigrated_on for the date of arrival (use immigrated_on)
notes:                None.
```

---

### `immigrated_to`

```
predicate_code:       immigrated_to
label:                Immigrated to
definition:           The country or region where this person arrived with intent to settle.
subject_types:        person
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      immigration
sensitivity_default:  public
recommended_evidence: ship_manifest, official_document, vital_record
valid_example:        Hanna immigrated_to [Place: Canada]
invalid_example:      Using immigrated_to for a temporary sojourn (use stayed_at)
notes:                None.
```

---

### `immigrated_on`

```
predicate_code:       immigrated_on
label:                Immigrated on
definition:           The date of formal arrival in the destination country.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      immigration
sensitivity_default:  public
recommended_evidence: ship_manifest, official_document
valid_example:        Hanna immigrated_on 1905-05-04
invalid_example:      Using immigrated_on for the departure date (use emigrated_on)
notes:                None.
```

---

### `departed_from`

```
predicate_code:       departed_from
label:                Departed from
definition:           The specific port, station, or departure point from which this person
                      set out on a documented journey. More specific than emigrated_from.
subject_types:        person
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      voyage
sensitivity_default:  public
recommended_evidence: ship_manifest, newspaper
valid_example:        Hanna departed_from [Place: Hamburg, Germany] on 1905-04-17
invalid_example:      Using departed_from for the country of origin rather than the port
                      (use emigrated_from for the country, departed_from for the port)
notes:                departed_from and arrived_at are useful for specific voyage segments.
```

---

### `departed_on`

```
predicate_code:       departed_on
label:                Departed on
definition:           The date of departure from a specific point on a documented journey.
subject_types:        person, vessel
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      voyage
sensitivity_default:  public
recommended_evidence: ship_manifest, newspaper
valid_example:        SS Hamburg departed_on 1905-04-17
invalid_example:      Using departed_on for emigration date without a specific departure point
notes:                None.
```

---

### `arrived_at`

```
predicate_code:       arrived_at
label:                Arrived at
definition:           The specific port, station, or arrival point where this person or vessel
                      arrived on a documented journey.
subject_types:        person, vessel
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      voyage
sensitivity_default:  public
recommended_evidence: ship_manifest, newspaper
valid_example:        Hanna arrived_at [Place: Quebec City, Canada]
invalid_example:      Using arrived_at for the destination country rather than the port
                      (use immigrated_to for the country)
notes:                None.
```

---

### `arrived_on`

```
predicate_code:       arrived_on
label:                Arrived on
definition:           The date of arrival at a specific port or destination.
subject_types:        person, vessel
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      voyage
sensitivity_default:  public
recommended_evidence: ship_manifest, newspaper
valid_example:        Hanna arrived_on 1905-05-04
invalid_example:      Using arrived_on without a corresponding arrived_at (the port must be
                      recorded as a separate Claim)
notes:                None.
```

---

### `travelled_on`

```
predicate_code:       travelled_on
label:                Travelled on
definition:           The vessel (ship, railway, aircraft) on which this person travelled
                      during a documented journey.
subject_types:        person
range_type:           entity
object_entity_types:  vessel
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      voyage
sensitivity_default:  public
recommended_evidence: ship_manifest, newspaper
valid_example:        Hanna travelled_on [Vessel: SS Pretoria] (April 1905)
invalid_example:      Using travelled_on for a place (use arrived_at / departed_from)
                      Using travelled_on without identifying the specific voyage when
                      the vessel made multiple voyages
notes:                When the specific voyage is known, temporal qualifiers disambiguate.
```

---

## Family 5 — Education

---

### `enrolled_at`

```
predicate_code:       enrolled_at
label:                Enrolled at
definition:           The educational institution where this person was enrolled as a student.
subject_types:        person
range_type:           entity
object_entity_types:  organization
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: proposes (proposes an organizational_membership Relationship)
generates_event:      none
sensitivity_default:  family
recommended_evidence: institutional_record, personal_recollection
valid_example:        Maria enrolled_at [Organization: University of Vienna] (1902–1906)
invalid_example:      Using enrolled_at for informal apprenticeship (use employed_by or
                      apprenticed_to)
notes:                None.
```

---

### `graduated_from`

```
predicate_code:       graduated_from
label:                Graduated from
definition:           The educational institution from which this person completed a formal
                      program of study.
subject_types:        person
range_type:           entity
object_entity_types:  organization
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      graduation
sensitivity_default:  public
recommended_evidence: institutional_record, newspaper
valid_example:        Maria graduated_from [Organization: University of Vienna]
invalid_example:      Using graduated_from for non-completion (record enrollment, not graduation)
notes:                None.
```

---

### `graduated_on`

```
predicate_code:       graduated_on
label:                Graduated on
definition:           The date on which this person's graduation was conferred.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      graduation
sensitivity_default:  public
recommended_evidence: institutional_record, newspaper
valid_example:        Maria graduated_on 1906-07-04
invalid_example:      Using graduated_on with a place value (use graduated_from)
notes:                None.
```

---

### `awarded_credential`

```
predicate_code:       awarded_credential
label:                Awarded credential
definition:           The name or type of credential, degree, diploma, certificate, or
                      qualification formally awarded to this person.
subject_types:        person
range_type:           text
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      graduation
sensitivity_default:  public
recommended_evidence: institutional_record, official_document
valid_example:        Maria awarded_credential "Doctor of Medicine" (1906)
invalid_example:      Using awarded_credential for an honour or decoration
                      (use awarded_honour)
notes:                None.
```

---

## Family 6 — Employment and Occupation

---

### `employed_by`

```
predicate_code:       employed_by
label:                Employed by
definition:           The organization or person by whom this person was employed in a
                      formal employment relationship. Does not include self-employment,
                      contracting, or military service.
subject_types:        person
range_type:           entity
object_entity_types:  organization, person
inverse:              employs (note: employs is defined but not listed as a required predicate
                      here; the Relationship record carries the symmetric connection)
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: proposes
generates_event:      employment_start
sensitivity_default:  public
recommended_evidence: institutional_record, official_document, personal_recollection
valid_example:        John employed_by [Organization: Canadian Pacific Railway] (1910–1935)
invalid_example:      Using employed_by for military service (use served_in)
                      Using employed_by for contract work (use contracted_to)
notes:                When this Claim is promoted to policy_approved, the system should verify
                      or create an Employment Relationship record.
```

---

### `contracted_to`

```
predicate_code:       contracted_to
label:                Contracted to
definition:           The organization or person with whom this person had a formal contractor
                      or self-employed service relationship, distinct from employment.
subject_types:        person
range_type:           entity
object_entity_types:  organization, person
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: proposes
generates_event:      none
sensitivity_default:  public
recommended_evidence: legal_document, personal_recollection, institutional_record
valid_example:        Tracy contracted_to [Organization: Edmonton Short Film Festival]
invalid_example:      Using contracted_to for formal employment with an employer (use employed_by)
notes:                None.
```

---

### `apprenticed_to`

```
predicate_code:       apprenticed_to
label:                Apprenticed to
definition:           This person served as an apprentice to the specified person (master or
                      mentor) or organization (apprenticeship host). Covers formal guild
                      apprenticeships, trade apprenticeships, craft apprenticeships, and
                      institutional apprenticeship programs. Does not include informal
                      learning or shadowing arrangements.
subject_types:        person
range_type:           entity
object_entity_types:  person, organization
inverse:              none (the Relationship record carries the inverse; a Person master
                      may be identified as role_b in the apprenticeship Relationship)
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: proposes (proposes an apprenticeship Relationship)
generates_event:      none
sensitivity_default:  public
recommended_evidence: guild_record, institutional_record, legal_document,
                      employment_record, personal_recollection
valid_example:        Thomas apprenticed_to [Person: James Whitmore, Carpenter] (1847–1851)
                      Anna apprenticed_to [Organization: Royal Academy of Music] (1902–1905)
invalid_example:      Using apprenticed_to for informal learning with no formal arrangement
                      Using enrolled_at for a formal apprenticeship (use apprenticed_to;
                      enrolled_at is for educational enrollment, not trades apprenticeship)
notes:                When the object is a Person, that person is the master or primary mentor.
                      When the object is an Organization, the organization is the apprenticeship
                      host. Both may be recorded as separate Claims if both are known.
                      Temporal qualifiers record the period of apprenticeship.
                      When promoted to policy_approved, the system should verify or create an
                      apprenticeship Relationship record.
```

---

### `had_occupation`

```
predicate_code:       had_occupation
label:                Had occupation
definition:           The general vocation, trade, or occupation of this person during a period,
                      independent of any specific employer.
subject_types:        person
range_type:           text
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      none
sensitivity_default:  public
recommended_evidence: census_record, vital_record, personal_recollection
valid_example:        Ivan had_occupation "Blacksmith" (1880–1920)
invalid_example:      Using had_occupation to record a specific employer (use employed_by)
notes:                Occupation text should use the terms as they appear in the source
                      record (e.g., "Laborer", "Farmer", "Widow") with the source language
                      preserved. Controlled occupation vocabulary is a future enhancement.
```

---

### `held_position`

```
predicate_code:       held_position
label:                Held position
definition:           The specific job title, role, or named position held by this person
                      within an employing or associated organization.
subject_types:        person
range_type:           text
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: describes (describes an Employment or organizational_membership Relationship)
generates_event:      none
sensitivity_default:  public
recommended_evidence: institutional_record, newspaper, official_document
valid_example:        Tracy held_position "Executive Director" at ESFF (2019–present)
invalid_example:      Using held_position without a corresponding employed_by or member_of Claim
                      (position requires a context organization)
notes:                held_position describes a role within a Relationship but does not itself
                      establish the Relationship. It should be accompanied by an employed_by
                      or member_of Claim referencing the same organization and period.
```

---

### `worked_at`

```
predicate_code:       worked_at
label:                Worked at
definition:           The physical place where this person performed their work, distinct from
                      the organization that employed them.
subject_types:        person
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      none
sensitivity_default:  public
recommended_evidence: census_record, institutional_record, personal_recollection
valid_example:        Anna worked_at [Place: Linen Mill, Derry] (1895–1910)
invalid_example:      Using worked_at for the employing organization (use employed_by)
notes:                Useful when the place of work is known but the employer is not, or
                      is different from the physical location (e.g., a government worker
                      posted to a specific location).
```

---

## Family 7 — Military Service

---

### `served_in`

```
predicate_code:       served_in
label:                Served in
definition:           The military unit, branch, or armed force in which this person served.
subject_types:        person
range_type:           entity
object_entity_types:  organization
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: proposes
generates_event:      military_service
sensitivity_default:  public
recommended_evidence: military_record, official_document, newspaper
valid_example:        Patrick served_in [Organization: 49th Battalion CEF] (1915–1918)
invalid_example:      Using served_in for a civilian organization (use member_of)
notes:                None.
```

---

### `enlisted_on`

```
predicate_code:       enlisted_on
label:                Enlisted on
definition:           The date on which this person formally enlisted, was conscripted, or
                      otherwise entered military service.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: supports
generates_event:      military_service
sensitivity_default:  public
recommended_evidence: military_record, official_document
valid_example:        Patrick enlisted_on 1915-08-11
invalid_example:      Using enlisted_on for the date of deployment or departure (record
                      those using departed_from / departed_on)
notes:                None.
```

---

### `enlisted_at`

```
predicate_code:       enlisted_at
label:                Enlisted at
definition:           The location where this person formally enlisted.
subject_types:        person
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: supports
generates_event:      military_service
sensitivity_default:  public
recommended_evidence: military_record
valid_example:        Patrick enlisted_at [Place: Edmonton, Alberta]
invalid_example:      Using enlisted_at with a date value (use enlisted_on)
notes:                None.
```

---

### `discharged_on`

```
predicate_code:       discharged_on
label:                Discharged on
definition:           The date on which this person was formally discharged, demobilized, or
                      otherwise concluded their period of military service.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: describes
generates_event:      military_service
sensitivity_default:  public
recommended_evidence: military_record, official_document
valid_example:        Patrick discharged_on 1919-03-15
invalid_example:      Using discharged_on to record the date a person died in service
                      (use died_on; discharge is a separate fact)
notes:                None.
```

---

### `held_rank`

```
predicate_code:       held_rank
label:                Held rank
definition:           The military rank held by this person during a specified period of service.
subject_types:        person
range_type:           text
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: describes
generates_event:      none
sensitivity_default:  public
recommended_evidence: military_record, official_document
valid_example:        Patrick held_rank "Corporal" (1916–1918)
invalid_example:      Using held_rank for a civilian title (use held_title)
notes:                Ranks vary across military traditions and time periods. Record the
                      rank as it appears in the source document.
```

---

### `served_at`

```
predicate_code:       served_at
label:                Served at
definition:           A place where this person was posted, stationed, or deployed during
                      their military service.
subject_types:        person
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: describes
generates_event:      none
sensitivity_default:  public
recommended_evidence: military_record, personal_recollection
valid_example:        Patrick served_at [Place: Ypres, Belgium] (1916)
invalid_example:      Using served_at for the location of enlistment (use enlisted_at)
notes:                None.
```

---

## Family 8 — Organizational and Community Participation

---

### `member_of`

```
predicate_code:       member_of
label:                Member of
definition:           This entity was or is a member of the specified organization or community.
subject_types:        person, organization
range_type:           entity
object_entity_types:  organization, community
inverse:              has_member (not a required predicate; the Relationship carries this)
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: proposes
generates_event:      none
sensitivity_default:  public
recommended_evidence: institutional_record, personal_recollection
valid_example:        Tracy member_of [Organization: Junior Chamber International] (1990–2005)
invalid_example:      Using member_of for employment (use employed_by)
                      Using member_of for military service (use served_in)
notes:                None.
```

---

### `joined_on`

```
predicate_code:       joined_on
label:                Joined on
definition:           The date on which this person formally joined an organization or community.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: supports
generates_event:      none
sensitivity_default:  public
recommended_evidence: institutional_record
valid_example:        Tracy joined_on 1992-03-01 (JCI Edmonton chapter)
invalid_example:      Using joined_on without a corresponding member_of Claim
notes:                Requires context of which organization; always pair with member_of.
```

---

### `left_on`

```
predicate_code:       left_on
label:                Left on
definition:           The date on which this person's membership in or association with an
                      organization or community ended.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: describes
generates_event:      none
sensitivity_default:  public
recommended_evidence: institutional_record, personal_recollection
valid_example:        Tracy left_on 2005-06-30 (JCI age limit reached)
invalid_example:      Using left_on without context of which organization
notes:                Describes the end of a membership Relationship, not a new Relationship.
```

---

### `associated_with`

```
predicate_code:       associated_with
label:                Associated with
definition:           A broad, undifferentiated association between this entity and another
                      entity or named thing. Used only when no more specific predicate applies
                      and the nature of the association is not yet determined.
subject_types:        person, organization, place, vessel, community, event_series
range_type:           entity
object_entity_types:  person, organization, place, vessel, community, event_series
inverse:              associated_with (symmetric by default)
symmetric:            yes (unless a directional context is explicitly documented in notes)
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      none
sensitivity_default:  family
recommended_evidence: any; an explanation or evidence reference is required
valid_example:        [Person: Heinrich] associated_with [Organization: Odessa Grain Exchange]
                      (1895; nature unclear — further research needed)
invalid_example:      Using associated_with when the nature of the association is known
                      (use employed_by, member_of, contracted_to, resided_at, or a more
                      specific predicate; associated_with is a last resort)
                      Using associated_with to assert a durable connection and treating it
                      as equivalent to a Relationship record
notes:                associated_with does NOT independently create a Relationship record and
                      must never be treated as doing so. It has relationship_interaction = none.
                      It is a placeholder Claim that:
                        (a) requires an explanation or evidence reference;
                        (b) defaults to review_status = pending;
                        (c) must be resolved by the reviewing steward into either:
                            — a more specific predicate (employed_by, member_of, etc.), or
                            — a typed Relationship record (professional_association,
                               friendship, community_membership, etc.), or
                            — a documented determination that no Relationship record
                               is warranted.
                      The reviewing steward will be prompted: "Determine whether this
                      association should be classified as friendship, professional association,
                      employment, community membership, travel companionship, correspondence,
                      or event co-participation."

PROMOTION RULE: A Claim using associated_with may not reach review_status = policy_approved
                      unless at least one of the following is true:
                        1. The reviewer explicitly confirms that the broad association is the
                           most accurate statement supported by the available evidence AND
                           records a written rationale in the broad_association_review_rationale
                           field (or equivalent ContestRecord / review note mechanism); or
                        2. The Claim is superseded_by a more specific Claim using a precise
                           predicate, or the Claim's subject is linked to a typed Relationship
                           record that captures the connection.
                      A Claim promoted to policy_approved without one of these conditions
                      being met is a governance violation. The application must enforce this
                      at the review submission layer, not just by convention.
                      The broad_association_review_rationale field is a text field added to
                      the Claim review workflow (not a direct Claim table field); it is
                      captured as part of the review action record.
```

---

### `ordained_in`

```
predicate_code:       ordained_in
label:                Ordained in
definition:           The religious body, denomination, or order in which this person was
                      ordained to ministry or priesthood.
subject_types:        person
range_type:           entity
object_entity_types:  organization, community
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: proposes
generates_event:      ordination
sensitivity_default:  public
recommended_evidence: church_register, institutional_record
valid_example:        Father O'Brien ordained_in [Organization: Roman Catholic Diocese of Toronto]
invalid_example:      Using ordained_in for secular professional licensing (use awarded_credential)
notes:                None.
```

---

### `ordained_on`

```
predicate_code:       ordained_on
label:                Ordained on
definition:           The date of ordination.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: supports
generates_event:      ordination
sensitivity_default:  public
recommended_evidence: church_register
valid_example:        Father O'Brien ordained_on 1923-06-15
invalid_example:      Using ordained_on with a place value (use ordained_at)
notes:                None.
```

---

### `ordained_at`

```
predicate_code:       ordained_at
label:                Ordained at
definition:           The place where this person's ordination ceremony took place.
subject_types:        person
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: supports
generates_event:      ordination
sensitivity_default:  public
recommended_evidence: church_register
valid_example:        Father O'Brien ordained_at [Place: St. Patrick's Cathedral, Dublin]
invalid_example:      Using ordained_at with a date value (use ordained_on)
notes:                None.
```

---

## Family 9 — Document Appearance

Claims in this family record that an entity appears in a specific document or source record. The actual Source record is linked via ClaimEvidence; the predicate records the nature of the appearance.

---

### `recorded_in`

```
predicate_code:       recorded_in
label:                Recorded in
definition:           This entity is named, listed, or otherwise recorded in a specific
                      document, register, or source. The document is identified by its
                      title or description; the Source record is linked via ClaimEvidence.
subject_types:        person, organization, place, vessel, community
range_type:           text
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      none
sensitivity_default:  public
recommended_evidence: (the Claim itself is derived from the evidence; no separate type required)
valid_example:        Ivan recorded_in "Canada, Ontario Census 1901, District 87"
invalid_example:      Using recorded_in as a substitute for a proper Source record;
                      the Source must be created and linked via ClaimEvidence
notes:                The value_text is a human-readable document reference.
                      The Source record — with full metadata — is the authoritative
                      evidential record. recorded_in is a convenience predicate for
                      document-appearance assertions that have not yet been fully sourced.
```

---

### `listed_as`

```
predicate_code:       listed_as
label:                Listed as
definition:           The name, designation, or identifier under which this entity appears
                      in a specific document or record. Captures the documentary spelling
                      or designation, which may differ from the entity's authoritative name.
subject_types:        person, organization, place, vessel
range_type:           text
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      none
sensitivity_default:  public
recommended_evidence: any source type
valid_example:        Ivan listed_as "Iwan Kowalski" in 1905 ship manifest
                      (documents a spelling variant without becoming an authoritative name)
invalid_example:      Using listed_as to create an alternative name record for a Person
                      (use PersonName with usage_type = documentary for persons)
notes:                listed_as preserves documentary evidence of how an entity was known
                      to a specific record-keeper. It does not assert that this is the
                      entity's name or correct designation.
```

---

### `documented_by`

```
predicate_code:       documented_by
label:                Documented by
definition:           The organization, institution, or authority that produced the document
                      in which this entity appears or that has official records about this entity.
subject_types:        person, organization, place, vessel
range_type:           entity
object_entity_types:  organization
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      none
sensitivity_default:  public
recommended_evidence: institutional_record
valid_example:        Patrick documented_by [Organization: Library and Archives Canada]
invalid_example:      Using documented_by for the source itself (use ClaimEvidence to link
                      the Claim to its Source record)
notes:                Useful for linking entities to the archival bodies that hold records
                      about them, to support future source discovery.
```

---

## Family 10 — Property, Custody, and Ownership

Ownership, custody, possession, and stewardship are distinct concepts and must not be collapsed.

- **Ownership:** Legal title to a property, asset, or entity.
- **Possession:** Physical holding or control, with or without legal title.
- **Custody:** Legal or formal responsibility for a person (child custody) or records.
- **Stewardship:** Care and responsibility for a heritage asset or records, typically without ownership.

---

### `owned`

```
predicate_code:       owned
label:                Owned
definition:           This entity held legal ownership of the specified property, asset, or
                      entity during a period.
subject_types:        person, organization
range_type:           entity
object_entity_types:  place, organization, vessel
inverse:              owned_by (not a required predicate; the Relationship carries it)
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: proposes
generates_event:      none
sensitivity_default:  family
recommended_evidence: legal_document, official_document
valid_example:        Heinrich owned [Place: Farm, Galicia] (1890–1905)
invalid_example:      Using owned for custody of a person (use custody_of)
                      Using owned for temporary possession (use possessed)
notes:                Ownership may be legally complex (shared ownership, undivided interest).
                      The notes field should capture such nuances.
```

---

### `possessed`

```
predicate_code:       possessed
label:                Possessed
definition:           This entity held or controlled a specific object or artifact, without
                      necessarily having legal title. Used for historical artefacts, heirlooms,
                      and objects passed within families.
subject_types:        person, organization
range_type:           text
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      none
sensitivity_default:  family
recommended_evidence: personal_recollection, legal_document
valid_example:        Babushka possessed "a silver samovar inherited from her mother" (1920–1965)
invalid_example:      Using possessed for legal ownership (use owned)
notes:                Range is text rather than entity because the possessed object is
                      often an Artifact, not an Entity. If the Artifact has been catalogued
                      as an Artifact record, the Claim should reference it by description.
                      A future ArtifactClaim junction may replace this pattern.
```

---

### `held_title_to`

```
predicate_code:       held_title_to
label:                Held title to
definition:           This entity held formal legal title (deed, grant, patent, or certificate
                      of title) to a specified place or property.
subject_types:        person, organization
range_type:           entity
object_entity_types:  place
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: proposes
generates_event:      none
sensitivity_default:  family
recommended_evidence: legal_document, official_document
valid_example:        John held_title_to [Place: Homestead, Saskatchewan] (1907–1932)
invalid_example:      Using held_title_to for informal possession (use possessed)
notes:                Distinguished from owned by the existence of a formal legal instrument.
```

---

### `custody_of`

```
predicate_code:       custody_of
label:                Had custody of
definition:           This entity had legal or formally recognized custody of a person.
                      Used for child custody arrangements, wardship, and official care orders.
                      Not for informal caregiving (use caregiving Relationship type).
subject_types:        person, organization
range_type:           entity
object_entity_types:  person
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: proposes
generates_event:      none
sensitivity_default:  steward
recommended_evidence: legal_document, official_document
valid_example:        Catherine custody_of [Person: James] (court order 1934–1940)
invalid_example:      Using custody_of for informal caregiving (use caregiving Relationship)
                      Using custody_of for ownership of an object (use held_title_to or possessed)
notes:                Default sensitivity steward due to the legal and privacy sensitivity of
                      custody records. Particularly sensitive for living persons.
```

---

### `held_in_stewardship`

```
predicate_code:       held_in_stewardship
label:                Held in stewardship
definition:           This entity had stewardship responsibility for a heritage asset, archival
                      collection, or trust property — meaning care and preservation without
                      necessarily holding legal title.
subject_types:        person, organization
range_type:           text
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      none
sensitivity_default:  public
recommended_evidence: institutional_record, legal_document
valid_example:        Historical Society held_in_stewardship "Mennonite Pioneer archives" (1945–present)
invalid_example:      Using held_in_stewardship for legal ownership (use owned)
                      Confusing with LifeBook stewardship — this predicate is for historical
                      records and heritage assets, not LifeBook governance roles
notes:                This predicate is for historical stewardship facts. LifeBook stewardship
                      roles are governed by AuthorityAssignment, not Claims.
```

---

## Family 11 — Titles and Honours

---

### `held_title`

```
predicate_code:       held_title
label:                Held title
definition:           An honorific, aristocratic, religious, or official title held by this person.
subject_types:        person
range_type:           text
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: none
generates_event:      none
sensitivity_default:  public
recommended_evidence: official_document, newspaper, institutional_record
valid_example:        Lady Margaret held_title "Countess of Strathmore" (1881–1904)
invalid_example:      Using held_title for a job position (use held_position)
                      Using held_title for an academic degree (use awarded_credential)
notes:                None.
```

---

### `awarded_honour`

```
predicate_code:       awarded_honour
label:                Awarded honour
definition:           A medal, decoration, prize, or formal recognition awarded to this person
                      by an official body.
subject_types:        person
range_type:           text
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      none
sensitivity_default:  public
recommended_evidence: official_document, newspaper, military_record
valid_example:        Sergeant Davies awarded_honour "Military Medal" (1917)
invalid_example:      Using awarded_honour for an academic credential (use awarded_credential)
notes:                None.
```

---

### `awarded_on`

```
predicate_code:       awarded_on
label:                Awarded on
definition:           The date on which an honour, prize, or credential was formally awarded.
subject_types:        person
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      none
sensitivity_default:  public
recommended_evidence: official_document, newspaper
valid_example:        Sergeant Davies awarded_on 1917-09-04 [the Military Medal]
invalid_example:      Using awarded_on without context of what was awarded
notes:                Requires context from a corresponding awarded_honour or awarded_credential
                      Claim for the same subject and period.
```

---

### `appointed_to`

```
predicate_code:       appointed_to
label:                Appointed to
definition:           A formal appointment to an office, position, or commission made by
                      an external authority.
subject_types:        person
range_type:           entity
object_entity_types:  organization
inverse:              none
symmetric:            no
transitive:           no
temporal:             yes
relationship_interaction: proposes
generates_event:      institutional_event
sensitivity_default:  public
recommended_evidence: official_document, newspaper
valid_example:        Judge Wilson appointed_to [Organization: Supreme Court of Canada] (1982)
invalid_example:      Using appointed_to for a hired position (use employed_by or held_position)
notes:                None.
```

---

## Family 12 — Relationship Qualification

Predicates in this family describe, date, or qualify a Relationship record. They are Claims about Relationships, not Claims that create Relationships. They require a corresponding Relationship record to be meaningful.

---

### `relationship_commenced_on`

```
predicate_code:       relationship_commenced_on
label:                Relationship commenced on
definition:           The date on which a specific Relationship formally or practically began.
                      This predicate provides a sourced, evidence-backed date for a Relationship's
                      effective_from field.
subject_types:        person, organization
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: describes
generates_event:      none
sensitivity_default:  family
recommended_evidence: vital_record, legal_document, institutional_record
valid_example:        [Employment Relationship: Tracy—ESFF] relationship_commenced_on 2019-01-15
invalid_example:      Using relationship_commenced_on without a corresponding Relationship record
notes:                This Claim is evidence for the Relationship.effective_from field. When
                      promoted, it should update or confirm the Relationship record's start date.
                      The subject_entity_id is one party to the Relationship.
```

---

### `relationship_ended_on`

```
predicate_code:       relationship_ended_on
label:                Relationship ended on
definition:           The date on which a specific Relationship formally or practically ended.
subject_types:        person, organization
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: describes
generates_event:      none
sensitivity_default:  family
recommended_evidence: vital_record, legal_document, institutional_record
valid_example:        [Marriage Relationship: James—Alice] relationship_ended_on 1943-11-08
                      (date of death of one party)
invalid_example:      Using relationship_ended_on to record a separation date
                      (separation is an Event; use the Event model and update Relationship.is_ongoing)
notes:                This Claim supports updating Relationship.effective_until and
                      Relationship.is_ongoing = false.
```

---

### `relationship_contested_on`

```
predicate_code:       relationship_contested_on
label:                Relationship contested on
definition:           The date on which a Relationship's existence, nature, or parties
                      became formally contested.
subject_types:        person, organization
range_type:           date
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: describes
generates_event:      none
sensitivity_default:  steward
recommended_evidence: legal_document, personal_recollection
valid_example:        [Parenthood Relationship] relationship_contested_on 1962-04-01
invalid_example:      Using relationship_contested_on without a ContestRecord being opened
notes:                This predicate should trigger or correspond to a ContestRecord.
                      Asserting this Claim with dispute_status = disputed requires a
                      ContestRecord to exist (per CONTENT_LAYER.md §11.3).
```

---

## Family 13 — Source and Artifact Associations

---

### `depicted_in`

```
predicate_code:       depicted_in
label:                Depicted in
definition:           This entity is depicted (visible, named, or identifiable) in a specific
                      Artifact. Used to link persons, places, and organizations to photographs,
                      artwork, maps, or other visual artifacts.
subject_types:        person, organization, place, vessel, community
range_type:           text
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      none
sensitivity_default:  family
recommended_evidence: photograph_metadata, personal_recollection
valid_example:        Grandmother depicted_in "Wedding photograph, 1924, back row left"
invalid_example:      Using depicted_in instead of NarrativeEntity for a narrative reference
                      (depicted_in is for visual artifacts; NarrativeEntity is for narratives)
notes:                The reference in value_text identifies the Artifact. The Artifact record
                      should be linked via ClaimEvidence. For persons, depiction in a photograph
                      carries privacy implications; default is family.
```

---

### `attributed_to`

```
predicate_code:       attributed_to
label:                Attributed to
definition:           A work, artifact, statement, or action is attributed to this entity as
                      its creator, author, speaker, or originating agent.
subject_types:        person, organization
range_type:           text
object_entity_types:  n/a
inverse:              none
symmetric:            no
transitive:           no
temporal:             no
relationship_interaction: none
generates_event:      none
sensitivity_default:  public
recommended_evidence: institutional_record, newspaper, personal_recollection
valid_example:        [Painting: "Village Scene, 1882"] attributed_to [Person: Nikolai Petrov]
invalid_example:      Using attributed_to as a certainty claim (attribution is often
                      evidence-dependent; use evidence_status to record confidence)
notes:                Attribution is a claim and should carry evidence_status to reflect
                      confidence. An attributed work that is disputed should have
                      dispute_status = disputed and a ContestRecord.
```

---

## Deprecation and Replacement Rules

When a predicate is deprecated:
1. Set `deprecated_at` to the deprecation date.
2. Set `replaced_by_predicate_id` to the replacement predicate.
3. Existing Claims using the deprecated predicate are not automatically migrated. A migration script must be reviewed and approved before moving existing Claim records.
4. New Claims must not be created with deprecated predicates. The application layer must enforce this.
5. The deprecated predicate remains in the catalogue and in the ClaimPredicate table permanently for referential integrity.

---

## Predicates not in this catalogue

The following types of assertions are handled by dedicated mechanisms and must not be expressed as Claim predicates:

| Type of assertion | Dedicated mechanism |
|---|---|
| Person's name | PersonName attribute table (PERSON_ATTRIBUTE_CATALOGUE.md) |
| Person's pronouns | PersonPronouns attribute table |
| Person's gender descriptor | PersonGenderDescriptor attribute table |
| Participation in an Event | EventParticipant record |
| A persistent connection between entities | Relationship record + RelationshipType |
| A LifeBook governance role | AuthorityAssignment record |
| A LifeBook stewardship relationship | LifeBook.steward_id and AuthorityAssignment |
| Cross-LifeBook access | CrossLifeBookAuthorization record |

---

## Summary count

| Family | Predicate count |
|---|---|
| 1. Identity and naming | 4 |
| 2. Vital events | 17 (`in_civil_partnership_with` added; count corrected from 16) |
| 3. Residence and location | 4 |
| 4. Migration and travel | 9 |
| 5. Education | 4 |
| 6. Employment and occupation | 6 (`apprenticed_to` added) |
| 7. Military service | 6 |
| 8. Organizational and community participation | 7 (`associated_with` added; count corrected from 8) |
| 9. Document appearance | 3 |
| 10. Property, custody, and ownership | 5 |
| 11. Titles and honours | 4 |
| 12. Relationship qualification | 3 |
| 13. Source and artifact associations | 2 |
| **Total** | **74** |

---

*Review this catalogue, then review RELATIONSHIP_TYPE_CATALOGUE.md, then read SEMANTIC_COLLISION_REPORT.md.*
