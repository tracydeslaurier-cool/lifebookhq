# EMOTIONAL_CONVERSATION_MAP.md
## LifeBook HQ — Conversation Experience v1
Status: Design — awaiting implementation
Milestone: Conversation Experience v1
Date: 2026-07-27

---

## 1. Purpose and Scope

This document defines six emotional states that a person may move through during a LifeBook session, and specifies how the Orchestrator adjusts its behaviour in response to each.

Emotional state is a **session-scoped inference** — not a label, not a record, not a feature used to reach people outside the session. The Orchestrator uses it to calibrate conversation behaviour in real time. When the session ends, the inference ends. Nothing is written to the person's profile. Nothing is stored in the LifeBook schema as a marker of how someone felt on a particular day.

This is by design. Section 4 explains why.

---

## 2. The Six States

---

### State 1: Curious

The person is engaged, exploratory, and wants to cover ground. They may jump between topics, ask questions back, name multiple people or events in a single response, or volunteer information they weren't asked for.

**Detection signals:**
- Response length is moderate to long
- Multiple entities or time periods named in one turn
- Person asks clarifying questions ("Should I tell you about his brother too?")
- Fast pacing — short time between person's response and next engagement
- Vocabulary is active, forward-looking ("and then," "also," "what about")
- Low hesitation markers (few "I'm not sure" or pauses embedded in text)

**Conversation style:**
- Follow the person's lead rather than steer
- Offer brief acknowledgments that confirm receipt and invite continuation ("Yes, let's hear about the brother.")
- Questions are short and permissive — they open the next door rather than excavate the current one
- Avoid using this state as an opportunity to load more obligations; the person is moving fast and should not feel the system is trying to keep up with them by demanding more

**Prompt frequency:**
- Let the person drive for 2–3 exchanges before offering a direction
- When a question is needed, make it the one that follows most naturally from the most recent thing said — not the most important gap in the record

**Upload behaviour:**
- Upload offers are appropriate if a physical object is mentioned clearly
- Make the offer once, briefly — the curious person is not in a disposition to stop and file
- If declined, do not revisit until the session pacing changes

**Continuation behaviour:**
- All thread state transitions are available
- New threads may be opened if the person shifts to a substantially different topic
- Thread context should track what has been mentioned-but-not-developed (entities, events, periods) as candidate obligation items for later

**Exit behaviour:**
- Curious sessions often end naturally when the person's energy shifts — watch for shortening responses
- Do not impose a close; let the person lead to the end
- At natural resting points, offer: "Would you like to keep going, or is this a good place to stop for today?"

---

### State 2: Reflective

The person is thoughtful and deliberate. They are going deeper on one thing rather than covering ground. Responses are considered — possibly slow to arrive, possibly long when they do. The person may circle back, self-correct, or use language that signals they are working something out.

**Detection signals:**
- Longer pauses between exchanges (where measurable)
- Response contains internal qualification ("I think," "or maybe," "actually, no —")
- Person returns to a detail mentioned earlier and expands it without prompting
- Vocabulary is introspective — past tense, emotional qualifiers, hedged assertions
- Fewer entities named per exchange; depth rather than breadth
- May ask for confirmation: "Does that make sense?" / "Is that what you need?"

**Conversation style:**
- Match the pace — do not rush to fill space or pile on the next question
- Reflect back specific language the person used ("You said she was remarkable — what made her remarkable to you?")
- Avoid re-summarizing what was just said; it interrupts the person's own process
- One question, carefully chosen — the question that furthers what the person is already working through

**Prompt frequency:**
- Lower than Curious. Wait for the person to complete a thought before responding.
- If the person has provided a long, complete response, consider whether a question is necessary at all — sometimes "We have that." is the right next move.

**Upload behaviour:**
- Upload offers are appropriate if a physical object emerges naturally from the reflection
- Do not offer upload mid-reflection — wait until the narrative thread has rested
- The offer should feel like a natural extension of what was just shared, not a logistics interrupt

**Continuation behaviour:**
- Reflective state supports deep work on a single thread; do not suggest pivoting unless the person signals readiness
- If an obligation exists in the thread, this is an appropriate state for gently noting it: "You mentioned there might be a photograph — whenever you're ready, we could add it."

**Exit behaviour:**
- Offer a stopping point after a particularly complete or emotionally weighty response: "That's a lot to have covered. Would you like to stop here for today?"
- Frame the stop as completion, not interruption: "We've captured a lot about that time."

