import { db, withTransaction } from "@/lib/db";
import { cookies } from "next/headers";

/**
 * Identity & Continuity — sessions.
 *
 * A session may be anonymous (storykeeper_id NULL). An anonymous session is a
 * real session with real protections; it is never a fictional Storykeeper
 * (Director's decision, 2026-07-12). Identity, when it arrives, is attached —
 * never faked in advance.
 */

const SESSION_COOKIE = "lb_session";
const ANONYMOUS_SESSION_DAYS = 30; // matches the unclaimed-Book retention window
// Identified sessions (365 days, spec §8) arrive with the Week 3 claim flow.

export type Session = {
  id: string;
  storykeeperId: string | null;
};

export async function currentSession(): Promise<Session | null> {
  const jar = await cookies();
  const sessionId = jar.get(SESSION_COOKIE)?.value;
  if (!sessionId) return null;

  const result = await db().query(
    `update identity.session
        set last_seen_at = now()
      where id = $1 and expires_at > now()
      returning id, storykeeper_id`,
    [sessionId],
  );
  const row = result.rows[0];
  if (!row) return null;
  return { id: row.id, storykeeperId: row.storykeeper_id };
}

export async function ensureSession(): Promise<Session> {
  const existing = await currentSession();
  if (existing) return existing;

  const result = await db().query(
    `insert into identity.session (expires_at)
     values (now() + ($1 || ' days')::interval)
     returning id`,
    [String(ANONYMOUS_SESSION_DAYS)],
  );
  const id: string = result.rows[0].id;

  const jar = await cookies();
  jar.set(SESSION_COOKIE, id, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    maxAge: ANONYMOUS_SESSION_DAYS * 24 * 60 * 60,
    path: "/",
  });

  return { id, storykeeperId: null };
}

/**
 * The Book an anonymous or identified session is keeping.
 * Anonymous: found via session_book. Identified: found via book_claim.
 */
export async function bookForSession(
  session: Session,
): Promise<{ bookId: string; contributorId: string } | null> {
  if (session.storykeeperId) {
    const result = await db().query(
      `select c.book_id, c.id as contributor_id
         from identity.book_claim bc
         join identity.contributor c on c.book_id = bc.book_id
        where bc.storykeeper_id = $1
        order by bc.claimed_at asc
        limit 1`,
      [session.storykeeperId],
    );
    const row = result.rows[0];
    return row ? { bookId: row.book_id, contributorId: row.contributor_id } : null;
  }

  const result = await db().query(
    `select sb.book_id, c.id as contributor_id
       from identity.session_book sb
       join identity.contributor c on c.book_id = sb.book_id
      where sb.session_id = $1
      order by sb.created_at asc
      limit 1`,
    [session.id],
  );
  const row = result.rows[0];
  return row ? { bookId: row.book_id, contributorId: row.contributor_id } : null;
}

/**
 * First arrival: an unclaimed Book, an anonymous Contributor, linked to this
 * session so the story can be found again — and, one day, claimed.
 */
export async function ensureBook(
  session: Session,
): Promise<{ bookId: string; contributorId: string }> {
  const existing = await bookForSession(session);
  if (existing) return existing;

  return withTransaction(async (tx) => {
    const book = await tx.query(
      `insert into identity.book default values returning id`,
    );
    const bookId: string = book.rows[0].id;

    const contributor = await tx.query(
      `insert into identity.contributor (book_id, storykeeper_id, role)
       values ($1, $2, 'owner') returning id`,
      [bookId, session.storykeeperId],
    );

    await tx.query(
      `insert into identity.session_book (session_id, book_id) values ($1, $2)`,
      [session.id, bookId],
    );

    if (session.storykeeperId) {
      await tx.query(
        `insert into identity.book_claim (book_id, storykeeper_id) values ($1, $2)`,
        [bookId, session.storykeeperId],
      );
    }

    return { bookId, contributorId: contributor.rows[0].id as string };
  });
}
