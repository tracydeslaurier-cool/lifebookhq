-- ============================================================
-- Migration 0001: All PostgreSQL enum types + ClaimValueUnit
-- Sequence position: Step 1 (no dependencies)
-- Governed by: SCHEMA_INVENTORY.md v0.2, CONTENT_LAYER.md v0.3,
--   ANCHOR_MODELS.md v0.2, GOVERNANCE_MODELS.md v0.1 Draft,
--   OPERATIONAL_MODELS.md v0.1 Draft, APPROVAL_INSTANCE_MODEL.md v1.0
-- Authorization: PRE_MIGRATION_CLOSURE.md v1.2 §7
-- Date: 2026-07-23
-- ============================================================

-- ============================================================
-- SECTION 1: CONFIDENCE / STATUS DIMENSIONS
-- Source: CONTENT_LAYER.md §18.5, GOVERNANCE_MODELS.md §1
-- ============================================================

-- Confidence in evidence supporting an assertion.
-- Does not encode dispute (→ dispute_status) or review state (→ review_status).
CREATE TYPE evidence_status AS ENUM (
    'unreviewed',    -- No assessment yet; default at submission
    'asserted',      -- Stated by a party with standing; no corroborating evidence
    'inferred',      -- Derived by system or AI process; never self-approved
    'supported',     -- One or more primary sources support this assertion
    'corroborated'   -- Multiple independent sources confirm this assertion
);

-- Temporal precision only. Does not encode evidence quality.
CREATE TYPE precision_status AS ENUM (
    'exact',         -- Known to the day (or finer granularity)
    'approximate',   -- Within a known range but not exact
    'range',         -- Only a range is known (e.g., "between 1910 and 1920")
    'unknown'        -- No temporal information is available
);

-- Whether a factual assertion is under dispute.
CREATE TYPE dispute_status AS ENUM (
    'uncontested',   -- No known dispute
    'disputed',      -- A party has opened a ContestRecord against this assertion
    'contradicted',  -- A conflicting claim exists and is unresolved
    'retracted',     -- The asserting party has retracted the claim
    'superseded'     -- A later claim has replaced this one
);

-- Workflow review state. Three values only — no others permitted.
-- Source: CONTENT_LAYER.md Core Design Principles (controlled status vocabulary)
CREATE TYPE review_status AS ENUM (
    'pending',           -- Awaiting review; not approved for consequential use
    'human_reviewed',    -- A human has reviewed; may be used for non-consequential display
    'policy_approved'    -- Approved for publication, cross-LifeBook sharing, AI context supply
);

-- ============================================================
-- SECTION 2: ACCESS CLASSIFICATION
-- Source: CONTENT_LAYER.md §17
-- ============================================================

CREATE TYPE access_classification AS ENUM (
    'public',               -- May appear in public-facing views where LifeBook visibility permits
    'family',               -- Accessible to family members and authorized contributors
    'steward',              -- Accessible to the LifeBook steward only
    'restricted',           -- Accessible only to specifically authorized individuals per display policy
    'culturally_governed'   -- Requires culturally_governed_processing ContextProfile; DENIED by default
);

-- ============================================================
-- SECTION 3: ENTITY AND ANCHOR MODEL ENUMS
-- Source: ANCHOR_MODELS.md v0.2
-- ============================================================

-- Entity supertype discriminator.
CREATE TYPE entity_type AS ENUM (
    'person',
    'organization',
    'place',
    'vessel',
    'community',
    'event_series'
);

-- Participation role in a LifeBook (LifeBookEntity.participation_role).
-- Note: candidate_match is REMOVED — use EntityMatchCandidate table.
CREATE TYPE participation_role AS ENUM (
    'subject',                   -- The focal entity this LifeBook is primarily about
    'family_member',             -- A family member of the subject referenced in the LifeBook
    'storyteller',               -- Contributing stories, recollections, or oral history
    'contributor',               -- Providing information, artifacts, or sources formally
    'event_participant',         -- Participated in documented events; not an active contributor
    'historical_associate',      -- Historical figure referenced in sources; no active participation
    'referenced_entity',         -- Mentioned in sources or narratives; not otherwise associated
    'steward',                   -- Holds governance authority over this LifeBook
    'witness',                   -- A witness to events documented in this LifeBook
    'institutional_representative', -- Representing an organization or institution
    'location_reference'         -- A place, vessel, or community referenced as context
);

