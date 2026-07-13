import { ensureSession } from "@/lib/identity/session";
import { requestSignIn } from "@/lib/identity/signin";
import { NextResponse } from "next/server";

/**
 * POST /api/identity/begin — "let your story find you again."
 * Always 202: whether or not the email is known, the answer is the same
 * (no account enumeration; also, there are no "accounts" — only doorways).
 */
export async function POST(request: Request) {
  let email: unknown;
  try {
    email = (await request.json())?.email;
  } catch {
    email = null;
  }
  if (typeof email !== "string" || !email.includes("@")) {
    return NextResponse.json(
      { message: "That doesn't look like an email address." },
      { status: 400 },
    );
  }

  const session = await ensureSession();
  const origin = new URL(request.url).origin;

  try {
    await requestSignIn({ email, session, origin });
  } catch (error) {
    // Delivery failures are logged server-side; the Storykeeper-facing
    // answer stays calm and identical either way.
    console.error("[identity/begin]", error);
  }

  return NextResponse.json(
    { message: "A doorway is on its way to your email." },
    { status: 202 },
  );
}
