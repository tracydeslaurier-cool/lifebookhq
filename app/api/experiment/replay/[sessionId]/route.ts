import { NextResponse, type NextRequest } from "next/server";
import { getSessionEvents } from "@/lib/experiment/replay";

// Protected by the EXPERIMENT_VIEWER_KEY door in middleware.
export async function GET(
  _request: NextRequest,
  context: { params: Promise<{ sessionId: string }> },
) {
  const { sessionId } = await context.params;
  try {
    const events = await getSessionEvents(sessionId);
    return NextResponse.json({ events });
  } catch {
    return NextResponse.json({ events: [] });
  }
}
