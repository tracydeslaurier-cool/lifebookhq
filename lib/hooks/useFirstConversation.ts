"use client";

import type { InputMode } from "@/components/opening/InvitationInput";
import { companionRespond } from "@/lib/companion/respond";
import type { CompanionReply } from "@/lib/companion/types";
import {
  clearDraftText,
  readStoredDraftText,
  storeDraftText,
  storeVoicePackId,
} from "@/lib/language";
import { cancelSpeech } from "@/lib/speech";
import type { VoicePack } from "@/lib/voice-packs/types";
import { useCallback, useEffect, useRef, useState, useSyncExternalStore } from "react";

const RESPONSE_DELAY_MS = 800;

function subscribeToSessionStorage() {
  return () => {};
}

export function useFirstConversation(pack: VoicePack) {
  const storedDraft = useSyncExternalStore(
    subscribeToSessionStorage,
    readStoredDraftText,
    () => null,
  );

  const [liveTranscript, setLiveTranscript] = useState<string | null>(null);
  const [inputMode, setInputMode] = useState<InputMode>("none");
  const [isListening, setIsListening] = useState(false);
  const [voicePrefix, setVoicePrefix] = useState("");
  const [submittedThought, setSubmittedThought] = useState<string | null>(null);
  const [companionReply, setCompanionReply] = useState<CompanionReply | null>(
    null,
  );
  const [showCompanionResponse, setShowCompanionResponse] = useState(false);
  const [isReadyForReply, setIsReadyForReply] = useState(false);

  const shouldRestartListeningRef = useRef(false);
  const responseDelayTimerRef = useRef<number | null>(null);
  const hasCompanionRespondedRef = useRef(false);

  const transcript = liveTranscript ?? storedDraft ?? "";
  const isInputActive = submittedThought === null || isReadyForReply;

  const stopListening = useCallback(() => {
    setIsListening(false);
  }, []);

  const persistDraft = useCallback((value: string) => {
    const trimmed = value.trim();
    if (trimmed.length > 0) {
      storeDraftText(value);
      return;
    }

    clearDraftText();
  }, []);

  const startListening = useCallback(() => {
    setVoicePrefix(transcript);
    setInputMode("voice");
    setIsListening(true);
  }, [transcript]);

  const activateReplyInput = useCallback(() => {
    setIsReadyForReply(true);
  }, []);

  const handleTranscriptChange = useCallback(
    (value: string) => {
      if (isListening) {
        stopListening();
        setVoicePrefix("");
      }

      if (inputMode === "none" && value.length > 0) {
        setInputMode("text");
      }

      setLiveTranscript(value);
      persistDraft(value);
    },
    [inputMode, isListening, persistDraft, stopListening],
  );

  const handleMicToggle = useCallback(() => {
    if (isListening) {
      stopListening();
      setVoicePrefix("");
      return;
    }

    startListening();
  }, [isListening, startListening, stopListening]);

  const handleListeningEnd = useCallback(() => {
    setIsListening(false);
    setVoicePrefix("");
  }, []);

  const handleSubmit = useCallback(() => {
    const trimmed = transcript.trim();
    if (!trimmed) {
      return;
    }

    cancelSpeech();
    stopListening();
    setVoicePrefix("");

    clearDraftText();
    storeVoicePackId(pack.id);

    if (!hasCompanionRespondedRef.current) {
      hasCompanionRespondedRef.current = true;
      setSubmittedThought(trimmed);
      setLiveTranscript("");
      setInputMode("none");
      setCompanionReply(
        companionRespond({
          thought: trimmed,
          pack,
          turn: "first",
        }),
      );

      if (responseDelayTimerRef.current !== null) {
        window.clearTimeout(responseDelayTimerRef.current);
      }

      responseDelayTimerRef.current = window.setTimeout(() => {
        setShowCompanionResponse(true);
        responseDelayTimerRef.current = null;
      }, RESPONSE_DELAY_MS);

      return;
    }

    setLiveTranscript("");
    setInputMode("none");
  }, [pack, stopListening, transcript]);

  const handleLanguageChange = useCallback(() => {
    cancelSpeech();

    if (isListening) {
      shouldRestartListeningRef.current = true;
    }

    stopListening();
    setVoicePrefix("");
  }, [isListening, stopListening]);

  useEffect(() => {
    if (!shouldRestartListeningRef.current) {
      return;
    }

    shouldRestartListeningRef.current = false;
    startListening();
  }, [pack.id, startListening]);

  useEffect(() => {
    return () => {
      if (responseDelayTimerRef.current !== null) {
        window.clearTimeout(responseDelayTimerRef.current);
      }
    };
  }, []);

  return {
    transcript,
    inputMode,
    isListening,
    isInputActive,
    isReadyForReply,
    submittedThought,
    companionReply,
    showCompanionResponse,
    voicePrefix,
    activateReplyInput,
    handleTranscriptChange,
    handleMicToggle,
    handleListeningEnd,
    handleSubmit,
    handleLanguageChange,
  };
}
