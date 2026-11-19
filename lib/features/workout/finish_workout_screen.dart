import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/edit_tile.dart';
import 'active_workout_provider.dart';
import 'duration_sheet.dart';

/// Vysledek finish obrazovky predany zpet aktivnimu workoutu.
enum FinishWorkoutResult { saved, discarded }

/// Souhrn pred ulozenim workoutu.
///
/// Uzivatel tu muze jeste zmenit nazev, dobu trvani a datum a cas zacatku.
/// Workout se ulozi az po stisku "Save workout"; dokud obrazovku zavre,
/// workout dal bezi.
class FinishWorkoutScreen extends ConsumerStatefulWidget {
  const FinishWorkoutScreen({super.key});

  @override
  ConsumerState<FinishWorkoutScreen> createState() =>
      _FinishWorkoutScreenState();
}

class _FinishWorkoutScreenState extends ConsumerState<FinishWorkoutScreen> {
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

  late final TextEditingController _titleController;
  late int _durationMinutes;
  late DateTime _startedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final workout = ref.read(activeWorkoutProvider);
    _startedAt = workout.startedAt;
    final elapsed = DateTime.now().difference(workout.startedAt).inMinutes;
    _durationMinutes = elapsed < 1 ? 1 : elapsed;

    final now = DateTime.now();
    _titleController = TextEditingController(
      text: 'Workout ${now.day}.${now.month}.',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ---------- Editace udaju ----------

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

  // ---------- Ulozeni / zahazeni ----------

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a workout title.')));
      return;
    }

    setState(() => _saving = true);
    final error = await ref
        .read(activeWorkoutProvider.notifier)
        .finish(
          title: title,
          durationSeconds: _durationMinutes * 60,
          startedAt: _startedAt,
        );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pop(FinishWorkoutResult.saved);
  }

  Future<void> _discard() async {
    if (_saving) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Discard workout',
      message: 'All exercises and sets from this workout will be lost.',
      confirmLabel: 'Discard',
    );
    if (!confirmed || !mounted) return;
    ref.read(activeWorkoutProvider.notifier).reset();
    Navigator.of(context).pop(FinishWorkoutResult.discarded);
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
    final workout = ref.watch(activeWorkoutProvider);

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Back',
            onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Finish workout'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          children: [
            _SummaryCard(workout: workout),
            const SizedBox(height: 22),
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
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Saving…' : 'Save workout'),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _saving ? null : _discard,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.danger,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              label: const Text('Discard workout'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  Souhrn workoutu
// ============================================================

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.workout});

  final ActiveWorkout workout;

  @override
  Widget build(BuildContext context) {
    final volume = formatVolume(workout.totalVolume).replaceAll(' kg', '');

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16233A), Color(0xFF0E1521)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(alpha: 0.16),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppTheme.accentBright,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workout complete',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Check the details and save it to your history.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
          const SizedBox(height: 14),
          Row(
            children: [
              _SummaryStat(
                value: '${workout.exercises.length}',
                label: 'Exercises',
              ),
              const _StatDivider(),
              _SummaryStat(value: '${workout.totalSets}', label: 'Sets'),
              const _StatDivider(),
              _SummaryStat(value: volume, label: 'kg volume'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

// ============================================================
//  Radky pro editaci
// ============================================================

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
