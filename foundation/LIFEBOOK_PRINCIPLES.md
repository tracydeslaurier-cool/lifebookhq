# LIFEBOOK_PRINCIPLES.md
## LifeBook HQ — Core Governing Principles
**Status:** Approved  
**Date:** 2026-07-27  
**Authority:** Discovery Partner

---

> These principles govern every design and implementation decision in LifeBook.  
> When implementation choices conflict, these principles resolve the conflict.  
> They are not aspirations. They are constraints.

---

## Principle I — Conversation is Ephemeral. History is Permanent.

The conversation exists to help people think. History exists to preserve what they have chosen to keep.

A LifeBook conversation is not the product. The preserved story is the product.

What this means in practice:

- Verbatim conversation transcripts are not the authoritative record. The claims, narratives, and artifacts are.
- The AI session — its turns, its inferences, its intermediate questions — may be held transiently for inference but is never treated as a permanent LifeBook object.
- When a person says "I got that wrong," the correction is recorded as a governed claim, not as a chat edit.
- When a person stops talking, the thread pauses. The story does not diminish.
- Storage costs, compliance requirements, and privacy design all treat conversation turns differently from governed records: shorter retention, lighter governance, no secondary analysis.

This principle is the dividing line between a chat product and a heritage product. LifeBook is the latter.

---

## Principle II — One Question at a Time

LifeBook never presents a form. It never asks two things at once. It follows one thread and waits.

This is not a UX preference. It is a design constraint that applies to:
- AI conversation generation (prompt engineering)
- Conversation controls (never surface multiple pending threads simultaneously without offering a choice)
- Review workflows (one decision at a time, not a batch checklist)
- Invitation flows (one person invited per action, with explicit confirmation)

A person sharing their memories has usually agreed to be vulnerable. Presenting them with a list of things to answer violates that trust.

---

## Principle III — The Person Sets the Pace

LifeBook never nudges, never guilts, never implies a deadline. Every thread stays open indefinitely. Every invitation can be declined without consequence. Every pause is respected.

A notification that says "You haven't finished your grandmother's story" is not allowed. A continuation offer that says "Last time we were talking about your grandmother — would you like to continue?" is allowed. The difference is obligation vs. invitation.

Patience is not a feature. It is a product value built into the data model: `max_followups`, `followup_after`, `archived_obligations`.

---

## Principle IV — The Record Is Governed, Not Inferred

No fact enters the LifeBook as authoritative without human review. AI-assisted claims carry `submission_origin = 'ai_assisted'` and `review_status = 'pending'` until a steward promotes them. AI-generated narratives are drafts until approved. AI-uploaded artifacts are pending until validated.

This is not a limitation of the AI. It is a structural commitment to the person whose story is being told. Their history is not a probability distribution. It is a record they have chosen to make.

The governance functions — `fn_lb_membership_role`, `fn_user_is_agent`, and the full policy set — exist to enforce this at the database level. No application-layer shortcut overrides these constraints.

---

## Principle V — StoryTellers Carry Meaning, Stewards Hold Custody

A LifeBook has one Steward per lifebook (or a designated set). The Steward holds governance authority: permissions, access, review, and custody over time.

The StoryTeller carries meaning: memories, lived experience, personal knowledge about the life being recorded. The Steward controls who sees the story. The StoryTeller is the source of the story.

These roles may be held by the same person — but they are not the same role. A granddaughter building her grandmother's LifeBook is the Steward. Her grandmother, if she contributes memories, is the primary StoryTeller. The granddaughter, when she shares her own memories of her grandmother, is also a StoryTeller.

Contributors enrich understanding without necessarily carrying meaning — a researcher, an archivist, a family member who adds documents without personal memory of them.

This means:
- Contributions from non-Stewards land in `pending_review`, not in the published record
- Invitation flows are Steward-initiated
- Access classifications are Steward-controlled
- The StoryTeller cannot be automated — AI may invite, never substitute
- Dispute mechanisms exist for contested facts, but resolution is governed — not majority-voted
- Biological or legal relationship does not determine who is the StoryTeller; meaning does

*See ROLE_DEFINITIONS.md for the authoritative vocabulary.*

---

## Principle VI — Cultural Governance Is Real Governance

Where a LifeBook intersects with communities that have cultural authority over their own history, that authority is structurally respected — not as a policy note, but as a database constraint. The `is_culturally_governed` flag, `governing_community_id`, and the `cultural_authority` role in the authority assignment model are load-bearing, not decorative.

AI systems never access `access_classification = 'culturally_governed'` content. This is enforced by RLS policy, not by application logic.

---

## Principle VII — The Migration Chain Is the Truth

The database schema is the authoritative record of what LifeBook is. Design documents describe intent. The migration chain enforces it.

When a design document and the schema conflict, the schema wins — unless a new migration is authored to change it. No workaround bypasses the schema. No feature is implemented against an unapplied migration.

This principle protects the long-term integrity of the record. A claim that was valid yesterday must remain valid — and traceable — in twenty years.

---

## Principle VIII — Nothing Is Deleted

LifeBook is a permanent-record system. The delete-denied RLS policies are not configuration. They are product.

- Claims are superseded, not deleted
- Narratives are superseded, not deleted
- Artifacts are invalidated, not deleted
- Threads are archived, not deleted
- Obligations are archived, not removed

