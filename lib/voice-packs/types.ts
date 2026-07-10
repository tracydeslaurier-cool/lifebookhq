export type VoicePackStatus = "reviewed" | "placeholder";

export type VoicePackId =
  | "en"
  | "fr"
  | "uk"
  | "ru"
  | "de"
  | "es"
  | "pl"
  | "it";

export type VoicePackStrings = {
  begin: string;
  touchWordYouUnderstand: string;
  whatsOnYourMind: string;
  inputPlaceholder: string;
  activateMicrophone: string;
  deactivateMicrophone: string;
  wordmark: string;
};

export type VoicePack = {
  id: VoicePackId;
  locale: string;
  nativeName: string;
  speechLang: string;
  status: VoicePackStatus;
  strings: VoicePackStrings;
};