-- LifeBookEntity visibility state.
CREATE TYPE visibility_status AS ENUM (
    'visible',       -- Surfaced to authorized viewers
    'hidden',        -- Exists in the record; steward-only access
    'pending_review' -- Requires steward review before becoming visible
);

-- Authority and governance context for a person in a LifeBook (LifeBookPersonContext).
CREATE TYPE authority_context AS ENUM (
    'full_subject_authority',        -- Living adult with capacity for this context
    'minor_subject_sole_guardian',   -- Minor with one guardian
    'minor_subject_joint_guardian',  -- Minor with multiple joint guardians
    'supported_subject',             -- Formal supported decision-making arrangement
    'represented_subject',           -- Legal representative or court-appointed guardian
    'deceased_with_preferences',     -- Deceased; documented identity preferences exist
    'deceased_without_preferences',  -- Deceased; no documented preferences
    'family_contributor',            -- Family member in a non-subject contributor role
    'external_contributor',          -- Non-family contributor
    'historical_only',               -- Historical person; no living governance; steward governs
    'disputed',                      -- Authority currently contested; ContestRecord is open
    'institutional_representative'   -- Acting in an institutional capacity
);

-- Contribution activity state for a person in a LifeBook.
CREATE TYPE contribution_status AS ENUM (
    'active_contributor',    -- Currently contributing
    'past_contributor',      -- Contributed previously; no longer active
    'invited',               -- Invited but not yet accepted
    'declined',              -- Invited and declined participation
    'revoked',               -- Contribution access revoked; record retained
    'not_a_contributor'      -- Referenced but holds no contributor role
);

-- UserPersonLink link type.
CREATE TYPE link_type AS ENUM (
    'self',                -- User claims this Person record represents themselves
    'guardian_of',         -- User is a legal guardian of this person
    'steward_for',         -- User is a designated steward for this person's LifeBook records
    'executor_for',        -- User holds executor or estate-authority for this person
    'representative_of',   -- User has legal or formal authority to act on this person's behalf
    'contributor_about',   -- User contributes content about this person without authority
    'unverified_claim'     -- Connection claimed but not yet verified
);

-- UserPersonLink verification state.
CREATE TYPE verification_status AS ENUM (
    'unverified',
    'pending_verification',
    'verified',
    'rejected'
);

-- EntityMatchCandidate review state.
CREATE TYPE entity_match_status AS ENUM (
    'pending',               -- Awaiting steward review
    'under_review',          -- Steward is actively evaluating
    'confirmed_match',       -- Steward confirmed these are the same entity
    'confirmed_non_match',   -- Steward confirmed these are different entities
    'merged',                -- Confirmed match; merge action completed
    'escalated',             -- Referred to a ContestRecord due to dispute
    'expired'                -- Candidate record aged out without resolution
);

-- EntityMatchCandidate review outcome (post-decision).
CREATE TYPE entity_match_review_outcome AS ENUM (
    'steward_confirmed',        -- Steward confirmed via manual review
    'evidence_corroborated',    -- Multiple independent sources corroborated
    'subject_confirmed',        -- Subject or authorized representative confirmed
    'community_confirmed',      -- Community authority confirmed (for indigenous/community entities)
    'no_consensus'              -- Review did not reach a conclusion
);

-- ============================================================
-- SECTION 4: SUBMISSION ORIGIN
-- Source: CONTENT_LAYER.md §1.1
-- ============================================================

-- Who or what submitted a content record. Set at creation; never changed.
CREATE TYPE submission_origin AS ENUM (
    'subject_submission',                   -- Subject entity themselves
    'authorized_representative_submission', -- Verified representative or guardian
    'steward_submission',                   -- LifeBook steward; human-reviewed by default
    'executor_submission',                  -- Executor; posthumous/estate scope only
    'family_submission',                    -- Family member; pending review
    'contributor_submission',               -- contributor_about link; pending review
    'institutional_submission',             -- Institution; pending review; provenance required
    'ai_extracted_submission',              -- AI agent extraction; quarantined pending human review
    'system_inferred_submission'            -- System process inference; never self-approved
);

-- ============================================================
-- SECTION 5: CONTENT LAYER ENUMS
-- Source: CONTENT_LAYER.md v0.3
-- ============================================================

