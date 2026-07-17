import { NextResponse } from "next/server";
import { listRecordedSessions } from "@/lib/experiment/replay";

// Protected by the EXPERIMENT_VIEWER_KEY door in middleware.
export async function GET() {
  try {
    const sessions = await listRecordedSessions();
    return NextResponse.json({ sessions });
  } catch {
    return NextResponse.json({ sessions: [] });
  }
}
