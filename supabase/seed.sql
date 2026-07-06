-- Seed the wave levels (colors match the original planner).
-- Run after 0001_init.sql. Safe to re-run.
insert into waveplanner.levels (name, abbr, color, sort_order) values
  ('Advanced',      'Advanced',      '#16a34a', 1),
  ('Advanced Plus', 'Advanced Plus', '#0d9488', 2),
  ('Expert',        'Expert',        '#ea580c', 3),
  ('Expert Turns',  'Expert Turns',  '#dc2626', 4),
  ('Expert Barrel', 'Expert Barrel', '#6d28d9', 5),
  ('Barrel Medley', 'Barrel Medley', '#be185d', 6)
on conflict (name) do update
  set abbr = excluded.abbr,
      color = excluded.color,
      sort_order = excluded.sort_order,
      active = true;
