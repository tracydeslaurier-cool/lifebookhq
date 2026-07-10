import type { VoicePack } from "./types";

/**
 * Placeholder voice packs — pending native-speaker review.
 * Strings are provisional machine translations; do not ship as reviewed.
 */
export const placeholderVoicePacks: VoicePack[] = [
  {
    id: "de",
    locale: "de",
    nativeName: "Deutsch",
    speechLang: "de-DE",
    status: "placeholder",
    strings: {
      begin: "Beginnen",
      touchWordYouUnderstand:
        "Berühren Sie das Wort, das Sie verstehen.",
      whatsOnYourMind: "Was beschäftigt Sie heute?",
      inputPlaceholder: "Hier schreiben…",
      activateMicrophone: "Sprechen",
      deactivateMicrophone: "Zuhören beenden",
      wordmark: "LifeBook",
    },
  },
  {
    id: "es",
    locale: "es",
    nativeName: "Español",
    speechLang: "es-ES",
    status: "placeholder",
    strings: {
      begin: "Comenzar",
      touchWordYouUnderstand: "Toca la palabra que entiendes.",
      whatsOnYourMind: "¿Qué tienes en mente hoy?",
      inputPlaceholder: "Escribe aquí…",
      activateMicrophone: "Hablar",
      deactivateMicrophone: "Dejar de escuchar",
      wordmark: "LifeBook",
    },
  },
  {
    id: "pl",
    locale: "pl",
    nativeName: "Polski",
    speechLang: "pl-PL",
    status: "placeholder",
    strings: {
      begin: "Zacznij",
      touchWordYouUnderstand: "Dotknij słowa, które rozumiesz.",
      whatsOnYourMind: "Co masz dziś na myśli?",
      inputPlaceholder: "Pisz tutaj…",
      activateMicrophone: "Mów",
      deactivateMicrophone: "Zatrzymaj nasłuchiwanie",
      wordmark: "LifeBook",
    },
  },
  {
    id: "it",
    locale: "it",
    nativeName: "Italiano",
    speechLang: "it-IT",
    status: "placeholder",
    strings: {
      begin: "Inizia",
      touchWordYouUnderstand: "Tocca la parola che capisci.",
      whatsOnYourMind: "Cosa hai in mente oggi?",
      inputPlaceholder: "Scrivi qui…",
      activateMicrophone: "Parla",
      deactivateMicrophone: "Smetti di ascoltare",
      wordmark: "LifeBook",
    },
  },
];
