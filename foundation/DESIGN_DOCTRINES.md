# LifeBook Design Doctrines
**Version:** 0.1  
**Status:** Active — foundational operating philosophy  
**Produced:** 2026-07-25  
**Produced by:** Discovery Partner + Claude (architecture session)

---

These doctrines are not implementation requirements, schema definitions, or feature specifications. They are the enduring design philosophies that govern LifeBook across all subsystems and all phases of the platform's life.

They emerge repeatedly during Discovery Partner sessions. This document collects them so they become part of the operating philosophy of the platform rather than remaining scattered across ADRs, subsystem documents, and session notes.

Doctrines are intentionally independent of implementation. They do not change when technology changes, when features are added, or when specific designs are revised. They are expected to evolve slowly — if at all — over the lifetime of the platform. A proposal to revise a doctrine requires the same deliberateness as a proposal to revise an architectural constant.

When a subsystem design, a product decision, or an implementation choice conflicts with a doctrine, the doctrine is the signal that something needs to be reconsidered.

---

## 1. LifeBook is an Operating System for Human Memory

LifeBook is not an application that stores memories. It is an operating system that governs the capture, authentication, preservation, connection, and presentation of human experience.

Every subsystem should strengthen that operating philosophy.

---

## 2. Authenticity Before Intelligence

AI may assist. It must never replace authentic human memory.

Whenever there is tension between inference and evidence, evidence prevails.

---

## 3. Atmosphere is Earned

Atmospheric richness increases only as authenticated understanding increases. The system becomes richer because the participant's history becomes richer — not because additional software features are enabled.

---

## 4. Atmosphere Supports Memory

Atmosphere exists to support recollection. It is never permitted to perform recollection.

---

## 5. Context Over Keywords

LifeBook responds to settled conversational context. Never to isolated words.

---

## 6. Stability Over Reactivity

Interfaces should possess inertia. They should evolve with the conversation rather than react to every conversational fluctuation.

---

## 7. Governance Before Personalisation

Personalisation is always downstream of governance. Nothing becomes more personal until permission, provenance, and confidence allow it.

---

## 8. The Quietest Interface Wins

The best interface is usually the one the participant stops noticing. Technology should disappear behind the experience.

---

## 9. Every Layer Must Be Earned

Trust. Knowledge. Relationships. Atmosphere. Personalisation.

Each becomes richer only through authentic interaction.

---

## 10. Subordinate Beauty to Cognition

If visual beauty ever conflicts with helping someone think clearly, cognition wins. Always.

---

## Cross-references

These doctrines are expressed through the following architectural documents, among others:

| Document | Doctrines expressed |
|---|---|
| `ARCHITECTURE_FREEZE_V1.md` | 1, 2, 7 |
| `MEMORY_ATMOSPHERE_ENGINE.md` | 3, 4, 5, 6, 8, 10 |
| `ADR-0002.md` | 3, 4, 5, 6 |
| `AI_CONTEXT_BROKER.md` | 2, 7 |
| `CONTENT_LAYER.md` | 2, 7, 9 |
| `GOVERNANCE_MODELS.md` | 7, 9 |
