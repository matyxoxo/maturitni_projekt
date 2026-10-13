import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../exercises/exercise_repository.dart';

// ============================================================
//  Modely dat
// ============================================================

/// Cilova hodnota pro jednu serii v rutine (co ma uzivatel saset).
class RoutineSetTarget {
  RoutineSetTarget({
    this.weightKg,
    this.reps = 0,
    this.durationSeconds,
    this.distanceMeters,
    this.setType = 'normal',
  });

  double? weightKg;
  int reps;
  int? durationSeconds;
  double? distanceMeters;
  String setType;
}

/// Rozepsany cvik v builderu rutiny (cvik + jeho cilove serie).
class RoutineExerciseDraft {
  RoutineExerciseDraft({
    required this.exercise,
    List<RoutineSetTarget>? targets,
  }) : targets = targets ?? [];

  final Exercise exercise;
  final List<RoutineSetTarget> targets;
}

/// Ulozena rutina (seznam cviku bez detailu serii).
class Routine {
  const Routine({
    required this.routineId,
    required this.name,
    required this.exerciseNames,
  });

  final String routineId;
  final String name;
  final List<String> exerciseNames;
}

// ============================================================
//  Cteni z DB
// ============================================================

/// Seznam vsech rutin prihlaseneho uzivatele.
final routinesProvider = FutureProvider<List<Routine>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  final rows = await Supabase.instance.client.from('routines').select('''
        routine_id, routine_name,
        routine_exercises (
          exercises (exercise_name)
        )
      ''').eq('user_id', userId).order('created_at', ascending: false);
  return rows.map((row) {
    final exercises = (row['routine_exercises'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return Routine(
      routineId: row['routine_id'] as String,
      name: row['routine_name'] as String,
      exerciseNames: [
        for (final ex in exercises)
          if (ex['exercises'] != null)
            ex['exercises']['exercise_name'] as String,
      ],
    );
  }).toList();
});

/// Detail rutiny (cviky + cilove serie) pro builder i pro start workoutu.
Future<List<RoutineExerciseDraft>> _loadRoutineDetail(String routineId) async {
  final rows = await Supabase.instance.client
      .from('routine_exercises')
      .select('''
        order_index,
        exercises (
          exercise_id, exercise_name, exercise_type, equipment,
          exercise_icon_url,
          sub_muscle_groups (sub_muscle_name, muscle_groups (muscle_group_name))
        ),
        routine_sets (
          set_number, target_weight_kg, target_reps,
          set_type, duration_seconds, distance_meters
        )
      ''')
      .eq('routine_id', routineId)
      .order('order_index');
  final result = <RoutineExerciseDraft>[];
  for (final row in rows) {
    final exRow = row['exercises'] as Map<String, dynamic>?;
    if (exRow == null) continue;
    final sets = (row['routine_sets'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
      ..sort((a, b) =>
          (a['set_number'] as int? ?? 0).compareTo(b['set_number'] as int? ?? 0));
    result.add(
      RoutineExerciseDraft(
        exercise: Exercise.fromRow(exRow),
        targets: [
          for (final set in sets)
            RoutineSetTarget(
              weightKg: (set['target_weight_kg'] as num?)?.toDouble(),
              reps: set['target_reps'] as int? ?? 0,
              durationSeconds: set['duration_seconds'] as int?,
              distanceMeters: (set['distance_meters'] as num?)?.toDouble(),
              setType: set['set_type'] as String? ?? 'normal',
            ),
        ],
      ),
    );
  }
  return result;
}

final routineDetailProvider =
    FutureProvider.family<List<RoutineExerciseDraft>, String>(
        (ref, routineId) => _loadRoutineDetail(routineId));

// ============================================================
//  Zapis do DB
// ============================================================

/// Ulozi rutinu (vytvori novou nebo prepise existujici). Vrati jeji id.
Future<String> saveRoutine({
  String? routineId,
  required String name,
  required List<RoutineExerciseDraft> exercises,
}) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw Exception('Not signed in.');

  final id = routineId == null
      ? await _createRoutine(client, userId, name)
      : await _replaceRoutine(client, routineId, name);

  for (var i = 0; i < exercises.length; i++) {
    await _saveRoutineExercise(client, id, exercises[i], i);
  }
  return id;
}

Future<String> _createRoutine(
  SupabaseClient client,
  String userId,
  String name,
) async {
  final row = await client
      .from('routines')
      .insert({'user_id': userId, 'routine_name': name})
      .select('routine_id')
      .single();
  return row['routine_id'] as String;
}

Future<String> _replaceRoutine(
  SupabaseClient client,
  String routineId,
  String name,
) async {
  await client
      .from('routines')
      .update({'routine_name': name}).eq('routine_id', routineId);
  await client
      .from('routine_exercises')
      .delete()
      .eq('routine_id', routineId);
  return routineId;
}

Future<void> _saveRoutineExercise(
  SupabaseClient client,
  String routineId,
  RoutineExerciseDraft draft,
  int orderIndex,
) async {
  final exRow = await client
      .from('routine_exercises')
      .insert({
        'routine_id': routineId,
        'exercise_id': draft.exercise.id,
        'order_index': orderIndex,
      })
      .select('routine_exercise_id')
      .single();
  final routineExerciseId = exRow['routine_exercise_id'] as String;

  for (var s = 0; s < draft.targets.length; s++) {
    await _saveRoutineSet(client, routineExerciseId, s + 1, draft.targets[s]);
  }
}

Future<void> _saveRoutineSet(
  SupabaseClient client,
  String routineExerciseId,
  int setNumber,
  RoutineSetTarget target,
) async {
  await client.from('routine_sets').insert({
    'routine_exercise_id': routineExerciseId,
    'set_number': setNumber,
    'target_weight_kg': target.weightKg,
    'target_reps': target.reps > 0 ? target.reps : null,
    'set_type': target.setType,
    'duration_seconds': target.durationSeconds,
    'distance_meters': target.distanceMeters,
  });
}

Future<void> deleteRoutine(String routineId) async {
  await Supabase.instance.client
      .from('routines')
      .delete()
      .eq('routine_id', routineId);
}
