import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
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
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => _selectBranch(ref, index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fitness_center_outlined),
                  selectedIcon: Icon(Icons.fitness_center_rounded),
                  label: 'Workout',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
                NavigationDestination(
                  icon: Icon(Icons.leaderboard_outlined),
                  selectedIcon: Icon(Icons.leaderboard_rounded),
                  label: 'Rank',
                ),
              ],
            ),
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
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF16233A), Color(0xFF101826)],
          ),
          border: Border(
            top: BorderSide(color: AppTheme.accent.withValues(alpha: 0.35)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 50,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  tooltip: 'Expand workout',
                  onPressed: () => _restoreWorkout(context, ref),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    size: 16,
                    color: AppTheme.accentBright,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Workout running • ${formatDuration(elapsedSeconds)}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.danger,
                  ),
                  tooltip: 'Discard workout',
                  onPressed: () => _discardWorkout(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
