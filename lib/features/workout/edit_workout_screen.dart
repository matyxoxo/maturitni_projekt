import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../core/widgets/edit_tile.dart';
import '../exercises/exercise_picker_screen.dart';
import '../exercises/exercise_repository.dart';
import '../home/feed_repository.dart';
import '../home/home_repository.dart';
import '../profile/profile_repository.dart';
import '../rank/rank_repository.dart';
import 'active_workout_provider.dart';
import 'duration_sheet.dart';
import 'exercise_card.dart';
import 'workout_editor_repository.dart';

/// Editace jiz ulozeneho workoutu (nazev, cas, trvani, cviky a serie).
class EditWorkoutScreen extends ConsumerStatefulWidget {
  const EditWorkoutScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  ConsumerState<EditWorkoutScreen> createState() => _EditWorkoutScreenState();
}

class _EditWorkoutScreenState extends ConsumerState<EditWorkoutScreen> {
  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final TextEditingController _titleController = TextEditingController();
  final List<WorkoutExercise> _exercises = [];

  bool _initialized = false;
  bool _saving = false;
  late int _durationMinutes;
  late DateTime _startedAt;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  /// Prelozi nacteny detail do lokalnich editovatelnych modelu.
  void _initFrom(WorkoutDetail detail) {
    if (_initialized) return;
    _initialized = true;

    _titleController.text = detail.title;
    final seconds = detail.durationSeconds ?? 0;
    _durationMinutes = seconds <= 0 ? 0 : (seconds / 60).round().clamp(1, 300);
    _startedAt = detail.createdAt.toLocal();

    for (final detailExercise in detail.exercises) {
      final entry = WorkoutExercise(_toExercise(detailExercise));
      for (final set in detailExercise.sets) {
        entry.sets.add(
          WorkoutSet(
            weightKg: set.weightKg ?? 0,
            reps: set.repsCount ?? 0,
            durationSeconds: set.durationSeconds,
            distanceMeters: set.distanceMeters,
            setType: set.setType,
            isCompleted: set.isCompleted,
          ),
        );
      }
      if (entry.sets.isEmpty) entry.sets.add(WorkoutSet());
      _exercises.add(entry);
    }
  }

  Exercise _toExercise(WorkoutDetailExercise detail) {
    return Exercise(
      id: detail.exerciseId,
      name: detail.name,
      exerciseType: detail.exerciseType,
      equipment: detail.equipment,
      gifUrl: detail.gifUrl,
      muscleGroup: detail.muscleGroup,
      subMuscleGroup: detail.subMuscleGroup,
    );
  }

  // ---------- Editace ----------

  Future<void> _editDuration() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DurationSheet(initialMinutes: _durationMinutes),
    );
    if (picked != null && mounted) {
      setState(() => _durationMinutes = picked);
    }
  }

  Future<void> _editStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startedAt,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: 'Workout date',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startedAt),
      helpText: 'Start time',
    );
    if (time == null || !mounted) return;

    var picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (picked.isAfter(now)) picked = now;
    setState(() => _startedAt = picked);
  }

  Future<void> _addExercise() async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise == null || !mounted) return;
    setState(() {
      _exercises.add(WorkoutExercise(exercise)..sets.add(WorkoutSet()));
    });
  }

  void _removeExercise(int index) {
    setState(() => _exercises.removeAt(index));
  }

  void _addSet(int exerciseIndex) {
    setState(() {
      final sets = _exercises[exerciseIndex].sets;
      final last = sets.isNotEmpty ? sets.last : null;
      sets.add(
        WorkoutSet(weightKg: last?.weightKg ?? 0, reps: last?.reps ?? 0),
      );
    });
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    setState(() => _exercises[exerciseIndex].sets.removeAt(setIndex));
  }

  void _setSetType(int exerciseIndex, int setIndex, String setType) {
    setState(() => _exercises[exerciseIndex].sets[setIndex].setType = setType);
  }

  void _toggleSetComplete(int exerciseIndex, int setIndex) {
    setState(() {
      final set = _exercises[exerciseIndex].sets[setIndex];
      set.isCompleted = !set.isCompleted;
    });
  }

  // ---------- Ulozeni ----------

  Future<void> _save() async {
    if (_saving) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a workout title.')));
      return;
    }
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise.')),
      );
      return;
    }

    setState(() => _saving = true);
    final error = await saveWorkoutEdits(
      workoutId: widget.workoutId,
      title: title,
      durationSeconds: _durationMinutes * 60,
      startedAt: _startedAt,
      exercises: _exercises,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    ref.invalidate(feedProvider);
    ref.invalidate(userFeedProvider);
    ref.invalidate(myWorkoutsProvider);
    ref.invalidate(workoutDetailProvider(widget.workoutId));
    ref.invalidate(previousWorkoutSetsProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(rankReportProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) ref.invalidate(workoutHistoryProvider(userId));

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Workout updated.')));
    Navigator.of(context).pop();
  }

  // ---------- Formatovani ----------

  String _formatStart(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final datePart = isToday
        ? 'Today'
        : '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$datePart • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(workoutDetailProvider(widget.workoutId));

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit workout'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (detail) {
            _initFrom(detail);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
              children: [
                const _SectionLabel('DETAILS'),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Workout title',
                    counterText: '',
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                EditTile(
                  icon: Icons.timer_outlined,
                  label: 'Duration',
                  value: '$_durationMinutes min',
                  onTap: _editDuration,
                ),
                const SizedBox(height: 10),
                EditTile(
                  icon: Icons.event_outlined,
                  label: 'Started',
                  value: _formatStart(_startedAt),
                  onTap: _editStart,
                ),
                const SizedBox(height: 24),
                const _SectionLabel('EXERCISES'),
                const SizedBox(height: 4),
                for (var i = 0; i < _exercises.length; i++)
                  WorkoutExerciseCard(
                    key: ValueKey(_exercises[i]),
                    exercise: _exercises[i].exercise,
                    sets: _exercises[i].sets,
                    showPrevious: false,
                    margin: const EdgeInsets.only(top: 8),
                    onAddSet: () => _addSet(i),
                    onRemoveExercise: () => _removeExercise(i),
                    onSetChanged: (_, _) => setState(() {}),
                    onSetTypeChanged: (setIndex, setType) =>
                        _setSetType(i, setIndex, setType),
                    onRemoveSet: (setIndex) => _removeSet(i, setIndex),
                    onToggleComplete: (setIndex) =>
                        _toggleSetComplete(i, setIndex),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add exercise'),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Save changes'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  child: const Text(
                    'Discard changes',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: AppTheme.textMuted,
      ),
    );
  }
}
