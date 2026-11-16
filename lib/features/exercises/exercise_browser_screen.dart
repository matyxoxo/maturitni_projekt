import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'exercise_repository.dart';

/// Prohlizec vsech cviku (jen pro zobrazeni, ne vyber).
class ExerciseBrowserScreen extends ConsumerStatefulWidget {
  const ExerciseBrowserScreen({super.key});

  @override
  ConsumerState<ExerciseBrowserScreen> createState() =>
      _ExerciseBrowserScreenState();
}

class _ExerciseBrowserScreenState
    extends ConsumerState<ExerciseBrowserScreen> {
  String _query = '';
  String? _selectedGroup;

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: exercisesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (_) => _MuscleGroupChips(
                groups: ref.watch(muscleGroupsProvider),
                selected: _selectedGroup,
                onSelected: (group) =>
                    setState(() => _selectedGroup = group),
              ),
            ),
          ),
          Expanded(
            child: exercisesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (exercises) {
                final filtered = filterExercises(
                  exercises,
                  query: _query,
                  muscleGroup: _selectedGroup,
                );
                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 30,
                            color: AppTheme.textMuted,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No exercises found.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _ExerciseTile(exercise: filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleGroupChips extends StatelessWidget {
  const _MuscleGroupChips({
    required this.groups,
    required this.selected,
    required this.onSelected,
  });

  final List<String> groups;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
        ),
        for (final group in groups)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(group),
              selected: selected == group,
              onSelected: (_) => onSelected(group),
            ),
          ),
      ],
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final subtitle = [
      if (exercise.muscleGroup.isNotEmpty) exercise.muscleGroup,
      exercise.subMuscleGroup,
      if (exercise.equipment != null) exercise.equipment!,
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showDetail(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: _thumbnail(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbnail() {
    if (exercise.gifUrl == null) {
      return Container(
        color: AppTheme.surfaceHigh,
        child: const Icon(
          Icons.fitness_center_rounded,
          size: 22,
          color: AppTheme.textMuted,
        ),
      );
    }
    return Image.network(
      exercise.gifUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, _, _) => Container(
        color: AppTheme.surfaceHigh,
        child: const Icon(
          Icons.fitness_center_rounded,
          size: 22,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: exercise.gifUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        exercise.gifUrl!,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(height: 80),
                      ),
                    )
                  : const SizedBox(height: 80),
            ),
            const SizedBox(height: 18),
            Text(
              exercise.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 12),
            _DetailRow(label: 'Muscle group', value: exercise.muscleGroup),
            _DetailRow(label: 'Sub muscle', value: exercise.subMuscleGroup),
            if (exercise.equipment != null)
              _DetailRow(label: 'Equipment', value: exercise.equipment!),
            _DetailRow(label: 'Type', value: exercise.exerciseType),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
