-- ============================================================
-- AlphaLift - demo data pro overeni ranku
--
-- Ucel: vlozi 3 dokoncene treninky ([RANK DEMO] Session 1-3)
-- do uctu matej.bilik2@gmail.com, aby bylo v aplikaci videt
-- cely rank strom (cvik -> podsval -> skupina -> global).
--
-- Co skript dela:
--   1. overi, ze ucet existuje v auth.users
--   2. pripadne doplni chybejici radek v public.users
--   3. body_weight_kg nastavi na 80 kg JEN pokud je NULL
--      (existujici vahu nikdy neprepise)
--   4. sex nastavi na 'male' JEN pokud je NULL
--   5. smaze predchozi [RANK DEMO] treninky a vlozi nove
--   6. realne treninky uzivatele se nikdy nedotkne
--
-- Vahy cviku jsou demo cisla. Ranky z nich pocita aplikace
-- z ostre tabulky Strength Level pro danou vahu a pohlavi.
--
-- Spusteni: Supabase Dashboard -> SQL Editor -> vlozit cely
-- soubor -> Run.
-- ============================================================

-- Idempotentni priprava sloupce pro pohlavi (migrace 0006).
alter table public.users
  add column if not exists sex text check (sex in ('male', 'female'));

do $$
declare
  v_user_id uuid;
  v_email text;
  v_username text;
  v_workout_id uuid;
  v_exercise_id uuid;
  v_workout_exercise_id uuid;
  v_session int;
  v_days int;
  v_mult numeric;
  v_reps int;
  v_order int;
  v_set_number int;
  v_weight numeric;
  v_created_at timestamptz;
  r record;
