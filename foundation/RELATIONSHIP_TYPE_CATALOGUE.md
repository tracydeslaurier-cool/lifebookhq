# LifeBook Relationship Type Catalogue
**Version:** 0.1 Draft  
**Status:** Pre-migration governed specification  
**Depends on:** ANCHOR_MODELS.md, CONTENT_LAYER.md, CLAIM_PREDICATE_CATALOGUE.md  
**Produced:** 2026-07-23

---

## Governance rules

### What is a Relationship?

A Relationship is a persistent, typed connection between two entities. It has a defined beginning, may have an end, and carries evidence and provenance. It is the durable record of a connection.

A Relationship is **not**:
- An event (something that happened at a point in time)
- A claim about an event
- A state transition

### The event / relationship / claim distinction

| Category | Model | Example |
|---|---|---|
| Something that happened | Event record | A wedding ceremony |
| A durable connection between entities | Relationship record | A marriage |
| A fact that supports or qualifies the connection | Claim + ClaimEvidence | "Married on 11 October 2024" |
| A change in the status of a connection | State transition on the Relationship | `is_ongoing = false`, `effective_until = date` |
| A formal dispute about the connection | ContestRecord | "The parenthood of this child is contested" |

### State transitions are not Relationship types

The following are **not** relationship types. They are events, claims, or state transitions on existing Relationships:

| Item | What it actually is |
|---|---|
| Separation | An Event (`separation_divorce` event_type) + `is_ongoing` update on the Marriage Relationship |
| Divorce | An Event + `is_ongoing = false` + `effective_until` on Marriage |
| Resignation | An Event (`employment_end` event_type) + `is_ongoing = false` on Employment |
| Termination | Same as resignation, from employer's perspective |
| Death of one party | An Event (`death` event_type) + `is_ongoing = false` on all relevant Relationships |
| Dissolution of an organization | An Event (`institutional_event` event_type) + `is_ongoing = false` on membership Relationships |
| Guardianship lapsing | An Event or Claim + `is_ongoing = false` on Guardianship Relationship |

### Relationship and Claim interaction

A Claim does not independently create a durable Relationship. The governing rule is:

1. A relational Claim (e.g., `married_to`) **proposes** a Relationship if none exists, or **supports** an existing one.
2. When the Claim is reviewed and promoted to `policy_approved`, the system should verify or create the corresponding Relationship record.
3. The Claim is retained as evidence; the Relationship is the canonical record.
4. Both are linked. Neither supersedes the other.

### Subtypes must not be collapsed

The relationship types in this catalogue distinguish between biological parenthood, legal parenthood, adoptive parenthood, step-parenthood, foster relationships, guardianship, and caregiving. Each has distinct legal implications, distinct evidence requirements, and distinct authority consequences. Do not merge them without documented justification.

### Authority-conferring relationships

Some relationship types, when verified, may confer governance authority in LifeBook contexts. The `confers_authority` flag identifies these. Authority is conferred only through an AuthorityAssignment record — the Relationship record identifies the basis; the AuthorityAssignment specifies the scope.

---

## Entry format

```
type_code              — machine identifier; immutable
label                  — human-readable label
definition             — precise semantic definition
entity_a_types         — permitted entity types for entity_a
entity_b_types         — permitted entity types for entity_b
role_a                 — the role entity_a plays (e.g., "parent")
role_b                 — the role entity_b plays (e.g., "child")
inverse_mapping        — role_a from entity_b's perspective and role_b from entity_a's
symmetric              — yes | no
exclusive              — yes | no (can entity_a have multiple active relationships of this type?)
temporal               — yes | no
ending_mechanism       — event | claim | state_transition | all
default_sensitivity    — public | family | steward | restricted
default_review         — pending | human_reviewed | policy_approved
recommended_evidence   — list of source types
confers_authority      — yes | no
implies_relationship   — type_code of implied relationship, or none
valid_example          — one or more concrete examples
invalid_example        — one or more concrete misuses
notes                  — additional governance notes
```

---

## Group A — Biological and Genetic Kinship

---

### `biological_parent_child`

```
type_code:             biological_parent_child
label:                 Biological parent–child
definition:            A relationship of biological descent: entity_a is the biological parent
                       of entity_b. Records the genetic relationship, not the legal or social one.
                       A person may have a biological parent relationship with an entity without
                       that person ever having had a social or legal parenting relationship.
entity_a_types:        person
entity_b_types:        person
role_a:                biological parent
role_b:                biological child
inverse_mapping:       From entity_b: role_a = biological child, role_b = biological parent
symmetric:             no
exclusive:             no (a person has exactly two biological parents, but both are recorded
                       separately; entity_a may be biological parent to multiple children)
temporal:              no (biological parenthood does not end)
ending_mechanism:      none (biological relationship persists regardless of social/legal changes)
default_sensitivity:   family
default_review:        human_reviewed
recommended_evidence:  vital_record, dna_analysis, church_register, personal_recollection
confers_authority:     no (legal authority comes from legal_parent_child or guardianship)
implies_relationship:  none
valid_example:         [Person: Maria] biological_parent_child [Person: Josef]
                       — Maria is Josef's biological mother
invalid_example:       Using biological_parent_child to record legal parenthood when
                       the biological connection is unknown or not established
                       (use legal_parent_child with evidence of the legal relationship instead)
notes:                 Biological parenthood and legal parenthood may differ. Both should be
                       recorded when both are known. Uncertainty about biological parenthood
                       should be expressed via evidence_status, not avoided.
                       For donor conception or surrogacy, record what is known and what is
                       uncertain; do not substitute legal for biological or vice versa.
```

