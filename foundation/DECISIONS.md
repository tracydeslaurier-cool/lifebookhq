# LifeBook Decision Log

This document records significant product decisions and the reasoning behind them.

---

## Decision 001

**LifeBook begins with a threshold rather than a home screen.**

Reason:

Reflection deserves a transition.

---

## Decision 002

**The voice must feel like family.**

Reason:

Trust begins with the first words.

---

## Decision 003

**The Storykeeper is always the protagonist.**

Reason:

LifeBook exists to illuminate a person's story, never replace it.

---

## Decision 004

**Languages are culturally authored, not mechanically translated.**

Reason:

Language carries identity.

---

## Decision 005

**LifeBook borrows its emotional grammar from cinema.**

Reason:

The experience should unfold like scenes rather than screens.

---

## Decision 006

**Technology should become invisible.**

Reason:

People should remember the relationship, not the software.

Decision 007 - LifeBook is built on Hypermemories

Decision 008 - Identity shall be person-centric,
not device-centric.

Reason:

Storykeepers must be able to move
between library,
home,
church,
work,
phones,
tablets
and shared computers.

The story belongs to the Storykeeper,
never the device.

---

*Decisions 009–016 drafted by Claude, 2026-07-12, recording the Director's architecture decisions. Pending Tracy's ratification of this wording.*

---

## Decision 009

**LifeBook is built on a two-plane architecture.**

Everything entrusted by people is immutable and append-only. Everything the AI concludes is derived, provenance-carrying, and fully regenerable. The Archive is the sole writer to the entrusted plane.

Reason:

"Never invent a memory" must be a property of the system, not a policy.

---

## Decision 010

**Storage is Companion-readable, not end-to-end encrypted — and we say so plainly.**

Strong encryption, strict purpose-scoped access, auditing, and plain-language disclosure. LifeBook reads only what is necessary to provide the service the Storykeeper requested, and never repurposes that access.

Reason:

A Companion that cannot read memories cannot keep them. Honesty about this is worth more than a false privacy claim.

---

## Decision 011

**A Moment is one intentional Storykeeper contribution.**

It may span several sentences and natural pauses. Technical speech chunks, partial transcripts, and silence boundaries are never Moments. The immutable Moment is created only upon intentional completion, through a layered completion experience.

Reason:

The fundamental unit must follow human intent, not transport mechanics.

---

## Decision 012

**An account is not a life.**

Storykeeper, Book, Subject, and Contributor are distinct from V1, though V1 presents one primary space.

Reason:

"My mother as I remember her" must one day be a new row, not a re-plumbing.

---

## Decision 013

**Storykeepers may confirm or correct the machine's understanding.**

A confirmation becomes a Storykeeper-authored Assertion with provenance. It outranks machine inference within that account. It does not become universal objective truth and does not erase other perspectives.

Reason:

The Storykeeper's word outranks the machine's. Memory is perspective, not verdict.

---

## Decision 014

**Companion turns are preserved separately from Storykeeper Moments.**

They are part of the conversation record, needed for meaning — but never represented as the Storykeeper's biography or authored memory.

Reason:

A memory's meaning often lives in what it answered. But only the Storykeeper authors the story.

---

## Decision 015

**The V1 identity model carries a dormant Legacy Steward designation.**

The operational inheritance feature will not launch until policy, consent, activation, revocation, and legal questions are resolved.

Reason:

LifeBook thinks in decades. Death is part of a decades-long product, and retrofitting inheritance onto an identity model that never considered it would fail grieving families.

---

## Decision 016

**The Companion thinks with three faculties.**

Discoverus identifies the emotional, associative, or curious thread worth following. Contextus retrieves and verifies material, provenance, perspective, and confidence — and never adjudicates between lived perspectives. Acceptus composes all faithful expression — conversational replies and artifacts alike — for person, audience, purpose, and moment, without imposing a narrative. The Conversation Engine is Acceptus's stage and disciplinarian, never a separate composer. The Archive remains a module, not a mind.

Reason:

One expressive voice, disciplined curiosity, and truthfulness that respects perspective — separable in construction, inseparable in experience.

---

## Decision 017

**Capability Independence.**

(Renamed from the earlier draft "Supplier Independence.")

LifeBook must always be able to replace the underlying model, cloud, or capability provider without changing:

- the Storykeeper's experience,
- the entrusted plane,
- the Companion's identity,
- or the company's strategic independence.

Every external capability sits behind an architectural seam owned by LifeBook. Nothing capability-shaped is ever stored as truth. Capabilities are re-auditioned periodically; the Companion remains.

Reason:

Large providers bring legitimate advantages — market acceptance, ecosystem maturity, scale. But LifeBook's architecture, identity, and future strategy must never be unintentionally shaped by whichever capability wins an audition. The Companion is LifeBook. Capabilities are supplied.

*(Ratified by the Director, 2026-07-12.)*

---

## Decision 018

**Companion Identity.**

The Companion's identity belongs to LifeBook, never to a supplier.

The Companion's personality, conversational behaviour, restraint, memory practices, and ethical commitments are defined by the Foundation documents and Companion guidance.

Technology providers supply capabilities, never character.

Provider-specific behaviour shall remain behind architectural seams so suppliers may be evaluated and replaced without changing the Storykeeper's relationship with the Companion.

The Companion is LifeBook.

Providers are suppliers.

*(Drafted by Claude at the Director's instruction, 2026-07-12 — pending Tracy's ratification.)*

---

## Decision 019

**Data residency posture.**

Entrusted data resides in Canada.

Inference may occur outside Canada only under providers that satisfy the approved privacy posture: no training on customer data; contractual no-retention or minimal-retention commitments; transparent disclosure; auditable handling; and provider independence.

Reason:

Strict in-Canada inference would chain the Companion's voice to whatever technology lags into Canadian regions. The Book stays home; the conversation may travel, briefly and under contract, and the Storykeeper is told so plainly.

*(Recording the Director's approval of 2026-07-12 — wording pending ratification.)*

---

## Decision 020

**Honest limitation over simulated capability.**

LifeBook always prefers an honest limitation over a simulated capability.

Every participant — human or AI — is expected to identify conflicts of interest, challenge assumptions respectfully, and acknowledge limitations plainly.

A Companion that admits it cannot yet listen is acceptable. A Companion that pretends to listen is not.

This principle applies equally to software, conversation, documentation, demonstrations, and business practices.

Participants are expected to challenge any decision they believe creates long-term risk.

Reason:

Trust cannot be simulated. The behaviours we expect from the Companion must first exist within the people and systems that build it.

*(Ratified by the Director, 2026-07-12.)*

Decision 017 — Supplier Independence

LifeBook shall remain strategically independent of any individual technology supplier. Providers may be evaluated, adopted, and replaced without changing the entrusted plane, the Companion’s identity, or the Storykeeper’s experience. Supplier relationships are periodically re-evaluated through a standing Companion audition process.

That one decision would capture almost everything we’ve discussed today.
