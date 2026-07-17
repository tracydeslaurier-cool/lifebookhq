"use client";

import {
  isSpeechRecognitionSupported,
  startSpeechRecognition,
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

type ThresholdInputProps = {
  pack: VoicePack;
  value: string;
  voicePrefix: string;
  isListening: boolean;
  onValueChange: (value: string) => void;
  onSubmit: () => void;
  onMicToggle: () => void;
  onListeningEnd: () => void;
  onVoiceUnsupported: () => void;
};

export function ThresholdInput({
  pack,
  value,
  voicePrefix,
  isListening,
  onValueChange,
  onSubmit,
  onMicToggle,
  onListeningEnd,
  onVoiceUnsupported,
}: ThresholdInputProps) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const recognitionRef = useRef<ReturnType<typeof startSpeechRecognition> | null>(
    null,
  );
  const [mounted, setMounted] = useState(false);
  const [supported, setSupported] = useState(false);

  useEffect(() => {
    queueMicrotask(() => {
      setMounted(true);
      setSupported(isSpeechRecognitionSupported());
    });
  }, []);

  useEffect(() => {
    if (!isListening || !supported) {
      recognitionRef.current?.stop();
      recognitionRef.current = null;
      return;
    }

    const session = startSpeechRecognition(
      pack,
      (result) => onValueChange(result.transcript),
      () => onListeningEnd(),
      voicePrefix,
    );
    recognitionRef.current = session;

    return () => {
      session?.stop();
      recognitionRef.current = null;
    };
  }, [isListening, supported, onListeningEnd, onValueChange, pack, voicePrefix]);

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
