-- ===========================================================================
-- Wave Planner — initial schema
-- Everything lives in the `waveplanner` schema (not `public`).
-- Run this in the Supabase SQL Editor (Dashboard -> SQL -> New query).
-- ===========================================================================

create schema if not exists waveplanner;

-- gen_random_uuid() (Supabase usually has this already; safe to re-run)
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- surfers : one row per person, linked 1:1 to a Supabase auth user
-- ---------------------------------------------------------------------------
create table if not exists waveplanner.surfers (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null unique references auth.users(id) on delete cascade,
  code       text not null unique check (char_length(code) between 1 and 4),  -- grid label, e.g. 'A' / 'T'
  name       text not null,                                                   -- display name
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- levels : the wave types (moved out of the old JS config)
-- ---------------------------------------------------------------------------
create table if not exists waveplanner.levels (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,          -- 'Advanced', 'Expert Turns', ...
  abbr       text not null,                 -- short label shown on the chip
  color      text not null,                 -- hex, e.g. '#16a34a'
  sort_order int  not null default 0,
  active     boolean not null default true
);

-- ---------------------------------------------------------------------------
-- bookings : the sessions on the grid
-- One person can hold at most one session per date+time (matches the old
-- person|date|time key). A and T can each book the same slot independently.
-- ---------------------------------------------------------------------------
create table if not exists waveplanner.bookings (
  id           uuid primary key default gen_random_uuid(),
  surfer_id    uuid not null references waveplanner.surfers(id) on delete cascade,
  level_id     uuid not null references waveplanner.levels(id)  on delete restrict,
  session_date date not null,
  session_time time not null,
  side         text check (side in ('L','R')),        -- null = unspecified
  status       text check (status in ('out','in')),   -- null = normal booking; 'out' = move out; 'in' = book in
  coaching     boolean not null default false,        -- true = coached session, starts 30 min early
  ref          text not null default '',              -- the Wave booking reference
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (surfer_id, session_date, session_time)
);

create index if not exists bookings_date_time_idx on waveplanner.bookings (session_date, session_time);
create index if not exists bookings_surfer_idx    on waveplanner.bookings (surfer_id);

-- keep updated_at fresh on every edit
create or replace function waveplanner.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists bookings_set_updated_at on waveplanner.bookings;
create trigger bookings_set_updated_at
  before update on waveplanner.bookings
  for each row execute function waveplanner.set_updated_at();

-- ---------------------------------------------------------------------------
-- auto-create a surfer row when a new auth user signs up.
-- name / code come from sign-up metadata, with sensible fallbacks.
-- ---------------------------------------------------------------------------
create or replace function waveplanner.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = waveplanner, public
as $$
declare
  -- Google sends full_name / name; email sign-up sends name. Fall back to the email local-part.
  v_name text := coalesce(
                   nullif(new.raw_user_meta_data->>'full_name',''),
                   nullif(new.raw_user_meta_data->>'name',''),
                   split_part(new.email,'@',1));
  v_code text := upper(coalesce(nullif(new.raw_user_meta_data->>'code',''), left(v_name,1)));
begin
  -- make the code unique if it collides
  while exists (select 1 from waveplanner.surfers where code = v_code) loop
    v_code := left(v_code,3) || floor(random()*10)::int::text;
  end loop;
  insert into waveplanner.surfers (user_id, code, name)
  values (new.id, v_code, v_name);
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function waveplanner.handle_new_user();

-- ---------------------------------------------------------------------------
-- Row Level Security
--   surfers  : signed-in users see everyone (names for the grid); edit only own
--   levels   : signed-in users read all; any signed-in user may manage
--   bookings : signed-in users SEE all sessions (shared grid); edit only own
-- ---------------------------------------------------------------------------
alter table waveplanner.surfers  enable row level security;
alter table waveplanner.levels   enable row level security;
alter table waveplanner.bookings enable row level security;

drop policy if exists surfers_select_all on waveplanner.surfers;
create policy surfers_select_all on waveplanner.surfers
  for select to authenticated using (true);

drop policy if exists surfers_modify_own on waveplanner.surfers;
create policy surfers_modify_own on waveplanner.surfers
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists levels_select_all on waveplanner.levels;
create policy levels_select_all on waveplanner.levels
  for select to authenticated using (true);

drop policy if exists levels_write on waveplanner.levels;
create policy levels_write on waveplanner.levels
  for all to authenticated using (true) with check (true);

drop policy if exists bookings_select_all on waveplanner.bookings;
create policy bookings_select_all on waveplanner.bookings
  for select to authenticated using (true);

drop policy if exists bookings_modify_own on waveplanner.bookings;
create policy bookings_modify_own on waveplanner.bookings
  for all to authenticated
  using     (exists (select 1 from waveplanner.surfers s where s.id = bookings.surfer_id and s.user_id = auth.uid()))
  with check (exists (select 1 from waveplanner.surfers s where s.id = bookings.surfer_id and s.user_id = auth.uid()));

-- ---------------------------------------------------------------------------
-- Expose the schema to the API roles.
-- IMPORTANT: you must ALSO add `waveplanner` under
--   Dashboard -> Project Settings -> API -> Exposed schemas
-- (and to "Extra search path"), then the REST API can reach these tables.
-- ---------------------------------------------------------------------------
grant usage on schema waveplanner to anon, authenticated, service_role;
grant select, insert, update, delete on all tables in schema waveplanner to authenticated;
grant select on all tables in schema waveplanner to anon;
grant all on all tables in schema waveplanner to service_role;

alter default privileges in schema waveplanner
  grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema waveplanner
  grant select on tables to anon;
alter default privileges in schema waveplanner
  grant all on tables to service_role;