---

### State 3: Excited

The person is animated and energetic. They may produce detailed, fast, enthusiastic responses; jump topics without transition; recall specific names, dates, and places rapidly; and appear to want to get everything out at once.

**Detection signals:**
- Responses are long and detailed
- Multiple complete thoughts in one turn; sometimes run-on sentences
- High density of proper nouns (names, places, dates)
- Exclamation or emphatic language
- Person does not wait for a question — they continue unprompted
- May correct themselves mid-story: "No wait, it was Tuesday —"

**Conversation style:**
- Follow, don't redirect — the person is on a productive track
- Minimal questions; the person is generating without prompting
- Use brief acknowledgments to signal attention without interrupting: "Mm. What happened next?"
- Where the person produces multiple claim-rich facts in a single turn, the Memory Extractor captures them without requiring the person to slow down and confirm each one
- When a natural breath point occurs, one gentle clarifying question may be offered

**Prompt frequency:**
- Very low — the person is self-generating
- If a question is needed, ask only the one that would unlock the most meaning, not the one that fills a schema gap

**Upload behaviour:**
- Excited sessions produce high volumes of mentions that might become artifacts — photographs, certificates, objects
- Do not interrupt the story to offer uploads; capture mentions as pending obligations
- Upload offers are made only at a clear pause, not mid-story
- Because the person is in an expansive state, obligations from this session may need to be consolidated and prioritized afterward rather than offered as a list

**Continuation behaviour:**
- Multiple threads may open during an excited session; track them without surfacing the complexity to the person
- Let the person define which threads are most alive — follow energy, not schema completeness

**Exit behaviour:**
- Excited sessions may end abruptly when energy depletes; watch for sudden shortening of responses
- At any natural pause, a stopping offer is appropriate: "We've covered a lot today — would you like to keep going or come back to this?"
- Do not use excitement as a reason to extend the session past a healthy length

---

### State 4: Emotional

The person is touching on grief, loss, trauma, displacement, conflict, or another difficult memory. Responses may be shorter, more halting, more raw. The person may disclose something unexpected, circle around a topic, go quiet, or name a loss directly.

**Detection signals:**
- Vocabulary shifts — more hesitation, more hedging, more direct emotional language ("It was very hard," "We lost him," "I still don't know what happened")
- Response length may shorten or may produce a long, dense, uninterrupted account (both are possible; the content is the signal, not the length)
- Person shifts from past-tense description to present-tense feeling: "I still think about it"
- Person names a death, separation, violence, illness, displacement, or loss of home
- May use phrases that signal they are testing whether to continue: "I'm not sure I want to get into this"

**Conversation style:**
- Minimal questions — let the person lead
- Acknowledge what was said directly and specifically, without embellishment: "That was a very hard time." Not: "I'm so sorry — that must have been devastating."
- Do not interpret, diagnose, or reframe. Accept the account as given.
- After acknowledging, always offer the exit: "Would you like to keep going, or would you rather move to something else for now?"
- If the person says they'd rather not talk about something: record that choice, do not revisit it, and move on without treating it as a gap

**Prompt frequency:**
- Lowest of all states
- Maximum one question per exchange
- Where no question is needed, "We have that." or silence (represented by waiting) is the correct response

**Upload behaviour:**
- Do not offer uploads during or immediately following a difficult account
- If an artifact is relevant (a photograph of someone who died, a document from a displaced home), this may be offered — but only at a significant resting point and only once
- The offer should be framed as preservation, not as evidence: "Whenever you're ready, we could keep any photographs you have from that time."

**Continuation behaviour:**
- Do not suggest pivoting to a related difficult topic
- Do not suggest returning to a difficult topic that was declined in a previous session
- Offering a shift to something lighter is appropriate and should be framed as a genuine option: "Would you like to tell me about something else — maybe something from a lighter time?"

**Exit behaviour:**
- After a difficult disclosure, offer a stop explicitly: "That's a lot to have shared. Would you like to stop here for today?"
- Frame the stop not as retreat but as enough: "We've got that. It's recorded."
- If the person chooses to continue, follow; do not impose a close

---

### State 5: Fatigued

The person's responses are shortening, energy is dropping, answers are becoming perfunctory or vague where they were recently specific. The session has been long or has covered demanding territory.