---

### `sibling`

```
type_code:             sibling
label:                 Sibling
definition:            Two persons share at least one biological or legal parent. The precise
                       nature of the shared parenthood (full sibling, half-sibling, adoptive
                       sibling) is captured in sub-types; this type is the general category.
entity_a_types:        person
entity_b_types:        person
role_a:                sibling
role_b:                sibling
inverse_mapping:       Symmetric; roles are identical from either direction
symmetric:             yes
exclusive:             no
temporal:              no
ending_mechanism:      none
default_sensitivity:   family
default_review:        human_reviewed
recommended_evidence:  vital_record, church_register, census_record, personal_recollection
confers_authority:     no
implies_relationship:  none
valid_example:         [Person: Anna] sibling [Person: Franz]
invalid_example:       Using sibling when the shared-parent basis is not established
                       (use with evidence_status = reported if the relationship is oral history)
notes:                 Use full_sibling or half_sibling when the shared-parent basis is known.
                       Sibling is appropriate when the nature of the shared parentage is unknown
                       or when the relationship is recognized in a social/cultural context
                       regardless of biological basis.
```

---

### `full_sibling`

```
type_code:             full_sibling
label:                 Full sibling
definition:            Two persons share both biological parents.
entity_a_types:        person
entity_b_types:        person
role_a:                full sibling
role_b:                full sibling
inverse_mapping:       Symmetric
symmetric:             yes
exclusive:             no
temporal:              no
ending_mechanism:      none
default_sensitivity:   family
default_review:        human_reviewed
recommended_evidence:  vital_record, church_register, dna_analysis
confers_authority:     no
implies_relationship:  sibling
valid_example:         [Person: Eva] full_sibling [Person: Karl] — same mother, same father
invalid_example:       Using full_sibling when only one shared parent is established
notes:                 implies_relationship = sibling means that a full_sibling record also
                       constitutes evidence for a sibling record between the same parties.
```

---

### `half_sibling`

```
type_code:             half_sibling
label:                 Half-sibling
definition:            Two persons share exactly one biological parent.
entity_a_types:        person
entity_b_types:        person
role_a:                half-sibling
role_b:                half-sibling
inverse_mapping:       Symmetric
symmetric:             yes
exclusive:             no
temporal:              no
ending_mechanism:      none
default_sensitivity:   family
default_review:        human_reviewed
recommended_evidence:  vital_record, church_register, dna_analysis, personal_recollection
confers_authority:     no
implies_relationship:  sibling
valid_example:         [Person: Heinrich] half_sibling [Person: Else] — shared father, different mothers
invalid_example:       Using half_sibling when the basis of the shared parent is not established
notes:                 Half-sibling relationships are often discovered through genealogical
                       research or DNA analysis. evidence_status should reflect the basis.
```

---

## Group B — Legal and Social Parenthood

---

### `legal_parent_child`

```
type_code:             legal_parent_child
label:                 Legal parent–child
definition:            Entity_a is the legal parent of entity_b, as recognized by the applicable
                       legal jurisdiction. Legal parenthood may arise through birth registration,
                       adoption, recognition, or court order, and may be distinct from
                       biological parenthood.
entity_a_types:        person
entity_b_types:        person
role_a:                legal parent
role_b:                legal child
inverse_mapping:       From entity_b: role_a = legal child, role_b = legal parent
symmetric:             no
exclusive:             no (a child may have two legal parents; a person may be legal parent
                       to multiple children)
temporal:              yes (legal parenthood may have a start date; it may be changed by
                       court order, though it rarely ends)
ending_mechanism:      event (adoption or court order may transfer or terminate legal parenthood)
default_sensitivity:   family
default_review:        human_reviewed
recommended_evidence:  vital_record, official_document, legal_document
confers_authority:     yes (legal parent may hold AuthorityAssignment for minor child)
implies_relationship:  none
valid_example:         [Person: Catherine] legal_parent_child [Person: James]
                       — Catherine is James's registered legal mother
invalid_example:       Using legal_parent_child when only biological relationship is established
                       and no legal recognition exists
notes:                 Legal parenthood is jurisdiction-specific. The applicable Jurisdiction
                       record should be linked. Historical legal parenthood may reflect
                       social and legal norms that differ from contemporary standards.
```

