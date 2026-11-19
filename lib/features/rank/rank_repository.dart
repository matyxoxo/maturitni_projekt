import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'rank_engine.dart';
import 'rank_model.dart';
import 'rank_standards.dart';

/// Vypočítá ranky přihlášeného uživatele z celé historie tréninků.
///
/// Nic se neukládá – rank je vždy odvozený z dat, takže změna váhy těla
/// nebo úprava tréninku se projeví okamžitě po invalidaci provideru.
final rankReportProvider = FutureProvider.autoDispose<RankReport>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const RankReport.empty();

  final userRow = await client
      .from('users')
      .select('body_weight_kg, sex')
      .eq('id', userId)
      .maybeSingle();

  final bodyWeightKg = (userRow?['body_weight_kg'] as num?)?.toDouble();
  if (bodyWeightKg == null || bodyWeightKg <= 0) {
    return const RankReport.empty();
  }
  final sex = RankSex.fromDatabase(userRow?['sex'] as String?);

  final workouts = <Map<String, dynamic>>[];
  const pageSize = 200;
  var from = 0;

  while (true) {
    final batch = await client
        .from('workouts')
        .select('''
          workout_id, created_at,
          workout_exercises (
            exercise_id,
            exercises (
              exercise_name,
              sub_muscle_groups (
                sub_muscle_name, muscle_groups (muscle_group_name)
              )
            ),
            workout_sets (weight_kg, reps_count, set_type, is_completed)
          )
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .order('workout_id')
        .range(from, from + pageSize - 1);

    workouts.addAll(batch);
    if (batch.length < pageSize) break;
    from += pageSize;
  }

  return buildRankReport(
    history: _buildHistory(workouts),
    bodyWeightKg: bodyWeightKg,
    sex: sex,
  );
});

class _HistoryBuilder {
  _HistoryBuilder(this.name, this.muscleGroup, this.subMuscle);

  final String name;
  final String muscleGroup;
  final String subMuscle;
  final List<RankSessionLog> sessions = [];
}

List<RankExerciseHistory> _buildHistory(List<Map<String, dynamic>> workouts) {
  final builders = <String, _HistoryBuilder>{};

  for (final workout in workouts) {
    final createdAt = DateTime.parse(workout['created_at'] as String);

    for (final exerciseRow
        in (workout['workout_exercises'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()) {
      final exercise = exerciseRow['exercises'] as Map<String, dynamic>?;
      final name = exercise?['exercise_name'] as String?;
      if (exercise == null || name == null || name.isEmpty) continue;

      final subMuscleRow = exercise['sub_muscle_groups'] as Map<String, dynamic>?;
      final groupRow =
          subMuscleRow?['muscle_groups'] as Map<String, dynamic>?;

      final sets = <RankSetLog>[
        for (final raw
            in (exerciseRow['workout_sets'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>())
          RankSetLog(
            weightKg: (raw['weight_kg'] as num?)?.toDouble() ?? 0,
            reps: raw['reps_count'] as int? ?? 0,
            setType: raw['set_type'] as String? ?? 'normal',
            isCompleted: raw['is_completed'] as bool? ?? false,
          ),
      ];

      if (sets.isEmpty) continue;

      // Seskupujeme podle názvu, ne podle exercise_id – v katalogu jsou
      // duplicitní cviky se stejným jménem a historie se tím nerozdělí.
      final builder = builders.putIfAbsent(
        rankExerciseKey(name),
        () => _HistoryBuilder(
          name,
          groupRow?['muscle_group_name'] as String? ?? '',
          subMuscleRow?['sub_muscle_name'] as String? ?? '',
        ),
      );
      builder.sessions.add(RankSessionLog(date: createdAt, sets: sets));
    }
  }

  return [
    for (final builder in builders.values)
      RankExerciseHistory(
        name: builder.name,
        muscleGroup: builder.muscleGroup,
        subMuscle: builder.subMuscle,
        sessions: builder.sessions,
      ),
  ];
}
