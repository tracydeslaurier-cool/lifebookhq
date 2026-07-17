import { NextResponse, type NextRequest } from "next/server";
import { isVariant, recordSessionRecording } from "@/lib/experiment/record";

/**
 * POST /api/experiment/recording — a batch of masked rrweb events.
 * The client masks all text and inputs before sending: behaviour only, never
 * the Storykeeper's words. Accepts fetch() or navigator.sendBeacon() bodies.
 */
export async function POST(request: NextRequest) {
  let body: { variant?: unknown; seq?: unknown; events?: unknown };
  try {
    body = JSON.parse(await request.text());
  } catch {
    return NextResponse.json({ error: "bad json" }, { status: 400 });
  }

  if (!isVariant(body.variant) || !Array.isArray(body.events)) {
    return NextResponse.json({ error: "bad request" }, { status: 400 });
  }

  try {
    await recordSessionRecording({
      variant: body.variant,
      seq: typeof body.seq === "number" ? body.seq : 0,
      events: body.events,
    });
  } catch {
    // Never surface instrumentation failure to the Storykeeper.
  }

  return NextResponse.json({ ok: true });
}
