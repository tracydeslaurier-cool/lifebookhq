import { db } from "@/lib/db";

/**
 * Replay data — server side. Reads the masked rrweb batches and their
 * threshold metadata for the facilitator-only viewer. Reached only through
 * the EXPERIMENT_VIEWER_KEY door (middleware); no content lives here anyway —
 * the events were masked in the browser before they were ever stored.
 */

export type RecordedSession = {
  sessionId: string;
  variant: string;
  startedAt: string;
  batchCount: number;
  entrusted: boolean;
};

export async function listRecordedSessions(): Promise<RecordedSession[]> {
  const result = await db().query(
    `select r.session_id,
            min(r.variant)                              as variant,
            min(r.at)                                   as started_at,
            count(*)::int                               as batch_count,
            coalesce(bool_or(e.entrusted), false)       as entrusted
       from audit.session_recording r
       left join (
         select distinct session_id, true as entrusted
           from audit.experiment_event
          where event_type = 'first_entrustment'
       ) e on e.session_id = r.session_id
      where r.session_id is not null
      group by r.session_id
      order by started_at desc
      limit 200`,
  );

  return result.rows.map((row) => ({
    sessionId: row.session_id as string,
    variant: row.variant as string,
    startedAt: (row.started_at as Date).toISOString(),
    batchCount: row.batch_count as number,
    entrusted: row.entrusted as boolean,
  }));
}

export async function getSessionEvents(sessionId: string): Promise<unknown[]> {
  const result = await db().query(
    `select events from audit.session_recording
      where session_id = $1
      order by seq asc`,
    [sessionId],
  );

  const all: unknown[] = [];
  for (const row of result.rows) {
    const events = row.events; // jsonb — node-pg returns a parsed array
    if (Array.isArray(events)) all.push(...events);
  }
  return all;
}
