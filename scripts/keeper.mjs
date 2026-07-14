import { Pool } from "pg";

/**
 * The Keeper — LifeBook's privileged expiry job.
 *
 * The sole exception to immutability is deletion, and this is its only door.
 * Runs as the lifebook_keeper role (never lifebook_app), on its own
 * connection string, with these disciplines:
 *
 *   - DRY-RUN BY DEFAULT. Nothing is deleted unless --execute is passed.
 *   - Every execution writes audit.deletion_event rows.
 *   - It deletes only what was never entrusted to a person:
 *       1. unclaimed Books past the retention window (30 days, spec §8) —
 *          "we do not keep what was not entrusted"
 *       2. expired provisional drafts (uncommitted thoughts past expiry)
 *       3. spent or expired doorway tokens older than 7 days
 *   - It can NEVER touch a claimed Book: the claim check is inside the same
 *     transaction as the delete.
 *
 * Usage:
 *   node --env-file=.env.local scripts/keeper.mjs            # dry run
 *   node --env-file=.env.local scripts/keeper.mjs --execute  # for real
 */

const UNCLAIMED_BOOK_DAYS = 30;
const SPENT_TOKEN_DAYS = 7;

const execute = process.argv.includes("--execute");
const forgetIndex = process.argv.indexOf("--forget");
const forgetStorykeeperId =
  forgetIndex >= 0 ? process.argv[forgetIndex + 1] : null;
if (forgetIndex >= 0 && !forgetStorykeeperId) {
  console.error("Usage: keeper.mjs --forget <storykeeper-id> [--execute]");
  process.exit(1);
}
const url = process.env.KEEPER_DATABASE_URL;
if (!url) {
  console.error(
    "KEEPER_DATABASE_URL is not set (it must connect as lifebook_keeper).",
  );
  process.exit(1);
}

const pool = new Pool({ connectionString: url, max: 1 });
const client = await pool.connect();

function say(line) {
  console.log(line);
}

/**
 * --forget <storykeeper-id>: the Storykeeper's right to vanish, as a tested
 * capability rather than a promise. Removes EVERYTHING: every claimed Book
 * and its contents, sessions, credentials, tokens, the identity itself.
 * Dry-run by default; every execution confesses to audit.deletion_event.
 */
async function forget(storykeeperId) {
  const person = await client.query(
    `select id, created_at from identity.storykeeper where id = $1`,
    [storykeeperId],
  );
  if (!person.rows[0]) {
    say(`No Storykeeper ${storykeeperId} exists. Nothing to forget.`);
    return;
  }

  const census = await client.query(
    `select count(distinct bc.book_id) as books,
            count(distinct c.id) as conversations,
            count(m.id) as moments
       from identity.book_claim bc
       left join entrusted.conversation c on c.book_id = bc.book_id
       left join entrusted.moment m on m.conversation_id = c.id
      where bc.storykeeper_id = $1`,
    [storykeeperId],
  );
  const { books, conversations, moments } = census.rows[0];
  say(
    `${execute ? "FORGETTING" : "Would forget"} Storykeeper ${storykeeperId}: ` +
      `${books} book(s), ${conversations} conversation(s), ${moments} moment(s), ` +
      `plus sessions, credentials, and identity.`,
  );

  if (!execute) return;

  // Everything hangs off the claimed Books and the identity. FK-safe order.
  const bookIds = (
    await client.query(
      `select book_id from identity.book_claim where storykeeper_id = $1`,
      [storykeeperId],
    )
  ).rows.map((row) => row.book_id);

  for (const bookId of bookIds) {
    await client.query(
      `delete from provisional.draft_contribution d using entrusted.conversation c
        where d.conversation_id = c.id and c.book_id = $1`,
      [bookId],
    );
    await client.query(
      `delete from entrusted.companion_turn ct using entrusted.conversation c
        where ct.conversation_id = c.id and c.book_id = $1`,
      [bookId],
    );
    await client.query(
      `delete from entrusted.moment m using entrusted.conversation c
        where m.conversation_id = c.id and c.book_id = $1`,
      [bookId],
    );
    await client.query(`delete from entrusted.conversation where book_id = $1`, [bookId]);
    await client.query(`delete from identity.signin_token where book_id = $1`, [bookId]);
    await client.query(`delete from identity.session_book where book_id = $1`, [bookId]);
    await client.query(`delete from identity.book_claim where book_id = $1`, [bookId]);
    await client.query(`delete from identity.contributor where book_id = $1`, [bookId]);
    await client.query(`delete from identity.book where id = $1`, [bookId]);
  }

  // Doorway tokens addressed to their credentials, then identity itself.
  await client.query(
    `delete from identity.signin_token t using identity.credential cr
      where cr.storykeeper_id = $1 and t.value_hash = cr.value_hash`,
    [storykeeperId],
  );
  await client.query(`delete from identity.session where storykeeper_id = $1`, [storykeeperId]);
  await client.query(`delete from identity.credential where storykeeper_id = $1`, [storykeeperId]);
  await client.query(`delete from identity.storykeeper where id = $1`, [storykeeperId]);

  await client.query(
    `insert into audit.deletion_event (what, requested_by)
     values ($1, 'keeper: storykeeper requested to be forgotten')`,
    [
      `storykeeper ${storykeeperId}: ${books} book(s), ${conversations} conversation(s), ` +
        `${moments} moment(s), all sessions/credentials/identity`,
    ],
  );
  say(`Forgotten. The confession is in audit.deletion_event.`);
}

