# LifeBook Anchor Models
**Version:** 0.2 Draft  
**Status:** Pre-schema design document  
**Depends on:** GOVERNANCE_MODELS.md, OPERATIONAL_MODELS.md, PERSON_ATTRIBUTE_CATALOGUE.md  
**Produced:** 2026-07-23  
**Updated:** 2026-07-23 — Entity supertype added; LifeBookPerson split into LifeBookEntity + LifeBookPersonContext; User model added

Covers: Entity · Person · Organization · Place · Vessel · Community · EventSeries · LifeBook · LifeBookEntity · LifeBookPersonContext · User · UserPersonLink · Cross-LifeBook Linkage · MergeRecord

---

## Foundational Domain Rule: User ≠ Person

A User is an authenticated account. A Person is a human identity represented within LifeBook. The relationship between them is optional and always explicit.

These are separate entities. Neither implies the other.

**Counter-examples that must be supported without special-casing:**
- A deceased ancestor is a Person but never a User.
- A child may be a Person record before ever having an account.
- A professional researcher may be a User without being represented as a Person in any LifeBook.
- One User may legitimately act for multiple Persons (as guardian, steward, executor, or representative).
- Multiple Users may legitimately act for the same Person over time (sequential stewards, a guardian followed by the person themselves at majority).

### The four identities

In any LifeBook interaction, up to four distinct identities may be present simultaneously:

| Identity | What it is | Example |
|---|---|---|
| **Authenticated User** | The account that is logged in and making the request | Tracy is logged in |
| **Storyteller** | The person who is speaking or providing the account | Tracy is recording a recollection |
| **Subject Person** | The Person the content is about | The subject is Alice |
| **Authority holder** | The person who may approve or govern changes to this content | Iryna is steward; Michael is executor |

These are often different people. A professional archivist contributing supporting documents is a User and a Storyteller but neither the Subject nor the Authority holder. A steward approving a claim is the Authority holder but may not be the Subject or the Storyteller.

**Authentication does not imply subject identity.** If Tracy is logged in, that does not mean every statement Tracy makes is about the Person record representing Tracy. No system behaviour — no default, no assumption, no shortcut — may conflate the authenticated User with the subject Person.

### Consequences for implementation

These rules are non-negotiable and must be enforced at the data layer, not by convention:

1. **Deleting a User account must not delete associated Person records.** The Person record represents a human identity. The account is a credential. They have independent lifecycles.
2. **Removing a UserPersonLink must not erase the Person.** Authority is revocable; identity is not.
3. **Verification of a `self` link must not automatically merge identities, grant governance authority, or alter any AuthorityAssignment record.** Verification of a claim of identity is a factual determination. It does not determine what the User may do with the Person's records. Authority is granted separately through AuthorityAssignment and ApprovalPolicy.
4. **Every content record must carry an explicit `created_by_id` (User) and a separate `subject_entity_id` (Person/Entity).** These must never default to the same value.
5. **Narratives must carry a `composed_by_entity_id` (the storyteller as an Entity) separately from `created_by_id` (the User who entered it).** The person telling a story and the person operating the keyboard are distinct roles.

---

## Core Principle: Three Distinct Layers

LifeBook's data architecture preserves three layers that must never be collapsed into one another:

| Layer | What it is | Access model |
|---|---|---|
| **1. Global identity** | Stable Entity anchors shared across all LifeBooks referencing the same individual, organization, place, vessel, or community | Internal system linkage only; never automatically visible to users |
| **2. LifeBook-specific content** | Claims, narratives, sources, artifacts, and permissions scoped to a specific LifeBook | Governed by that LifeBook's steward and the participating persons' authority assignments |
| **3. Cross-LifeBook permission** | Explicit, authorized disclosure that two LifeBooks reference the same entity, plus what may be shared between them | Requires separate approval from both LifeBook stewards and (for persons) the person themselves |

The system may internally know that LifeBook A and LifeBook B both reference the same Entity anchor. This internal knowledge must not automatically:
- Surface the connection to either LifeBook's users
- Share attributes, narratives, or sources between LifeBooks
- Invite contact between contributors
- Merge records or create any cross-LifeBook inference in AI context

Each of those actions requires its own ApprovalPolicy and explicit authorization.

---

## 1. Entity (Supertype)

Entity is the common supertype for all named, referenceable things in LifeBook's global identity layer: persons, organizations, places, vessels, communities, and event series. All claims, relationships, narratives, and event participation records target Entity IDs rather than type-specific IDs.

Subtype tables (Person, Organization, Place, Vessel, Community, EventSeries) extend Entity through an `entity_id` field that is simultaneously the subtype table's primary key and a foreign key to Entity.

### 1.1 Design constraint

Entity holds only fields that apply uniformly across all subtypes: identity, canonical status, suppression, erasure, merge/split lineage, and creation provenance. Identity attributes specific to a subtype (person names, organization founding dates, place coordinates) live in the subtype table or in attribute tables with provenance and versioning.

