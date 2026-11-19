import 'package:flutter/material.dart';

import '../theme.dart';

/// Mini stitek pro cviky, ktere maji vlastni rank standard.
///
/// Drzi se palety appky – elektricka modra, zadna nova barva.
class RankedTag extends StatelessWidget {
  const RankedTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Counts toward your rank',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.42),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 10, color: AppTheme.accentBright),
            SizedBox(width: 2),
            Text(
              'RANKED',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                height: 1.1,
                color: AppTheme.accentBright,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