begin
  -- ---------- 1) Najdi ucet ----------
  select u.id, u.email
    into v_user_id, v_email
  from auth.users u
  where lower(u.email) in (
    'matej.bilik2@gmail.com',
    'maty.bilik2@gmail.com'
  )
  order by u.created_at
  limit 1;

  if v_user_id is null then
    raise exception
      'Ucet matej.bilik2@gmail.com nebyl nalezen v auth.users.';
  end if;

  raise notice 'Nalezen ucet: % (%)', v_email, v_user_id;

  -- ---------- 2) Pripadne doplni public.users ----------
  if not exists (select 1 from public.users where id = v_user_id) then
    v_username := left(
      regexp_replace(split_part(v_email, '@', 1), '[^a-zA-Z0-9_]', '', 'g'),
      12
    );

    if char_length(v_username) < 3 then
      v_username := 'demo';
    end if;

    v_username := v_username || '_' || substr(v_user_id::text, 1, 4);

    insert into public.users (id, email, username)
    values (v_user_id, v_email, v_username);

    raise notice 'Vytvoren radek public.users s username %', v_username;
  end if;

  -- ---------- 3) Vaha a pohlavi jen kdyz chybi ----------
  update public.users
  set body_weight_kg = coalesce(body_weight_kg, 80),
      sex = coalesce(sex, 'male')
  where id = v_user_id;

  -- ---------- 4) Uklid predchozich demo dat ----------
  delete from public.workouts
  where user_id = v_user_id
    and workout_title like '[RANK DEMO]%';

  -- ---------- 5) Tri treninky ----------
  -- Session 1: 21 dni zpet, 90 % vahy, 8 opakovani
  -- Session 2: 14 dni zpet, 100 % vahy, 8 opakovani
  -- Session 3:  7 dni zpet, 108 % vahy, 6 opakovani
  for v_session in 1..3 loop
    v_days := case v_session when 1 then 21 when 2 then 14 else 7 end;
    v_mult := case v_session when 1 then 0.90 when 2 then 1.00 else 1.08 end;
    v_reps := case v_session when 3 then 6 else 8 end;
    v_created_at := date_trunc('day', now())
      - make_interval(days => v_days)
      + interval '18 hours';

    insert into public.workouts (
      user_id, workout_title, duration_seconds, created_at, updated_at
    ) values (
      v_user_id,
      '[RANK DEMO] Session ' || v_session,
      3600,
      v_created_at,
      v_created_at
    )
    returning workout_id into v_workout_id;

    v_order := 0;

    for r in
      select *
      from (values
        ('Barbell Bench Press',              110::numeric),
        ('Dumbbell Fly',                      16::numeric),
        ('Barbell Seated Overhead Press',     62::numeric),
        ('Dumbbell Lateral Raise',            14::numeric),
        ('Cable Kneeling Crunch',             45::numeric),
        ('Lever Seated Crunch',               50::numeric),
        ('Barbell Curl',                      42::numeric),
        ('Dumbbell Hammer Curl',              22::numeric),
        ('Cable Pushdown',                    50::numeric),
        ('Barbell Lying Triceps Extension',   40::numeric),
        ('Barbell Wrist Curl',                45::numeric),
        ('Dumbbell Reverse Wrist Curl',       12::numeric),
        ('Cable Bar Lateral Pulldown',        80::numeric),
        ('Cable Straight Arm Pulldown',       40::numeric),
        ('Barbell Bent Over Row',             85::numeric),
        ('Cable Seated Row',                  85::numeric),
        ('Lever Back Extension',              70::numeric),
        ('Barbell Shrug',                    120::numeric),
        ('Dumbbell Shrug',                    42::numeric),
        ('Lever Leg Extension',               90::numeric),
        ('Dumbbell Goblet Squat',             36::numeric),
        ('Lever Lying Leg Curl',              58::numeric),
        ('Lever Seated Leg Curl',             72::numeric),
        ('Barbell Full Squat',               140::numeric),
        ('Barbell Deadlift',                 170::numeric),
        ('Lever Standing Calf Raise',        130::numeric),
        ('Lever Seated Calf Raise',           85::numeric),
        ('Lever Seated Hip Adduction',        45::numeric),
        ('Lever Seated Hip Abduction',        45::numeric)
      ) as t(exercise_name, base_weight)
    loop
      select e.exercise_id
        into v_exercise_id
      from public.exercises e
      where e.exercise_name = r.exercise_name
        and e.user_id is null
      order by e.created_at, e.exercise_id
      limit 1;

      if v_exercise_id is null then
        raise exception
          'Cvik "%" nebyl nalezen v public.exercises.', r.exercise_name;
      end if;

      insert into public.workout_exercises (
        workout_id, exercise_id, order_index
      ) values (
        v_workout_id, v_exercise_id, v_order
      )
      returning workout_exercise_id into v_workout_exercise_id;

      v_order := v_order + 1;

      -- Zaokrouhleni na pul kilogramu, aby data vypadala jako
      -- realne zaznamy z posilovny.
      v_weight := round(r.base_weight * v_mult * 2) / 2;

      for v_set_number in 1..3 loop
        insert into public.workout_sets (
          workout_exercise_id,
          set_number,
          weight_kg,
          reps_count,
          set_type,
          is_completed,
          created_at
        ) values (
          v_workout_exercise_id,
          v_set_number,
          v_weight,
          v_reps,
          'normal',
          true,
          v_created_at
        );
      end loop;
    end loop;

    -- total_volume_kg se v DB nedrzi (migrace 0004 ho odstranila),
    -- objem se pocita az z workout_sets v aplikaci.
  end loop;

  raise notice 'Hotovo: 3 demo treninky vlozeny pro %', v_email;
end $$;

-- ---------- 6) Kontrola ----------
select
  w.workout_title,
  w.created_at::date as workout_date,
  count(distinct we.workout_exercise_id) as exercises,
  count(ws.set_id) as sets
from public.workouts w
left join public.workout_exercises we
  on we.workout_id = w.workout_id
left join public.workout_sets ws
  on ws.workout_exercise_id = we.workout_exercise_id
where w.user_id = (
  select id
  from auth.users
  where lower(email) in (
    'matej.bilik2@gmail.com',
    'maty.bilik2@gmail.com'
  )
  order by created_at
  limit 1
)
  and w.workout_title like '[RANK DEMO]%'
group by w.workout_id, w.workout_title, w.created_at
order by w.created_at;

-- ============================================================
-- UKLID DEMO DAT (spustit samostatne, az nebudou potreba):
--
-- delete from public.workouts
-- where user_id = (
--   select id from auth.users
--   where lower(email) in ('matej.bilik2@gmail.com', 'maty.bilik2@gmail.com')
--   order by created_at
--   limit 1
-- )
--   and workout_title like '[RANK DEMO]%';
-- ============================================================
