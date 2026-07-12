import type { VoicePack } from "@/lib/voice-packs/types";

export type CompanionReply = {
  opening: string;
  question: string;
  text: string;
};

export type CompanionRequest = {
  thought: string;
  pack: VoicePack;
  turn: "first";
};
