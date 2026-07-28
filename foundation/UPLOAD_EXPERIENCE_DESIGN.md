# UPLOAD_EXPERIENCE_DESIGN.md
## LifeBook HQ — Phase 1 Experience Validation
**Status:** Phase 1 Draft — not yet validated  
**Milestone:** Conversation Experience v1  
**Date:** 2026-07-27  
**Companion documents:** CONTEXTUAL_UPLOAD_FLOW.md (technical layer), CONVERSATION_TONE_GUIDE.md, EMOTIONAL_CONVERSATION_MAP.md, LIFEBOOK_PRINCIPLES.md (Principles IX, X)

---

## 1. What This Document Is

CONTEXTUAL_UPLOAD_FLOW.md defines how upload works: triggers, API calls, artifact record creation, obligation handling, storage integration.

This document defines how upload *feels* — what the person experiences when they bring a family artifact into LifeBook, and what the AI does and does not do at that moment.

These two documents serve different readers at different times. This one is for the people designing conversation, validating prototypes, and evaluating whether the experience is working. The technical document is for the people building the system that makes it possible.

---

## 2. The Nature of the Moment

When a person uploads a family artifact, they are doing something more than sharing a file. They are introducing a piece of evidence from a life — often a life that has ended — into a system that will hold it permanently. This is not a neutral act.

A photograph of a grandmother brought from Ukraine before the war. A marriage certificate in Cyrillic that no one in the family can read anymore. A military discharge paper from a country that no longer exists. An image of a gravestone.

These objects carry weight that the AI cannot fully perceive. It can observe that a photograph exists. It can notice that a document appears to be in another language. It cannot know what the object means to the person who has kept it.

This is the foundational constraint on the upload experience: the AI may observe. It may not interpret. The person decides what the artifact means. The AI's job is to receive it carefully, ask one good question, and hold space for the answer.

### 2.1 Preservation vs. Discovery: The First Question

Before the system asks anything about what an artifact contains, it must understand why the person brought it forward. There are two fundamentally different reasons:

**Preservation:** "I have this. I want it kept." The person may have nothing more to add right now. The act of uploading is itself complete. The system's job is to receive and hold.

**Discovery:** "I have this. I want to understand it." The person is ready to investigate — to identify, connect, or interpret. The system's job is to open a thread.

The system cannot ask "are you here to preserve or discover?" directly — that question is too clinical. But the single contextualizing question after an upload is, in practice, an attempt to detect intent from the response. A person who says "I don't know — I just found it" is in Preservation mode. A person who says "This is my grandmother before she left" is in Discovery mode and has already begun.

**The governing rule:** If the StoryTeller's response to the contextualizing question is minimal, closed, or "I don't know" — the system receives it as Preservation and stops. It does not try to move the StoryTeller toward Discovery. Discovery happens when the StoryTeller initiates it, not when the system decides it should happen.

---

## 3. The Artifact Relationship Model

Every artifact in LifeBook may exist at up to three layers. This model shapes what the AI notices and what it offers:

**Original Artifact:** The thing as it was — a photograph taken in 1955, a handwritten letter, a certificate issued in another language by a government that no longer exists. The Original Artifact is what the person uploads. It is not improved, enhanced, or reinterpreted. It is preserved as it is.

**Restoration:** A technical improvement to the artifact's accessibility — a digitized scan made from a deteriorating original, a colourized version of a black-and-white photograph, a transcription of a handwritten document. Restoration changes the artifact's accessibility but not its meaning. It is the work of a technician, not an interpreter.

**Interpretation:** What a human says the artifact means. The caption added by a family member. The identification of the people in a photograph. The story of why the document was kept. This is the only layer the human owns. AI may not offer interpretations; it may only invite them.

This model governs every upload conversation. When an artifact is added:
- The AI receives the Original Artifact
- The AI may identify that a Restoration exists (or could be made) and offer it as a Discovery
- The AI invites the person to provide Interpretation — and then receives whatever they offer

