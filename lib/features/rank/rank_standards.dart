import 'dart:math' as math;

import 'rank_model.dart';
import 'rank_standards_data.dart';

/// Percentily, které Strength Level publikuje u svých pěti úrovní.
///
/// Podle jejich FAQ: Beginner = 5., Novice = 20., Intermediate = 50.,
/// Advanced = 80. a Elite = 95. percentil.
const List<double> rankPublishedPercentiles = [5, 20, 50, 80, 95];

/// Hranice (stropy) našich osmi rankovaných úrovní v percentilech.
///
/// Pět hranic sedí přesně na publikované percentily Strength Levelu:
///   Iron/Bronze = 5 (Beginner), Bronze/Silver = 20 (Novice),
///   Silver/Gold = 50 (Intermediate), Platinum/Diamond = 80 (Advanced),
///   Master/Grandmaster = 95 (Elite).
///
/// Zbývající tři jsou mezi nimi lineárně dopočítané:
///   Gold/Platinum = 65 (půlka mezi 50 a 80),
///   Diamond/Master = 88 (8/15 cesty mezi 80 a 95),
///   Grandmaster/Alpha = 99 (extrapolace sklonem 80→95, tj. top 1 %).
///
/// Díky tomu jsou všechny kilogramy z veřejné tabulky a jediné, co
/// dopočítáváme, jsou mezistupně mezi publikovanými percentily.
const List<double> rankBoundaryPercentiles = [5, 20, 50, 65, 80, 88, 95, 99];

/// Jeden rankovaný cvik.
///
/// Kilogramové prahy nejsou v kódu napsané – berou se z [rankTableData],
/// což je vygenerovaná mužská a ženská tabulka "By Bodyweight" ze
/// Strength Levelu. Pro konkrétní váhu těla se mezi řádky lineárně
/// interpoluje, stejně jako to dělá jejich tabulka mezi 5kg kroky.
class RankStandard {
  const RankStandard({
    required this.name,
    this.aliases = const [],
    this.perHand = false,
  });

  /// Přesný název cviku v `exercises.exercise_name`.
  final String name;

  /// Další názvy, které se mají mapovat na stejný standard.
  final List<String> aliases;

  /// U jednoruček se zapisuje váha jedné činky.
  final bool perHand;

  String get key => rankExerciseKey(name);

  RankTableData get data {
    final table = rankTableData[key];
    if (table == null) {
      throw StateError('Chybí tabulka standardů pro "$name".');
    }
    return table;
  }

  /// Prahy pro konkrétní váhu těla a pohlaví.
  ///
  /// Skóre cviku je `e1RM / váha^0,67`, takže i prahy se dělí stejným
  /// číslem. Výsledkem je, že se e1RM porovnává přímo s publikovanou
  /// tabulkou pro danou váhu těla.
  RankScale scaleFor({
    required double bodyWeightKg,
    RankSex sex = RankSex.male,
  }) {
    final rows = sex == RankSex.female ? data.female : data.male;
    final levels = _levelsAt(rows, bodyWeightKg);
    final thresholdsKg = _thresholdsKgAt(levels);
    final bwScore = math.pow(bodyWeightKg, 0.67).toDouble();
    return RankScale(
      thresholds: [for (final kg in thresholdsKg) kg / bwScore],
    );
  }
}

/// Pět publikovaných úrovní interpolovaných na přesnou váhu těla.
List<double> _levelsAt(List<List<int>> rows, double bodyWeightKg) {
  final lowest = rows.first[0].toDouble();
  final highest = rows.last[0].toDouble();
  final bw = bodyWeightKg.clamp(lowest, highest).toDouble();

  for (var i = 0; i < rows.length - 1; i++) {
    final lo = rows[i];
    final hi = rows[i + 1];
    if (bw <= hi[0]) {
      final span = (hi[0] - lo[0]).toDouble();
      final t = span == 0 ? 0.0 : (bw - lo[0]) / span;
      return [for (var c = 1; c <= 5; c++) lo[c] + t * (hi[c] - lo[c])];
    }
  }

  return [for (var c = 1; c <= 5; c++) rows.last[c].toDouble()];
}

/// Převede pět publikovaných úrovní na osm hranic našich ranků.
///
/// Mezi publikovanými body se interpoluje lineárně v percentilech;
/// nad Elitem (95) se pokračuje stejným sklonem jako mezi 80 a 95.
List<double> _thresholdsKgAt(List<double> levels) {
  final beginner = levels[0];
  final novice = levels[1];
  final intermediate = levels[2];
  final advanced = levels[3];
  final elite = levels[4];

  double at(double percentile) {
    if (percentile <= 20) {
      return _lerp(beginner, novice, (percentile - 5) / 15);
    }
    if (percentile <= 50) {
      return _lerp(novice, intermediate, (percentile - 20) / 30);
    }
    if (percentile <= 80) {
      return _lerp(intermediate, advanced, (percentile - 50) / 30);
    }
    if (percentile <= 95) {
      return _lerp(advanced, elite, (percentile - 80) / 15);
    }
    return elite + (elite - advanced) * (percentile - 95) / 15;
  }

  return [for (final percentile in rankBoundaryPercentiles) at(percentile)];
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

String rankExerciseKey(String name) {
  final buffer = StringBuffer();
  for (final rune in name.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    if (RegExp('[a-z0-9]').hasMatch(char)) buffer.write(char);
  }
  return buffer.toString();
}

/// Všechny rankované cviky. Seznam i tabulky jsou generované
/// z `tool/rank_standards_mapping.dart`; tady se jen obalí do objektů.
final List<RankStandard> rankStandards = [
  for (final entry in rankStandardEntries)
    RankStandard(
      name: entry.name,
      aliases: entry.aliases,
      perHand: entry.perHand,
    ),
];

final Map<String, RankStandard> _standardsByKey = {
  for (final standard in rankStandards) standard.key: standard,
  for (final standard in rankStandards)
    for (final alias in standard.aliases) rankExerciseKey(alias): standard,
};

/// Najde standard podle názvu cviku. Vrací `null`, pokud cvik
/// zatím rankovaný není.
RankStandard? rankStandardFor(String exerciseName) {
  return _standardsByKey[rankExerciseKey(exerciseName)];
}

/// Cviky, u kterých se zapisuje váha jedné činky.
bool rankStandardIsPerHand(String exerciseName) {
  return rankStandardFor(exerciseName)?.perHand ?? false;
}
