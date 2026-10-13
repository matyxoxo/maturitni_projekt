import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exercise_types.dart';
import '../../core/widgets/exercise_thumbnail.dart';
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
    final config = configForExerciseType(entry.exercise.exerciseType);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ExerciseHeader(
              exerciseIndex: exerciseIndex,
              name: entry.exercise.name,
              muscleGroup: entry.exercise.muscleGroup,
              gifUrl: entry.exercise.gifUrl,
            ),
            const Divider(),
            SetTableHeader(config: config, showPrevious: true),
            for (var s = 0; s < entry.sets.length; s++)
              SetInputRow(
                key: ObjectKey(entry.sets[s]),
                exerciseIndex: exerciseIndex,
                setIndex: s,
                config: config,
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => ref
                    .read(activeWorkoutProvider.notifier)
                    .addSet(exerciseIndex),
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

/// Hlavicka karty: gif, nazev, svalova skupina, tlacitko smazat.
class _ExerciseHeader extends ConsumerWidget {
  const _ExerciseHeader({
    required this.exerciseIndex,
    required this.name,
    required this.muscleGroup,
    required this.gifUrl,
  });

  final int exerciseIndex;
  final String name;
  final String muscleGroup;
  final String? gifUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        ExerciseThumbnail(gifUrl: gifUrl, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                muscleGroup,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => ref
              .read(activeWorkoutProvider.notifier)
              .removeExercise(exerciseIndex),
        ),
      ],
    );
  }
}
