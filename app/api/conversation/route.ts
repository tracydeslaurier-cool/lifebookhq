import { beginConversation } from "@/lib/archive/archive";
import { db } from "@/lib/db";
import { ensureBook, ensureSession } from "@/lib/identity/session";
import { NextResponse } from "next/server";

/**
 * POST /api/conversation — begin, or come back to (anonymous permitted).
 *
 * The conversation pointer lives server-side, behind the session cookie —
 * never in per-tab browser storage. A closed tab is not a closed door:
 * returning finds the same conversation and any unfinished thought waiting
 * in it. Continuity, not just persistence.
 */
export async function POST(request: Request) {
  let language = "en";
  try {
    const body = await request.json();
    if (typeof body?.language === "string" && body.language.length <= 10) {
      language = body.language;
    }
  } catch {
    // no body — arrival defaults apply
  }

  const session = await ensureSession();
  const { bookId, contributorId } = await ensureBook(session);

  // Resume the Book's most recent conversation if one exists.
  const existing = await db().query(
    `select c.id, c.language, d.text as draft
       from entrusted.conversation c
       left join provisional.draft_contribution d
         on d.conversation_id = c.id and d.expires_at > now()
      where c.book_id = $1
      order by c.began_at desc
      limit 1`,
    [bookId],
  );
  const row = existing.rows[0];
  if (row) {
    return NextResponse.json(
      { conversationId: row.id, language: row.language, draft: row.draft ?? null },
      { status: 200 },
    );
  }

  const { conversationId } = await beginConversation({
    bookId,
    contributorId,
    language,
  });

  return NextResponse.json(
    { conversationId, language, draft: null },
    { status: 201 },
  );
}
