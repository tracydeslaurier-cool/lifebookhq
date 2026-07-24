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
import { cancelSpeech, speakText, type SpeechLifecycle } from "@/lib/speech";
import { getVoicePack } from "@/lib/voice-packs";
import type { VoicePackId } from "@/lib/voice-packs/types";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

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
    handleVoiceResult,
    handleSubmit,
    handleMicToggle,
    handleListeningEnd,
    handleLanguageChange,
    activateReplyInput,
    beginArrival,
    replyWasRepaintedRef,
  } = conversation;

  const arrivalAtRef = useRef(0);
  const firstInteractionRef = useRef(false);
  const inputModeEmittedRef = useRef(false);
  const entrustCountRef = useRef(0);
  const lastSubmittedRef = useRef<string | null>(null);
  const lastSpokenReplyRef = useRef<string | null>(null);
  const usedVoiceRef = useRef(false);

  const elapsed = useCallback(
    () => Math.round(performance.now() - arrivalAtRef.current),
    [],
  );

  // Discovery-only voice telemetry: where the voice experience breaks, so a
  // Presence problem can be told apart from a browser/platform limitation.
  const voiceLifecycle = useMemo<SpeechLifecycle>(
    () => ({
      onStart: () => emitEvent(variant, "voice_started", { elapsedMs: elapsed() }),
      onRecognitionEnd: () =>
        emitEvent(variant, "recognition_ended", { elapsedMs: elapsed() }),
      onAutoRestart: () =>
        emitEvent(variant, "automatic_restart", { elapsedMs: elapsed() }),
      onStop: (durationMs) =>
        emitEvent(variant, "user_stopped", { durationMs, elapsedMs: elapsed() }),
      onError: (error, durationMs) =>
        emitEvent(variant, "voice_error", {
          error: error ?? "unknown",
          durationMs,
          elapsedMs: elapsed(),
        }),
    }),
    [variant, elapsed],
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

    // A true first arrival: mint a fresh anonymous session so the experiment
    // never lands in an existing Storykeeper's conversation, then open the
    // (empty) conversation.
    void fetch("/api/experiment/reset", { method: "POST" })
      .catch(() => {})
      .then(() => beginArrival())
      .catch(() => {});

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

  // Speak each live reply, then naturally continue listening if the
  // Storykeeper has been speaking — listen → respond → listen, no second tap.
  // Repainted memories are shown, never spoken.
  useEffect(() => {
    if (!showCompanionResponse || !companionReply) return;
    if (replyWasRepaintedRef.current) return;
    if (companionReply.text === lastSpokenReplyRef.current) return;
    lastSpokenReplyRef.current = companionReply.text;
    speakText(companionReply.text, pack, () => {
      // The Companion has finished — it's the Storykeeper's turn again.
      // Bring the input back, and if they've been speaking, resume listening
      // so the conversation simply continues (no second tap).
      activateReplyInput();
      if (usedVoiceRef.current && !isListening) {
        handleMicToggle();
      }
    });
  }, [
    showCompanionResponse,
    companionReply,
    replyWasRepaintedRef,
    pack,
    isListening,
    handleMicToggle,
    activateReplyInput,
  ]);

  const onValueChange = useCallback(
    (value: string) => {
      markFirstInteraction("text");
      handleTranscriptChange(value);
    },
    [handleTranscriptChange, markFirstInteraction],
  );

  // Voice recognition results take a separate path that does NOT stop the mic.
  // handleTranscriptChange stops listening (correct for keyboard input), but
  // calling it on every voice result killed the mic after each spoken phrase.
  const onVoiceResult = useCallback(
    (value: string) => {
      markFirstInteraction("voice");
      handleVoiceResult(value);
    },
    [handleVoiceResult, markFirstInteraction],
  );

  const onMic = useCallback(() => {
    usedVoiceRef.current = true;
    markFirstInteraction("voice");
    handleMicToggle();
  }, [handleMicToggle, markFirstInteraction]);

  const onSubmit = useCallback(() => {
    const chars = transcript.trim().length;
    if (chars > 0) {
      // The act of entrustment itself — thought → trust → entrustment.
      // Observed, never altered yet. Content-free: a count, never the words.
      emitEvent(variant, "kept_this", { inputMode, chars, elapsedMs: elapsed() });
    }
    handleSubmit();
  }, [transcript, inputMode, handleSubmit, variant, elapsed]);

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
              onVoiceResult={onVoiceResult}
              onSubmit={onSubmit}
              onMicToggle={onMic}
              onListeningEnd={handleListeningEnd}
              onVoiceUnsupported={onVoiceUnsupported}
              voiceLifecycle={voiceLifecycle}
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
