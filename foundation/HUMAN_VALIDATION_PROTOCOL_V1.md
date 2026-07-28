# HUMAN_VALIDATION_PROTOCOL_V1.md
## LifeBook HQ — Phase 1 Experience Validation
**Status:** Phase 1 Draft — prepared by Claude, conducted by Tracy  
**Milestone:** Conversation Experience v1  
**Date:** 2026-07-27  
**Companion documents:** CONVERSATION_PROTOTYPE_V1.md (the script), UPLOAD_EXPERIENCE_DESIGN.md (upload scenarios), LIFEBOOK_VOICE_AND_CONVERSATION_GUIDE.md (evaluation criteria)

---

## Overview

This document is the operational protocol for Phase 1 human validation. It tells Tracy:
- Who to conduct sessions with
- How to run each session
- What to observe
- How to record findings
- What constitutes a passing result vs. a finding that requires iteration

Claude cannot conduct these sessions. The only way to know if the LifeBook experience works is to put a real person through it and see what happens.

---

## 1. Participant Profile

### Required: Ukrainian family participant

The primary validation target is someone with family connections to Ukraine — ideally someone who has:
- A family member who emigrated from Ukraine (especially since 2022)
- Family artifacts with Ukrainian-language material (documents, photographs)
- Family history that spans displacement, loss of property, or wartime separation

This is not the easiest session to start with. It is the right one to start with. The Ukrainian grandmother scenario is the hardest version of the experience — if it holds under those conditions, lighter scenarios will work.

**Why this participant first:**
- Tests the language barrier handling (Ukrainian/Russian documents)
- Tests the displacement and loss handling (Principle IX emotional boundary)
- Tests the proxy steward model (granddaughter building for grandmother)
- Cultural sensitivity: if the approach feels wrong to a Ukrainian participant, it will fail in production

### Secondary participants

After the Ukrainian session, conduct at least two additional sessions with participants from different contexts:

**Option A: Long-settled family historian**  
Someone who has been researching their family tree for years. They have a lot of facts, organized records, and opinions about genealogy tools. They will push on what LifeBook can and cannot do. Their frustrations are valuable.

**Option B: Person with living subject**  
Someone building a LifeBook for a living parent or grandparent who is present and participable. This tests whether the AI's voice holds when the subject of the LifeBook can hear what's being said about them.

**Option C: Person with significant cultural complexity**  
Someone from a community with specific cultural governance concerns — Indigenous family, refugee family with politically sensitive history, family spanning multiple countries. This tests Principle VI (Cultural Governance Is Real Governance) against the conversation experience.

---

## 2. Session Structure

Each session is approximately 45-60 minutes, structured as follows:

**Introduction (5 min)**  
Tell the participant: "We're testing a conversation system designed to preserve family history. I'm going to read you the system's responses. I want to know what feels right and what doesn't. There are no wrong reactions."

Do not explain LifeBook's principles or approach. Do not tell them what the system is designed to do. The session tests whether they experience those things — it does not tell them to expect them.

**Script session (30-40 min)**  
Run CONVERSATION_PROTOTYPE_V1.md. Tracy reads LifeBook lines. Participant responds naturally. Tracy reads the next line based on the branch the participant takes.

Do not improvise LifeBook lines on the first pass. If the participant goes somewhere the script doesn't cover, note it and say: "I'm going to make a note here — I want to flag this for the system design." Then take the most natural scriptable continuation.

**Debrief (10-15 min)**  
Ask the debrief questions from CONVERSATION_PROTOTYPE_V1.md Section "Debrief Questions." Record the answers verbatim — these are the core finding data.

---

## 3. What to Observe During the Script

These are the observations that matter most. Record them with timestamps and verbatim quotes where possible.

**Pauses:**  
When does the participant pause before answering? Long pauses (more than 5 seconds) after a LifeBook question signal that the question is either difficult, confusing, or touching something sensitive. Note: which question, how long, what the participant said next.

**Offers beyond the question:**  
When does the participant give significantly more than asked? This signals a thread the LifeBook question opened well. Note: which question triggered it, what they said.

**Short answers:**  
When does the participant give notably short answers to questions that would seem to invite more? This may signal discomfort, misunderstanding, or a mismatch between what LifeBook offered and what the participant wanted to talk about. Note: which questions got short answers.

**Pushback:**  
Any moment where the participant explicitly questions what the system is doing ("Can't you just...?" / "Why doesn't it...?" / "Shouldn't it be able to...?"). These are high-value findings. Record exactly what was said.

**Emotional signals:**  
Visible emotion — not just named emotion. If a participant becomes quiet, if their voice changes, if they deflect from a topic — note it without judgment. Do not probe. Note: what topic they were on, what changed.

**Trust signals:**  
Any explicit statement of trust ("I like that it just..." / "That felt right") or distrust ("That felt weird" / "I don't know if I'd want to..." / "What happens to this?"). These are direct evaluation data points.