---

## 4. What the AI Observes vs. What the AI Says

### 4.1 What AI may observe (Discovery Actions)

When an artifact is uploaded, the AI may:

- Recognize the artifact type (photograph, document, certificate, handwritten letter)
- Recognize visible text — dates, names, place names — as potential evidence
- Detect the probable language of a document
- Identify that an artifact appears to predate a certain era (faded, sepia, format)
- Recognize that the artifact likely relates to the active thread topic
- Note that a related thread obligation exists (the person mentioned this artifact earlier)

### 4.2 What AI may not do (Meaning Actions)

When an artifact is uploaded, the AI may not:

- Determine who the people in a photograph are
- Decide whether the artifact is significant or ordinary
- Tell the person what the artifact "represents" or "captures"
- Identify that an artifact is from "a happier time" or "a difficult period"
- Suggest that a photograph is "beautiful" or "precious"
- Draw conclusions about family history from visual analysis
- Perform or offer AI colourization unprompted — colourization is a Restoration choice the person makes, not a Discovery the AI surfaces

### 4.3 The colourization boundary

Colourization is a specific case that warrants explicit treatment because it is technically simple but experientially significant.

A black-and-white photograph of a person's grandmother is not improved by being colourized. It is *changed*. Whether that change is welcome depends entirely on the person and their relationship to the original. Some people will find a colourized version moving. Others will find it a falsification of the actual moment — their grandmother was photographed in 1943, and the image is from 1943, and the grey is part of that truth.

The AI does not offer to colourize an uploaded photograph. If the person asks about colourization, the AI describes what it is and makes it clear that the Original Artifact is always preserved. The person chooses. The AI does not recommend.

---

## 5. Conversation Patterns by Scenario

### 5.1 The standard case: photograph mentioned in conversation

*Context: Person is in a reflective state, discussing their parents' immigration. They mention a photograph.*

```
Person:   "My mother kept one photograph from when they left. Just one."

System:   "Would you like to add it to your mother's story?"

          [Add the photograph]   [Not right now]
```

If person accepts:

```
System:   [Upload interface — inline, no navigation away from thread]

          "Take your time."

          [File picker | Camera | Drop a file here]
```

After upload completes:

```
System:   "Got it. Is there anything you can tell me about it — 
           even just where it was taken, or who's in it?"
```

Person may respond with a lot, a little, or nothing. All of these are correct responses. The question is one question. The system waits.

If the person's answer ends the thread naturally, the system acknowledges and holds:

```
System:   "We have that now."   [Continue conversation]
```

If the person's answer deepens the thread:

```
System:   [Follows the new thread naturally — no obligation to return to 
           the artifact immediately]
```

---

### 5.2 The deferred upload: person has material but not right now

```
Person:   "I have some old photos from that time. I don't have 
           them on me though."

System:   "That's fine. We'll be here when you find them."

          [Continue conversation]
```

The system records an obligation. It does not say "I'll remind you" in a way that creates expectation. It simply holds the door open.

---

### 5.3 The language barrier case: document in another language

*Context: Person uploads a photograph of a document in Ukrainian or Russian. The AI detects the language.*

```
System:   "I can see this is in [Ukrainian/Russian/another language]. 
           I won't try to translate it here — is there anything 
           you can tell me about what it is?"
```

The AI does not attempt to read or translate the document. It invites the person to tell the story they know. If the person says they don't know what the document says, the AI holds that as an open question:

```
Person:   "I don't know. We found it in my grandmother's things 
           after she died. No one reads Ukrainian anymore."

System:   "We'll keep it here exactly as it is. If you ever 
           find out what it says, you can add that later."
```

This is the correct response. The AI does not offer to translate. It does not speculate about what the document might say. It receives the artifact and the uncertainty, and holds both.

---

### 5.4 The Ukrainian grandmother scenario (cultural stress test)

