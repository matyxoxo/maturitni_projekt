-- Presun cviku do podsvalu podle primarniho svalu.
--
-- Katalog pochazi z ExerciseDB, ktery vetsinu drepu a leg pressu vede pod
-- Glutes. Pro rank je rozhodujici primarni sval, proto:
--   * drepy a leg press -> Quadriceps
--   * rumunske / stiff-leg deadlifty a good mornings -> Hamstrings
--
-- Duvod: u drepu je primarni sval quadriceps (Symmetry tak vede hack squat
-- i high bar squat), u RDL a stiff-leg deadliftu hamstring. Nejde o nova
-- data, jen o spravne zarazeni existujicich cviku.

do $$
declare
  v_quads uuid;
  v_hams uuid;
begin
  select sg.sub_muscle_id into v_quads
  from public.sub_muscle_groups sg
  join public.muscle_groups mg on mg.muscle_group_id = sg.muscle_group_id
  where mg.muscle_group_name = 'Legs'
    and sg.sub_muscle_name = 'Quadriceps';

  select sg.sub_muscle_id into v_hams
  from public.sub_muscle_groups sg
  join public.muscle_groups mg on mg.muscle_group_id = sg.muscle_group_id
  where mg.muscle_group_name = 'Legs'
    and sg.sub_muscle_name = 'Hamstrings';

  if v_quads is null or v_hams is null then
    raise exception 'Chybi podsvaly Quadriceps/Hamstrings v sub_muscle_groups';
  end if;

  -- Drepy (vcetne hack squatu, goblet, pistol a jump variant).
  update public.exercises
  set sub_muscle_id = v_quads
  where exercise_name in (
    'Band Squat',
    'Barbell Clean-grip Front Squat',
    'Barbell Front Chest Squat',
    'Barbell Front Squat',
    'Barbell Full Squat',
    'Barbell Full Squat (back Pov)',
    'Barbell Full Squat (side Pov)',
    'Barbell Full Zercher Squat',
    'Barbell Hack Squat',
    'Barbell High Bar Squat',
    'Barbell Jefferson Squat',
    'Barbell Jump Squat',
    'Barbell Low Bar Squat',
    'Barbell Narrow Stance Squat',
    'Barbell Speed Squat',
    'Barbell Zercher Squat',
    'Bodyweight Drop Jump Squat',
    'Curtsey Squat',
    'Dumbbell Bench Squat',
    'Dumbbell Plyo Squat',
    'Dumbbell Single Leg Squat',
    'Dumbbell Squat',
    'Frankenstein Squat',
    'Jump Squat',
    'Jump Squat V. 2',
    'Kettlebell Front Squat',
    'Kettlebell Goblet Squat',
    'Kettlebell Pistol Squat',
    'Kneeling Jump Squat',
    'One Leg Squat',
    'Potty Squat with Support',
    'Single Leg Squat (pistol) Male',
    'Sled Closer Hack Squat',
    'Sled Hack Squat',
    'Sled Lying Squat',
    'Smith Front Squat (clean Grip)',
    'Smith Full Squat',
    'Smith Hack Squat',
    'Smith Low Bar Squat',
    'Smith Squat',
    'Smith Sumo Squat',
    'Weighted Cossack Squats (male)',
    'Weighted Squat'
  );

  -- Leg press. Varianty "Sled 45..." maji v katalogu rozbity znak stupne,
  -- proto se matchuji prefixem a ne presnym nazvem.
  update public.exercises
  set sub_muscle_id = v_quads
  where exercise_name in (
    'Lever Horizontal One Leg Press',
    'Sled 45 Degrees One Leg Press',
    'Smith Leg Press'
  )
     or exercise_name like 'Sled 45%Leg Press%'
     or exercise_name like 'Sled 45%Leg Wide Press%';

  -- Hamstring-dominantni varianty deadliftu a good morning.
  update public.exercises
  set sub_muscle_id = v_hams
  where exercise_name in (
    'Band Stiff Leg Deadlift',
    'Band Straight Back Stiff Leg Deadlift',
    'Barbell Romanian Deadlift',
    'Barbell Seated Good Morning',
    'Barbell Stiff Leg Good Morning',
    'Dumbbell Romanian Deadlift',
    'Dumbbell Stiff Leg Deadlift',
    'Dumbbell Straight Leg Deadlift',
    'Lever Seated Good Morning',
    'Smith Bent Knee Good Morning'
  );