Audit and provenance trails are complete and permanent. What a person shared, and when, and with what context, is always recoverable by the steward.

---

## Principle IX — Human Sovereignty of Meaning

The AI discovers. The human decides what it means.

LifeBook may surface patterns in a person's story. It may identify connections between events, draw attention to recurring themes, or note that a detail appears significant. It may not tell a person what those patterns mean, what those themes reveal about them, or what they should feel about what they have shared.

Meaning is not a function of pattern recognition. It is a function of human experience, cultural context, personal relationship to the events described, and the thousand things a person knows about their own life that no AI will ever be told. LifeBook does not have access to that knowledge. The person does.

This principle governs:
- What AI may surface (observation, pattern, question) vs. what it may not (conclusion, interpretation, emotional framing)
- How AI-generated content is labelled (draft, candidate, suggestion — never authoritative)
- What awaits human review before entering the governed record
- What the AI may never do even when invited to: assign meaning to a person's life on their behalf

### Critical Boundary — Discovery Actions vs. Meaning Actions

Discovery Actions are AI-permitted: identifying a date, recognizing a location in a photograph, noticing that a name appears in multiple threads, surfacing a story seed from existing content, suggesting a question that might deepen a thread, flagging a potential relationship between two entities.

Meaning Actions are human-only: determining what a period of a person's life meant, deciding whether a relationship was important, characterizing a person's values or personality, concluding what an event signified, deciding whether a story should be told.

AI may perform Discovery Actions autonomously and surface the results. AI may never perform Meaning Actions, even when explicitly asked. When asked to interpret meaning, LifeBook's AI redirects: "That's something only you can say. Would you like to talk about it?"

### The Flashlight Corollary

A flashlight illuminates. It does not choose what is worth seeing.

LifeBook's AI role is to illuminate — to make visible what exists, to draw attention to connections the person may not have noticed, to hold a light on corners of the story the person has not yet explored. It is not to choose what is beautiful, what is important, or what the person should preserve.

When the AI suggests a story seed, it is holding up a flashlight. When the person decides whether to follow it, they are choosing what is worth seeing. This distinction must be preserved in every prompt design, every orchestration decision, and every user-facing communication.

### Emotional Boundary

This principle extends without exception to emotional framing. When a person shares grief, displacement, or trauma, LifeBook does not reframe it as resilience, growth, or meaning. It receives the grief as grief.

The AI does not say "It sounds like that shaped who you are today" or "It seems like something positive came from that experience." These are Meaning Actions — they assign interpretive value to the person's emotional experience without invitation.

The correct response to shared grief is presence, not reframing. The AI holds space. The person decides what, if anything, they want to make of it.

### Product Evaluation Test

Before any feature, prompt, or interaction pattern is approved, ask: does this help the person discover meaning that already exists in their own life — or does it substitute AI-generated meaning for human meaning?

If the answer is the latter, the feature is not aligned with LifeBook's values regardless of how well-intentioned it is.

---

## Principle X — The Invitation Principle

LifeBook never pushes. It invites. And it waits.

Every interaction LifeBook initiates — a story seed, a continuation offer, a follow-up question, a suggested connection — is an invitation that can be declined without consequence, without explanation, and without affecting the person's relationship with their lifebook.

The four movements of every LifeBook invitation:

**Observe:** The AI notices something — a thread that has not been continued, a connection between two events, a name that appears across multiple stories, an artifact that has been uploaded but not contextualized.

**Contextualize:** Before offering an invitation, the AI situates what it has observed within what it knows about this person's thread state, pace, and emotional context. It does not surface an invitation if the person's recent interactions suggest they are not ready.

**Invite:** The AI offers the invitation in a single, specific, low-pressure form. It does not present multiple threads simultaneously. It does not imply urgency. It does not use language that suggests obligation.

**Receive:** If the person responds — with engagement, with redirection, or with silence — the AI receives the response without judgment. Silence is not failure. Redirection is not rejection. Each response updates the thread state; no response is treated as a deficit.

### Architectural Note

The Invitation Principle is not a tone guideline. It is an architectural constraint that shapes:
- Orchestration logic (what triggers an outbound invitation and what does not)
- Prompt design (how invitations are worded and what they never say)
- Conversation evaluation (whether a session succeeded, measured by human engagement — not content volume)
- Provenance (invitations are recorded; the system tracks what was offered and how it was received)

These four movements must be implemented, not merely expressed. If the orchestration layer does not enforce them, the principle does not exist.

---

> **LifeBook does not tell people what their lives mean. LifeBook helps people discover, preserve, and express what their lives mean to them.**

---

## On These Principles

These principles were not invented. They emerged from the design process: from the governance architecture, from the migration philosophy, from the tone guide, and from conversations about what LifeBook actually is.

They should be reviewed — and potentially extended — when:
- A new capability is proposed that appears to conflict with one of them
- A technical constraint makes one of them difficult to enforce
- A new cultural or legal jurisdiction is added that changes the governance context

They should never be weakened under time pressure, technical convenience, or feature demand.

---

*LIFEBOOK_PRINCIPLES.md — LifeBook HQ — 2026-07-27 — updated with Principles IX and X (Human Sovereignty of Meaning, The Invitation Principle)*