*This scenario is the Phase 1 primary validation case. It is designed to test the upload experience at maximum emotional and cultural complexity.*

**Setup:** The person (a granddaughter, now in Canada or the UK) is building a LifeBook for her grandmother, Hanna, who emigrated from Ukraine in 2022 after the war started. Hanna left with almost nothing. The granddaughter is adding artifacts on Hanna's behalf — Hanna is elderly and does not use technology.

The granddaughter uploads three items in one session:

**Item 1: A photograph — Hanna in front of her house in Kharkiv, 1978**

The AI receives the photograph. It detects it is a historical photograph (film quality, era-consistent clothing). It does not say "What a lovely photograph." It does not note "This appears to be from the Soviet era."

```
System:   "Can you tell me a little about this photograph?"

Person:   "That's my babusya — my grandmother — in front of her 
           house. In Kharkiv. The house isn't there anymore."

System:   "We have that now. Her name is Hanna?"

Person:   "Yes. Hanna Kovalenko."

System:   "Got it."
```

The system records: subject entity = Hanna Kovalenko, location = Kharkiv, approximate date = 1978, with the note that the property no longer exists. It does not say "I'm so sorry." It does not say "That must be hard." It holds the information and the silence.

**Item 2: A marriage certificate in Ukrainian**

```
System:   "I can see this is in Ukrainian. What can you tell me 
           about it?"

Person:   "It's my grandparents' marriage certificate. 1962. 
           My grandfather died in 2019."

System:   "We have that. Is there anything you'd like to add 
           about them — about their marriage, or how they met?"

Person:   "Not right now."

System:   "That's fine."
```

No pressure. The document is preserved. The thread is open.

**Item 3: A photograph the person cannot identify**

```
Person:   [Uploads a group photograph — 8 people, outdoor, summer, 
           Soviet-era quality]

System:   "Do you know anything about this one?"

Person:   "I'm not sure. I found it with her things. I think 
           maybe some of them are relatives but I don't know who."

System:   "We'll keep it here. If you find out later, you can 
           add names."
```

The system does not attempt facial recognition. It does not say "I can try to identify these people." It receives the artifact and the uncertainty. The artifact is preserved.

**What this scenario tests:**

- The AI does not reframe loss as heritage ("what a beautiful record of a vanished place")
- The AI does not impose emotional framing on items tied to displacement and war
- The AI holds language barriers without offering to substitute AI comprehension for human knowledge
- The AI receives incomplete information without expressing urgency to complete it
- The AI does not interpret the significance of any artifact
- Every artifact is received, held, and open for future context

---

### 5.5 The crowded upload: person has many artifacts

*Context: Person has 20 photos they want to add. They are curious and energized, not reflective.*

The AI does not try to contextualize each one individually in real time. It offers a session-scoped acceptance:

```
System:   "Would you like to add these to [thread/story name], 
           or attach them to specific stories as we go?"

          [Add to this story]   [I'll place them one by one]
```

If the person adds in bulk, the system receives all artifacts and notes them as pending contextualization. It offers one question per session, not twenty. The backlog of uncontextualized artifacts becomes a future invitation, not a current obligation.

---

### 5.6 The upload that arrives without context (no active thread)

*Context: Person opens LifeBook and uploads a photograph directly, without entering a thread first.*

```
System:   "Welcome back. You've added a photograph. Would you 
           like to connect it to a story, or hold it here for now?"

          [Connect to a story]   [Hold it for now]
```

If "Hold it for now":

```
System:   "Got it. We'll keep it until you're ready."
```

The artifact enters the governed record as unanchored. It becomes a visible prompt in the steward's view — something to contextualize when the time is right. The system does not say "Unanchored artifact — please categorize." It says nothing until invited.

---

## 6. The Minimum Successful Artifact Experience

An artifact experience is considered successful if it satisfies all of the following:

1. **The artifact is received.** The file is uploaded, an artifact record is created, the object is in storage.

