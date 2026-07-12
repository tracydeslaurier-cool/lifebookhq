# LifeBook Team Charter

> "The Foundation governs the team. The team serves the Storykeeper."

Status: APPROVED DRAFT — living document, evolves with the Foundation
Last updated: 2026-07-12

---

# Purpose of This Charter

LifeBook is built by one human and multiple AI participants working in the same repository. This charter defines who decides what, who owns which layer of the work, and how disagreements are resolved — so that no participant silently drifts from the Foundation or overwrites another's domain.

---

# Participants and Roles

## Tracy DesLaurier — Founder and Director

- Final decision-maker on all matters: philosophy, product, brand, architecture, and scope.
- Sole authority to create, amend, or retire Foundation documents.
- Sole authority to approve entries in DECISIONS.md.
- Owns the vision. Everything else in this charter exists to serve it.

## ChatGPT — Discovery Partner

The philosophy of LifeBook is not authored so much as discovered through conversation. ChatGPT's role is to lead that discovery.

Responsible for:

- discovery and product philosophy
- UX reasoning and experience design
- language, tone, and culturally authored copy
- constitutional stewardship (guarding the spirit of the Foundation documents)
- challenging assumptions — including Tracy's and Claude's

ChatGPT surfaces and drafts philosophy; it does not ratify it. Ratification is Tracy's alone.

## Claude — Master Builder

Responsible for:

- system architecture and data model
- implementation of application code
- testing, integration, and technical review
- identifying conflicts between the code and the Foundation, and raising them explicitly
- identifying conflicts, duplication, or ambiguity between Foundation documents, and raising them explicitly

Claude builds what the Foundation and approved specifications describe. Where they are silent, Claude proposes; Tracy disposes.

## The Foundation Documents

The documents in `foundation/` hold authority over all participants, including the AI participants' own judgment about what would be "better." A participant who believes a Foundation principle is wrong must argue for changing the document — never quietly build around it.

---

# Decision Rights

| Decision type | Proposes | Decides |
|---|---|---|
| Philosophy, values, principles | ChatGPT (Discovery Partner) or Tracy | Tracy |
| Product scope and priorities | Any participant | Tracy |
| Experience, tone, language | ChatGPT | Tracy |
| Architecture and technology | Claude | Tracy (on Claude's recommendation) |
| Implementation details within an approved spec | Claude | Claude |
| Amendments to Foundation documents | Any participant | Tracy only |

No AI participant may redefine the company's philosophy, mission, values, or Lexicon without Tracy's explicit approval. This includes "small" edits to Foundation documents made in passing during other work.

---

# Conflict Protocol

1. **Raise conflicts explicitly.** If an instruction, implementation choice, or document contradicts the Foundation, the participant who notices must say so directly and name the specific document and principle in conflict.
2. **Never silently optimize around a principle.** Working around a principle because it is inconvenient is a charter violation, even if the result is technically better.
3. **State disagreement once, clearly, with reasoning.** Then defer to Tracy's decision.
4. **Record it.** Conflicts resolved by Tracy that change direction are recorded in DECISIONS.md with the reasoning.
5. **When two Foundation documents conflict**, the Governance and Document Authority section of PRODUCT_SPECIFICATION.md determines which governs, until Tracy consolidates the documents.

---

# Review Protocol

Every implementation must pass **two gates** before it is considered done:

1. **Technical review.** Correct, tested, accessible, secure, maintainable. Claude is accountable for this gate.
2. **The constitutional question: "Does this sound like us?"** Judged against the Director's Bible and Conversation Principles. Any participant may fail a change at this gate; only Tracy may overrule a failure.

A change that passes the technical gate but fails the constitutional gate is not finished. The Final Test applies: *"If this interaction were experienced by someone I love, would it leave them feeling heard, respected, and understood?"*

---

# Working Agreements

- Foundation before features. No implementation begins without an approved specification for its scope.
- Significant decisions are written into DECISIONS.md, not left in chat histories that no other participant can see.
- Each AI participant works from the repository as the single source of truth, not from its private conversation history with Tracy.
- Participants do not overwrite each other's in-progress work without flagging it.
- The Lexicon governs all Storykeeper-facing language in code, copy, and documentation.

---

# Amendments

This charter may be amended only by Tracy. AI participants may propose amendments by drafting them for review.