### 1.2 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | Immutable. The permanent global identifier for this entity |
| `entity_type` | Enum | `person` / `organization` / `place` / `vessel` / `community` / `event_series` |
| `canonical_status` | Enum | See §1.3 |
| `merged_into_entity_id` | UUID FK | Self-referential; nullable. Set when this record is merged into another |
| `split_from_entity_id` | UUID FK | Self-referential; nullable. Set when this record was produced by splitting another |
| `merge_record_id` | UUID FK | FK to MergeRecord; nullable |
| `suppression_state` | Enum | See §1.4 |
| `suppression_reason` | Text | Nullable |
| `suppressed_at` | Timestamp | Nullable |
| `suppressed_by_id` | UUID FK | Nullable |
| `erasure_state` | Enum | `none` / `erasure_requested` / `erasure_in_progress` / `erased` |
| `erasure_requested_at` | Timestamp | Nullable |
| `erasure_jurisdiction_id` | UUID FK | Nullable |
| `creation_source` | Enum | `user_created` / `document_extracted` / `system_inferred` / `imported` |
| `creation_source_record_id` | UUID FK | Nullable |
| `creation_confidence` | evidence_status | For extracted or inferred entities; nullable |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | |

### 1.3 canonical_status values

| Value | Description |
|---|---|
| `canonical` | Live, authoritative record |
| `candidate` | Tentative; extracted from a document or inferred; not yet confirmed |
| `merged_into` | Merged into another entity; merged_into_entity_id points to the survivor |
| `split_from` | Produced by splitting another entity record |
| `duplicate_pending_review` | Probable duplicate identified; awaiting human review |

### 1.4 suppression_state values

| Value | Description |
|---|---|
| `active` | Normal state; accessible per authorization rules |
| `suppressed` | Hidden from ordinary access; steward-only |
| `redacted` | Personal data values removed; structural record retained |
| `deletion_pending` | Erasure authorized; awaiting AccessPolicyChanged propagation |

---

## 2. Person (Subtype)

Person extends Entity for natural persons. It holds only person-specific operational state. All identity attributes — names, pronouns, gender descriptors — live in the attribute tables defined in PERSON_ATTRIBUTE_CATALOGUE.md.

### 2.1 Design constraint

Person contains nothing that changes as a result of who the person is or how they identify. It contains only operational status about the record, person lifecycle state, erasure tracking, and governance review. `entity_id` is both the primary key and the FK to Entity.

### 2.2 Fields

| Field | Type | Notes |
|---|---|---|
| `entity_id` | UUID PK/FK | References Entity.id. Also the person's permanent identifier |
| `lifecycle_status` | Enum | `living` / `deceased` / `unknown` / `presumed_deceased` |
| `lifecycle_status_evidence_id` | UUID FK | Nullable; FK to Source or Claim supporting the lifecycle status |
| `last_governance_review_at` | Timestamp | Nullable; when a steward last reviewed governance for this record |
| `notes` | Text | Internal steward notes; access restricted |

### 2.3 What Person does not contain

The following must never be fields on the Person table:

- Name (any form)
- Date of birth or death
- Pronouns or gender
- Location, nationality, or ethnicity
- Relationships
- Any LifeBook identifier
- Any display preference
- Any privacy classification

These live in attribute tables with full provenance, versioning, and authority control.

---

## 3. Organization (Subtype)

Organization extends Entity for institutions, companies, religious bodies, military units, governmental bodies, civic groups, and other formal collectives.

### 3.1 Fields

| Field | Type | Notes |
|---|---|---|
| `entity_id` | UUID PK/FK | References Entity.id |
| `organization_type` | Enum | `religious` / `governmental` / `military` / `educational` / `commercial` / `civic` / `community` / `cultural` / `other` |
| `cached_display_name` | Text | **Cached display label only; not authoritative.** The authoritative name is a Claim with predicate `has_name` or equivalent. This field carries `_policy_version_id`, `_validity_state`, and `_invalidated_at` lineage (see CONTENT_LAYER.md §18.2). Invalidated by AccessPolicyChanged. |
| `cached_display_name_policy_version_id` | UUID FK | Nullable |
| `cached_display_name_validity_state` | Enum | `valid` / `policy_superseded` / `invalidated` |
| `cached_display_name_invalidated_at` | Timestamp | Nullable |
| `primary_jurisdiction_id` | UUID FK | Nullable |
| `notes` | Text | Nullable |

**Note:** `founded_date` and `dissolved_date` are not direct fields. These are Claims against this Organization entity with the predicates `founding_date_of` and `dissolved_date_of` (CONTENT_LAYER.md §3.2). They belong to the content layer with full provenance and confidence tracking.

---

## 4. Place (Subtype)

Place extends Entity for geographic and constructed locations: countries, cities, churches, farms, cemeteries, streets, geographic features.

### 4.1 Fields

