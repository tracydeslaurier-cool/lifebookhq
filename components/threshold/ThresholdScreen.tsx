"use client";

/**
 * ThresholdScreen — the universal first-visit entrance to LifeBook.
 *
 * Design decision (2026-08-03): Options A, B, and C are no longer competing
 * alternatives. This component is the canonical threshold experience for all
 * first-time visitors. It embodies the governing principle:
 *
 *   A and B asked the visitor to understand the interface before experiencing
 *   LifeBook. The threshold lets the visitor experience LifeBook before
 *   asking anything of them.
 *
 * Sequence:
 *   1. Darkness — the world before arrival.
 *   2. Disturbance — a crack of warm light opens. Interruptible immediately.
 *   3. The word "Begin" (or its equivalent) appears in the detected language.
 *   4. Spoken cue: "Touch the word you understand." (once, detected language).
 *   5. If no response within ROTATION_DELAY_MS: rotate through all supported
 *      languages. Display and speech always match — never shown Ukrainian
 *      while speaking English.
 *   6. Touching any word stops the rotation, selects that language, and
 *      advances into LifeBook.
 *   7. Globe: retained as a quiet accessibility fallback, not primary discovery.
 *   8. Reduced-motion / silent: the experience is fully accessible without
 *      animation or sound. The Begin word appears immediately; rotation
 *      continues; speech is attempted but never required.
 *
 * This component calls onEnter(packId) when the visitor selects a language.
 * OpeningExperience then owns everything after — invitation, conversation,
 * homecoming for returning visitors.
 */

import { GlobeOverlay } from "@/components/threshold/GlobeOverlay";
import { getAllVoicePacks } from "@/lib/voice-packs";
import type { VoicePack, VoicePackId } from "@/lib/voice-packs/types";
import { cancelSpeech, speakText } from "@/lib/speech";
import { storeVoicePackId } from "@/lib/language";
import { useCallback, useEffect, useRef, useState } from "react";

/** How long to wait before beginning language rotation after Begin appears. */
const ROTATION_DELAY_MS = 3500;

/** How long each language is displayed during rotation. */
const ROTATION_INTERVAL_MS = 2600;

/** How long the crack/light animation runs before Begin becomes visible. */
const ANIMATION_DURATION_MS = 3000;

