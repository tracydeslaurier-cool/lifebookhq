"use client";

import { InvitationInput, type InputMode } from "@/components/opening/InvitationInput";
import { LanguageSelector } from "@/components/opening/LanguageSelector";
import { Wordmark } from "@/components/opening/Wordmark";
import {
  ARRIVAL_SPOKEN_KEY,
  detectBrowserVoicePack,
  hasSpokenArrival,
  markArrivalSpoken,
  readStoredVoicePackId,
  storeVoicePackId,
} from "@/lib/language";
import { cancelSpeech, speakText } from "@/lib/speech";
import { getVoicePack } from "@/lib/voice-packs";
import type { VoicePackId } from "@/lib/voice-packs/types";
import { useEffect, useRef, useState, useSyncExternalStore } from "react";

type Phase = "welcome" | "invitation";

function getDetectedPackId(): VoicePackId {
  const storedId = readStoredVoicePackId();
  return storedId ?? detectBrowserVoicePack().id;
}

function subscribeToPackId() {
  return () => {};
}

export function OpeningExperience() {
  const detectedPackId = useSyncExternalStore(
    subscribeToPackId,
    getDetectedPackId,
    () => "en" as VoicePackId,
  );
  const [selectedPackId, setSelectedPackId] = useState<VoicePackId | null>(
    null,
  );
  const pack = getVoicePack(selectedPackId ?? detectedPackId);
  const [phase, setPhase] = useState<Phase>("welcome");
  const [inputMode, setInputMode] = useState<InputMode>("none");
  const [entry, setEntry] = useState("");
  const [isListening, setIsListening] = useState(false);
  const hasInitializedSpeech = useRef(false);

  useEffect(() => {
    document.documentElement.lang = pack.locale;
  }, [pack.locale]);

  useEffect(() => {
    if (hasInitializedSpeech.current) {
      return;
    }

    hasInitializedSpeech.current = true;

    if (!hasSpokenArrival()) {
      speakText(pack.strings.touchWordYouUnderstand, pack, () => {
        markArrivalSpoken();
      });
    }
  }, [pack]);

  useEffect(() => {
    return () => {
      cancelSpeech();
    };
  }, []);

  function handleLanguageSelect(id: VoicePackId) {
    const nextPack = getVoicePack(id);
    setSelectedPackId(id);
    storeVoicePackId(id);
    document.documentElement.lang = nextPack.locale;

    if (phase === "welcome") {
      cancelSpeech();
      speakText(nextPack.strings.touchWordYouUnderstand, nextPack, () => {
        sessionStorage.setItem(ARRIVAL_SPOKEN_KEY, "1");
      });
    }
  }

  function handleBegin() {
    setPhase("invitation");
    cancelSpeech();
    speakText(pack.strings.whatsOnYourMind, pack);
  }

  return (
    <div className="relative min-h-screen overflow-hidden bg-[var(--lb-bg)] text-[var(--lb-fg)]">
      <LanguageSelector
        selectedId={pack.id}
        onSelect={handleLanguageSelect}
      />
      <Wordmark pack={pack} />

      <main className="flex min-h-screen items-center justify-center px-6 py-20">
        <div className="relative h-[min(70vh,32rem)] w-full max-w-3xl">
          <div
            className={[
              "absolute inset-0 flex items-center justify-center transition-all duration-[1200ms] ease-[cubic-bezier(0.22,1,0.36,1)]",
              phase === "welcome"
                ? "translate-y-0 opacity-100"
                : "pointer-events-none -translate-y-3 opacity-0",
            ].join(" ")}
          >
            <button
              type="button"
              onClick={handleBegin}
              className={[
                "font-sans text-4xl font-extralight tracking-[0.14em] sm:text-5xl md:text-6xl",
                "text-[var(--lb-fg)] transition-opacity duration-700 hover:opacity-75",
                "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-8 focus-visible:outline-[var(--lb-fg-soft)]",
              ].join(" ")}
            >
              {pack.strings.begin}
            </button>
          </div>

          <div
            className={[
              "absolute inset-0 flex flex-col items-center justify-center text-center transition-all duration-[1400ms] ease-[cubic-bezier(0.22,1,0.36,1)]",
              phase === "invitation"
                ? "translate-y-0 opacity-100"
                : "pointer-events-none translate-y-4 opacity-0",
            ].join(" ")}
            aria-hidden={phase !== "invitation"}
          >
            <p className="font-sans text-2xl font-extralight leading-relaxed tracking-[0.06em] text-[var(--lb-fg-soft)] sm:text-3xl md:text-4xl">
              {pack.strings.whatsOnYourMind}
            </p>

            <InvitationInput
              pack={pack}
              mode={inputMode}
              value={entry}
              isListening={isListening}
              onValueChange={setEntry}
              onModeChange={setInputMode}
              onListeningChange={setIsListening}
            />
          </div>
        </div>
      </main>
    </div>
  );
}
