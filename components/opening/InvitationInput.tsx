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
  mode: InputMode;
  value: string;
  isListening: boolean;
  onValueChange: (value: string) => void;
  onModeChange: (mode: InputMode) => void;
  onListeningChange: (listening: boolean) => void;
};

export function InvitationInput({
  pack,
  mode,
  value,
  isListening,
  onValueChange,
  onModeChange,
  onListeningChange,
}: InvitationInputProps) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const [mounted, setMounted] = useState(false);
  const [speechSupported, setSpeechSupported] = useState(false);
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
    if (!isListening) {
      recognitionRef.current?.stop();
      recognitionRef.current = null;
      return;
    }

    const session = startSpeechRecognition(
      pack,
      (transcript) => {
        onValueChange(transcript);
      },
      () => {
        onListeningChange(false);
      },
    );

    recognitionRef.current = session;

    return () => {
      session?.stop();
      recognitionRef.current = null;
    };
  }, [isListening, onListeningChange, onValueChange, pack]);

  function handleTextChange(nextValue: string) {
    if (mode === "voice") {
      onValueChange(nextValue);
      return;
    }

    if (mode === "none") {
      onModeChange("text");
    }

    onValueChange(nextValue);
  }

  function handleMicrophoneToggle() {
    if (!speechSupported || mode === "text") {
      return;
    }

    if (isListening) {
      onListeningChange(false);
      return;
    }

    if (mode === "none") {
      onModeChange("voice");
    }

    onListeningChange(true);
    textareaRef.current?.focus();
  }

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
          placeholder={pack.strings.inputPlaceholder}
          onChange={(event) => handleTextChange(event.target.value)}
          className={[
            "w-full resize-none bg-transparent font-sans text-xl font-extralight leading-relaxed tracking-[0.04em]",
            "text-[var(--lb-fg)] placeholder:text-[var(--lb-fg-muted)] placeholder:opacity-50",
            "border-b border-[var(--lb-border)] pb-4 pr-14",
            "outline-none transition-[border-color] duration-700 focus:border-[var(--lb-fg-soft)]",
          ].join(" ")}
        />
        {mounted && speechSupported && mode !== "text" ? (
          <button
            type="button"
            onClick={handleMicrophoneToggle}
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