---

### `adoptive_parent_child`

```
type_code:             adoptive_parent_child
label:                 Adoptive parent–child
definition:            Entity_a adopted entity_b through a formal legal process, creating a
                       legal parent–child relationship that replaces or supplements any prior
                       legal parenthood. Distinct from fostering, guardianship, and informal care.
entity_a_types:        person
entity_b_types:        person
role_a:                adoptive parent
role_b:                adopted child
inverse_mapping:       From entity_b: role_a = adopted child, role_b = adoptive parent
symmetric:             no
exclusive:             no
temporal:              no (once finalized, adoption is permanent)
ending_mechanism:      none (legal adoption does not end, though rare annulments exist)
default_sensitivity:   steward
default_review:        human_reviewed
recommended_evidence:  legal_document, official_document
confers_authority:     yes (adoptive parent holds full legal authority equivalent to legal_parent_child)
implies_relationship:  legal_parent_child
valid_example:         [Person: Robert and Joan] adoptive_parent_child [Person: Samuel]
invalid_example:       Using adoptive_parent_child for informal adoption or customary adoption
                       without legal proceedings (use foster_parent_child or a notes-qualified
                       sibling/family Relationship instead, with evidence_status = reported)
notes:                 Default sensitivity steward because adoption records carry elevated
                       privacy risk. Some jurisdictions seal adoption records; others open them.
                       The applicable Jurisdiction must be referenced.
                       Implies legal_parent_child: an adoptive parent is also a legal parent.
```

---

### `step_parent_child`

```
type_code:             step_parent_child
label:                 Step-parent–child
definition:            Entity_a is the spouse or partner of entity_b's legal or biological
                       parent and has a recognized social step-parenting role. Step-parenthood
                       is a social role; it does not automatically create legal parenthood.
entity_a_types:        person
entity_b_types:        person
role_a:                step-parent
role_b:                step-child
inverse_mapping:       From entity_b: role_a = step-child, role_b = step-parent
symmetric:             no
exclusive:             no
temporal:              yes (step-parenthood begins with the relevant marriage/partnership
                       and may end with its dissolution)
ending_mechanism:      state_transition (ends when the underlying marriage/partnership ends,
                       unless the step-parent independently adopts)
default_sensitivity:   family
default_review:        pending
recommended_evidence:  personal_recollection, vital_record, census_record
confers_authority:     no (unless also accompanied by legal guardianship)
implies_relationship:  none
valid_example:         [Person: David] step_parent_child [Person: Emma]
                       — David married Emma's mother; Emma is David's step-daughter
invalid_example:       Using step_parent_child to imply legal parenthood (use legal_parent_child
                       or adoptive_parent_child for legal relationships)
notes:                 Step-parenthood is culturally variable. Evidence may be oral history
                       or census records listing "step-children". Cultural recognition of
                       step-parenting may predate legal recognition.
```

---

### `foster_parent_child`

```
type_code:             foster_parent_child
label:                 Foster parent–child
definition:            Entity_a provided formal or informal foster care to entity_b. Fostering
                       is distinct from adoption (no permanent legal transfer of parenthood)
                       and from guardianship (which carries legal authority). It may be
                       formalized through a state or agency arrangement, or informal within
                       extended families or communities.
entity_a_types:        person, organization
entity_b_types:        person
role_a:                foster parent / foster carer
role_b:                foster child
inverse_mapping:       From entity_b: role_a = foster child, role_b = foster parent
symmetric:             no
exclusive:             no
temporal:              yes
ending_mechanism:      event (foster placement ends with a specific event or order)
default_sensitivity:   steward
default_review:        human_reviewed
recommended_evidence:  legal_document, institutional_record, personal_recollection
confers_authority:     no (authority comes from formal guardianship if granted)
implies_relationship:  none
valid_example:         [Person: Mary and Patrick] foster_parent_child [Person: Thomas] (1953–1958)
invalid_example:       Using foster_parent_child for informal adoption within a family where
                       there was no formal fostering arrangement (record with evidence_status
                       = reported and notes explaining the informal nature)
notes:                 Default sensitivity steward due to child welfare privacy concerns.
                       Institutional foster care (by an organization) is also valid.
```

---

## Group C — Guardianship and Care

---

### `guardianship`

