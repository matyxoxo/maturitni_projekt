import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'rank_model.dart';
import 'rank_repository.dart';
import 'rank_widgets.dart';

/// Přehled všech ranků od Ironu po Alphu.
///
/// Slouží jako legenda: každý tier má vlastní emblém, popis a divize.
/// Aktuální celkový rank je v seznamu zvýrazněný.
class RankTiersScreen extends ConsumerWidget {
  const RankTiersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(rankReportProvider).asData?.value.global;

    return Scaffold(
      appBar: AppBar(title: const Text('Ranks')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
        children: [
          _TiersHeader(current: current),
          const SizedBox(height: 20),
          for (final tier in RankTier.values) ...[
            _TierCard(tier: tier, current: current),
            if (tier != RankTier.values.last) const SizedBox(height: 10),
          ],
          const SizedBox(height: 22),
          const _TiersNote(),
        ],
      ),
    );
  }
}

class _TiersHeader extends StatelessWidget {
  const _TiersHeader({required this.current});

  final RankValue? current;

  @override
  Widget build(BuildContext context) {
    final color = current?.tier.color ?? AppTheme.accentBright;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: AppTheme.heroGradient,
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: current == null
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.14),
                  blurRadius: 40,
                  offset: const Offset(0, 14),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THE LADDER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Iron to Alpha',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.9,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nine ranks. Each one is a slice of the community, not a fixed '
            'weight. Iron to Grandmaster have three divisions; Alpha is the '
            'top 1 %.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          if (current != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  RankBadge(rank: current, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'YOUR OVERALL RANK',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          current!.label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Your overall rank shows up here once it unlocks.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier, required this.current});

  final RankTier tier;
  final RankValue? current;

  @override
  Widget build(BuildContext context) {
    final isCurrent = current?.tier == tier;
    final color = tier.color;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent ? color.withValues(alpha: 0.1) : AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCurrent
              ? color.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.06),
          width: isCurrent ? 1.4 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.14),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          RankTierMark(tier: tier, size: 48, active: isCurrent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tier.label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: color,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      _CurrentBadge(color: color),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  tier.caption,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                _DivisionRow(
                  tier: tier,
                  division: isCurrent ? current!.division : null,
                  color: color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        'YOU',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }
}

class _DivisionRow extends StatelessWidget {
  const _DivisionRow({
    required this.tier,
    required this.division,
    required this.color,
  });

  final RankTier tier;
  final int? division;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!tier.hasDivisions) {
      return _chip(
        'TOP 1 %',
        active: true,
        color: color,
      );
    }

    return Row(
      children: [
        for (var i = 1; i <= 3; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          _chip(
            const ['I', 'II', 'III'][i - 1],
            active: division == i,
            color: color,
          ),
        ],
      ],
    );
  }

  Widget _chip(String label, {required bool active, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? color.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: active
              ? color.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          color: active ? color : AppTheme.textMuted,
        ),
      ),
    );
  }
}

class _TiersNote extends StatelessWidget {
  const _TiersNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW THE LADDER WORKS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: AppTheme.textMuted,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Every lift is scored for your sex and exact bodyweight. Exercise '
            'ranks roll up into sub-muscles, sub-muscles into muscle groups, '
            'and the overall rank is the average of all six groups. It unlocks '
            'at 10 ranked exercises.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppTheme.textMuted,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Thresholds come from Strength Level\'s public by-bodyweight '
            'tables. Divisions are interpolated between their published '
            'percentiles.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
