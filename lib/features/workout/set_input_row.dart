import 'package:flutter/material.dart';

import '../../core/exercise_types.dart';
import '../../core/set_type.dart';
import '../../core/theme.dart';
import '../../core/widgets/set_type_sheet.dart';
import 'active_workout_provider.dart';

/// Jeden radek serie – v aktivnim workoutu i v editaci ulozeneho workoutu.
///
/// Obsahuje: krouzek s cislem (klik = zmena typu), pripadne minule hodnoty,
/// vstupni pole podle typu cviku a zakrtnuti "hotovo".
class SetInputRow extends StatefulWidget {
  const SetInputRow({
    super.key,
    required this.set,
    required this.setNumber,
    required this.config,
    required this.onChanged,
    required this.onSetTypeChanged,
    required this.onToggleComplete,
    this.onRemoveSet,
    this.previousLabel = '',
    this.showPrevious = true,
  });

  /// Data serie. Widget je zapisuje primo do objektu a vola [onChanged].
  final WorkoutSet set;
  final int setNumber;
  final ExerciseInputConfig config;
  final VoidCallback onChanged;
  final ValueChanged<String> onSetTypeChanged;
  final VoidCallback onToggleComplete;
  final VoidCallback? onRemoveSet;
  final String previousLabel;
  final bool showPrevious;

  @override
  State<SetInputRow> createState() => _SetInputRowState();
}

class _SetInputRowState extends State<SetInputRow> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;
  late final TextEditingController _durationController;
  late final TextEditingController _distanceController;

  @override
  void initState() {
    super.initState();
    final set = widget.set;
    _weightController = TextEditingController(
      text: _formatNumber(set.weightKg),
    );
    _repsController = TextEditingController(
      text: set.reps > 0 ? '${set.reps}' : '',
    );
    _durationController = TextEditingController(
      text: set.durationSeconds != null ? '${set.durationSeconds}' : '',
    );
    _distanceController = TextEditingController(
      text: _formatNumber(set.distanceMeters),
    );
  }

  /// Cislo bez zbytecne desetinne casti (20.0 -> "20").
  String _formatNumber(double? value) {
    if (value == null || value == 0) return '';
    return value == value.truncateToDouble() ? '${value.toInt()}' : '$value';
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
    final set = widget.set;
    set.weightKg = double.tryParse(_weightController.text.replaceAll(',', '.'));
    set.reps = int.tryParse(_repsController.text) ?? 0;
    set.durationSeconds = int.tryParse(_durationController.text);
    set.distanceMeters = double.tryParse(
      _distanceController.text.replaceAll(',', '.'),
    );
    widget.onChanged();
  }

  void _openSetTypeSheet() {
    showSetTypeSheet(
      context,
      currentType: widget.set.setType,
      onTypeSelected: widget.onSetTypeChanged,
      onRemoveSet: widget.onRemoveSet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final set = widget.set;
    final scheme = Theme.of(context).colorScheme;
    final inputStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: set.isCompleted ? Colors.white : scheme.onSurface,
    );

    return Container(
      color: set.isCompleted ? scheme.primary.withValues(alpha: 0.1) : null,
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          _buildSetCircle(set.setType),
          if (widget.showPrevious)
            _buildPreviousLabel(widget.previousLabel)
          else
            const SizedBox(width: 8),
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
    final isSpecial = setType != SetType.normal;
    final color = _typeColor(setType);

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
              color: isSpecial ? color.withValues(alpha: 0.14) : null,
              border: Border.all(
                color: isSpecial
                    ? color.withValues(alpha: 0.55)
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            child: Text(
              SetType.indicator(setType, widget.setNumber),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSpecial
                    ? color
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Barva krouzku podle typu serie.
  Color _typeColor(String setType) {
    switch (setType) {
      case SetType.warmup:
        return AppTheme.cyan;
      case SetType.failure:
        return AppTheme.danger;
      case SetType.dropSet:
        return AppTheme.accentBright;
      default:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  Widget _buildPreviousLabel(String label) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 10,
          ),
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
          size: 24,
          color: isCompleted
              ? Theme.of(context).colorScheme.primary
              : AppTheme.surfaceHighest,
        ),
        onPressed: widget.onToggleComplete,
      ),
    );
  }
}
