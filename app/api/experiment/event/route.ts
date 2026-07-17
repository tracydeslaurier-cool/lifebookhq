import { NextResponse, type NextRequest } from "next/server";
import { isVariant, recordExperimentEvent } from "@/lib/experiment/record";

/**
 * POST /api/experiment/event — one content-free threshold observation.
 * Accepts JSON from fetch() or navigator.sendBeacon(). Instrumentation must
 * never break the experience, so failures are swallowed after validation.
 */
export async function POST(request: NextRequest) {
  let body: { variant?: unknown; eventType?: unknown; detail?: unknown };
  try {
    body = JSON.parse(await request.text());
  } catch {
    return NextResponse.json({ error: "bad json" }, { status: 400 });
  }

  if (!isVariant(body.variant) || typeof body.eventType !== "string") {
    return NextResponse.json({ error: "bad request" }, { status: 400 });
  }

  const detail =
    body.detail && typeof body.detail === "object" && !Array.isArray(body.detail)
      ? (body.detail as Record<string, unknown>)
      : undefined;

  try {
    await recordExperimentEvent({
      variant: body.variant,
      eventType: body.eventType,
      detail,
    });
  } catch {
    // Never surface instrumentation failure to the Storykeeper.
  }

  return NextResponse.json({ ok: true });
}