function prefersReducedMotion(): boolean {
  if (typeof window === "undefined") return false;
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

/**
 * Build the rotation sequence: all packs except the detected language,
 * drawn from getAllVoicePacks() so it tracks the live configuration.
 * The detected language is already visible at the start — skip it.
 */
function buildRotationSequence(detectedId: VoicePackId): VoicePack[] {
  return getAllVoicePacks().filter((p) => p.id !== detectedId);
}

type ThresholdPhase =
  | "animating"   // crack/light animation is running
  | "presenting"  // Begin word is visible, awaiting tap or rotation timer
  | "rotating";   // rotating through supported languages

type ThresholdScreenProps = {
  detectedPack: VoicePack;
  onEnter: (selectedPackId: VoicePackId) => void;
};

export function ThresholdScreen({ detectedPack, onEnter }: ThresholdScreenProps) {
  const reduced = prefersReducedMotion();

  const [phase, setPhase] = useState<ThresholdPhase>(
    reduced ? "presenting" : "animating",
  );
  const [beginVisible, setBeginVisible] = useState(reduced);
  const [currentPack, setCurrentPack] = useState<VoicePack>(detectedPack);
  const [globeOpen, setGlobeOpen] = useState(false);

  // Guards
  const enteredRef = useRef(false);
  const spokenInstructionRef = useRef(false);
  const rotationTimerRef = useRef<number | null>(null);

  /** Complete the threshold — select language and advance. Idempotent. */
  const enter = useCallback(
    (packId: VoicePackId) => {
      if (enteredRef.current) return;
      enteredRef.current = true;
      if (rotationTimerRef.current !== null) {
        window.clearTimeout(rotationTimerRef.current);
        rotationTimerRef.current = null;
      }
      cancelSpeech();
      storeVoicePackId(packId);
      onEnter(packId);
    },
    [onEnter],
  );

  // Phase 1 → 2: animation completes, Begin word appears.
  useEffect(() => {
    if (phase !== "animating") return;
    const timer = window.setTimeout(() => {
      setBeginVisible(true);
      setPhase("presenting");
    }, ANIMATION_DURATION_MS);
    return () => window.clearTimeout(timer);
  }, [phase]);

  // Phase 2: speak the instruction once, then start rotation timer.
  useEffect(() => {
    if (phase !== "presenting") return;

    if (!spokenInstructionRef.current) {
      spokenInstructionRef.current = true;
      // Speak "Touch the word you understand." once, in the detected language.
      // TTS may be unavailable on some devices — never let it crash the UI.
      try { speakText(detectedPack.strings.touchWordYouUnderstand, detectedPack); } catch { /* silent */ }
    }

    const rotationStart = window.setTimeout(() => {
      setPhase("rotating");
    }, ROTATION_DELAY_MS);

    return () => window.clearTimeout(rotationStart);
  }, [phase, detectedPack]);

  // Phase 3: rotate through supported languages; display and speech always match.
  useEffect(() => {
    if (phase !== "rotating") return;
    const sequence = buildRotationSequence(detectedPack.id);
    if (sequence.length === 0) return;

    let index = 0;

    const tick = () => {
      if (enteredRef.current) return;
      const pack = sequence[index % sequence.length];
      index += 1;
      setCurrentPack(pack);
      // Short spoken cue only — "Begin" in that language.
      // Display and speech are set in the same synchronous tick.
      // TTS may be unavailable on some devices — never let it crash the UI.
      try { speakText(pack.strings.begin, pack); } catch { /* silent */ }
      rotationTimerRef.current = window.setTimeout(tick, ROTATION_INTERVAL_MS);
    };

    // First tick immediately — ROTATION_DELAY_MS has already elapsed.
    tick();

    return () => {
      if (rotationTimerRef.current !== null) {
        window.clearTimeout(rotationTimerRef.current);
        rotationTimerRef.current = null;
      }
    };
    // phase and detectedPack.id are stable for the lifetime of this effect.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase]);

  // Cleanup on unmount.
  useEffect(() => {
    return () => {
      if (rotationTimerRef.current !== null) {
        window.clearTimeout(rotationTimerRef.current);
      }
      cancelSpeech();
    };
  }, []);

  /** Any interaction with the Begin word selects the currently displayed language. */
  function handleBeginActivate() {
    enter(currentPack.id);
  }

  /** Globe is the quiet accessibility fallback — selecting here also enters. */
  function handleGlobeSelect(id: VoicePackId) {
    setGlobeOpen(false);
    enter(id);
  }

  /**
   * Keyboard: any key press while on the threshold interrupts the animation /
   * rotation and advances with the currently displayed language.
   * (Escape is reserved for closing the globe overlay.)
   */
  function handleKeyDown(event: React.KeyboardEvent) {
    if (globeOpen) return;
    if (event.key === "Escape") return;
    if (phase === "animating") {
      // Skip animation immediately.
      setBeginVisible(true);
      setPhase("presenting");
      return;
    }
    // presenting or rotating: advance.
    handleBeginActivate();
  }

  return (
    // biome-ignore lint/a11y/noNoninteractiveTabindex: wrapper captures keyboard
    // interaction so keyboard users can interrupt the animation without a mouse.
    <div
      className="relative min-h-screen overflow-hidden bg-[var(--lb-bg)] text-[var(--lb-fg)]"
      onKeyDown={handleKeyDown}
      // biome-ignore lint/a11y/noNoninteractiveTabindex: intentional
      tabIndex={0}
    >
      {/* ── Crack / light animation overlay ────────────────────────────────── */}
      {/* Collapsed to 0.01ms by prefers-reduced-motion in globals.css. */}
      {!reduced && phase === "animating" ? (
        <div aria-hidden="true" className="pointer-events-none fixed inset-0 z-40">
          {/* Dark veil that lifts as the crack opens */}
          <div className="lb-threshold-veil absolute inset-0 bg-[var(--lb-bg)]" />
          {/* The crack itself: a warm vertical hairline */}
          <div className="lb-threshold-crack absolute left-1/2 top-0 -translate-x-1/2" />
          {/* Warm bloom spreading from the crack's origin */}
          <div className="lb-threshold-bloom absolute inset-0 flex items-center justify-center">
            <div className="lb-threshold-bloom-inner" />
          </div>
        </div>
      ) : null}

      {/* ── Globe: quiet fallback ────────────────────────────────────────── */}
      <button
        type="button"
        onClick={() => setGlobeOpen(true)}
        aria-label="Choose a language"
        className="fixed top-6 right-6 z-30 text-[var(--lb-fg-muted)] opacity-55 transition-opacity duration-500 hover:opacity-90 focus-visible:opacity-100 focus-visible:outline-none"
      >
        <span aria-hidden="true" className="text-xl">🌐</span>
      </button>

      {/* ── Accessibility: announce current word to screen readers ──────── */}
      <p className="sr-only" aria-live="polite" aria-atomic="true">
        {phase === "presenting" || phase === "rotating"
          ? currentPack.strings.touchWordYouUnderstand
          : null}
      </p>

      {/* ── The Begin word ─────────────────────────────────────────────── */}
      <main className="flex min-h-screen items-center justify-center px-6">
        <button
          type="button"
          onClick={handleBeginActivate}
          lang={currentPack.locale}
          aria-label={currentPack.strings.touchWordYouUnderstand}
          className={[
            "font-sans text-4xl font-extralight tracking-[0.14em] sm:text-5xl md:text-6xl",
            "text-[var(--lb-fg)] transition-opacity duration-700",
            "hover:opacity-75 focus-visible:outline focus-visible:outline-2",
            "focus-visible:outline-offset-8 focus-visible:outline-[var(--lb-fg-soft)]",
            beginVisible ? "opacity-100" : "pointer-events-none opacity-0",
          ]
            .filter(Boolean)
            .join(" ")}
        >
          {currentPack.strings.begin}
        </button>
      </main>

      {/* ── Instruction hint (presenting phase only, detected language) ─── */}
      {phase === "presenting" ? (
        <p
          aria-hidden="true"
          className="fixed bottom-16 left-1/2 -translate-x-1/2 whitespace-nowrap text-center font-sans text-sm font-extralight tracking-[0.10em] text-[var(--lb-fg-muted)] opacity-40 transition-opacity duration-700"
        >
          {detectedPack.strings.touchWordYouUnderstand}
        </p>
      ) : null}

      <GlobeOverlay
        open={globeOpen}
        onClose={() => setGlobeOpen(false)}
        onSelect={handleGlobeSelect}
      />
    </div>
  );
}