| Field | Type | Notes |
|---|---|---|
| `entity_id` | UUID PK/FK | References Entity.id |
| `place_type` | Enum | `country` / `province_state` / `city_town_village` / `neighbourhood` / `street` / `building` / `church` / `cemetery` / `farm_estate` / `geographic_feature` / `other` |
| `cached_primary_name` | Text | **Cached display label only; not authoritative.** The authoritative name history (historical names, current name, renamed dates) is held in versioned name Claim records against this entity. Carries `_policy_version_id`, `_validity_state`, `_invalidated_at` lineage. |
| `cached_primary_name_policy_version_id` | UUID FK | Nullable |
| `cached_primary_name_validity_state` | Enum | `valid` / `policy_superseded` / `invalidated` |
| `cached_primary_name_invalidated_at` | Timestamp | Nullable |
| `cached_latitude` | Decimal | Nullable. **Cached representative coordinate only; not authoritative.** See §4.2. |
| `cached_longitude` | Decimal | Nullable. **Cached representative coordinate only; not authoritative.** See §4.2. |
| `coordinate_precision` | Enum | Nullable. `exact` / `approximate` / `centroid` / `disputed` / `unknown`. Describes the confidence and precision of the cached coordinates. |
| `coordinate_source_note` | Text | Nullable. Free-text note on the origin of the cached coordinates (e.g., "derived from OpenStreetMap centroid 2024"). For display guidance; supplemented by coordinate_source_id when a formal Source record exists. |
| `coordinate_source_id` | UUID FK | Nullable; optional FK → Source.id. If the cached coordinates were derived from a Source record (e.g., a map or gazetteer ingested into the system), this field carries the link. Non-blocking for migration: if circular dependency ordering in the migration sequence makes this FK difficult to add in step 1, it may be added as an ALTER TABLE in a later migration step after the Source table exists. |
| `country_code` | Char(2) | ISO 3166-1 alpha-2; nullable |
| `parent_place_entity_id` | UUID FK | Nullable; e.g., a church within a city |
| `notes` | Text | Nullable |

**Note:** Place names change over time. The cached_primary_name field holds only the name used to identify this entity in the system. Authoritative historical names (what this place was called at a specific time), renames, and alternative names are Claims against this entity with temporal precision fields. This is how "Königsberg" and "Kaliningrad" both appear in the record without either being wrong.

### 4.2 Cached coordinates policy

`cached_latitude` and `cached_longitude` are **representative display coordinates** for mapping and UI purposes. They are not authoritative geographic facts.

**What the cached coordinates are:**
- A single point suitable for placing a pin on a map or computing approximate distance.
- Populated at entity creation from an available reference source (e.g., geocoder, OpenStreetMap centroid).
- Marked with `coordinate_precision` to indicate confidence level.

**What the cached coordinates are not:**
- Authoritative or immutable. Coordinates for the same place may differ across sources, time periods, and boundary definitions.
- Suitable for jurisdictional, legal, or precise spatial analysis.
- Safe to present as "the location of this place" without precision qualification.

**Where authoritative or contested geometry belongs:**
Disputed coordinates, historically-changing boundaries, area-based geometry (polygons), sourced spatial data, and coordinates derived from specific documents belong in the Claim layer using a dedicated spatial predicate, or in a future `PlaceGeometry` table with full provenance. This does not block migration; the cache is sufficient for launch. The cache must not be presented to users as immutable truth.

**Invalidation:** Cached coordinates are not invalidated by AccessPolicyChanged. They may be updated by the steward or a system geocoding process at any time. Updates should be logged in the entity's audit trail with the source note updated accordingly.

---

## 5. Vessel (Subtype)

Vessel extends Entity for ships, steamships, sailing vessels, and other conveyances significant in historical records (immigration manifests, passenger lists, military transport).

### 5.1 Fields

| Field | Type | Notes |
|---|---|---|
| `entity_id` | UUID PK/FK | References Entity.id |
| `vessel_type` | Enum | `ship` / `steamship` / `sailing_vessel` / `aircraft` / `train` / `other` |
| `cached_vessel_name` | Text | **Cached display label only; not authoritative.** Vessels were often renamed; authoritative name history is Claims. Carries `_policy_version_id`, `_validity_state`, `_invalidated_at` lineage. |
| `cached_vessel_name_policy_version_id` | UUID FK | Nullable |
| `cached_vessel_name_validity_state` | Enum | `valid` / `policy_superseded` / `invalidated` |
| `cached_vessel_name_invalidated_at` | Timestamp | Nullable |
| `flag_country_code` | Char(2) | ISO 3166-1; nullable |
| `operating_entity_id` | UUID FK | Nullable; the shipping line or operator |
| `notes` | Text | Nullable |

**Note:** `registry`, `first_voyage_date`, and `last_voyage_date` are not direct fields. These are Claims against this Vessel entity. Vessel name, registry, and operating entity may change over a vessel's operational life and must be represented with temporal Claims.

---

## 6. Community (Subtype)

Community extends Entity for groups defined by shared identity, practice, or geography: Indigenous nations, ethnic communities, religious communities, occupational communities.

### 6.1 Fields

