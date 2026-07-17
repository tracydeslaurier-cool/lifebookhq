"use client";

import { CompanionResponse } from "@/components/opening/CompanionResponse";
import { Wordmark } from "@/components/opening/Wordmark";
import { GlobeOverlay } from "@/components/threshold/GlobeOverlay";
import { ThresholdInput } from "@/components/threshold/ThresholdInput";
import {
  emitBeacon,
  emitEvent,
  startMaskedRecording,
  type ExperimentVariant,
} from "@/lib/experiment/client";
import { useFirstConversation } from "@/lib/hooks/useFirstConversation";
import { detectBrowserVoicePack, storeVoicePackId } from "@/lib/language";
import { cancelSpeech, speakText } from "@/lib/speech";
import { getVoicePack } from "@/lib/voice-packs";
import type { VoicePackId } from "@/lib/voice-packs/types";
import { useCallback, useEffect, useRef, useState } from "react";

/**
 * The Threshold — a discovery experiment. Three variants share this brain and
 * differ only in their arrival visuals:
 *   A (radical simplicity): nothing but the logo, voice, text, globe.
 *   B (presence): a gentle breathing halo — "I'm here whenever you're ready."
 *   C (invitation): a warm opening in words.
 * Everything else — the Companion backend, voice/text, language detection,
 * instrumentation, masked recording — is identical, so only the threshold
 * itself varies.
 */

const INVITATION_LINES = [
  "Hi.",
  "I'm glad you're here.",
  "There's no right place to begin.",
  "Some people tell me about today.",
  "Some tell me about fifty years ago.",
  "Some simply say hello.",
  "Wherever you'd like to begin is exactly the right place.",
];

