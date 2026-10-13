import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exercise_types.dart';
import '../../core/set_type.dart';
import '../../core/widgets/set_type_sheet.dart';
import 'active_workout_provider.dart';

/// Jeden radek serie v aktivnim workoutu.
///
/// Obsahuje: krouzek s cislem (klik = zmena typu), minule hodnoty,
/// vstupni pole podle typu cviku a zakrtnuti "hotovo".
class SetInputRow extends ConsumerStatefulWidget {
  const SetInputRow({
    super.key,
    required this.exerciseIndex,
    required this.setIndex,
    required this.config,
  });

  final int exerciseIndex;
  final int setIndex;
  final ExerciseInputConfig config;

  @override
  ConsumerState<SetInputRow> createState() => _SetInputRowState();
}

class _SetInputRowState extends ConsumerState<SetInputRow> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;
  late final TextEditingController _durationController;
  late final TextEditingController _distanceController;

  int get _setNumber => widget.setIndex + 1;

  @override
  void initState() {
    super.initState();
    final set = _currentSet();
    _weightController = TextEditingController(
      text: set.weightKg == null || set.weightKg == 0 ? '' : '${set.weightKg}',
    );
    _repsController = TextEditingController(
      text: set.reps > 0 ? '${set.reps}' : '',
    );
    _durationController = TextEditingController(
      text: set.durationSeconds != null ? '${set.durationSeconds}' : '',
    );
    _distanceController = TextEditingController(
      text: set.distanceMeters != null ? '${set.distanceMeters}' : '',
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

  WorkoutSet _currentSet() {
    return ref
        .read(activeWorkoutProvider)
        .exercises[widget.exerciseIndex]
        .sets[widget.setIndex];
  }

  void _saveValues() {
    ref.read(activeWorkoutProvider.notifier).updateSet(
          widget.exerciseIndex,
          widget.setIndex,
          weightKg: double.tryParse(
            _weightController.text.replaceAll(',', '.'),
          ),
          reps: int.tryParse(_repsController.text),
          durationSeconds: int.tryParse(_durationController.text),
          distanceMeters: double.tryParse(
            _distanceController.text.replaceAll(',', '.'),
          ),
        );
  }

  void _openSetTypeSheet() {
    final set = _currentSet();
    showSetTypeSheet(
      context,
      currentType: set.setType,
      onTypeSelected: (newType) {
        ref.read(activeWorkoutProvider.notifier).setSetType(
              widget.exerciseIndex,
              widget.setIndex,
              newType,
            );
      },
      onRemoveSet: () {
        ref.read(activeWorkoutProvider.notifier).removeSet(
              widget.exerciseIndex,
              widget.setIndex,
            );
      },
    );
  }

  void _toggleComplete() {
    ref.read(activeWorkoutProvider.notifier).toggleSetComplete(
          widget.exerciseIndex,
          widget.setIndex,
        );
  }

  @override
  Widget build(BuildContext context) {
    final set = _currentSet();
    final previous = ref.watch(previousWorkoutSetsProvider).value;
    final exerciseId = ref
        .read(activeWorkoutProvider)
        .exercises[widget.exerciseIndex]
        .exercise
        .id;
    final previousLabel = previous?[exerciseId]?[_setNumber] ?? '';

    final inputStyle = TextStyle(
      fontSize: 14,
      color: set.isCompleted ? Colors.white : null,
    );

    return Container(
      color: set.isCompleted ? Colors.green.withValues(alpha: 0.3) : null,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          _buildSetCircle(set.setType),
          _buildPreviousLabel(previousLabel),
          if (widget.config.showWeight)
            _buildInputField(
              controller: _weightController,
              hint: widget.config.weightLabel.toLowerCase(),
              style: inputStyle,
              width: 74,
              isDecimal: true,
            ),
          if (widget.config.showReps)
            _buildInputField(
              controller: _repsController,
              hint: 'reps',
              style: inputStyle,
              width: 64,
            ),
          if (widget.config.showDuration)
            _buildInputField(
              controller: _durationController,
              hint: 'sec',
              style: inputStyle,
              width: 64,
            ),
          if (widget.config.showDistance)
            _buildInputField(
              controller: _distanceController,
              hint: 'km',
              style: inputStyle,
              width: 64,
              isDecimal: true,
            ),
          _buildCompleteButton(set.isCompleted),
        ],
      ),
    );
  }

  Widget _buildSetCircle(String setType) {
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
              SetType.indicator(setType, _setNumber),
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

  Widget _buildPreviousLabel(String label) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required TextStyle style,
    required double width,
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
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildCompleteButton(bool isCompleted) {
    return SizedBox(
      width: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.check_circle_outline,
          size: 22,
          color: isCompleted ? Colors.green.shade300 : Colors.grey.shade600,
        ),
        onPressed: _toggleComplete,
      ),
    );
  }
}
