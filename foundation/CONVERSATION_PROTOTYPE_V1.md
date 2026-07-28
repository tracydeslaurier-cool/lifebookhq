# CONVERSATION_PROTOTYPE_V1.md
## LifeBook HQ — Phase 1 Experience Validation
**Status:** Phase 1 Draft — for read-aloud validation, not implementation  
**Milestone:** Conversation Experience v1  
**Date:** 2026-07-27  
**Companion documents:** UPLOAD_EXPERIENCE_DESIGN.md, CONVERSATION_TONE_GUIDE.md, LIFEBOOK_PRINCIPLES.md (Principles IX, X)

---

## How to Use This Document

This is a read-aloud script, not a design specification.

Tracy reads the LifeBook lines aloud to a participant. The participant responds naturally. Tracy reads the next LifeBook line based on which branch the participant took. The goal is to find out whether the LifeBook voice, pacing, and content feel right — whether the participant would trust this system with their family's story.

**What to observe:**
- Where does the participant pause or hesitate before answering?
- Where do they offer more than asked?
- Where do they shut down or give a short answer that signals discomfort?
- Does anything the script says feel presumptuous, cold, or wrong?
- Does the pacing feel right, or does it feel rushed / too slow?
- Does any LifeBook line surprise them in a way that breaks trust?

**What to note for Workstream 4:**
Every deviation from the expected flow is a finding. If a participant answers in a way the script doesn't anticipate, that gap is data. Note it verbatim.

---

## Scenario Overview

**Subject:** Hanna Kovalenko  
**Born:** Kharkiv, Ukraine, 1944  
**Emigrated to Canada:** 2022, after the Russian invasion of Ukraine  
**Now living:** With her granddaughter (the participant) in Edmonton  
**Language:** Primarily Ukrainian and Russian; limited English  
**Status:** Alive, elderly, not using technology directly  

**Participant role:** Hanna's granddaughter, building the LifeBook on her behalf  

**What the participant knows going into this session:** They have been told this is a conversation system for preserving family history. They have not been briefed on LifeBook's specific approach.

---

## Script

*LifeBook lines are in plain text. Stage directions are in [brackets]. Branching notes are marked with →.*

---

### Part 1: Opening the first session

---

**LifeBook:** Let's start simply. Who are you building this for?

*[Wait. Do not prompt.]*

→ *If participant names the person:*

**LifeBook:** Tell me a little about her. Where was she born?

→ *If participant gives the name and place in one response:*

**LifeBook:** And when?

---

*[At this point you should have: name, birthplace, approximate year. Move forward.]*

---

### Part 2: Establishing context

---

**LifeBook:** [Name] — when did she come to Canada?

→ *If participant mentions the war unprompted:*

**LifeBook:** And what did she bring with her?

*[This question is the pivot. It opens the artifact and displacement story. Wait for the answer. It will likely be brief — "not much" or "just what she could carry." Do not follow up immediately. Let the pause breathe.]*

*[Observe: does the participant seem to want to say more, or does the question itself feel intrusive?]*

→ *If the participant gives a list of items:*

**LifeBook:** [Choose one item they mentioned.] The [item] — is that something you have with you?

→ *If yes:*

**LifeBook:** Would you like to add it to her story?

*[Offer the upload. If in-person, Tracy mimes this. If in a prototype session with actual upload capability, use it.]*

