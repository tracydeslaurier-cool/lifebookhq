import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { db } from "@/lib/db";
import { ensureBook } from "@/lib/identity/session";

/**
 * POST /api/experiment/reset — a true first arrival.
 *
 * The threshold experiment must never land in an existing Storykeeper's
 * conversation. This mints a fresh anonymous session (replacing the session
 * cookie on this device) and an empty Book, so every entry to /begin/* is a
 * stranger arriving for the first time. The previous session's data is
 * untouched in the Archive; only this browser's pointer is renewed.
 */

const SESSION_COOKIE = "lb_session";
const ANONYMOUS_SESSION_DAYS = 30;

export async function POST() {
  try {
    const created = await db().query(
      `insert into identity.session (expires_at)
       values (now() + ($1 || ' days')::interval)
       returning id`,
      [String(ANONYMOUS_SESSION_DAYS)],
    );
    const id = created.rows[0].id as string;

    const jar = await cookies();
    jar.set(SESSION_COOKIE, id, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      maxAge: ANONYMOUS_SESSION_DAYS * 24 * 60 * 60,
      path: "/",
    });

    await ensureBook({ id, storykeeperId: null });
    return NextResponse.json({ ok: true });
  } catch {
    return NextResponse.json({ ok: false }, { status: 200 });
  }
}
