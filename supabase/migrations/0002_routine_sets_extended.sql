-- Prida typ serie, cas a vzdalenost k rutinam (pro intervalove/kardio cviky).

alter table public.routine_sets
  add column if not exists set_type text not null default 'normal'
    check (set_type in ('normal', 'warmup', 'failure', 'drop_set')),
  add column if not exists duration_seconds int,
  add column if not exists distance_meters numeric;
