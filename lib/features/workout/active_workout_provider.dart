import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../exercises/exercise_repository.dart';
import '../routines/routines_repository.dart';

// ============================================================
//  Modely dat
// ============================================================

/// Jedna serie u cviku (vaha, opakovani, typ, atd.).
class WorkoutSet {
  WorkoutSet({
    this.weightKg,
    this.reps = 0,
    this.durationSeconds,
    this.distanceMeters,
    this.setType = 'normal',
    this.isCompleted = false,
  });

  double? weightKg;
  int reps;
  int? durationSeconds;
  double? distanceMeters;
  String setType;
  bool isCompleted;
}

/// Cvik v probihajicim workoutu + jeho serie.
class WorkoutExercise {
  WorkoutExercise(this.exercise);

  final Exercise exercise;
  final List<WorkoutSet> sets = [];
}

/// Celkovy stav probihajiciho workoutu.
class ActiveWorkout {
  ActiveWorkout({
    required this.startedAt,
    required this.exercises,
    this.isMinimized = false,
    this.bodyWeightKg,
  });

  final DateTime startedAt;
  final List<WorkoutExercise> exercises;
  final bool isMinimized;

  /// Vaha uzivatele z profilu (potreba pro vypocet objemu u cviku s vlastni vahou).
  final double? bodyWeightKg;

  bool get isEmpty => exercises.isEmpty;

  int get totalSets {
    var count = 0;
    for (final exercise in exercises) {
      count += exercise.sets.length;
    }
    return count;
  }

  /// Celkovy objem workoutu v kg.
  ///
  /// U kazde serie se pocita: efektivni vaha * pocet opakovani.
  double get totalVolume {
    var volume = 0.0;
    for (final exercise in exercises) {
      final type = exercise.exercise.exerciseType;
      for (final set in exercise.sets) {
        volume += _effectiveWeightKg(type, set) * set.reps;
      }
    }
    return volume;
  }

  /// Pocita skutecnou zatez podle typu cviku:
  /// - weight_reps: zadej vaha
  /// - bodyweight_reps: vaha tela
  /// - weighted_bodyweight: vaha tela + pridana vaha
  /// - assisted_bodyweight: vaha tela - asistence
  double _effectiveWeightKg(String type, WorkoutSet set) {
    final bodyWeight = bodyWeightKg ?? 0.0;
    final entered = set.weightKg ?? 0.0;
    switch (type) {
      case 'bodyweight_reps':
        return bodyWeight;
      case 'weighted_bodyweight':
        return bodyWeight + entered;
      case 'assisted_bodyweight':
        return (bodyWeight - entered).clamp(0, double.infinity);
      default:
        return entered;
    }
  }
}

// ============================================================
//  Provider aktivniho workoutu
// ============================================================

/// Stav probihajiciho workoutu. Jeden globalni instance – preziva celej session.
final activeWorkoutProvider =
    NotifierProvider<ActiveWorkoutController, ActiveWorkout>(
  ActiveWorkoutController.new,
);

/// Kazdou vterinu vydaji aktualni cas (pro odectenou dobu workoutu).
final workoutClockProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  controller.add(DateTime.now());
  final timer = Timer.periodic(const Duration(seconds: 1), (_) {
    controller.add(DateTime.now());
  });
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Ovladac stavu workoutu – pridava/maze cviky a serie, uklada do DB.
class ActiveWorkoutController extends Notifier<ActiveWorkout> {
  double? _bodyWeightKg;

  @override
  ActiveWorkout build() {
    _loadBodyWeight();
    return ActiveWorkout(startedAt: DateTime.now(), exercises: []);
  }

