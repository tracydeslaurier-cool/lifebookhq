# CONVERSATION_CONTROLS.md
## LifeBook HQ — Conversation Experience v1
**Status:** Design — awaiting implementation  
**Milestone:** Conversation Experience v1  
**Date:** 2026-07-27  
**Companion documents:** CONVERSATION_STATE_ENGINE.md, THREAD_CONTINUATION_MODEL.md

---

## 1. Design Philosophy

Controls exist to give users agency over the conversation — not to manage the interface. There should be as few as are actually needed, they should be invisible when not relevant, and they should never appear more important than the conversation itself.

The goal is a screen where the conversation is the dominant element and the controls are peripheral. A user who never uses a control should never feel like they're missing something.

---

## 2. The Control Set

Three controls cover the full range of conversation management needs in v1:

| Control | What it does |
|---|---|
| **New topic** | Starts a fresh thread without ending the current one |
| **Come back later** | Pauses the current thread and exits gracefully |
| **Add something** | Opens the upload/contribution flow inline |

A fourth state indicator — not a control — communicates open threads passively:

| Indicator | What it shows |
|---|---|
| **Open threads** | A count or brief label for threads with unresolved obligations |

---

## 3. Control Descriptions

### 3.1 New topic

**Purpose:** The user wants to talk about something different without abandoning the current thread.

**When it appears:** Always available during an active conversation, but visually quiet — it doesn't compete with the conversation.

**What happens:**
1. Current thread is moved to `paused`
2. Any unresolved obligations are preserved
3. A new thread begins, either anchored to what the user says next or to an explicit topic they name
4. The paused thread appears in the open threads indicator

**What it does not do:**
- It does not end the old thread
- It does not prompt the user to "finish" the old thread first
- It does not show a modal or confirmation dialog

**Conversation example:**
> **User:** [taps "New topic"]  
> **LifeBook:** "What would you like to talk about?"

That's it. The topic follows from what the user says.

---

### 3.2 Come back later

**Purpose:** The user wants to stop for now. The thread stays open.

**When it appears:** Always available during an active conversation. Also offered naturally by LifeBook when it detects a natural pause point — end of an event, long gap between messages, or after a difficult topic.

**What happens:**
1. Current thread moves to `paused`
2. Outstanding obligations are preserved
3. Session closes gracefully
4. No nudge is sent for at least the minimum dormancy interval (default: 3 days)

**What it says:**
> "Your story will be here when you're ready."

No elaboration. No "see you soon!" No confirmation dialog.

**Proactive offering by LifeBook:**

After a natural pause point (e.g., a story has reached a complete-feeling moment, or a difficult topic has been discussed), LifeBook may offer:

> "Would you like to keep going, or is this a good place to stop for today?"

This is not an instruction. The user can ignore it and keep talking.

---

### 3.3 Add something

**Purpose:** The user wants to contribute material — a photo, document, correction, or additional detail — without waiting for LifeBook to ask.

**When it appears:** Available during any active conversation. Particularly prominent when the conversation is on a topic that typically has associated materials (events, people, places).

**What it opens:**
An inline contribution panel with options:
- Add a photo or document
- Add a note or correction
- Invite someone to contribute

The user can choose and the conversation thread absorbs the contribution without navigating away.

**When the user adds a correction:**
> **User:** [taps "Add something" → "Add a note or correction"]  
> **LifeBook:** "What would you like to add or correct?"  
> **User:** "Actually I got the year wrong — it was 1968, not 1967."  
> **LifeBook:** "Got it. We've updated that. The original answer is kept for reference."

The correction creates a superseding claim. The original is retained per the permanent-record model.

**When the user invites someone:**
> **User:** [taps "Add something" → "Invite someone to contribute"]  
> **LifeBook:** "Who would you like to invite? You can add their name and contact information, and we'll send them an invitation to contribute to this part of your story."

The invitation flow is separate from this document but links to the stewardship and access model.

---

## 4. When Controls Appear

### 4.1 Persistent controls
**New topic** and **Come back later** are always available during a conversation, but styled to be quiet. They appear in a consistent location (e.g., bottom corner or collapsed into a single "..." menu) and never compete visually with the conversation.

### 4.2 Contextual controls
**Add something** becomes more visually prominent when:
- The topic is known to have associated materials (wedding, military service, immigration)
- LifeBook has offered an upload and the user declined
- The user has just described a physical object

It recedes when the conversation is in emotional territory (difficult memories, uncertainty) — not removed, just less prominent.

### 4.3 The open threads indicator
This is always visible in some form — a small badge, a count, a thread name. It is not a notification. It does not pulse or flash. It is simply visible information that says "you have unfinished stories."

---

## 5. How Controls Affect Thread State

| Control | Current thread state | New thread state | Other effects |
|---|---|---|---|
| New topic | active | paused | New thread created |
| Come back later | active | paused | Session ends |
| Add something (upload) | active | active | Obligation fulfilled or created |
| Add something (correction) | active | active | Superseding claim created |
| Add something (invite) | active | pending_materials | Invitation created, obligation added |

---

## 6. Tracking Unfinished Threads

Unfinished threads surface in two ways:

### 6.1 Open threads indicator
A lightweight count or label visible at all times:
- "2 stories in progress" 
- Or simply: "Wedding Day · Military Service" (thread names)

Tapping the indicator opens the **thread browser** — a simple list of active and paused threads with their pending obligations. From there the user can jump back into any thread.

### 6.2 Natural continuation at session start
When a user returns after an absence with open threads, LifeBook opens with a continuation offer (see THREAD_CONTINUATION_MODEL.md for language). This is not a notification — it is the opening of the conversation.

---

## 7. What the Controls Are Not

**They are not a navigation bar.** LifeBook is not an app with sections. The controls manage the conversation, not the experience.

**They are not a menu.** "Add something" expands inline. Nothing pushes the user out of the conversation flow.

**They are not obligatory.** The user who never uses a control should still have a complete and functional experience. Controls are for power users and edge cases, not for core flow.

**They are not present on every screen.** During the onboarding/founder journey (see FOUNDER_ACCEPTANCE_JOURNEY.md), controls are not visible. The experience is guided. Controls appear once the person has established their first thread and is in open-ended conversation.

---

## 8. Mobile Considerations

On small screens:
- **New topic** and **Come back later** collapse into a "..." menu that expands on tap
- **Add something** remains a floating button near the input field (familiar pattern from other messaging apps)
- The open threads indicator collapses to a numeric badge

The controls should require no tutorial. Their labels are self-explanatory. A user encountering them for the first time should be able to figure out what they do without help.

---

*CONVERSATION_CONTROLS.md — LifeBook HQ — Conversation Experience v1 — 2026-07-27*
