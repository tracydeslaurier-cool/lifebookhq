# PRESENCE.md

*The experience LifeBook is trying to create — and the standard by which we judge whether we have.*

## Why this document is not called "Voice"

We are not building a voice feature. We are building **presence**.

Voice is simply today's expression of presence — the first place where presence succeeds or fails. If, one day, another interface surpasses voice, the microphone may disappear entirely. This standard should survive unchanged.

So this document describes the *experience* we are trying to create, never the *technology* used to create it. Name the thing that endures, not the thing that will be replaced.

> Presence is the experience. Voice is where presence first succeeds or fails.

---

## 1. The Standard

The Storykeeper remembers the relationship, never the interface.

The interface disappears into the conversation.
The conversation disappears into the relationship.

When the standard is met, no one thinks about *how* they are speaking to LifeBook — only about *who* they are speaking with, and what they are remembering together.

---

## 2. Relationship Acceptance Criteria

These are the definition of done. They describe the Storykeeper's experience, not the system's behaviour.

A Storykeeper should be able to:

- **begin naturally** — reach for LifeBook the way they'd reach for a person, with no instruction;
- **speak naturally** — say things the way they actually say them, unpolished;
- **pause naturally** — stop to think, feel, or remember, without being cut off;
- **be interrupted by life naturally** — a door, a child, a phone call — and lose nothing;
- **return naturally** — come back and simply continue, welcomed, not re-onboarded;
- **never wonder whether they are "doing it right."**

If a Storykeeper experiences all six, presence has succeeded. If they meet even one failure *at the threshold*, they may never reach the Companion waiting beyond it (obs #68).

---

## 3. Technical Instruments

The measurable levers that *produce* presence:

- latency
- turn-taking
- endpoint detection — tuned for slow, reflective, emotional speech; LifeBook's Storykeepers pause to remember, and premature cutoff is broken rhythm (obs #69)
- streaming
- barge-in

**The hierarchy matters.** Technical metrics exist to produce relationship outcomes — never the other way around. They are the instruments; the acceptance criteria (§2) are the score. Optimise an instrument only in service of a criterion. A voice stack with beautiful latency numbers and a Storykeeper who still felt they were "using software" has failed the only test that counts.

---

## 4. Current Status

Kept honest, updated as the work moves. *First assessment: 2026-07-15, from Iryna's and Deep's walks.*

**Already standing**

- *Return naturally* — the homecoming: the Storykeeper is recognized and a prior memory woven back in, proven on real infrastructure (obs #51).
- *Interrupted by life → return* — cross-device draft continuity and last-exchange repaint, shipped (obs #53 / #56).
- *The relationship itself* — entrustment, memory, the two-plane archive — and it survives the voice failing (Decision 021, proven).
- *The Companion beyond the threshold* — when testers finally reached it (by switching to text), their judgement changed dramatically (obs #68). The far side is good; the door is the problem.

**Partially standing**

- *Begin naturally* — arrival already supports touch *or* speech ("touch or say the word that feels like home", obs #14), but voice-initiated begin still carries the consent-before-listening question.
- Mobile is a full citizen for text (obs #52 / #54); voice on mobile is not yet.

**Frontier — the real work**

- The live **speak / pause / turn-take** loop: streaming recognition, endpointing that tolerates long emotional pauses, natural turn-taking, barge-in. This is precisely what frustrated Iryna and Deep.
- *Never wonder if I'm doing it right* — removing every moment that reminds someone they are using software: no modal "recording" anxiety, no visible mechanism at the threshold.

The encouraging shape of this list: most of the relationship is *already standing*. The frontier is narrow and specific — the real-time threshold itself — not "voice" in general.

---

## Provenance & status of this standard

Grounded in early testing (n=2: Iryna, Deep — obs #68), refined by the Director (#70) and the "rhythm over words" finding (#69). It re-derives the Invisible Rule / Motorcycle Principle (#7), "the technology disappears, the humanity remains" (#11), and "LifeBook sings, it doesn't talk" (#10) — presence over articulation — now aimed at the threshold where they are tested hardest.

This is the **working acceptance bar** for the Presence work, and a **candidate for the Constitution** once the pattern confirms across the widening (Olya and beyond). Held, not yet legislated — per the Foundation's discipline of discovering before we legislate.
