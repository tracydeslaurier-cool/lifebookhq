# FOUNDER_ACCEPTANCE_JOURNEY.md
## LifeBook HQ — Conversation Experience v1
**Status:** Design — awaiting implementation  
**Milestone:** Conversation Experience v1  
**Date:** 2026-07-27  
**Companion documents:** CONVERSATION_TONE_GUIDE.md, CONVERSATION_STATE_ENGINE.md, CONTEXTUAL_UPLOAD_FLOW.md

---

## 1. Purpose

This document defines the first complete experience a Founding Member encounters when they open LifeBook for the first time. It ends when the person has:

- A first **person** record (themselves, or someone they're creating a book for)
- A first **story** (a narrative linked to an event or period)
- A first **uploaded photograph** (or a pending obligation for one)
- An **invited family member** (sent or declined)

This is a guided experience — controls are minimal, flow is led by LifeBook, and every step has a clear way forward. The goal is to leave the founder feeling that something real has been preserved, not that they've filled out a form.

---

## 2. Hypothetical Subject

For illustration: **Marta Shevchenko**, born 1947 in Poltava, Ukraine. Immigrated to Canada in 1992 with her husband Bohdan and their two adult children. Now 79, living in Edmonton. Her daughter Oksana has created the LifeBook account on her behalf and is guiding the first session.

This hypothetical is representative of the Founding Member demographic and tests the system's handling of:
- A subject who is not the account holder
- Immigration and displacement narratives
- Family contribution patterns
- Non-English names, places, and dates

---

## 3. The Journey

### Step 1: Welcome

The first screen after onboarding is simple. No tutorial. No video. No list of features.

```
LifeBook: "Tell me about yourself."
```

If Oksana is creating the book on her mother's behalf, she will say so. LifeBook adjusts.

```
Oksana: "This is actually for my mother, Marta. She was born in Ukraine."

LifeBook: "I'd love to hear about Marta. Let's start with her."
```

**What's created:** A thread is opened. No entity record yet — entity creation waits for enough information.

---

### Step 2: The First Person

LifeBook gathers the minimum needed to create a person record — not everything, just enough to anchor the story.

```
LifeBook: "What's her full name?"

Oksana: "Marta Oleksandrivna Shevchenko. She was Marchenko before she 
         married — that's her maiden name."

LifeBook: "And when and where was she born?"

Oksana: "July 14th, 1947, in Poltava — that's in central Ukraine."

LifeBook: "Is Marta still alive?"

Oksana: "Yes. She's 79 and still very sharp."
```

**What's created:**
- `entities` record: type=person, entity_id generated
- `persons` record: linked to entity
- `person_names` record: Marta Oleksandrivna Shevchenko (legal name), Marchenko (birth name, derivative type = maiden_name)
- Claims: birth date (1947-07-14, precision=day), birth place (Poltava, Ukraine)
- Thread is now anchored to Marta's entity_id

LifeBook does not ask for everything at once. Birth date and place are enough to proceed.

---

### Step 3: The First Story

Once the person is established, LifeBook invites the first story — not the full life, just one thing.

```
LifeBook: "Is there a part of Marta's life you'd like to start with?"

Oksana: "Her immigration. She and my father came to Canada in 1992. It 
         was a very hard time."

LifeBook: "What made them decide to come?"

Oksana: "The Soviet Union had just collapsed. Things were very uncertain. 
         My father had a cousin in Edmonton who helped them."

LifeBook: "Did they come together — all four of you?"

Oksana: "Yes. My brother was 23 and I was 21. We came on tourist visas 
         and applied for refugee status when we arrived."

LifeBook: "That was a significant journey. What do you remember about 
         arriving?"

Oksana: "It was November. We had four suitcases between us. My mother 
         cried at the airport — not from sadness, I think. Just the 
         weight of it."
```

**What's created:**
- `narratives` record: "Immigration to Canada, 1992" — linked to Marta and family entities
- `events` record: Immigration event, November 1992
- Claims: immigration year, immigration destination (Edmonton, Canada), travel context
- Thread summary updated: "Immigration to Canada, November 1992. Four suitcases. Bohdan's cousin in Edmonton. Arrived on tourist visas."

```
LifeBook: "That's a powerful image. Do you have any photographs from 
         that time — arriving, early days in Edmonton, anything?"

Oksana: "I have one. It's us at the airport. My father is holding a 
         folder — our documents. We all look tired."

LifeBook: "That sounds like exactly the kind of photograph worth keeping. 
         Would you like to add it now?"

Oksana: "Yes."
```

---

### Step 4: The First Upload

```
LifeBook: [upload interface appears]

         "Add the airport photo here. Once it's uploaded, it'll be 
         attached to your family's immigration story."

Oksana: [uploads photo]

LifeBook: "That's been added. It's now part of the immigration story."
```

**What's created:**
- `artifacts` record: type=photograph, validity_state=pending_review
- `artifact_source_links`: artifact → narrative (immigration story)
- Thread obligation: fulfilled (airport photo)

The photo is at `pending_review`. Since Oksana is the steward, she can approve it immediately or let it process. LifeBook doesn't ask about this — the review queue exists in the background.

---

### Step 5: First Family Member Invited

After the upload, LifeBook offers the invitation naturally — not as a separate step, but from the conversation.

```
LifeBook: "Is there anyone else in your family who would have memories 
         from that time — your father, your brother?"

Oksana: "My brother Andriy. He has a different perspective. He was 
         older than me."

LifeBook: "Would you like to invite Andriy to add his memories to 
         this story?"

Oksana: "Yes, that would be wonderful."

LifeBook: "What's the best way to reach him — email or phone?"

Oksana: "Email. andriy.shevchenko@gmail.com"

LifeBook: "Done. Andriy will receive an invitation. When he joins, 
         he'll be able to add to the immigration story — and you'll 
         be notified when he does."
```

**What's created:**
- An invitation record for Andriy
- Thread moves to `pending_materials` (awaiting Andriy's contribution)
- Obligation: Andriy's contribution
- Access classification for Andriy's contribution: `family` (he can see what Oksana has added, and add his own)

---

### Step 6: Closing the Founding Session

```
LifeBook: "You've made a real start today. Marta's story is here — 
         her birth, the immigration, the airport photo, and an 
         invitation to Andriy. Would you like to keep going, or 
         is this a good place to pause?"

Oksana: "I think this is good for today. There's so much more to 
        tell."

LifeBook: "It'll be here when you're ready. Whenever you come back, 
         we can continue."
```

Thread state: `pending_materials` (Andriy's invitation pending)  
Open obligations: Andriy's contribution  
Session ends.

---

## 4. What the Founder Has After One Session

| Item | Description |
|---|---|
| Person | Marta Oleksandrivna Shevchenko, b. 1947, Poltava, Ukraine |
| Birth name | Marchenko (maiden name recorded) |
| Story | Immigration to Canada, November 1992 |
| Event | Arrival in Edmonton, November 1992 |
| Claims | ~8 claims: birth date, birth place, immigration year, destination, travel context, family members present |
| Photograph | Airport arrival photograph, pending review |
| Invited member | Andriy Shevchenko (invitation sent) |
| Thread | "Immigration to Canada, 1992" — pending_materials |

This is a complete founding session. Not a complete LifeBook — which could take years — but a real, meaningful start.

---

## 5. Design Observations

**The person doesn't need to be the account holder.** Oksana creating a book for her mother is a primary use case, not an edge case. The system must handle this naturally from the first question.

**The story doesn't need to start at birth.** Oksana chose immigration because it was most alive for her in that moment. LifeBook followed. Birth records came because they were contextually asked, not because there's an enforced order.

**Difficulty is expected.** "It was a very hard time" — LifeBook absorbed this without making it a pivot point. It acknowledged and continued. This is the tone guide in practice.

**The photograph is emotional, not bureaucratic.** "My father is holding a folder of documents. We all look tired." LifeBook treated it as significant without turning it into a metadata entry exercise.

**The invitation emerged from the conversation.** Andriy wasn't presented as a "feature." He emerged because LifeBook asked "is there anyone else." This is how contribution should work — not as a settings page, but as a natural extension of sharing.

---

## 6. Data Model at End of Founding Session

```
entities (1 new: Marta)
persons (1 new: Marta)
person_names (2 new: Shevchenko (legal), Marchenko (maiden))
claims (~8 new: birth date, birth place, immigration year, etc.)
narratives (1 new: Immigration to Canada)
events (1 new: Arrival in Edmonton)
event_participants (4 new: Marta, Bohdan, Oksana, Andriy)
artifacts (1 new: airport photograph, pending_review)
artifact_source_links (1 new: photo → narrative)
ConversationThread (1: immigration story, pending_materials)
pending_obligations (1: Andriy's contribution)
invitation (1: Andriy Shevchenko)
```

The LifeBook is not empty. It has structure, story, image, and a thread leading forward.

---

## 7. Variations Not Covered in This Document

- **Founder creating their own book** (not for a relative)
- **Founder who starts with a person who has already died**
- **Founder whose primary language is not English**
- **Founder who starts with a photo rather than a conversation**
- **Founder with no family members to invite**
- **Founder in a cultural community with restricted governance requirements**

These variations follow the same structural pattern but require tone and flow adaptations. They will be addressed in separate experience design documents as the product matures.

---

*FOUNDER_ACCEPTANCE_JOURNEY.md — LifeBook HQ — Conversation Experience v1 — 2026-07-27*
