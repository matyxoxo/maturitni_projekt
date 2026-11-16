import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/comment_sheet.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/exercise_thumbnail.dart';
import 'feed_repository.dart';
import 'home_repository.dart';

/// Sjednoceny feed workoutu – moje i od pratel, razeno podle data.
///
/// Karty umoznuji lajk (optimistic), komentare (bottom sheet),
/// odkaz na profil autora a u vlastnich workoutu Edit/Delete.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (workouts) {
          if (workouts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accent.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.people_outline_rounded,
                        size: 38,
                        color: AppTheme.accentBright,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Your feed is empty',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Follow athletes to see their workouts here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: 220,
                      child: FilledButton.tonalIcon(
                        onPressed: () => context.push('/find-friends'),
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Find friends'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppTheme.accent,
            backgroundColor: AppTheme.surfaceHigh,
            onRefresh: () async => ref.invalidate(feedProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              itemCount: workouts.length,
              itemBuilder: (context, index) => FeedWorkoutCard(
                key: ValueKey(workouts[index].workoutId),
                workout: workouts[index],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Karta jednoho workoutu v feedu (sdilena Home + profil).
class FeedWorkoutCard extends ConsumerWidget {
  const FeedWorkoutCard({super.key, required this.workout});

  final FeedWorkout workout;

  void _invalidateFeeds(WidgetRef ref) {
    ref.invalidate(feedProvider);
    ref.invalidate(userFeedProvider);
  }

  Future<void> _renameWorkout(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: workout.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename workout'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Workout title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(84, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.trim().isEmpty) return;
    try {
      await Supabase.instance.client
          .from('workouts')
          .update({'workout_title': newName.trim()})
          .eq('workout_id', workout.workoutId);
      _invalidateFeeds(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Rename failed: $e')));
      }
    }
  }

  Future<void> _deleteWorkout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete workout',
      message: 'Delete "${workout.title}"? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await Supabase.instance.client
          .from('workouts')
          .delete()
          .eq('workout_id', workout.workoutId);
      _invalidateFeeds(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _toggleLike(BuildContext context, WidgetRef ref) async {
    final overrides = ref.read(likeOverridesProvider.notifier);
    final previous = resolveLiked(
      ref.read(likeOverridesProvider),
      workout,
    );
    final next = !previous;
    // Optimistic – okamzita zmena, pri neuspechu vratime.
    overrides.set(workout.workoutId, next);

    final ok = await setWorkoutLike(workout.workoutId, liked: next);
    if (!ok) {
      overrides.rollback(workout.workoutId, previous);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update like.')),
        );
      }
    }
  }

  void _openComments(BuildContext context) {
    showCommentSheet(context, workoutId: workout.workoutId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isMine = workout.isMine(myId);
    final overrides = ref.watch(likeOverridesProvider);
    final liked = resolveLiked(overrides, workout);
    final likeCount = resolveLikeCount(overrides, workout);
    final previewExercises = workout.exercises.take(3).toList();
    final extraCount = workout.exercises.length - previewExercises.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/history/${workout.workoutId}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                userId: workout.userId,
                username: workout.username,
                photoUrl: workout.profilePhotoUrl,
                createdAt: workout.createdAt,
                onRename: isMine
                    ? () => _renameWorkout(context, ref)
                    : null,
                onDelete:
                    isMine ? () => _deleteWorkout(context, ref) : null,
              ),
              const SizedBox(height: 14),
              Text(
                workout.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              _CardStats(
                durationSeconds: workout.durationSeconds,
                totalVolumeKg: workout.totalVolumeKg,
              ),
              if (previewExercises.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final exercise in previewExercises)
                  _ExercisePreview(exercise: exercise),
              ],
              if (extraCount > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        context.push('/history/${workout.workoutId}'),
                    child: Text('See all ($extraCount)'),
                  ),
                ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 2),
              _CardActions(
                liked: liked,
                likeCount: likeCount,
                commentCount: workout.commentCount,
                onLike: () => _toggleLike(context, ref),
                onComments: () => _openComments(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hlavicka karty: avatar, uzivatel (klik na profil), cas, menu.
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.userId,
    required this.username,
    required this.photoUrl,
    required this.createdAt,
    required this.onRename,
    required this.onDelete,
  });

  final String userId;
  final String username;
  final String? photoUrl;
  final DateTime createdAt;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final canEdit = onRename != null && onDelete != null;

    return Row(
      children: [
        _Avatar(username: username, photoUrl: photoUrl, userId: userId),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.push('/u/$userId'),
                child: Text(
                  username,
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
                timeAgo(createdAt),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (canEdit)
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: AppTheme.textMuted,
            ),
            padding: EdgeInsets.zero,
            splashRadius: 20,
            onSelected: (value) {
              if (value == 'rename') onRename!();
              if (value == 'delete') onDelete!();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: AppTheme.danger),
                  title: Text('Delete'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Kruhovy avatar s inicialy nebo fotkou (klik -> profil).
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.username,
    required this.userId,
    this.photoUrl,
  });

  final String username;
  final String userId;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/u/$userId'),
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: _AvatarCircle(
          username: username,
          photoUrl: photoUrl,
          radius: 19,
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.username,
    required this.radius,
    this.photoUrl,
  });

  final String username;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(photoUrl!),
        radius: radius,
      );
    }
    return CircleAvatar(
      backgroundColor: AppTheme.avatarColor(username),
      radius: radius,
      child: Text(
        _initials(username),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.78,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .replaceAll(RegExp(r'[^A-Za-zÀ-ž ]'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();
    return parts.isEmpty ? '?' : parts;
  }
}

/// Radek statistik karty: cas + objem.
class _CardStats extends StatelessWidget {
  const _CardStats({
    required this.durationSeconds,
    required this.totalVolumeKg,
  });

  final int? durationSeconds;
  final double? totalVolumeKg;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(
          icon: Icons.timer_outlined,
          label: durationSeconds != null
              ? formatDuration(durationSeconds!)
              : '--:--',
        ),
        _StatChip(
          icon: Icons.fitness_center_rounded,
          label: formatVolume(totalVolumeKg),
        ),
      ],
    );
  }
}

/// Jedna polozka statistiky (ikona + text).
class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

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

/// Nahled jednoho cviku v karte (gif + nazev).
class _ExercisePreview extends StatelessWidget {
  const _ExercisePreview({required this.exercise});

  final WorkoutExerciseBrief exercise;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: ExerciseThumbnail(gifUrl: exercise.gifUrl, size: 30),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              exercise.name,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFFCBD5E6),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Radek akci karty: lajk + komentar.
class _CardActions extends StatelessWidget {
  const _CardActions({
    required this.liked,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.onComments,
  });

  final bool liked;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionButton(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: '$likeCount',
          active: liked,
          onTap: onLike,
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.mode_comment_outlined,
          label: '$commentCount',
          active: false,
          onTap: onComments,
        ),
        const Spacer(),
        const Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppTheme.textMuted,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
