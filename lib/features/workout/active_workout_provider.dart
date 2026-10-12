import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../exercises/exercise_repository.dart';

class WorkoutSet {
  WorkoutSet({
    this.weightKg,
    this.reps = 0,
    this.setType = 'normal',
    this.isCompleted = false,
  });

  double? weightKg;
  int reps;
  String setType;
  bool isCompleted;
}

class WorkoutExercise {
  WorkoutExercise(this.exercise);

  final Exercise exercise;
  final List<WorkoutSet> sets = [];
}

class ActiveWorkout {
  ActiveWorkout({required this.startedAt, required this.exercises});

  final DateTime startedAt;
  final List<WorkoutExercise> exercises;

  bool get isEmpty => exercises.isEmpty;

  double get totalVolume {
    var volume = 0.0;
    for (final exercise in exercises) {
      for (final set in exercise.sets) {
        volume += (set.weightKg ?? 0) * set.reps;
      }
    }
    return volume;
  }
}

final activeWorkoutProvider =
    NotifierProvider<ActiveWorkoutController, ActiveWorkout>(
  ActiveWorkoutController.new,
);

class ActiveWorkoutController extends Notifier<ActiveWorkout> {
  @override
  ActiveWorkout build() =>
      ActiveWorkout(startedAt: DateTime.now(), exercises: []);

  void addExercise(Exercise exercise) {
    final entry = WorkoutExercise(exercise)
      ..sets.add(WorkoutSet(weightKg: 0, reps: 0));
    _update((exercises) => exercises.add(entry));
  }

  void removeExercise(int index) {
    _update((exercises) => exercises.removeAt(index));
  }

  void addSet(int exerciseIndex) {
    _update((exercises) {
      final sets = exercises[exerciseIndex].sets;
      final last = sets.isNotEmpty ? sets.last : null;
      sets.add(WorkoutSet(weightKg: last?.weightKg ?? 0, reps: last?.reps ?? 0));
    });
  }

  void updateSet(
    int exerciseIndex,
    int setIndex, {
    required double? weightKg,
    required int? reps,
  }) {
    _update((exercises) {
      final set = exercises[exerciseIndex].sets[setIndex];
      set.weightKg = weightKg;
      set.reps = reps ?? 0;
    });
  }

  void setSetType(int exerciseIndex, int setIndex, String setType) {
    _update((exercises) =>
        exercises[exerciseIndex].sets[setIndex].setType = setType);
  }

  void toggleSetComplete(int exerciseIndex, int setIndex) {
    _update((exercises) {
      final set = exercises[exerciseIndex].sets[setIndex];
      set.isCompleted = !set.isCompleted;
    });
  }

  void removeSet(int exerciseIndex, int setIndex) {
    _update((exercises) =>
        exercises[exerciseIndex].sets.removeAt(setIndex));
  }

  void reset() {
    state = ActiveWorkout(startedAt: DateTime.now(), exercises: []);
  }

  void _update(void Function(List<WorkoutExercise>) mutate) {
    mutate(state.exercises);
    state = ActiveWorkout(
      startedAt: state.startedAt,
      exercises: List.of(state.exercises),
    );
  }

  Future<String?> finish(String title) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return 'Not signed in.';
    if (state.isEmpty) return 'Add at least one exercise.';

    try {
      final workoutRow = await client
          .from('workouts')
          .insert({
            'user_id': userId,
            'workout_title': title,
            'duration_seconds':
                DateTime.now().difference(state.startedAt).inSeconds,
            'total_volume_kg': state.totalVolume,
          })
          .select('workout_id')
          .single();

      for (var i = 0; i < state.exercises.length; i++) {
        final entry = state.exercises[i];
        final exerciseRow = await client
            .from('workout_exercises')
            .insert({
              'workout_id': workoutRow['workout_id'],
              'exercise_id': entry.exercise.id,
              'order_index': i,
            })
            .select('workout_exercise_id')
            .single();

        for (var s = 0; s < entry.sets.length; s++) {
          final set = entry.sets[s];
          await client.from('workout_sets').insert({
            'workout_exercise_id': exerciseRow['workout_exercise_id'],
            'set_number': s + 1,
            'weight_kg': set.weightKg,
            'reps_count': set.reps > 0 ? set.reps : null,
            'set_type': set.setType,
            'is_completed': set.isCompleted,
          });
        }
      }

      reset();
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save workout. Please try again.';
    }
  }
}

String _formatPrevSet(num? weightKg, int? reps) {
  final parts = <String>[];
  if (weightKg != null) {
    final w = weightKg.toDouble();
    parts.add('${w == w.truncateToDouble() ? w.toInt() : w}kg');
  }
  if (reps != null) parts.add('x$reps');
  return parts.join(' ');
}

/// exerciseId -> (setNumber -> "20kg x 10") z posledniho ulozeneho workoutu
final previousWorkoutSetsProvider =
    FutureProvider<Map<String, Map<int, String>>>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return {};

  final lastWorkout = await client
      .from('workouts')
      .select('workout_id')
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  if (lastWorkout == null) return {};

  final rows = await client.from('workout_sets').select('''
        set_number, weight_kg, reps_count,
        workout_exercises!inner(exercise_id, workout_id)
      ''').eq('workout_exercises.workout_id', lastWorkout['workout_id']);

  final result = <String, Map<int, String>>{};
  for (final row in rows) {
    final exercise = row['workout_exercises'];
    final exerciseId =
        exercise is Map ? exercise['exercise_id'] as String? : null;
    if (exerciseId == null) continue;
    final setNumber = row['set_number'] as int;
    final label = _formatPrevSet(
      row['weight_kg'] as num?,
      row['reps_count'] as int?,
    );
    if (label.isEmpty) continue;
    result.putIfAbsent(exerciseId, () => {})[setNumber] = label;
  }
  return result;
});
