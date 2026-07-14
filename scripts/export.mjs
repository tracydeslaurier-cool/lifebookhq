import { Pool } from "pg";
import { writeFileSync } from "fs";

/**
 * Export — the Storykeeper's story, handed back whole.
 *
 * Produces two files: a human-readable Markdown document and a
 * machine-readable JSON archive, containing every Moment and Companion
 * Turn across every Book the Storykeeper has claimed — verbatim, in
 * original language, with provenance. No lock-in, no summaries in place
 * of words, nothing withheld.
 *
 * Usage:
 *   node --env-file=.env.local scripts/export.mjs <storykeeper-id>
 */

const storykeeperId = process.argv[2];
if (!storykeeperId) {
  console.error("Usage: export.mjs <storykeeper-id>");
  process.exit(1);
}

const url = process.env.DATABASE_URL;
if (!url) {
  console.error("DATABASE_URL is not set.");
  process.exit(1);
}

const pool = new Pool({ connectionString: url, max: 1 });

const record = await pool.query(
  `select c.id as conversation_id, c.began_at, c.language as conversation_language,
          t.speaker, t.text, t.at, t.language, t.input_mode, t.model_id
     from entrusted.conversation c
     join identity.book_claim bc on bc.book_id = c.book_id
     left join lateral (
       select 'storykeeper' as speaker, m.original_text as text, m.submitted_at as at,
              m.original_language as language, m.input_mode, null as model_id, m.seq
         from entrusted.moment m where m.conversation_id = c.id
       union all
       select 'companion', ct.text, ct.spoken_at, ct.language, null, ct.model_id, ct.seq
         from entrusted.companion_turn ct where ct.conversation_id = c.id
       order by at, seq
     ) t on true
    where bc.storykeeper_id = $1
    order by c.began_at asc, t.at asc`,
  [storykeeperId],
);

await pool.query(
  `insert into audit.access_event (actor, purpose, scope) values ('export-script', 'export', $1)`,
  [storykeeperId],
);

const conversations = new Map();
for (const row of record.rows) {
  if (!conversations.has(row.conversation_id)) {
    conversations.set(row.conversation_id, {
      beganAt: row.began_at,
      language: row.conversation_language,
      turns: [],
    });
  }
  if (row.speaker) {
    conversations.get(row.conversation_id).turns.push({
      speaker: row.speaker,
      text: row.text,
      at: row.at,
      language: row.language,
      inputMode: row.input_mode ?? undefined,
      modelId: row.model_id ?? undefined,
    });
  }
}

const exportedAt = new Date().toISOString();
const stamp = exportedAt.slice(0, 10);

// Machine-readable: everything, with provenance.
const json = {
  format: "lifebook-export-v1",
  exportedAt,
  storykeeperId,
  conversations: [...conversations.values()],
};
const jsonPath = `lifebook-export-${stamp}.json`;
writeFileSync(jsonPath, JSON.stringify(json, null, 2));

// Human-readable: the story as it was lived.
const lines = [`# Your LifeBook\n`, `*Everything you have entrusted, exactly as you said it. Exported ${stamp}.*\n`];
for (const conversation of conversations.values()) {
  const day = new Date(conversation.beganAt).toDateString();
  lines.push(`\n## A conversation — ${day}\n`);
  for (const turn of conversation.turns) {
    if (turn.speaker === "storykeeper") {
      lines.push(`**You:** ${turn.text}\n`);
    } else {
      lines.push(`*Companion:* ${turn.text}\n`);
    }
  }
}
const mdPath = `lifebook-export-${stamp}.md`;
writeFileSync(mdPath, lines.join("\n"));

console.log(
  `Exported ${conversations.size} conversation(s) for ${storykeeperId}:\n  ${mdPath}\n  ${jsonPath}\nThe export is recorded in audit.access_event (purpose: export).`,
);

await pool.end();
