import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF16233A), Color(0xFF101826)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _StatItem(
                icon: Icons.timer_outlined,
                label: formatDuration(elapsedSeconds),
              ),
            ),
            const _StatDivider(),
            Expanded(
              child: _StatItem(
                icon: Icons.fitness_center_rounded,
                label: formatVolume(workout.totalVolume),
              ),
            ),
            const _StatDivider(),
            Expanded(
              child: _StatItem(
                icon: Icons.playlist_add_check_rounded,
                label: '${workout.totalSets}',
                caption: 'sets',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Jedna polozka statistiky (ikona + popisek).
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.accentBright),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 1),
          Text(
            caption!,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: Colors.white.withValues(alpha: 0.07),
    );
  }
}
