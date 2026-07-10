"use client";

import { getAllVoicePacks } from "@/lib/voice-packs";
import type { VoicePack, VoicePackId } from "@/lib/voice-packs/types";

type LanguageSelectorProps = {
  selectedId: VoicePackId;
  onSelect: (id: VoicePackId) => void;
};

const voicePacks = getAllVoicePacks();

export function LanguageSelector({
  selectedId,
  onSelect,
}: LanguageSelectorProps) {
  return (
    <nav
      aria-label="Language"
      className="fixed top-6 right-6 z-20 flex flex-wrap items-center justify-end gap-x-3 gap-y-1"
    >
      {voicePacks.map((pack: VoicePack) => {
        const isSelected = pack.id === selectedId;
        const isPlaceholder = pack.status === "placeholder";

        return (
          <button
            key={pack.id}
            type="button"
            onClick={() => onSelect(pack.id)}
            aria-current={isSelected ? "true" : undefined}
            className={[
              "font-sans text-xs font-extralight tracking-[0.12em] transition-colors duration-500",
              "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-[var(--lb-fg-soft)]",
              isSelected
                ? "text-[var(--lb-fg)] opacity-90"
                : "text-[var(--lb-fg-muted)] opacity-45 hover:opacity-70",
              isPlaceholder ? "italic" : "",
            ]
              .filter(Boolean)
              .join(" ")}
            title={
              isPlaceholder
                ? `${pack.nativeName} — pending native review`
                : pack.nativeName
            }
          >
            {pack.nativeName}
          </button>
        );
      })}
    </nav>
  );
}
