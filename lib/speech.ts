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

/**
 * Browser TTS is interim (AD-5 retires it for a real voice provider), but
 * until then the voice must not frighten anyone. macOS ships novelty voices
 * ("Albert", "Fred", "Whisper", …) at the front of the list; naive
 * first-match selection hands the threshold to a ghost.
 */
const NOVELTY_VOICES = [
  "albert", "bad news", "bahh", "bells", "boing", "bubbles", "cellos",
  "deranged", "eddy", "flo", "fred", "good news", "grandma", "grandpa",
  "jester", "junior", "kathy", "organ", "ralph", "reed", "rocko", "sandy",
  "shelley", "superstar", "trinoids", "whisper", "wobble", "zarvox", "hysterical",
];

/** Warm, human-quality voices worth seeking out, per language. */
const PREFERRED_VOICES: Record<string, string[]> = {
  en: ["samantha", "ava", "allison", "zoe", "google us english", "karen", "moira", "daniel", "serena", "tessa"],
  uk: ["lesya", "google українська"],
  ru: ["milena", "google русский"],
  fr: ["amelie", "amélie", "thomas", "audrey", "google français"],
  de: ["anna", "petra", "google deutsch"],
  es: ["monica", "mónica", "paulina", "google español"],
  pl: ["zosia", "google polski"],
  it: ["alice", "google italiano"],
};

function scoreVoice(
  voice: SpeechSynthesisVoice,
  target: string,
  language: string,
): number {
  const name = voice.name.toLowerCase();
  const voiceLang = normalizeLanguageTag(voice.lang);

  // Language fit is the entry ticket.
  let score = 0;
  if (voiceLang === target) score += 40;
  else if (voiceLang.startsWith(`${language}-`)) score += 30;
  else if (voiceLang.startsWith(language)) score += 20;
  else return -1000; // wrong language entirely

  // Never the ghost.
  if (NOVELTY_VOICES.some((novelty) => name.includes(novelty))) {
    score -= 500;
  }

  const preferred = PREFERRED_VOICES[language] ?? [];
  const preferredIndex = preferred.findIndex((p) => name.includes(p));
  if (preferredIndex >= 0) {
    score += 100 - preferredIndex; // earlier in the list = warmer
  }

  if (name.includes("premium") || name.includes("enhanced")) score += 15;
  if (name.includes("natural")) score += 10;
  if (name.startsWith("google") || name.startsWith("microsoft")) score += 8;
  if (voice.default) score += 3;
  if (name.includes("compact")) score -= 20;

  return score;
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

  let best: SpeechSynthesisVoice | null = null;
  let bestScore = -Infinity;
  for (const voice of voices) {
    const score = scoreVoice(voice, target, language);
    if (score > bestScore) {
      best = voice;
      bestScore = score;
    }
  }

  // A heavily penalized novelty voice may still "win" if it is the only
  // match for the language — better an odd voice than silence, and the
  // real remedy is AD-5's provider voice.
  return bestScore > -1000 ? best : (voices[0] ?? null);
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

  let stopped = false; // set only by an intentional stop()
  let committed = ""; // finals accumulated ACROSS restarts
  let recognition: SpeechRecognition | null = null;
  let restartTimer: number | null = null;
  let startedAt = 0;
  // Guard against an environment that ends instantly and never hears audio:
  // count only *quick* ends; a genuine listening window (or any result)
  // resets the count, so real pauses never end the session.
  let emptyEnds = 0;

  const emit = (interim: string) => {
    onResult({
      transcript: `${prefix}${committed}${interim}`,
      isFinal: interim.length === 0,
    });
  };

  const startOnce = () => {
    const rec = new Recognition() as SpeechRecognition & {
      onend: ((this: SpeechRecognition, ev: Event) => void) | null;
    };
    recognition = rec;
    rec.lang = pack.speechLang;
    rec.continuous = true;
    rec.interimResults = true;

    rec.onresult = (event: SpeechRecognitionEvent) => {
      emptyEnds = 0; // audio is flowing — let the loop run as long as needed
      let interim = "";
      for (let index = event.resultIndex; index < event.results.length; index++) {
        const result = event.results[index];
        const segment = result[0]?.transcript ?? "";
        if (result.isFinal) committed += segment;
        else interim += segment;
      }
      emit(interim);
    };

    rec.onerror = (event: Event) => {
      const error = (event as unknown as { error?: string }).error;
      // Permission / service refusal is fatal — stop and report.
      if (error === "not-allowed" || error === "service-not-allowed") {
        stopped = true;
        onError?.();
        return;
      }
      // 'no-speech', 'aborted', 'network', 'audio-capture' are transient;
      // onend decides whether to keep the loop alive.
    };

    // Safari/iOS ignore `continuous` and end after each short utterance.
    // To feel present, quietly restart so the Storykeeper never re-taps.
    rec.onend = () => {
      recognition = null;
      if (stopped) return;
      if (Date.now() - startedAt > 1200) {
        emptyEnds = 0; // that was a real listening window (even if silent)
      } else {
        emptyEnds += 1;
      }
      if (emptyEnds > 6) {
        stopped = true;
        onError?.(); // the environment can't actually listen — surface it
        return;
      }
      restartTimer = window.setTimeout(() => {
        restartTimer = null;
        if (!stopped) {
          try {
            startOnce();
          } catch {
            onError?.();
          }
        }
      }, 150);
    };

    startedAt = Date.now();
    try {
      rec.start();
    } catch {
      // start() can throw if a prior instance is still winding down; the
      // pending onend will recover.
    }
  };

  startOnce();

  return {
    stop: () => {
      stopped = true;
      if (restartTimer !== null) {
        window.clearTimeout(restartTimer);
        restartTimer = null;
      }
      try {
        recognition?.stop();
      } catch {
        /* already stopped */
      }
    },
  };
}