-- Narrative type.
CREATE TYPE narrative_type AS ENUM (
    'personal_recollection',   -- First-person memory account
    'family_oral_history',     -- Story passed down within a family
    'biographical_essay',      -- Third-person biographical account
    'historical_account',      -- Account of historical events or context
    'interview_transcript',    -- Transcribed or recorded interview
    'written_memoir',          -- Memoir or autobiographical text
    'community_account',       -- Account from or authorized by a community
    'ai_generated_summary',    -- AI-produced; requires review_status = policy_approved before use
    'ai_generated_draft'       -- AI-drafted; awaiting human review
);

-- Content type (from GOVERNANCE_MODELS.md §8, surface in CONTENT_LAYER.md §7.3).
CREATE TYPE content_type AS ENUM (
    'archival_transcript',       -- Verbatim; attributed; unedited
    'historical_quotation',      -- Selected extract in quotation marks with attribution
    'respectful_presentation',   -- Steward-authored using approved attribute representations
    'ai_generated_summary',      -- AI-produced; requires policy_approved before display or AI reuse
    'community_account'          -- Authorized by a community
);

-- Narrative composition status.
CREATE TYPE composition_status AS ENUM (
    'draft',
    'submitted',
    'under_review',
    'approved',
    'published',
    'retracted',
    'archived'
);

-- Source type.
CREATE TYPE source_type AS ENUM (
    'personal_recollection',    -- Individual's spoken or written memory
    'official_document',        -- Government-issued document
    'vital_record',             -- Birth, death, marriage, or divorce registration
    'church_register',          -- Baptism, marriage, burial, or confirmation record
    'census_record',            -- Population census or household enumeration
    'ship_manifest',            -- Passenger or crew list
    'military_record',          -- Service record, pension file, discharge paper
    'newspaper',                -- Newspaper article, obituary, or announcement
    'photograph_metadata',      -- Information associated with a photograph
    'audio_recording',          -- Recorded speech or oral history
    'video_recording',          -- Recorded video
    'letter_correspondence',    -- Personal or official correspondence
    'diary_journal',            -- Personal diary or journal
    'legal_document',           -- Will, deed, contract, power of attorney, etc. (not court records)
    'court_record',             -- Court pleadings, orders, judgments (default: steward/restricted)
    'institutional_record',     -- School, hospital, employer, organization record
    'archival_database',        -- Record from an archival database
    'map',                      -- Cartographic document
    'dna_analysis',             -- Genetic genealogy testing or DNA analysis (RESTRICTED by default)
    'other'                     -- Any type not otherwise categorized
);

-- SourceDerivative type.
CREATE TYPE derivative_type AS ENUM (
    'exact_transcript',           -- Verbatim transcript
    'extracted_claims',           -- Claims extracted by AI or human from source material
    'sanitized_summary',          -- AI-sanitized summary safe for context supply
    'identity_resolution_tokens', -- Tokens for identity resolution; no prose content
    'access_metadata'             -- Access classification and policy metadata only
);

-- SourceDerivative validity state.
CREATE TYPE derivative_validity_state AS ENUM (
    'valid',
    'policy_superseded',
    'under_review',
    'invalidated',
    'expired'
);

-- LifeBookSourceAccess status.
CREATE TYPE source_access_status AS ENUM (
    'active',
    'suspended',
    'revoked'
);

-- Artifact type.
CREATE TYPE artifact_type AS ENUM (
    'photograph',       -- Still image
    'letter',           -- Personal or official correspondence
    'certificate',      -- Official certificate
    'audio_recording',  -- Sound recording
    'video_recording',  -- Video recording
    'document',         -- Document not otherwise categorized
    'map',              -- Cartographic artifact
    'recipe',           -- Written recipe
    'diary_journal',    -- Personal diary or journal
    'artwork',          -- Painting, drawing, illustration, or other artwork
    'object',           -- Physical object
    'other'             -- Any type not otherwise categorized
);

-- FileStorageReference storage provider.
CREATE TYPE storage_provider AS ENUM (
    'supabase_storage',
    's3',
    'gcs',
    'azure_blob',
    'other'
);

-- FileStorageReference derivative relationship.
CREATE TYPE file_derivative_relationship AS ENUM (
    'original',
    'thumbnail',
    'compressed',
    'transcript',
    'derivative'
);

-- ArtifactSourceLink relationship type.
CREATE TYPE artifact_source_relationship AS ENUM (
    'artifact_is_source',        -- The artifact itself serves as primary evidence
    'artifact_contains_source',  -- The artifact contains source material
    'source_describes_artifact', -- The source describes or documents the artifact
    'digital_copy_of_source',    -- The artifact is a digital copy of the source document
    'derivative_of_artifact'     -- The source is derived from or produced by the artifact
);