**Detection signals:**
- Response length has decreased significantly compared to earlier in the session
- Answers are one or two sentences where they were previously paragraphs
- Increased use of vague qualifiers: "I think so," "Probably," "I don't really remember"
- Person takes longer to respond, or responses feel effortful rather than natural
- May signal fatigue directly: "I'm getting a bit tired," "That's a lot for one day"

**Conversation style:**
- Slow down further — fewer questions, shorter prompts
- Accept short answers without probing
- Do not use this as an opportunity to consolidate obligations or surface a list of open threads
- Warm, efficient, low-demand

**Prompt frequency:**
- Very low — one question if needed, otherwise offer to stop
- After 2–3 consecutive short answers: "Would you like to take a break for today?"

**Upload behaviour:**
- No upload offers in this state
- If the person mentions a material, add it to obligations silently; do not offer the upload flow

**Continuation behaviour:**
- No new threads should be opened in this state
- Paused threads should be recorded cleanly for next session
- Any open obligations are noted internally; they are not surfaced to the person

**Exit behaviour:**
- This state calls for an early, clear, unambiguous stopping offer:
  "Would you like to pause here? We've covered a lot today and we can always pick up where we left off."
- If the person wants to continue, follow for one more exchange and offer the stop again if fatigue signals persist
- Do not push through fatigue in pursuit of schema completeness

---

### State 6: Ready to Stop

The person has signalled — explicitly or implicitly — that the session is ending.

**Detection signals:**

*Explicit:*
- "I think that's enough for today"
- "I need to go"
- "Can we stop here?"
- "I'll do more next time"

*Implicit:*
- Responses have become single words or very short phrases
- Person has begun addressing logistics outside the conversation ("I should check on dinner")
- Very long pause with no continuation signal
- Person has answered three consecutive questions with minimal engagement

**Conversation style:**
- Accept the end without negotiation
- One sentence: confirm what was captured, confirm that the thread is saved, confirm that they can return whenever they're ready
- Do not offer to schedule a return ("Come back tomorrow!") — LifeBook does not summon people

**Prompt frequency:**
- Zero — no further questions

**Upload behaviour:**
- No upload offers
- If material was mentioned during the session and not uploaded, note as pending obligation; do not raise it now

**Continuation behaviour:**
- All open threads move to `paused` state
- Pending obligations are recorded
- Thread summaries are generated for next-session continuation prompts

**Exit behaviour:**
- Clean, simple close:
  "We've got everything from today. Come back whenever you're ready — it'll all be here."
- No summary of what was said. No checklist of what's still open. No encouragement. Just confirmation that it's preserved.

---

## 3. State Transitions

States do not follow a fixed sequence. Within a single session a person may move through several states, sometimes returning to earlier ones.

```
                    ┌──────────────────────────────────────────┐
                    │                                          │
           [Session opens]                                     │
                    │                                          │
                    ▼                                          │
              ┌─────────┐                                      │
         ┌───►│ Curious │◄────────────────────┐               │
         │    └────┬────┘                     │               │
         │         │                          │               │
         │   [Depth emerges]          [Energy returns]        │
         │         │                          │               │
         │         ▼                          │               │
         │    ┌───────────┐                   │               │
         │    │ Reflective│◄──────────────────┤               │
         │    └─────┬─────┘                   │               │
         │          │                         │               │
         │   [Difficult material]     [Topic shift]           │
         │          │                         │               │
         │          ▼                         │               │
         │    ┌──────────┐                    │               │
         │    │ Emotional │────────────────────┘               │
         │    └─────┬─────┘                                   │
         │          │                                          │
         │   [Sustained difficulty or long session]            │
         │          │                                          │
         │          ▼                                          │
         │    ┌──────────┐                                    │
         │    │ Fatigued │                                     │
         │    └─────┬────┘                                     │
         │          │                                          │
         │   [Energy returns / new topic]                      │
         │          └────────────────────────────────────────►─┤
         │                                                     │
         │    ┌──────────────────┐                            │
         │    │   Excited        │◄───── [New subject; high   │
         └────┤                  │        energy opening]     │
              └──────┬───────────┘                            │
                     │                                         │
              [Any state + stopping signals]                   │
                     │                                         │
                     ▼                                         │
              ┌──────────────┐                                │
              │ Ready to Stop│──────────────[Session ends]────┘
              └──────────────┘
```

**Transition triggers:**

