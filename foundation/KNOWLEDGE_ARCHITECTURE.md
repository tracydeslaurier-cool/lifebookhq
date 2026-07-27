# KNOWLEDGE_ARCHITECTURE.md
## LifeBook HQ — The Knowledge Architecture
**Status:** Foundational architectural paper  
**Date:** 2026-07-27  
**Classification:** Conceptual foundation — no schema, no migrations, no roadmap changes

---

> *In an age when almost anything can be generated convincingly, the enduring question is no longer "Can this be created?" but "Where did this come from, and why should we trust it?"*

---

## Preface

LifeBook is sometimes described as a platform for preserving personal history. That description is accurate but incomplete. It obscures something more important about what LifeBook is attempting to do.

A photograph can be preserved. A document can be archived. A story can be recorded. But none of these things, by itself, constitutes preserved knowledge. A photograph on a hard drive without context is data. The same photograph with a known date, a named subject, a documented source, and a clear chain of custody is evidence. That evidence, reviewed by the people who knew that subject and anchored by their testimony, becomes governed knowledge.

The difference between data and governed knowledge is not a matter of degree. It is a matter of architecture.

This paper explores the architectural model underlying LifeBook — a model that distinguishes four distinct layers: reality, evidence, governance, and representation. Understanding these layers, and understanding where each belongs, explains why the existing architecture is structured as it is and why that structure will support capabilities we have not yet designed.

---

## Part I — The Four Layers

### Layer 1: Reality

Reality is the domain of things that actually happened. Births. Deaths. Marriages. Migrations. Wars. Conversations. Illnesses. Moments of joy or grief that will never be recovered in full.

Reality exists independently of LifeBook. It existed before LifeBook. It will be shaped by forces LifeBook never touches. LifeBook does not create reality, does not alter reality, and does not adjudicate what reality was. This is not a limitation of the platform — it is a foundational commitment.

The temptation to treat a record system as reality itself is one of the oldest problems in information architecture. A birth record does not make a person born. A marriage certificate does not make two people married. A database entry cannot retroactively make a migration happen. These are representations of reality — records that evidence reality — but they are not reality itself.

LifeBook is designed to be clear about this. The schema contains no field that asserts "this is what happened." It contains fields that assert "this is what was claimed, by whom, on what basis, and to what degree of confidence." This is not epistemic timidity. It is precision.

### Layer 2: Evidence

Evidence is the layer between reality and any record system. Evidence is what reality leaves behind: the traces, artifacts, memories, and documents that allow us to reconstruct and understand what happened.

Evidence takes many forms. A birth certificate is evidence. A photograph is evidence. A spoken memory is evidence. A ship manifest is evidence. A letter is evidence. A court record is evidence. A family story passed down over three generations is evidence.

What evidence is not, is perfect.

- Evidence can be incomplete. The ship manifest may list the surname but not the maiden name.
- Evidence can disagree. The census says 1883. The church register says 1885. The grandmother always said she was younger than she actually was.
- Evidence can be mistaken. The witness was sincere. The witness was wrong.
- Evidence can degrade. The photograph fades. The recording deteriorates. The journal is partially burned.
- Evidence can be deliberately altered. Dates were changed. Names were anglicized. Identities were obscured for survival.

A system that requires evidence to be perfect before it can be preserved is not a heritage system. It is an exclusion mechanism. Most of what we know about most people's lives is imperfect evidence — and imperfect evidence, carefully preserved with its imperfections intact, is vastly more valuable than silence.

LifeBook's commitment at this layer is to preserve evidence as evidence, not to transform it into something cleaner, simpler, or more definitive than it actually is.

### Layer 3: Governance

If evidence alone were sufficient, a well-organized archive would be a knowledge system. It is not. Evidence without governance is a pile of documents. Governance is what converts evidence into trusted knowledge.

This is the layer that is uniquely LifeBook's.

Governance in LifeBook's model is not bureaucracy. It is the set of processes and structures that allow evidence to be:

