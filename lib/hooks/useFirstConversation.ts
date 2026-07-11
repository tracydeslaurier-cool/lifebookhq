"use client";

import type { InputMode } from "@/components/opening/InvitationInput";
import {
  readStoredFirstThought,
  storeFirstThought,
  type StoredFirstThought,
} from "@/lib/language";
import { cancelSpeech } from "@/lib/speech";
import type { VoicePack } from "@/lib/voice-packs/types";
import { useCallback, useEffect, useRef, useState } from "react";

function readInitialConversationState(): {
  transcript: string;
  isSubmitted: boolean;
} {
  const stored = readStoredFirstThought();
  if (stored) {
    return {
      transcript: stored.transcript,
      isSubmitted: true,
    };
  }

  return {
    transcript: "",
    isSubmitted: false,
  };
}

export function useFirstConversation(pack: VoicePack) {
  const [transcript, setTranscript] = useState(
    () => readInitialConversationState().transcript,
  );
  const [inputMode, setInputMode] = useState<InputMode>("none");
  const [isListening, setIsListening] = useState(false);
  const [isSubmitted, setIsSubmitted] = useState(
    () => readInitialConversationState().isSubmitted,
  );
  const [voicePrefix, setVoicePrefix] = useState("");
  const shouldRestartListeningRef = useRef(false);

  const stopListening = useCallback(() => {
    setIsListening(false);
  }, []);

  const startListening = useCallback(() => {
    if (isSubmitted) {
      return;
    }

    setVoicePrefix(transcript);
    setInputMode("voice");
    setIsListening(true);
  }, [isSubmitted, transcript]);

  const handleTranscriptChange = useCallback(
    (value: string) => {
      if (isSubmitted) {
        return;
      }

      if (isListening) {
        stopListening();
        setVoicePrefix("");
      }

      if (inputMode === "none" && value.length > 0) {
        setInputMode("text");
      }

      setTranscript(value);
    },
    [inputMode, isListening, isSubmitted, stopListening],
  );

  const handleRecognitionResult = useCallback(
    (value: string) => {
      if (isSubmitted) {
        return;
      }

      setTranscript(value);
    },
    [isSubmitted],
  );

  const handleMicToggle = useCallback(() => {
    if (isSubmitted) {
      return;
    }

    if (isListening) {
      stopListening();
      setVoicePrefix("");
      return;
    }

    startListening();
  }, [isListening, isSubmitted, startListening, stopListening]);

  const handleListeningEnd = useCallback(() => {
    setIsListening(false);
    setVoicePrefix("");
  }, []);

  const handleSubmit = useCallback(() => {
    const trimmed = transcript.trim();
    if (!trimmed || isSubmitted) {
      return;
    }

    cancelSpeech();
    stopListening();
    setVoicePrefix("");

    const submission: StoredFirstThought = {
      transcript: trimmed,
      packId: pack.id,
      submittedAt: new Date().toISOString(),
    };

    storeFirstThought(submission);
    setTranscript(trimmed);
    setIsSubmitted(true);
    setInputMode("text");
  }, [isSubmitted, pack.id, stopListening, transcript]);

  const handleLanguageChange = useCallback(() => {
    cancelSpeech();

    if (isListening) {
      shouldRestartListeningRef.current = true;
    }

    stopListening();
    setVoicePrefix("");
  }, [isListening, stopListening]);

  useEffect(() => {
    if (!shouldRestartListeningRef.current || isSubmitted) {
      return;
    }

    shouldRestartListeningRef.current = false;
    startListening();
  }, [isSubmitted, pack.id, startListening]);

  return {
    transcript,
    inputMode,
    isListening,
    isSubmitted,
    voicePrefix,
    handleTranscriptChange,
    handleRecognitionResult,
    handleMicToggle,
    handleListeningEnd,
    handleSubmit,
    handleLanguageChange,
  };
}
