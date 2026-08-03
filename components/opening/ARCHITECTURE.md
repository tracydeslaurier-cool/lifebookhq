# Opening Experience Architecture

*`components/opening/` — the root product experience rendered at `/`.*

## Overview

The opening experience is the only entry point for first-time Storekeepers. It owns the complete flow from first arrival to first conversation. The flow has three distinct phases, each with a clear ownership boundary.

```
First visit:   ThresholdScreen  →  Invitation  →  Conversation
Returning:     Homecoming check →  Invitation  →  Conversation
```

---

## Phase 1 — Threshold (ThresholdScreen)

**Owner:** `components/threshold/ThresholdScreen.tsx`

**Rendered by:** `OpeningExperience` when `homecoming !== null && !homecoming.recognized && !sessionBeginCompleted`

`OpeningExperience` holds the darkness while the homecoming check is in flight (`homecoming === null`). Once the check resolves and the visitor is not recognized, `ThresholdScreen` takes the full screen.

### ThresholdScreen responsibilities

- Animate the crack/light sequence (unless `prefers-reduced-motion`)
- Present the `begin` string in the detected browser language
- Speak "Touch the word you understand." once
- Rotate through all supported voice packs after `ROTATION_DELAY_MS`
- Keep display and speech synchronized at all times (same pack, same tick)
- Call `onEnter(packId)` when the visitor selects a language
- Handle keyboard, touch, and globe (GlobeOverlay) interactions
- Own all speech before the threshold is crossed

### ThresholdScreen does NOT own

- The conversation session — `beginArrival()` is called by `OpeningExperience` after `onEnter`
- Post-threshold UI

---

## Phase 2 — Invitation

**Owner:** `OpeningExperience` (`handleThresholdEnter` and the invitation render block)

When `ThresholdScreen` calls `onEnter(packId)`:

1. The selected pack is adopted (`setSelectedPackId`, `storeVoicePackId`, `document.documentElement.lang`)
2. `markBeginCompleted()` writes the session flag that prevents threshold repetition
3. `setHasBegun(true)` unmounts `ThresholdScreen` and renders the invitation
4. `beginArrival()` opens the anonymous conversation session
5. `storyInvitation` is spoken and displayed as the `h1`
6. Input focus is requested via `requestAnimationFrame`

Returning visitors (recognized or `sessionBeginCompleted`) skip directly to this phase. They reach `beginArrival()` via the `useEffect` that fires when `isInvitation` is true.

---

## Phase 3 — Conversation

**Owner:** `useFirstConversation` hook + `InvitationInput` / `CompanionResponse` components

The conversation hook manages the full state machine: transcript, voice prefix, submitted thought, companion reply, input activation. `OpeningExperience` wires the hook's callbacks to the UI and speaks companion replies through the `speakText` pipeline.

---

## Key state

| State | Where | Meaning |
|---|---|---|
| `homecoming` | `OpeningExperience` | `null` = checking; `{ recognized }` = resolved |
| `hasBegun` | `OpeningExperience` | threshold crossed this session |
| `sessionBeginCompleted` | sessionStorage | threshold crossed in any prior session |
| `selectedPackId` | `OpeningExperience` | overrides detected pack after selection |
| `phase` | `ThresholdScreen` | `animating` → `presenting` → `rotating` |
| `currentPack` | `ThresholdScreen` | currently displayed + spoken language |

---

## Homecoming detection

`/api/home` is fetched once on mount. If `recognized: true`, the visitor is a known Storykeeper: `markBeginCompleted()` and `setHasBegun(true)` are called immediately, and the threshold is never shown. The greeting (if any) is spoken.

If the fetch fails, homecoming defaults to `{ recognized: false }` and the threshold proceeds normally.

---

## Voice pack source of truth

`ThresholdScreen` draws its rotation sequence from `getAllVoicePacks()` (filtered by detected language). Any new voice pack added to `lib/voice-packs/index.ts` automatically participates in the threshold rotation without changes to `ThresholdScreen`.

---

## Accessibility

- `prefers-reduced-motion`: animation phase is skipped; Begin appears immediately; rotation continues
- Silent device: full experience works without speech; instruction appears visually
- Screen readers: `aria-live="polite"` region announces the current language
- Keyboard: any key skips animation or advances with current language (Escape reserved for GlobeOverlay)
- Globe: quiet fallback at top-right, accessible at all times during the threshold

---

## Files

```
components/
  opening/
    OpeningExperience.tsx   — root orchestrator: homecoming, threshold, invitation, conversation
    CompanionResponse.tsx   — companion reply display
    InvitationInput.tsx     — text + voice input after threshold
    LanguageSelector.tsx    — post-threshold language switch
    StoryInvitation.tsx     — "Tell me another story" re-invite
    Wordmark.tsx            — LifeBook mark (appears after threshold)
    ARCHITECTURE.md         — this file
  threshold/
    ThresholdScreen.tsx     — canonical first-visit threshold experience
    ThresholdExperience.tsx — A/B/C experiment archive (instrumented variants)
    ThresholdInput.tsx      — voice/text input used by experiment variants
    GlobeOverlay.tsx        — language picker overlay (shared)
```
