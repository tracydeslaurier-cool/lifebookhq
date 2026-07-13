import { withTransaction } from "@/lib/db";
import type { PoolClient } from "pg";

/**
 * The Archive — the one door into the entrusted plane (ARCHITECTURE.md §3).
 *
 * This module is the only code in LifeBook permitted to write entrusted
 * records, and the database role it runs under is only ABLE to append them.
 * There is no update function here because there is no update anywhere.
 *
 * An edit, when it exists, will be a NEW moment with supersedes_moment_id —
 * beside the original, never in place of it (Decision 011).
 */

export type EntrustedMoment = {
  id: string;
  seq: number;
};

async function nextSeq(
  tx: PoolClient,
  table: "moment" | "companion_turn",
  conversationId: string,
): Promise<number> {
  // Advisory lock keyed to the conversation: serializes appends without
  // requiring UPDATE privileges (which the app role deliberately lacks).
  await tx.query(`select pg_advisory_xact_lock(hashtextextended($1, 0))`, [
    conversationId,
  ]);
  const result = await tx.query(
    `select coalesce(max(seq), 0) + 1 as next
       from entrusted.${table}
      where conversation_id = $1`,
    [conversationId],
  );
  return result.rows[0].next as number;
}

export async function beginConversation(input: {
  bookId: string;
  contributorId: string;
  language: string;
}): Promise<{ conversationId: string }> {
  return withTransaction(async (tx) => {
    const result = await tx.query(
      `insert into entrusted.conversation (book_id, contributor_id, language)
       values ($1, $2, $3) returning id`,
      [input.bookId, input.contributorId, input.language],
    );
    return { conversationId: result.rows[0].id as string };
  });
}

/**
 * Entrust a Moment: one intentional Storykeeper contribution (Decision 011).
 * Any provisional draft for the conversation is promoted atomically and
 * discarded — transport, not history.
 */
export async function entrustMoment(input: {
  conversationId: string;
  contributorId: string;
  originalText: string;
  originalLanguage: string;
  inputMode: "text" | "voice";
}): Promise<EntrustedMoment> {
  const text = input.originalText;
  if (text.trim().length === 0) {
    throw new Error("A Moment cannot be empty");
  }

  return withTransaction(async (tx) => {
    const seq = await nextSeq(tx, "moment", input.conversationId);
    const result = await tx.query(
      `insert into entrusted.moment
         (conversation_id, contributor_id, seq, original_text, original_language, input_mode)
       values ($1, $2, $3, $4, $5, $6)
       returning id, seq`,
      [
        input.conversationId,
        input.contributorId,
        seq,
        text, // verbatim — never trimmed, corrected, or improved
        input.originalLanguage,
        input.inputMode,
      ],
    );

    await tx.query(
      `delete from provisional.draft_contribution where conversation_id = $1`,
      [input.conversationId],
    );

    return { id: result.rows[0].id as string, seq: result.rows[0].seq as number };
  });
}

export async function preserveCompanionTurn(input: {
  conversationId: string;
  text: string;
  language: string;
  modelId: string;
}): Promise<{ id: string; seq: number }> {
  return withTransaction(async (tx) => {
    const seq = await nextSeq(tx, "companion_turn", input.conversationId);
    const result = await tx.query(
      `insert into entrusted.companion_turn
         (conversation_id, seq, text, language, model_id)
       values ($1, $2, $3, $4, $5)
       returning id, seq`,
      [input.conversationId, seq, input.text, input.language, input.modelId],
    );
    return { id: result.rows[0].id as string, seq: result.rows[0].seq as number };
  });
}
