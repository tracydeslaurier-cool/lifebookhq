import type { VoicePack } from "@/lib/voice-packs/types";

type WordmarkProps = {
  pack: VoicePack;
};

export function Wordmark({ pack }: WordmarkProps) {
  return (
    <div
      aria-hidden="true"
      className="pointer-events-none fixed bottom-6 left-6 z-10 font-sans text-sm font-extralight tracking-[0.28em] text-[var(--lb-fg-muted)] opacity-40 select-none"
    >
      {pack.strings.wordmark}
    </div>
  );
}
