import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import 'active_workout_provider.dart';

/// Horni lista se zivymi statistikami probihajiciho workoutu:
/// uplynuly cas, celkovy objem a pocet serii.
class WorkoutStatsBar extends ConsumerWidget {
  const WorkoutStatsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider);
    final now = ref.watch(workoutClockProvider).value ?? DateTime.now();
    final elapsedSeconds = now.difference(workout.startedAt).inSeconds;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.timer_outlined,
            label: formatDuration(elapsedSeconds),
          ),
          const SizedBox(width: 24),
          _StatItem(
            icon: Icons.fitness_center,
            label: formatVolume(workout.totalVolume),
          ),
          const SizedBox(width: 24),
          _StatItem(
            icon: Icons.playlist_add_check_outlined,
            label: '${workout.totalSets} sets',
          ),
        ],
      ),
    );
  }
}

/// Jedna polozka statistiky (ikona + popisek).
class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
        ),
      ],
    );
  }
}
