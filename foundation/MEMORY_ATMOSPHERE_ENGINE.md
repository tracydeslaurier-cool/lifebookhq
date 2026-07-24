# Memory Atmosphere Engine
**Version:** 0.1 Draft  
**Status:** Architectural specification — not yet implemented  
**Classification:** New subsystem — architectural preservation only  
**Depends on:** AI_CONTEXT_BROKER.md, GOVERNANCE_MODELS.md, CONTENT_LAYER.md, OPERATIONAL_MODELS.md, ANCHOR_MODELS.md  
**Produced:** 2026-07-24  
**Produced by:** Discovery Partner + Claude (architecture session)

---

## Foundational Principle

> **LifeBook must never tell the participant what to remember. It may only create conditions that help authentic memories emerge.**

This principle is absolute. It governs every design decision in this subsystem. Any feature, output, or behaviour that directs, biases, dramatizes, or manufactures recollection is prohibited — regardless of how natural or helpful it might appear.

Two corollaries follow directly:

> **Atmosphere follows the conversation's settled context, not its latest keyword.**

A single word or brief aside does not constitute a topic change. The engine responds to stable, persistent conversational context — not to surface-level noun matching.

> **Atmosphere must always be subordinate to cognition.**

The participant is thinking. The environment exists to support that thinking, not to compete with it, direct it, or substitute for it. Where there is any doubt, the engine retreats to stillness.

---

## Core Distinction

The Memory Atmosphere Engine is **not** a background-image generator.

It does not ask: *What picture should be displayed?*

It asks: *What emotional and sensory environment best supports authentic remembering?*

The default output is **abstract atmosphere** — colour, light, texture, spatial openness — not literal imagery.

### The spectrum from abstract to specific

| Mode | Description | Example |
|---|---|---|
| Abstract | Colour temperature, luminance, spatial quality | Warm amber field; open blue-grey |
| Suggestive | Non-specific environmental hints | Stained-glass coloration; soft outdoor openness |
| Generic representational | Non-specific class of environment | Domestic warmth without a specific room |
| Authenticated personal | Participant-provided or historically verified | Subject's own photographs under consent |

Specific or personalized imagery appears **only** when supported by authenticated material:
- participant-provided photographs
- verified archival material
- previously governed artifacts

The engine does not generate, retrieve, or infer specific imagery from conversation content alone.

### Abstract vs. literal — examples

| Settled topic | Wrong response | Correct response |
|---|---|---|
| Childhood faith and community | A specific church interior | Faint stained-glass colouration |
| Outdoor recreational memory | A literal golf course | Soft outdoor openness |
| Domestic life and family | A specific kitchen | Warm domestic light |
| Traumatic or difficult memory | Dramatic or evocative visual | Stillness and neutral support |
| Rapidly shifting topic | Rapid visual change | No change; maintain settled state |

---

## 1. Subsystem Responsibilities

The Memory Atmosphere Engine is responsible for:

1. Receiving settled context signals from the AI Context Broker and Voice/Conversation System
2. Evaluating topic stability, emotional intensity, sensitivity risk, and confidence before any atmosphere change
3. Producing an atmosphere profile that governs presentation parameters
4. Holding the atmosphere steady through topic inertia (§4)
5. Retreating toward stillness when confidence is low, sensitivity is high, or topic stability is insufficient
6. Enforcing all safety and accessibility constraints as hard limits before any output
7. Passing atmosphere profiles to the presentation layer — it does not itself render, animate, or retrieve imagery

The Memory Atmosphere Engine does **not**:

