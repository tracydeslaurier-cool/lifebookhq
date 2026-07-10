import type { VoicePack } from "@/lib/voice-packs/types";

type SpeechRecognitionConstructor = new () => SpeechRecognition;

function getSpeechRecognitionConstructor():
  | SpeechRecognitionConstructor
  | null {
  if (typeof window === "undefined") {
    return null;
  }

  return window.SpeechRecognition ?? window.webkitSpeechRecognition ?? null;
}

export function isSpeechSynthesisSupported(): boolean {
  return typeof window !== "undefined" && "speechSynthesis" in window;
}

export function isSpeechRecognitionSupported(): boolean {
  return getSpeechRecognitionConstructor() !== null;
}

export function cancelSpeech(): void {
  if (!isSpeechSynthesisSupported()) {
    return;
  }

  window.speechSynthesis.cancel();
}

export function speakText(
  text: string,
  pack: VoicePack,
  onEnd?: () => void,
): void {
  if (!isSpeechSynthesisSupported() || !text) {
    onEnd?.();
    return;
  }

  cancelSpeech();

  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = pack.speechLang;
  utterance.rate = 0.92;
  utterance.pitch = 1;

  if (onEnd) {
    utterance.onend = () => onEnd();
    utterance.onerror = () => onEnd();
  }

  window.speechSynthesis.speak(utterance);
}

export type SpeechRecognitionSession = {
  stop: () => void;
};

export function startSpeechRecognition(
  pack: VoicePack,
  onResult: (transcript: string, isFinal: boolean) => void,
  onError?: () => void,
): SpeechRecognitionSession | null {
  const Recognition = getSpeechRecognitionConstructor();
  if (!Recognition) {
    onError?.();
    return null;
  }

  const recognition = new Recognition();
  recognition.lang = pack.speechLang;
  recognition.continuous = true;
  recognition.interimResults = true;

  recognition.onresult = (event: SpeechRecognitionEvent) => {
    let transcript = "";

    for (let index = event.resultIndex; index < event.results.length; index++) {
      transcript += event.results[index][0].transcript;
    }

    const isFinal = event.results[event.results.length - 1]?.isFinal ?? false;
    onResult(transcript.trim(), isFinal);
  };

  recognition.onerror = () => {
    onError?.();
  };

  recognition.start();

  return {
    stop: () => {
      recognition.stop();
    },
  };
}
