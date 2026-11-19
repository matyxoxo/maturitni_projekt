import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'rank_model.dart';

/// Kruhový emblém jednoho ranku.
///
/// Uvnitř je ikona tieru; pokud se předá [glyph], přidá se pod ni ještě
/// římská divize (u Alphay řecké α).
class RankEmblem extends StatelessWidget {
  const RankEmblem({
    super.key,
    this.tier,
    this.size = 44,
    this.glyph,
    this.active = false,
  });

  final RankTier? tier;
  final double size;
  final String? glyph;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = tier?.color ?? AppTheme.outline;
    final lit = tier != null;

    Widget child;
    if (tier == null) {
      child = Text(
        '—',
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
        ),
      );
    } else if (glyph != null) {
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(tier!.icon, size: size * 0.34, color: color),
          SizedBox(height: size * 0.015),
          Text(
            glyph!,
            style: TextStyle(
              fontSize: size * 0.17,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: color,
            ),
          ),
        ],
      );
    } else {
      child = Icon(tier!.icon, size: size * 0.46, color: color);
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: lit ? 0.26 : 0.06),
            AppTheme.surface,
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: lit ? 0.7 : 0.22),
          width: active ? 1.8 : 1.5,
        ),
        boxShadow: lit
            ? [
                BoxShadow(
                  color: color.withValues(alpha: active ? 0.32 : 0.2),
                  blurRadius: size * 0.4,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// Velký kruhový odznak s ikonou ranku a římskou divizí.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank, this.size = 64});

  final RankValue? rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = rank;
    final division = value?.division;
    final glyph = value == null
        ? null
        : division == null
            ? 'α'
            : const ['I', 'II', 'III'][division - 1];

    return RankEmblem(
      tier: value?.tier,
      size: size,
      glyph: glyph,
      active: value != null,
    );
  }
}

/// Samostatný emblém tieru bez divize – pro přehled ranků a vysvětlivky.
class RankTierMark extends StatelessWidget {
  const RankTierMark({
    super.key,
    required this.tier,
    this.size = 44,
    this.active = false,
  });

  final RankTier tier;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return RankEmblem(tier: tier, size: size, active: active);
  }
}

/// Malý štítek s celým názvem ranku.
class RankPill extends StatelessWidget {
  const RankPill({super.key, required this.rank, this.dense = false});

  final RankValue? rank;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final value = rank;
    final color = value?.tier.color ?? AppTheme.textMuted;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: value == null ? 0.06 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) ...[
            Icon(
              value.tier.icon,
              size: dense ? 11 : 13,
              color: color,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            value?.label ?? '—',
            style: TextStyle(
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tenká lišta postupu k dalšímu ranku.
class RankProgressBar extends StatelessWidget {
  const RankProgressBar({
    super.key,
    required this.rank,
    this.showLabel = true,
  });

  final RankValue rank;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final next = rank.nextLabel;
    final percent = (rank.progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  next == null ? 'Max rank reached' : 'Next: $next',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                next == null ? '100 %' : '$percent %',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: rank.tier.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: rank.progress,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            color: rank.tier.color,
          ),
        ),
      ],
    );
  }
}

/// Ikona skupiny – drží se stejného vizuálního jazyka jako zbytek appky.
IconData rankGroupIcon(String group) => switch (group) {
      'Arms' => Icons.fitness_center_rounded,
      'Legs' => Icons.directions_run_rounded,
      'Back' => Icons.airline_seat_recline_normal_rounded,
      'Chest' => Icons.favorite_rounded,
      'Shoulders' => Icons.accessibility_new_rounded,
      'Abs' => Icons.self_improvement_rounded,
      _ => Icons.circle_outlined,
    };

String formatRankKg(double kg) {
  if ((kg - kg.roundToDouble()).abs() < 0.05) return kg.round().toString();
  return kg.toStringAsFixed(1);
}

/// Výběr tabulky standardů – muži, nebo ženy.
///
/// Strength Level publikuje pro každý cvik obě tabulky; tenhle přepínač
/// rozhoduje, která se použije.
class RankSexSelector extends StatelessWidget {
  const RankSexSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final RankSex? value;
  final ValueChanged<RankSex> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _choice(
            RankSex.male,
            'Men',
            Icons.male_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _choice(
            RankSex.female,
            'Women',
            Icons.female_rounded,
          ),
        ),
      ],
    );
  }

  Widget _choice(RankSex sex, String label, IconData icon) {
    final selected = value == sex;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onChanged(sex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accent.withValues(alpha: 0.16)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppTheme.accent
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppTheme.accentBright : AppTheme.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
