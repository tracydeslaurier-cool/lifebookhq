-- LifeBook — Migration 0001: the planes
-- Governed by foundation/ARCHITECTURE.md (Decisions 009–016).
-- Run as the database owner (not the application role).

begin;

create extension if not exists pgcrypto;

create schema if not exists identity;    -- who is speaking, which Book is open
create schema if not exists entrusted;   -- the entrusted plane: append-only, sacred
create schema if not exists provisional; -- uncommitted thoughts; protected, not yet entrusted
create schema if not exists audit;       -- Decision 010: access has purposes, purposes leave trails

-- ---------------------------------------------------------------------------
-- identity
-- ---------------------------------------------------------------------------

create table identity.storykeeper (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now()
);

-- Method-neutral (spec §8: authentication technology deliberately undecided).
create table identity.credential (
  id             uuid primary key default gen_random_uuid(),
  storykeeper_id uuid not null references identity.storykeeper(id),
  kind           text not null,              -- 'email' in slice 1
  value_hash     text not null,              -- never the raw value
  verified_at    timestamptz,
  created_at     timestamptz not null default now(),
  unique (kind, value_hash)
);

create table identity.signin_token (
  id          uuid primary key default gen_random_uuid(),
  kind        text not null,                 -- 'email'
  value_hash  text not null,                 -- hash of the address the link was sent to
  token_hash  text not null unique,          -- single-use, never stored raw
  expires_at  timestamptz not null,
  used_at     timestamptz,
  created_at  timestamptz not null default now()
);

-- NULL storykeeper_id = anonymous session. Never a fictional identity (Director, 2026-07-12).
create table identity.session (
  id             uuid primary key default gen_random_uuid(),
  storykeeper_id uuid references identity.storykeeper(id),
  created_at     timestamptz not null default now(),
  last_seen_at   timestamptz not null default now(),
  expires_at     timestamptz not null
);

create table identity.book (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now()
);

-- NULL storykeeper_id = the anonymous Contributor of an unclaimed Book.
create table identity.contributor (
  id             uuid primary key default gen_random_uuid(),
  book_id        uuid not null references identity.book(id),
  storykeeper_id uuid references identity.storykeeper(id),
  role           text not null default 'owner',
  created_at     timestamptz not null default now()
);

-- Claiming is an INSERT — a new fact, never a rewrite (Director, 2026-07-12).
create table identity.book_claim (
  id             uuid primary key default gen_random_uuid(),
  book_id        uuid not null unique references identity.book(id),
  storykeeper_id uuid not null references identity.storykeeper(id),
  claimed_at     timestamptz not null default now()
);

-- How an anonymous session finds its unclaimed Book.
create table identity.session_book (
  session_id uuid not null references identity.session(id),
  book_id    uuid not null references identity.book(id),
  created_at timestamptz not null default now(),
  primary key (session_id, book_id)
);

create index on identity.session (expires_at);
create index on identity.contributor (book_id);
create index on identity.book_claim (storykeeper_id);

-- ---------------------------------------------------------------------------
-- entrusted  (append-only; privileges enforced in 0002)
-- ---------------------------------------------------------------------------

create table entrusted.conversation (
  id             uuid primary key default gen_random_uuid(),
  book_id        uuid not null references identity.book(id),
  contributor_id uuid not null references identity.contributor(id),
  began_at       timestamptz not null default now(),
  language       text not null
);

create table entrusted.moment (
  id                   uuid primary key default gen_random_uuid(),
  conversation_id      uuid not null references entrusted.conversation(id),
  contributor_id       uuid not null references identity.contributor(id),
  seq                  integer not null,
  submitted_at         timestamptz not null default now(),
  original_text        text not null,        -- verbatim, forever (Decision 009)
  original_language    text not null,
  input_mode           text not null,        -- 'text' in slice 1
  source_kind          text not null default 'conversation',
  supersedes_moment_id uuid references entrusted.moment(id), -- an edit is a new row beside the original
  unique (conversation_id, seq)
);

create table entrusted.companion_turn (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references entrusted.conversation(id),
  seq             integer not null,
  spoken_at       timestamptz not null default now(),
  text            text not null,
  language        text not null,
  model_id        text not null,             -- provenance: which mind spoke (Decision 014)
  unique (conversation_id, seq)
);

create index on entrusted.conversation (book_id, began_at);
create index on entrusted.moment (conversation_id, seq);
create index on entrusted.companion_turn (conversation_id, seq);

-- ---------------------------------------------------------------------------
-- provisional  (uncommitted; same privacy discipline, deliberate expiry)
-- ---------------------------------------------------------------------------

create table provisional.draft_contribution (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null unique references entrusted.conversation(id),
  text            text not null,
  updated_at      timestamptz not null default now(),
  expires_at      timestamptz not null
);

-- ---------------------------------------------------------------------------
-- audit
-- ---------------------------------------------------------------------------

create table audit.access_event (
  id      bigint generated always as identity primary key,
  actor   text not null,          -- service path, never a person's name
  purpose text not null,          -- 'conversation' | 'homecoming' | ...
  scope   text not null,          -- book/conversation identifier
  at      timestamptz not null default now()
);

create table audit.deletion_event (
  id           bigint generated always as identity primary key,
  what         text not null,
  requested_by text not null,
  executed_at  timestamptz not null default now()
);

commit;
