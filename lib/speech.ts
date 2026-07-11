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

function normalizeLanguageTag(tag: string): string {
  return tag.trim().toLowerCase().replace(/_/g, "-");
}

export function isSpeechSynthesisSupported(): boolean {
  return typeof window !== "undefined" && "speechSynthesis" in window;
}

export function isSpeechRecognitionSupported(): boolean {
  return getSpeechRecognitionConstructor() !== null;
}

export function selectBestVoice(speechLang: string): SpeechSynthesisVoice | null {
  if (!isSpeechSynthesisSupported()) {
    return null;
  }

  const voices = window.speechSynthesis.getVoices();
  if (voices.length === 0) {
    return null;
  }

  const target = normalizeLanguageTag(speechLang);
  const [language] = target.split("-");

  const exactMatch = voices.find(
    (voice) => normalizeLanguageTag(voice.lang) === target,
  );
  if (exactMatch) {
    return exactMatch;
  }

  const regionalMatch = voices.find((voice) => {
    const voiceLang = normalizeLanguageTag(voice.lang);
    return voiceLang.startsWith(`${language}-`);
  });
  if (regionalMatch) {
    return regionalMatch;
  }

  const languageMatch = voices.find((voice) =>
    normalizeLanguageTag(voice.lang).startsWith(language),
  );
  if (languageMatch) {
    return languageMatch;
  }

  return voices[0] ?? null;
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

  const beginSpeaking = () => {
    const voice = selectBestVoice(pack.speechLang);
    if (voice) {
      utterance.voice = voice;
    }

    window.speechSynthesis.speak(utterance);
  };

  if (window.speechSynthesis.getVoices().length > 0) {
    beginSpeaking();
    return;
  }

  window.speechSynthesis.addEventListener("voiceschanged", beginSpeaking, {
    once: true,
  });
}

export type SpeechRecognitionResult = {
  transcript: string;
  isFinal: boolean;
};

export type SpeechRecognitionSession = {
  stop: () => void;
};

export function startSpeechRecognition(
  pack: VoicePack,
  onResult: (result: SpeechRecognitionResult) => void,
  onError?: () => void,
  prefix = "",
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

  let committed = "";

  recognition.onresult = (event: SpeechRecognitionEvent) => {
    let interim = "";

    for (let index = event.resultIndex; index < event.results.length; index++) {
      const result = event.results[index];
      const segment = result[0]?.transcript ?? "";

      if (result.isFinal) {
        committed += segment;
      } else {
        interim += segment;
      }
    }

    onResult({
      transcript: `${prefix}${committed}${interim}`,
      isFinal: interim.length === 0,
    });
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
