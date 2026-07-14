import { db } from "@/lib/db";

/**
 * Reading the Book — purpose-scoped, audited access (Decision 010).
 * Contextus's instrument in slice 1: with one Storykeeper and few
 * conversations, the smallest correct retrieval is the whole Book.
 */

export type BookTurn = {
  speaker: "storykeeper" | "companion";
  text: string;
  at: string;
  conversationId: string;
};

export async function recordAccess(input: {
  actor: string;
  purpose: "conversation" | "homecoming" | "export";
  scope: string;
}): Promise<void> {
  await db().query(
    `insert into audit.access_event (actor, purpose, scope) values ($1, $2, $3)`,
    [input.actor, input.purpose, input.scope],
  );
}

export async function readConversation(
  conversationId: string,
): Promise<BookTurn[]> {
  const result = await db().query(
    `select 'storykeeper' as speaker, original_text as text, submitted_at as at,
            conversation_id, seq
       from entrusted.moment where conversation_id = $1
     union all
     select 'companion', text, spoken_at, conversation_id, seq
       from entrusted.companion_turn where conversation_id = $1
     order by at asc, seq asc`,
    [conversationId],
  );
  return result.rows.map((row) => ({
    speaker: row.speaker,
    text: row.text,
    at: row.at,
    conversationId: row.conversation_id,
  }));
}

export async function readBook(bookId: string): Promise<BookTurn[]> {
  const result = await db().query(
    `select t.speaker, t.text, t.at, t.conversation_id
       from (
         select 'storykeeper' as speaker, m.original_text as text,
                m.submitted_at as at, m.conversation_id, m.seq
           from entrusted.moment m
           join entrusted.conversation c on c.id = m.conversation_id
          where c.book_id = $1
         union all
         select 'companion', ct.text, ct.spoken_at, ct.conversation_id, ct.seq
           from entrusted.companion_turn ct
           join entrusted.conversation c on c.id = ct.conversation_id
          where c.book_id = $1
       ) t
      order by t.at asc, t.seq asc`,
    [bookId],
  );
  return result.rows.map((row) => ({
    speaker: row.speaker,
    text: row.text,
    at: row.at,
    conversationId: row.conversation_id,
  }));
}

/**
 * The whole story of a recognized Storykeeper: every Moment and Companion
 * Turn across ALL Books they have claimed. Ephemeral sessions may have
 * scattered one life across several Books; the person is one, so the
 * remembering is one (Decision 012: the account is not the Book).
 */
export async function readStory(storykeeperId: string): Promise<BookTurn[]> {
  const result = await db().query(
    `select t.speaker, t.text, t.at, t.conversation_id
       from (
         select 'storykeeper' as speaker, m.original_text as text,
                m.submitted_at as at, m.conversation_id, m.seq
           from entrusted.moment m
           join entrusted.conversation c on c.id = m.conversation_id
           join identity.book_claim bc on bc.book_id = c.book_id
          where bc.storykeeper_id = $1
         union all
         select 'companion', ct.text, ct.spoken_at, ct.conversation_id, ct.seq
           from entrusted.companion_turn ct
           join entrusted.conversation c on c.id = ct.conversation_id
           join identity.book_claim bc on bc.book_id = c.book_id
          where bc.storykeeper_id = $1
       ) t
      order by t.at asc, t.seq asc`,
    [storykeeperId],
  );
  return result.rows.map((row) => ({
    speaker: row.speaker,
    text: row.text,
    at: row.at,
    conversationId: row.conversation_id,
  }));
}

export async function conversationBelongsToBook(
  conversationId: string,
  bookId: string,
): Promise<boolean> {
  const result = await db().query(
    `select 1 from entrusted.conversation where id = $1 and book_id = $2`,
    [conversationId, bookId],
  );
  return result.rowCount === 1;
}