-- EventParticipant participant role.
CREATE TYPE participant_role AS ENUM (
    'subject',               -- The person the event primarily concerns
    'spouse_partner',        -- Spouse or partner in a marriage or union event
    'parent',                -- Parent in a birth, baptism, or adoption event
    'guardian',              -- Legal guardian in an adoption or guardianship event
    'witness',               -- A witness who attested to the event
    'officiant',             -- Celebrant, registrar, or official who presided
    'family_member',         -- Family member present
    'passenger',             -- Traveller on a voyage
    'crew_member',           -- Crew on a vessel
    'employer',              -- An employer
    'employee',              -- An employee
    'community_member',      -- Community member in a community ceremony
    'location',              -- A place entity in a multi-location event
    'vessel',                -- A vessel entity in a voyage event
    'organizing_body',       -- Organization that organized or officiated
    'other'                  -- Any role not otherwise categorized
);

-- Event type.
CREATE TYPE event_type AS ENUM (
    'birth',
    'baptism',
    'naming_ceremony',
    'marriage',
    'civil_partnership_registration', -- Distinct from marriage; see CONTENT_LAYER.md §15.2
    'separation_divorce',
    'death',
    'burial_interment',
    'immigration',
    'emigration',
    'naturalization',
    'employment_start',
    'employment_end',
    'military_service',
    'graduation',
    'ordination',
    'adoption',
    'voyage',
    'community_ceremony',
    'institutional_event',
    'other'
);

-- Claim text validity state (cached display text invalidation).
CREATE TYPE claim_text_validity_state AS ENUM (
    'valid',
    'policy_superseded',
    'invalidated'
);

-- ============================================================
-- SECTION 6: GOVERNANCE MODEL ENUMS
-- Source: GOVERNANCE_MODELS.md v0.1 Draft
-- ============================================================

-- Authority basis type — quick discriminator on AuthorityAssignment.
-- Nullable Claim (basis_claim_id) carries the evidentiary detail (ADR-0001).
CREATE TYPE authority_basis_type AS ENUM (
    'self_assertion',                    -- Subject asserts their own authority; no Claim required
    'parental_guardianship',             -- Natural or presumed parental guardianship
    'court_appointed_guardianship',      -- Guardian appointed by court order
    'supported_decision_making',         -- Formal SDM arrangement under applicable legislation
    'power_of_attorney_general',         -- General power of attorney
    'power_of_attorney_personal',        -- Personal (healthcare/personal care) power of attorney
    'enduring_power_of_attorney',        -- Enduring power; survives incapacity
    'testamentary_executor',             -- Executor named in a will
    'estate_administrator',              -- Administrator appointed by court for intestate estate
    'cultural_authority',                -- Authority recognized under Indigenous or community law
    'institutional_authority',           -- Authority deriving from an institutional role
    'legal_representative',              -- Court-appointed or statutory legal representative
    'stewardship_succession',            -- Stewardship transferred by succession record
    'policy_default'                     -- Policy applies default rule; no Claim required
);

-- AuthorityAssignment coordination rule for joint authority holders.
CREATE TYPE coordination_rule AS ENUM (
    'sole',              -- This holder acts alone
    'joint_unanimous',   -- All joint holders must agree
    'joint_majority',    -- Majority of joint holders must agree
    'joint_any',         -- Any joint holder may act alone
    'escalate'           -- No presumption; route to EscalationPolicy if joint action required
);

-- AuthorityAssignment succession behaviour when this holder is unavailable.
CREATE TYPE succession_behaviour AS ENUM (
    'next_in_order',          -- Pass to the next AuthorityAssignment in the succession list
    'escalate_to_steward',    -- Refer to the LifeBook steward
    'freeze',                 -- Block the action pending a new assignment
    'apply_policy_default',   -- Apply policy_default authority_basis_type rules
    'route_external'          -- Flag for external legal or community resolution
);

-- ApprovalPolicy lifecycle status.
CREATE TYPE approval_policy_lifecycle_status AS ENUM (
    'draft',
    'pending_legal_review',
    'legally_reviewed',
    'active',
    'under_amendment',
    'deprecated',
    'superseded',
    'archived',
    'suspended'
);