---

## 4. Scenarios to Ensure Are Tested

At minimum, each session should cover:

1. **Opening:** Is the first question (who are you building this for?) the right entry point? Does it invite the participant in, or does it feel abrupt?

2. **A photograph with known subjects:** Does the AI's handling of the photograph — one question, receive the answer, hold the uncertainty — feel right?

3. **Something the participant doesn't know:** A date, a person's identity, where an artifact came from. Does "We'll keep it here" feel like the right response to not knowing?

4. **An exit moment:** Does the session include a natural moment where the participant is offered a choice to stop? Does the offer feel like genuine permission, or like a formality?

5. **If applicable: language barrier.** A document or artifact in Ukrainian, Russian, or another language. Does the AI receive it without interpreting?

6. **If applicable: loss or displacement.** A mention of something gone — a house, a place, a person. Does the response feel right?

---

## 5. Recording Findings

After each session, complete a finding record with this structure:

```
SESSION DATE: [date]
PARTICIPANT PROFILE: [brief description — no names]
SESSION DURATION: [minutes]

SCRIPT DEVIATIONS:
[List every moment where participant went somewhere the script didn't anticipate. 
Verbatim quote + what happened next.]

HIGH-VALUE OBSERVATIONS:
[5-10 specific moments that taught you something. Verbatim quote from participant 
+ what the LifeBook line was + what you observed.]

TRUST SIGNALS:
[Explicit statements of trust or distrust. Verbatim.]

PUSHBACK MOMENTS:
[Every moment of explicit pushback. Verbatim + context.]

EMOTIONAL SIGNALS:
[Any notable emotional moments. Topic + what changed.]

DEBRIEF ANSWERS:
[Verbatim answers to each of the 5 debrief questions.]

HEADLINE FINDING:
[One sentence: the most important thing this session taught you.]

OPEN QUESTIONS:
[What does this session leave unresolved? What would the next session need to test?]
```

---

## 6. What Constitutes a Passing Result

The goal of Phase 1 validation is not to prove the experience is perfect. It is to identify which elements work, which don't, and what needs to change before a prototype is built.

### Passing indicators (the experience is working)

- Participants respond to the one-question-at-a-time pacing without friction
- Participants accept "that's fine" as closure on things they don't know
- Participants find the exit offers (would you like to keep going?) reassuring rather than dismissive
- No participant interprets LifeBook lines as telling them what their life means
- Ukrainian participant does not find the handling of loss/displacement cold or inadequate
- At least one participant says something like "it felt like it was listening"

### Findings that require iteration

- Any participant feels pushed to provide information they don't have
- Any participant interprets a LifeBook line as evaluating or interpreting their story
- Any participant finds the approach cold at a moment of clear emotional weight
- Any participant raises explicit concern about what happens to their data or their story
- The Ukrainian participant finds the language barrier handling inadequate or presumptuous
- Multiple participants expect something the script doesn't offer (translation, identification, etc.)

### Findings that invalidate the current approach

- Consistent pattern where participants feel judged or evaluated
- Consistent pattern where participants feel the system is not listening
- The Ukrainian participant finds the displacement/loss handling harmful or dismissive
- Multiple participants explicitly state they would not trust the system with their family's story

If a session produces invalidating findings, the approach requires redesign — not iteration — before the next session.

---

## 7. After Validation: Feeding Findings Into Workstream 5

All session findings are the primary input for PHASE_1_ARCHITECTURAL_FINDINGS.md (Workstream 5). Specifically:

- Script deviations → conversation architecture gaps
- Pushback moments → feature expectations to evaluate (add, defer, or explicitly exclude)
- Trust failures → design constraints for the experience layer
- Cultural sensitivity findings → constraints for Principle VI implementation
- Passing indicators → confirmation of which design choices are validated

The findings document is raw data. Workstream 5 is interpretation. That interpretation is done together — Tracy brings the session experience, Claude brings the architectural analysis.

---

## 8. Session Checklist

Before each session:
- [ ] Read CONVERSATION_PROTOTYPE_V1.md — have the script in front of you
- [ ] Have a blank finding record ready to fill in
- [ ] Know which scenarios you want to ensure are covered
- [ ] Do not explain the principles to the participant beforehand

During each session:
- [ ] Record verbatim quotes — exact words matter
- [ ] Note timestamps on significant moments
- [ ] Do not improvise LifeBook lines; use the script
- [ ] Do not fill silences; let them breathe
- [ ] If participant goes off-script, note it and take the most natural scripted continuation

After each session:
- [ ] Complete the finding record while details are fresh (same day)
- [ ] Identify the headline finding
- [ ] Note what the next session needs to test differently

---

*HUMAN_VALIDATION_PROTOCOL_V1.md — LifeBook HQ — Phase 1 Experience Validation — 2026-07-27*
