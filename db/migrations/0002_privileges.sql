-- LifeBook — Migration 0002: the privilege model
-- "Never invent a memory" as a property of the database, not a policy (P1, Decision 009).
-- Run as the database owner AFTER creating the roles:
--
--   create role lifebook_app  login password '...';  -- the application
--   create role lifebook_keeper login password '...'; -- the privileged deletion path (humans + expiry job)
--
-- Acceptance proof (Week 1 demo): connect as lifebook_app and attempt
--   UPDATE entrusted.moment SET original_text = 'x';
-- The database must refuse with "permission denied".

begin;

-- --- application role: lifebook_app ---------------------------------------

grant usage on schema identity, entrusted, provisional, audit to lifebook_app;

-- identity: normal read/write (sessions touch last_seen; tokens mark used)
grant select, insert, update on all tables in schema identity to lifebook_app;

-- entrusted: INSERT and SELECT only. No UPDATE. No DELETE. No TRUNCATE. Ever.
grant select, insert on all tables in schema entrusted to lifebook_app;
revoke update, delete, truncate on all tables in schema entrusted from lifebook_app;

-- provisional: drafts are mutable and deletable by design (they are not yet entrusted)
grant select, insert, update, delete on all tables in schema provisional to lifebook_app;

-- audit: append-only for everyone, including us
grant select, insert on all tables in schema audit to lifebook_app;
revoke update, delete, truncate on all tables in schema audit from lifebook_app;

-- future tables inherit the same discipline
alter default privileges in schema entrusted
  grant select, insert on tables to lifebook_app;
alter default privileges in schema identity
  grant select, insert, update on tables to lifebook_app;
alter default privileges in schema provisional
  grant select, insert, update, delete on tables to lifebook_app;
alter default privileges in schema audit
  grant select, insert on tables to lifebook_app;

-- --- privileged deletion path: lifebook_keeper -----------------------------
-- The sole exception to immutability is the Storykeeper's right to delete.
-- It runs on a different connection, with a different role, and leaves a trail.

grant usage on schema identity, entrusted, provisional, audit to lifebook_keeper;
grant select, delete on all tables in schema entrusted to lifebook_keeper;
grant select, delete on all tables in schema provisional to lifebook_keeper;
grant select, insert, update, delete on all tables in schema identity to lifebook_keeper;
grant select, insert on all tables in schema audit to lifebook_keeper;
revoke update on all tables in schema entrusted from lifebook_keeper; -- even the keeper never edits

commit;
