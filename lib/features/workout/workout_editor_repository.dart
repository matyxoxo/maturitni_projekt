import 'package:supabase_flutter/supabase_flutter.dart';

import 'active_workout_provider.dart';

/// Ulozi upraveny ulozeny workout.
///
/// Aktualizuje radek v `workouts`, smaze puvodni cviky (serie se smazou
/// kaskadove) a vlozi cviky i serie znovu. Vraci null pri uspechu, jinak
/// chybovou hlasku.
Future<String?> saveWorkoutEdits({
  required String workoutId,
  required String title,
  required int durationSeconds,
  required DateTime startedAt,
  required List<WorkoutExercise> exercises,
}) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser?.id == null) return 'Not signed in.';
  if (exercises.isEmpty) return 'Add at least one exercise.';

  try {
    await client
        .from('workouts')
        .update({
          'workout_title': title,
          'duration_seconds': durationSeconds,
          // Datum a cas, kdy workout zacal.
          'created_at': startedAt.toUtc().toIso8601String(),
        })
        .eq('workout_id', workoutId);

    // Serie se smazou spolu s cviky (on delete cascade).
    await client.from('workout_exercises').delete().eq('workout_id', workoutId);

    for (var i = 0; i < exercises.length; i++) {
      final entry = exercises[i];
      final exerciseRow = await client
          .from('workout_exercises')
          .insert({
            'workout_id': workoutId,
            'exercise_id': entry.exercise.id,
            'order_index': i,
          })
          .select('workout_exercise_id')
          .single();

      final workoutExerciseId = exerciseRow['workout_exercise_id'] as String;
      for (var s = 0; s < entry.sets.length; s++) {
        final set = entry.sets[s];
        await client.from('workout_sets').insert({
          'workout_exercise_id': workoutExerciseId,
          'set_number': s + 1,
          'weight_kg': set.weightKg,
          'reps_count': set.reps > 0 ? set.reps : null,
          'duration_seconds': set.durationSeconds,
          'distance_meters': set.distanceMeters,
          'set_type': set.setType,
          'is_completed': set.isCompleted,
        });
      }
    }
    return null;
  } on PostgrestException catch (e) {
    return e.message;
  } catch (_) {
    return 'Could not save workout. Please try again.';
  }
}
