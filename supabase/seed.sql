-- Seed / update the wave levels. Colors are a muted, flat difficulty ramp
-- (green -> teal -> blue -> indigo -> violet -> mauve -> rose), easy to hard.
-- Run after 0001_init.sql. Safe to re-run — it upserts by name.
insert into waveplanner.levels (name, abbr, color, sort_order) values
  ('Advanced',      'Adv',    '#5a8a74', 1),   -- muted green
  ('Advanced Plus', 'Adv+',   '#4a8489', 2),   -- muted teal
  ('Expert',        'Exp',    '#4d7aa0', 3),   -- muted blue
  ('Expert Turns',  'Turns',  '#5b6ba0', 4),   -- muted indigo
  ('Expert Barrel', 'Barrel', '#79609b', 5),   -- muted violet
  ('Expert Plus',   'Exp+',   '#965f88', 6),   -- muted mauve
  ('Barrel Medley', 'Medley', '#a05a64', 7)    -- muted rose
on conflict (name) do update
  set abbr = excluded.abbr,
      color = excluded.color,
      sort_order = excluded.sort_order,
      active = true;
