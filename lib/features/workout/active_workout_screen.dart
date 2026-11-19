import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../exercises/exercise_picker_screen.dart';
import '../exercises/exercise_repository.dart';
import '../home/feed_repository.dart';
import '../home/home_repository.dart';
import '../profile/profile_repository.dart';
import 'active_workout_provider.dart';
import 'exercise_card.dart';
import 'finish_workout_screen.dart';
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
    final volume = ref.read(activeWorkoutProvider).totalVolume;

    // Finish obrazovka je fullscreen nad shellem – uzivatel tu jeste muze
    // upravit nazev, dobu trvani a cas zacatku, nebo workout zahodit.
    final result = await Navigator.of(context, rootNavigator: true)
        .push<FinishWorkoutResult>(
          MaterialPageRoute(builder: (_) => const FinishWorkoutScreen()),
        );
    if (!context.mounted || result == null) return;

    if (result == FinishWorkoutResult.saved) {
      ref.invalidate(myWorkoutsProvider);
      ref.invalidate(feedProvider);
      ref.invalidate(previousWorkoutSetsProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(workoutHistoryProvider);
      _showSavedMessage(context, volume);
    }
    context.go('/workout');
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent.withValues(alpha: 0.10),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                size: 40,
                color: AppTheme.accentBright,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No exercises yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add your first exercise and start logging sets.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 210,
              child: FilledButton.icon(
                onPressed: onAddExercise,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add exercise'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seznam cviku + tlacitko "Discard workout" na konci.
class _ExerciseList extends StatelessWidget {
  const _ExerciseList({required this.exerciseCount, required this.onDiscard});

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
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppTheme.danger,
              backgroundColor: AppTheme.danger.withValues(alpha: 0.07),
              side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.35)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onDiscard,
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            label: const Text('Discard workout'),
          ),
        );
      },
    );
  }
}
