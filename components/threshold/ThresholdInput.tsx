"use client";

import {
  isSpeechRecognitionSupported,
  startSpeechRecognition,
  type SpeechLifecycle,
} from "@/lib/speech";
import type { VoicePack } from "@/lib/voice-packs/types";
import { useEffect, useRef, useState } from "react";

/**
 * The threshold input — redesigned as a conversational voice interface.
 *
 * State machine:
 *
 *   IDLE  ──tap mic──►  LISTENING  ──final result──►  END_OF_TURN
 *     ▲                     ▲                              │
 *     │                     └──── new speech ◄─────────────┘
 *     │                                                    │
 *     │                                           2 s silence
 *     │                                                    │
 *     │                                           auto-submit
 *     │                                                    │
 *     └──────────────────────────────────────────◄─────────┘
 *
 * "Keep This" is removed from the voice flow. Auto-submit is the primary
 * path. Pause and Edit remain as secondary human-intent controls.
 * Text entry is always available as a typed fallback.
 */

/**
 * Milliseconds of silence after the most recent final speech result before
 * automatic turn completion fires. Two seconds covers natural conversational
 * pauses on macOS without feeling sluggish. Increase to 2500 if participants
 * report premature submission on multi-clause sentences.
 */
const SILENCE_THRESHOLD_MS = 2000;

/** Internal voice phase — drives the state label shown to the participant. */
type VoicePhase = "listening" | "end_of_turn";

type ThresholdInputProps = {
  pack: VoicePack;
  value: string;
  voicePrefix: string;
  isListening: boolean;
  onValueChange: (value: string) => void;
  /** Voice recognition results — does not stop the mic (unlike onValueChange). */
  onVoiceResult: (value: string) => void;
  /**
   * Called when the silence timer fires after a final result. The parent
   * submits the transcript and owns the duplicate-submission guard at the
   * server-call level; ThresholdInput owns the guard at the timer level.
   */
  onAutoSubmit: () => void;
  /** Manual submit — Enter key and typed-input fallback only. */
  onSubmit: () => void;
  onMicToggle: () => void;
  onListeningEnd: () => void;
  onVoiceUnsupported: () => void;
  voiceLifecycle?: SpeechLifecycle;
};

