"use client";

import {
  InvitationInput,
  type InvitationInputHandle,
} from "@/components/opening/InvitationInput";
import { LanguageSelector } from "@/components/opening/LanguageSelector";
import { Wordmark } from "@/components/opening/Wordmark";
import { useFirstConversation } from "@/lib/hooks/useFirstConversation";
import {
  ARRIVAL_SPOKEN_KEY,
  detectBrowserVoicePack,
  hasCompletedBegin,
  hasSpokenArrival,
  markArrivalSpoken,
  markBeginCompleted,
  readStoredVoicePackId,
  storeVoicePackId,
} from "@/lib/language";
import { cancelSpeech, speakText } from "@/lib/speech";
import { getVoicePack } from "@/lib/voice-packs";
import type { VoicePackId } from "@/lib/voice-packs/types";
import { useEffect, useRef, useState, useSyncExternalStore } from "react";

function subscribeToSessionStorage() {
  return () => {};
}

function readSessionPackId(): VoicePackId {
  const storedPackId = readStoredVoicePackId();
  return storedPackId ?? detectBrowserVoicePack().id;
}

function readIsClientReady(): boolean {
  return true;
}

export function OpeningExperience() {
  const isClientReady = useSyncExternalStore(
    subscribeToSessionStorage,
    readIsClientReady,
    () => false,
  );
  const sessionBeginCompleted = useSyncExternalStore(
    subscribeToSessionStorage,
    hasCompletedBegin,
    () => false,
  );
  const sessionPackId = useSyncExternalStore(
    subscribeToSessionStorage,
    readSessionPackId,
    () => "en" as VoicePackId,
  );

  const [selectedPackId, setSelectedPackId] = useState<VoicePackId | null>(
    null,
  );
  const [hasBegun, setHasBegun] = useState(false);
  const pack = getVoicePack(selectedPackId ?? sessionPackId);
  const isInvitation = hasBegun || sessionBeginCompleted;
  const conversation = useFirstConversation(pack);
  const hasInitializedSpeech = useRef(false);
  const inputRef = useRef<InvitationInputHandle>(null);

  useEffect(() => {
    document.documentElement.lang = pack.locale;
  }, [pack.locale]);

  useEffect(() => {
    if (!isClientReady || hasInitializedSpeech.current || isInvitation) {
      return;
    }

    hasInitializedSpeech.current = true;

    if (!hasSpokenArrival()) {
      speakText(pack.strings.touchWordYouUnderstand, pack, () => {
        markArrivalSpoken();
      });
    }
  }, [isClientReady, isInvitation, pack]);

  useEffect(() => {
    if (!isClientReady || !isInvitation) {
      return;
    }

    const frame = requestAnimationFrame(() => {
      inputRef.current?.focus();
    });

    return () => {
      cancelAnimationFrame(frame);
    };
  }, [conversation.isAcknowledging, isClientReady, isInvitation]);

  useEffect(() => {
    return () => {
      cancelSpeech();
    };
  }, []);

  function handleLanguageSelect(id: VoicePackId) {
    const nextPack = getVoicePack(id);
    conversation.handleLanguageChange();
    setSelectedPackId(id);
    storeVoicePackId(id);
    document.documentElement.lang = nextPack.locale;

    if (!isInvitation) {
      cancelSpeech();
      speakText(nextPack.strings.touchWordYouUnderstand, nextPack, () => {
        sessionStorage.setItem(ARRIVAL_SPOKEN_KEY, "1");
      });
    }
  }

  function handleBegin() {
    markBeginCompleted();
    setHasBegun(true);
    cancelSpeech();
    speakText(pack.strings.whatsOnYourMind, pack);

    requestAnimationFrame(() => {
      inputRef.current?.focus();
    });
  }

  if (!isClientReady) {
    return (
      <div
        className="min-h-screen bg-[var(--lb-bg)]"
        aria-hidden="true"
      />
    );
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
              isInvitation
                ? "pointer-events-none z-0 -translate-y-3 opacity-0"
                : "z-10 translate-y-0 opacity-100",
            ].join(" ")}
            aria-hidden={isInvitation}
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
              "absolute inset-0 flex flex-col items-center justify-center text-center",
              isInvitation
                ? "z-10 translate-y-0 opacity-100"
                : "pointer-events-none z-0 translate-y-4 opacity-0",
            ].join(" ")}
            aria-hidden={!isInvitation}
          >
            <p className="font-sans text-2xl font-extralight leading-relaxed tracking-[0.06em] text-[var(--lb-fg-soft)] sm:text-3xl md:text-4xl">
              {pack.strings.whatsOnYourMind}
            </p>

            <InvitationInput
              ref={inputRef}
              pack={pack}
              isActive={isInvitation}
              isAcknowledging={conversation.isAcknowledging}
              value={conversation.transcript}
              voicePrefix={conversation.voicePrefix}
              isListening={conversation.isListening}
              onValueChange={conversation.handleTranscriptChange}
              onSubmit={conversation.handleSubmit}
              onMicToggle={conversation.handleMicToggle}
              onListeningEnd={conversation.handleListeningEnd}
            />
          </div>
        </div>
      </main>
    </div>
  );
}