| Field | Type | Notes |
|---|---|---|
| `entity_id` | UUID PK/FK | References Entity.id |
| `community_type` | Enum | `indigenous_nation` / `ethnic_community` / `religious_community` / `geographic_community` / `occupational_community` / `other` |
| `cached_display_name` | Text | **Cached display label only; not authoritative.** The community's preferred name at a given time is a Claim. Carries lineage fields. |
| `cached_display_name_policy_version_id` | UUID FK | Nullable |
| `cached_display_name_validity_state` | Enum | `valid` / `policy_superseded` / `invalidated` |
| `cached_display_name_invalidated_at` | Timestamp | Nullable |
| `governance_notes` | Text | Nullable; relevant to culturally governed information processing |
| `primary_jurisdiction_id` | UUID FK | Nullable |
| `notes` | Text | Nullable |

**Pre-deployment blocker:** Any Community record of type `indigenous_nation` requires community consultation before the `culturally_governed_processing` ContextProfile may be enabled. See AI_CONTEXT_BROKER.md §4.5.

---

## 7. EventSeries (Subtype)

EventSeries extends Entity for recurring or institutional sequences of events: annual family gatherings, a parish's record series, a migration wave, a military campaign.

### 7.1 Fields

| Field | Type | Notes |
|---|---|---|
| `entity_id` | UUID PK/FK | References Entity.id |
| `series_type` | Enum | `annual_gathering` / `institutional_record_series` / `migration_wave` / `military_campaign` / `other` |
| `cached_display_name` | Text | **Cached display label only; not authoritative.** Carries lineage fields. |
| `cached_display_name_policy_version_id` | UUID FK | Nullable |
| `cached_display_name_validity_state` | Enum | `valid` / `policy_superseded` / `invalidated` |
| `cached_display_name_invalidated_at` | Timestamp | Nullable |
| `recurrence_description` | Text | Nullable; human-readable description of the recurrence pattern |
| `notes` | Text | Nullable |

**Note:** `first_occurrence_date` and `last_occurrence_date` are not direct fields. These are Claims against this EventSeries entity with temporal precision.

---

## 8. LifeBook

A LifeBook is a curated, governed historical knowledge collection organized around one or more focal entities, managed by a steward.

LifeBook is not a container for a person's data. It is a governed context in which information about entities — held in the global data layer — is assembled, interpreted, and presented according to the steward's and participants' authorities.

### 8.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `title` | String | Working title (e.g., "The Kowalski Family LifeBook") |
| `slug` | String | URL-friendly identifier; unique |
| `lifebook_status` | Enum | See §8.2 |
| `subject_scope` | Enum | See §8.3 |
| `visibility` | Enum | See §8.4 |
| `primary_language` | String | BCP 47 |
| `supported_languages` | Array\<String\> | BCP 47 codes |
| `steward_id` | UUID FK | FK to public.user_profiles; the current primary steward |
| `stewardship_type` | Enum | `self` / `designated` / `institutional` / `post_mortem` |
| `primary_jurisdiction_id` | UUID FK | FK to Jurisdiction |
| `additional_jurisdiction_ids` | Array\<UUID\> | Other applicable jurisdictions |
| `creation_reason` | Enum | `personal_history` / `family_history` / `memorial` / `community_record` / `other` |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | |
| `last_activity_at` | Timestamp | |
| `archived_at` | Timestamp | Nullable |
| `archived_by_id` | UUID FK | Nullable |
| `steward_notes` | Text | Steward-only internal notes |

### 8.2 lifebook_status values

| Value | Description |
|---|---|
| `active` | In normal use |
| `archived` | Preserved but no longer actively maintained; read-only for contributors |
| `suspended` | Temporarily inaccessible; typically during a governance dispute or legal hold |
| `transfer_pending` | Stewardship transfer is in progress |
| `deletion_pending` | Deletion authorized; awaiting AccessPolicyChanged propagation |

### 8.3 subject_scope values

| Value | Description |
|---|---|
| `individual` | Primarily about one person's life and memory |
| `family` | About a family, lineage, or household across generations |
| `community` | About a community, village, congregation, or other social group |
| `institutional` | About an organization, institution, or place |

### 8.4 visibility values

| Value | Description |
|---|---|
| `private` | Accessible only to persons with explicit LifeBookEntity records and authorized roles |
| `family` | Accessible to family members; not publicly discoverable |
| `public_preview` | A curated excerpt is publicly visible; full content is private |
| `published` | A steward-approved public version is accessible without authentication |

Visibility controls discoverability only. Even a `published` LifeBook displays only content whose display policies permit public access. Restricted attributes remain restricted regardless of LifeBook visibility.

### 8.5 What LifeBook does not contain

- Personal data about any entity
- Identity attributes
- Narratives, sources, artifacts, claims (those are content records scoped to a lifebook_id)

LifeBook is the governance and scoping container. Content records carry a `lifebook_id` as a scoping field; they are not embedded in the LifeBook record.

---

## 9. LifeBookEntity

LifeBookEntity is the many-to-many association between LifeBook and Entity (any subtype). It records the participation context: why this entity appears in this LifeBook, in what role, and with what visibility.

