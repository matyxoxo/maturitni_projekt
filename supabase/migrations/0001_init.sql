-- ============================================================
-- AlphaLift - schema v1
-- Spustit v Supabase: SQL Editor -> New query -> vlozit -> Run
-- ============================================================

-- ---------- UVIZIVATELE ----------

create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  username text not null unique check (char_length(username) between 3 and 20),
  full_name text,
  profile_photo_url text,
  body_weight_kg numeric check (body_weight_kg > 0),
  created_at timestamptz not null default now()
);

-- ---------- SOCIALNI SIT ----------

create table public.follows (
  follower_user_id uuid not null references public.users (id) on delete cascade,
  following_user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_user_id, following_user_id),
  check (follower_user_id <> following_user_id)
);

create index follows_following_idx on public.follows (following_user_id);

-- ---------- SVALOVA HIERARCHIE ----------

create table public.muscle_groups (
  muscle_group_id uuid primary key default gen_random_uuid(),
  muscle_group_name text not null unique
);

create table public.sub_muscle_groups (
  sub_muscle_id uuid primary key default gen_random_uuid(),
  muscle_group_id uuid not null references public.muscle_groups (muscle_group_id),
  sub_muscle_name text not null,
  unique (muscle_group_id, sub_muscle_name)
);

create index sub_muscle_groups_muscle_idx on public.sub_muscle_groups (muscle_group_id);

-- ---------- KATALOG CVIKU ----------

create table public.exercises (
  exercise_id uuid primary key default gen_random_uuid(),
  sub_muscle_id uuid not null references public.sub_muscle_groups (sub_muscle_id),
  user_id uuid references public.users (id) on delete cascade, -- NULL = globalni cvik
  exercise_name text not null,
  exercise_type text not null default 'weight_reps'
    check (exercise_type in (
      'weight_reps',            -- vaha + opakovani
      'bodyweight_reps',        -- vlastni vaha + opakovani
      'weighted_bodyweight',    -- vlastni vaha + pridana zatez
      'assisted_bodyweight',    -- asistovany cvik
      'duration',               -- vydrz na cas (plank)
      'distance_duration'       -- kardio: vzdalenost + cas
    )),
  equipment text,
  exercise_icon_url text,
  is_custom boolean not null default false,
  created_at timestamptz not null default now()
);

create index exercises_sub_muscle_idx on public.exercises (sub_muscle_id);
create index exercises_user_idx on public.exercises (user_id) where user_id is not null;
create index exercises_name_idx on public.exercises (exercise_name);

-- ---------- RUTINY (SABLONY) ----------

create table public.routines (
  routine_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  routine_name text not null,
  created_at timestamptz not null default now()
);

create index routines_user_idx on public.routines (user_id);

create table public.routine_exercises (
  routine_exercise_id uuid primary key default gen_random_uuid(),
  routine_id uuid not null references public.routines (routine_id) on delete cascade,
  exercise_id uuid not null references public.exercises (exercise_id),
  order_index int not null,
  unique (routine_id, order_index)
);

create index routine_exercises_routine_idx on public.routine_exercises (routine_id);

create table public.routine_sets (
  routine_set_id uuid primary key default gen_random_uuid(),
  routine_exercise_id uuid not null references public.routine_exercises (routine_exercise_id) on delete cascade,
  set_number int not null check (set_number > 0),
  target_weight_kg numeric,
  target_reps int check (target_reps > 0)
);

create index routine_sets_exercise_idx on public.routine_sets (routine_exercise_id);

-- ---------- PROBEHLY TRENINKY ----------

