-- ===========================================================================
-- "Announcement" sessions — a slot marker with nobody booked in.
--
-- Sometimes you want to show that a session EXISTS at a given slot (so the grid
-- reads like a schedule) without booking a specific person into it. Such a row
-- is still owned by whoever created it (so RLS "edit only your own" keeps
-- working) but is drawn as a subtle gray marker and is excluded from every
-- per-person count / summary.
--
-- Run in the Supabase SQL Editor. Idempotent.
-- ===========================================================================

alter table waveplanner.bookings
  add column if not exists announcement boolean not null default false;
