import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../exercises/exercise_picker_screen.dart';
import '../exercises/exercise_repository.dart';
import 'active_workout_provider.dart';
import 'workout_screen.dart';

class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key});

  Future<void> _pickExercise(BuildContext context, WidgetRef ref) async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise != null) {
      ref.read(activeWorkoutProvider.notifier).addExercise(exercise);
    }
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final workout = ref.read(activeWorkoutProvider);
    final titleController = TextEditingController(
      text: 'Workout ${DateTime.now().day}.${DateTime.now().month}.',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finish workout'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Workout title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final error =
        await ref.read(activeWorkoutProvider.notifier).finish(titleController.text);
    if (!context.mounted) return;
    if (error == null) {
      ref.invalidate(recentWorkoutsProvider);
      ref.invalidate(previousWorkoutSetsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Workout saved • ${workout.totalVolume.toStringAsFixed(0)} kg volume',
          ),
        ),
      );
      context.go('/workout');
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout in progress'),
        actions: [
          if (!workout.isEmpty)
            TextButton(
              onPressed: () => _finish(context, ref),
              child: const Text('Finish'),
            ),
        ],
      ),
      body: workout.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No exercises yet',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _pickExercise(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add exercise'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: workout.exercises.length,
              itemBuilder: (context, index) =>
                  _ExerciseCard(exerciseIndex: index),
            ),
      floatingActionButton: workout.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _pickExercise(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
            ),
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({required this.exerciseIndex});

  final int exerciseIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider);
    final entry = workout.exercises[exerciseIndex];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (entry.exercise.gifUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      entry.exercise.gifUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.fitness_center),
                    ),
                  )
                else
                  const Icon(Icons.fitness_center),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.exercise.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        entry.exercise.muscleGroup,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref
                      .read(activeWorkoutProvider.notifier)
                      .removeExercise(exerciseIndex),
                ),
              ],
            ),
            const Divider(),
            const _SetHeaderRow(),
            for (var s = 0; s < entry.sets.length; s++)
              _SetRow(
                key: ObjectKey(entry.sets[s]),
                exerciseIndex: exerciseIndex,
                setIndex: s,
                setNumber: s + 1,
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => ref
                    .read(activeWorkoutProvider.notifier)
                    .addSet(exerciseIndex),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add set'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetHeaderRow extends StatelessWidget {
  const _SetHeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade500,
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
          Expanded(child: Center(child: Text('PREVIOUS', style: style))),
          SizedBox(
            width: 74,
            child: Center(child: Text('KG', style: style)),
          ),
          SizedBox(
            width: 64,
            child: Center(child: Text('REPS', style: style)),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

const _typeLabels = {
  'normal': 'Normal set',
  'warmup': 'Warmup (W)',
  'failure': 'Failure (F)',
  'drop_set': 'Drop set (D)',
};

class _SetRow extends ConsumerStatefulWidget {
  const _SetRow({
    super.key,
    required this.exerciseIndex,
    required this.setIndex,
    required this.setNumber,
  });

  final int exerciseIndex;
  final int setIndex;
  final int setNumber;

  @override
  ConsumerState<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<_SetRow> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    final set = ref
        .read(activeWorkoutProvider)
        .exercises[widget.exerciseIndex]
        .sets[widget.setIndex];
    _weightController = TextEditingController(
      text: set.weightKg == null || set.weightKg == 0
          ? ''
          : '${set.weightKg}',
    );
    _repsController = TextEditingController(
      text: set.reps > 0 ? '${set.reps}' : '',
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _save() {
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));
    final reps = int.tryParse(_repsController.text);
    ref.read(activeWorkoutProvider.notifier).updateSet(
          widget.exerciseIndex,
          widget.setIndex,
          weightKg: weight,
          reps: reps,
        );
  }

  String get _typeIndicator {
    final set = ref
        .read(activeWorkoutProvider)
        .exercises[widget.exerciseIndex]
        .sets[widget.setIndex];
    switch (set.setType) {
      case 'warmup':
        return 'W';
      case 'failure':
        return 'F';
      case 'drop_set':
        return 'D';
      default:
        return '${widget.setNumber}';
    }
  }

  void _showTypeMenu() {
    final controller = ref.read(activeWorkoutProvider.notifier);
    final currentType = ref
        .read(activeWorkoutProvider)
        .exercises[widget.exerciseIndex]
        .sets[widget.setIndex]
        .setType;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in _typeLabels.entries)
              ListTile(
                leading: entry.key == currentType
                    ? const Icon(Icons.check)
                    : const SizedBox(width: 24),
                title: Text(entry.value),
                onTap: () {
                  controller.setSetType(
                    widget.exerciseIndex,
                    widget.setIndex,
                    entry.key,
                  );
                  Navigator.pop(sheetContext);
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
              title: Text(
                'Remove set',
                style: TextStyle(color: Colors.red.shade400),
              ),
              onTap: () {
                controller.removeSet(widget.exerciseIndex, widget.setIndex);
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workout = ref.watch(activeWorkoutProvider);
    final entry = workout.exercises[widget.exerciseIndex];
    final set = entry.sets[widget.setIndex];
    final previous = ref.watch(previousWorkoutSetsProvider).value;
    final previousLabel =
        previous?[entry.exercise.id]?[widget.setNumber] ?? '';

    final inputStyle = TextStyle(
      fontSize: 14,
      color: set.isCompleted ? Colors.white : null,
    );

    return Container(
      color: set.isCompleted
          ? Colors.green.withValues(alpha: 0.3)
          : null,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Center(
              child: InkWell(
                onTap: _showTypeMenu,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade600),
                  ),
                  child: Text(
                    _typeIndicator,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                previousLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: 74,
            child: TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _save(),
              textAlign: TextAlign.center,
              style: inputStyle,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'kg',
                hintStyle: TextStyle(fontSize: 13),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: InputBorder.none,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              onChanged: (_) => _save(),
              textAlign: TextAlign.center,
              style: inputStyle,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'reps',
                hintStyle: TextStyle(fontSize: 13),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: InputBorder.none,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.check_circle_outline,
                size: 22,
                color: set.isCompleted
                    ? Colors.green.shade300
                    : Colors.grey.shade600,
              ),
              onPressed: () => ref
                  .read(activeWorkoutProvider.notifier)
                  .toggleSetComplete(widget.exerciseIndex, widget.setIndex),
            ),
          ),
        ],
      ),
    );
  }
}