  /// Nahraje vahu uzivatele z DB (pro vypocet objemu).
  Future<void> _loadBodyWeight() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final row = await Supabase.instance.client
        .from('users')
        .select('body_weight_kg')
        .eq('id', userId)
        .maybeSingle();
    final weight = (row?['body_weight_kg'] as num?)?.toDouble();
    if (weight != null) {
      _bodyWeightKg = weight;
      state = ActiveWorkout(
        startedAt: state.startedAt,
        exercises: state.exercises,
        isMinimized: state.isMinimized,
        bodyWeightKg: weight,
      );
    }
  }

  // ---------- Cviky ----------

  void addExercise(Exercise exercise) {
    final entry = WorkoutExercise(exercise)
      ..sets.add(WorkoutSet(weightKg: 0, reps: 0));
    _updateState((exercises) => exercises.add(entry));
  }

  void removeExercise(int exerciseIndex) {
    _updateState((exercises) => exercises.removeAt(exerciseIndex));
  }

  // ---------- Serie ----------

  void addSet(int exerciseIndex) {
    _updateState((exercises) {
      final sets = exercises[exerciseIndex].sets;
      final last = sets.isNotEmpty ? sets.last : null;
      sets.add(
        WorkoutSet(weightKg: last?.weightKg ?? 0, reps: last?.reps ?? 0),
      );
    });
  }

  void updateSet(
    int exerciseIndex,
    int setIndex, {
    required double? weightKg,
    required int? reps,
    int? durationSeconds,
    double? distanceMeters,
  }) {
    _updateState((exercises) {
      final set = exercises[exerciseIndex].sets[setIndex];
      set.weightKg = weightKg;
      set.reps = reps ?? 0;
      set.durationSeconds = durationSeconds;
      set.distanceMeters = distanceMeters;
    });
  }

  void setSetType(int exerciseIndex, int setIndex, String setType) {
    _updateState((exercises) =>
        exercises[exerciseIndex].sets[setIndex].setType = setType);
  }

  void toggleSetComplete(int exerciseIndex, int setIndex) {
    _updateState((exercises) {
      final set = exercises[exerciseIndex].sets[setIndex];
      set.isCompleted = !set.isCompleted;
    });
  }

  void removeSet(int exerciseIndex, int setIndex) {
    _updateState(
        (exercises) => exercises[exerciseIndex].sets.removeAt(setIndex));
  }

  // ---------- Minimizace ----------

  /// Schova workout do pasky dole (uzivatel presel na jinou zalozku).
  void minimize() {
    state = ActiveWorkout(
      startedAt: state.startedAt,
      exercises: state.exercises,
      isMinimized: true,
      bodyWeightKg: state.bodyWeightKg,
    );
  }

  /// Obnovi workout z pasky dole zpet na celou obrazovku.
  void restore() {
    state = ActiveWorkout(
      startedAt: state.startedAt,
      exercises: state.exercises,
      isMinimized: false,
      bodyWeightKg: state.bodyWeightKg,
    );
  }

  // ---------- Zakladni operace ----------

  /// Prepne na prazdny workout (nova session).
  void reset() {
    state = ActiveWorkout(
      startedAt: DateTime.now(),
      exercises: [],
      bodyWeightKg: _bodyWeightKg,
    );
  }

  /// Predvyplni workout z rutiny – cilove serie se prenesou jako startovni hodnoty.
  void loadFromRoutine(List<RoutineExerciseDraft> drafts) {
    final exercises = <WorkoutExercise>[];
    for (final draft in drafts) {
      final entry = WorkoutExercise(draft.exercise);
      if (draft.targets.isEmpty) {
        entry.sets.add(WorkoutSet());
      } else {
        for (final target in draft.targets) {
          entry.sets.add(
            WorkoutSet(
              weightKg: target.weightKg,
              reps: target.reps,
              durationSeconds: target.durationSeconds,
              distanceMeters: target.distanceMeters,
              setType: target.setType,
            ),
          );
        }
      }
      exercises.add(entry);
    }
    state = ActiveWorkout(
      startedAt: DateTime.now(),
      exercises: exercises,
      bodyWeightKg: _bodyWeightKg,
    );
  }

  /// Ulozi workout do DB a vrati null pri uspechu, jinak chybovou hlasku.
  Future<String?> finish(String title) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return 'Not signed in.';
    if (state.isEmpty) return 'Add at least one exercise.';

    try {
      final duration =
          DateTime.now().difference(state.startedAt).inSeconds;
      final workoutId = await _saveWorkoutRow(
        client,
        userId,
        title,
        duration,
        state.totalVolume,
      );

      for (var i = 0; i < state.exercises.length; i++) {
        await _saveExerciseWithSets(client, workoutId, i);
      }

      reset();
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save workout. Please try again.';
    }
  }

  // ---------- Ukladani do DB ----------

  Future<String> _saveWorkoutRow(
    SupabaseClient client,
    String userId,
    String title,
    int durationSeconds,
    double totalVolume,
  ) async {
    final row = await client
        .from('workouts')
        .insert({
          'user_id': userId,
          'workout_title': title,
          'duration_seconds': durationSeconds,
          'total_volume_kg': totalVolume,
        })
        .select('workout_id')
        .single();
    return row['workout_id'] as String;
  }

  Future<void> _saveExerciseWithSets(
    SupabaseClient client,
    String workoutId,
    int exerciseIndex,
  ) async {
    final entry = state.exercises[exerciseIndex];
    final exerciseRow = await client
        .from('workout_exercises')
        .insert({
          'workout_id': workoutId,
          'exercise_id': entry.exercise.id,
          'order_index': exerciseIndex,
        })
        .select('workout_exercise_id')
        .single();

    for (var s = 0; s < entry.sets.length; s++) {
      await _saveSetRow(
        client,
        exerciseRow['workout_exercise_id'] as String,
        s + 1,
        entry.sets[s],
      );
    }
  }

  Future<void> _saveSetRow(
    SupabaseClient client,
    String workoutExerciseId,
    int setNumber,
    WorkoutSet set,
  ) async {
    await client.from('workout_sets').insert({
      'workout_exercise_id': workoutExerciseId,
      'set_number': setNumber,
      'weight_kg': set.weightKg,
      'reps_count': set.reps > 0 ? set.reps : null,
      'duration_seconds': set.durationSeconds,
      'distance_meters': set.distanceMeters,
      'set_type': set.setType,
      'is_completed': set.isCompleted,
    });
  }

  /// Bezpecne prepne stav – zavola [mutate] a vytvori kopii listu pro rebuild.
  void _updateState(void Function(List<WorkoutExercise>) mutate) {
    mutate(state.exercises);
    state = ActiveWorkout(
      startedAt: state.startedAt,
      exercises: List.of(state.exercises),
      isMinimized: state.isMinimized,
      bodyWeightKg: state.bodyWeightKg,
    );
  }
}

// ============================================================
//  Predchozi workout (napoveda "minule jsi dal...")
// ============================================================

/// exerciseId -> (setNumber -> "20kg x 10") z posledniho ulozeneho workoutu.
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
    final label = _formatPreviousSetLabel(
      row['weight_kg'] as num?,
      row['reps_count'] as int?,
    );
    if (label.isEmpty) continue;
    result.putIfAbsent(exerciseId, () => {})[setNumber] = label;
  }
  return result;
});

/// Vytvori popisek "20kg x 10" pro zobrazeni minule hodnoty.
String _formatPreviousSetLabel(num? weightKg, int? reps) {
  final parts = <String>[];
  if (weightKg != null) {
    final w = weightKg.toDouble();
    parts.add('${w == w.truncateToDouble() ? w.toInt() : w}kg');
  }
  if (reps != null) parts.add('x$reps');
  return parts.join(' ');
}
