import { enVoicePack, getVoicePack } from "@/lib/voice-packs";
import type { VoicePack, VoicePackId } from "@/lib/voice-packs/types";

const LOCALE_ALIASES: Record<string, VoicePackId> = {
  en: "en",
  fr: "fr",
  uk: "uk",
  ua: "uk",
  ru: "ru",
  de: "de",
  es: "es",
  pl: "pl",
  it: "it",
};

const SUPPORTED_IDS = new Set<VoicePackId>([
  "en",
  "fr",
  "uk",
  "ru",
  "de",
  "es",
  "pl",
  "it",
]);

function normalizeLanguageTag(tag: string): string {
  return tag.trim().toLowerCase().replace(/_/g, "-");
}

function resolvePackId(languageTag: string): VoicePackId | null {
  const normalized = normalizeLanguageTag(languageTag);
  const [language, region] = normalized.split("-");

  if (language === "uk" || region === "ua") {
    return "uk";
  }

  const direct = LOCALE_ALIASES[language];
  if (direct && SUPPORTED_IDS.has(direct)) {
    return direct;
  }

  return null;
}

export function findClosestVoicePack(
  browserLanguages: readonly string[],
): VoicePack {
  for (const tag of browserLanguages) {
    const packId = resolvePackId(tag);
    if (packId) {
      return getVoicePack(packId);
    }
  }

  return enVoicePack;
}

export function detectBrowserVoicePack(): VoicePack {
  if (typeof navigator === "undefined") {
    return enVoicePack;
  }

  const languages =
    navigator.languages.length > 0
      ? navigator.languages
      : [navigator.language];

  return findClosestVoicePack(languages);
}

export const VOICE_PACK_STORAGE_KEY = "lifebook-voice-pack";

export function readStoredVoicePackId(): VoicePackId | null {
  if (typeof sessionStorage === "undefined") {
    return null;
  }

  const stored = sessionStorage.getItem(VOICE_PACK_STORAGE_KEY);
  if (!stored || !SUPPORTED_IDS.has(stored as VoicePackId)) {
    return null;
  }

  return stored as VoicePackId;
}

export function storeVoicePackId(id: VoicePackId): void {
  sessionStorage.setItem(VOICE_PACK_STORAGE_KEY, id);
}

export const ARRIVAL_SPOKEN_KEY = "lifebook-arrival-spoken";

export function hasSpokenArrival(): boolean {
  if (typeof sessionStorage === "undefined") {
    return false;
  }

  return sessionStorage.getItem(ARRIVAL_SPOKEN_KEY) === "1";
}

export function markArrivalSpoken(): void {
  sessionStorage.setItem(ARRIVAL_SPOKEN_KEY, "1");
}

export const BEGIN_COMPLETED_KEY = "lifebook-begin-completed";

export function hasCompletedBegin(): boolean {
  if (typeof sessionStorage === "undefined") {
    return false;
  }

  return sessionStorage.getItem(BEGIN_COMPLETED_KEY) === "1";
}

export function markBeginCompleted(): void {
  sessionStorage.setItem(BEGIN_COMPLETED_KEY, "1");
}

/** The server-side conversation this arrival belongs to. */
export const CONVERSATION_ID_KEY = "lifebook-conversation-id";

export function readStoredConversationId(): string | null {
  if (typeof sessionStorage === "undefined") {
    return null;
  }
  return sessionStorage.getItem(CONVERSATION_ID_KEY);
}

export function storeConversationId(id: string): void {
  sessionStorage.setItem(CONVERSATION_ID_KEY, id);
}

export function clearStoredConversationId(): void {
  sessionStorage.removeItem(CONVERSATION_ID_KEY);
}

/** Unfinished draft only — never used for submitted thoughts. */
export const DRAFT_THOUGHT_KEY = "lifebook-draft-thought";

/** Legacy key from earlier sprints — cleared on read, never restored. */
const LEGACY_FIRST_THOUGHT_KEY = "lifebook-first-thought";

function readDraftFromStorage(): string | null {
  const stored = sessionStorage.getItem(DRAFT_THOUGHT_KEY);
  if (!stored) {
    return null;
  }

  const trimmed = stored.trim();
  return trimmed.length > 0 ? stored : null;
}

function clearLegacySubmittedThought(): void {
  const legacy = sessionStorage.getItem(LEGACY_FIRST_THOUGHT_KEY);
  if (!legacy) {
    return;
  }

  sessionStorage.removeItem(LEGACY_FIRST_THOUGHT_KEY);
}

/** Stable getSnapshot for useSyncExternalStore — returns a primitive string. */
export function readStoredDraftText(): string | null {
  if (typeof sessionStorage === "undefined") {
    return null;
  }

  clearLegacySubmittedThought();

  return readDraftFromStorage();
}

export function storeDraftText(transcript: string): void {
  sessionStorage.setItem(DRAFT_THOUGHT_KEY, transcript);
}

export function clearDraftText(): void {
  sessionStorage.removeItem(DRAFT_THOUGHT_KEY);
}