create table public.workouts (
  workout_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  routine_id uuid references public.routines (routine_id),
  workout_title text not null,
  duration_seconds int,
  total_volume_kg numeric,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index workouts_user_created_idx on public.workouts (user_id, created_at desc);

create table public.workout_exercises (
  workout_exercise_id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references public.workouts (workout_id) on delete cascade,
  exercise_id uuid not null references public.exercises (exercise_id),
  order_index int not null
);

create index workout_exercises_workout_idx on public.workout_exercises (workout_id);

create table public.workout_sets (
  set_id uuid primary key default gen_random_uuid(),
  workout_exercise_id uuid not null references public.workout_exercises (workout_exercise_id) on delete cascade,
  set_number int not null check (set_number > 0),
  weight_kg numeric,
  reps_count int check (reps_count > 0),
  duration_seconds int,
  distance_meters numeric,
  set_type text not null default 'normal'
    check (set_type in ('normal', 'warmup', 'failure', 'drop_set')),
  is_completed boolean not null default false,
  created_at timestamptz not null default now()
);

create index workout_sets_exercise_idx on public.workout_sets (workout_exercise_id);

-- ---------- SOCIALNI INTERAKCE ----------

create table public.workout_likes (
  like_id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references public.workouts (workout_id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (workout_id, user_id)
);

create index workout_likes_user_idx on public.workout_likes (user_id);

create table public.workout_comments (
  comment_id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references public.workouts (workout_id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  comment_text text not null,
  created_at timestamptz not null default now()
);

create index workout_comments_workout_idx on public.workout_comments (workout_id, created_at desc);

-- ---------- RANKY ----------

create table public.user_ranks (
  rank_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  -- prave jeden z tech tri sloupcu je not null (hlidano checkem nize)
  exercise_id uuid references public.exercises (exercise_id) on delete cascade,
  sub_muscle_id uuid references public.sub_muscle_groups (sub_muscle_id) on delete cascade,
  muscle_group_id uuid references public.muscle_groups (muscle_group_id) on delete cascade,
  rank_level_name text not null default 'Bronze',
  score_ratio numeric not null default 0,
  updated_at timestamptz not null default now(),
  check (
    (case when exercise_id is not null then 1 else 0 end
     + case when sub_muscle_id is not null then 1 else 0 end
     + case when muscle_group_id is not null then 1 else 0 end) = 1
  ),
  unique (user_id, exercise_id),
  unique (user_id, sub_muscle_id),
  unique (user_id, muscle_group_id)
);

create index user_ranks_user_idx on public.user_ranks (user_id);

-- ---------- TRIGGER updated_at ----------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger workouts_set_updated_at
  before update on public.workouts
  for each row execute function public.set_updated_at();

-- ============================================================
-- RLS (Row Level Security)
-- ============================================================

alter table public.users enable row level security;
alter table public.follows enable row level security;
alter table public.muscle_groups enable row level security;
alter table public.sub_muscle_groups enable row level security;
alter table public.exercises enable row level security;
alter table public.routines enable row level security;
alter table public.routine_exercises enable row level security;
alter table public.routine_sets enable row level security;
alter table public.workouts enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.workout_sets enable row level security;
alter table public.workout_likes enable row level security;
alter table public.workout_comments enable row level security;
alter table public.user_ranks enable row level security;

-- users: kazdy prihlaseny vidi profily, kazdy si upravi jen svuj
create policy "users_select" on public.users
  for select to authenticated using (true);
create policy "users_insert" on public.users
  for insert to authenticated with check (id = auth.uid());
create policy "users_update" on public.users
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- follows: kazdy vidi, kdo koho sleduje; pridava/maze jen sve follow
create policy "follows_select" on public.follows
  for select to authenticated using (true);
create policy "follows_insert" on public.follows
  for insert to authenticated with check (follower_user_id = auth.uid());
create policy "follows_delete" on public.follows
  for delete to authenticated using (follower_user_id = auth.uid());

-- muscle_groups / sub_muscle_groups: pouze cteni (seedovane)
create policy "muscle_groups_select" on public.muscle_groups
  for select to authenticated using (true);
create policy "sub_muscle_groups_select" on public.sub_muscle_groups
  for select to authenticated using (true);

-- exercises: cteni vsem, zapis jen vlastnich cviku
create policy "exercises_select" on public.exercises
  for select to authenticated using (true);
create policy "exercises_insert" on public.exercises
  for insert to authenticated with check (user_id = auth.uid());
create policy "exercises_update" on public.exercises
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "exercises_delete" on public.exercises
  for delete to authenticated using (user_id = auth.uid());

-- routines + jejich casti: jen vlastnik
create policy "routines_select" on public.routines
  for select to authenticated using (user_id = auth.uid());
create policy "routines_insert" on public.routines
  for insert to authenticated with check (user_id = auth.uid());
create policy "routines_update" on public.routines
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "routines_delete" on public.routines
  for delete to authenticated using (user_id = auth.uid());

create policy "routine_exercises_select" on public.routine_exercises
  for select to authenticated using (
    exists (select 1 from public.routines r
            where r.routine_id = routine_exercises.routine_id
              and r.user_id = auth.uid())
  );
create policy "routine_exercises_write" on public.routine_exercises
  for all to authenticated using (
    exists (select 1 from public.routines r
            where r.routine_id = routine_exercises.routine_id
              and r.user_id = auth.uid())
  ) with check (
    exists (select 1 from public.routines r
            where r.routine_id = routine_exercises.routine_id
              and r.user_id = auth.uid())
  );

create policy "routine_sets_select" on public.routine_sets
  for select to authenticated using (
    exists (
      select 1 from public.routine_exercises re
      join public.routines r on r.routine_id = re.routine_id
      where re.routine_exercise_id = routine_sets.routine_exercise_id
        and r.user_id = auth.uid()
    )
  );
create policy "routine_sets_write" on public.routine_sets
  for all to authenticated using (
    exists (
      select 1 from public.routine_exercises re
      join public.routines r on r.routine_id = re.routine_id
      where re.routine_exercise_id = routine_sets.routine_exercise_id
        and r.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.routine_exercises re
      join public.routines r on r.routine_id = re.routine_id
      where re.routine_exercise_id = routine_sets.routine_exercise_id
        and r.user_id = auth.uid()
    )
  );

-- workouts: feed (cteni vsem prihlasenym), zapis/mazani jen vlastnik
create policy "workouts_select" on public.workouts
  for select to authenticated using (true);
create policy "workouts_insert" on public.workouts
  for insert to authenticated with check (user_id = auth.uid());
create policy "workouts_update" on public.workouts
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "workouts_delete" on public.workouts
  for delete to authenticated using (user_id = auth.uid());

-- workout_exercises / workout_sets: vlastnik materskeho workoutu
create policy "workout_exercises_select" on public.workout_exercises
  for select to authenticated using (
    exists (select 1 from public.workouts w
            where w.workout_id = workout_exercises.workout_id)
  );
create policy "workout_exercises_write" on public.workout_exercises
  for all to authenticated using (
    exists (select 1 from public.workouts w
            where w.workout_id = workout_exercises.workout_id
              and w.user_id = auth.uid())
  ) with check (
    exists (select 1 from public.workouts w
            where w.workout_id = workout_exercises.workout_id
              and w.user_id = auth.uid())
  );

create policy "workout_sets_select" on public.workout_sets
  for select to authenticated using (
    exists (
      select 1 from public.workout_exercises we
      join public.workouts w on w.workout_id = we.workout_id
      where we.workout_exercise_id = workout_sets.workout_exercise_id
    )
  );
create policy "workout_sets_write" on public.workout_sets
  for all to authenticated using (
    exists (
      select 1 from public.workout_exercises we
      join public.workouts w on w.workout_id = we.workout_id
      where we.workout_exercise_id = workout_sets.workout_exercise_id
        and w.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.workout_exercises we
      join public.workouts w on w.workout_id = we.workout_id
      where we.workout_exercise_id = workout_sets.workout_exercise_id
        and w.user_id = auth.uid()
    )
  );

-- workout_likes: cteni vsem, lajkuje/maze jen prihlaseny sam sebe
create policy "workout_likes_select" on public.workout_likes
  for select to authenticated using (true);
create policy "workout_likes_insert" on public.workout_likes
  for insert to authenticated with check (user_id = auth.uid());
create policy "workout_likes_delete" on public.workout_likes
  for delete to authenticated using (user_id = auth.uid());

-- workout_comments: cteni vsem, pise/maze jen autor
create policy "workout_comments_select" on public.workout_comments
  for select to authenticated using (true);
create policy "workout_comments_insert" on public.workout_comments
  for insert to authenticated with check (user_id = auth.uid());
create policy "workout_comments_delete" on public.workout_comments
  for delete to authenticated using (user_id = auth.uid());

-- user_ranks: cteni vsem, zapis jen vlastni radky
create policy "user_ranks_select" on public.user_ranks
  for select to authenticated using (true);
create policy "user_ranks_insert" on public.user_ranks
  for insert to authenticated with check (user_id = auth.uid());
create policy "user_ranks_update" on public.user_ranks
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "user_ranks_delete" on public.user_ranks
  for delete to authenticated using (user_id = auth.uid());
