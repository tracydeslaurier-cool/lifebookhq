# THREAD_CONTINUATION_MODEL.md
## LifeBook HQ — Conversation Experience v1
**Status:** Design — awaiting implementation  
**Milestone:** Conversation Experience v1  
**Date:** 2026-07-27  
**Companion documents:** CONVERSATION_STATE_ENGINE.md, CONVERSATION_CONTROLS.md

---

## 1. The Problem

Most conversational systems fail at returning. They either say too much ("You never finished telling me about your grandmother!") or nothing at all — the thread just sits there, lost.

LifeBook needs to thread the needle: remember what was left open, offer to return, but never make the person feel like they owe the system an answer.

---

## 2. When Continuation Is Offered

### 2.1 Session-open continuation (primary trigger)
When a user opens LifeBook and has one or more paused threads, the session opens with a continuation offer. This is the default entry point for returning users.

**Conditions:**
- At least one thread is in `paused` or `pending_materials` state
- The thread has not been already continued or archived
- Minimum dormancy has passed (configurable; default 0 — can offer immediately on return)

### 2.2 Obligation-triggered continuation
A specific obligation's `followup_after` date has passed and `followup_count < max_followups`. This does not trigger a notification — it affects what LifeBook says when the user next opens a session.

### 2.3 Inbound material continuation
A file arrives (uploaded by the user or contributed by a family member). If it can be associated with a paused thread, LifeBook offers to resume that thread around the new material.

### 2.4 Natural in-conversation pivot
During an active conversation on one topic, the user mentions something that belongs to a paused thread. LifeBook can note the connection without pivoting:

> "That sounds connected to what you shared about your father's military service — we can link them later if you'd like."

This is informational only. The user is not redirected.

---

## 3. Language Patterns for Continuation

The opening language for continuation is critical. It must:
- Remind without recapping at length
- Invite without pressuring
- Offer a genuine alternative (start fresh, or see what's been added)

### 3.1 Single paused thread

```
"Last time we were talking about your [thread topic]. 
Would you like to pick up where we left off, or is there 
something else on your mind?"
```

Example:
> "Last time we were talking about your wedding day. Would you like to pick up where we left off, or is there something else on your mind?"

### 3.2 Paused thread with pending obligation

```
"Last time we were talking about your [thread topic]. 
[Obligation brief.] We can come back to that now, or 
start somewhere new."
```

Example:
> "Last time we were talking about your wedding day. You mentioned there might be some photos. We can come back to that now, or start somewhere new."

### 3.3 Multiple paused threads (2–3)

```
"You have a few conversations in progress — [thread 1], 
[thread 2]. Would you like to continue one of those, 
or start something new?"
```

### 3.4 Multiple paused threads (4+)

Don't list them all. Present the most recently active one and offer the browser:

```
"You have several stories in progress. The most recent was 
[thread topic]. Would you like to continue there, pick a 
different thread, or start something new?"
```

### 3.5 Long absence (30+ days)

After a long gap, a soft reset is appropriate. Don't assume the person remembers every detail:

```
"Welcome back. It's been a while. You were working on 
[thread topic] last time — there's still [brief description 
of open obligations]. Would you like to continue, or 
would you rather start fresh?"
```

"Start fresh" does not delete anything. It opens a new thread while leaving the old one accessible.

### 3.6 Return after a difficult conversation

If the last thread was on a difficult topic (classified as such based on the topic type and the thread's conversation history), the continuation offer is gentler and includes a clear alternative:

```
"Last time we were talking about [thread topic]. That was 
a lot to cover. Would you like to continue, or is there 
somewhere lighter you'd rather start today?"
```

---

## 4. What Is Shown in the Continuation Offer

The continuation offer is brief. It shows:
- Thread name
- A one-sentence summary of where the thread was left (auto-generated from thread state)
- One specific open obligation if any (not a list)
- Two or three options: Continue / Start something new / [Other open thread if relevant]

It does not show:
- A full transcript
- A list of every obligation
- A completion percentage
- A streak or reminder count

---

## 5. What Is Not Offered in Continuation

### 5.1 No notifications
LifeBook does not send push notifications, email reminders, or SMS nudges saying "You have unfinished stories." Continuation is offered in-session, not before it. The person comes to LifeBook when they're ready. LifeBook does not summon them.

This is a firm design constraint. Notification-based prompting undermines the sense that LifeBook is patient and on the person's timeline.

*Exception:* If a family member has contributed to a thread (added material, completed an invitation), a single notification may be appropriate — because it's news, not a reminder. This is an exception, not a pattern.

### 5.2 No repeated offers for the same obligation
An obligation that has been declined is not offered again in the same session. The `max_followups` limit ensures it is not offered indefinitely across sessions either. After `max_followups` is exhausted, the obligation moves to `archived_obligations` and is noted but not surfaced.

### 5.3 No implied urgency
Language never implies the thread is expiring, decaying, or that the person is falling behind. There is no "this story is 40% complete." There is no time pressure.

---

## 6. Thread Summary Generation

Each thread carries a `thread_summary` field — a short, human-readable text generated from the thread's current state. This is used in continuation offers and the thread browser.

Summaries are generated (not stored verbatim) at summarization time and may be refreshed when the thread state changes significantly.

Format: 1–2 sentences, past tense, descriptive, no evaluation.

Examples:
- "You shared the story of your wedding in October 1983 — the ceremony, the rain, the four-layer cake. A photo was mentioned but not yet added."
- "Your grandfather's early life in eastern Ukraine, approximate birth around 1902. The exact village name was uncertain."
- "Military service from 1943 to 1946. Your father's return home has not yet been captured."

---

## 7. Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| "You haven't finished your story about X!" | Creates obligation and guilt |
| Listing all pending threads on open | Overwhelming; implies backlog |
| Repeating the same continuation offer every session | Becomes noise; user learns to ignore it |
| Requiring the user to close a thread before starting another | Creates artificial friction |
| "It looks like you were trying to add a photo. Don't forget!" | Patronizing; implies forgetfulness |
| Sending email reminders about incomplete threads | Intrusive; violates the patience principle |
| Counting days since last activity ("You were last here 14 days ago") | Accountability framing; not what this is |

---

## 8. The Invitation Thread

A special case: a family member has been invited to contribute to a thread. The thread moves to `pending_materials` with an obligation representing the pending contribution.

The continuation handling for invitations differs slightly:

- If the invited person has not yet accepted, the obligation is passive — LifeBook does not nag the inviting steward about it
- If the invited person has accepted and contributed, a single notification is appropriate ("Your daughter added to your wedding story")
- If the invited person declined or the invitation expired, the obligation is archived — LifeBook does not dwell on it

---

## 9. Schema Notes

The following fields support thread continuation:

```
ConversationThread.state                — determines whether to offer continuation
ConversationThread.last_activity_at    — basis for dormancy calculation
ConversationThread.dormant_since       — set when thread transitions from active
ConversationThread.pending_obligations — obligation list for continuation offers
ConversationThread.thread_summary      — text used in continuation language
obligation.followup_after              — schedule for re-offer
obligation.followup_count              — track re-offer count
obligation.max_followups               — cap on re-offers
```

---

*THREAD_CONTINUATION_MODEL.md — LifeBook HQ — Conversation Experience v1 — 2026-07-27*