**Reviewed**: A steward reads a claim, examines its basis, and decides whether it meets the standard for the authoritative record. A contributor submits a memory; the steward confirms whether it should be included. An AI transcription is checked against the original.

**Attributed**: Every piece of evidence in the record knows where it came from. Who stated it. When. What they based it on. Which document it was extracted from. This is provenance — the chain of custody that makes trust possible.

**Contextualized by confidence**: Not everything in a lifebook is equally certain. Some claims are documented. Some are remembered. Some are inferred. Some are disputed. The architecture captures these distinctions so they are visible to anyone working with the record.

**Amended through correction, not deletion**: History does not disappear when it is discovered to be wrong. The incorrect claim is superseded — the new claim references it, the correction is recorded, and the full history is preserved. A record that was believed true and later found false is itself evidence of how the story was understood and how understanding changed.

**Arbitrated in dispute**: When evidence conflicts — when two people remember differently, when a document contradicts a memory — the governance layer provides a mechanism for recording the disagreement, not resolving it by fiat. A dispute is not a defect in the system. It is an accurate representation of the evidence.

**Stewarded by humans**: The governance layer is not automated. An AI system may assist governance — flagging inconsistencies, suggesting connections, proposing corrections. But governance decisions — what enters the authoritative record, what is disputed, what is restricted — belong to the steward. This is a structural commitment, not a policy preference.

Governance is the process by which preserved evidence becomes trusted knowledge. Without it, you have better or worse storage. With it, you have something a family can rely on for generations.

### Layer 4: Representation

Representation is everything created to help humans understand governed knowledge. It is the interface between the governed record and human minds.

Representations include narratives — the stories that make governed claims legible as a life. They include timelines, relationship graphs, and indexes. They include translations of documents from one language to another. They include summaries of conversation threads. They include the AI-generated response that helps a steward understand what they have in their lifebook. They include the interview prompts that suggest what questions haven't been asked yet.

Representations are extraordinarily valuable. They are, in a real sense, the product. The governed record exists so that representations can be trustworthy.

But representations are not reality. They are not even evidence. They are interpretations of governed knowledge, and they must never be mistaken for something more primary.

This distinction becomes increasingly important as the representations become more convincing. A timeline is easy to distinguish from history. A well-written narrative in a person's voice may be much harder. A generated voice that sounds like a grandmother, or a portrait that looks like a great-grandfather who died before photographs existed — these are representations so vivid they can displace memory entirely.

The architecture must hold the line. No matter how convincing a representation becomes, it is always clearly derived from, and subordinate to, the governed record from which it was generated.

---

## Part II — Where AI Belongs

AI is a powerful instrument for representation. It is a useful assistant to governance. It has no legitimate place in the reality or evidence layers.

### What AI may legitimately do

**In the Representation layer:** AI may organize and present governed knowledge. It may generate narrative from approved claims. It may suggest timelines, identify gaps in the story, propose follow-up questions. It may translate, transcribe, summarize, and make the record navigable. It may create synthetic representations — portraits, voice, visualisations — that help make a historical figure present and human. These are legitimate uses, subject to the disclosure and labelling requirements this architecture demands.

**As governance assistance:** AI may help humans govern more effectively. It may flag likely duplicate entities. It may notice that a claimed birth year is inconsistent with other records. It may suggest that a document and a conversation thread are describing the same event. It may identify missing information and prompt the steward to address it. In each case, the AI is providing input to human governance — not replacing it.

### What AI must never do autonomously

**Originate lived experience.** AI cannot generate a memory. It can generate a plausible-sounding narrative about a person's past, but that narrative is a fabrication unless it is grounded in actual testimony. The moment AI is permitted to originate facts about a person's life without a human source, the entire evidentiary basis of the record is compromised.

**Silently create historical assertions.** If AI produces an inference — an event record, a claim about a relationship, a suggested fact — that inference must be visible as an inference, subject to review, and incapable of entering the authoritative record without steward promotion.

