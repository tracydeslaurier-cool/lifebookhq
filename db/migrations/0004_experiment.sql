-- LifeBook — Migration 0004: Threshold discovery-experiment instrumentation.
--
-- Append-only OBSERVATIONS of how arrivals begin across variants A / B / C.
-- These are not analytics. They live in the audit schema, which Migration 0002
-- makes append-only for everyone: the application may INSERT and SELECT, never
-- UPDATE, DELETE, or TRUNCATE. Deletion, when a Storykeeper asks, is the
-- keeper's job alone.
--
-- Two disciplines are deliberate:
--   1. Content-free. experiment_event records timings and choices, never words.
--   2. Masked. session_recording stores rrweb screen-interaction batches with
--      all text and inputs masked before they ever leave the browser — layout
--      and behaviour only, never the story, never a camera.
--
-- Run as the database owner in the Supabase SQL editor, like prior migrations.

begin;

-- Content-free events: what happened and when, never what was said.
create table if not exists audit.experiment_event (
  id          uuid primary key default gen_random_uuid(),
  experiment  text not null default 'threshold',
  variant     text not null,            -- 'a' | 'b' | 'c'
  session_id  uuid,                      -- identity.session.id (anonymous ok); stamped server-side
  event_type  text not null,            -- arrival | first_interaction | input_mode | globe_opened |
                                         -- language_detected | language_selected | first_entrustment |
                                         -- continued | session_end
  detail      jsonb not null default '{}'::jsonb,
  at          timestamptz not null default now()
);

create index if not exists experiment_event_variant_at_idx
  on audit.experiment_event (variant, at);
create index if not exists experiment_event_session_idx
  on audit.experiment_event (session_id);

-- Masked screen-interaction replay (rrweb): behaviour only.
create table if not exists audit.session_recording (
  id          uuid primary key default gen_random_uuid(),
  experiment  text not null default 'threshold',
  variant     text not null,
  session_id  uuid,
  seq         integer not null default 0,   -- batch order within a session
  events      jsonb not null,               -- rrweb event batch, content already masked
  at          timestamptz not null default now()
);

create index if not exists session_recording_session_seq_idx
  on audit.session_recording (session_id, seq);

-- Append-only for the application (0002's audit default-privileges already
-- imply this; stated explicitly so the discipline is legible on the table).
grant select, insert on audit.experiment_event, audit.session_recording to lifebook_app;
revoke update, delete, truncate on audit.experiment_event, audit.session_recording from lifebook_app;

commit;