LifeBookEntity applies to all entity types: persons, organizations, places, vessels, communities, and event series. For person-specific participation details — authority context, contribution status, terms acceptance, cross-LifeBook consent — see LifeBookPersonContext (§10).

### 9.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `lifebook_id` | UUID FK | |
| `entity_id` | UUID FK | References Entity.id |
| `entity_type` | Enum | Denormalized from Entity.entity_type for query efficiency |
| `participation_role` | Enum | See §9.2 |
| `relationship_description` | Text | Nullable; human-readable description of how this entity relates to the focal subject |
| `is_focal_entity` | Boolean | Is this entity a primary subject of this LifeBook? |
| `visibility_status` | Enum | See §9.3 |
| `added_by_id` | UUID FK | |
| `added_at` | Timestamp | |
| `removed_at` | Timestamp | Nullable |
| `removed_by_id` | UUID FK | Nullable |
| `removal_reason` | Text | Nullable |
| `steward_notes` | Text | Nullable; not shown to the entity subject or contributors |

### 9.2 participation_role values

| Value | Description |
|---|---|
| `subject` | The focal entity this LifeBook is primarily about |
| `family_member` | A family member of the subject referenced in the LifeBook |
| `storyteller` | A person actively contributing stories, recollections, or oral history |
| `contributor` | A person providing information, artifacts, or sources in a formal capacity |
| `event_participant` | A person who participated in documented events but is not an active contributor |
| `historical_associate` | A historical figure referenced in sources or narratives; no active participation |
| ~~`candidate_match`~~ | **Removed.** Candidate matches are now modelled as `EntityMatchCandidate` records (§14), not as a participation_role value. A LifeBookEntity record must not exist solely to record a candidate match. |
| `referenced_entity` | Mentioned in sources or narratives but not otherwise associated |
| `steward` | Holds governance authority over this LifeBook |
| `witness` | A witness to events documented in this LifeBook |
| `institutional_representative` | Representing an organization or institution in this LifeBook context |
| `location_reference` | A place, vessel, or community referenced as context for events or claims |

### 9.3 visibility_status values

| Value | Description |
|---|---|
| `visible` | This entity is visible to authorized viewers |
| `hidden` | Exists in the record but not surfaced in any view; steward-only access |
| `restricted` | Visible only to specific authorized roles |
| `pending_confirmation` | Identified (e.g., extracted from a document) but not yet confirmed |
| `anonymized` | Identity redacted in views; referenced but not identified |

---

## 10. LifeBookPersonContext

LifeBookPersonContext is the person-specific participation overlay, associated with a LifeBookEntity record where `entity_type = person`. It holds fields that apply only to natural persons: authority context, contribution lifecycle, terms acceptance, cached permission state, and cross-LifeBook consent.

LifeBookEntity + LifeBookPersonContext together replace the former LifeBookPerson model.

**Completeness invariant:** Every active LifeBookEntity whose Entity.entity_type = `person` must have exactly one corresponding LifeBookPersonContext record. This invariant is enforced at the database layer using a deferred constraint trigger or equivalent mechanism — not by application convention alone. LifeBookEntity and LifeBookPersonContext must be created in the same transaction. Deletion of LifeBookPersonContext without deletion of the parent LifeBookEntity is prohibited.

### 10.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `lifebook_entity_id` | UUID FK | References LifeBookEntity.id; unique (one-to-one) |
| `entity_id` | UUID FK | Redundant reference for direct joins; must equal LifeBookEntity.entity_id |
| `authority_context` | Enum | See §10.2; which governance pattern applies |
| `contribution_status` | Enum | See §10.3 |
| `has_accepted_terms` | Boolean | Has this person accepted LifeBook's terms of participation? |
| `terms_accepted_at` | Timestamp | Nullable |
| `cross_lifebook_linkage_authorized` | Boolean | Has this person explicitly authorized that their participation in this LifeBook may be disclosed to stewards of other LifeBooks? |
| `cross_lifebook_linkage_authorized_at` | Timestamp | Nullable |
| `cross_lifebook_linkage_scope` | JSONB | Nullable; what specifically is authorized to be disclosed across LifeBooks |
| `cached_permission_summary` | JSONB | See §10.4; derived cache only — NOT authoritative |
| `permission_cache_policy_version_id` | UUID FK | The ApprovalPolicy or policy version that produced the cache; nullable |
| `permission_cache_computed_at` | Timestamp | Nullable |

### 10.2 authority_context values

| Value | Applies when |
|---|---|
| `full_subject_authority` | Living adult with capacity for this context |
| `minor_subject_sole_guardian` | Minor with one guardian |
| `minor_subject_joint_guardian` | Minor with multiple joint guardians |
| `supported_subject` | Formal SDM arrangement in effect |
| `represented_subject` | Legal representative or court-appointed guardian |
| `deceased_with_preferences` | Subject deceased; documented identity preferences exist |
| `deceased_without_preferences` | Subject deceased; no documented preferences |
| `family_contributor` | Family member in a non-subject contributor role |
| `external_contributor` | Non-family contributor |
| `historical_only` | Historical person with no living governance; steward governs |
| `disputed` | Authority is currently contested; ContestRecord is open |
| `institutional_representative` | Acting in an institutional capacity |

