"use client";

import { getAllVoicePacks } from "@/lib/voice-packs";
import type { VoicePackId } from "@/lib/voice-packs/types";
import { useEffect } from "react";

/**
 * The globe is not the primary path — it is a quiet accessibility door.
 * Selecting it does not navigate to Settings; the scene softly blurs and words
 * for "let's talk" drift upward in many languages. No flags, no countries, no
 * hierarchy. Choosing one dissolves the overlay and localizes — as if the
 * Companion simply kept waiting.
 *
 * The eight phrases that map to a voice pack are selectable; the rest drift as
 * atmosphere until the language-engine grows packs for them.
 */

type Phrase = { text: string; packId?: VoicePackId };

const PHRASES: Phrase[] = [
  { text: "Let's talk", packId: "en" },
  { text: "Parlons", packId: "fr" },
  { text: "Поговорімо", packId: "uk" },
  { text: "Давайте поговорим", packId: "ru" },
  { text: "Reden wir", packId: "de" },
  { text: "Hablemos", packId: "es" },
  { text: "Porozmawiajmy", packId: "pl" },
  { text: "Parliamo", packId: "it" },
  { text: "لنتحدث" },
  { text: "चलिए बात करते हैं" },
  { text: "ਆਓ ਗੱਲ ਕਰੀਏ" },
  { text: "Vamos conversar" },
  { text: "让我们聊聊" },
  { text: "話しましょう" },
];

const supported = new Set<VoicePackId>(getAllVoicePacks().map((pack) => pack.id));

type GlobeOverlayProps = {
  open: boolean;
  onClose: () => void;
  onSelect: (id: VoicePackId) => void;
};

export function GlobeOverlay({ open, onClose, onSelect }: GlobeOverlayProps) {
  useEffect(() => {
    if (!open) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Choose a language"
      onClick={onClose}
      className="fixed inset-0 z-50 flex flex-wrap items-center justify-center gap-x-10 gap-y-8 overflow-hidden px-8 backdrop-blur-xl"
      style={{ backgroundColor: "rgba(11, 10, 9, 0.72)" }}
    >
      {PHRASES.map((phrase, i) => {
        const selectable = phrase.packId !== undefined && supported.has(phrase.packId);
        const style = {
          animationDelay: `${(i % 7) * 0.4}s`,
          animationDuration: `${9 + (i % 5) * 1.5}s`,
        } as React.CSSProperties;

        if (selectable) {
          return (
            <button
              key={phrase.text}
              type="button"
              onClick={(event) => {
                event.stopPropagation();
                onSelect(phrase.packId as VoicePackId);
              }}
              style={style}
              className="lb-globe-word font-serif text-2xl font-light tracking-[0.06em] text-[var(--lb-fg-soft)] opacity-80 transition-opacity duration-500 hover:opacity-100 focus-visible:opacity-100 focus-visible:outline-none sm:text-3xl"
            >
              {phrase.text}
            </button>
          );
        }

        return (
          <span
            key={phrase.text}
            aria-hidden="true"
            style={style}
            className="lb-globe-word pointer-events-none select-none font-serif text-2xl font-light tracking-[0.06em] text-[var(--lb-fg-muted)] opacity-35 sm:text-3xl"
          >
            {phrase.text}
          </span>
        );
      })}
    </div>
  );
}
