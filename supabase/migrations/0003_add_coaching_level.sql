-- ===========================================================================
-- Add the "Performance Coaching" (a.k.a. Advanced Coaching) wave type.
-- These sessions start 30 minutes earlier than the booked slot — the grid
-- draws the illustration reaching up into the half-hour before.
-- Run in the Supabase SQL Editor. Idempotent (upsert by name).
-- ===========================================================================
insert into waveplanner.levels (name, abbr, color, sort_order) values
  ('Performance Coaching', 'Coach', '#b5722b', 8)   -- amber; distinct from the cool difficulty ramp
on conflict (name) do update
  set abbr = excluded.abbr,
      color = excluded.color,
      sort_order = excluded.sort_order,
      active = true;
