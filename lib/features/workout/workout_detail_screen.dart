import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/exercise_types.dart';
import '../../core/format.dart';
import '../../core/set_type.dart';
import '../../core/theme.dart';
import '../../core/widgets/comment_sheet.dart';
import '../home/feed_repository.dart';
import '../home/home_repository.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final String workoutId;

  Future<void> _toggleLike(BuildContext context, WidgetRef ref) async {
    final engagement =
        ref.read(workoutEngagementProvider(workoutId)).value;
    if (engagement == null) return;

    final overrides = ref.read(likeOverridesProvider.notifier);
    final previous = resolveEngagementLiked(
      ref.read(likeOverridesProvider),
      workoutId,
      engagement,
    );
    final next = !previous;
    overrides.set(workoutId, next);

    final ok = await setWorkoutLike(workoutId, liked: next);
    if (!ok) {
      overrides.rollback(workoutId, previous);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update like.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(workoutDetailProvider(workoutId));
    final engagementAsync = ref.watch(workoutEngagementProvider(workoutId));
    final overrides = ref.watch(likeOverridesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (detail) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: detail.userId != null
                      ? () => context.push('/u/${detail.userId}')
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          AppTheme.avatarColor(detail.username),
                      child: Text(
                        detail.username.isEmpty
                            ? '?'
                            : detail.username[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: detail.userId != null
                            ? () => context.push('/u/${detail.userId}')
                            : null,
                        child: Text(
                          detail.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeAgo(detail.createdAt),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              detail.title,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatPill(
                  icon: Icons.timer_outlined,
                  label: detail.durationSeconds != null
                      ? formatDuration(detail.durationSeconds!)
                      : '--:--',
                ),
                _StatPill(
                  icon: Icons.fitness_center_rounded,
                  label: formatVolume(detail.totalVolumeKg),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _EngagementRow(
              workoutId: workoutId,
              engagementAsync: engagementAsync,
              overrides: overrides,
              onLike: () => _toggleLike(context, ref),
              onComments: () => showCommentSheet(
                context,
                workoutId: workoutId,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 12),
            for (final exercise in detail.exercises) ...[
              _ExerciseDetailSection(exercise: exercise),
            ],
          ],
        ),
      ),
    );
  }
}

/// Maly ramecek se statistikou (cas / objem).
class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.accentBright),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFFDDE6F5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Radek lajku a komentaru pod statistikami detailu.
class _EngagementRow extends StatelessWidget {
  const _EngagementRow({
    required this.workoutId,
    required this.engagementAsync,
    required this.overrides,
    required this.onLike,
    required this.onComments,
  });

  final String workoutId;
  final AsyncValue<WorkoutEngagement> engagementAsync;
  final Map<String, bool> overrides;
  final VoidCallback onLike;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final engagement = engagementAsync.value;
    if (engagement == null) {
      return const SizedBox(height: 36);
    }

    final liked = overrides[workoutId] ?? engagement.likedByMe;
    final likeCount = engagement.likeCount -
        (engagement.likedByMe ? 1 : 0) +
        (liked ? 1 : 0);

    return Row(
      children: [
        _EngagementPill(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: '$likeCount',
          active: liked,
          onTap: onLike,
        ),
        const SizedBox(width: 8),
        _EngagementPill(
          icon: Icons.mode_comment_outlined,
          label: '${engagement.commentCount}',
          active: false,
          onTap: onComments,
        ),
      ],
    );
  }
}

class _EngagementPill extends StatelessWidget {
  const _EngagementPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.accentBright : AppTheme.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.accent.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? AppTheme.accent.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseDetailSection extends StatelessWidget {
  const _ExerciseDetailSection({required this.exercise});

  final WorkoutDetailExercise exercise;

  @override
  Widget build(BuildContext context) {
    final config = configForExerciseType(exercise.exerciseType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _GifBox(gifUrl: exercise.gifUrl, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                exercise.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SetTableHeader(config: config),
        for (final set in exercise.sets)
          _SetDetailRow(set: set, config: config),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SetTableHeader extends StatelessWidget {
  const _SetTableHeader({required this.config});

  final ExerciseInputConfig config;

  @override
  Widget build(BuildContext context) {
    final style = const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppTheme.textMuted,
      letterSpacing: 0.5,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Center(child: Text('SET', style: style)),
          ),
          const SizedBox(width: 8),
          if (config.showWeight)
            SizedBox(
              width: 74,
              child: Center(child: Text(config.weightLabel, style: style)),
            ),
          if (config.showReps)
            SizedBox(
              width: 64,
              child: Center(child: Text('REPS', style: style)),
            ),
          if (config.showDuration)
            SizedBox(
              width: 64,
              child: Center(child: Text('TIME', style: style)),
            ),
          if (config.showDistance)
            SizedBox(
              width: 64,
              child: Center(child: Text('KM', style: style)),
            ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _SetDetailRow extends StatelessWidget {
  const _SetDetailRow({required this.set, required this.config});

  final WorkoutSetDetail set;
  final ExerciseInputConfig config;

  @override
  Widget build(BuildContext context) {
    final isSpecial = set.setType != SetType.normal;
    final indicatorColor = _indicatorColor(set.setType, context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Center(
              child: Tooltip(
                message: SetType.labels[set.setType] ?? 'Set',
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSpecial
                        ? indicatorColor.withValues(alpha: 0.14)
                        : null,
                    border: Border.all(
                      color: isSpecial
                          ? indicatorColor.withValues(alpha: 0.55)
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Text(
                    SetType.indicator(set.setType, set.setNumber),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSpecial ? indicatorColor : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (config.showWeight)
            SizedBox(
              width: 74,
              child: Center(
                child: Text(
                  set.weightKg != null ? '${set.weightKg}' : '–',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (config.showReps)
            SizedBox(
              width: 64,
              child: Center(
                child: Text(
                  set.repsCount != null ? '${set.repsCount}' : '–',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (config.showDuration)
            SizedBox(
              width: 64,
              child: Center(
                child: Text(
                  set.durationSeconds != null
                      ? '${set.durationSeconds}s'
                      : '–',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (config.showDistance)
            SizedBox(
              width: 64,
              child: Center(
                child: Text(
                  set.distanceMeters != null
                      ? '${set.distanceMeters}m'
                      : '–',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          const Spacer(),
          SizedBox(
            width: 40,
            child: Icon(
              set.isCompleted
                  ? Icons.check_circle
                  : Icons.check_circle_outline,
              size: 22,
              color: set.isCompleted
                  ? Theme.of(context).colorScheme.primary
                  : AppTheme.surfaceHighest,
            ),
          ),
        ],
      ),
    );
  }

  /// Barva krouzku podle typu serie (normalni serie pouziva vychozi barvu).
  static Color _indicatorColor(String setType, BuildContext context) {
    switch (setType) {
      case SetType.warmup:
        return AppTheme.cyan;
      case SetType.failure:
        return AppTheme.danger;
      case SetType.dropSet:
        return AppTheme.accentBright;
      default:
        return Theme.of(context).colorScheme.onSurface;
    }
  }
}

class _GifBox extends StatelessWidget {
  const _GifBox({required this.gifUrl, this.size = 48});

  final String? gifUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (gifUrl == null) {
      return Icon(
        Icons.fitness_center_rounded,
        size: size * 0.7,
        color: AppTheme.textMuted,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        gifUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.fitness_center_rounded,
          size: size * 0.7,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }
}
