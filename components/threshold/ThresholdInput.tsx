"use client";

import {
  isSpeechRecognitionSupported,
  startSpeechRecognition,
  type SpeechLifecycle,
} from "@/lib/speech";
import type { VoicePack } from "@/lib/voice-packs/types";
import { useEffect, useRef, useState } from "react";

/**
 * The threshold input. Unlike the main InvitationInput, the voice affordance
 * is ALWAYS shown — even where the browser cannot do speech recognition — so
 * the experiment can observe whether a Storykeeper *reaches* for voice, not
 * merely whether they used it. Where recognition is unavailable, the reach is
 * reported and a gentle note appears; no autofocus, so nothing pushes the
 * Storykeeper toward the keyboard before they choose.
 */

/**
 * Silence after the most recent final speech result that triggers automatic
 * turn completion. Two seconds is a natural conversational pause on macOS;
 * tune upward if testers find premature submission, downward if the
 * conversation feels sluggish.
 */
const SILENCE_THRESHOLD_MS = 2000;

type ThresholdInputProps = {
  pack: VoicePack;
  value: string;
  voicePrefix: string;
  isListening: boolean;
  onValueChange: (value: string) => void;
  /** Receives voice recognition results. Separate from onValueChange so that
   *  voice results do NOT trigger the stop-listening side-effect that
   *  onValueChange (→ handleTranscriptChange) carries for keyboard input. */
  onVoiceResult: (value: string) => void;
  /**
   * Called when the silence timer fires after a final speech result and the
   * Storykeeper has not resumed speaking. The parent is responsible for
   * submitting the transcript exactly once. This is separate from onSubmit so
   * the parent can apply its own duplicate guard independently of the button
   * path.
   */
  onAutoSubmit: () => void;
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
  const recognitionRef = useRef<ReturnType<typeof startSpeechRecognition> | null>(
    null,
  );
  const silenceTimerRef = useRef<number | null>(null);

  /**
   * Duplicate-submit guard at the ThresholdInput level. Set to true when the
   * silence timer fires; reset to false when a new listening session begins
   * (isListening transitions to true). Prevents a racing onend + timer from
   * calling onAutoSubmit twice before the parent's state update propagates.
   */
  const hasAutoSubmittedRef = useRef(false);

  /**
   * Callback refs — hold the latest version of each callback without
   * including them in the recognition useEffect deps. This prevents the
   * recognition session from being torn down and restarted whenever the
   * parent's memoized callbacks change reference (e.g. on every transcript
   * update, which would cause isSubmitting state flicker).
   */
  const onVoiceResultRef = useRef(onVoiceResult);
  const onListeningEndRef = useRef(onListeningEnd);
  const onAutoSubmitRef = useRef(onAutoSubmit);
  useEffect(() => { onVoiceResultRef.current = onVoiceResult; }, [onVoiceResult]);
  useEffect(() => { onListeningEndRef.current = onListeningEnd; }, [onListeningEnd]);
  useEffect(() => { onAutoSubmitRef.current = onAutoSubmit; }, [onAutoSubmit]);

  const [mounted, setMounted] = useState(false);
  const [supported, setSupported] = useState(false);

  useEffect(() => {
    queueMicrotask(() => {
      setMounted(true);
      setSupported(isSpeechRecognitionSupported());
    });
  }, []);

  useEffect(() => {
    // Clear any pending silence timer whenever the listening state changes.
    if (silenceTimerRef.current !== null) {
      window.clearTimeout(silenceTimerRef.current);
      silenceTimerRef.current = null;
    }

    if (!isListening || !supported) {
      recognitionRef.current?.stop();
      recognitionRef.current = null;
      return;
    }

    // Reset the duplicate-submit guard for this new listening session.
    hasAutoSubmittedRef.current = false;

    const session = startSpeechRecognition(
      pack,
      (result) => {
        // Any new result — interim or final — cancels the pending silence timer.
        // The Storykeeper is still speaking.
        if (silenceTimerRef.current !== null) {
          window.clearTimeout(silenceTimerRef.current);
          silenceTimerRef.current = null;
        }

        onVoiceResultRef.current(result.transcript);

        // Only start the silence timer after a FINAL result that has content.
        // Interim results are incomplete phrases; we must not cut the
        // Storykeeper off mid-thought.
        if (result.isFinal && result.transcript.trim().length > 0) {
          silenceTimerRef.current = window.setTimeout(() => {
            silenceTimerRef.current = null;

            // Duplicate-submit guard: if this session already auto-submitted
            // (e.g. a second timer race), do nothing.
            if (hasAutoSubmittedRef.current) return;
            hasAutoSubmittedRef.current = true;

            // Stop recognition before signalling submission so the onend
            // auto-restart loop in speech.ts does not fire a new session.
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
      // Clear the silence timer on cleanup so a pending auto-submit does not
      // fire after the session has been torn down (e.g. user pressed Stop
      // Listening before the threshold elapsed).
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
    // onVoiceResult, onListeningEnd, onAutoSubmit intentionally omitted —
    // they are accessed via refs so the session is not torn down on each
    // parent re-render.
  ]);

  function handleKeyDown(event: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key !== "Enter" || event.shiftKey) return;
    event.preventDefault();
    onSubmit();
  }

  function handleMic() {
    if (!supported) {
      onVoiceUnsupported();
      return;
    }
    onMicToggle();
  }

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
          placeholder={pack.strings.inputPlaceholder}
          onChange={(event) => onValueChange(event.target.value)}
          onKeyDown={handleKeyDown}
          className="lb-invitation-input w-full resize-none border-b border-[var(--lb-border)] bg-transparent pb-4 pr-14 font-sans text-xl font-extralight leading-relaxed tracking-[0.04em] text-[var(--lb-fg)] caret-[var(--lb-fg-soft)] outline-none transition-[border-color,opacity] duration-700 placeholder:text-[var(--lb-fg-muted)] focus:border-[var(--lb-fg-soft)]"
        />
        {value.trim().length > 0 ? (
          <button
            type="button"
            onClick={onSubmit}
            className="absolute -bottom-12 right-0 font-sans text-sm font-extralight tracking-[0.14em] text-[var(--lb-fg-soft)] opacity-70 transition-opacity duration-500 hover:opacity-100 focus-visible:opacity-100 focus-visible:outline-none"
          >
            {/* TODO(language-engine): culturally authored per pack. */}
            Keep this
          </button>
        ) : null}
        {mounted ? (
          <button
            type="button"
            onClick={handleMic}
            aria-pressed={isListening}
            aria-label={
              isListening
                ? pack.strings.deactivateMicrophone
                : pack.strings.activateMicrophone
            }
            className={[
              "absolute right-0 bottom-4 font-sans text-xs font-extralight tracking-[0.14em] transition-all duration-500",
              "hover:text-[var(--lb-fg)] focus-visible:outline-none",
              isListening
                ? "text-[var(--lb-fg)] opacity-100"
                : "text-[var(--lb-fg-muted)] opacity-55",
            ].join(" ")}
          >
            <span
              aria-hidden="true"
              className={[
                "mr-2 inline-block h-2 w-2 rounded-full align-middle transition-colors duration-500",
                isListening
                  ? "bg-[var(--lb-accent)] animate-pulse"
                  : "bg-[var(--lb-fg-muted)] opacity-60",
              ].join(" ")}
            />
            {isListening
              ? pack.strings.deactivateMicrophone
              : pack.strings.activateMicrophone}
          </button>
        ) : null}
      </div>
    </div>
  );
}