```
type_code:             guardianship
label:                 Guardianship
definition:            Entity_a holds legal guardianship of entity_b — a formal legal authority
                       to make decisions on behalf of entity_b. Guardianship may be of a minor,
                       of an adult with diminished capacity, or may be granted by court order
                       in specific circumstances.
entity_a_types:        person, organization
entity_b_types:        person
role_a:                guardian
role_b:                ward
inverse_mapping:       From entity_b: role_a = ward, role_b = guardian
symmetric:             no
exclusive:             no (a person may have multiple guardians under some arrangements)
temporal:              yes
ending_mechanism:      event (majority, court order, death of guardian, restoration of capacity)
default_sensitivity:   steward
default_review:        human_reviewed
recommended_evidence:  legal_document, official_document
confers_authority:     yes (guardian holds AuthorityAssignment for ward in LifeBook context)
implies_relationship:  none
valid_example:         [Organization: Children's Aid Society] guardianship [Person: Margaret] (1931–1947)
invalid_example:       Using guardianship for informal family care without legal authority
                       (use caregiving or foster_parent_child)
notes:                 Guardianship authority in LifeBook is reflected through AuthorityAssignment.
                       The Relationship documents the historical fact; the AuthorityAssignment
                       specifies what the guardian may do in the system.
```

---

### `caregiving`

```
type_code:             caregiving
label:                 Caregiving
definition:            Entity_a provided regular care, support, or assistance to entity_b
                       without formal legal authority. Includes informal family caregiving,
                       paid care without legal guardianship, and community care arrangements.
entity_a_types:        person, organization
entity_b_types:        person
role_a:                caregiver
role_b:                care recipient
inverse_mapping:       From entity_b: role_a = care recipient, role_b = caregiver
symmetric:             no
exclusive:             no
temporal:              yes
ending_mechanism:      state_transition (ends when care arrangement ends)
default_sensitivity:   family
default_review:        pending
recommended_evidence:  personal_recollection, institutional_record
confers_authority:     no
implies_relationship:  none
valid_example:         [Person: Daughter] caregiving [Person: Elderly Mother] (2015–2023)
invalid_example:       Using caregiving for formal legal guardianship (use guardianship)
notes:                 Caregiving is not interchangeable with guardianship, custody, or
                       legal representative status. It carries no governance authority.
```

---

## Group D — Marriage and Partnership

---

### `marriage`

```
type_code:             marriage
label:                 Marriage
definition:            Entity_a and entity_b are or were in a legally or ceremonially recognized
                       marriage. The specific ceremony, date, and place are captured as Claims
                       (married_on, married_at) and Events (marriage event_type). The Relationship
                       record is the durable record of the connection.
entity_a_types:        person
entity_b_types:        person
role_a:                spouse
role_b:                spouse
inverse_mapping:       Symmetric; roles are identical
symmetric:             yes
exclusive:             yes (for most jurisdictions; a person may not have two concurrent
                       legal marriages — though polygamous marriages existed historically
                       and must be representable; the exclusive field may be overridden
                       by jurisdiction context)
temporal:              yes
ending_mechanism:      event (marriage ends through death of a spouse, divorce, or annulment;
                       each is an Event record; the Relationship.is_ongoing is then set to false
                       and effective_until is recorded)
default_sensitivity:   family
default_review:        human_reviewed
recommended_evidence:  vital_record, church_register, official_document
confers_authority:     no (a spouse does not automatically hold LifeBook governance authority)
implies_relationship:  none
valid_example:         [Person: Tracy] marriage [Person: Iryna] — effective 2024-10-11
invalid_example:       Using marriage to record a civil partnership (use civil_partnership)
                       Using marriage when only an intention to marry is documented
                       (use evidence_status = reported)
notes:                 Separation and divorce are Events + state transitions, not separate
                       Relationship types. When a marriage ends, create the appropriate Event
                       and set Relationship.is_ongoing = false and effective_until.
                       Historically, polygamous marriages in some cultural traditions should
                       be recorded accurately rather than collapsed or omitted. The exclusive
                       flag reflects a default that may vary by jurisdiction and period.
```

---

### `civil_partnership`

```
type_code:             civil_partnership
label:                 Civil partnership
definition:            Entity_a and entity_b are or were in a legally recognized civil
                       partnership, domestic partnership, or registered partnership arrangement
                       distinct from marriage.
entity_a_types:        person
entity_b_types:        person
role_a:                civil partner
role_b:                civil partner
inverse_mapping:       Symmetric
symmetric:             yes
exclusive:             yes (per most jurisdictions)
temporal:              yes
ending_mechanism:      event (ends through dissolution, death, or legal termination)
default_sensitivity:   family
default_review:        human_reviewed
recommended_evidence:  official_document, legal_document
confers_authority:     no
implies_relationship:  none
valid_example:         [Person: A] civil_partnership [Person: B] — registered 2005, Canada
invalid_example:       Using civil_partnership for an unregistered cohabiting relationship
                       (use domestic_partnership)
notes:                 Civil partnership legislation varies by jurisdiction and year.
                       The Jurisdiction record should be linked to this Relationship.
```

---

### `domestic_partnership`

