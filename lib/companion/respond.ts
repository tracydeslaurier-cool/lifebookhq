import { getFirstCompanionResponse } from "./responses";
import type { CompanionReply, CompanionRequest } from "./types";

/**
 * Temporary Companion service — handcrafted responses until intelligence is introduced.
 * The thought is accepted for future use but not read or summarized in Scene 2.
 */
export function companionRespond(request: CompanionRequest): CompanionReply {
  if (request.turn === "first") {
    return getFirstCompanionResponse(request.pack.id);
  }

  return getFirstCompanionResponse(request.pack.id);
}
