-- ===========================================================================
-- 0002 — migrate the existing bookings from the old single-file planner, and
-- let a pre-seeded (unclaimed) surfer be claimed on first Google login,
-- matched by email or name. Safe to re-run.
-- ===========================================================================

-- 1) allow a surfer to exist before its auth user does (user_id null = unclaimed)
alter table waveplanner.surfers alter column user_id drop not null;

-- 1b) optional email used to claim a pre-seeded surfer on first login
alter table waveplanner.surfers add column if not exists claim_email text;

-- 2) smarter sign-up handler: first try to CLAIM an unclaimed surfer whose
--    claim_email or name matches; otherwise create a fresh surfer row.
create or replace function waveplanner.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = waveplanner, public
as $$
declare
  v_name text := coalesce(nullif(new.raw_user_meta_data->>'full_name',''),
                          nullif(new.raw_user_meta_data->>'name',''),
                          split_part(new.email,'@',1));
  v_code text := upper(coalesce(nullif(new.raw_user_meta_data->>'code',''), left(v_name,1)));
  v_claimed uuid;
begin
  -- claim a pre-seeded surfer nobody owns yet, matched by email or name
  update waveplanner.surfers
     set user_id = new.id
   where user_id is null
     and ( lower(claim_email) = lower(new.email)
        or lower(name)        = lower(v_name) )
  returning id into v_claimed;
  if v_claimed is not null then
    return new;
  end if;

  -- otherwise create a new surfer, making the code unique
  while exists (select 1 from waveplanner.surfers where code = v_code) loop
    v_code := left(v_code,3) || floor(random()*10)::int::text;
  end loop;
  insert into waveplanner.surfers (user_id, code, name) values (new.id, v_code, v_name);
  return new;
end $$;

-- 3) make sure both surfers exist
--    Alessandro (already has an auth user)
insert into waveplanner.surfers (user_id, code, name)
values ('261a11eb-1e41-4620-876e-2bc960026898', 'A', 'Alessandro Cancemi')
on conflict (user_id) do nothing;

--    Tim — unclaimed until he signs in with Google (matched by email or name)
insert into waveplanner.surfers (user_id, code, name, claim_email)
values (null, 'T', 'Tim Koslowski', 'lawski@gmx.net')
on conflict (code) do update
  set claim_email = excluded.claim_email,
      name        = excluded.name
  where waveplanner.surfers.user_id is null;

-- 4) load the existing bookings. Person A -> Alessandro's row, person T -> Tim's row.
--    Level is matched by name; conflicts (same surfer+date+time) are ignored.
with sa as (select id from waveplanner.surfers where user_id = '261a11eb-1e41-4620-876e-2bc960026898' limit 1),
     st as (select id from waveplanner.surfers where lower(name) = 'tim koslowski' order by created_at limit 1)
insert into waveplanner.bookings (surfer_id, level_id, session_date, session_time, side, ref)
select case v.person when 'A' then (select id from sa) else (select id from st) end,
       l.id, v.d::date, v.t::time, nullif(v.side,''), v.ref
from (values
  -- person, level,           side, ref,            date,         time
  ('A','Advanced Plus','R','772607040158','2026-07-16','20:00'),
  ('A','Expert Turns', 'R','772607040158','2026-07-19','12:00'),
  ('A','Advanced Plus','R','772607040158','2026-07-16','08:00'),
  ('A','Expert Turns', 'R','772607040158','2026-07-19','20:00'),
  ('A','Advanced Plus','R','772607040158','2026-07-15','16:00'),
  ('A','Advanced Plus','R','772607040158','2026-07-18','08:00'),
  ('A','Advanced Plus','R','772607040158','2026-07-17','08:00'),
  ('A','Expert Turns', 'R','',            '2026-07-17','09:00'),
  ('A','Expert Turns', 'R','772607040168','2026-07-21','14:00'),
  ('A','Advanced Plus','L','772607040168','2026-07-23','12:00'),
  ('A','Advanced',     'L','772607040168','2026-07-20','09:00'),
  ('A','Advanced',     'L','772607040168','2026-07-22','09:00'),
  ('A','Advanced Plus','L','772607040168','2026-07-23','20:00'),
  ('A','Advanced Plus','R','772607040168','2026-07-20','16:00'),
  ('A','Expert Turns', 'R','772607040168','2026-07-22','16:00'),
  ('A','Advanced',     'L','772607040168','2026-07-21','20:00'),
  ('A','Expert Turns', 'R','772607040168','2026-07-23','09:00'),
  ('A','Advanced',     'R','',            '2026-07-15','10:00'),
  ('A','Advanced',     'R','772607040199','2026-07-18','17:00'),
  ('A','Advanced',     'R','',            '2026-07-17','14:00'),
  ('A','Advanced Plus','R','',            '2026-07-14','20:00'),
  ('T','Advanced Plus','L','772607010102','2026-07-14','20:00'),
  ('T','Advanced',     'L','772607010102','2026-07-14','17:00'),
  ('T','Advanced',     'R','772607060152','2026-07-18','17:00'),
  ('T','Advanced Plus','L','772607060152','2026-07-15','16:00'),
  ('T','Expert Barrel','L','772607060193','2026-07-22','19:00'),
  ('T','Expert Turns', 'L','772607060193','2026-07-22','09:00'),
  ('T','Advanced Plus','L','772607060193','2026-07-21','20:00'),
  ('T','Expert',       'L','772607060193','2026-07-21','16:00'),
  ('T','Advanced Plus','R','772607060193','2026-07-20','09:00'),
  ('T','Expert Turns', 'L','772607060193','2026-07-19','12:00'),
  ('T','Expert Turns', 'L','772607060193','2026-07-19','09:00'),
  ('T','Advanced Plus','R','772607060193','2026-07-18','08:00'),
  ('T','Expert',       'L','772607060193','2026-07-16','10:00'),
  ('T','Advanced Plus','R','772607060193','2026-07-16','08:00'),
  ('T','Expert Turns', 'L','772607060193','2026-07-17','09:00'),
  ('T','Advanced Plus','L','772607060193','2026-07-17','08:00'),
  ('T','Advanced',     'R','772607060193','2026-07-15','10:00'),
  ('T','Advanced',     'L','772607060229','2026-07-20','10:00'),
  ('T','Advanced',     'R','772607060229','2026-07-20','16:00'),
  ('T','Expert Turns', 'L','772607060229','2026-07-23','09:00')
) as v(person, level, side, ref, d, t)
join waveplanner.levels l on l.name = v.level
on conflict (surfer_id, session_date, session_time) do nothing;

-- 5) sanity check
select s.name, s.code, s.user_id, count(b.id) as bookings
from waveplanner.surfers s
left join waveplanner.bookings b on b.surfer_id = s.id
group by s.name, s.code, s.user_id
order by s.name;