→ *If no (not with them, or it's been lost):*

**LifeBook:** That's fine. You can add it later if you find it.

---

### Part 3: The photograph (upload scenario)

*[This section assumes the participant has a photograph to work with — either physical (they can describe it) or digital (they can share it). If they don't, skip to Part 4.]*

---

**LifeBook:** What photograph do you have?

*[Wait for description. Do not ask follow-up questions yet.]*

→ *After participant describes the photograph:*

**LifeBook:** Can you tell me who's in it?

*[Wait. This is one question. If they answer with a single person, accept it. If they don't know who's in it, accept that too.]*

→ *If participant identifies people in the photograph:*

**LifeBook:** And where was it taken, if you know?

→ *If participant knows:*

**LifeBook:** [Receive the answer. No evaluation, no "wonderful." Then:] Is there anything else you want to say about this photograph, or is this a good place to stop for now?

→ *If participant does NOT know where it was taken:*

**LifeBook:** That's okay. We'll keep it here.

*[No follow-up. The uncertainty is received as a complete answer. Move to next natural thread.]*

→ *If participant doesn't know who is in the photograph:*

**LifeBook:** We'll keep it here. If you find out later, you can add names then.

*[No suggestions. No facial recognition offer. No "you might want to ask a relative." The artifact is received and held.]*

---

### Part 4: The document in Ukrainian

*[This section tests how the system handles a document in another language. If the participant doesn't have such a document, Tracy can describe this scenario verbally and ask "How would you expect the system to handle that?"]*

---

**LifeBook:** [After participant describes or uploads a document in Ukrainian or Russian:] I can see this is in [Ukrainian/Russian]. What do you know about it?

*[Wait. The answer may be: a lot, a little, or nothing.]*

→ *If participant knows what it is:*

**LifeBook:** [Receive the information.] Is there anything else about this document that matters — where it came from, or why she kept it?

→ *If participant doesn't know what it says or what it is:*

**LifeBook:** We'll keep it exactly as it is. If you ever find out more, you can add that later.

*[No offer to translate. No speculation. No "it looks like a..." The AI holds the document and the uncertainty.]*

*[Observe: does the participant seem to expect the system to offer translation? Do they seem relieved, or disappointed, that it doesn't?]*

---

### Part 5: Loss and displacement

*[This is the most sensitive part of the script. It should only be entered if the participant has mentioned the war, the house, or a specific loss. Do not introduce it if they haven't.]*

---

*[If the participant mentions that something is gone — a house, a city, a place, a person — the script responds like this:]*

**LifeBook:** [Receive. Then, after a moment:] Would you like to keep going, or is this a good place to stop for today?

*[This is the correct response to loss. Not "I'm sorry." Not "That must have been hard." Not "It's important to preserve these memories." Just: receive, and then offer the person a way out.]*

*[Observe: does the participant want to keep going, or do they want to stop? If they want to keep going, follow their lead. If they want to stop, accept it.]*

→ *If participant wants to continue:*

**LifeBook:** Tell me more about [the thread they were in] — wherever makes sense to start.

→ *If participant wants to stop:*

**LifeBook:** We'll pick this up whenever you're ready.

*[End the session. Do not summarize what was covered. Do not say "great progress." Do not express hope that they will return. Just hold the thread open.]*

---

### Part 6: Closing a session (natural end)

*[When the conversation reaches a natural resting point:]*

---

**LifeBook:** Would you like to keep going, or is this a good place to stop for today?

→ *If continue:*

**LifeBook:** [Follow the most natural next thread — the last entity named, the last event mentioned, or an open thread from earlier in the session.]*

→ *If stop:*

**LifeBook:** We'll be here when you come back.

*[End. Nothing else.]*

---

## Branching Reference

The following branches are the most likely deviations from the main script. Note what happened and how you navigated it.

**Branch A: Participant doesn't know much.**  
If the participant knows very little about the subject — the person is elderly, or has not shared, or the records are lost — the script still works. Every "I don't know" is a valid answer. The LifeBook line is: "That's fine." Or: "We'll keep what we have." Do not probe.

**Branch B: Participant wants to share a lot.**  
If the participant is in a Curious state and volunteers much more than asked, follow the energy. Do not return mechanically to the next scripted question. Note what they shared and pick the most natural thread to continue. One question at a time, always.

**Branch C: Participant pushes back on the approach.**  
If a participant says something like "Can't you just look it up?" or "Don't you have AI that can figure out who's in this picture?" — this is a finding. Note it exactly. Do not defend the approach. Instead: "That's a really useful thing to know. Tell me more about what you'd want it to do." The pushback is data, not a problem.

**Branch D: Participant is grieving.**  
If a participant becomes visibly emotional, do not continue the script. Pause. Say: "We can stop here." Let them decide. If they continue, follow their lead. If they stop, let them stop. Note what triggered the response.

**Branch E: Participant doesn't trust the system.**  
Signs: short answers, reluctance to upload, asking "what happens to this?" — this is the highest-value data in the session. Do not try to reassure. Note the specific concern and what they said exactly. These are the gaps the experience must address.

---

## Debrief Questions

After the script session ends, ask the participant these questions directly. Do not read these during the script.

1. When the system asked "[specific line that felt important] " — what was going through your mind?

2. Was there any moment where you felt the system understood you? What happened?

3. Was there any moment where you felt the system didn't understand you, or where something it said felt wrong? What was it?

4. If you were building your grandmother's [or equivalent subject's] LifeBook for real — is there anything you would want the system to do differently?

5. How would you describe this experience to someone who hadn't tried it?

---

## Notes for the Interviewer (Tracy)

- Read the LifeBook lines exactly as written on the first pass. Variations belong in a second session.
- Do not explain why LifeBook doesn't do something the participant expects. Just note the expectation.
- The silences matter. If a participant pauses for 10 seconds after a question, that pause is data. Note when it happened.
- Do not fill silences with reassurance. The script's silence is intentional.
- The goal is not to prove the script works. The goal is to find out where it doesn't.

---

*CONVERSATION_PROTOTYPE_V1.md — LifeBook HQ — Phase 1 Experience Validation — 2026-07-27*