```
type_code:             domestic_partnership
label:                 Domestic partnership / Cohabitation
definition:            Entity_a and entity_b lived together as partners in a committed
                       domestic arrangement without legal marriage or civil partnership.
entity_a_types:        person
entity_b_types:        person
role_a:                partner
role_b:                partner
inverse_mapping:       Symmetric
symmetric:             yes
exclusive:             no
temporal:              yes
ending_mechanism:      state_transition (ends when cohabitation ends; no formal legal event required)
default_sensitivity:   family
default_review:        pending
recommended_evidence:  personal_recollection, census_record, institutional_record
confers_authority:     no
implies_relationship:  none
valid_example:         [Person: A] domestic_partnership [Person: B] (1978–1985)
invalid_example:       Using domestic_partnership for a legally registered civil partnership
                       (use civil_partnership)
notes:                 Cohabitation without legal recognition may have legal implications
                       (common-law status) depending on jurisdiction and duration. These
                       implications are not inferred from the Relationship record alone.
```

---

## Group E — Employment and Economic Relationships

---

### `employment`

```
type_code:             employment
label:                 Employment
definition:            Entity_a was employed by entity_b in a formal employment relationship,
                       with defined duties, compensation, and legal obligations on both sides.
                       Entity_a is the employee; entity_b is the employer.
entity_a_types:        person
entity_b_types:        organization, person
role_a:                employee
role_b:                employer
inverse_mapping:       From entity_b: role_a = employer, role_b = employee
symmetric:             no
exclusive:             no (a person may hold multiple concurrent employments)
temporal:              yes
ending_mechanism:      event (employment_end event_type) + state_transition
default_sensitivity:   public
default_review:        pending
recommended_evidence:  institutional_record, official_document, personal_recollection
confers_authority:     no
implies_relationship:  none
valid_example:         [Person: Tracy] employment [Organization: ESFF] — employee
invalid_example:       Using employment for self-employment (record via had_occupation
                       or contracted_to instead)
                       Using employment for military service (use military_service)
notes:                 Job title and role are recorded as Claims (held_position) against one
                       party to this Relationship. The Relationship captures the fact of
                       employment; Claims capture the details.
```

---

### `contractor`

```
type_code:             contractor
label:                 Contractor / Service relationship
definition:            Entity_a provided services to entity_b as a self-employed contractor,
                       consultant, or independent service provider, without the legal status
                       of an employee.
entity_a_types:        person, organization
entity_b_types:        organization, person
role_a:                contractor / service provider
role_b:                client / commissioning party
inverse_mapping:       From entity_b: role_a = client, role_b = contractor
symmetric:             no
exclusive:             no
temporal:              yes
ending_mechanism:      state_transition
default_sensitivity:   public
default_review:        pending
recommended_evidence:  legal_document, personal_recollection, institutional_record
confers_authority:     no
implies_relationship:  none
valid_example:         [Person: Tracy] contractor [Organization: Otipemisiwak Government, District 9]
invalid_example:       Using contractor for employment with regular wages and employer deductions
                       (use employment)
notes:                 The contractor/employee distinction is legally significant and
                       jurisdiction-specific. The available evidence may not always resolve it;
                       use evidence_status and notes to record uncertainty.
```

---

### `apprenticeship`

```
type_code:             apprenticeship
label:                 Apprenticeship
definition:            Entity_a was formally apprenticed to entity_b for the purpose of learning
                       a trade or skill, typically under a structured arrangement with defined
                       terms.
entity_a_types:        person
entity_b_types:        person, organization
role_a:                apprentice
role_b:                master / trainer
inverse_mapping:       From entity_b: role_a = master, role_b = apprentice
symmetric:             no
exclusive:             no
temporal:              yes
ending_mechanism:      event (completion or termination of the apprenticeship)
default_sensitivity:   public
default_review:        pending
recommended_evidence:  legal_document, institutional_record, church_register
confers_authority:     no
implies_relationship:  none
valid_example:         [Person: Johann] apprenticeship [Person: Master Weaver Schulz] (1832–1836)
invalid_example:       Using apprenticeship for an informal learning relationship
                       (use mentorship instead)
notes:                 Formal apprenticeships in historical periods were often legally bound
                       and documented in guild or church records.
```

---

## Group F — Military and Institutional Association

---

### `military_service`

```
type_code:             military_service
label:                 Military service
definition:            Entity_a served in entity_b (a military unit, branch, or armed force).
                       This is a membership relationship in a military context.
entity_a_types:        person
entity_b_types:        organization
role_a:                service member
role_b:                military unit / armed force
inverse_mapping:       From entity_b: role_a = military unit, role_b = service member
symmetric:             no
exclusive:             no (a person may serve in multiple units concurrently or sequentially)
temporal:              yes
ending_mechanism:      event (discharge, death, end of conscription)
default_sensitivity:   public
default_review:        pending
recommended_evidence:  military_record, official_document, newspaper
confers_authority:     no
implies_relationship:  none
valid_example:         [Person: Patrick] military_service [Organization: 49th Battalion CEF]
invalid_example:       Using military_service for civilian support roles in wartime
                       (use employment or organizational_membership)
notes:                 None.
```

