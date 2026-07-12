import type { VoicePackId } from "@/lib/voice-packs/types";
import type { CompanionReply } from "../types";
import { enFirstResponse } from "./en";
import { frFirstResponse } from "./fr";
import { ruFirstResponse } from "./ru";
import { ukFirstResponse } from "./uk";

const firstResponses: Partial<Record<VoicePackId, CompanionReply>> = {
  en: enFirstResponse,
  fr: frFirstResponse,
  uk: ukFirstResponse,
  ru: ruFirstResponse,
};

export function getFirstCompanionResponse(packId: VoicePackId): CompanionReply {
  return firstResponses[packId] ?? enFirstResponse;
}
