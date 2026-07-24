"use client";

import type { InputMode } from "@/components/opening/InvitationInput";
import type { CompanionReply } from "@/lib/companion/types";
import {
  beginConversation,
  entrustMoment,
  getConversation,
  saveDraft,
} from "@/lib/client/api";
import {
  clearDraftText,
  clearStoredConversationId,
  readStoredDraftText,
  storeConversationId,
  storeDraftText,
  storeVoicePackId,
} from "@/lib/language";
import { cancelSpeech } from "@/lib/speech";
import type { VoicePack } from "@/lib/voice-packs/types";
import {
  useCallback,
  useEffect,
  useRef,
  useState,
  useSyncExternalStore,
} from "react";

const RESPONSE_DELAY_MS = 800;
const DRAFT_SAVE_DEBOUNCE_MS = 1200;

function subscribeToSessionStorage() {
  return () => {};
}

/**
 * The first conversation.
 *
 * The Storykeeper's words live server-side: the conversation is real, the
 * draft survives a closed tab, and a submitted Moment is entrusted to the
 * Archive. sessionStorage remains only as a local echo between keystrokes.
 */
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
  const replyWasRepaintedRef = useRef(false);
  const responseDelayTimerRef = useRef<number | null>(null);
  const draftSaveTimerRef = useRef<number | null>(null);
  const conversationIdRef = useRef<string | null>(null);
  const conversationPromiseRef = useRef<Promise<string> | null>(null);
  const isSubmittingRef = useRef(false);

  const transcript = liveTranscript ?? storedDraft ?? "";
  const isInputActive = submittedThought === null || isReadyForReply;

  /**
   * The conversation pointer lives on the server, behind the session cookie.
   * Asking to begin *is* asking to come back: the server resumes the Book's
   * open conversation and returns any unfinished thought with it.
   */
  const ensureConversation = useCallback((): Promise<string> => {
    if (conversationIdRef.current) {
      return Promise.resolve(conversationIdRef.current);
    }
    if (!conversationPromiseRef.current) {
      conversationPromiseRef.current = beginConversation(pack.id).then(
        ({ conversationId, draft }) => {
          conversationIdRef.current = conversationId;
          storeConversationId(conversationId);
          // A thought left unfinished in another tab, another hour, comes home.
          if (draft && !readStoredDraftText()) {
            storeDraftText(draft);
            setLiveTranscript(draft);
          }
          // Returning must never LOOK like scratch: repaint the last entrusted
          // thought so the Storykeeper sees where the conversation left off.
          // (Minimal by design — a scrolling history is a scene-design
          // question the observation period still owns.)
          void getConversation(conversationId).then((turns) => {
            const lastMomentIndex = turns.map((t) => t.speaker).lastIndexOf("storykeeper");
            const lastMoment = lastMomentIndex >= 0 ? turns[lastMomentIndex] : null;
            if (lastMoment) {
              setSubmittedThought((previous) => previous ?? lastMoment.text);
              setIsReadyForReply(true);
              // Repaint the Companion's reply too — half a conversation
              // repainted is not continuity (Director, 2026-07-17). Marked
              // as repainted so it is shown, never re-spoken aloud.
              const replyAfter = turns
                .slice(lastMomentIndex + 1)
                .find((turn) => turn.speaker === "companion");
              if (replyAfter) {
                replyWasRepaintedRef.current = true;
                setCompanionReply((previous) =>
                  previous ?? {
                    opening: replyAfter.text,
                    question: "",
                    text: replyAfter.text,
                  },
                );
                setShowCompanionResponse(true);
              }
              // Self-healing for ghost drafts: a draft identical to the last
              // entrusted Moment is a leftover of the autosave race — clear
              // it everywhere rather than showing the Storykeeper a double.
              const draftNow = readStoredDraftText();
              if (draftNow && draftNow.trim() === lastMoment.text.trim()) {
                clearDraftText();
                setLiveTranscript("");
                void saveDraft(conversationId, "");
              }
            }
          });
          return conversationId;
        },
      );
      conversationPromiseRef.current.catch(() => {
        conversationPromiseRef.current = null;
      });
    }
    return conversationPromiseRef.current;
  }, [pack.id]);

  const stopListening = useCallback(() => {
    setIsListening(false);
  }, []);

  const persistDraft = useCallback(
    (value: string) => {
      const trimmed = value.trim();
      if (trimmed.length > 0) {
        storeDraftText(value);
      } else {
        clearDraftText();
      }

      if (draftSaveTimerRef.current !== null) {
        window.clearTimeout(draftSaveTimerRef.current);
      }
      draftSaveTimerRef.current = window.setTimeout(() => {
        draftSaveTimerRef.current = null;
        // A submission in flight means these words are becoming a Moment;
        // saving them as a draft now would create a ghost (the "double
        // reply" defect, 2026-07-17).
        if (isSubmittingRef.current) {
          return;
        }
        ensureConversation()
          .then((id) => saveDraft(id, value))
          .catch(() => {
            // The local echo still holds the words; the next save retries.
          });
      }, DRAFT_SAVE_DEBOUNCE_MS);
    },
    [ensureConversation],
  );

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

  /**
   * Voice-only transcript update. Does NOT stop listening — that is the bug
   * that handleTranscriptChange carried: it was shared between keyboard input
   * (where stopping is correct) and voice results (where it kills the mic
   * after every spoken phrase). This callback is used exclusively by the
   * speech recognition callback in ThresholdInput.
   */
  const handleVoiceResult = useCallback(
    (value: string) => {
      setLiveTranscript(value);
      persistDraft(value);
    },
    [persistDraft],
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
    if (!trimmed || isSubmittingRef.current) {
      return;
    }

    cancelSpeech();
    stopListening();
    setVoicePrefix("");
    storeVoicePackId(pack.id);

    // Disarm any pending autosave: these words are being entrusted, not drafted.
    if (draftSaveTimerRef.current !== null) {
      window.clearTimeout(draftSaveTimerRef.current);
      draftSaveTimerRef.current = null;
    }

    isSubmittingRef.current = true;
    setSubmittedThought(trimmed);
    setLiveTranscript("");
    setInputMode("none");

    ensureConversation()
      .then((id) => entrustMoment(id, trimmed, pack.id))
      .then((reply) => {
        replyWasRepaintedRef.current = false; // a live reply follows
        clearDraftText();
        // Belt and suspenders: erase any server-side draft of the words that
        // just became a Moment, in case an autosave slipped through.
        if (conversationIdRef.current) {
          void saveDraft(conversationIdRef.current, "");
        }
        setCompanionReply({ opening: reply.text, question: "", text: reply.text });

        if (responseDelayTimerRef.current !== null) {
          window.clearTimeout(responseDelayTimerRef.current);
        }
        responseDelayTimerRef.current = window.setTimeout(() => {
          setShowCompanionResponse(true);
          responseDelayTimerRef.current = null;
        }, RESPONSE_DELAY_MS);
      })
      .catch(() => {
        // The words were not entrusted — they must not be lost.
        // Return them to the Storykeeper's hands, unchanged.
        setSubmittedThought(null);
        setLiveTranscript(trimmed);
        storeDraftText(trimmed);
        setInputMode("text");
      })
      .finally(() => {
        isSubmittingRef.current = false;
      });
  }, [ensureConversation, pack.id, stopListening, transcript]);

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
      if (draftSaveTimerRef.current !== null) {
        window.clearTimeout(draftSaveTimerRef.current);
      }
    };
  }, []);

  return {
    replyWasRepaintedRef,
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
    beginArrival: ensureConversation,
    handleTranscriptChange,
    handleVoiceResult,
    handleMicToggle,
    handleListeningEnd,
    handleSubmit,
    handleLanguageChange,
  };
}

export { clearStoredConversationId };
