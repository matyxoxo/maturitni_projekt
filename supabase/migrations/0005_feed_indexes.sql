-- Indexy pro feed (workouty podle uzivatele + pocet lajku/komentaru).
create index if not exists workouts_user_created_idx
  on public.workouts (user_id, created_at desc);

create index if not exists workout_likes_workout_idx
  on public.workout_likes (workout_id);
