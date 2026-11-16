import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _ActionCard(
            icon: Icons.play_arrow_rounded,
            title: 'Start empty workout',
            subtitle: 'Build your session from scratch',
            highlight: true,
            onTap: () => _startEmptyWorkout(context, ref),
          ),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.playlist_add_rounded,
            title: 'Add routine',
            subtitle: 'Save a reusable template',
            onTap: () => _openRoutineBuilder(context, null),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'My routines',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (routinesAsync.value case final routines?
                  when routines.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${routines.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentBright,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          routinesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Text(
              'Error: $err',
              style: const TextStyle(color: AppTheme.textMuted),
            ),
            data: (routines) {
              if (routines.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 26,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.list_alt_rounded,
                        size: 28,
                        color: AppTheme.textMuted,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No routines yet.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Create one with "Add routine".',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
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
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: highlight ? AppTheme.heroGradient : null,
          color: highlight ? null : AppTheme.surface,
          borderRadius: radius,
          border: Border.all(
            color: highlight
                ? AppTheme.accent.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: highlight ? AppTheme.accentGradient : null,
                    color: highlight
                        ? null
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: highlight
                        ? [
                            BoxShadow(
                              color: AppTheme.accent.withValues(alpha: 0.4),
                              blurRadius: 18,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: highlight ? Colors.white : AppTheme.accentBright,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
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
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    size: 19,
                    color: AppTheme.accentBright,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    routine.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: AppTheme.textMuted,
                  ),
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
                        leading: Icon(
                          Icons.delete_outline_rounded,
                          color: AppTheme.danger,
                        ),
                        title: Text('Delete'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    routine.exerciseNames.isEmpty
                        ? 'No exercises yet'
                        : routine.exerciseNames.join(' • '),
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: AppTheme.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded, size: 19),
                    label: const Text('Start routine'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      backgroundColor:
                          AppTheme.accent.withValues(alpha: 0.14),
                      foregroundColor: AppTheme.accentBright,
                      textStyle: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
