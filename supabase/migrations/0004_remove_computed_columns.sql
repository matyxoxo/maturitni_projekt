-- Odebrani odvozenych (vypoctenych) hodnot - nemaji byt v DB.
-- total_volume_kg se pocita z workout_sets, score_ratio a rank_level_name z workout dat.

alter table public.workouts drop column if exists total_volume_kg;
alter table public.user_ranks drop column if exists score_ratio;
alter table public.user_ranks drop column if exists rank_level_name;