**Overwrite testimony.** A person's spoken memory, however imperfect, is primary evidence. An AI transcription that "corrects" a memory into something more historically plausible is not transcription — it is fabrication. AI-assisted transformation must be transparent and reversible.

**Erase provenance.** No AI operation may destroy the chain of custody that makes a record trustworthy. Transformation must be additive — the original is always preserved alongside the transformed version.

**Replace human authority.** The governance layer is the human layer. AI may prepare, suggest, flag, and assist. The steward decides. An AI system that promotes its own inferences to authoritative status has stepped outside the architecture and into a role it was never intended to occupy.

---

## Part III — Representation Is Not Reality

This is obvious when stated plainly. It becomes less obvious as the representations improve.

Consider a well-produced narrative about a person's childhood in a village that was destroyed in a war. If that narrative is generated from approved claims — from testimony, from photographs, from documented records — then it is a representation of governed knowledge. It is valuable, and it is trustworthy as a representation. But the narrative did not happen. The village existed. The childhood existed. The narrative is an interpretation of evidence about them.

Now consider a generated photograph of that village as it might have appeared. Or a synthetic recording of the person's grandmother's voice reading a letter she wrote. These are representations of even greater vividness. A person encountering them fifty years from now may struggle to maintain the distinction between the representation and the reality.

LifeBook's architecture must hold that line permanently. Not by avoiding vivid representations — they serve genuine human needs — but by ensuring that every representation is permanently, irrevocably linked to the governed record from which it was derived, and labelled in a way that cannot be removed.

Authenticity is not a property of how convincing something looks. It is a property of how well its origins are known and preserved.

---

## Part IV — Knowledge or Information?

LifeBook is preserving knowledge. The distinction matters.

Information can exist without context. A database row reading "born: 1887, location: Kyiv" is information. It can be stored, queried, and reported. It carries no indication of how it was known, how certain it is, or what it means in relation to anything else.

Knowledge includes all of that. Knowledge requires:

**Source**: Where did this come from? Who said it? What document recorded it?

**Confidence**: How certain is this? Is it documented, remembered, inferred, or contested?

**Relationships**: How does this fact connect to other facts? Is this birth record consistent with the marriage record? Does this photograph corroborate the testimony?

**Stewardship**: Who is responsible for this record? Who has verified it? Who has authority to govern what happens to it?

**Interpretation**: What does this mean? Not just what it says, but what it signifies in context — in a life, in a family, in a community, in a historical moment.

When a steward reviews an AI-inferred claim and promotes it to the authoritative record, they are not just clicking a button. They are converting information into knowledge by anchoring it in a human judgment, a chain of custody, and a relationship to other governed records. That act is the central operation of the governance layer, and it is the reason LifeBook cannot be reduced to a well-labeled database.

---

## Part V — Truth

A difficult question deserves a direct answer: can LifeBook preserve something that is sincerely believed but factually incorrect?

Yes. And it must.

Human memory is not a recording. It is a reconstruction. Every act of remembering is also an act of composing — shaped by current emotion, by the stories told about the past, by the forgetting that occurred in between. A person can genuinely, sincerely, honestly remember an event that did not happen the way they remember it. Or at all.

This is not pathology. It is how human memory works.

A family story is not simply true or false. It is a piece of social fabric. The story that a great-grandfather came to Canada with nothing and built a business through sheer will may be somewhat embroidered. The historical record may show he had more resources than the story suggests. But the story still tells us something true — about how the family understood itself, about the values it wanted to transmit, about the history it chose to remember. That meaning is real.

LifeBook must be able to preserve a memory alongside its uncertainty, a family story alongside the evidence that complicates it, a disputed fact alongside the competing testimonies. This is not an endorsement of any particular version of events. It is an accurate representation of what we actually know — which is that knowledge is always partial, always interpreted, always contested.

The alternative is a system that flattens everything into a single official version. That system would be less honest, not more.

