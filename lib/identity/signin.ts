import { db, withTransaction } from "@/lib/db";
import { bookForSession, type Session } from "@/lib/identity/session";
import { createHash, randomBytes } from "crypto";
import { cookies } from "next/headers";

/**
 * Coming home — not authentication.
 *
 * A Storykeeper asks that their story be able to find them again. A doorway
 * (single-use, short-lived) is sent to their email; opening it on any device
 * brings them home. The doorway carries the Book that asked to be found, so
 * claiming works across devices. No identity is ever created in advance, and
 * no original is ever rewritten — claiming is an INSERT (Decision 012 lineage).
 */

const TOKEN_MINUTES = 15;
const IDENTIFIED_SESSION_DAYS = 365; // long-lived on personal devices (spec §8)
const SESSION_COOKIE = "lb_session";

function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

/**
 * Dev transport: the doorway is printed to the server console, honestly
 * labelled. A real transactional sender arrives with hosting (Week 0 gate);
 * in production, an unconfigured transport refuses rather than pretends
 * (Decision 020).
 */
async function deliverDoorway(email: string, url: string): Promise<void> {
  if (process.env.EMAIL_TRANSPORT === undefined) {
    if (process.env.NODE_ENV === "production") {
      throw new Error("No email transport configured; refusing to pretend.");
    }
    console.log(
      `\n[LifeBook dev doorway] For ${email} — open on any device:\n${url}\n`,
    );
    return;
  }
  throw new Error(`Unknown EMAIL_TRANSPORT: ${process.env.EMAIL_TRANSPORT}`);
}

export async function requestSignIn(input: {
  email: string;
  session: Session;
  origin: string;
}): Promise<void> {
  const email = normalizeEmail(input.email);
  if (!email.includes("@")) {
    throw new Error("That doesn't look like an email address.");
  }

  const book = await bookForSession(input.session);
  const rawToken = randomBytes(32).toString("hex");

  await db().query(
    `insert into identity.signin_token (kind, value_hash, token_hash, expires_at, book_id)
     values ('email', $1, $2, now() + ($3 || ' minutes')::interval, $4)`,
    [sha256(email), sha256(rawToken), String(TOKEN_MINUTES), book?.bookId ?? null],
  );

  await deliverDoorway(email, `${input.origin}/welcome?token=${rawToken}`);
}

export type Homecoming = {
  storykeeperId: string;
  returning: boolean;
};

export async function completeSignIn(rawToken: string): Promise<Homecoming> {
  return withTransaction(async (tx) => {
    // Claim the doorway: single-use, unexpired.
    const tokenResult = await tx.query(
      `update identity.signin_token
          set used_at = now()
        where token_hash = $1 and used_at is null and expires_at > now()
        returning value_hash, book_id`,
      [sha256(rawToken)],
    );
    const token = tokenResult.rows[0];
    if (!token) {
      throw new Error("This doorway has expired or was already opened.");
    }

    // Find or welcome the Storykeeper — identity attaches, never pre-exists.
    const existing = await tx.query(
      `select storykeeper_id from identity.credential
        where kind = 'email' and value_hash = $1`,
      [token.value_hash],
    );
    let storykeeperId: string;
    let returning = true;
    if (existing.rows[0]) {
      storykeeperId = existing.rows[0].storykeeper_id;
    } else {
      returning = false;
      const created = await tx.query(
        `insert into identity.storykeeper default values returning id`,
      );
      storykeeperId = created.rows[0].id;
      await tx.query(
        `insert into identity.credential (storykeeper_id, kind, value_hash, verified_at)
         values ($1, 'email', $2, now())`,
        [storykeeperId, token.value_hash],
      );
    }

    // Claim the Book the doorway carried — an INSERT, never a rewrite.
    if (token.book_id) {
      const hasClaim = await tx.query(
        `select 1 from identity.book_claim where storykeeper_id = $1`,
        [storykeeperId],
      );
      const bookClaimed = await tx.query(
        `select 1 from identity.book_claim where book_id = $1`,
        [token.book_id],
      );
      if (!hasClaim.rows[0] && !bookClaimed.rows[0]) {
        await tx.query(
          `insert into identity.book_claim (book_id, storykeeper_id) values ($1, $2)`,
          [token.book_id, storykeeperId],
        );
      }
      // A Storykeeper with an existing claimed Book who arrives carrying a
      // second unclaimed one: V1 leaves the second to the unclaimed-expiry
      // window rather than silently merging lives. Logged limitation.
    }

    return { storykeeperId, returning };
  });
}

/** Bind the current device's session to the Storykeeper who came home. */
export async function bindSession(storykeeperId: string): Promise<void> {
  const jar = await cookies();
  const existingId = jar.get(SESSION_COOKIE)?.value;

  let sessionId: string | null = null;
  if (existingId) {
    const updated = await db().query(
      `update identity.session
          set storykeeper_id = $1,
              last_seen_at = now(),
              expires_at = now() + ($2 || ' days')::interval
        where id = $3 and expires_at > now()
        returning id`,
      [storykeeperId, String(IDENTIFIED_SESSION_DAYS), existingId],
    );
    sessionId = updated.rows[0]?.id ?? null;
  }
  if (!sessionId) {
    const created = await db().query(
      `insert into identity.session (storykeeper_id, expires_at)
       values ($1, now() + ($2 || ' days')::interval)
       returning id`,
      [storykeeperId, String(IDENTIFIED_SESSION_DAYS)],
    );
    sessionId = created.rows[0].id;
  }

  jar.set(SESSION_COOKIE, sessionId!, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    maxAge: IDENTIFIED_SESSION_DAYS * 24 * 60 * 60,
    path: "/",
  });
}

/** "This isn't my device" — leave nothing behind. */
export async function departSession(): Promise<void> {
  const jar = await cookies();
  const sessionId = jar.get(SESSION_COOKIE)?.value;
  if (sessionId) {
    await db().query(
      `update identity.session set expires_at = now() where id = $1`,
      [sessionId],
    );
  }
  jar.delete(SESSION_COOKIE);
}