- Independently retrieve, authenticate, or govern source material
- Access the Governance Engine or Content Layer directly
- Generate imagery
- Determine which specific artifacts may be shown (that is the Governance Engine's responsibility)
- Modify conversation flow, questions, or prompts

---

## 2. Inputs

The engine receives the following inputs from upstream subsystems. All inputs are read-only from the engine's perspective.

### 2.1 From the AI Context Broker

| Input | Description |
|---|---|
| `settled_topic` | The stable conversational topic after inertia evaluation — not the latest keyword |
| `topic_stability_score` | Numeric (0–1): how long and consistently the topic has persisted |
| `topic_confidence` | Numeric (0–1): the broker's confidence that the topic identification is correct |
| `emotional_intensity_signal` | Enum: `neutral` / `positive` / `reflective` / `elevated` / `sensitive` |
| `sensitivity_risk` | Enum: `none` / `low` / `moderate` / `high` / `trauma` |
| `source_authenticity_level` | Enum: `none` / `inferred` / `generic` / `authenticated` / `participant_provided` |

### 2.2 From the Governance Engine (via Context Broker)

| Input | Description |
|---|---|
| `available_artifacts` | List of artifact IDs permitted for display under current governance — may be empty |
| `personalization_permitted` | Boolean: whether authenticated personal imagery may be used at all in this session |
| `consent_record_id` | FK to applicable consent record if personalization is permitted; null otherwise |
| `cultural_constraints` | Flags or policy references that restrict specific imagery types |
| `governance_tier` | Current maximum atmosphere level permitted (0–4) under current governance state |

### 2.3 From Participant Preferences and Accessibility Settings

| Input | Description |
|---|---|
| `prefers_reduced_motion` | Boolean: from OS/browser signal and stored preference |
| `atmosphere_profile` | Enum: `off` / `minimal` / `still` / `reflective` / `richer` — participant-selected |
| `visual_memory_responsiveness` | Boolean: participant has indicated positive response to visual atmosphere |
| `static_mode_required` | Boolean: no animation under any circumstances |
| `contrast_requirements` | Enum: `none` / `high_contrast` / `dark_mode_only` |

### 2.4 From the Voice/Conversation System

| Input | Description |
|---|---|
| `turn_state` | Enum: `listening` / `processing` / `responding` / `idle` |
| `topic_continuity_signal` | Whether the current turn continues or shifts the settled topic |
| `elapsed_dwell_ms` | How long the current settled topic has persisted in the conversation |

---

## 3. Outputs

The engine produces a single **AtmosphereProfile** — a structured package of presentation parameters passed to the presentation layer. It does not produce images, CSS, animations, or audio directly.

| Output field | Type | Description |
|---|---|---|
| `atmosphere_level` | Integer (0–4) | See §5 |
| `colour_warmth` | Numeric (0–1) | 0 = cool/neutral; 1 = warm |
| `luminance` | Numeric (0–1) | 0 = dark/minimal; 1 = bright |
| `openness` | Numeric (0–1) | 0 = enclosed/intimate; 1 = expansive/open |
| `texture_presence` | Numeric (0–1) | 0 = clean/flat; 1 = organic/textured |
| `motion_level` | Enum: `none` / `breath` / `gentle` / `moderate` | Maximum animation intensity |
| `transition_speed` | Enum: `instant` / `slow` / `very_slow` | Transition between atmosphere states |
| `image_opacity` | Numeric (0–1) | Opacity cap for any representational content |
| `audio_permitted` | Boolean | Whether ambient audio may accompany (always false in initial implementation) |
| `personalization_level` | Integer (0–4) | Mirror of atmosphere_level; capped by governance_tier |
| `consent_required_before_display` | Boolean | Whether explicit in-session consent is needed before showing this profile's content |
| `neutral_fallback_active` | Boolean | Whether the engine has retreated to Level 0 due to a safety trigger |
| `retreat_reason` | Enum: `sensitivity` / `low_confidence` / `low_stability` / `safety_constraint` / `governance` / `participant_preference` | Why retreat was applied; for audit only, never displayed |

---

## 4. Memory Inertia

**The engine must not react to every noun or sentence.**

A participant mentioning their daughter wanting to go golfing while discussing a significant memory of their childhood faith does not constitute a topic shift. Reacting to surface keywords would destabilize the environment precisely when cognitive support is most needed.

### 4.1 Topic change requirements

For the engine to transition away from a settled atmosphere, all of the following conditions must be met:

| Requirement | Threshold |
|---|---|
| Conversational persistence | The new topic must appear across at least N consecutive turns (N defined by implementation, minimum 3) |
| Topic stability score | The new topic's stability score must cross a minimum threshold |
| Confidence | Topic confidence must exceed a minimum threshold before any transition begins |
| Minimum dwell time | The new topic must have been the primary topic for a minimum dwell period |
| Transition cooldown | A minimum cooldown period must have elapsed since the last atmosphere transition |
| Emotional suitability | The current sensitivity_risk level must permit a transition (high/trauma states block transitions) |

### 4.2 Transition behaviour

Atmosphere transitions **must pass through a neutral state** (Level 0) when moving between non-adjacent atmosphere levels. A transition from warm domestic light to outdoor openness does not skip directly — it retreats to neutral first, dwells briefly, then advances.

This prevents jarring visual discontinuity and prevents the environment from appearing to chase the conversation.

### 4.3 Aside handling

A brief aside — a reference to another topic mid-sentence, a conversational digression, a name-drop — does not start the inertia clock. Asides are identified by the Voice/Conversation System's `topic_continuity_signal` and do not increment dwell time for any new topic.

---

## 5. Atmosphere Levels

The engine operates on a graduated model. Higher levels carry greater specificity and greater risk. The engine defaults downward when confidence is low.

### Level 0 — Neutral

Black or quiet neutral field. No representational cues. No colour temperature signal. No texture. No motion.

This is the **safe state** and the **default state** when:
- No settled topic has been established
- Sensitivity risk is `high` or `trauma`
- Topic stability or confidence is below threshold
- The participant has selected `atmosphere_profile = off` or `minimal`
- A safety constraint has been triggered

Level 0 is not a failure state. It is the correct state for uncertain, sensitive, or early-conversation conditions.

### Level 1 — Abstract

Colour, light, texture, and spatial atmosphere only. No representational cues. No imagery.

Examples: a warm amber field; a quiet blue-grey openness; soft low luminance with gentle texture.

Used when: a topic is settled with moderate confidence, emotional intensity is neutral or positive, and sensitivity risk is none or low.

### Level 2 — Suggestive

Non-specific environmental hints derived from the settled topic's emotional register. Still non-representational — no identifiable objects, places, or scenes.

Examples: stained-glass light patterns without a specific building; foliage and green luminance without a specific setting; water reflection without a specific body of water; architectural geometry without a specific structure.

Used when: topic is stable with high confidence, emotional intensity is positive or reflective, sensitivity risk is none or low, and participant preferences permit.

### Level 3 — Generic Representational

A non-specific class of environment, used **cautiously**. No identifying details. No personally meaningful specifics.

Examples: a generically warm domestic interior; an unspecified outdoor landscape.

Used when: topic is highly stable, confidence is high, emotional intensity is positive or reflective, sensitivity is none, governance_tier permits, and participant preferences support it.

This level must not be used when any ambiguity exists about whether the class of environment is appropriate for the participant's cultural, personal, or emotional context.

### Level 4 — Authenticated Personal Atmosphere

Participant-specific or historically verified imagery and atmosphere. This level may include photographs the participant has provided, verified archival images, or governed artifacts.

Used **only** under all of the following conditions:

1. `personalization_permitted = true` from the Governance Engine
2. A valid `consent_record_id` is present
3. The specific artifact has been authorized for display via the Governance Engine's artifact permission pathway
4. `atmosphere_level = 4` is within the participant's selected `atmosphere_profile`
5. The participant has not indicated any accessibility constraint that would make representational imagery harmful or disorienting

Level 4 is never reached by inference from conversation alone. It requires explicit governance authorization and consent.

---

## 6. Safety and Accessibility Constraints

These are **hard constraints**, not optional styling guidance. No atmosphere configuration may violate them. The engine enforces them before producing any output.

### 6.1 Absolute prohibitions (no exceptions)

- No flashing
- No strobing
- No rapid luminance changes
- No rapid colour inversion
- No high-frequency animation
- No abrupt full-screen transitions
- No excessive parallax
- No repeated transitions triggered by fleeting speech

### 6.2 OS and browser signals

- `prefers-reduced-motion` OS/browser signal: must be respected as a hard constraint; overrides all atmosphere settings except Level 0
- When `prefers-reduced-motion` is active: `motion_level = none`, `atmosphere_level` capped at 1
- Note: `prefers-reduced-motion` removes animation but does **not** authorize abrupt luminance changes. Even in reduced-motion mode, transitions between luminance states must remain within the safety-bounded fade range defined in §6.4.

### 6.3 Participant-selectable modes

| Mode | Behaviour |
|---|---|
| `atmosphere_profile = off` | Level 0 always. No colour, texture, or motion |
| `atmosphere_profile = minimal` | Level 0–1 only. Colour permitted; no texture, no motion, no imagery |
| `atmosphere_profile = still` | Level 0–2. No motion. Very slow transitions. No representational content |
| `atmosphere_profile = reflective` | Level 0–3. Slow transitions. Gentle breath-motion only. No personalized content |
| `atmosphere_profile = richer` | Level 0–4 (subject to governance and consent). All transitions available |

Default for users with unknown accessibility needs: **`still`**.

### 6.4 Retreat trigger

When **any** of the following conditions is true, the engine must initiate a safety retreat and set `neutral_fallback_active = true`:

- `sensitivity_risk = high` or `trauma`
- `topic_stability_score` below minimum threshold
- `topic_confidence` below minimum threshold
- Any safety constraint is active
- `atmosphere_profile = off`
- `prefers-reduced-motion` with current motion_level > none

**The decision to retreat is immediate. The visual transition is safety-bounded.**

This distinction matters because a hard cut to neutral — particularly from a bright or warm atmosphere state — may itself constitute a rapid luminance change, violating §6.1. The two requirements are reconciled as follows:

| Retreat action | Timing |
|---|---|
| Stop all motion | Immediate — no new frames rendered |
| Prevent new representational imagery | Immediate — no new material introduced |
| Remove semantic detail where possible | Immediate — content specificity reduced without visual event |
| Luminance and colour return toward neutral | Controlled fade: approximately 800–1,500 ms, subject to accessibility testing |
| Bright-to-black hard cut | **Prohibited** — falls under no-rapid-luminance-change rule regardless of retreat urgency |
| Reduced-motion mode | Removes animation, but must not cause abrupt luminance changes; fade duration may be compressed but not eliminated |

The retreat does not pass through intermediate atmosphere levels. Specificity is removed immediately and held at Level 0. The visual presentation reaches Level 0 appearance through the safety-bounded fade rather than an instantaneous jump.

Once retreat is active, no new AtmosphereProfile above Level 0 is computed until all retreat conditions have cleared and a full inertia cycle has elapsed.

---

## 7. Trauma-Sensitive Behaviour

When `sensitivity_risk = trauma`, the engine:

1. Immediately sets `neutral_fallback_active = true`
2. Targets Level 0 regardless of topic stability or confidence
3. Sets `motion_level = none` — all animation stops immediately
4. Initiates the safety-bounded luminance fade defined in §6.4 — a hard cut to black is prohibited even under trauma conditions
5. Removes semantic specificity immediately (no new representational imagery; existing imagery held at zero opacity or removed)
6. Does not attempt any atmosphere recovery until the sensitivity signal clears and a full inertia cycle has elapsed

**Explicit prohibition:** The engine must never generate, display, or suggest literal or evocative reconstruction of traumatic events.

For subjects including but not limited to: death, violence, accidents, abuse, medical crises, war, displacement, or grief — the default is **reduced sensory stimulation, stillness, and neutral support**.

The engine does not generate:
- Literal accident scenes or emergency imagery
- Weapons, blood, or physical injury depictions
- Hospital or clinical environments in response to medical trauma mentions
- Imagery that dramatically contextualizes suffering

The mention of a difficult topic is not an instruction to visualize it. The presence of a memory does not authorize its dramatization.

---

## 8. Governance and Consent

The engine distinguishes the following material types, because each carries different governance requirements:

| Material type | Description | Consent requirement |
|---|---|---|
| `inferred_atmosphere` | Abstract or suggestive output derived from conversational context | No explicit consent; covered by general terms |
| `generic_atmosphere` | Non-specific class of environment (Level 3) | No explicit consent; covered by general terms |
| `authenticated_atmosphere` | Historically or archivally verified imagery | Consent record required; Governance Engine authorization |
| `participant_provided` | Photographs or artifacts the participant supplied | Participant consent already given at upload; usage scope must be confirmed |
| `third_party_material` | Images or artifacts involving persons other than the participant | Explicit consent from all depicted parties required |
| `culturally_governed_material` | Material subject to cultural community authority | Joint authorization from subject and designated authority required (per AI_CONTEXT_BROKER.md §2, `culturally_governed_processing` profile) |
| `sensitive_or_restricted_material` | Material classified `restricted` or `steward` in the Content Layer | Not permitted for atmosphere use without explicit steward authorization |

### 8.1 Non-silencing rule

The engine must **never silently present inferred imagery as historical fact**. If an atmosphere element could reasonably be interpreted as a depiction of a specific event, person, or place, and it is not authenticated material, it must not be displayed at that level of specificity.

### 8.2 Consent record structure (deferred)

A `ConsentRecord` model covering atmosphere-level imagery consent is identified as a deferred schema object (see §11). The current architecture does not implement this table; it is documented here for future implementation.

---

## 9. Relationship to Existing Subsystems

The Memory Atmosphere Engine is a **dependent consumer** of several existing subsystems. It does not replace or extend their authority.

| Subsystem | Relationship |
|---|---|
| **AI Context Broker** | Primary data supplier. The broker resolves settled context, topic confidence, and emotional signals before passing them to the engine. The engine never queries the Content Layer directly. The Context Broker's authorization model governs what context may be supplied. |
| **Governance Engine** | Determines what may be used or shown. The engine receives `governance_tier`, `personalization_permitted`, `consent_record_id`, and `available_artifacts` from the Governance Engine (via the broker). The engine does not make governance decisions. |
| **Story Engine** | Identifies narrative context and memory stage (early exploration, deep reflection, biographical anchoring). The Story Engine's assessment informs the `settled_topic` and `emotional_intensity_signal`. |
| **Voice / Conversation System** | Provides `turn_state` and `topic_continuity_signal`. The engine holds atmosphere steady during active listening and processing turns. Atmosphere does not change mid-utterance. |
| **Accessibility Preferences** | Hard constraints on all output. `prefers-reduced-motion`, `atmosphere_profile`, `static_mode_required`, and `contrast_requirements` are enforced before any AtmosphereProfile is produced. |
| **Evidence and Provenance Systems** | Establish whether specific imagery is authenticated. The engine does not authenticate material; it receives `source_authenticity_level` as an input. If a source cannot be authenticated, the engine may not advance beyond Level 2. |

---

## 10. Architecture Notes

### 10.1 Where this subsystem sits

The Memory Atmosphere Engine sits between the AI Context Broker (which resolves and sanctions context) and the Presentation Layer (which renders the environment). It is a **translation layer**, not a data layer. It does not persist records beyond its current AtmosphereProfile output and a minimal audit trail.

### 10.2 What it does not do

The engine does not:
- Write to the Content Layer
- Query the Claim, Narrative, or Source tables directly
- Make governance decisions
- Retrieve, score, or rank artifacts
- Authenticate imagery
- Store participant history beyond what the Context Broker supplies

### 10.3 Audit trail

Every AtmosphereProfile output is logged with:
- Input snapshot (settled_topic, stability_score, confidence, sensitivity_risk)
- Computed atmosphere_level
- `neutral_fallback_active` and `retreat_reason` if applicable
- `personalization_level` and `consent_required_before_display`
- Timestamp and session_id

This log is for audit and safety review. It is not a real-time diagnostic. Participants do not see it.

### 10.4 Stateless per turn

The engine is effectively stateless per turn. It does not carry state from one turn to the next autonomously — the inertia model (§4) is maintained by the Voice/Conversation System, which passes `elapsed_dwell_ms` and `topic_continuity_signal`. This means the engine can be replaced, reset, or bypassed without corrupting any persistent data.

---

## 11. Deferred Schema Objects

The following schema objects are identified as **future implementation requirements**. They are documented here for preservation. No SQL, no tables, no migrations are produced in this session.

| Deferred object | Purpose | Depends on |
|---|---|---|
| `AtmosphereProfile` (output record) | Persisted log of each computed profile for audit | Session model, Voice/Conversation System |
| `AtmosphereConsentRecord` | Records participant consent for specific atmosphere levels and material types | Governance Engine, participant_id, artifact_id |
| `AtmospherePolicyVersion` | Versioned policy defining thresholds, level caps, and inertia parameters per jurisdiction or deployment context | Jurisdiction table, JurisdictionPolicyVersion (OPERATIONAL_MODELS.md) |
| `AtmosphereAuditLog` | Immutable log of all profile transitions, retreat events, and consent checks | Session model, AccessPolicyChanged event |
| `ArtifactAtmospherePermission` | Governs whether a specific artifact may appear at a specific atmosphere level in a specific session context | Artifact (CONTENT_LAYER.md), ConsentRecord |

These objects require schema design review before migration. They are not migration blockers for 0002.

---

## 12. Open Questions

The following questions are unresolved and require Discovery Partner review before implementation:

1. **Inertia thresholds:** What are the specific numeric values for minimum dwell time, topic stability threshold, and turn count before a topic change is recognized? These are implementation parameters but have ethical implications — too low risks keyword-chasing; too high risks atmosphere lagging meaningfully behind the conversation.

2. **Sensitivity signal source:** Who computes `sensitivity_risk`? The AI Context Broker must receive this from somewhere — either the Story Engine, a dedicated sensitivity classifier, or the Companion agent. The data flow must be specified before implementation.

3. **Level 3 justification gate:** At what point is Level 3 (Generic Representational) appropriate? A specific session type or depth marker may be needed. Level 3 used too readily approaches the keyword-chasing problem from a different direction.

4. **Cultural atmosphere norms:** Certain cultural communities have distinct visual languages, colour associations, and imagery restrictions. A blanket abstract atmosphere may still carry unintended cultural meaning. Whether the engine needs per-cultural-community atmosphere policies is unresolved.

5. **Trauma signal authority:** Who determines that `sensitivity_risk = trauma`? This signal must come from a source that understands the difference between mentioning a difficult topic and actively reliving it. Over-triggering the trauma state would suppress atmosphere in most reflective conversations; under-triggering it would be harmful.

6. **Audio atmosphere:** The output model includes `audio_permitted` but audio is flagged as always-false in the initial implementation. The governance and accessibility requirements for ambient audio are distinct from those for visual atmosphere and must be designed separately.

7. **Third-party consent at Level 4:** If an authenticated photograph shows persons other than the participant, what consent model applies? This intersects with `third_party_material` classification and requires explicit policy before Level 4 is enabled.

8. **Retreat transition timing:** ~~Is an instant jump to Level 0 visually safe?~~ **Resolved in §6.4.** The retreat transition model is now specified: the decision is immediate, the visual transition is safety-bounded (approximately 800–1,500 ms fade; no hard luminance cut). The remaining open question is the precise timing range, which requires accessibility testing against WCAG photosensitivity guidance before the first implementation. The 800–1,500 ms range is an initial estimate, not a finalized constraint.

---

*This document is architectural preservation only. No implementation, UI effects, image generation, database tables, or production logic should be produced until these questions are addressed in a Discovery Partner review session.*
