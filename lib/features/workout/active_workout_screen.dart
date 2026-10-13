import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/confirm_dialog.dart';
import '../exercises/exercise_picker_screen.dart';
import '../exercises/exercise_repository.dart';
import '../home/home_repository.dart';
import 'active_workout_provider.dart';
import 'exercise_card.dart';
import 'workout_stats_bar.dart';

/// Obrazovka probihajiciho workoutu.
///
/// Uzivatel pridava cviky, vyplnuje serie a na konci klikne Finish.
/// Minimizovanim (sipka dolu) se workout schova, ale bezi dal.
class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key});

  Future<void> _pickExercise(BuildContext context, WidgetRef ref) async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise != null) {
      ref.read(activeWorkoutProvider.notifier).addExercise(exercise);
    }
  }

  void _minimize(BuildContext context, WidgetRef ref) {
    if (!ref.read(activeWorkoutProvider).isEmpty) {
      ref.read(activeWorkoutProvider.notifier).minimize();
    }
    context.go('/workout');
  }

  Future<void> _discardWorkout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Discard workout',
      message: 'All exercises and sets from this workout will be lost.',
      confirmLabel: 'Discard',
    );
    if (!confirmed || !context.mounted) return;
    ref.read(activeWorkoutProvider.notifier).reset();
    context.go('/workout');
  }

  Future<void> _finishWorkout(BuildContext context, WidgetRef ref) async {
    final workout = ref.read(activeWorkoutProvider);
    final title = await _askForWorkoutTitle(context);
    if (title == null || !context.mounted) return;

    final error =
        await ref.read(activeWorkoutProvider.notifier).finish(title);
    if (!context.mounted) return;

    if (error == null) {
      ref.invalidate(myWorkoutsProvider);
      ref.invalidate(previousWorkoutSetsProvider);
      _showSavedMessage(context, workout.totalVolume);
      context.go('/workout');
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  /// Zobrazi dialog s nazvem workoutu. Vrati zvoleny nazev nebo null.
  Future<String?> _askForWorkoutTitle(BuildContext context) {
    final titleController = TextEditingController(
      text: 'Workout ${DateTime.now().day}.${DateTime.now().month}.',
    );
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finish workout'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Workout title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, titleController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSavedMessage(BuildContext context, double volumeKg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Workout saved • ${volumeKg.toStringAsFixed(0)} kg volume',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _minimize(context, ref);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            tooltip: 'Minimize',
            onPressed: () => _minimize(context, ref),
          ),
          title: const Text('Workout'),
          actions: [
            if (!workout.isEmpty)
              TextButton(
                onPressed: () => _finishWorkout(context, ref),
                child: const Text('Finish'),
              ),
          ],
        ),
        body: Column(
          children: [
            const WorkoutStatsBar(),
            Expanded(
              child: workout.isEmpty
                  ? _EmptyWorkoutMessage(
                      onAddExercise: () => _pickExercise(context, ref),
                    )
                  : _ExerciseList(
                      exerciseCount: workout.exercises.length,
                      onDiscard: () => _discardWorkout(context, ref),
                    ),
            ),
          ],
        ),
        floatingActionButton: workout.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _pickExercise(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add exercise'),
              ),
      ),
    );
  }
}

/// Zprava "No exercises yet" + tlacitko pro pridani prvniho cviku.
class _EmptyWorkoutMessage extends StatelessWidget {
  const _EmptyWorkoutMessage({required this.onAddExercise});

  final VoidCallback onAddExercise;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No exercises yet',
            style: TextStyle(color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAddExercise,
            icon: const Icon(Icons.add),
            label: const Text('Add exercise'),
          ),
        ],
      ),
    );
  }
}

/// Seznam cviku + tlacitko "Discard workout" na konci.
class _ExerciseList extends StatelessWidget {
  const _ExerciseList({
    required this.exerciseCount,
    required this.onDiscard,
  });

  final int exerciseCount;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: exerciseCount + 1,
      itemBuilder: (context, index) {
        if (index < exerciseCount) {
          return ExerciseCard(exerciseIndex: index);
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade400,
              side: BorderSide(color: Colors.red.shade400),
            ),
            onPressed: onDiscard,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Discard workout'),
          ),
        );
      },
    );
  }
}
