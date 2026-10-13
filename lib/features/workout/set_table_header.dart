import 'package:flutter/material.dart';

import '../../core/exercise_types.dart';

/// Hlavicka tabulky serii u cviku – popisky sloupcu (SET, PREVIOUS, KG, REPS...).
///
/// [showPrevious] zapina sloupec PREVIOUS (jen v aktivnim workoutu).
class SetTableHeader extends StatelessWidget {
  const SetTableHeader({
    super.key,
    required this.config,
    this.showPrevious = false,
  });

  final ExerciseInputConfig config;
  final bool showPrevious;

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
          if (showPrevious)
            Expanded(
              child: Center(child: Text('PREVIOUS', style: style)),
            )
          else
            const SizedBox(width: 8),
          if (config.showWeight)
            SizedBox(
              width: 74,
              child: Center(child: Text(config.weightLabel, style: style)),
            ),
          if (config.showReps)
            SizedBox(
              width: 64,
              child: Center(child: Text('REPS', style: style)),
            ),
          if (config.showDuration)
            SizedBox(
              width: 64,
              child: Center(child: Text('TIME', style: style)),
            ),
          if (config.showDistance)
            SizedBox(
              width: 64,
              child: Center(child: Text('KM', style: style)),
            ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