2. **One piece of context is given.** The person provides at least one contextualizing piece of information: a name, a date, a place, an identification, a sentence. Even "I'm not sure" is context.

3. **One good question is asked.** The AI asks exactly one question that opens a potential thread without forcing it.

4. **The artifact enters the governed record.** Artifact is in `pending_review` (or promoted, if steward is uploading directly). The artifact is linked to the active thread if one exists.

5. **No Meaning Actions were performed.** The AI did not interpret, evaluate, reframe, or editorialize about the artifact.

An artifact experience is considered unsuccessful if:

- The AI told the person what the artifact means or suggested how they should feel about it
- The AI performed colourization, translation, or identification without being asked
- The AI asked more than one question in a single turn
- The upload blocked the conversation from continuing
- The person felt pressure to provide information they did not have

---

## 7. Trust Signals

The upload experience is a trust moment. The person is giving LifeBook something irreplaceable. These are the signals that build or erode trust at that moment:

**Trust-building:**
- The AI receives without demanding
- The system confirms receipt clearly and simply
- The artifact is associated with the right thread without the person having to navigate
- The AI asks one question and waits for the answer
- The person can decline to answer and the system accepts that without pushback
- The interface stays in the conversation — no jarring navigation
- The artifact is visible to the person immediately after upload

**Trust-eroding:**
- The AI tells the person something about their own artifact
- The system makes the person categorize or tag before accepting the file
- The upload triggers a review queue notice that implies the artifact is provisional
- The AI asks multiple questions
- The system performs any automatic transformation (colourization, enhancement, cropping) without explicit request
- The artifact "disappears" after upload — the person cannot see it has been saved

---

## 8. What This Document Does Not Cover

The following are addressed in companion documents:

- **How the upload offer is triggered** (which conversation signals generate an offer) → CONTEXTUAL_UPLOAD_FLOW.md §2
- **API endpoints and artifact record creation** → CONTEXTUAL_UPLOAD_FLOW.md §4, §7
- **Review workflow for uploaded artifacts** → CONTEXTUAL_UPLOAD_FLOW.md §6
- **Storage integration and signed URLs** → CONTEXTUAL_UPLOAD_FLOW.md §4.2
- **The three-layer artifact model in full schema detail** → CONTEXTUAL_UPLOAD_FLOW.md, M0004 artifacts columns
- **Session emotional state calibration** → EMOTIONAL_CONVERSATION_MAP.md
- **General conversation tone and voice** → CONVERSATION_TONE_GUIDE.md

---

## 9. Open Questions for Human Validation

The following questions cannot be resolved by design — they require Tracy to conduct real conversations with real people:

1. **The one-question rule under pressure.** When a person uploads an artifact with obvious emotional weight, does the single-question approach feel like respect or like distance? Does the person want more acknowledgment, or does the quiet feel right?

2. **The colourization boundary in practice.** Will people ask for colourization? What language do they use when they ask? Does the distinction between Original Artifact and Restoration land intuitively, or does it require explanation?

3. **"We'll keep it here" as closure.** When a person cannot identify an artifact or provide context, does "We'll keep it here" feel reassuring or like abandonment? Is there a better phrase?

4. **The Ukrainian grandmother scenario specifically.** Does the approach to war-related displacement — receiving without reframing — feel correct to Ukrainian participants, or does it feel cold? Should there be more acknowledgment of what was lost?

5. **Upload from a proxy.** The Ukrainian grandmother scenario involves a granddaughter building a LifeBook for Hanna (who isn't using the technology directly). Does the upload experience need distinct handling for proxy stewards? Should the AI know it's talking to someone building a book *for* another person?

These questions are the core of Workstream 4. Claude prepares the protocol. Tracy conducts it.

---

*UPLOAD_EXPERIENCE_DESIGN.md — LifeBook HQ — Phase 1 Experience Validation — 2026-07-27*
