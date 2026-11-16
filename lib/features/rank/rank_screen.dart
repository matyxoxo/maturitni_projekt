import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Zalozka Rank – zebricek (zatim pripraveny stav).
class RankScreen extends StatelessWidget {
  const RankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rank')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.22),
                      AppTheme.accent.withValues(alpha: 0.04),
                    ],
                  ),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.leaderboard_rounded,
                  size: 40,
                  color: AppTheme.accentBright,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Leaderboard is coming',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Keep training and track your volume, streaks and\nweekly consistency here soon.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
