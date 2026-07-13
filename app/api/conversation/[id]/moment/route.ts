import { entrustMoment, preserveCompanionTurn } from "@/lib/archive/archive";
import {
  conversationBelongsToBook,
  readBook,
  recordAccess,
} from "@/lib/archive/reading";
import { companionProvider } from "@/lib/companion/engine";
import { bookForSession, currentSession } from "@/lib/identity/session";
import { NextResponse } from "next/server";

/**
 * POST /api/conversation/:id/moment — the Archive's one door, over HTTP.
 * Entrusts one intentional contribution, then the Companion responds.
 */
export async function POST(
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
  let language = "en";
  try {
    const body = await request.json();
    text = body?.text;
    if (typeof body?.language === "string") language = body.language;
  } catch {
    return NextResponse.json(
      { message: "We couldn't read that just now." },
      { status: 400 },
    );
  }
  if (typeof text !== "string" || text.trim().length === 0) {
    return NextResponse.json(
      { message: "There was nothing to keep yet." },
      { status: 400 },
    );
  }

  const moment = await entrustMoment({
    conversationId,
    contributorId: book.contributorId,
    originalText: text,
    originalLanguage: language,
    inputMode: "text",
  });

  await recordAccess({
    actor: "conversation-engine",
    purpose: "conversation",
    scope: book.bookId,
  });
  const record = await readBook(book.bookId);
  const composition = await companionProvider().compose({
    book: record,
    latest: text,
    purpose: "conversation",
    language,
  });

  const turn = await preserveCompanionTurn({
    conversationId,
    text: composition.text,
    language,
    modelId: composition.modelId,
  });

  return NextResponse.json({
    momentId: moment.id,
    companion: { text: composition.text, turnId: turn.id },
  });
}
