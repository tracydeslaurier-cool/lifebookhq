import { readBook, recordAccess } from "@/lib/archive/reading";
import { companionProvider } from "@/lib/companion/engine";
import { bookForSession, currentSession } from "@/lib/identity/session";
import { NextResponse } from "next/server";

/**
 * GET /api/home — coming home.
 *
 * Identified and recognized: a greeting composed over the Book, which may
 * weave one earlier memory, naturally — never announced ("Last time you
 * mentioned…", not "According to my memory…").
 * Anonymous: not recognized; the threshold plays.
 */
export async function GET() {
  const session = await currentSession();
  if (!session || !session.storykeeperId) {
    return NextResponse.json({ recognized: false });
  }

  const book = await bookForSession(session);
  if (!book) {
    return NextResponse.json({ recognized: false });
  }

  await recordAccess({
    actor: "conversation-engine",
    purpose: "homecoming",
    scope: book.bookId,
  });
  const record = await readBook(book.bookId);
  const composition = await companionProvider().compose({
    book: record,
    latest: null,
    purpose: "homecoming",
    language: "en",
  });

  return NextResponse.json({
    recognized: true,
    greeting: composition.text,
  });
}
