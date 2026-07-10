import { enVoicePack } from "./en";
import { frVoicePack } from "./fr";
import { placeholderVoicePacks } from "./placeholders";
import { ruVoicePack } from "./ru";
import type { VoicePack, VoicePackId } from "./types";
import { ukVoicePack } from "./uk";

export const reviewedVoicePacks: VoicePack[] = [
  enVoicePack,
  frVoicePack,
  ukVoicePack,
  ruVoicePack,
];

export const allVoicePacks: VoicePack[] = [
  ...reviewedVoicePacks,
  ...placeholderVoicePacks,
];

const voicePackById = new Map<VoicePackId, VoicePack>(
  allVoicePacks.map((pack) => [pack.id, pack]),
);

export function getVoicePack(id: VoicePackId): VoicePack {
  return voicePackById.get(id) ?? enVoicePack;
}

export function getReviewedVoicePacks(): VoicePack[] {
  return reviewedVoicePacks;
}

export function getAllVoicePacks(): VoicePack[] {
  return allVoicePacks;
}

export { enVoicePack };
