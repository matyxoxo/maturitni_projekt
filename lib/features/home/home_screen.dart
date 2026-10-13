import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/format.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/exercise_thumbnail.dart';
import 'home_repository.dart';

/// Prehled poslednich workoutu – karty s informacemi a moznosti Detail/Delete.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(myWorkoutsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: workoutsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (workouts) {
          if (workouts.isEmpty) {
            return Center(
              child: Text(
                'No workouts yet. Start your first one!',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myWorkoutsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: workouts.length,
              itemBuilder: (context, index) => _WorkoutCard(
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

/// Karta jednoho workoutu v prehledu.
///
/// Obsahuje: uzivatele, nazev, statistiky, nahled 3 cviku,
/// "See more" a menu Edit/Delete.
class _WorkoutCard extends ConsumerWidget {
  const _WorkoutCard({super.key, required this.workout});

  final WorkoutSummary workout;

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
      ref.invalidate(myWorkoutsProvider);
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
      ref.invalidate(myWorkoutsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewExercises = workout.exercises.take(3).toList();
    final extraCount = workout.exercises.length - previewExercises.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/history/${workout.workoutId}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                username: workout.username,
                photoUrl: workout.profilePhotoUrl,
                createdAt: workout.createdAt,
                onRename: () => _renameWorkout(context, ref),
                onDelete: () => _deleteWorkout(context, ref),
              ),
              const SizedBox(height: 12),
              Text(
                workout.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              _CardStats(
                durationSeconds: workout.durationSeconds,
                totalVolumeKg: workout.totalVolumeKg,
              ),
              const SizedBox(height: 12),
              for (final exercise in previewExercises)
                _ExercisePreview(exercise: exercise),
              if (extraCount > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        context.push('/history/${workout.workoutId}'),
                    child: Text('See more ($extraCount)'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hlavicka karty: avatar, uzivatel, cas, menu Edit/Delete.
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.username,
    required this.photoUrl,
    required this.createdAt,
    required this.onRename,
    required this.onDelete,
  });

  final String username;
  final String? photoUrl;
  final DateTime createdAt;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Avatar(username: username, photoUrl: photoUrl),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                timeAgo(createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'rename') onRename();
            if (value == 'delete') onDelete();
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
                leading: Icon(Icons.delete_outline, color: Colors.red),
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

/// Kruhovy avatar s inicialy nebo fotkou.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.username, this.photoUrl});

  final String username;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(photoUrl!),
        radius: 20,
      );
    }
    return CircleAvatar(
      backgroundColor: _avatarColor(username),
      radius: 20,
      child: Text(
        _initials(username),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Vytvori barvu avataru z hash uzivatelskeho jmena.
  static Color _avatarColor(String name) {
    const colors = <Color>[
      Colors.teal,
      Colors.indigo,
      Colors.deepOrange,
      Colors.pink,
      Colors.blueGrey,
      Colors.green,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  /// Vytvori inicialy z jmena (max 2 pismena).
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
    return Row(
      children: [
        _StatChip(
          icon: Icons.timer_outlined,
          label: durationSeconds != null
              ? formatDuration(durationSeconds!)
              : '--:--',
        ),
        const SizedBox(width: 12),
        _StatChip(
          icon: Icons.fitness_center,
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

/// Nahled jednoho cviku v karte (gif + nazev).
class _ExercisePreview extends StatelessWidget {
  const _ExercisePreview({required this.exercise});

  final WorkoutExerciseBrief exercise;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          ExerciseThumbnail(gifUrl: exercise.gifUrl, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              exercise.name,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade300,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
