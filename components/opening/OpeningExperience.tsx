"use client";

import { CompanionResponse } from "@/components/opening/CompanionResponse";
import {
  InvitationInput,
  type InvitationInputHandle,
} from "@/components/opening/InvitationInput";
import { LanguageSelector } from "@/components/opening/LanguageSelector";
import { StoryInvitation } from "@/components/opening/StoryInvitation";
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
  // Coming home: recognized Storykeepers skip the threshold ceremony and are
  // greeted — quieter and warmer than arrival. null = not yet checked.
  const [homecoming, setHomecoming] = useState<
    { recognized: boolean; greeting: string | null } | null
  >(null);
  const pack = getVoicePack(selectedPackId ?? sessionPackId);
  const isInvitation = hasBegun || sessionBeginCompleted;
  const conversation = useFirstConversation(pack);
  const {
    activateReplyInput,
    beginArrival,
    companionReply,
    showCompanionResponse,
    isInputActive,
    isReadyForReply,
    submittedThought,
    transcript,
    voicePrefix,
    isListening,
    handleTranscriptChange,
    handleSubmit,
    handleMicToggle,
    handleListeningEnd,
    handleLanguageChange,
  } = conversation;
  const hasInitializedSpeech = useRef(false);
  const companionSpokenRef = useRef(false);
  const inputRef = useRef<InvitationInputHandle>(null);
  const beginRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    document.documentElement.lang = pack.locale;
  }, [pack.locale]);

  // Ask "am I home?" before anything speaks — a recognized Storykeeper is
  // greeted, never re-welcomed like a stranger.
  useEffect(() => {
    if (!isClientReady || homecoming !== null) {
      return;
    }
    let cancelled = false;
    fetch("/api/home")
      .then((response) => response.json())
      .then((body: { recognized: boolean; greeting?: string }) => {
        if (cancelled) return;
        if (body.recognized) {
          markBeginCompleted();
          setHasBegun(true);
          setHomecoming({ recognized: true, greeting: body.greeting ?? null });
          if (body.greeting) {
            speakText(body.greeting, pack);
          }
        } else {
          setHomecoming({ recognized: false, greeting: null });
        }
      })
      .catch(() => {
        if (!cancelled) setHomecoming({ recognized: false, greeting: null });
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isClientReady, homecoming]);

  useEffect(() => {
    if (
      !isClientReady ||
      hasInitializedSpeech.current ||
      isInvitation ||
      homecoming === null || // don't speak to a stranger who may be family
      homecoming.recognized
    ) {
      return;
    }

    hasInitializedSpeech.current = true;

    if (!hasSpokenArrival()) {
      speakText(pack.strings.touchWordYouUnderstand, pack, () => {
        markArrivalSpoken();
      });
    }
  }, [homecoming, isClientReady, isInvitation, pack]);

  useEffect(() => {
    if (!showCompanionResponse || !companionReply || companionSpokenRef.current) {
      return;
    }

    companionSpokenRef.current = true;

    speakText(companionReply.text, pack, () => {
      activateReplyInput();
      requestAnimationFrame(() => {
        inputRef.current?.focus();
      });
    });
  }, [activateReplyInput, companionReply, pack, showCompanionResponse]);

  useEffect(() => {
    if (!isClientReady || !isInvitation || !isInputActive) {
      return;
    }

    const frame = requestAnimationFrame(() => {
      inputRef.current?.focus();
    });

    return () => {
      cancelAnimationFrame(frame);
    };
  }, [isClientReady, isInputActive, isInvitation, isReadyForReply]);

  useEffect(() => {
    return () => {
      cancelSpeech();
    };
  }, []);

  // Arriving already past the threshold (a reload, a return): reconnect to
  // the conversation immediately so any unfinished thought is waiting in the
  // input before the Storykeeper touches anything.
  useEffect(() => {
    if (!isClientReady || !isInvitation) {
      return;
    }
    void beginArrival().catch(() => {
      // Recovered on first keystroke or submission.
    });
  }, [beginArrival, isClientReady, isInvitation]);

  function handleLanguageSelect(id: VoicePackId) {
    const nextPack = getVoicePack(id);
    handleLanguageChange();
    setSelectedPackId(id);
    storeVoicePackId(id);
    document.documentElement.lang = nextPack.locale;

    if (!isInvitation) {
      cancelSpeech();
      speakText(nextPack.strings.touchWordYouUnderstand, nextPack, () => {
        sessionStorage.setItem(ARRIVAL_SPOKEN_KEY, "1");
      });
      // Continuity for keyboard travellers: choosing a language carries
      // focus to Begin, so the next Enter continues the journey instead of
      // stalling on a word that has already done its work.
      requestAnimationFrame(() => {
        beginRef.current?.focus();
      });
    }
  }

  function handleBegin() {
    markBeginCompleted();
    setHasBegun(true);
    cancelSpeech();
    // The conversation becomes real the moment the threshold is crossed,
    // so the first thought has somewhere safe to land.
    void beginArrival().catch(() => {
      // Retried automatically on first draft save or submission.
    });
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
              ref={beginRef}
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
            <h1 className="font-sans text-2xl font-extralight leading-relaxed tracking-[0.06em] text-[var(--lb-fg-soft)] sm:text-3xl md:text-4xl">
              {pack.strings.whatsOnYourMind}
            </h1>

            {submittedThought ? (
              <p className="mt-10 w-full max-w-xl font-sans text-xl font-extralight leading-relaxed tracking-[0.04em] text-[var(--lb-fg)] sm:text-2xl">
                {submittedThought}
              </p>
            ) : null}

            {companionReply ? (
              <CompanionResponse
                opening={companionReply.opening}
                question={companionReply.question}
                visible={showCompanionResponse}
              />
            ) : homecoming?.recognized && homecoming.greeting ? (
              <CompanionResponse
                opening={homecoming.greeting}
                question=""
                visible
              />
            ) : null}

            {isInputActive ? (
              <InvitationInput
                ref={inputRef}
                pack={pack}
                isActive={isInvitation}
                value={transcript}
                voicePrefix={voicePrefix}
                isListening={isListening}
                onValueChange={handleTranscriptChange}
                onSubmit={handleSubmit}
                onMicToggle={handleMicToggle}
                onListeningEnd={handleListeningEnd}
              />
            ) : null}

            {homecoming !== null &&
            !homecoming.recognized &&
            showCompanionResponse ? (
              <StoryInvitation pack={pack} />
            ) : null}
          </div>
        </div>
      </main>
    </div>
  );
}