What LifeBook commits to is not truth-by-declaration but trust-through-transparency: here is what was claimed, here is on what basis, here is what confidence we have, here is how this stands against competing evidence. A reader fifty years from now can work with that. They cannot work with a record that has silently discarded the uncertainty.

---

## Part VI — Human Memory as Evidence

Memory is not certainty. It is not fiction. It is evidence.

This framing has consequences for how LifeBook treats spoken testimony.

If memory is evidence, it must be preserved with the full attributes of evidence: source (who remembered), timing (when was this recounted), context (what prompted this memory), corroboration (what else supports or challenges it), and confidence (how certain does the person appear to be about it).

If memory is evidence, it must be evaluated alongside other evidence — not automatically privileged over documentary records, and not automatically subordinated to them. A person who remembers their birth year as different from what the certificate says may be wrong. They may also know something the certificate doesn't capture.

If memory is evidence, it must be preserved even when it turns out to be mistaken. The mistake itself is evidence — of what was believed, of how understanding changed, of the limits of human recollection in this domain.

A system that only preserves confirmed facts has already discarded most of what we know about most lives. A system that treats human memory as evidence — fallible, partial, valuable — has a chance of preserving something that resembles the truth of how a life was lived and understood.

---

## Part VII — Comparisons

Brief comparisons clarify what LifeBook is not, and what it is.

**A traditional database** stores data. It makes no claims about provenance, confidence, or epistemological status. A row is a row. If you want to know where the data came from or whether it is reliable, the database does not help you.

**An archive** stores documents. It focuses on authenticity and preservation — ensuring that an original is maintained intact. Archives are excellent at preserving evidence. They are not structured for the governance layer: they do not adjudicate competing claims, track confidence, or support active stewardship.

**Genealogy software** stores structured facts. It treats information as either established or to-be-established — as a tree that will eventually be complete. It models the world as if all facts about a person's life are knowable in principle and will eventually be entered. It has limited support for uncertainty, dispute, or the preservation of memory as distinct from documented fact.

**A large language model** generates plausible language. It has no connection to reality, no provenance, no evidence base, and no governance. It can produce a vivid, convincing narrative about any person's life. That narrative is indistinguishable from fabrication in the absence of the governance layer that LLMs do not provide. This is not a criticism of LLMs — it is a description of their nature. They are extraordinary tools for the representation layer. They are not, and cannot be, the governing architecture.

**LifeBook** is a governed knowledge system. It preserves evidence about real lives with explicit provenance, confidence tracking, dispute mechanisms, human stewardship, and a clear distinction between evidence and representation. It is designed so that a person fifty years from now can look at a record and understand not only what was claimed but how that claim was established, who was responsible for it, what the alternatives were, and how certain anyone was.

This is a fundamentally different kind of system from any of the above.

---

## Part VIII — Future Capabilities

The knowledge architecture described in this paper is not merely a description of the existing system. It is also a predictive model for future capabilities.

Every significant future feature of LifeBook fits naturally into one of the four layers, or into the relationships between them. This means that the architecture does not need to be redesigned to accommodate new capabilities — it needs to be extended within the existing framework.

**Provenance visualization** is a Representation layer capability that reads from Governance layer records. The data it needs — provenance chains, transformation records, approval history — is defined by the architecture. The visualization is a new representation of existing governed knowledge.

**AI disclosure in the interface** is a Governance layer responsibility exposed through the Representation layer. The disclosure policy (what must be shown, when, and at what level of detail) flows directly from the four-layer model: a user encountering a representation has the right to understand what layer of the architecture produced it.

**Conflicting memory handling** is a natural expression of the Governance layer. Multiple testimonies about the same event are not an error condition — they are the normal state of evidence about lived experience. The architecture supports this natively through the dispute and confidence model.

**Confidence-aware search** is a Representation layer feature built on Governance layer metadata. A search that can distinguish "documented birth year" from "estimated birth year" from "disputed birth year" is simply reading the epistemic status fields the Governance layer maintains.

