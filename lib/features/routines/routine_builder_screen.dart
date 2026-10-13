import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/exercise_types.dart';
import '../../core/set_type.dart';
import '../../core/widgets/exercise_thumbnail.dart';
import '../../core/widgets/set_type_sheet.dart';
import '../exercises/exercise_picker_screen.dart';
import '../exercises/exercise_repository.dart';
import '../workout/set_table_header.dart';
import 'routines_repository.dart';

/// Obrazovka pro vytvoreni / upraveni rutiny (sablony workoutu).
///
/// Uzivatel si zvoli cviky a pro kazdy cvik nastavi cilove serie
/// (vaha, opakovani, typ serie). Ulozenou rutinu pak muze spustit.
class RoutineBuilderScreen extends ConsumerStatefulWidget {
  const RoutineBuilderScreen({super.key, this.routineId, this.initialName});

  /// Pokud je zadany, jedna se o upravu existujici rutiny.
  final String? routineId;

  /// Vychozi nazev nove rutiny.
  final String? initialName;

  @override
  ConsumerState<RoutineBuilderScreen> createState() =>
      _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends ConsumerState<RoutineBuilderScreen> {
  late final TextEditingController _nameController;
  late bool _isEdit;
  bool _loading = true;
  bool _saving = false;
  List<RoutineExerciseDraft> _exercises = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _isEdit = widget.routineId != null;
    _loading = _isEdit;
    if (_isEdit) _loadExistingRoutine();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingRoutine() async {
    final drafts =
        await ref.read(routineDetailProvider(widget.routineId!).future);
    if (!mounted) return;
    setState(() {
      _exercises = drafts;
      _loading = false;
    });
  }

  // ---------- Pridani cviku ----------

  Future<void> _addExercise() async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise == null || !mounted) return;
    setState(() {
      _exercises.add(
        RoutineExerciseDraft(
          exercise: exercise,
          targets: [RoutineSetTarget(reps: 10)],
        ),
      );
    });
  }

  // ---------- Sprava serii ----------

  void _addSet(int exerciseIndex) {
    final targets = _exercises[exerciseIndex].targets;
    final last = targets.isNotEmpty ? targets.last : null;
    setState(() {
      targets.add(
        RoutineSetTarget(
          weightKg: last?.weightKg,
          reps: last?.reps ?? 10,
          durationSeconds: last?.durationSeconds,
          distanceMeters: last?.distanceMeters,
          setType: last?.setType ?? SetType.normal,
        ),
      );
    });
  }

  void _updateSet(
    int exerciseIndex,
    int setIndex,
    RoutineSetTarget updated,
  ) {
    setState(() {
      _exercises[exerciseIndex].targets[setIndex] = updated;
    });
  }

  void _changeSetType(int exerciseIndex, int setIndex, String setType) {
    setState(() {
      _exercises[exerciseIndex].targets[setIndex].setType = setType;
    });
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    setState(() {
      _exercises[exerciseIndex].targets.removeAt(setIndex);
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  // ---------- Ukladani ----------

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Enter a routine name.');
      return;
    }
    if (_exercises.isEmpty) {
      _showError('Add at least one exercise.');
      return;
    }
    setState(() => _saving = true);
    try {
      await saveRoutine(
        routineId: widget.routineId,
        name: name,
        exercises: _exercises,
      );
      ref.invalidate(routinesProvider);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Save failed: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit routine' : 'New routine'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildEditor(),
    );
  }

  Widget _buildEditor() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Routine name',
            hintText: 'e.g. Push day',
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _exercises.length; i++)
          _ExerciseDraftCard(
            key: ObjectKey(_exercises[i]),
            draft: _exercises[i],
            onAddSet: () => _addSet(i),
            onUpdateSet: (setIndex, target) => _updateSet(i, setIndex, target),
            onChangeSetType: (setIndex, setType) =>
                _changeSetType(i, setIndex, setType),
            onRemoveSet: (setIndex) => _removeSet(i, setIndex),
            onRemoveExercise: () => _removeExercise(i),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _addExercise,
          icon: const Icon(Icons.add),
          label: const Text('Add exercise'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ============================================================
//  Karta cviku v builderu
// ============================================================

/// Karta jednoho cviku v builderu rutiny (nazev + cilove serie).
class _ExerciseDraftCard extends StatelessWidget {
  const _ExerciseDraftCard({
    super.key,
    required this.draft,
    required this.onAddSet,
    required this.onUpdateSet,
    required this.onChangeSetType,
    required this.onRemoveSet,
    required this.onRemoveExercise,
  });

  final RoutineExerciseDraft draft;
  final VoidCallback onAddSet;
  final void Function(int setIndex, RoutineSetTarget target) onUpdateSet;
  final void Function(int setIndex, String setType) onChangeSetType;
  final ValueChanged<int> onRemoveSet;
  final VoidCallback onRemoveExercise;

  @override
  Widget build(BuildContext context) {
    final config = configForExerciseType(draft.exercise.exerciseType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExerciseThumbnail(gifUrl: draft.exercise.gifUrl, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    draft.exercise.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemoveExercise,
                ),
              ],
            ),
            const Divider(),
            SetTableHeader(config: config),
            for (var s = 0; s < draft.targets.length; s++)
              _TargetSetRow(
                key: ObjectKey(draft.targets[s]),
                setNumber: s + 1,
                target: draft.targets[s],
                config: config,
                onUpdate: (target) => onUpdateSet(s, target),
                onChangeType: (setType) => onChangeSetType(s, setType),
                onRemove: () => onRemoveSet(s),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onAddSet,
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

// ============================================================
//  Radek cilove serie v builderu
// ============================================================

/// Jeden radek cilove serie v builderu rutiny.
///
/// Krouzek s cislem = zmena typu serie. Vstupni pole podle typu cviku.
class _TargetSetRow extends ConsumerStatefulWidget {
  const _TargetSetRow({
    super.key,
    required this.setNumber,
    required this.target,
    required this.config,
    required this.onUpdate,
    required this.onChangeType,
    required this.onRemove,
  });

  final int setNumber;
  final RoutineSetTarget target;
  final ExerciseInputConfig config;
  final ValueChanged<RoutineSetTarget> onUpdate;
  final ValueChanged<String> onChangeType;
  final VoidCallback onRemove;

  @override
  ConsumerState<_TargetSetRow> createState() => _TargetSetRowState();
}

class _TargetSetRowState extends ConsumerState<_TargetSetRow> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;
  late final TextEditingController _durationController;
  late final TextEditingController _distanceController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.target.weightKg == null || widget.target.weightKg == 0
          ? ''
          : '${widget.target.weightKg}',
    );
    _repsController = TextEditingController(
      text: widget.target.reps > 0 ? '${widget.target.reps}' : '',
    );
    _durationController = TextEditingController(
      text: widget.target.durationSeconds != null
          ? '${widget.target.durationSeconds}'
          : '',
    );
    _distanceController = TextEditingController(
      text: widget.target.distanceMeters != null
          ? '${widget.target.distanceMeters}'
          : '',
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  void _saveValues() {
    widget.onUpdate(
      RoutineSetTarget(
        weightKg: double.tryParse(
          _weightController.text.replaceAll(',', '.'),
        ),
        reps: int.tryParse(_repsController.text) ?? 0,
        durationSeconds: int.tryParse(_durationController.text),
        distanceMeters: double.tryParse(
          _distanceController.text.replaceAll(',', '.'),
        ),
        setType: widget.target.setType,
      ),
    );
  }

  void _openSetTypeSheet() {
    showSetTypeSheet(
      context,
      currentType: widget.target.setType,
      onTypeSelected: widget.onChangeType,
      onRemoveSet: widget.onRemove,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputStyle = const TextStyle(fontSize: 14);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          _buildSetCircle(),
          const SizedBox(width: 8),
          if (widget.config.showWeight)
            _buildInputField(
              controller: _weightController,
              hint: widget.config.weightLabel.toLowerCase(),
              width: 74,
              style: inputStyle,
              isDecimal: true,
            ),
          if (widget.config.showReps)
            _buildInputField(
              controller: _repsController,
              hint: 'reps',
              width: 64,
              style: inputStyle,
            ),
          if (widget.config.showDuration)
            _buildInputField(
              controller: _durationController,
              hint: 'sec',
              width: 64,
              style: inputStyle,
            ),
          if (widget.config.showDistance)
            _buildInputField(
              controller: _distanceController,
              hint: 'km',
              width: 64,
              style: inputStyle,
              isDecimal: true,
            ),
          const Spacer(),
          IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }

  Widget _buildSetCircle() {
    return SizedBox(
      width: 44,
      child: Center(
        child: InkWell(
          onTap: _openSetTypeSheet,
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
              SetType.indicator(widget.target.setType, widget.setNumber),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required double width,
    required TextStyle style,
    bool isDecimal = false,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: isDecimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        onChanged: (_) => _saveValues(),
        textAlign: TextAlign.center,
        style: style,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        ),
      ),
    );
  }
}
