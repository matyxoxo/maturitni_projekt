import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
//  Seznam workoutu (karta na Home)
// ============================================================

/// Strucny popis jednoho cviku v prehledu (nazev + gif).
class WorkoutExerciseBrief {
  const WorkoutExerciseBrief({
    required this.exerciseId,
    required this.name,
    this.gifUrl,
  });

  final String exerciseId;
  final String name;
  final String? gifUrl;
}

/// Jeden workout v prehledu na Home obrazovce.
class WorkoutSummary {
  const WorkoutSummary({
    required this.workoutId,
    required this.title,
    required this.createdAt,
    required this.durationSeconds,
    required this.totalVolumeKg,
    required this.username,
    required this.profilePhotoUrl,
    required this.exercises,
  });

  final String workoutId;
  final String title;
  final DateTime createdAt;
  final int? durationSeconds;
  final double? totalVolumeKg;
  final String username;
  final String? profilePhotoUrl;
  final List<WorkoutExerciseBrief> exercises;

  factory WorkoutSummary.fromRow(Map<String, dynamic> row) {
    final user = row['users'] as Map<String, dynamic>?;
    final exerciseRows =
        (row['workout_exercises'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
          ..sort((a, b) =>
              (a['order_index'] as int? ?? 0)
                  .compareTo(b['order_index'] as int? ?? 0));
    final exercises = [
      for (final ex in exerciseRows)
        if (ex['exercises'] != null)
          WorkoutExerciseBrief(
            exerciseId: ex['exercises']['exercise_id'] as String,
            name: ex['exercises']['exercise_name'] as String,
            gifUrl: ex['exercises']['exercise_icon_url'] as String?,
          ),
    ];
    return WorkoutSummary(
      workoutId: row['workout_id'] as String,
      title: row['workout_title'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      durationSeconds: row['duration_seconds'] as int?,
      totalVolumeKg: (row['total_volume_kg'] as num?)?.toDouble(),
      username: user?['username'] as String? ?? 'Unknown',
      profilePhotoUrl: user?['profile_photo_url'] as String?,
      exercises: exercises,
    );
  }
}

/// Poslednich 50 workoutu prihlaseneho uzivatele (razeno od nejnovejsiho).
final myWorkoutsProvider = FutureProvider<List<WorkoutSummary>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  final rows = await Supabase.instance.client.from('workouts').select('''
        workout_id, workout_title, created_at, duration_seconds,
        total_volume_kg,
        users (username, profile_photo_url),
        workout_exercises (
          order_index,
          exercises (exercise_id, exercise_name, exercise_icon_url)
        )
      ''').eq('user_id', userId).order('created_at', ascending: false).limit(50);
  return rows.map(WorkoutSummary.fromRow).toList();
});

// ============================================================
//  Detail workoutu (obrazovka /history/:id)
// ============================================================

/// Jedna serie v detailu workoutu.
class WorkoutSetDetail {
  const WorkoutSetDetail({
    required this.setNumber,
    required this.weightKg,
    required this.repsCount,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.setType,
    required this.isCompleted,
  });

  final int setNumber;
  final double? weightKg;
  final int? repsCount;
  final int? durationSeconds;
  final double? distanceMeters;
  final String setType;
  final bool isCompleted;

  factory WorkoutSetDetail.fromRow(Map<String, dynamic> row) {
    return WorkoutSetDetail(
      setNumber: row['set_number'] as int? ?? 1,
      weightKg: (row['weight_kg'] as num?)?.toDouble(),
      repsCount: row['reps_count'] as int?,
      durationSeconds: row['duration_seconds'] as int?,
      distanceMeters: (row['distance_meters'] as num?)?.toDouble(),
      setType: row['set_type'] as String? ?? 'normal',
      isCompleted: row['is_completed'] as bool? ?? false,
    );
  }
}

/// Jeden cvik v detailu workoutu (nazev + serie).
class WorkoutDetailExercise {
  const WorkoutDetailExercise({
    required this.orderIndex,
    required this.name,
    required this.exerciseType,
    required this.gifUrl,
    required this.sets,
  });

  final int orderIndex;
  final String name;
  final String exerciseType;
  final String? gifUrl;
  final List<WorkoutSetDetail> sets;
}

/// Kompletni detail jednoho workoutu.
class WorkoutDetail {
  const WorkoutDetail({
    required this.workoutId,
    required this.title,
    required this.createdAt,
    required this.durationSeconds,
    required this.totalVolumeKg,
    required this.username,
    required this.profilePhotoUrl,
    required this.exercises,
  });

  final String workoutId;
  final String title;
  final DateTime createdAt;
  final int? durationSeconds;
  final double? totalVolumeKg;
  final String username;
  final String? profilePhotoUrl;
  final List<WorkoutDetailExercise> exercises;

  factory WorkoutDetail.fromRow(Map<String, dynamic> row) {
    final user = row['users'] as Map<String, dynamic>?;
    final exerciseRows =
        (row['workout_exercises'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    final exercises = [
      for (final ex in exerciseRows)
        if (ex['exercises'] != null)
          WorkoutDetailExercise(
            orderIndex: ex['order_index'] as int? ?? 0,
            name: ex['exercises']['exercise_name'] as String,
            exerciseType:
                ex['exercises']['exercise_type'] as String? ?? 'weight_reps',
            gifUrl: ex['exercises']['exercise_icon_url'] as String?,
            sets: [
              for (final set
                  in (ex['workout_sets'] as List<dynamic>? ?? [])
                      .cast<Map<String, dynamic>>())
                WorkoutSetDetail.fromRow(set),
            ]..sort((a, b) => a.setNumber.compareTo(b.setNumber)),
          ),
    ]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return WorkoutDetail(
      workoutId: row['workout_id'] as String,
      title: row['workout_title'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      durationSeconds: row['duration_seconds'] as int?,
      totalVolumeKg: (row['total_volume_kg'] as num?)?.toDouble(),
      username: user?['username'] as String? ?? 'Unknown',
      profilePhotoUrl: user?['profile_photo_url'] as String?,
      exercises: exercises,
    );
  }
}

/// Detail jednoho workoutu podle jeho id.
final workoutDetailProvider =
    FutureProvider.family<WorkoutDetail, String>((ref, workoutId) async {
  final row = await Supabase.instance.client
      .from('workouts')
      .select('''
        workout_id, workout_title, created_at, duration_seconds,
        total_volume_kg,
        users (username, profile_photo_url),
        workout_exercises (
          order_index,
          exercises (exercise_name, exercise_type, exercise_icon_url),
          workout_sets (
            set_number, weight_kg, reps_count, duration_seconds,
            distance_meters, set_type, is_completed
          )
        )
      ''')
      .eq('workout_id', workoutId)
      .single();
  return WorkoutDetail.fromRow(row);
});