### 10.3 contribution_status values

| Value | Description |
|---|---|
| `active_contributor` | Currently contributing |
| `past_contributor` | Contributed in the past; no longer active |
| `invited` | Has been invited but has not yet accepted |
| `declined` | Was invited and declined participation |
| `revoked` | Contribution access was revoked; record is retained |
| `not_a_contributor` | Referenced but has no contributor role |

### 10.4 Cached permission summary

`cached_permission_summary` is a JSONB field containing computed, cached values derived from the applicable AuthorityAssignment and ApprovalPolicy records. Examples of what it may contain:

```json
{
  "can_view_own_entries": true,
  "can_contribute_stories": true,
  "can_view_family_content": false,
  "computed_from_authority_assignment_ids": ["uuid-1", "uuid-2"],
  "computed_from_policy_version_id": "uuid-3"
}
```

**This field is not authoritative.** It is a performance cache only. The authoritative source is always the AuthorityAssignment and ApprovalPolicy records. Applications must:

1. Check `permission_cache_computed_at` and `permission_cache_policy_version_id` to determine whether the cache is current
2. Recompute from AuthorityAssignment + ApprovalPolicy whenever a relevant AccessPolicyChanged event has fired after `permission_cache_computed_at`
3. Never make irreversible or sensitive decisions (e.g., whether to produce an AI context, whether to share data cross-LifeBook) based solely on this cache

An AccessPolicyChanged event invalidates this cache for all affected LifeBookPersonContext records. Invalidated cache entries must be recomputed before the next access decision.

---

## 11. User Model

LifeBook uses Supabase authentication. User identity is managed by `auth.users` (Supabase-controlled). LifeBook application data is in `public.user_profiles`, linked by the same UUID primary key.

### 11.1 public.user_profiles

| Field | Type | Notes |
|---|---|---|
| `id` | UUID PK | Equals auth.users.id |
| `display_name` | Text | Chosen display name; not necessarily a legal name |
| `account_status` | Enum | `active` / `suspended` / `pending_verification` / `deactivated` |
| `preferred_language` | String | BCP 47 |
| `timezone` | String | IANA timezone identifier |
| `created_at` | Timestamp | |
| `updated_at` | Timestamp | |
| `last_active_at` | Timestamp | |

`public.user_profiles` does not contain email, password, or authentication tokens. Those remain in `auth.users` under Supabase's control.

### 11.2 UserPersonLink

UserPersonLink records the verified or claimed relationship between a User account and one or more Person records. This is not automatic: a user who creates a LifeBook is not automatically linked to any Person anchor. The link requires explicit action and, for sensitive link types, verification.

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `user_id` | UUID FK | References public.user_profiles.id |
| `person_entity_id` | UUID FK | References Entity.id (must be entity_type = person) |
| `link_type` | Enum | See §11.3 |
| `verification_status` | Enum | `unverified` / `pending_verification` / `verified` / `rejected` |
| `verification_method` | Text | Nullable; how verification was conducted |
| `verified_at` | Timestamp | Nullable |
| `verified_by_id` | UUID FK | Nullable; who verified the link |
| `authority_basis_type` | Text | Nullable; for guardian_of, steward_for, representative_of: the basis of authority |
| `effective_from` | Date | Nullable |
| `effective_until` | Date | Nullable |
| `created_at` | Timestamp | |
| `created_by_id` | UUID FK | |
| `notes` | Text | Nullable |

### 11.3 link_type values

| Value | Description |
|---|---|
| `self` | The user claims this Person record represents themselves |
| `guardian_of` | The user is a legal guardian of this person (typically a minor) |
| `steward_for` | The user is a designated steward for this person's LifeBook records |
| `executor_for` | The user holds executor or estate-authority for this person (typically deceased) |
| `representative_of` | The user has legal or formal authority to act on this person's behalf |
| `contributor_about` | The user contributes stories or content about this person without holding authority over them (e.g., a friend, colleague, or professional archivist) |
| `unverified_claim` | The user claims a connection but it has not been verified |

A user may have multiple UserPersonLink records (e.g., `self` for their own Person anchor, `guardian_of` for a child, `contributor_about` for a historical figure they are researching). A Person record may have multiple UserPersonLink records from different users, including multiple authority holders over time.

### 11.4 UserPersonLink constraints

These constraints implement the User ≠ Person domain rule defined at the top of this document:

