import { bindSession, completeSignIn } from "@/lib/identity/signin";
import { NextResponse } from "next/server";

/** POST /api/identity/complete — the doorway opens; the Storykeeper is home. */
export async function POST(request: Request) {
  let token: unknown;
  try {
    token = (await request.json())?.token;
  } catch {
    token = null;
  }
  if (typeof token !== "string" || token.length < 32) {
    return NextResponse.json(
      { message: "This doorway has expired or was already opened." },
      { status: 400 },
    );
  }

  try {
    const homecoming = await completeSignIn(token);
    await bindSession(homecoming.storykeeperId);
    return NextResponse.json({ returning: homecoming.returning });
  } catch {
    return NextResponse.json(
      { message: "This doorway has expired or was already opened." },
      { status: 400 },
    );
  }
}