try {
  await client.query("begin");

  if (forgetStorykeeperId) {
    say(
      `${execute ? "EXECUTE" : "DRY RUN"} — the Keeper (forget), ${new Date().toISOString()}`,
    );
    await forget(forgetStorykeeperId);
    if (execute) {
      await client.query("commit");
    } else {
      await client.query("rollback");
      say("Dry run complete — nothing was changed. Re-run with --execute to act.");
    }
    client.release();
    await pool.end();
    process.exit(0);
  }

  // ---- 1. Unclaimed Books past the retention window --------------------
  const books = await client.query(
    `select b.id,
            b.created_at,
            (select count(*) from entrusted.conversation c where c.book_id = b.id) as conversations,
            (select count(*) from entrusted.moment m
              join entrusted.conversation c on c.id = m.conversation_id
             where c.book_id = b.id) as moments
       from identity.book b
      where not exists (select 1 from identity.book_claim bc where bc.book_id = b.id)
        and b.created_at < now() - ($1 || ' days')::interval
      order by b.created_at`,
    [String(UNCLAIMED_BOOK_DAYS)],
  );

  say(
    `${execute ? "EXECUTE" : "DRY RUN"} — the Keeper, ${new Date().toISOString()}`,
  );
  say(
    `Unclaimed Books past ${UNCLAIMED_BOOK_DAYS} days: ${books.rows.length}`,
  );

  for (const book of books.rows) {
    say(
      `  book ${book.id} (created ${book.created_at.toISOString()}, ` +
        `${book.conversations} conversations, ${book.moments} moments)` +
        (execute ? " — deleting" : " — would delete"),
    );

    if (!execute) continue;

    // Claim check INSIDE the transaction: a Book claimed since the select
    // above is skipped, never deleted.
    const claimed = await client.query(
      `select 1 from identity.book_claim where book_id = $1`,
      [book.id],
    );
    if (claimed.rows.length > 0) {
      say(`    claimed since scan — SKIPPED`);
      continue;
    }

    // FK-safe order: leaves first, book last.
    await client.query(
      `delete from provisional.draft_contribution d
        using entrusted.conversation c
        where d.conversation_id = c.id and c.book_id = $1`,
      [book.id],
    );
    await client.query(
      `delete from entrusted.companion_turn ct
        using entrusted.conversation c
        where ct.conversation_id = c.id and c.book_id = $1`,
      [book.id],
    );
    await client.query(
      `delete from entrusted.moment m
        using entrusted.conversation c
        where m.conversation_id = c.id and c.book_id = $1`,
      [book.id],
    );
    await client.query(`delete from entrusted.conversation where book_id = $1`, [
      book.id,
    ]);
    await client.query(`delete from identity.signin_token where book_id = $1`, [
      book.id,
    ]);
    await client.query(`delete from identity.session_book where book_id = $1`, [
      book.id,
    ]);
    await client.query(`delete from identity.contributor where book_id = $1`, [
      book.id,
    ]);
    await client.query(`delete from identity.book where id = $1`, [book.id]);

    await client.query(
      `insert into audit.deletion_event (what, requested_by)
       values ($1, 'keeper: unclaimed-book retention window')`,
      [
        `unclaimed book ${book.id}: ${book.conversations} conversations, ` +
          `${book.moments} moments, created ${book.created_at.toISOString()}`,
      ],
    );
  }

  // ---- 2. Expired provisional drafts ------------------------------------
  const drafts = await client.query(
    `select count(*) as n from provisional.draft_contribution where expires_at < now()`,
  );
  say(`Expired provisional drafts: ${drafts.rows[0].n}`);
  if (execute && Number(drafts.rows[0].n) > 0) {
    await client.query(
      `delete from provisional.draft_contribution where expires_at < now()`,
    );
    await client.query(
      `insert into audit.deletion_event (what, requested_by)
       values ($1, 'keeper: provisional expiry')`,
      [`${drafts.rows[0].n} expired provisional draft(s)`],
    );
  }

  // ---- 3. Spent/expired doorway tokens ----------------------------------
  const tokens = await client.query(
    `select count(*) as n from identity.signin_token
      where (used_at is not null or expires_at < now())
        and created_at < now() - ($1 || ' days')::interval`,
    [String(SPENT_TOKEN_DAYS)],
  );
  say(`Spent/expired doorway tokens older than ${SPENT_TOKEN_DAYS} days: ${tokens.rows[0].n}`);
  if (execute && Number(tokens.rows[0].n) > 0) {
    await client.query(
      `delete from identity.signin_token
        where (used_at is not null or expires_at < now())
          and created_at < now() - ($1 || ' days')::interval`,
      [String(SPENT_TOKEN_DAYS)],
    );
    await client.query(
      `insert into audit.deletion_event (what, requested_by)
       values ($1, 'keeper: doorway token hygiene')`,
      [`${tokens.rows[0].n} spent/expired doorway token(s)`],
    );
  }

  if (execute) {
    await client.query("commit");
    say("Committed. Every deletion is recorded in audit.deletion_event.");
  } else {
    await client.query("rollback");
    say("Dry run complete — nothing was changed. Re-run with --execute to act.");
  }
} catch (error) {
  await client.query("rollback").catch(() => {});
  console.error("The Keeper stopped without changing anything:", error);
  process.exitCode = 1;
} finally {
  client.release();
  await pool.end();
}