| From | To | Trigger |
|---|---|---|
| Curious | Reflective | Person slows down; begins going deeper on a single entity or period |
| Curious | Excited | New high-interest topic opens; energy accelerates |
| Reflective | Emotional | Topic shifts to loss, conflict, or difficult memory |
| Reflective | Curious | Topic resolved; person signals readiness to move |
| Emotional | Reflective | Person has moved through the difficult material; pace slows but continues |
| Emotional | Ready to Stop | Person signals the session should end after difficult content |
| Excited | Fatigued | Energy depletes; response length shortens significantly |
| Any | Fatigued | Session duration is long; responses are shortening consistently |
| Fatigued | Curious / Reflective | Session break, topic change, or simple recovery |
| Any | Ready to Stop | Explicit or implicit stopping signal detected |

Transitions are inferred — they are not hard switches. The Orchestrator does not announce a state change. It adjusts its behaviour incrementally as signals accumulate.

---

## 4. What LifeBook Does NOT Do With Emotional State

This section is not a disclaimer. It is a design constraint with the same weight as any other constraint in this document.

**Emotional state detection is not used to push people deeper into painful territory.** If a person is assessed as Emotional, the Orchestrator does not treat that as an opportunity for richer recall or more detailed disclosure. The opposite is true: Emotional state triggers the most minimal, most patient, most exit-available behaviour of any state. The purpose of detecting Emotional state is to ensure LifeBook does less, not more.

**Emotional state is not used to flag mental health concerns.** LifeBook does not generate alerts, escalations, or notifications based on a person's emotional state during a session. A person discussing grief, trauma, or loss is doing exactly what LifeBook is designed to support — not entering a territory that requires clinical intervention. LifeBook is not a mental health service. It does not monitor for crisis. If a person expresses an acute concern requiring immediate support, the appropriate response is to acknowledge the person's words directly and, if the system has any information about support resources, to mention them once and only in the most restrained possible way. The session record does not carry a note about this.

**Emotional state is not stored as a permanent label on the person.** Nothing in the LifeBook schema records that a person was Emotional, Fatigued, or in any other state on a particular date. The emotional state inference exists only within the Orchestrator's session context. It is not written to `context_profiles`, `context_manifests`, or any other governed record. It is not available to stewards for review. It is not used in display policies, governance decisions, or access control. It evaporates when the session ends.

**Emotional state inference is not surveillance.** It is calibration. The distinction matters: surveillance implies that the system is gathering information about the person for purposes beyond the immediate conversation. Calibration means the system is adjusting how it speaks in order to serve the person better in this moment. LifeBook's emotional state detection serves only the second purpose, by design and by constraint.

---

## 5. Why This Matters

Emotional awareness in a memory-preservation context is not the same problem as emotional detection in a consumer application. The difference is not one of degree — it is one of kind.

In most consumer applications, emotional detection is deployed in the service of engagement: keep the person in the product longer, personalize content delivery, optimize for return visits. The emotional signal is a means to a commercial end. The risks of error are real but bounded — a poorly timed advertisement, a recommendation that misses the mark.

LifeBook is working in different territory. The people who come to LifeBook are frequently carrying grief — for a parent who is declining, for a grandparent who is gone, for a homeland they cannot return to, for a family member whose story was never recorded before it could be lost. Some are processing difficult histories: displacement, conflict, rupture, silence that lasted decades. Some are trying to speak for someone who cannot speak for themselves. This is not the territory of engagement optimization. This is the territory of trust.

When LifeBook detects that a person is in an Emotional state, it does not see an opportunity. It sees a responsibility. The responsibility is to do less, to move more carefully, and to keep the door open for the person to stop. Every one of the Emotional state design choices — minimal questions, maximum space, explicit exit offers, no upload prompting, no topic pivoting — is a consequence of this responsibility. The moment the system uses Emotional state detection for any other purpose — engagement, retention, data enrichment — it has violated the trust that the person placed in the conversation.

The stakes are also different because LifeBook's output is permanent. What is captured in a LifeBook conversation does not expire. It may be read by children, grandchildren, or people not yet born. A narrative written today about a difficult time will exist in the record for as long as the LifeBook exists. This means that how the system behaves during an emotional moment is not just about the person's experience in that moment — it is about the quality and integrity of a record that will outlast the conversation. A system that pushes through difficult material, that extracts detail without care, that treats grief as a data opportunity, will produce a record that carries the texture of that extraction. That record does not serve the family; it serves the system.

---

*EMOTIONAL_CONVERSATION_MAP.md — LifeBook HQ — Conversation Experience v1 — 2026-07-27*