-- ============================================================
-- SECTION 7: APPROVAL INSTANCE MODEL ENUMS
-- Source: APPROVAL_INSTANCE_MODEL.md v1.0
-- ============================================================

-- ApprovalRecord status (concrete approval decision instance).
CREATE TYPE approval_record_status AS ENUM (
    'draft',        -- Being assembled; not yet submitted for approval
    'pending',      -- Submitted; awaiting approver decisions
    'approved',     -- Required quorum reached with approve decisions
    'rejected',     -- Required quorum reached with reject decisions
    'expired',      -- Approval window elapsed without reaching quorum
    'superseded'    -- A later ApprovalRecord supersedes this one
);

-- ============================================================
-- SECTION 8: OPERATIONAL MODEL ENUMS
-- Source: OPERATIONAL_MODELS.md v0.1 Draft
-- ============================================================

-- EscalationPolicy trigger type.
CREATE TYPE escalation_trigger_type AS ENUM (
    'approval_timeout',           -- Required approver did not respond within expiry window
    'no_authority_assigned',      -- Requested action has no applicable AuthorityAssignment
    'unresolvable_conflict',      -- ConflictResolutionPolicy returned escalate/steward_decides with no steward
    'validation_violation',       -- Context Broker output validation detected restricted content
    'cannot_classify',            -- Sanitization Pipeline could not safely classify content
    'dispute_opened',             -- ContestRecord created; affected actions must be frozen
    'dispute_unresolved',         -- ContestRecord exceeded resolution SLA
    'cultural_protocol_triggered',-- Action requires culturally_governed_processing; no authorization
    'agent_deprecated',           -- In-progress agent run invalidated by agent deprecation
    'capacity_change_mid_action', -- Capacity change occurred during approval workflow
    'stewardship_gap'             -- Stewardship ended with no succession; no new steward
);

-- EscalationPolicy default action if unresolved.
CREATE TYPE escalation_default_action AS ENUM (
    'freeze',               -- Block indefinitely; preserve state; notify
    'deny',                 -- Reject the action; audit; notify
    'apply_policy_default', -- Apply policy_default authority_basis_type rules
    'route_to_steward',     -- Transfer to any available active steward
    'route_external',       -- Flag for external legal or community process
    'terminate_agent_run'   -- For agent_deprecated: safely terminate in-progress run
);

-- EscalationRecord status.
CREATE TYPE escalation_record_status AS ENUM (
    'active',            -- Running; current step is waiting
    'step_advancing',    -- Timer expired; transitioning to next step
    'awaiting_external', -- Routed to external process; no LifeBook timer
    'resolved',          -- Completed with a resolution
    'default_applied',   -- Timed out; default_action applied automatically
    'cancelled',         -- Cancelled by steward or resolution of underlying trigger
    'failed'             -- Escalation pipeline error; manual intervention required
);

-- ContestRecord contest type.
CREATE TYPE contest_type AS ENUM (
    'authority_dispute',              -- Parties each claim authority
    'identity_claim_dispute',         -- Party disputes accuracy of an identity attribute
    'merge_dispute',                  -- Parties disagree whether two records are the same individual
    'split_dispute',                  -- Party claims merged record incorrectly combines two individuals
    'access_dispute',                 -- Party believes they should have access they do not hold
    'posthumous_disclosure_dispute',  -- Disagreement about posthumous disclosure
    'cultural_authority_dispute',     -- Disagreement about community authority
    'capacity_determination_dispute', -- Dispute over capacity determination
    'stewardship_dispute'             -- Disagreement about who holds stewardship
);

-- ContestRecord status.
CREATE TYPE contest_status AS ENUM (
    'open',                      -- Dispute active; frozen actions blocked
    'under_review',              -- Steward or designated reviewer is evaluating
    'pending_external',          -- Routed to external legal/cultural/community process
    'resolved',                  -- Resolution recorded; frozen actions may resume
    'closed_without_resolution', -- Closed without definitive resolution; frozen actions remain frozen
    'superseded'                 -- Superseded by a later ContestRecord or external determination
);

-- ContestRecord access mode during dispute.
CREATE TYPE contest_access_mode AS ENUM (
    'read_only_all_parties',   -- Pre-contest access maintained as read-only
    'read_only_steward_only',  -- Only steward may access during contest
    'frozen',                  -- No access except by system for preservation
    'per_party_isolation'      -- Each party sees only their own view (default)
);

