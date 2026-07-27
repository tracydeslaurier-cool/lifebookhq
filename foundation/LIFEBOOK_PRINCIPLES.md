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

## Principle V — Families Contribute, Stewards Decide

A LifeBook has one steward per lifebook (or a designated set). The steward is the decision-maker. Contributors — family members, invited participants — add material, but the steward governs what is published, what is restricted, and what is shared.

This means:
- Contributions from non-stewards land in `pending_review`, not in the published record
- Invitation flows are steward-initiated
- Access classifications are steward-controlled
- Dispute mechanisms exist for contested facts, but resolution is governed — not majority-voted

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

## On These Principles

These principles were not invented. They emerged from the design process: from the governance architecture, from the migration philosophy, from the tone guide, and from conversations about what LifeBook actually is.

They should be reviewed — and potentially extended — when:
- A new capability is proposed that appears to conflict with one of them
- A technical constraint makes one of them difficult to enforce
- A new cultural or legal jurisdiction is added that changes the governance context

They should never be weakened under time pressure, technical convenience, or feature demand.

---

*LIFEBOOK_PRINCIPLES.md — LifeBook HQ — 2026-07-27*
