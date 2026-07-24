# LifeBook AI Context Broker
**Version:** 0.1 Draft  
**Status:** Pre-implementation architecture specification  
**Depends on:** GOVERNANCE_MODELS.md, PERSON_ATTRIBUTE_CATALOGUE.md  
**Produced:** 2026-07-23  

---

## Core Rule

> An AI agent must never receive information that it is not authorized to process for its specific purpose — not merely information it is instructed not to reveal.

Prompt instructions are not a privacy boundary. Authorization is enforced at the data-access layer before model invocation. There is no pathway by which restricted data enters a model call that is not authorized to process it.

The refinement to carry forward: the rule is not that restricted attributes can never be supplied to any AI. The rule is that every model invocation receives only the minimum data authorized for that specific **agent × user × task × purpose × output context** combination.

---

## 1. The Context Broker

The Context Broker is the mandatory gateway between all data retrieval and all model invocation. No model call is made without the Context Broker completing the following steps in sequence.

### 1.1 Responsibilities

| Step | Action |
|---|---|
| **1. Authenticate** | Verify the requesting user's identity, session, and role. Verify the agent's identity and version. Reject unrecognized agents |
| **2. Resolve authority** | Identify the Person(s) involved. Retrieve applicable AuthorityAssignment records for the action type. Confirm the requesting user holds the required role for the intended purpose |
| **3. Resolve policy** | Retrieve the applicable ApprovalPolicy for the action type and the lifecycle_status of each Person involved. Confirm the action is permitted |
| **4. Identify task and profile** | Map the request to a defined ContextProfile. Reject requests that do not map to a known profile |
| **5. Retrieve minimum data** | Query only the data categories permitted by the ContextProfile. Retrieve sources only at the authorized derivative level. No additional retrieval |
| **6. Redact embedded content** | For each retrieved document, transcript, or source text: redact or substitute restricted values embedded in prose, not only in structured fields. Run the SanitizationPipeline (§4) |
| **7. Prevent index contamination** | Confirm that no restricted content will enter embeddings, search indexes, chat history, trace logs, or model caches as a result of this invocation |
| **8. Issue context manifest** | Generate a ContextManifest (§5) documenting what data categories were supplied, at what derivative level, under which authority records |
| **9. Invoke model** | Pass the sanitized context to the model |
| **10. Validate output** | Before releasing or saving output, invoke the privacy_review profile to validate that no restricted content has leaked into the response |
| **11. Audit** | Write an audit record for every access to restricted data, regardless of outcome |

### 1.2 Failure modes

The Context Broker must fail closed, not open.

| Failure condition | Response |
|---|---|
| Agent identity cannot be verified | Reject. No data retrieved |
| Applicable ContextProfile cannot be determined | Reject. No data retrieved |
| AuthorityAssignment record is missing for the action | Apply `policy_default` basis_type. Audit. If action is consequential: reject pending explicit authority |
| Sanitization pipeline encounters content it cannot classify | Quarantine that content. Proceed without it. Note omission in ContextManifest |
| Output validation detects a violation | Quarantine output. Return error to user. Create audit record. Notify steward |
| Any step times out or fails | Reject the entire invocation. Do not proceed with partial context |

---

## 2. Context Profiles

Each ContextProfile defines the data categories a model may receive, the derivative level at which sources are provided, and the constraints on output.

Five profiles are defined at launch. Additional profiles require a formal addition to this specification and a corresponding AuthorityAssignment scope.

---

### Profile: `respectful_generation`

**Purpose:** Generate narratives, summaries, timeline entries, question prompts, or contextual content for display to family, public, or the subject themselves.

**Invoked by:** Storytelling companion agent, narrative drafting agent, question generation agent, timeline engine.

| Dimension | Specification |
|---|---|
| **Data permitted** | Preferred_name (current active) · current active pronoun_set · gender_descriptor (only if subject has enabled for this context) · public and family-authorized attributes per display policy · sanitized_summary source derivatives · extracted_claims (non-restricted) · access_metadata |
| **Data denied** | former_name (all) · birth_name (unless subject has enabled) · legal_name (unless same as preferred) · indigenous_name · ceremonial_name · institutional_name · gender_descriptor (if not subject-enabled) · exact_transcript · identity_resolution_tokens · any attribute with display_policy denying family_ui or public_ui |
| **Source derivative level** | `sanitized_summary` only |
| **Output constraints** | Must use current authorized display identity throughout. Must not reproduce any value that was absent from the supplied context. Pronouns must match current active pronoun_set for all references, including references to past periods |
| **Output requires validation** | Yes. Privacy_review profile validates before save or display |
| **Audit level** | Standard. Access to any person-level data is logged |
| **Cannot be used for** | Genealogical identity matching · merge decisions · publication of sensitive information |