1. A UserPersonLink does not grant governance authority. Authority is granted only through AuthorityAssignment records (GOVERNANCE_MODELS.md §3). The link_type identifies the nature of the relationship; AuthorityAssignment identifies what the user may do.
2. Verification of a `self` link (`verification_status = verified`) does not automatically create an AuthorityAssignment, alter any existing AuthorityAssignment, or grant any content-editing permission. It is a factual determination only.
3. Deleting or expiring a UserPersonLink must not alter the Person record or any content records about that person. The link is a relationship record; its removal affects only what the user may do, not the person's existence in the system.
4. `contributor_about` links carry no authority. A user with only a `contributor_about` link may submit contributions; those contributions require approval by whoever holds authority for that person in the relevant LifeBook.

---

## 12. Cross-LifeBook Linkage

### 12.1 What the system may know internally

When an Entity anchor appears in LifeBookEntity records across multiple LifeBooks, the system internally knows these LifeBooks reference the same entity. This is the intended function of the global Entity anchor.

This internal knowledge:
- Does not create any user-visible connection
- Does not trigger any notification to either LifeBook's contributors or steward
- Does not permit any attribute, narrative, source, or artifact to flow between LifeBooks
- Does not affect AI context assembly for either LifeBook
- Does not constitute consent to share information

The internal connection exists solely to prevent duplicate Entity anchors and to enable future authorized cross-LifeBook linkage if all required approvals are obtained.

### 12.2 What requires explicit authorization

Each of the following is a separate action requiring its own ApprovalPolicy and approval:

| Action | Required approvals |
|---|---|
| Disclosing to Steward A that their participant also appears in LifeBook B | Steward B's consent + Person's cross_lifebook_linkage_authorized = true for this purpose |
| Sharing any attribute from LifeBook A's context with LifeBook B | Both stewards + Person's explicit cross-LifeBook scope authorization |
| Contacting a contributor in LifeBook B from LifeBook A | Both stewards + the contributor's consent + Person's authorization |
| Merging LifeBook-specific content across LifeBooks | Both stewards + Person + ApprovalPolicy for approve_merge |
| Surfacing the connection to the person themselves | Steward of each LifeBook where the person participates |

### 12.3 Candidate match handling

When identity-resolution identifies a probable match across LifeBooks:
- A `candidate_match` LifeBookEntity record is created in each LifeBook for the matched Entity anchor
- A match confidence score is recorded in the identity-resolution record
- A pending approval workflow is created requiring steward review

Until review and applicable approvals are obtained:
- The candidate match is not visible to any user in either LifeBook
- No information is shared between LifeBooks
- No notification is sent to any contributor
- AI context for either LifeBook does not include the candidate match

A suggested system notification to each LifeBook's steward after internal identity resolution identifies a probable match:

> "A historical record associated with your LifeBook may also be relevant to another LifeBook. You control whether you would like to explore a possible connection."

The notification does not name the other LifeBook, identify the other steward, or describe the matched entity beyond what the notified steward already knows.

### 12.4 CrossLifeBookAuthorization record

When cross-LifeBook linkage is authorized, a CrossLifeBookAuthorization record is created:

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `lifebook_a_id` | UUID FK | |
| `lifebook_b_id` | UUID FK | |
| `entity_id` | UUID FK | The Entity whose linkage is authorized |
| `authorized_actions` | Array\<ActionType\> | Specifically what is permitted between the two LifeBooks |
| `authorized_data_categories` | Array\<String\> | Which attribute categories may be shared |
| `approval_a_id` | UUID FK | ApprovalRecord from Steward A |
| `approval_b_id` | UUID FK | ApprovalRecord from Steward B |
| `person_authorization_id` | UUID FK | Nullable; the Person's explicit authorization record (required when entity_type = person) |
| `effective_from` | Timestamp | |
| `effective_until` | Timestamp | Nullable |
| `status` | Enum | `active` / `suspended` / `revoked` |
| `revoked_at` | Timestamp | Nullable |
| `revoked_by_id` | UUID FK | Nullable |
| `revocation_reason` | Text | Nullable |
| `created_at` | Timestamp | |

Revocation fires the `cross_lifebook_authorization_revoked` AccessPolicyChanged event (AI_CONTEXT_BROKER.md §11.1 and §11.4). The full invalidation scope is defined in AI_CONTEXT_BROKER.md §11.4.

### 12.5 LifeBook-scoped content records

Content records — Claim, Narrative, Source, Artifact — are scoped to a LifeBook via `lifebook_id` and target entities via `entity_id`. A Claim about a person in LifeBook A belongs to LifeBook A. It cannot flow to LifeBook B without a CrossLifeBookAuthorization that explicitly covers that claim's data category.

The global Entity anchor is shared. The content is not.

---

## 13. MergeRecord

MergeRecord preserves the full history of a merge or split operation on Entity records, enabling reversal.

