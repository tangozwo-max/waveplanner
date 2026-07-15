-- ===========================================================================
-- Coaching becomes a FLAG on a booking, not a separate wave type.
--
-- You book a normal wave (e.g. Advanced) and tick "coaching" — you sit in the
-- main session but get a 30-min-early coaching portion, drawn as an amber tab
-- reaching up into the slot before. This replaces the old "Performance
-- Coaching" / "Advanced Coaching" levels added in 0003.
--
-- Run in the Supabase SQL Editor. Idempotent.
-- ===========================================================================

-- 1. New flag on bookings (no-op if 0001 already created it).
alter table waveplanner.bookings
  add column if not exists coaching boolean not null default false;

-- 2. Convert any existing coaching-LEVEL bookings into Advanced + coaching flag.
--    (Advanced is guaranteed by the seed; skip gracefully if it's missing.)
update waveplanner.bookings b
   set coaching = true,
       level_id = coalesce(
                    (select id from waveplanner.levels where name = 'Advanced'),
                    b.level_id)
 where b.level_id in (
         select id from waveplanner.levels
          where name in ('Performance Coaching', 'Advanced Coaching'));

-- 3. Retire the coaching levels so they leave the type dropdown / legend.
update waveplanner.levels
   set active = false
 where name in ('Performance Coaching', 'Advanced Coaching');