export function ThresholdInput({
  pack,
  value,
  voicePrefix,
  isListening,
  onValueChange,
  onVoiceResult,
  onAutoSubmit,
  onSubmit,
  onMicToggle,
  onListeningEnd,
  onVoiceUnsupported,
  voiceLifecycle,
}: ThresholdInputProps) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const recognitionRef = useRef<ReturnType<typeof startSpeechRecognition> | null>(null);
  const silenceTimerRef = useRef<number | null>(null);

  /**
   * Duplicate-submit guard at the ThresholdInput level.
   * Prevents a timer race (e.g. second fire before parent state propagates).
   * Reset when a new listening session begins.
   */
  const hasAutoSubmittedRef = useRef(false);

  /**
   * Whether voice has been used at any point during this mount.
   * Determines whether "paused" state shows voice controls or falls back
   * to plain text mode. Resets on unmount (between turns).
   */
  const hasUsedVoiceRef = useRef(false);

  /**
   * Callback refs — hold the latest version of each callback without
   * including them in the recognition effect deps. Prevents the recognition
   * session from being torn down whenever the parent's memoized callbacks
   * change reference (which happens on every transcript update).
   */
  const onVoiceResultRef = useRef(onVoiceResult);
  const onListeningEndRef = useRef(onListeningEnd);
  const onAutoSubmitRef = useRef(onAutoSubmit);
  useEffect(() => { onVoiceResultRef.current = onVoiceResult; }, [onVoiceResult]);
  useEffect(() => { onListeningEndRef.current = onListeningEnd; }, [onListeningEnd]);
  useEffect(() => { onAutoSubmitRef.current = onAutoSubmit; }, [onAutoSubmit]);

  const [mounted, setMounted] = useState(false);
  const [supported, setSupported] = useState(false);
  const [voicePhase, setVoicePhase] = useState<VoicePhase>("listening");

  /**
   * Edit mode: participant tapped "Edit my words" — shows the textarea so
   * they can correct what was captured. Resets when a new listening session
   * begins (resume speaking).
   */
  const [isEditMode, setIsEditMode] = useState(false);

  useEffect(() => {
    queueMicrotask(() => {
      setMounted(true);
      setSupported(isSpeechRecognitionSupported());
    });
  }, []);

  // Sync voice state with isListening prop.
  useEffect(() => {
    if (isListening) {
      hasUsedVoiceRef.current = true;
      setVoicePhase("listening");
      setIsEditMode(false);
    }
  }, [isListening]);

  // Recognition session — silence timer lives here.
  useEffect(() => {
    // Always clear any pending silence timer when the listening state changes.
    if (silenceTimerRef.current !== null) {
      window.clearTimeout(silenceTimerRef.current);
      silenceTimerRef.current = null;
    }

    if (!isListening || !supported) {
      recognitionRef.current?.stop();
      recognitionRef.current = null;
      return;
    }

    hasAutoSubmittedRef.current = false;

    const session = startSpeechRecognition(
      pack,
      (result) => {
        // Any incoming result cancels the pending silence timer and resets
        // the state label — the participant is still speaking.
        if (silenceTimerRef.current !== null) {
          window.clearTimeout(silenceTimerRef.current);
          silenceTimerRef.current = null;
        }
        setVoicePhase("listening");

        onVoiceResultRef.current(result.transcript);

        // Only evaluate end-of-turn after a FINAL result with content.
        // Interim results are incomplete phrases; do not start the timer on them.
        if (result.isFinal && result.transcript.trim().length > 0) {
          // Show "Listening for anything else…" immediately so the participant
          // sees that we detected the end of their thought.
          setVoicePhase("end_of_turn");

          silenceTimerRef.current = window.setTimeout(() => {
            silenceTimerRef.current = null;

            // Duplicate guard — if a previous path already submitted, stop.
            if (hasAutoSubmittedRef.current) return;
            hasAutoSubmittedRef.current = true;

            // Stop recognition BEFORE calling onAutoSubmit so the onend
            // auto-restart loop in speech.ts does not spawn a new session
            // while the server call is in flight.
            recognitionRef.current?.stop();
            recognitionRef.current = null;

            onAutoSubmitRef.current();
          }, SILENCE_THRESHOLD_MS);
        }
      },
      () => onListeningEndRef.current(),
      voicePrefix,
      voiceLifecycle,
    );
    recognitionRef.current = session;

    return () => {
      // Cancel any pending timer when the session is torn down (e.g. user
      // pressed "Pause conversation" before the threshold elapsed).
      if (silenceTimerRef.current !== null) {
        window.clearTimeout(silenceTimerRef.current);
        silenceTimerRef.current = null;
      }
      session?.stop();
      recognitionRef.current = null;
    };
  }, [
    isListening,
    supported,
    pack,
    voicePrefix,
    voiceLifecycle,
    // onVoiceResult, onListeningEnd, onAutoSubmit — accessed via refs above.
  ]);

  function handleMic() {
    if (!supported) {
      onVoiceUnsupported();
      return;
    }
    onMicToggle();
  }

  function handlePause() {
    // Express human intent: "I want a break." Stops recognition and returns
    // to the paused-voice UI where "Resume speaking" is offered.
    onMicToggle();
  }

  function handleEdit() {
    // Express human intent: "Let me correct what you heard."
    // Stop listening (if active), switch to the textarea, focus it.
    if (isListening) onMicToggle();
    setIsEditMode(true);
    requestAnimationFrame(() => textareaRef.current?.focus());
  }

  function handleKeyDown(event: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key !== "Enter" || event.shiftKey) return;
    event.preventDefault();
    onSubmit();
  }

  // ─── VOICE ACTIVE ────────────────────────────────────────────────────────
  // Listening or detecting end-of-turn. Primary conversational state.
  if (isListening) {
    const stateLabel =
      voicePhase === "end_of_turn"
        ? "Listening for anything else…"
        : "I’m listening.";

    return (
      <div className="mt-12 w-full max-w-xl text-center">
        {/* Live transcript — story forming, not a form field */}
        {value ? (
          <p className="font-serif text-xl font-light leading-relaxed tracking-[0.03em] text-[var(--lb-fg)] sm:text-2xl">
            {value}
          </p>
        ) : null}

        {/* Conversational state label */}
        <p className="mt-6 flex items-center justify-center gap-3 font-sans text-sm font-extralight tracking-[0.10em] text-[var(--lb-fg-muted)]">
          <span
            aria-hidden="true"
            className="inline-block h-2 w-2 flex-shrink-0 rounded-full bg-[var(--lb-accent)] animate-pulse"
          />
          {stateLabel}
        </p>

        {/* Secondary human-intent controls — unobtrusive */}
        <div className="mt-5 flex items-center justify-center gap-6">
          <button
            type="button"
            onClick={handlePause}
            className="font-sans text-xs font-extralight tracking-[0.10em] text-[var(--lb-fg-muted)] opacity-50 transition-opacity duration-300 hover:opacity-90 focus-visible:outline-none focus-visible:opacity-90"
          >
            Pause conversation
          </button>
          {value.trim().length > 0 ? (
            <button
              type="button"
              onClick={handleEdit}
              className="font-sans text-xs font-extralight tracking-[0.10em] text-[var(--lb-fg-muted)] opacity-50 transition-opacity duration-300 hover:opacity-90 focus-visible:outline-none focus-visible:opacity-90"
            >
              Edit my words
            </button>
          ) : null}
        </div>
      </div>
    );
  }

  // ─── VOICE PAUSED ────────────────────────────────────────────────────────
  // Not listening, transcript exists, voice was used, not in edit mode.
  // Participant took a break; transcript is preserved as a story fragment.
  if (value.trim().length > 0 && hasUsedVoiceRef.current && !isEditMode) {
    return (
      <div className="mt-12 w-full max-w-xl text-center">
        {/* Frozen transcript — same story-forming treatment */}
        <p className="font-serif text-xl font-light leading-relaxed tracking-[0.03em] text-[var(--lb-fg)] sm:text-2xl">
          {value}
        </p>

        {/* Resume and edit controls */}
        <div className="mt-6 flex items-center justify-center gap-6">
          {mounted && supported ? (
            <button
              type="button"
              onClick={handleMic}
              className="font-sans text-xs font-extralight tracking-[0.10em] text-[var(--lb-fg-muted)] opacity-60 transition-opacity duration-300 hover:opacity-100 focus-visible:outline-none focus-visible:opacity-100"
            >
              <span
                aria-hidden="true"
                className="mr-2 inline-block h-2 w-2 rounded-full bg-[var(--lb-fg-muted)] opacity-60 align-middle"
              />
              Resume speaking
            </button>
          ) : null}
          <button
            type="button"
            onClick={handleEdit}
            className="font-sans text-xs font-extralight tracking-[0.10em] text-[var(--lb-fg-muted)] opacity-50 transition-opacity duration-300 hover:opacity-90 focus-visible:outline-none focus-visible:opacity-90"
          >
            Edit my words
          </button>
        </div>
      </div>
    );
  }

  // ─── TEXT / EDIT MODE ────────────────────────────────────────────────────
  // Idle (never used voice), or participant chose to edit / type instead.
  // Textarea is always accessible; Enter submits.
  const placeholderText = isEditMode
    ? "Correct your words…"
    : pack.strings.inputPlaceholder;

  return (
    <div className="mt-12 w-full max-w-xl">
      <label htmlFor="threshold-entry" className="sr-only">
        {pack.strings.inputPlaceholder}
      </label>
      <div className="relative">
        <textarea
          ref={textareaRef}
          id="threshold-entry"
          value={value}
          rows={3}
          placeholder={placeholderText}
          onChange={(event) => onValueChange(event.target.value)}
          onKeyDown={handleKeyDown}
          className="lb-invitation-input w-full resize-none border-b border-[var(--lb-border)] bg-transparent pb-4 pr-20 font-sans text-xl font-extralight leading-relaxed tracking-[0.04em] text-[var(--lb-fg)] caret-[var(--lb-fg-soft)] outline-none transition-[border-color,opacity] duration-700 placeholder:text-[var(--lb-fg-muted)] focus:border-[var(--lb-fg-soft)]"
        />

        {/* Mic affordance — "Begin speaking" (idle) or "Resume speaking" (edit) */}
        {mounted ? (
          <button
            type="button"
            onClick={handleMic}
            aria-label={pack.strings.activateMicrophone}
            className="absolute right-0 bottom-4 font-sans text-xs font-extralight tracking-[0.14em] text-[var(--lb-fg-muted)] opacity-55 transition-all duration-500 hover:text-[var(--lb-fg)] hover:opacity-100 focus-visible:outline-none focus-visible:opacity-100"
          >
            <span
              aria-hidden="true"
              className="mr-2 inline-block h-2 w-2 rounded-full bg-[var(--lb-fg-muted)] opacity-60 align-middle"
            />
            {isEditMode && hasUsedVoiceRef.current
              ? "Resume speaking"
              : "Begin speaking"}
          </button>
        ) : null}
      </div>

      {/* Subtle submit hint — keyboard-literate users know Enter; show for others */}
      {value.trim().length > 0 ? (
        <p className="mt-3 text-right font-sans text-[10px] font-extralight tracking-[0.10em] text-[var(--lb-fg-muted)] opacity-35">
          Press Enter to continue
        </p>
      ) : null}
    </div>
  );
}
