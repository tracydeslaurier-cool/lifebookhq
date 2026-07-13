import {
  conversationBelongsToBook,
  readConversation,
} from "@/lib/archive/reading";
import { bookForSession, currentSession } from "@/lib/identity/session";
import { NextResponse } from "next/server";

/**
 * GET /api/conversation/:id — the transcript, for resuming a scene.
 */
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

  const turns = await readConversation(conversationId);
  return NextResponse.json({ turns });
}
