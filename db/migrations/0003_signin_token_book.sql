-- LifeBook — Migration 0003: the doorway carries the story
--
-- A sign-in doorway is requested FROM a device that holds an unclaimed Book,
-- and may be opened ON a different device that knows nothing. The token must
-- therefore carry which story asked to be found, so claiming works across
-- devices without ever faking an identity.

begin;

alter table identity.signin_token
  add column book_id uuid references identity.book(id);

commit;
