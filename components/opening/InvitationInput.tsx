"use client";

import {
  isSpeechRecognitionSupported,
  startSpeechRecognition,
} from "@/lib/speech";
import type { VoicePack } from "@/lib/voice-packs/types";
import { useEffect, useRef, useState } from "react";

export type InputMode = "none" | "text" | "voice";

type InvitationInputProps = {
  pack: VoicePack;
  isActive: boolean;
  isSubmitted: boolean;
  value: string;
  voicePrefix: string;
  isListening: boolean;
  onValueChange: (value: string) => void;
  onSubmit: () => void;
  onMicToggle: () => void;
  onListeningEnd: () => void;
};

export function InvitationInput({
  pack,
  isActive,
  isSubmitted,
  value,
  voicePrefix,
  isListening,
  onValueChange,
  onSubmit,
  onMicToggle,
  onListeningEnd,
}: InvitationInputProps) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const [mounted, setMounted] = useState(false);
  const [speechSupported, setSpeechSupported] = useState(false);
  const [isFocused, setIsFocused] = useState(false);
  const recognitionRef = useRef<ReturnType<typeof startSpeechRecognition> | null>(
    null,
  );

  useEffect(() => {
    queueMicrotask(() => {
      setMounted(true);
      setSpeechSupported(isSpeechRecognitionSupported());
    });
  }, []);

  useEffect(() => {
    if (!isActive || isSubmitted) {
      return;
    }

    textareaRef.current?.focus();
  }, [isActive, isSubmitted]);

  useEffect(() => {
    if (!isListening || isSubmitted) {
      recognitionRef.current?.stop();
      recognitionRef.current = null;
      return;
    }

    const session = startSpeechRecognition(
      pack,
      (result) => {
        onValueChange(result.transcript);
      },
      () => {
        onListeningEnd();
      },
      voicePrefix,
    );

    recognitionRef.current = session;

    return () => {
      session?.stop();
      recognitionRef.current = null;
    };
  }, [
    isListening,
    isSubmitted,
    onListeningEnd,
    onValueChange,
    pack,
    voicePrefix,
  ]);

  function handleKeyDown(event: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key !== "Enter" || event.shiftKey || isSubmitted) {
      return;
    }

    event.preventDefault();
    onSubmit();
  }

  const placeholderVisible = !isFocused && value.length === 0 && !isSubmitted;

  return (
    <div className="mt-14 w-full max-w-xl">
      <label htmlFor="storykeeper-entry" className="sr-only">
        {pack.strings.inputPlaceholder}
      </label>
      <div className="relative">
        <textarea
          ref={textareaRef}
          id="storykeeper-entry"
          value={value}
          rows={3}
          readOnly={isSubmitted}
          placeholder={pack.strings.inputPlaceholder}
          onChange={(event) => onValueChange(event.target.value)}
          onKeyDown={handleKeyDown}
          onFocus={() => setIsFocused(true)}
          onBlur={() => setIsFocused(false)}
          className={[
            "lb-invitation-input w-full resize-none bg-transparent font-sans text-xl font-extralight leading-relaxed tracking-[0.04em]",
            "text-[var(--lb-fg)] placeholder:text-[var(--lb-fg-muted)]",
            "border-b border-[var(--lb-border)] pb-4 pr-14",
            "outline-none transition-[border-color,opacity] duration-700 focus:border-[var(--lb-fg-soft)]",
            placeholderVisible
              ? "placeholder:opacity-50"
              : "placeholder:opacity-0",
            isSubmitted ? "opacity-60" : "opacity-100",
          ].join(" ")}
        />
        {mounted && speechSupported && !isSubmitted ? (
          <button
            type="button"
            onClick={onMicToggle}
            aria-pressed={isListening}
            aria-label={
              isListening
                ? pack.strings.deactivateMicrophone
                : pack.strings.activateMicrophone
            }
            className={[
              "absolute right-0 bottom-4 font-sans text-xs font-extralight tracking-[0.14em]",
              "text-[var(--lb-fg-muted)] transition-all duration-500",
              "hover:text-[var(--lb-fg)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-[var(--lb-fg-soft)]",
              isListening ? "text-[var(--lb-fg)] opacity-100" : "opacity-55",
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