**Documentary lineage** — the ability to trace a claim from its current form back through the transformations that produced it, to the original document or testimony — is a Governance layer capability with a Representation layer surface. The data model for this exists in principle in the current architecture and requires structured provenance event records to complete.

**Family collaboration** — multiple contributors, competing perspectives, steward-governed reconciliation — is a natural expression of the architecture. The Evidence layer accommodates multiple sources. The Governance layer manages authority and adjudication. The Representation layer presents the result.

**Research integration** — external databases, genealogical records, archival sources — is an Evidence layer capability. New documentary evidence is added to the record; the Governance layer determines its status; the Representation layer makes it visible.

None of these capabilities require fundamental redesign. They are extensions of an architecture that was designed, from the beginning, to support them.

---

## Part IX — Relationship to Existing Documents

This paper is conceptual. The existing documents are operational. They do not conflict; they operate at different levels of abstraction.

**LIFEBOOK_PRINCIPLES.md** contains the governing principles that constrain every implementation decision. The knowledge architecture described in this paper explains *why* those principles take the form they do. Principle IV ("The Record Is Governed, Not Inferred") is the Governance layer in a single sentence. Principle VII ("The Migration Chain Is the Truth") is the knowledge architecture's insistence that the schema — not the prose — is the authoritative implementation of the governance layer. Principle VIII ("Nothing Is Deleted") preserves the complete provenance chain that the knowledge architecture requires. The principles enforce the architecture at the operational level.

**AUTHORSHIP_PROVENANCE_AND_AI_DISCLOSURE.md** is the policy document that operationalizes the boundary between the Evidence layer and the Governance layer with respect to AI involvement. It defines the authorship taxonomy, the disclosure rules, and the governance requirements that give the architecture teeth. Where this paper describes what the layers are, that document describes what the rules are within the Governance layer.

**AI_ORCHESTRATION_LAYER.md** describes the technical implementation of AI's role in the Representation layer and its governance-assistance functions. It is the engineering specification for what this paper describes in principle: AI belongs in Representation and may assist Governance, but may not occupy the Evidence layer or act in Reality. The Orchestration Layer document translates that architectural position into component design.

The three documents together form a coherent hierarchy: the knowledge architecture explains the model, the principles enforce the commitments, the provenance policy operationalizes the boundary conditions, and the orchestration layer implements the technical structures.

---

## Closing Reflection

The question that opened this paper — *Where did this come from, and why should we trust it?* — is not new. It has been asked about every significant record system humans have ever built.

What is new is the context. We are entering a period in which the generation of convincing representations — plausible narratives, realistic images, authentic-sounding voices — is becoming trivially easy and increasingly indistinguishable from genuine evidence. The cost of fabrication is collapsing. The difficulty of distinguishing fabrication from evidence is growing.

In this environment, a system that stores information without provenance is not merely incomplete. It is actively unreliable. Any record in such a system might be genuine, or it might be generated. Without the governance layer, there is no way to know.

LifeBook's response to this is not to reject AI. AI is one of the most powerful tools available for the Representation layer — for making governed knowledge navigable, legible, translatable, and vivid in ways that preserve human dignity and family connection. Rejecting AI would mean rejecting tools that can make lived experience more accessible to the families who need it.

The response is to place AI within a governed architecture. AI generates and transforms within the Representation layer. AI assists governance within the Governance layer. AI never creates evidence, never originates claims about reality, never operates without provenance, and never promotes its own output to authoritative status without human review.

The four layers do not constrain what LifeBook can do. They constrain what LifeBook will call trustworthy.

That distinction — between capability and trust — is the philosophical foundation of the entire architecture. A system can generate almost anything. LifeBook is designed to preserve something: the governed knowledge of how lives were actually lived, by the people who actually lived them, within a chain of custody that future generations can follow back to its source.

That is what makes a life worth preserving.

---

*KNOWLEDGE_ARCHITECTURE.md — LifeBook HQ — 2026-07-27*
