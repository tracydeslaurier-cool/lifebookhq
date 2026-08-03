"use client";

/**
 * OpeningExperience — the root product experience at /.
 *
 * Flow for first-time visitors (homecoming not recognized):
 *   ThresholdScreen → language selected → invitation → conversation
 *
 * Flow for returning visitors (homecoming recognized):
 *   Greeted immediately → conversation (threshold skipped)
 *
 * The threshold is implemented in ThresholdScreen. This component owns
 * everything that comes after: the invitation, the conversation, and the
 * homecoming ceremony for recognized Storekeepers.
 */

import { CompanionResponse } from "@/components/opening/CompanionResponse";
import {
  InvitationInput,
  type InvitationInputHandle,
} from "@/components/opening/InvitationInput";
import { LanguageSelector } from "@/components/opening/LanguageSelector";
import { StoryInvitation } from "@/components/opening/StoryInvitation";
import { Wordmark } from "@/components/opening/Wordmark";
import { ThresholdScreen } from "@/components/threshold/ThresholdScreen";
import { useFirstConversation } from "@/lib/hooks/useFirstConversation";
import {
  ARRIVAL_SPOKEN_KEY,
  detectBrowserVoicePack,
  hasCompletedBegin,
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
  const stored = readStoredVoicePackId();
  return stored ?? detectBrowserVoicePack().id;
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

  const [selectedPackId, setSelectedPackId] = useState<VoicePackId | null>(null);
  const [hasBegun, setHasBegun] = useState(false);
  // homecoming: null = still checking; { recognized } = result known.
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

  useEffect(() => {
    document.documentElement.lang = pack.locale;
  }, [pack.locale]);

  // Ask "am I home?" before anything appears — recognized Storekeepers skip
  // the threshold ceremony and are greeted quietly.
  useEffect(() => {
    if (!isClientReady || homecoming !== null) return;
    let cancelled = false;
    fetch("/api/home")
      .then((response) => response.json())
      .then((body: { recognized: boolean; greeting?: string }) => {
        if (cancelled) return;
        if (body.recognized) {
          markBeginCompleted();
          setHasBegun(true);
          setHomecoming({ recognized: true, greeting: body.greeting ?? null });
          if (body.greeting) speakText(body.greeting, pack);
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

  // Returning visitors who have already passed the threshold in a prior
  // session (sessionBeginCompleted): reconnect to their conversation
  // immediately so any unfinished thought is waiting in the input.
  useEffect(() => {
    if (!isClientReady || !isInvitation) return;
    void beginArrival().catch(() => {});
  }, [beginArrival, isClientReady, isInvitation]);

  // Speak the companion's reply, then restore input.
  useEffect(() => {
    if (!showCompanionResponse || !companionReply || companionSpokenRef.current) return;
    if (conversation.replyWasRepaintedRef.current) {
      activateReplyInput();
      return;
    }
    companionSpokenRef.current = true;
    speakText(companionReply.text, pack, () => {
      activateReplyInput();
      requestAnimationFrame(() => { inputRef.current?.focus(); });
    });
  }, [activateReplyInput, companionReply, conversation.replyWasRepaintedRef, pack, showCompanionResponse]);

  // Focus the input when it becomes active in the invitation phase.
  useEffect(() => {
    if (!isClientReady || !isInvitation || !isInputActive) return;
    const frame = requestAnimationFrame(() => { inputRef.current?.focus(); });
    return () => cancelAnimationFrame(frame);
  }, [isClientReady, isInputActive, isInvitation, isReadyForReply]);

  // Guard: mark arrival spoken when returning via sessionBeginCompleted so
  // the speech guard in legacy code paths doesn't re-fire.
  useEffect(() => {
    if (!isClientReady || isInvitation || homecoming === null || homecoming.recognized) return;
    if (hasInitializedSpeech.current) return;
    hasInitializedSpeech.current = true;
    // ThresholdScreen owns all speech before the threshold is crossed.
    // This effect is a no-op for the new flow but kept as a safety guard.
    sessionStorage.setItem(ARRIVAL_SPOKEN_KEY, "1");
  }, [homecoming, isClientReady, isInvitation]);

  useEffect(() => {
    return () => { cancelSpeech(); };
  }, []);

  /**
   * Called by ThresholdScreen when the visitor taps a language word.
   * Adopts the selected pack, marks Begin completed, opens the invitation.
   */
  function handleThresholdEnter(packId: VoicePackId) {
    const nextPack = getVoicePack(packId);
    handleLanguageChange();
    setSelectedPackId(packId);
    storeVoicePackId(packId);
    document.documentElement.lang = nextPack.locale;
    markBeginCompleted();
    setHasBegun(true);
    cancelSpeech();
    // Open the conversation so the first thought has somewhere safe to land.
    void beginArrival().catch(() => {});
    // Speak and display the story invitation in the selected language.
    speakText(nextPack.strings.storyInvitation, nextPack);
    requestAnimationFrame(() => { inputRef.current?.focus(); });
  }

  /** Post-threshold language change (from the LanguageSelector in the nav). */
  function handleLanguageSelect(id: VoicePackId) {
    const nextPack = getVoicePack(id);
    handleLanguageChange();
    setSelectedPackId(id);
    storeVoicePackId(id);
    document.documentElement.lang = nextPack.locale;
  }

  // ── Render ───────────────────────────────────────────────────────────────

  // Server / hydration shell.
  if (!isClientReady) {
    return <div className="min-h-screen bg-[var(--lb-bg)]" aria-hidden="true" />;
  }

  // Homecoming check in progress — hold the darkness briefly.
  if (homecoming === null) {
    return <div className="min-h-screen bg-[var(--lb-bg)]" aria-hidden="true" />;
  }

  // First-time visitor: show the threshold experience.
  // (Recognized returning visitors skip straight to isInvitation.)
  if (!homecoming.recognized && !isInvitation) {
    return (
      <ThresholdScreen
        detectedPack={getVoicePack(sessionPackId)}
        onEnter={handleThresholdEnter}
      />
    );
  }

  // ── Invitation / conversation ─────────────────────────────────────────

  return (
    <div className="relative min-h-screen overflow-hidden bg-[var(--lb-bg)] text-[var(--lb-fg)]">
      {/* Language selector: available after the threshold is crossed. */}
      <LanguageSelector selectedId={pack.id} onSelect={handleLanguageSelect} />
      <Wordmark pack={pack} />

      <main className="flex min-h-screen items-center justify-center px-6 py-20">
        <div className="relative h-[min(70vh,32rem)] w-full max-w-3xl">
          <div
            className="absolute inset-0 flex flex-col items-center overflow-y-auto text-center"
            aria-hidden={!isInvitation}
          >
            <div className="m-auto flex w-full flex-col items-center py-6">
              {/* Story invitation — replaces the old "What's on your mind?" heading. */}
              <h1 className="font-sans text-2xl font-extralight leading-relaxed tracking-[0.06em] text-[var(--lb-fg-soft)] sm:text-3xl md:text-4xl">
                {pack.strings.storyInvitation}
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

              {homecoming !== null && !homecoming.recognized && showCompanionResponse ? (
                <StoryInvitation pack={pack} />
              ) : null}
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
