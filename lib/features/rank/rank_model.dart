import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ranky od nejnižšího po nejvyšší.
///
/// Iron–Grandmaster mají tři divize (I/II/III), Alpha je jediná
/// a odpovídá přibližně hornímu 1 %.
enum RankTier {
  iron,
  bronze,
  silver,
  gold,
  platinum,
  diamond,
  master,
  grandmaster,
  alpha,
}

extension RankTierInfo on RankTier {
  String get label => switch (this) {
        RankTier.iron => 'Iron',
        RankTier.bronze => 'Bronze',
        RankTier.silver => 'Silver',
        RankTier.gold => 'Gold',
        RankTier.platinum => 'Platinum',
        RankTier.diamond => 'Diamond',
        RankTier.master => 'Master',
        RankTier.grandmaster => 'Grandmaster',
        RankTier.alpha => 'Alpha',
      };

  /// Barva zůstává v paletě appky (černá / bílá / elektrická modrá),
  /// jen se mění jas a odstín, aby byly ranky od sebe čitelné.
  Color get color => switch (this) {
        RankTier.iron => const Color(0xFF6B7688),
        RankTier.bronze => const Color(0xFF8C97A8),
        RankTier.silver => const Color(0xFFC2CDDD),
        RankTier.gold => const Color(0xFF2F6BFF),
        RankTier.platinum => const Color(0xFF5B9BFF),
        RankTier.diamond => const Color(0xFF43D9FF),
        RankTier.master => const Color(0xFF8AB8FF),
        RankTier.grandmaster => const Color(0xFFC7DCFF),
        RankTier.alpha => const Color(0xFFFFFFFF),
      };

  /// Vlastní symbol ranku. S postupem roste i tvar emblému.
  IconData get icon => switch (this) {
        RankTier.iron => Icons.change_history_rounded,
        RankTier.bronze => Icons.hexagon_outlined,
        RankTier.silver => Icons.hexagon_rounded,
        RankTier.gold => Icons.workspace_premium_outlined,
        RankTier.platinum => Icons.workspace_premium_rounded,
        RankTier.diamond => Icons.diamond_outlined,
        RankTier.master => Icons.military_tech_outlined,
        RankTier.grandmaster => Icons.military_tech_rounded,
        RankTier.alpha => Icons.bolt_rounded,
      };

  /// Krátký popis pro přehled ranků.
  String get caption => switch (this) {
        RankTier.iron => 'Just starting out',
        RankTier.bronze => 'Beginner',
        RankTier.silver => 'Novice',
        RankTier.gold => 'Intermediate',
        RankTier.platinum => 'Strong',
        RankTier.diamond => 'Advanced',
        RankTier.master => 'Very advanced',
        RankTier.grandmaster => 'Elite',
        RankTier.alpha => 'Top 1 %',
      };

  /// Alpha se nedělí, ostatní ranky mají tři divize.
  bool get hasDivisions => this != RankTier.alpha;
}

/// Pohlaví, podle kterého se vybírá tabulka standardů.
///
/// Strength Level má mužské i ženské tabulky pro stejné cviky. Dokud
/// uživatel pohlaví nevyplní, používá se mužská tabulka (stejně jako
/// před zavedením volby).
enum RankSex {
  male,
  female;

  static RankSex fromDatabase(String? value) =>
      value == 'female' ? RankSex.female : RankSex.male;

  String get databaseValue => name;

  String get label => switch (this) {
        RankSex.male => 'Men',
        RankSex.female => 'Women',
      };
}

/// Rank převedený na spojité body 0–25.
///
/// 0–3 Iron, 3–6 Bronze, … 21–24 Grandmaster, 24–25 Alpha.
/// Spojitá hodnota se používá pro průměrování mezi cviky, svaly
/// a skupinami – díky tomu se rank posouvá plynule a ne skokově.
class RankValue {
  const RankValue(this.points) : assert(points >= 0, 'points nesmi byt zaporne');

  static const double maxPoints = 25;

  final double points;

  RankTier get tier {
    final index = (points / 3).floor().clamp(0, RankTier.values.length - 1);
    return RankTier.values[index];
  }

  /// 1–3, nebo `null` u Alphay (ta se nedělí).
  int? get division {
    if (tier == RankTier.alpha) return null;
    final withinTier = points - tier.index * 3;
    return (withinTier.floor() + 1).clamp(1, 3);
  }

  String get label {
    final d = division;
    if (d == null) return tier.label;
    const roman = ['I', 'II', 'III'];
    return '${tier.label} ${roman[d - 1]}';
  }

  /// Např. "Platinum III".
  String get shortLabel => label;

  /// Podíl cesty od začátku aktuálního ranku k dalšímu (0–1).
  double get progress {
    final start = tier.index * 3.0;
    final end = tier == RankTier.alpha ? maxPoints : start + 3;
    return ((points - start) / (end - start)).clamp(0.0, 1.0);
  }

  /// Popisek dalšího ranku, nebo `null` u Alphay.
  String? get nextLabel {
    if (tier == RankTier.alpha) return null;
    final nextPoints = tier.index * 3 + division!;
    return RankValue(nextPoints.toDouble()).label;
  }

  @override
  bool operator ==(Object other) =>
      other is RankValue && (other.points - points).abs() < 1e-9;

  @override
  int get hashCode => (points * 1000).round();

  @override
  String toString() => 'RankValue(${points.toStringAsFixed(2)} → $label)';
}

/// Prahy jednoho cviku.
///
/// Osm vzestupných hodnot ve "skóre" (e1RM / váha^0,67):
/// postupně strop Ironu, Bronzu, Silveru, Goldu, Platiny, Diamond,
/// Masteru a Grandmasteru. Nad poslední hodnotou je Alpha.
class RankScale {
  const RankScale({required this.thresholds})
      : assert(thresholds.length == 8, 'scale potrebuje 8 prahu');

  final List<double> thresholds;

  /// Převede skóre cviku na rank.
  RankValue rankForScore(double score) {
    if (!score.isFinite || score <= 0) return const RankValue(0);

    for (var i = 0; i < thresholds.length; i++) {
      final hi = thresholds[i];
      if (score < hi) {
        final lo = i == 0 ? 0.0 : thresholds[i - 1];
        final span = math.max(hi - lo, 1e-9);
        final fraction = ((score - lo) / span).clamp(0.0, 1.0);
        return RankValue(i * 3 + fraction * 3);
      }
    }

    // Alpha: nad Grandmasterem, body 24–25.
    final top = thresholds.last;
    final overflow = ((score - top) / (top * 0.35)).clamp(0.0, 1.0);
    return RankValue(24 + overflow);
  }

  /// Skóre, na kterém začíná daná divize/rank (pro "next rank at …").
  double scoreAt(double points) {
    final index = (points / 3).floor().clamp(0, thresholds.length - 1);
    if (index >= thresholds.length - 1 && points >= 24) {
      return thresholds.last;
    }
    final lo = index == 0 ? 0.0 : thresholds[index - 1];
    final hi = thresholds[index];
    final fraction = (points - index * 3) / 3;
    return lo + (hi - lo) * fraction.clamp(0.0, 1.0);
  }
}
