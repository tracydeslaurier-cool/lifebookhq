import { db } from "@/lib/db";
import { currentSession } from "@/lib/identity/session";

/**
 * Threshold experiment — server-side instrumentation.
 *
 * Observations, not analytics. The session_id is resolved here, from the
 * anonymous session cookie, and never trusted from the client. Detail is
 * capped and content-free by contract (the client sends timings and choices,
 * never the Storykeeper's words).
 */

export type ExperimentVariant = "a" | "b" | "c";

const VALID_VARIANTS = new Set<ExperimentVariant>(["a", "b", "c"]);
const MAX_DETAIL_BYTES = 4096;
const MAX_RECORDING_BYTES = 1_500_000; // a batch of masked rrweb events

export function isVariant(value: unknown): value is ExperimentVariant {
  return typeof value === "string" && VALID_VARIANTS.has(value as ExperimentVariant);
}

export async function recordExperimentEvent(input: {
  variant: ExperimentVariant;
  eventType: string;
  detail?: Record<string, unknown>;
}): Promise<void> {
  const session = await currentSession().catch(() => null);
  await db().query(
    `insert into audit.experiment_event (variant, session_id, event_type, detail)
     values ($1, $2, $3, $4)`,
    [input.variant, session?.id ?? null, input.eventType, safeJson(input.detail, MAX_DETAIL_BYTES)],
  );
}

export async function recordSessionRecording(input: {
  variant: ExperimentVariant;
  seq: number;
  events: unknown[];
}): Promise<void> {
  const session = await currentSession().catch(() => null);
  const events = safeJson(input.events, MAX_RECORDING_BYTES);
  if (events === null) return; // oversized batch — drop rather than truncate a story's shape
  await db().query(
    `insert into audit.session_recording (variant, session_id, seq, events)
     values ($1, $2, $3, $4)`,
    [input.variant, session?.id ?? null, Math.trunc(input.seq) || 0, events],
  );
}

function safeJson(value: unknown, maxBytes: number): string | null {
  if (value === undefined || value === null) return "{}";
  try {
    const json = JSON.stringify(value);
    if (json.length > maxBytes) return null;
    return json;
  } catch {
    return null;
  }
}
