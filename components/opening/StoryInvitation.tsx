"use client";

import type { VoicePack } from "@/lib/voice-packs/types";
import { useState } from "react";

/**
 * The quiet invitation: after the first exchange, the Storykeeper may let
 * their story find them again. Framed as safekeeping, never registration —
 * one line of text until touched, never demanding, easily ignored.
 *
 * NOTE: copy is English-only for now — culturally authored strings for the
 * other packs come with the language-engine directive. The component takes
 * the pack so that wiring is already in place.
 */

type Phase = "quiet" | "asking" | "sent";

export function StoryInvitation({ pack }: { pack: VoicePack }) {
  const [phase, setPhase] = useState<Phase>("quiet");
  const [email, setEmail] = useState("");
  void pack; // reserved for culturally authored copy (language-engine)

  if (phase === "sent") {
    return (
      <p
        className="mt-14 font-sans text-base font-extralight tracking-[0.05em] text-[var(--lb-fg-soft)] opacity-80 transition-opacity duration-1000"
        aria-live="polite"
      >
        A doorway is on its way to your email. It stays open a little while.
      </p>
    );
  }

  if (phase === "quiet") {
    return (
      <button
        type="button"
        onClick={() => setPhase("asking")}
        className="mt-14 font-sans text-base font-extralight tracking-[0.05em] text-[var(--lb-fg-soft)] opacity-60 transition-opacity duration-700 hover:opacity-100 focus-visible:opacity-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-8 focus-visible:outline-[var(--lb-fg-soft)]"
      >
        Would you like your story to be able to find you again?
      </button>
    );
  }

  return (
    <form
      className="mt-14 flex flex-col items-center"
      onSubmit={(event) => {
        event.preventDefault();
        const trimmed = email.trim();
        if (!trimmed.includes("@")) return;
        setPhase("sent");
        void fetch("/api/identity/begin", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ email: trimmed }),
        }).catch(() => {
          // The answer on screen stays calm; delivery issues surface in the
          // server log. A doorway can always be asked for again.
        });
      }}
    >
      <label
        htmlFor="story-email"
        className="font-sans text-base font-extralight tracking-[0.05em] text-[var(--lb-fg-soft)]"
      >
        Where should your story look for you?
      </label>
      <input
        id="story-email"
        type="email"
        inputMode="email"
        autoComplete="email"
        value={email}
        onChange={(event) => setEmail(event.target.value)}
        className="mt-4 w-full max-w-sm border-b border-[var(--lb-fg-soft)] bg-transparent pb-2 text-center font-sans text-lg font-extralight tracking-[0.04em] text-[var(--lb-fg)] outline-none placeholder:text-[var(--lb-fg-soft)] placeholder:opacity-50"
        placeholder="your email"
        autoFocus
      />
      <button
        type="submit"
        className="mt-6 font-sans text-base font-extralight tracking-[0.1em] text-[var(--lb-fg-soft)] transition-opacity duration-500 hover:opacity-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-8 focus-visible:outline-[var(--lb-fg-soft)]"
      >
        Send a doorway
      </button>
    </form>
  );
}
