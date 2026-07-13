import { conversationBelongsToBook } from "@/lib/archive/reading";
import { db } from "@/lib/db";
import { bookForSession, currentSession } from "@/lib/identity/session";
import { NextResponse } from "next/server";

const DRAFT_EXPIRY_DAYS = 30;

/**
 * PUT /api/conversation/:id/draft — provisional autosave.
 * An uncommitted thought held server-side so a closed tab loses nothing
 * (spec §15.3). Provisional, not entrusted: mutable, expiring, private.
 */
export async function PUT(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id: conversationId } = await context.params;

  const session = await currentSession();
  const book = session ? await bookForSession(session) : null;
  if (!session || !book) {
    return NextResponse.json(
      { message: "We couldn't find your story from here." },
      { status: 401 },
    );
  }
  if (!(await conversationBelongsToBook(conversationId, book.bookId))) {
    return NextResponse.json(
      { message: "That conversation isn't part of this story." },
      { status: 403 },
    );
  }

  let text: unknown;
  try {
    text = (await request.json())?.text;
  } catch {
    return NextResponse.json({ message: "We couldn't read that." }, { status: 400 });
  }
  if (typeof text !== "string") {
    return NextResponse.json({ message: "We couldn't read that." }, { status: 400 });
  }

  if (text.trim().length === 0) {
    await db().query(
      `delete from provisional.draft_contribution where conversation_id = $1`,
      [conversationId],
    );
    return new NextResponse(null, { status: 204 });
  }

  await db().query(
    `insert into provisional.draft_contribution (conversation_id, text, expires_at)
     values ($1, $2, now() + ($3 || ' days')::interval)
     on conflict (conversation_id)
     do update set text = excluded.text, updated_at = now(), expires_at = excluded.expires_at`,
    [conversationId, text, String(DRAFT_EXPIRY_DAYS)],
  );

  return new NextResponse(null, { status: 204 });
}

/** GET /api/conversation/:id/draft — restore an uncommitted thought. */
export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id: conversationId } = await context.params;

  const session = await currentSession();
  const book = session ? await bookForSession(session) : null;
  if (!session || !book) {
    return NextResponse.json(
      { message: "We couldn't find your story from here." },
      { status: 401 },
    );
  }
  if (!(await conversationBelongsToBook(conversationId, book.bookId))) {
    return NextResponse.json(
      { message: "That conversation isn't part of this story." },
      { status: 403 },
    );
  }

  const result = await db().query(
    `select text from provisional.draft_contribution
      where conversation_id = $1 and expires_at > now()`,
    [conversationId],
  );

  return NextResponse.json({ text: result.rows[0]?.text ?? null });
}