---

### Profile: `archival_transcription`

**Purpose:** Process exact source documents to produce structured derivatives: exact transcript, extracted claims, sanitized summary, identity-resolution tokens. This profile operates on source material, not on person profiles.

**Invoked by:** Document extraction agent, handwriting analysis agent, photograph analysis agent, archival import agent.

| Dimension | Specification |
|---|---|
| **Data permitted** | The exact source document, at the source's access classification · access_metadata for related persons · no person profile data beyond what is necessary to associate extracted claims with Person anchors |
| **Data denied** | Person profile attributes from other contexts · other sources not being processed in this invocation · preferred name / pronoun data (the agent processes the source as it exists; it does not have access to current identity to perform substitution — that is the SanitizationPipeline's role) |
| **Source derivative level** | `exact_transcript` (under source access classification) |
| **Output constraints** | Output is classified at the source's access level. Output does not automatically flow to any other context. Exact transcript output is a restricted derivative — it must not be passed to any agent operating under a different profile without a reclassification step and human review |
| **Output requires validation** | Yes. Output is quarantined at source access level pending human review before any derivative is promoted or reclassified |
| **Audit level** | Elevated. Every invocation, every document accessed, and every output derivative is logged with the manifest |
| **Cannot be used for** | Generating user-facing content · identity resolution · updating person profiles without human review of extracted claims |

---

### Profile: `identity_resolution`

**Purpose:** Match persons across records; evaluate potential duplicate Person records; search for genealogical connections; associate historical records with Person anchors.

**Invoked by:** Identity resolution agent, duplicate detection agent, genealogical research agent.

| Dimension | Specification |
|---|---|
| **Data permitted** | identity_resolution_tokens · former_name (only with explicit steward authorization per query, logged) · birth_name · legal_name · historical name records at `identity_resolution_search` permission level · extracted_claims (non-restricted) · access_metadata |
| **Data denied** | pronoun_set · gender_descriptor · culturally governed attributes · sanitized_summary · exact_transcript (unless authorized under a separate archival_transcription invocation) · preferred_name for output purposes (may be used internally for de-duplication only) |
| **Source derivative level** | `identity_resolution_tokens` and `extracted_claims` only |
| **Output constraints** | Output is restricted. The agent may produce: match confidence scores, Person anchor IDs, claim association recommendations, and conflict flags. Output must **not** contain readable restricted values (former names, birth names) as text strings. A human reviews all match recommendations before any match is surfaced to a user or written to the record |
| **Output requires validation** | Yes. Privacy_review validates that no restricted values appear in output text |
| **Audit level** | Mandatory. Every query, every record accessed, every result returned, and every authorization consulted is logged. The log entry for each restricted attribute accessed must include the specific steward authorization record ID |
| **Authorization requirement** | Steward authorization is required per query for access to former_name and birth_name. General users cannot invoke this profile. This profile is not available to the subject themselves without steward co-authorization |
| **Cannot be used for** | Generating user-facing narratives · publishing information · providing search results to general users |

---

### Profile: `privacy_review`

**Purpose:** Validate that generated content does not contain restricted information. This is step 10 of the Context Broker and may also be invoked independently for auditing.

**Invoked by:** Context Broker (output validation step) · compliance audit process.

| Dimension | Specification |
|---|---|
| **Data permitted** | Restricted attribute values (for comparison only, not for output) · generated content to be validated · ContextManifest of the invocation being validated |
| **Data denied** | Source documents · person profiles beyond what is necessary for comparison |
| **How restricted values are used** | Hashed comparison only. The agent receives a hash index of restricted strings, not the strings themselves. It checks whether any hash in the generated content matches a restricted hash. The restricted value itself is never in the agent's context as a readable string |
| **Output constraints** | Returns only: `validated` or `violation_detected`. If violation: returns violation type (e.g., `restricted_former_name_detected`) and character position. Never reproduces the restricted value in output. Never caches the restricted hash index beyond the duration of the invocation |
| **Output requires validation** | Not recursively. Privacy_review is the terminal validation step |
| **Audit level** | Mandatory. All invocations and outcomes logged |
| **Cannot be used for** | Generating content · accessing records for any purpose other than validation |

---

### Profile: `culturally_governed_processing`

**Purpose:** Process culturally governed information — including Indigenous names, ceremonial names, and other attributes subject to community authority — under explicit joint authorization.

**Default state: DENIED.**

This profile cannot be invoked without active, documented AuthorityAssignment records from both the subject and the designated community authority. The absence of joint authorization is not a configuration gap — it is the correct default state. Cultural protocols may determine that digital processing of specific information is not appropriate at all, regardless of authorization.

**Invoked by:** No agent may invoke this profile autonomously. Invocation requires explicit, human-initiated authorization per session.

| Dimension | Specification |
|---|---|
| **Data permitted** | Only data explicitly authorized in the joint authorization records. Authorization must specify which data categories, which agent, which purpose, and which output classification |
| **Data denied** | Everything not explicitly authorized. Default deny |
| **Source derivative level** | As specified in the joint authorization. If not specified: exact_transcript only, at the highest restriction level |
| **Output constraints** | Output remains classified at the same restriction level as input. Output does not flow to any other profile automatically. All output is quarantined pending review by the authorizing parties |
| **Output requires validation** | Yes. Both subject and community authority must review output before any release |
| **Audit level** | Maximum. Every invocation, every data access, every output, and every authorization check is logged with full detail. Logs for this profile are classified at the same level as the data |
| **Succession** | Joint authorization does not transfer automatically. If subject dies, community authority governs whether processing continues, under what conditions, and whether any stored outputs may be retained |
| **Pre-deployment requirement** | This profile must not be enabled until the Indigenous governance policy (GOVERNANCE_MODELS.md §9 open question 6) is completed. Enabling the schema fields is permitted. Enabling the processing pathway is not |
| **Cannot be used for** | Any purpose not explicitly authorized in the joint authorization record |

---

## 3. Agent Registry

Every agent that may invoke the Context Broker must be registered. An unregistered agent cannot receive data.

### 3.1 AgentRegistration fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `agent_code` | String | Stable identifier (e.g., `storytelling_companion_v1`) |
| `agent_version` | String | Semantic version |
| `permitted_profiles` | Array\<ContextProfile\> | Which profiles this agent may use |
| `permitted_action_types` | Array\<ActionType\> | Which actions this agent may initiate |
| `max_data_categories` | JSONB | Upper bound on data categories per profile; may be narrower than profile default |
| `output_destination_types` | Array\<Enum\> | Where this agent may write output (e.g., `draft_narrative`, `claim_suggestion`, `audit_log`) |
| `requires_human_review_before_save` | Boolean | Whether all output must be reviewed before being written to the record |
| `cost_limit_per_invocation` | Decimal | Token or cost ceiling |
| `is_active` | Boolean | |
| `registered_at` | Timestamp | |
| `registered_by_id` | UUID FK | |
| `deprecation_date` | Date | Nullable |

### 3.2 Launch agent registry

| agent_code | permitted_profiles | output_destination | review_required |
|---|---|---|---|
| `storytelling_companion` | respectful_generation | draft_narrative · prompt_suggestion | Yes |
| `document_extractor` | archival_transcription | source_derivative · claim_suggestion | Yes |
| `identity_resolver` | identity_resolution | match_recommendation · conflict_flag | Yes, human must approve all matches |
| `privacy_validator` | privacy_review | validation_result · audit_log | No (it is the validator) |
| `narrative_drafter` | respectful_generation | draft_narrative | Yes |
| `question_generator` | respectful_generation | prompt_suggestion | No (prompts, not facts) |
| `translation_agent` | respectful_generation · archival_transcription | translated_derivative | Yes |
| `historical_context_agent` | respectful_generation | context_package | Yes |
| `conflict_detector` | respectful_generation · identity_resolution | conflict_flag | No (flags only; resolution requires human) |

`culturally_governed_processing` is not assigned to any launch agent. It requires explicit registration of a purpose-specific agent per engagement.

**Deferred registration — Memory Atmosphere Engine (2026-07-24):**  
A `memory_atmosphere_policy_evaluator` entry is required in this registry when the Memory Atmosphere Engine is implemented. The name reflects its function: it evaluates governed policy inputs to produce an atmosphere profile. It does not retrieve material, authenticate evidence, establish facts, or choose imagery independently.

It will operate under the `respectful_generation` Context Profile with a narrowed `max_data_categories` constraint excluding all content with `access_classification = restricted` or `culturally_governed`. The evaluator receives settled context, topic signals, and artifact permissions as read-only inputs via the broker; it produces `AtmosphereProfile` outputs only. No sensitive material enters its context. Registration is deferred pending implementation. See `MEMORY_ATMOSPHERE_ENGINE.md` and `ADR-0002`.

---

## 4. Sanitization Pipeline

The Sanitization Pipeline is invoked at step 6 of the Context Broker. It processes every retrieved document, transcript, and source text before it enters the model context.

### 4.1 What is sanitized

The pipeline does not only remove structured attribute fields. It processes all prose, metadata, and embedded text, replacing restricted values wherever they appear.

| Content type | Sanitization action |
|---|---|
| Structured attribute field | Omit entirely if denied; supply if permitted |
| Name appearing in prose text | Replace with authorized substitution (see §4.2) |
| Pronoun appearing in prose text | Replace with current authorized pronoun set if different |
| Date with insufficient precision authorization | Replace with authorized precision level (exact → approximate → range → [date redacted]) |
| Location with sensitivity concern | Replace with authorized granularity (street address → city → region → [location redacted]) |
| Embedded metadata in images or documents | Strip and re-evaluate; do not pass through automatically |
| Referenced person not authorized in this context | Replace with [person: role_descriptor] (e.g., [person: sibling]) |

### 4.2 Substitution values

| Restricted type | Substitution in prose |
|---|---|
| former_name | `[name in original: see restricted record]` in archival contexts · `[subject's preferred name]` replaced by actual preferred name in generation contexts |
| birth_name | `[birth name: restricted]` |
| indigenous_name | `[name: culturally restricted]` |
| ceremonial_name | `[name: culturally restricted]` |
| institutional_name | `[institutional record name: see historical record]` |
| gender_descriptor (not authorized) | Omit from context |
| Pronoun (historical, superseded) | Replace with current authorized pronoun set before supplying to generation agent |

### 4.3 Sanitization record

Every sanitization action is recorded in the ContextManifest:
- Which content item was sanitized
- Which substitution was applied
- Which restricted type triggered the substitution

The sanitization record is not supplied to the model. It is retained in the manifest for audit purposes.

### 4.4 Cannot-classify escalation

If the pipeline encounters embedded content it cannot confidently classify (e.g., an ambiguous name that may or may not be restricted, content in an unknown encoding), it quarantines that content and notes the omission in the ContextManifest. The invocation continues without the quarantined content. The quarantine is logged for human review.

---

## 5. Sanitized Source Derivatives

One Source record in LifeBook may produce multiple derivative artifacts, each classified at a different access level and available to different ContextProfiles.

### 5.1 Derivative types

| Derivative | Access classification | Available to profile | Description |
|---|---|---|---|
| `exact_transcript` | Source access level (typically restricted) | archival_transcription only | Verbatim reproduction of the source. Immutable after capture. Never automatically reclassified |
| `extracted_claims` | Steward | archival_transcription · identity_resolution | Structured claims extracted from the source. Claim text, not full source text. Person associations pending human review |
| `sanitized_summary` | Defined per summary (may be family or public) | respectful_generation · historical_context | A prose summary of the source in which restricted values have been replaced by the Sanitization Pipeline and a human reviewer has confirmed redaction |
| `identity_resolution_tokens` | Restricted: identity_resolution profile only | identity_resolution | Tokenized or hashed identifiers enabling matching without readable restricted values |
| `access_metadata` | Any authenticated user | Any | Source exists, type, approximate date, number of persons referenced. No content |

### 5.2 Derivation process

Derivatives are produced by the document_extractor agent under the archival_transcription profile. The process:

1. `exact_transcript` is produced and classified at source access level. Immutable.
2. `extracted_claims` are produced by the agent and quarantined pending human review.
3. A human steward reviews extracted_claims, corrects associations, and marks as `human_reviewed`.
4. `identity_resolution_tokens` are generated from reviewed claims. A human authorizes token generation.
5. `sanitized_summary` is produced by the agent, then reviewed by a human who confirms all restricted content has been replaced. The reviewer approves the summary's access classification.
6. `access_metadata` is generated automatically from source registration.

No derivative is promoted to a lower restriction level without an explicit human action. The document_extractor agent does not self-approve derivative reclassification.

### 5.3 Derivative isolation

Derivatives do not automatically share context with each other.

- An agent receiving `sanitized_summary` does not thereby receive `exact_transcript`.
- An agent receiving `identity_resolution_tokens` does not thereby receive `extracted_claims` text.
- Each derivative is retrieved independently, per the ContextProfile's authorized derivative level.

---

## 6. Context Manifest

The Context Broker issues a ContextManifest with every model invocation. The manifest is stored permanently and forms part of the provenance record for any AI action.

### 6.1 Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `invocation_id` | UUID | Links to the model invocation record |
| `agent_code` | String | Which agent was invoked |
| `agent_version` | String | |
| `user_id` | UUID FK | |
| `user_role` | AuthorityRole | Role under which the user is acting for this invocation |
| `context_profile` | ContextProfile | Which profile was applied |
| `persons_involved` | Array\<UUID\> | Person anchor IDs whose data was retrieved |
| `authority_assignments_consulted` | Array\<UUID\> | AuthorityAssignment record IDs consulted |
| `approval_policies_consulted` | Array\<UUID\> | ApprovalPolicy record IDs consulted |
| `data_categories_supplied` | Array\<String\> | Category names (not values) of data supplied to the model |
| `source_derivatives_supplied` | JSONB | Source ID → derivative type for each source supplied |
| `restricted_categories_accessed` | Array\<String\> | Category names of any restricted data accessed (not values) |
| `sanitization_actions` | Array\<SanitizationRecord\> | What was redacted or substituted and why |
| `content_quarantined` | Boolean | Whether any content was quarantined due to cannot-classify |
| `output_validation_result` | Enum: validated / violation_detected / pending | |
| `output_quarantined` | Boolean | Whether output was quarantined due to violation |
| `timestamp` | Timestamp | |
| `manifest_hash` | String | Hash of manifest content for tamper detection |

### 6.2 Manifest retention

Manifests are never deleted. They form part of the audit trail. Manifests for invocations involving restricted data are classified at the same level as the most restricted data category accessed.

---

## 7. Embedding and Index Hygiene

Restricted content must not enter:
- Vector embedding stores used for semantic search
- Full-text search indexes (ordinary or identity-resolution)
- Conversational history stores (chat history)
- LLM observability traces or logs
- Model prompt caches

### 7.1 Embedding classification

Each embedding is generated at a specific access level and is tagged with that level. Embeddings are stored in separate collections or namespaces per access level. A query to a `public` embedding collection cannot return results from a `restricted` collection.

Embeddings for a person's profile are generated per ContextProfile:
- A `respectful_generation` embedding of a person contains only data permitted by that profile.
- An `identity_resolution` embedding is built from identity_resolution_tokens, not from readable text.
- No single embedding encodes both public and restricted content about the same person.

### 7.2 Chat history

Conversational history passed to a model as context is itself treated as a data source subject to the Context Broker. Each history message carries a classification tag. History messages containing restricted data are stripped from context unless the current ContextProfile authorizes access to that data category.

### 7.3 Prompt cache isolation

If prompt caching is used (e.g., Anthropic's prompt caching feature), cache keys must include the ContextProfile as a component. A cached context segment from an `identity_resolution` invocation cannot be served to a `respectful_generation` invocation. Cache entries containing restricted data are tagged at the appropriate access level and served only to invocations authorized for that level.

### 7.4 Trace and log classification

All observability traces, logs, and debugging output are classified at the level of the most restricted data that passed through the invocation. Traces for identity_resolution or culturally_governed_processing invocations are restricted and are not accessible through standard observability tooling. A separate access control layer governs restricted trace access.

---

## 8. Output Validation Detail

Step 10 of the Context Broker. Invokes the privacy_review profile.

### 8.1 What is validated

| Check | Description |
|---|---|
| Restricted name detection | Hashed comparison: checks whether any hash in the output matches a hash in the restricted name index for involved persons |
| Pronoun consistency | Checks that pronouns in output match the current authorized pronoun set for each referenced person |
| Data category consistency | Checks that the output does not appear to reference data categories not present in the ContextManifest |
| Identity marker detection | Heuristic check for patterns that might encode restricted identity information (date+name combinations, unusual name forms) |

### 8.2 Restricted name index

The restricted name index contains hashed forms of:
- All former_name values for involved persons
- All birth_name values not authorized in this context
- All indigenous_name and ceremonial_name values
- All institutional_name values

The index is regenerated per invocation and not persisted beyond the validation step. The index is not itself accessible to any agent — it is an internal structure of the Context Broker.

### 8.3 Violation handling

If a violation is detected:
1. Output is quarantined. Not returned to user. Not saved.
2. Audit record created with violation type and manifest ID.
3. Steward is notified.
4. User receives a generic error: "Content could not be generated. A steward has been notified."
5. The restricted value that triggered the violation is not disclosed in the error message.

---

## 9. Implementation Notes

### 9.1 This is not a single service

The Context Broker is an architectural pattern and a set of mandatory behaviors, not necessarily a single microservice. Implementations may distribute these responsibilities across components. What must not be distributed is the enforcement guarantee: no model call without context resolution, no output without validation.

### 9.2 Order of implementation

The following sequence is recommended:

1. Define the ContextProfile enum and AgentRegistration table in the migration.
2. Implement the ContextManifest record structure.
3. Implement basic authentication and profile resolution (no model calls until this exists).
4. Implement the Sanitization Pipeline for structured attribute fields only.
5. Add prose-level sanitization for source text.
6. Implement output validation (privacy_review profile) using hash comparison.
7. Implement embedding classification and collection separation.
8. Implement chat history classification.
9. Implement prompt cache isolation.
10. Enable the identity_resolution profile under steward authorization.
11. Leave culturally_governed_processing disabled until governance policy is complete.

### 9.3 The model is replaceable; the broker is not

The Context Broker's purpose is to make the underlying model irrelevant to the privacy guarantee. Whether LifeBook uses Claude, GPT, Gemini, or a self-hosted model, the same Context Broker enforces the same rules. The model receives a sanitized, classified context. It does not know what it is not receiving. It cannot circumvent a restriction it is not aware of.

This is why the core rule is stated as it is: the agent must never receive what it is not authorized to process. Instruction-based restrictions rely on the model following instructions. Access-layer restrictions do not.

### 9.4 What the AI may autonomously produce

For absolute clarity:

| Action | Autonomous AI permitted |
|---|---|
| Generate a draft narrative using permitted data | Yes — subject to output validation and human review gate before save |
| Suggest a follow-up question | Yes — no save gate required |
| Flag a potential conflict for human review | Yes — the flag itself is not a consequential action |
| Extract claims from a source | Yes — under archival_transcription profile; claims quarantined for human review |
| Elevate evidence_status to corroborated | **No** |
| Approve a merge recommendation | **No** |
| Promote AI output to accepted narrative | **No** — human review required |
| Assign or modify authority | **No** |
| Change display or export policy | **No** |
| Invoke culturally_governed_processing | **No** — human-initiated authorization required |
| Access restricted data outside authorized profile | **No** — enforced at data layer |

---

## 10. Multi-Person Invocation Aggregation

Authorization is resolved per person, per attribute, per task, and per output context. Each person in a multi-person invocation receives an independently resolved context projection. The combined model context contains only the permitted intersection necessary for the requested output.

A restriction on Person A for attribute X does not automatically remove permitted attribute Y about Person B. Restrictions are resolved per attribute per person, then aggregated.

### 10.1 Aggregation outcomes

| Outcome | Meaning | Action |
|---|---|---|
| `permit` | All persons' required attributes are permitted in the combined context | Supply combined context to model |
| `permit_with_redaction` | One or more persons' specific values must be substituted, but the invocation can proceed with sanitized content | Run Sanitization Pipeline; supply redacted combined context |
| `permit_with_partition` | Restrictions interact across persons such that a combined context would be unsafe; separate invocations are possible | Run per-person partitioned invocations (§10.2); combine sanitized derivatives in final call |
| `require_joint_approval` | The requested output requires authorization not yet obtained from one or more persons' authority holders | Pause; create approval workflow; return pending status to user |
| `quarantine` | Restrictions cannot be safely separated, or the meaning of the output would be materially distorted by the required redaction | Quarantine; notify steward; return error |
| `deny` | The invocation cannot proceed as requested; a person has denied participation in this output context, or separation is impossible | Deny; audit; return error |

**Governing principle:** Where restrictions cannot be safely separated, where meaning would be materially distorted by redaction, or where any person has denied participation in the output context, the most restrictive rule governs and the invocation fails closed.

### 10.2 Permit-with-partition workflow

`permit_with_partition` is the preferred outcome for high-sensitivity multi-person content. It avoids the risks of combined context by running separate authorized invocations per person and combining only sanitized derivatives.

1. The Context Broker identifies that a combined context is unsafe.
2. For each person involved: a separate Context Broker invocation is run under that person's specific authorizations and ContextProfile. Each invocation produces a validated, sanitized output fragment for that person only.
3. Each output fragment is classified at the appropriate level and retained as a sanitized derivative.
4. A final Context Broker invocation receives only the sanitized derivatives from step 2 — not the underlying person data.
5. The final model call assembles the output from the sanitized derivatives.
6. A single ContextManifest is produced for the final invocation, with references to the per-person manifest IDs from step 2.

### 10.3 Resolution algorithm

For each data category needed for the requested output, and for each person referenced:

```
resolve(person, attribute, contextProfile, outputContext) →
  permitted_intersection across all persons for this attribute

if all persons → permit:            aggregate = permit
if any person → deny AND cannot exclude without distorting output: aggregate = deny
if any person → deny AND can exclude safely:                        aggregate = permit_with_redaction
if restrictions interact across persons:                            aggregate = permit_with_partition (preferred)
if required authorization not yet obtained:                         aggregate = require_joint_approval
if separation unsafe or meaning distorted:                          aggregate = quarantine or deny
```

The algorithm runs per attribute category. The final aggregation for the invocation is the most restrictive outcome across all attribute categories required.

---

## 11. AccessPolicyChanged Event

An event-driven invalidation mechanism fires whenever any record that affects authorized access changes. Content-addressed model caching is helpful operationally but is not the authorization mechanism and is not sufficient for revocation.

### 11.1 Trigger conditions

Any of the following changes must fire an `AccessPolicyChanged` event:

| Trigger | Description |
|---|---|
| `authority_assignment_changed` | AuthorityAssignment created, updated, terminated, or expired |
| `display_policy_changed` | Attribute display, search, or export policy modified |
| `stewardship_succession` | Stewardship transferred to a new holder |
| `capacity_change` | New CapacityDetermination record created or an existing one revised |
| `death_recorded` | Subject's lifecycle status updated to deceased |
| `dispute_opened` | ContestRecord opened; affected actions frozen |
| `dispute_resolved` | ContestRecord resolved; frozen actions may resume |
| `deletion_or_redaction` | A record is deleted, suppressed, or redacted |
| `source_reclassification` | A source's access classification changes |
| `cultural_authorization_withdrawn` | Joint authorization for culturally_governed_processing is revoked |
| `merge_or_split_applied` | Person records merged or split; all derived artifacts for affected IDs must be revalidated |
| `agent_deprecated` | An agent registration is deactivated; paused runs under that agent must be terminated |
| `cross_lifebook_authorization_revoked` | A CrossLifeBookAuthorization record is suspended or revoked; all artifacts and permissions produced under it must be invalidated |

### 11.2 AccessPolicyChanged event fields

| Field | Type | Notes |
|---|---|---|
| `event_id` | UUID | |
| `event_type` | Enum | From trigger list above |
| `triggered_at` | Timestamp | |
| `triggered_by_id` | UUID FK | User or system process that initiated the change |
| `person_ids_affected` | Array\<UUID\> | All Person anchors whose access policy has changed |
| `source_ids_affected` | Array\<UUID\> | Nullable; for source_reclassification |
| `agent_code_affected` | String | Nullable; for agent_deprecated |
| `trigger_record_type` | String | The record type that changed (e.g., `AuthorityAssignment`) |
| `trigger_record_id` | UUID | The specific record that changed |
| `invalidation_scope` | JSONB | Which derived artifact types must be invalidated (see §11.3) |
| `processing_status` | Enum: pending / in_progress / completed / failed | |
| `completed_at` | Timestamp | Nullable |

### 11.3 Derived artifacts requiring invalidation

Every derived artifact type must retain lineage (§11.4) to support targeted invalidation. Upon receiving an `AccessPolicyChanged` event, the following artifact types must be evaluated and invalidated or reclassified where the lineage connects them to the changed records:

| Artifact type | Invalidation action |
|---|---|
| Prompt cache segments | Invalidate entries whose lineage references affected person_ids or policy records |
| Embedding vectors | Reclassify or regenerate embeddings for affected persons and ContextProfiles |
| Ordinary search index entries | Remove or reclassify entries for affected persons |
| Identity-resolution search index entries | Remove or reclassify entries for affected persons |
| Chat-history context segments | Mark segments containing affected data as `policy_superseded`; strip from future context assembly |
| Sanitized summaries | Mark as `under_review`; require human re-approval before further use |
| Identity-resolution tokens | Invalidate tokens derived from now-restricted attributes |
| Paused agent runs | Evaluate whether the paused run's context is still valid; terminate if not |
| Active approval workflows | Re-evaluate whether the approval policy still applies; notify affected parties |
| ContextManifests | Mark as `policy_superseded`; manifests are never deleted but are flagged when their policy basis has changed |

### 11.4 Cross-LifeBook revocation scope

When the trigger is `cross_lifebook_authorization_revoked`, the invalidation scope extends beyond the standard §11.3 table. The revoked `CrossLifeBookAuthorization` record must be identified, and every artifact or permission produced under it must be evaluated and invalidated. The following items must be processed in addition to the general §11.3 actions:

| Scope | Invalidation action |
|---|---|
| Shared sanitized derivatives | Any SanitizedSourceDerivative (exact_transcript, extracted_claims, sanitized_summary, identity_resolution_tokens, access_metadata) produced under or shared via the revoked authorization must be marked `invalidated`; they may not be supplied to any further model invocation |
| Cross-LifeBook claim references | Any Claim, ClaimEvidence, or NarrativeEntity record that was accessible only by virtue of the revoked authorization must be re-evaluated for accessibility; visibility flags and display policies must be recalculated |
| Contact permissions | Any cross-LifeBook contact or communication permissions derived from the authorization must be suspended immediately |
| Embeddings and search projections | Embedding vectors and search index entries produced from cross-LifeBook data supplied under the revoked authorization must be reclassified or removed |
| Prompt cache segments | Cache segments whose lineage references the CrossLifeBookAuthorization ID must be invalidated |
| Chat-history context segments | Segments containing cross-LifeBook data assembled under the revoked authorization must be marked `policy_superseded` and stripped from future context assembly |
| Pending invitations | Any cross-LifeBook invitation (to view, contribute, or link) issued under the revoked authorization must be cancelled or held pending re-authorization |
| Paused cross-LifeBook agent runs | Agent runs paused with cross-LifeBook context assembled under the revoked authorization must be terminated; they may not be resumed without a new authorization and fresh context assembly |
| Derived artifacts with revoked-authorization lineage | Any artifact carrying the revoked `CrossLifeBookAuthorization` ID in its lineage (authority_assignment_ids or cross_lifebook_authorization_id) must be invalidated regardless of artifact type |

The revocation event must record the `CrossLifeBookAuthorization` ID in `trigger_record_id` and populate `invalidation_scope` with the full list of affected artifact types. Revocation is immediate and irreversible; re-authorization requires a new `CrossLifeBookAuthorization` record.

### 11.5 Artifact lineage fields

Every derived AI or search artifact must carry the following lineage fields:

| Field | Notes |
|---|---|
| `source_record_ids` | IDs of all source records used to produce this artifact |
| `policy_version_id` | The version of all policies (ApprovalPolicy, ConflictResolutionPolicy, display policy) in effect at creation |
| `authority_assignment_ids` | All AuthorityAssignment records consulted during the Context Broker invocation that produced this artifact |
| `context_manifest_id` | The ContextManifest for the producing invocation |
| `created_at` | Timestamp |
| `validity_state` | Enum: `valid` / `policy_superseded` / `under_review` / `invalidated` / `expired` |
| `invalidated_at` | Timestamp; nullable |
| `invalidation_event_id` | FK to AccessPolicyChanged event; nullable |

`validity_state` must be checked before any artifact is used in a new model invocation. An artifact with state other than `valid` must not be supplied to a model context without re-authorization.

---

## 12. Open Questions

1. **Restricted name index technology:** Hashed comparison is specified for output validation. The specific hashing approach (length-preserving, order-preserving, or opaque) must be determined based on what is detectable in free prose while preserving privacy.

2. **Cannot-classify escalation workflow:** When the Sanitization Pipeline quarantines content it cannot classify, who is notified? What is the review timeline? This needs an EscalationPolicy record.

3. **Multi-person invocations:** A narrative may involve multiple persons with different authority and access profiles. The Context Broker must resolve the most restrictive profile among all involved persons. The resolution rule for cross-person invocations must be specified.

4. **Agent versioning:** When an agent is updated, existing ContextManifest records reference the previous version. The audit trail must handle agent version history. Deprecated agent versions must not receive new authorizations.

5. **Prompt cache invalidation on authority change:** If a person's AuthorityAssignment changes (a steward is replaced; a subject regains capacity), cached prompt segments that encoded the old authority state must be invalidated. The mechanism for this must be specified.

---

*Next step: EscalationPolicy and ContestRecord tables, Jurisdiction table schema, then Person anchor and Supabase migration.*
