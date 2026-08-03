Arrival Experience

Objective

Create the first emotional interaction between LifeBook and the Storykeeper.

The opening experience should feel calm, intimate, literary, and completely free of application chrome.

The Storykeeper should immediately feel welcomed — not instructed, not surveyed, not onboarded.

⸻

Governing Principle (2026-08-03)

The threshold lets the visitor experience LifeBook before asking anything of them.

Prior approaches (A: radical simplicity, B: breathing presence, C: written invitation) all asked the visitor to understand the interface before experiencing LifeBook. The canonical threshold reverses this: the experience comes first, the question comes second.

⸻

Canonical Sequence

First visit only. Returning visitors who have completed the threshold in a prior session are recognized and greeted directly — the sequence below does not repeat.

1. Darkness — the world before arrival. No chrome, no instruction, no language.

2. Disturbance — a hairline crack of warm amber light opens vertically at center screen. Interruptible immediately: any key or tap advances.

3. The word "Begin" (or its localized equivalent) appears in the browser's detected language, centered, once the crack animation resolves (~3 seconds). If the visitor prefers reduced motion, Begin appears immediately.

4. Spoken instruction — "Touch the word you understand." — said once in the detected language. Silent devices receive the same visual experience without speech.

5. Language rotation — if no response within ~3.5 seconds, LifeBook rotates through all supported languages. Each language is both displayed and spoken simultaneously (display and speech never diverge). The small globe navigation does not rotate — rotation happens in the main Begin word.

6. Selection — touching the Begin word (or pressing any key) stops rotation, selects the displayed language, and advances.

7. Invitation — "Every story has a beginning. Where would you like to begin?" — spoken and displayed in the selected language. Input activates immediately.

8. Conversation — the Storykeeper's first words are the opening of their story.

⸻

Accessibility Rules

* Reduced motion: all animations collapse to 0.01ms; Begin appears instantly; rotation continues; speech is attempted but never required.
* Silent device: the full experience works without audio. The instruction hint appears visually in the presenting phase.
* Globe: retained as a quiet accessibility fallback (top-right, low opacity). Selecting a language from the globe also advances to the invitation.
* Screen readers: the current word and instruction are announced via aria-live="polite".
* Keyboard: any key press during the animation phase skips to presenting. Any key during presenting or rotating advances with the current language.

⸻

Returning Visitors

Returning Storekeepers who are recognized by the /api/home endpoint are greeted by their Companion immediately. The threshold ceremony does not repeat. Visitors who have previously completed Begin in the same browser session (sessionStorage flag) also skip the threshold.

⸻

Design Rules

* No buttons except the Begin word and the quiet globe.
* No visible forms until the invitation phase.
* No menus, no logos, no chrome during the threshold.
* The LifeBook wordmark appears after the threshold is crossed.
* Black background. Warm amber accent (#d4a574). Warm typography.
* Nothing should move quickly. Every animation should feel intentional.
* The crack is not a logo or a button. It is evidence that something is about to begin.

⸻

Voice

The first voice establishes the relationship.

It must communicate: warmth, trust, patience, intelligence, safety.

Never: robotic, theatrical, over-enthusiastic, sales-like.

⸻

Success Criteria

A first-time Storykeeper should feel:

"I've arrived somewhere safe."

not

"I've opened another app."