-- Jurisdiction type.
CREATE TYPE jurisdiction_type AS ENUM (
    'national',              -- Sovereign nation
    'provincial_or_state',   -- Subnational unit with own privacy legislation
    'indigenous_nation',     -- First Nation, Métis nation, or equivalent self-governing entity
    'supranational',         -- Multi-national legal framework (e.g., EU GDPR)
    'international_default'  -- Fallback when no more specific jurisdiction applies
);

-- Jurisdiction right to erasure.
CREATE TYPE right_to_erasure AS ENUM (
    'strong',           -- Subject may require deletion; LifeBook must accommodate
    'qualified',        -- Subject may request erasure subject to conditions
    'limited',          -- No general right; subject may request correction only
    'none_specified'    -- Jurisdiction has not specified a right to erasure in applicable law
);

-- Default joint guardian coordination rule for a jurisdiction.
CREATE TYPE guardian_coordination_presumption AS ENUM (
    'joint_unanimous', -- All joint guardians must agree (most Canadian jurisdictions)
    'joint_any',       -- Any guardian may act alone
    'unclear'          -- No statutory presumption; LifeBook applies escalate if unspecified
);

-- JurisdictionPolicyVersion review status.
CREATE TYPE jurisdiction_review_status AS ENUM (
    'draft',
    'legally_reviewed',
    'approved',
    'superseded'
);

-- ============================================================
-- SECTION 9: CLAIM VALUE UNIT REFERENCE TABLE
-- Source: CONTENT_LAYER.md §3.2
-- ============================================================

-- ClaimValueUnit is a reference table, not an enum, because the set of
-- units must be extensible without a schema migration. Managed as seed data.
CREATE TABLE IF NOT EXISTS claim_value_units (
    unit_code          TEXT        PRIMARY KEY,
    unit_label         TEXT        NOT NULL,
    unit_category      TEXT        NOT NULL, -- e.g., 'duration', 'length', 'currency', 'count', 'other'
    si_unit            BOOLEAN     NOT NULL DEFAULT FALSE,
    requires_qualifier BOOLEAN     NOT NULL DEFAULT FALSE,
    qualifier_notes    TEXT,
    notes              TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE claim_value_units IS
    'Reference table for units of measure applicable to numeric Claims. '
    'Extensible without schema migration. Governed by CONTENT_LAYER.md §3.2.';

COMMENT ON COLUMN claim_value_units.requires_qualifier IS
    'If true, Claim.value_unit_qualifier must be non-null when this unit is used '
    '(e.g., currency requires an ISO 4217 code).';

-- Seed: 11 canonical units from CONTENT_LAYER.md §3.2
INSERT INTO claim_value_units
    (unit_code, unit_label, unit_category, si_unit, requires_qualifier, qualifier_notes, notes)
VALUES
    ('years',    'Years',    'duration', FALSE, FALSE, NULL,
        'Age in years, duration of marriage, length of employment, etc.'),
    ('months',   'Months',   'duration', FALSE, FALSE, NULL,
        'Duration or age expressed in months'),
    ('days',     'Days',     'duration', FALSE, FALSE, NULL,
        'Duration expressed in days'),
    ('km',       'Kilometres', 'length', TRUE,  FALSE, NULL,
        'Distance in kilometres'),
    ('miles',    'Miles',    'length',   FALSE, FALSE, NULL,
        'Distance in miles'),
    ('m',        'Metres',   'length',   TRUE,  FALSE, NULL,
        'Height, depth, or distance in metres'),
    ('ft',       'Feet',     'length',   FALSE, FALSE, NULL,
        'Height or distance in feet'),
    ('kg',       'Kilograms', 'weight',  TRUE,  FALSE, NULL,
        'Weight in kilograms'),
    ('lbs',      'Pounds',   'weight',   FALSE, FALSE, NULL,
        'Weight in pounds'),
    ('currency', 'Currency amount', 'currency', FALSE, TRUE,
        'ISO 4217 three-letter currency code (e.g., CAD, USD, UAH)',
        'Claim.value_unit_qualifier must be a valid ISO 4217 code when this unit is used'),
    ('count',    'Count',    'count',    FALSE, FALSE, NULL,
        'Unitless integer count (e.g., number of children, number of siblings). '
        'Use only for predicates that explicitly define a unitless integer value.')
ON CONFLICT (unit_code) DO NOTHING;

-- ============================================================
-- END OF MIGRATION 0001
-- ============================================================
