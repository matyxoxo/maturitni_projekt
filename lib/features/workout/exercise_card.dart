import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exercise_types.dart';
import '../../core/theme.dart';
import '../../core/widgets/exercise_thumbnail.dart';
import '../exercises/exercise_repository.dart';
import 'active_workout_provider.dart';
import 'set_input_row.dart';
import 'set_table_header.dart';

/// Karta jednoho cviku v aktivnim workoutu.
///
/// Obsahuje nazev cviku, gif, tabulku serii a tlacitko "Add set".
class ExerciseCard extends ConsumerWidget {
  const ExerciseCard({super.key, required this.exerciseIndex});

  final int exerciseIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider);
    final entry = workout.exercises[exerciseIndex];
    final previous = ref.watch(previousWorkoutSetsProvider).value;
    final controller = ref.read(activeWorkoutProvider.notifier);

    return WorkoutExerciseCard(
      exercise: entry.exercise,
      sets: entry.sets,
      previousLabels: previous?[entry.exercise.id] ?? const {},
      onAddSet: () => controller.addSet(exerciseIndex),
      onRemoveExercise: () => controller.removeExercise(exerciseIndex),
      onSetChanged: (setIndex, set) => controller.updateSet(
        exerciseIndex,
        setIndex,
        weightKg: set.weightKg,
        reps: set.reps,
        durationSeconds: set.durationSeconds,
        distanceMeters: set.distanceMeters,
      ),
      onSetTypeChanged: (setIndex, setType) =>
          controller.setSetType(exerciseIndex, setIndex, setType),
      onRemoveSet: (setIndex) => controller.removeSet(exerciseIndex, setIndex),
      onToggleComplete: (setIndex) =>
          controller.toggleSetComplete(exerciseIndex, setIndex),
    );
  }
}

/// Karta cviku nezavisla na provideru – pouziva ji aktivni workout
/// i editace ulozeneho workoutu.
class WorkoutExerciseCard extends StatelessWidget {
  const WorkoutExerciseCard({
    super.key,
    required this.exercise,
    required this.sets,
    required this.onAddSet,
    required this.onRemoveExercise,
    required this.onSetChanged,
    required this.onSetTypeChanged,
    required this.onRemoveSet,
    required this.onToggleComplete,
    this.previousLabels = const {},
    this.showPrevious = true,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final Exercise exercise;
  final List<WorkoutSet> sets;
  final VoidCallback onAddSet;
  final VoidCallback onRemoveExercise;
  final void Function(int setIndex, WorkoutSet set) onSetChanged;
  final void Function(int setIndex, String setType) onSetTypeChanged;
  final void Function(int setIndex) onRemoveSet;
  final void Function(int setIndex) onToggleComplete;

  /// setNumber -> popisek minule hodnoty (napr. "20kg x 10").
  final Map<int, String> previousLabels;
  final bool showPrevious;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final config = configForExerciseType(exercise.exerciseType);

    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExerciseThumbnail(gifUrl: exercise.gifUrl, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        exercise.muscleGroup,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemoveExercise,
                ),
              ],
            ),
            const Divider(),
            SetTableHeader(config: config, showPrevious: showPrevious),
            for (var s = 0; s < sets.length; s++)
              SetInputRow(
                key: ObjectKey(sets[s]),
                set: sets[s],
                setNumber: s + 1,
                config: config,
                previousLabel: previousLabels[s + 1] ?? '',
                showPrevious: showPrevious,
                onChanged: () => onSetChanged(s, sets[s]),
                onSetTypeChanged: (setType) => onSetTypeChanged(s, setType),
                onRemoveSet: () => onRemoveSet(s),
                onToggleComplete: () => onToggleComplete(s),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onAddSet,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add set'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
