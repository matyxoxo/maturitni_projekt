import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/confirm_dialog.dart';
import '../routines/routines_repository.dart';
import 'active_workout_provider.dart';

/// Uvodni obrazovka workoutu – spusteni prazdneho workoutu
/// nebo spusteni/UPRAVA/MAZANI ulozene rutiny.
class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  void _startEmptyWorkout(BuildContext context, WidgetRef ref) {
    ref.read(activeWorkoutProvider.notifier).reset();
    context.push('/workout/active');
  }

  Future<void> _startRoutine(
    BuildContext context,
    WidgetRef ref,
    Routine routine,
  ) async {
    final drafts =
        await ref.read(routineDetailProvider(routine.routineId).future);
    if (!context.mounted) return;
    ref.read(activeWorkoutProvider.notifier).loadFromRoutine(drafts);
    context.push('/workout/active');
  }

  void _openRoutineBuilder(BuildContext context, Routine? routine) {
    if (routine == null) {
      context.push('/routine-builder');
    } else {
      context.push(
        '/routine-builder?id=${routine.routineId}'
        '&name=${Uri.encodeComponent(routine.name)}',
      );
    }
  }

  Future<void> _deleteRoutine(
    BuildContext context,
    WidgetRef ref,
    Routine routine,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete routine',
      message: 'Delete "${routine.name}"?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await deleteRoutine(routine.routineId);
      ref.invalidate(routinesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(routinesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ActionCard(
            icon: Icons.play_arrow,
            title: 'Start empty workout',
            subtitle: 'Build your session from scratch',
            onTap: () => _startEmptyWorkout(context, ref),
          ),
          _ActionCard(
            icon: Icons.playlist_add,
            title: 'Add routine',
            subtitle: 'Save a reusable template',
            onTap: () => _openRoutineBuilder(context, null),
          ),
          const SizedBox(height: 24),
          const Text(
            'My routines',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          routinesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error: $err'),
            data: (routines) {
              if (routines.isEmpty) {
                return Text(
                  'No routines yet. Create one with "Add routine".',
                  style: TextStyle(color: Colors.grey.shade400),
                );
              }
              return Column(
                children: [
                  for (final routine in routines)
                    _RoutineCard(
                      key: ValueKey(routine.routineId),
                      routine: routine,
                      onStart: () => _startRoutine(context, ref, routine),
                      onEdit: () => _openRoutineBuilder(context, routine),
                      onDelete: () => _deleteRoutine(context, ref, routine),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Velka karta s akci (Start empty workout / Add routine).
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Karta ulozene rutiny – nazev, seznam cviku, Start/Edit/Delete.
class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    super.key,
    required this.routine,
    required this.onStart,
    required this.onEdit,
    required this.onDelete,
  });

  final Routine routine;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    routine.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
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
            ),
            const SizedBox(height: 4),
            Text(
              routine.exerciseNames.join(' • '),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Start routine'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