---

### `military_unit_association`

```
type_code:             military_unit_association
label:                 Military unit association
definition:            Entity_a and entity_b (both persons) served together in the same
                       military unit, campaign, or posting, creating a documented association
                       without necessarily establishing a personal relationship.
entity_a_types:        person
entity_b_types:        person
role_a:                comrade / fellow service member
role_b:                comrade / fellow service member
inverse_mapping:       Symmetric
symmetric:             yes
exclusive:             no
temporal:              yes
ending_mechanism:      state_transition
default_sensitivity:   public
default_review:        pending
recommended_evidence:  military_record, personal_recollection
confers_authority:     no
implies_relationship:  none
valid_example:         [Person: Patrick] military_unit_association [Person: James] — both served in
                       49th Battalion CEF, 1916
invalid_example:       Using military_unit_association to imply a close personal friendship
                       (evidence of association does not establish friendship)
notes:                 Derived from shared military service records. Do not create this
                       Relationship unless documentary evidence places both persons in the
                       same unit at the same time.
```

---

### `organizational_membership`

```
type_code:             organizational_membership
label:                 Organizational membership
definition:            Entity_a was or is a member of entity_b (an organization, institution,
                       or formal body). Covers civic organizations, professional associations,
                       church congregations, clubs, and other formal membership structures.
entity_a_types:        person, organization
entity_b_types:        organization
role_a:                member
role_b:                organization
inverse_mapping:       From entity_b: role_a = organization, role_b = member
symmetric:             no
exclusive:             no
temporal:              yes
ending_mechanism:      state_transition (membership ends; may be recorded via left_on Claim)
default_sensitivity:   public
default_review:        pending
recommended_evidence:  institutional_record, personal_recollection
confers_authority:     no
implies_relationship:  none
valid_example:         [Person: Tracy] organizational_membership [Organization: Junior Achievement NAlberta]
invalid_example:       Using organizational_membership for employment (use employment)
                       Using organizational_membership for military service (use military_service)
notes:                 Role within the organization (e.g., President, Board Director) is
                       captured as a held_position Claim, not as a Relationship variation.
```

---

### `community_membership`

```
type_code:             community_membership
label:                 Community membership
definition:            Entity_a was or is a recognized member of entity_b, a community defined
                       by shared identity, geography, religion, ethnicity, or practice.
                       Distinct from organizational_membership in that communities often lack
                       formal membership rosters and recognize membership through cultural
                       and social criteria.
entity_a_types:        person
entity_b_types:        community
role_a:                community member
role_b:                community
inverse_mapping:       From entity_b: role_a = community, role_b = community member
symmetric:             no
exclusive:             no
temporal:              yes
ending_mechanism:      state_transition
default_sensitivity:   family
default_review:        pending
recommended_evidence:  personal_recollection, church_register, institutional_record
confers_authority:     no
implies_relationship:  none
valid_example:         [Person: Helena] community_membership [Community: Ukrainian diaspora, Edmonton]
invalid_example:       Using community_membership for formal organizational membership
                       (use organizational_membership for bodies with membership rolls)
notes:                 For indigenous communities, community membership may have specific
                       legal and governance meaning (e.g., First Nation band membership).
                       The Jurisdiction record should be linked. Community authority for
                       culturally governed information is a separate governance concern handled
                       in AI_CONTEXT_BROKER.md §4.5.
```

---

## Group G — Personal and Social Relationships

---

### `friendship`

```
type_code:             friendship
label:                 Friendship
definition:            Entity_a and entity_b shared a recognized personal friendship. Evidence
                       is typically oral, photographic, or documented in correspondence.
entity_a_types:        person
entity_b_types:        person
role_a:                friend
role_b:                friend
inverse_mapping:       Symmetric
symmetric:             yes
exclusive:             no
temporal:              yes
ending_mechanism:      state_transition
default_sensitivity:   family
default_review:        pending
recommended_evidence:  personal_recollection, letter_correspondence, photograph_metadata
confers_authority:     no
implies_relationship:  none
valid_example:         [Person: James] friendship [Person: Robert] — childhood friends, confirmed
                       by family recollection and photographs
invalid_example:       Using friendship to record a professional or collegial relationship
                       without evidence of personal friendship (use professional_association)
notes:                 Friendship is one of the more subjectively defined relationship types.
                       Evidence should be explicit and sourced; do not infer friendship from
                       co-residence, co-employment, or proximity alone.
```

---

### `mentorship`