export function ThresholdExperience({ variant }: { variant: ExperimentVariant }) {
  const [selectedPackId, setSelectedPackId] = useState<VoicePackId | null>(null);
  const [detectedPackId, setDetectedPackId] = useState<VoicePackId>("en");
  const [ready, setReady] = useState(false);
  const [globeOpen, setGlobeOpen] = useState(false);
  const [voiceNote, setVoiceNote] = useState(false);

  const pack = getVoicePack(selectedPackId ?? detectedPackId);
  const conversation = useFirstConversation(pack);
  const {
    transcript,
    voicePrefix,
    isListening,
    isInputActive,
    submittedThought,
    companionReply,
    showCompanionResponse,
    inputMode,
    handleTranscriptChange,
    handleSubmit,
    handleMicToggle,
    handleListeningEnd,
    handleLanguageChange,
    beginArrival,
    replyWasRepaintedRef,
  } = conversation;

  const arrivalAtRef = useRef(0);
  const firstInteractionRef = useRef(false);
  const inputModeEmittedRef = useRef(false);
  const entrustCountRef = useRef(0);
  const lastSubmittedRef = useRef<string | null>(null);
  const companionSpokenRef = useRef(false);

  const elapsed = useCallback(
    () => Math.round(performance.now() - arrivalAtRef.current),
    [],
  );

  // Arrival: detect language, open the conversation, begin masked recording.
  useEffect(() => {
    const detected = detectBrowserVoicePack().id;
    setDetectedPackId(detected);
    setReady(true);
    arrivalAtRef.current = performance.now();
    document.documentElement.lang = getVoicePack(detected).locale;

    emitEvent(variant, "arrival", {});
    emitEvent(variant, "language_detected", { pack: detected });

    void beginArrival().catch(() => {});

    let stop: (() => void) | undefined;
    void startMaskedRecording(variant).then((s) => {
      stop = s;
    });

    const onPageHide = () => {
      emitBeacon(variant, "session_end", {
        durationMs: elapsed(),
        entrusted: entrustCountRef.current > 0,
        continued: entrustCountRef.current > 1,
      });
    };
    window.addEventListener("pagehide", onPageHide);

    return () => {
      window.removeEventListener("pagehide", onPageHide);
      stop?.();
      cancelSpeech();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [variant]);

  const markFirstInteraction = useCallback(
    (which: string) => {
      if (firstInteractionRef.current) return;
      firstInteractionRef.current = true;
      emitEvent(variant, "first_interaction", { which, elapsedMs: elapsed() });
    },
    [variant, elapsed],
  );

  // Which input the Storykeeper reached for, emitted once.
  useEffect(() => {
    if (inputModeEmittedRef.current) return;
    if (inputMode === "text" || inputMode === "voice") {
      inputModeEmittedRef.current = true;
      emitEvent(variant, "input_mode", { mode: inputMode, elapsedMs: elapsed() });
    }
  }, [inputMode, variant, elapsed]);

  // Entrustment counting — the metric that matters. Repaints of a resumed
  // conversation are not fresh entrustments.
  useEffect(() => {
    if (!submittedThought) return;
    if (submittedThought === lastSubmittedRef.current) return;
    if (replyWasRepaintedRef.current) {
      lastSubmittedRef.current = submittedThought;
      return;
    }
    lastSubmittedRef.current = submittedThought;
    entrustCountRef.current += 1;
    if (entrustCountRef.current === 1) {
      emitEvent(variant, "first_entrustment", { elapsedMs: elapsed() });
    } else if (entrustCountRef.current === 2) {
      emitEvent(variant, "continued", { elapsedMs: elapsed() });
    }
  }, [submittedThought, replyWasRepaintedRef, variant, elapsed]);

  // Speak the Companion's live reply (never a repainted memory).
  useEffect(() => {
    if (!showCompanionResponse || !companionReply || companionSpokenRef.current) {
      return;
    }
    if (replyWasRepaintedRef.current) return;
    companionSpokenRef.current = true;
    speakText(companionReply.text, pack);
  }, [showCompanionResponse, companionReply, replyWasRepaintedRef, pack]);

  const onValueChange = useCallback(
    (value: string) => {
      markFirstInteraction("text");
      handleTranscriptChange(value);
    },
    [handleTranscriptChange, markFirstInteraction],
  );

  const onMic = useCallback(() => {
    markFirstInteraction("voice");
    handleMicToggle();
  }, [handleMicToggle, markFirstInteraction]);

  const onVoiceUnsupported = useCallback(() => {
    markFirstInteraction("voice");
    setVoiceNote(true);
    emitEvent(variant, "voice_reach_unsupported", { elapsedMs: elapsed() });
  }, [markFirstInteraction, variant, elapsed]);

  function openGlobe() {
    markFirstInteraction("globe");
    emitEvent(variant, "globe_opened", { elapsedMs: elapsed() });
    setGlobeOpen(true);
  }

  function selectLanguage(id: VoicePackId) {
    handleLanguageChange();
    setSelectedPackId(id);
    storeVoicePackId(id);
    document.documentElement.lang = getVoicePack(id).locale;
    emitEvent(variant, "language_selected", { pack: id, elapsedMs: elapsed() });
    setGlobeOpen(false);
  }

  if (!ready) {
    return <div className="min-h-screen bg-[var(--lb-bg)]" aria-hidden="true" />;
  }

  const showInvitationCopy =
    variant === "c" && !submittedThought && !companionReply;

  return (
    <div className="relative min-h-screen overflow-hidden bg-[var(--lb-bg)] text-[var(--lb-fg)]">
      <button
        type="button"
        onClick={openGlobe}
        aria-label="Choose a language"
        className="fixed top-6 right-6 z-30 text-[var(--lb-fg-muted)] opacity-55 transition-opacity duration-500 hover:opacity-90 focus-visible:opacity-100 focus-visible:outline-none"
      >
        <span aria-hidden="true" className="text-xl">
          🌐
        </span>
      </button>

      <Wordmark pack={pack} />

      {variant === "b" ? (
        <div
          aria-hidden="true"
          className="pointer-events-none fixed inset-0 z-0 flex items-center justify-center"
        >
          <div
            className="lb-breathe h-64 w-64 rounded-full"
            style={{
              background:
                "radial-gradient(circle, rgba(212,165,116,0.14), transparent 70%)",
            }}
          />
        </div>
      ) : null}

      <main className="relative z-10 flex min-h-screen items-center justify-center px-6 py-20">
        <div className="flex w-full max-w-2xl flex-col items-center text-center">
          {showInvitationCopy ? (
            <div className="mb-6 space-y-2">
              {INVITATION_LINES.map((line) => (
                <p
                  key={line}
                  className="font-serif text-xl font-light leading-relaxed tracking-[0.03em] text-[var(--lb-fg-soft)] sm:text-2xl"
                >
                  {line}
                </p>
              ))}
            </div>
          ) : null}

          {submittedThought ? (
            <p className="mt-2 w-full max-w-xl font-sans text-xl font-extralight leading-relaxed tracking-[0.04em] text-[var(--lb-fg)] sm:text-2xl">
              {submittedThought}
            </p>
          ) : null}

          {companionReply ? (
            <CompanionResponse
              opening={companionReply.opening}
              question={companionReply.question}
              visible={showCompanionResponse}
            />
          ) : null}

          {isInputActive ? (
            <ThresholdInput
              pack={pack}
              value={transcript}
              voicePrefix={voicePrefix}
              isListening={isListening}
              onValueChange={onValueChange}
              onSubmit={handleSubmit}
              onMicToggle={onMic}
              onListeningEnd={handleListeningEnd}
              onVoiceUnsupported={onVoiceUnsupported}
            />
          ) : null}

          {voiceNote ? (
            <p className="mt-8 font-sans text-xs font-extralight tracking-[0.08em] text-[var(--lb-fg-muted)]">
              Speaking isn&rsquo;t ready on this device yet &mdash; you can type
              for now.
            </p>
          ) : null}
        </div>
      </main>

      <p className="fixed bottom-4 left-1/2 z-20 max-w-[90vw] -translate-x-1/2 px-4 text-center font-sans text-[10px] font-extralight tracking-[0.08em] text-[var(--lb-fg-muted)] opacity-40">
        On-screen interactions are recorded to help us learn &mdash; no camera,
        and never the words you write.
      </p>

      <GlobeOverlay
        open={globeOpen}
        onClose={() => setGlobeOpen(false)}
        onSelect={selectLanguage}
      />
    </div>
  );
}
