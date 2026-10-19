-- Prida cilovy cas odpocinku mezi serii k cviku v rutine (v sekundach).

alter table public.routine_exercises
  add column if not exists rest_time_seconds int check (rest_time_seconds >= 0);