```
type_code:             mentorship
label:                 Mentorship
definition:            Entity_a provided guidance, teaching, or professional mentorship to
                       entity_b in an informal or semi-formal capacity. Distinct from
                       apprenticeship (which is formal and contractual) and employment.
entity_a_types:        person
entity_b_types:        person
role_a:                mentor
role_b:                mentee
inverse_mapping:       From entity_b: role_a = mentee, role_b = mentor
symmetric:             no
exclusive:             no
temporal:              yes
ending_mechanism:      state_transition
default_sensitivity:   family
default_review:        pending
recommended_evidence:  personal_recollection, letter_correspondence, institutional_record
confers_authority:     no
implies_relationship:  none
valid_example:         [Person: Professor Klein] mentorship [Person: Maria] — supervised doctoral work
invalid_example:       Using mentorship for formal instruction (use enrolled_at Claim and
                       organizational_membership for the institution)
notes:                 None.
```

---

### `professional_association`

```
type_code:             professional_association
label:                 Professional association
definition:            Entity_a and entity_b had a recognized professional or collegial
                       relationship through shared work, research, or field, without the
                       specifics of employment, contracting, or membership.
entity_a_types:        person
entity_b_types:        person, organization
role_a:                associate / colleague
role_b:                associate / colleague
inverse_mapping:       Symmetric for person–person; asymmetric for person–organization
symmetric:             yes (for person–person)
exclusive:             no
temporal:              yes
ending_mechanism:      state_transition
default_sensitivity:   public
default_review:        pending
recommended_evidence:  institutional_record, newspaper, personal_recollection
confers_authority:     no
implies_relationship:  none
valid_example:         [Person: Dr. Smith] professional_association [Person: Dr. Jones]
                       — co-published research, 1934
invalid_example:       Using professional_association as a vague catch-all for any
                       connection documented in records
notes:                 Use this type when a specific professional connection is documented
                       but does not fit employment, membership, or mentorship.
```

---

## Group H — Property and Asset Relationships

Ownership, custody, possession, and stewardship are distinct. See also CLAIM_PREDICATE_CATALOGUE.md Family 10 for the predicate counterparts.

---

### `ownership`

```
type_code:             ownership
label:                 Ownership
definition:            Entity_a legally owned entity_b (a place, vessel, organization, or
                       other asset) during a specified period.
entity_a_types:        person, organization
entity_b_types:        place, vessel, organization
role_a:                owner
role_b:                owned property / asset
inverse_mapping:       From entity_b: role_a = property, role_b = owner
symmetric:             no
exclusive:             no (co-ownership is permitted; multiple concurrent owners are recorded
                       as separate Relationship records)
temporal:              yes
ending_mechanism:      event or claim (transfer of title is an Event; sale is documented
                       by Claims)
default_sensitivity:   public
default_review:        pending
recommended_evidence:  legal_document, official_document
confers_authority:     no
implies_relationship:  none
valid_example:         [Person: Heinrich] ownership [Place: Farm, Galicia] (1890–1905)
invalid_example:       Using ownership for possession without legal title (use possession)
                       Using ownership for stewardship of records (use historical_stewardship)
notes:                 Shared or undivided ownership should be noted. The notes field on the
                       Relationship record should capture the ownership structure.
```

---

### `possession`

```
type_code:             possession
label:                 Possession
definition:            Entity_a held or controlled entity_b (a place, artifact, or asset)
                       without necessarily having legal title during a specified period.
entity_a_types:        person, organization
entity_b_types:        place, vessel
role_a:                possessor
role_b:                possessed asset
inverse_mapping:       From entity_b: role_a = asset, role_b = possessor
symmetric:             no
exclusive:             no
temporal:              yes
ending_mechanism:      state_transition
default_sensitivity:   family
default_review:        pending
recommended_evidence:  legal_document, personal_recollection, institutional_record
confers_authority:     no
implies_relationship:  none
valid_example:         [Organization: Occupying forces] possession [Place: Estate, 1939–1945]
invalid_example:       Using possession for legal ownership (use ownership)
notes:                 Possession without title is historically significant in contexts
                       of displacement, occupation, and inheritance disputes.
```

---

### `custody_of_person`

```
type_code:             custody_of_person
label:                 Custody of person
definition:            Entity_a held legal or formally recognized custody of entity_b (a person).
                       Distinct from guardianship (which is broader decision-making authority)
                       and from physical care (which is caregiving).
entity_a_types:        person, organization
entity_b_types:        person
role_a:                custodial party
role_b:                person in custody
inverse_mapping:       From entity_b: role_a = person in custody, role_b = custodial party
symmetric:             no
exclusive:             no (split custody arrangements have two custodial parties)
temporal:              yes
ending_mechanism:      event (court order, majority, death)
default_sensitivity:   steward
default_review:        human_reviewed
recommended_evidence:  legal_document, official_document
confers_authority:     yes (legal custodian may hold AuthorityAssignment in LifeBook)
implies_relationship:  none
valid_example:         [Person: Marie] custody_of_person [Person: Charles] — court order 1952
invalid_example:       Using custody_of_person for physical caregiving without legal status
                       (use caregiving)
notes:                 Legal custody and physical custody may be held by different parties.
                       Record both if known; note which type applies.
```

