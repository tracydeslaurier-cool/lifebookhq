"use client";

import {
  isSpeechRecognitionSupported,
  startSpeechRecognition,
} from "@/lib/speech";
import type { VoicePack } from "@/lib/voice-packs/types";
import {
  forwardRef,
  useEffect,
  useImperativeHandle,
  useRef,
  useState,
} from "react";

export type InputMode = "none" | "text" | "voice";

export type InvitationInputHandle = {
  focus: () => void;
};

type InvitationInputProps = {
  pack: VoicePack;
  isActive: boolean;
  value: string;
  voicePrefix: string;
  isListening: boolean;
  onValueChange: (value: string) => void;
  onSubmit: () => void;
  onMicToggle: () => void;
  onListeningEnd: () => void;
};

export const InvitationInput = forwardRef<
  InvitationInputHandle,
  InvitationInputProps
>(function InvitationInput(
  {
    pack,
    isActive,
    value,
    voicePrefix,
    isListening,
    onValueChange,
    onSubmit,
    onMicToggle,
    onListeningEnd,
  },
  ref,
) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const [mounted, setMounted] = useState(false);
  const [speechSupported, setSpeechSupported] = useState(false);
  const [isFocused, setIsFocused] = useState(false);
  const recognitionRef = useRef<ReturnType<typeof startSpeechRecognition> | null>(
    null,
  );

  useImperativeHandle(ref, () => ({
    focus: () => {
      const textarea = textareaRef.current;
      if (!textarea) {
        return;
      }

      textarea.focus();
      const length = textarea.value.length;
      textarea.setSelectionRange(length, length);
    },
  }));

  useEffect(() => {
    queueMicrotask(() => {
      setMounted(true);
      setSpeechSupported(isSpeechRecognitionSupported());
    });
  }, []);

  useEffect(() => {
    if (!isActive) {
      return;
    }

    const frame = requestAnimationFrame(() => {
      const textarea = textareaRef.current;
      if (!textarea) {
        return;
      }

      textarea.focus();
      const length = textarea.value.length;
      textarea.setSelectionRange(length, length);
    });

    return () => {
      cancelAnimationFrame(frame);
    };
  }, [isActive]);

  useEffect(() => {
    if (!isListening) {
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
  }, [isListening, onListeningEnd, onValueChange, pack, voicePrefix]);

  function handleKeyDown(event: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key !== "Enter" || event.shiftKey) {
      return;
    }

    event.preventDefault();
    onSubmit();
  }

  const placeholderVisible = !isFocused && value.length === 0;

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
          onChange={(event) => onValueChange(event.target.value)}
          onKeyDown={handleKeyDown}
          onFocus={() => setIsFocused(true)}
          onBlur={() => setIsFocused(false)}
          className={[
            "lb-invitation-input w-full resize-none bg-transparent font-sans text-xl font-extralight leading-relaxed tracking-[0.04em]",
            "text-[var(--lb-fg)] caret-[var(--lb-fg-soft)] placeholder:text-[var(--lb-fg-muted)]",
            "border-b border-[var(--lb-border)] pb-4 pr-14",
            "outline-none transition-[border-color,opacity] duration-700 focus:border-[var(--lb-fg-soft)]",
            placeholderVisible
              ? "placeholder:opacity-50"
              : "placeholder:opacity-0",
          ].join(" ")}
        />
        {value.trim().length > 0 ? (
          <button
            type="button"
            onClick={onSubmit}
            className={[
              "absolute -bottom-12 right-0 font-sans text-sm font-extralight tracking-[0.14em]",
              "text-[var(--lb-fg-soft)] opacity-70 transition-opacity duration-500",
              "hover:opacity-100 focus-visible:opacity-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-[var(--lb-fg-soft)]",
            ].join(" ")}
          >
            {/* TODO(language-engine): culturally authored per pack; Director's
                control language from the layered-completion decision. */}
            Keep this
          </button>
        ) : null}
        {mounted && speechSupported ? (
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
});
