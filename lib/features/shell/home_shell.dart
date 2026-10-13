import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../workout/active_workout_provider.dart';

/// Hlavni shell aplikace – doli navigace + paska minimalizovaneho workoutu.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Prepne zalozku. Pokud bezi workout, automaticky se minimalizuje.
  void _selectBranch(WidgetRef ref, int index) {
    final workout = ref.read(activeWorkoutProvider);
    if (!workout.isEmpty && !workout.isMinimized) {
      ref.read(activeWorkoutProvider.notifier).minimize();
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider);
    final showMinimizedBar = !workout.isEmpty && workout.isMinimized;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMinimizedBar) const _MinimizedWorkoutBar(),
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => _selectBranch(ref, index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: 'Workout',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
              NavigationDestination(
                icon: Icon(Icons.leaderboard_outlined),
                selectedIcon: Icon(Icons.leaderboard),
                label: 'Rank',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Paska dole se zkracenym workoutem – cas + sipka nahoru + mazani.
class _MinimizedWorkoutBar extends ConsumerWidget {
  const _MinimizedWorkoutBar();

  Future<void> _discardWorkout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Discard workout',
      message: 'All exercises and sets from this workout will be lost.',
      confirmLabel: 'Discard',
    );
    if (!confirmed) return;
    ref.read(activeWorkoutProvider.notifier).reset();
  }

  void _restoreWorkout(BuildContext context, WidgetRef ref) {
    ref.read(activeWorkoutProvider.notifier).restore();
    context.go('/workout/active');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider);
    final now = ref.watch(workoutClockProvider).value ?? DateTime.now();
    final elapsedSeconds = now.difference(workout.startedAt).inSeconds;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up),
                tooltip: 'Expand workout',
                onPressed: () => _restoreWorkout(context, ref),
              ),
              Icon(
                Icons.fitness_center,
                size: 18,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Workout running • ${formatDuration(elapsedSeconds)}',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                tooltip: 'Discard workout',
                onPressed: () => _discardWorkout(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
