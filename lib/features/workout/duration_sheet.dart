import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Dolni sheet pro vyber doby trvani workoutu v minutach.
///
/// Vraci zvoleny pocet minut pres `Navigator.pop`.
class DurationSheet extends StatefulWidget {
  const DurationSheet({super.key, required this.initialMinutes});

  final int initialMinutes;

  @override
  State<DurationSheet> createState() => _DurationSheetState();
}

class _DurationSheetState extends State<DurationSheet> {
  static const int _maxMinutes = 300;
  static const _presets = [15, 30, 45, 60, 90, 120];

  late int _minutes = widget.initialMinutes.clamp(0, _maxMinutes);

  void _set(int value) {
    setState(() => _minutes = value.clamp(0, _maxMinutes));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Duration',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              const Text(
                'How long did the workout take?',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              Text(
                '$_minutes min',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              Slider(
                value: _minutes.toDouble(),
                min: 0,
                max: _maxMinutes.toDouble(),
                divisions: _maxMinutes,
                label: '$_minutes min',
                onChanged: (value) => _set(value.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepButton(
                    icon: Icons.remove_rounded,
                    onTap: () => _set(_minutes - 1),
                  ),
                  const SizedBox(width: 16),
                  _StepButton(
                    icon: Icons.add_rounded,
                    onTap: () => _set(_minutes + 1),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final preset in _presets)
                    ChoiceChip(
                      label: Text('$preset min'),
                      selected: _minutes == preset,
                      onSelected: (_) => _set(preset),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context, _minutes),
                child: const Text('Set duration'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceHigh,
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: AppTheme.accentBright),
        ),
      ),
    );
  }
}
