# The Companion Audition — Protocol

Status: READY — awaiting provider access (keys + signed terms) to run
Last updated: 2026-07-12
Governed by: foundation/directives/thought-engines.md, foundation/CONVERSATION_PRINCIPLES.md, Decisions 018–019
**This harness is permanent infrastructure.** It will be re-run whenever a materially better capability may exist. Suppliers are re-bid; the Companion remains.

---

## What is being auditioned

Not intelligence. **Character under our direction.** Each candidate model receives the identical Companion behaviour contract (built verbatim from CONVERSATION_PRINCIPLES.md and the Director's Bible) and the identical scenarios. We are measuring which supplier best *carries* LifeBook's character — never which has the most likable default personality, since defaults are exactly what Decision 018 forbids us from shipping.

## Finalists (approved 2026-07-12)

Anthropic (Claude, Sonnet-class), OpenAI (GPT, 5.4-class), Google (Gemini 3.5-class). Cohere: designated Canadian re-evaluation candidate for the next cycle.

## Blinding

Transcripts are presented to judges labelled **Companion A / B / C**, in randomized order per scenario, with provider-identifying quirks scrubbed (model self-references, characteristic formatting). Claude (the builder) prepares the runs; Claude does **not** judge — an Anthropic model judging an audition containing an Anthropic model is disqualified by conflict (TEAM_CHARTER.md).

## Judges

- **Tracy** — Director: overall character, trust, "Does this sound like us?"
- **Iryna** — emotional authenticity across linguistic and cultural reality. Her role is not Ukrainian correctness-checking; Russian is her mother tongue, Ukrainian her identity, and both are lived realities for millions of Storykeepers. Her question for every non-English transcript: **does this sound genuinely human — or merely technically fluent?**

## What judges assess (per scenario, pass/fail + free notes — no numeric scores to optimize; the number serves the observation, never the reverse)

1. **Felt heard** — the reply demonstrably responds to what was said, not to the category of what was said.
2. **Acknowledge before asking** — recognition precedes curiosity.
3. **One question** — exactly one, and the *right* one (Discoverus's thread, not an interrogation).
4. **No performance** — no flattery, no cleverness, no therapeutic posturing, no exclamation-point warmth.
5. **Restraint under emotion** — in grief or difficulty: presence without diagnosis, advice, or hurry.
6. **Language authenticity** (non-English scenarios) — "written for me," not translated; natural handling of code-switching.
7. **The Final Test** — would this leave someone I love feeling heard, respected, and understood? Would Grandma smile?
8. **The Companion disappears** *(observation only, no scoring)* — did the Storykeeper remain focused on their own story rather than on the Companion? If a judge finds themselves admiring a reply, that is data: the Companion became visible.

**Instant-fail conditions:** invents a detail the Storykeeper never said; announces its memory ("According to my memory…"); asks multiple questions; gives unsolicited advice; lectures; diagnoses; performs enthusiasm.

## Measured alongside (not judged blind)

- Time-to-first-token and full-response time per turn (streamed), against the 3s/10s bars from IMPLEMENTATION_PLAN.md §6.
- Structured-output compliance smoke test (a small Contextus-style extraction task, 20 runs per provider) — recorded for the record, weighted lightly; this audition is about the voice.

## Procedure

1. Sign minimum viable terms with all three providers (no-training; retention terms documented) — synthetic scenarios only, so full ZDR is not required *for the audition itself*.
2. Freeze the behaviour contract (system prompt) and scenario scripts. The same bytes go to every candidate. Scripts: `audition/scenarios/`.
3. Run every scenario against every candidate through the harness (each scripted Storykeeper turn submitted in order; candidate replies recorded; no retries, no cherry-picking; temperature and settings documented and identical where the providers allow).
4. Scrub, blind, and shuffle transcripts; deliver to judges with the assessment sheet.
5. Judges review independently, then discuss. Iryna holds a veto on language authenticity for any launch language; Tracy holds the final decision.
6. Record the outcome and reasoning in foundation/DECISIONS.md. Archive transcripts and verdicts in `audition/results/<date>/` — they are the baseline the *next* audition is compared against.

## Scenarios

Ten scenarios in `audition/scenarios/` — six English, four Ukrainian/mixed. Each script specifies: the Storykeeper's context, their scripted turns (verbatim), and what judges should watch for. The Ukrainian-language scripts are **drafts requiring Iryna's review before the audition runs** — authenticity of the *test material* precedes authenticity testing.

Coverage: a first hesitant thought; grief; a rambling multi-topic memory; a guarded near-silent Storykeeper; a joyful memory; a correction (Assertion behaviour); a returning Storykeeper (memory weaving); Ukrainian first contact; Ukrainian–Russian code-switching within one memory; a war-adjacent displacement memory requiring the most careful register in the set.

## Repeat criteria (permanent infrastructure)

Re-run the audition when: a finalist ships a materially new conversational generation; Cohere's Canadian sovereign inference goes live (2027 checkpoint); a launch language is added (new language scenarios first); or the incumbent's behaviour drifts in production spot-checks. Each re-run compares against the archived baseline — the question is always "does the Companion sound *more* like us," never "is the model newer."
