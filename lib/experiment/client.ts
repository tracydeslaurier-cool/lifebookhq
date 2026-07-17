"use client";

import type { ExperimentVariant } from "@/lib/experiment/record";

/**
 * Threshold experiment — client-side instrumentation.
 *
 * Low-level primitives only: emit content-free events, and record masked
 * screen interactions. The tracking policy (what counts as "first
 * interaction", timers, once-only guards) lives in ThresholdExperience.
 *
 * Nothing here ever sends the Storykeeper's words. Events carry timings and
 * choices; the recorder masks all text and inputs in the browser before a
 * single byte leaves the device.
 */

const EVENT_URL = "/api/experiment/event";
const RECORDING_URL = "/api/experiment/recording";
const FLUSH_INTERVAL_MS = 5000;

export type { ExperimentVariant };

export function emitEvent(
  variant: ExperimentVariant,
  eventType: string,
  detail?: Record<string, unknown>,
): void {
  const body = JSON.stringify({ variant, eventType, detail });
  try {
    void fetch(EVENT_URL, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body,
      keepalive: true,
    }).catch(() => {});
  } catch {
    /* instrumentation must never break the experience */
  }
}

export function emitBeacon(
  variant: ExperimentVariant,
  eventType: string,
  detail?: Record<string, unknown>,
): void {
  const body = JSON.stringify({ variant, eventType, detail });
  try {
    if (typeof navigator !== "undefined" && navigator.sendBeacon) {
      navigator.sendBeacon(EVENT_URL, new Blob([body], { type: "application/json" }));
    } else {
      emitEvent(variant, eventType, detail);
    }
  } catch {
    /* ignore */
  }
}

/**
 * Begin masked screen-interaction recording. Returns a stop() that flushes
 * whatever remains. Safe to call once per session; returns a no-op stopper if
 * rrweb cannot load or the environment cannot record.
 */
export async function startMaskedRecording(
  variant: ExperimentVariant,
): Promise<() => void> {
  if (typeof window === "undefined") return () => {};

  let buffer: unknown[] = [];
  let seq = 0;

  const flush = (useBeacon = false) => {
    if (buffer.length === 0) return;
    const batch = buffer;
    buffer = [];
    const body = JSON.stringify({ variant, seq: seq++, events: batch });
    try {
      if (useBeacon && navigator.sendBeacon) {
        navigator.sendBeacon(RECORDING_URL, new Blob([body], { type: "application/json" }));
      } else {
        void fetch(RECORDING_URL, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body,
          keepalive: true,
        }).catch(() => {});
      }
    } catch {
      /* drop the batch rather than break the experience */
    }
  };

  let stopRecorder: (() => void) | undefined;
  try {
    const mod = await import("rrweb");
    // Loose cast: masking-option names vary across rrweb versions, and we want
    // maskAllText regardless. Behaviour and layout only — never the words.
    const record = mod.record as (opts: unknown) => (() => void) | undefined;
    stopRecorder = record({
      emit: (event: unknown) => buffer.push(event),
      maskAllInputs: true,
      maskAllText: true,
      maskTextFn: () => "•",
      recordCanvas: false,
      collectFonts: false,
    });
  } catch {
    return () => {};
  }

  const interval = window.setInterval(() => flush(false), FLUSH_INTERVAL_MS);
  const onVisibility = () => {
    if (document.visibilityState === "hidden") flush(true);
  };
  document.addEventListener("visibilitychange", onVisibility);

  return () => {
    window.clearInterval(interval);
    document.removeEventListener("visibilitychange", onVisibility);
    try {
      stopRecorder?.();
    } catch {
      /* ignore */
    }
    flush(true);
  };
}
