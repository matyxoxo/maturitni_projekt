import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'exercise_repository.dart';

class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  ConsumerState<ExercisePickerScreen> createState() =>
      _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends ConsumerState<ExercisePickerScreen> {
  String _query = '';
  String? _selectedGroup;

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add exercise')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: Icon(Icons.search),
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
                  return const Center(child: Text('No exercises found.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
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
    return ListTile(
      leading: SizedBox(
        width: 56,
        height: 56,
        child: exercise.gifUrl != null
            ? Image.network(
                exercise.gifUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, _, _) => const Icon(Icons.fitness_center),
              )
            : const Icon(Icons.fitness_center),
      ),
      title: Text(exercise.name),
      subtitle: Text(
        [
          exercise.subMuscleGroup,
          if (exercise.equipment != null) exercise.equipment!,
        ].join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.add_circle_outline),
      onTap: () => Navigator.of(context).pop(exercise),
    );
  }
}
