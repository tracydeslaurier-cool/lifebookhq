import { bindSession, completeSignIn } from "@/lib/identity/signin";
import { cookies } from "next/headers";
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

    // A doorway is an invitation: whoever it welcomed is, by definition,
    // admitted through the staging gate too. "Welcome home" must never be
    // followed by a locked door (defect found by the Director, 2026-07-17).
    const gateKey = process.env.STAGING_GATE_KEY;
    if (gateKey) {
      const jar = await cookies();
      jar.set("lb_gate", gateKey, {
        httpOnly: true,
        secure: true,
        sameSite: "lax",
        maxAge: 180 * 24 * 60 * 60,
        path: "/",
      });
    }

    return NextResponse.json({ returning: homecoming.returning });
  } catch {
    return NextResponse.json(
      { message: "This doorway has expired or was already opened." },
      { status: 400 },
    );
  }
}