end $$;

-- ---------- OSTATNI SKUPINY ----------
-- Stejne pravidlo: cvik patri tam, kde je primarni sval. Opravujeme jen
-- pripady, kde to nazev jednoznacne urcuje.

do $$
declare
  v_front uuid;
  v_rear uuid;
  v_abs uuid;
  v_quads uuid;
  v_hams uuid;
begin
  select sg.sub_muscle_id into v_front
  from public.sub_muscle_groups sg
  join public.muscle_groups mg on mg.muscle_group_id = sg.muscle_group_id
  where mg.muscle_group_name = 'Shoulders'
    and sg.sub_muscle_name = 'Front Delts';

  select sg.sub_muscle_id into v_rear
  from public.sub_muscle_groups sg
  join public.muscle_groups mg on mg.muscle_group_id = sg.muscle_group_id
  where mg.muscle_group_name = 'Shoulders'
    and sg.sub_muscle_name = 'Rear Delts';

  select sg.sub_muscle_id into v_abs
  from public.sub_muscle_groups sg
  join public.muscle_groups mg on mg.muscle_group_id = sg.muscle_group_id
  where mg.muscle_group_name = 'Core'
    and sg.sub_muscle_name = 'Abs';

  select sg.sub_muscle_id into v_quads
  from public.sub_muscle_groups sg
  join public.muscle_groups mg on mg.muscle_group_id = sg.muscle_group_id
  where mg.muscle_group_name = 'Legs'
    and sg.sub_muscle_name = 'Quadriceps';

  select sg.sub_muscle_id into v_hams
  from public.sub_muscle_groups sg
  join public.muscle_groups mg on mg.muscle_group_id = sg.muscle_group_id
  where mg.muscle_group_name = 'Legs'
    and sg.sub_muscle_name = 'Hamstrings';

  if v_front is null or v_rear is null or v_abs is null
     or v_quads is null or v_hams is null then
    raise exception 'Chybi nektery podsval pro reklasifikaci';
  end if;

  -- Tlaky nad hlavou a shoulder pressy maji primarne predni deltovy sval.
  update public.exercises
  set sub_muscle_id = v_front
  where exercise_name in (
    'Band Shoulder Press',
    'Cable Alternate Shoulder Press',
    'Cable Shoulder Press',
    'Dumbbell One Arm Shoulder Press',
    'Dumbbell One Arm Shoulder Press V. 2',
    'Dumbbell Push Press',
    'Dumbbell Seated Shoulder Press',
    'Dumbbell Seated Shoulder Press (parallel Grip)',
    'Kettlebell Double Push Press',
    'Kettlebell One Arm Push Press',
    'Lever One Arm Shoulder Press',
    'Lever Shoulder Press',
    'Lever Shoulder Press V. 2',
    'Lever Shoulder Press V. 3',
    'Resistance Band Seated Shoulder Press',
    'Smith Seated Shoulder Press',
    'Smith Shoulder Press'
  );

  -- Reverse fly, Y-raise a rear-delt row maji primarne zadni deltovy sval.
  update public.exercises
  set sub_muscle_id = v_rear
  where exercise_name in (
    'Band Y-raise',
    'Cable Cross-over Revers Fly',
    'Dumbbell Incline Y-raise',
    'Dumbbell Lying Rear Delt Row'
  );

  -- Klasicke crunch varianty zapojuji primarne rectus abdominis (Abs),
  -- ne oblique. Twist/side varianty zustavaji v Obliques.
  update public.exercises
  set sub_muscle_id = v_abs
  where exercise_name in (
    'Band Standing Crunch',
    'Cable Kneeling Crunch',
    'Cable Seated Crunch',
    'Cable Standing Crunch',
    'Cable Standing Crunch (with Rope Attachment)',
    'Lever Seated Crunch',
    'Lever Seated Crunch (chest Pad)',
    'Lever Seated Crunch V. 2',
    'Weighted Crunch',
    'Weighted Overhead Crunch (on Stability Ball)'
  );

  -- Cviky, ktere byly omylem v jine skupine nez v Legs.
  update public.exercises
  set sub_muscle_id = v_hams
  where exercise_name in (
    'Band Straight Leg Deadlift'
  );

  update public.exercises
  set sub_muscle_id = v_quads
  where exercise_name in (
    'Lunge with Twist',
    'Potty Squat'
  );
end $$;