---

### `historical_stewardship`

```
type_code:             historical_stewardship
label:                 Historical stewardship
definition:            Entity_a held care, preservation, and responsibility for a heritage asset,
                       archival collection, or cultural property, without necessarily owning it.
                       This is a relationship to a collection or cultural asset, not to a LifeBook.
entity_a_types:        person, organization
entity_b_types:        organization
role_a:                steward of records / heritage
role_b:                collection or asset held
inverse_mapping:       From entity_b: role_a = asset, role_b = steward
symmetric:             no
exclusive:             no
temporal:              yes
ending_mechanism:      state_transition (transfer of custodial responsibility)
default_sensitivity:   public
default_review:        pending
recommended_evidence:  institutional_record, legal_document
confers_authority:     no
implies_relationship:  none
valid_example:         [Organization: Provincial Archives] historical_stewardship
                       [Organization: Pioneer Museum collection] (1965–present)
invalid_example:       Confusing with LifeBook governance stewardship (which is governed
                       by AuthorityAssignment, not by this Relationship type)
notes:                 This Relationship records historical facts about who cared for records
                       and assets. LifeBook stewardship is a separate governance concept.
```

---

## State Transitions: What Is NOT a Relationship Type

The following concepts were considered as candidate relationship types and explicitly excluded.

| Concept | Reason excluded | Correct modelling |
|---|---|---|
| Separation | State transition on Marriage / CivilPartnership | `separation_divorce` Event + Relationship.is_ongoing = false |
| Divorce | State transition on Marriage | `separation_divorce` Event + effective_until + is_ongoing = false |
| Annulment | Legal state transition on Marriage | `marriage` Event of type annulment + is_ongoing = false |
| Widowhood | Consequence of a death Event, not a Relationship | `death` Event for the deceased spouse; the Marriage Relationship ends via died_on Claim |
| Resignation | State transition on Employment | `employment_end` Event + is_ongoing = false on Employment Relationship |
| Termination | Same as resignation | Same mechanism |
| Abandonment | State transition or legal finding | Notes on relevant Relationship + ContestRecord if contested |
| Estrangement | Social state; no durable connection to record | May be recorded via notes on an existing Relationship or as a Narrative |
| Disownment | May have legal implications; primarily social | ContestRecord if legal; notes if social; no Relationship type |
| Excommunication | State transition on community_membership | `left_on` Claim + is_ongoing = false on community_membership |

---

## Open questions

1. **Polygamous and plural marriage.** The `exclusive` flag on `marriage` defaults to yes. Historical and culturally recognized plural marriages must be representable. The correct mechanism — whether `exclusive` is set to false, or whether a separate `plural_marriage` type is created — requires community consultation for culturally sensitive contexts and legal review for others.

2. **Same-sex partnerships before legal recognition.** Couples who lived as partners without legal recognition, or under historical laws that criminalized their relationship, should have their relationships recorded accurately. The `domestic_partnership` type is the primary vehicle; but the sensitivity implications and display policy defaults for historically criminalized relationships require specific guidance.

3. **Relationship implication chaining.** `adoptive_parent_child` implies `legal_parent_child`. Does `legal_parent_child` imply `sibling` for the adopted person and the biological children of the adoptive parents? No automatic implication is assumed; all Relationships must be asserted and evidenced independently.

4. **Digital-era relationship types.** Online-only friendships, communities formed through digital platforms, and other contemporary relationship forms are not covered in this catalogue. They are not blocked; the `notes` field accommodates them, but a formal type may be needed in future iterations.

5. **Relationship to non-Entity objects.** Several relationship types (possession, stewardship) reference assets that are not in the Entity table (specific artifacts, collections). The current model handles this through value_text or through Artifact and Source records. A formal asset-entity pattern is a future consideration.

---

## Summary count

| Group | Types | Count |
|---|---|---|
| A. Biological and genetic kinship | biological_parent_child, sibling, full_sibling, half_sibling | 4 |
| B. Legal and social parenthood | legal_parent_child, adoptive_parent_child, step_parent_child, foster_parent_child | 4 |
| C. Guardianship and care | guardianship, caregiving | 2 |
| D. Marriage and partnership | marriage, civil_partnership, domestic_partnership | 3 |
| E. Employment and economic | employment, contractor, apprenticeship | 3 |
| F. Military and institutional | military_service, military_unit_association, organizational_membership, community_membership | 4 |
| G. Personal and social | friendship, mentorship, professional_association | 3 |
| H. Property and asset | ownership, possession, custody_of_person, historical_stewardship | 4 |
| **Total** | | **27** |

---

*After reviewing this catalogue, read SEMANTIC_COLLISION_REPORT.md.*
