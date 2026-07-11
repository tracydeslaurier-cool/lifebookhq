"use client";

import type { InputMode } from "@/components/opening/InvitationInput";
import {
  clearDraftText,
  readStoredDraftText,
  storeDraftText,
  storeVoicePackId,
} from "@/lib/language";
import { cancelSpeech } from "@/lib/speech";
import type { VoicePack } from "@/lib/voice-packs/types";
import { useCallback, useEffect, useRef, useState, useSyncExternalStore } from "react";

const ACKNOWLEDGEMENT_MS = 1500;

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
  const [isAcknowledging, setIsAcknowledging] = useState(false);
  const shouldRestartListeningRef = useRef(false);
  const acknowledgementTimerRef = useRef<number | null>(null);

  const transcript = liveTranscript ?? storedDraft ?? "";

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
    setLiveTranscript("");
    setInputMode("none");
    setIsAcknowledging(true);

    if (acknowledgementTimerRef.current !== null) {
      window.clearTimeout(acknowledgementTimerRef.current);
    }

    acknowledgementTimerRef.current = window.setTimeout(() => {
      setIsAcknowledging(false);
      acknowledgementTimerRef.current = null;
    }, ACKNOWLEDGEMENT_MS);
  }, [pack.id, stopListening, transcript]);

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
      if (acknowledgementTimerRef.current !== null) {
        window.clearTimeout(acknowledgementTimerRef.current);
      }
    };
  }, []);

  return {
    transcript,
    inputMode,
    isListening,
    isAcknowledging,
    voicePrefix,
    handleTranscriptChange,
    handleMicToggle,
    handleListeningEnd,
    handleSubmit,
    handleLanguageChange,
  };
}