### 13.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `operation_type` | Enum | `merge` / `split` |
| `entity_type` | Enum | The entity_type of the records involved |
| `source_entity_ids` | Array\<UUID\> | Entity records that were merged (or the record that was split) |
| `target_entity_ids` | Array\<UUID\> | Surviving or resulting entity records |
| `approval_record_id` | UUID FK | The ApprovalRecord for the approve_merge or approve_split action |
| `approved_by_id` | UUID FK | |
| `approved_at` | Timestamp | |
| `attribute_assignments` | JSONB | Which attribute records were reassigned to which target entity |
| `lifebook_entity_assignments` | JSONB | Which LifeBookEntity records were reassigned |
| `content_assignments` | JSONB | Which Claim, Narrative, Source records were reassigned |
| `is_reversible` | Boolean | Whether sufficient information exists to reconstruct the pre-merge state |
| `reversal_blocked_reason` | Text | Nullable |
| `reversed_at` | Timestamp | Nullable |
| `reversed_by_id` | UUID FK | Nullable |
| `reversed_merge_record_id` | UUID FK | Self-referential; nullable |
| `created_at` | Timestamp | |
| `notes` | Text | Nullable |

---

## 14. EntityMatchCandidate

EntityMatchCandidate is the dedicated model for recording probable identity matches between two Entity records across or within LifeBooks. It replaces the former `candidate_match` participation_role value on LifeBookEntity.

An EntityMatchCandidate record represents a hypothesis — not a conclusion. The existence of a candidate record does not authorize disclosure, content sharing, cross-LifeBook contact, or any merge action. No user-visible change may result from a candidate match until a steward confirms the match and all applicable approvals are obtained.

### 14.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `entity_a_id` | UUID FK | References Entity.id; one of the candidate-match pair |
| `entity_b_id` | UUID FK | References Entity.id; the other candidate |
| `lifebook_a_id` | UUID FK | Nullable; the LifeBook in which entity_a was encountered |
| `lifebook_b_id` | UUID FK | Nullable; the LifeBook in which entity_b was encountered |
| `producing_agent_code` | Text | Nullable; the AI agent or system process that generated this candidate |
| `produced_by_user_id` | UUID FK | Nullable; if generated by a human reviewer or steward |
| `confidence_score` | Decimal | The system's confidence that entity_a and entity_b represent the same real-world entity (0.0–1.0) |
| `supporting_record_ids` | JSONB | Array of record IDs (claims, sources, attributes) that the confidence score is based on |
| `status` | Enum | See §14.2 |
| `review_outcome` | Enum | Nullable; see §14.3 |
| `reviewed_by_id` | UUID FK | Nullable |
| `reviewed_at` | Timestamp | Nullable |
| `merge_record_id` | UUID FK | Nullable; FK to MergeRecord if status = `confirmed_same` and a merge was executed |
| `context_manifest_id` | UUID FK | Nullable; if produced by an AI agent |
| `created_at` | Timestamp | |
| `superseded_by_id` | UUID FK | Nullable; self-referential; if a newer candidate record supersedes this one |

### 14.2 status values

| Value | Description |
|---|---|
| `generated` | Produced by a system or AI process; not yet reviewed |
| `pending_review` | Assigned to a steward for review |
| `confirmed_same` | Steward confirmed these entities represent the same real-world entity |
| `confirmed_distinct` | Steward confirmed these entities are different |
| `insufficient_evidence` | Review completed; evidence insufficient to decide |
| `rejected` | Candidate was rejected as implausible |
| `superseded` | A newer candidate record replaces this one |

### 14.3 review_outcome values (set at review)

| Value | Description |
|---|---|
| `merged` | Confirmed same; MergeRecord created; entity_b is now merged_into entity_a |
| `linked` | Confirmed same; entities are not merged but a CrossLifeBookAuthorization is being pursued |
| `distinct_confirmed` | Entities are confirmed as different people/things |
| `deferred` | Decision deferred pending additional evidence |
| `no_action` | Reviewed; neither merge nor linkage pursued |

### 14.4 Non-disclosure guarantee

The system must enforce the following at the database or application layer:

- A LifeBookEntity record for either entity_a or entity_b must not be altered, added, or notified as a result of an EntityMatchCandidate record being created.
- The EntityMatchCandidate table is accessible only to stewards and authorized system processes. It must not appear in any user-facing query or API response without explicit steward-level authorization.
- The candidate's existence must not trigger any cross-LifeBook event, notification, or data-sharing action.

---

## 15. Open Questions Before Migration

1. **UserPersonLink verification workflow:** The verification process for link_types other than `unverified_claim` and `self` (e.g., how `guardian_of` is verified) needs a defined workflow. Initial implementation: steward attestation. Formal document verification is a later milestone.

2. **EntityMatchCandidate access control:** The EntityMatchCandidate table is accessible to stewards and system processes only. The exact RLS policy and API exposure rules need to be specified before migration.

3. **OrgName versioned attribute table:** Organization names change over time. A parallel name attribute table (comparable to PersonName in PERSON_ATTRIBUTE_CATALOGUE.md) should be designed before migration. The `cached_display_name` field is a temporary operational convenience, not a substitute.

4. **Community name authority:** For Communities of type `indigenous_nation`, the preferred name is governed by the community. The consultation and name-governance process needs to be defined before the community's `cached_display_name` may be set or changed.

---

*Next step: Review CONTENT_LAYER.md (Claim, Narrative, Source, Artifact, Event and related tables) then produce the Supabase migration.*
