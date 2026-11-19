import 'dart:math' as math;

import 'rank_model.dart';
import 'rank_standards.dart';

/// Global rank se odemkne až od tohoto počtu rankovaných cviků.
const int kRankGlobalUnlockCount = 10;

/// Jak dlouho dopředu se berou série pro výpočet ranku.
const int kRankWindowDays = 84; // 12 týdnů

/// Z kolika posledních tréninků se počítá průměr.
const int kRankSessionCount = 3;

/// Rank nikdy neklesne pod tento podíl historického maxima.
const double kRankFloorFactor = 0.85;

/// Pořadí skupin v UI.
const List<String> kRankGroupOrder = [
  'Arms',
  'Legs',
  'Back',
  'Chest',
  'Shoulders',
  'Abs',
];

/// Podsvaly zobrazované v jednotlivých skupinách.
const Map<String, List<String>> kRankMusclesByGroup = {
  'Arms': ['Biceps', 'Triceps', 'Forearms'],
  'Legs': [
    'Quadriceps',
    'Hamstrings',
    'Glutes',
    'Calves',
    'Adductors',
    'Abductors',
  ],
  'Back': ['Lats', 'Upper Back', 'Lower Back', 'Traps'],
  'Chest': ['Chest'],
  'Shoulders': ['Shoulders'],
  'Abs': ['Abs'],
};

/// Jedna série z historie.
class RankSetLog {
  const RankSetLog({
    required this.weightKg,
    required this.reps,
    this.setType = 'normal',
    this.isCompleted = true,
  });

  final double weightKg;
  final int reps;
  final String setType;
  final bool isCompleted;

  /// Rozcvičovací, drop sety a neplatná opakování se do ranku nepočítají.
  bool get countsForRank =>
      isCompleted &&
      (setType == 'normal' || setType == 'failure') &&
      weightKg > 0 &&
      reps >= 1 &&
      reps <= 30;

  /// Epleyho přepočet na jedno opakování (posunutý, aby 1 opakování
  /// vrátilo přesně zvednutou váhu).
  double get e1rmKg => weightKg * (1 + (reps - 1) / 30);
}

/// Jeden trénink jednoho cviku.
class RankSessionLog {
  const RankSessionLog({required this.date, required this.sets});

  final DateTime date;
  final List<RankSetLog> sets;
}

/// Historie jednoho cviku napříč všemi tréninky.
class RankExerciseHistory {
  const RankExerciseHistory({
    required this.name,
    required this.muscleGroup,
    required this.subMuscle,
    required this.sessions,
  });

  final String name;
  final String muscleGroup;
  final String subMuscle;
  final List<RankSessionLog> sessions;
}

/// Výsledek ranku jednoho cviku.
class RankedExercise {
  const RankedExercise({
    required this.name,
    required this.group,
    required this.muscle,
    required this.rank,
    required this.score,
    required this.e1rmKg,
    required this.bestWeightKg,
    required this.bestReps,
    required this.sets12w,
    required this.lastPerformedAt,
    required this.perHand,
    required this.latestScore,
    required this.allTimeE1rmKg,
    this.nextRankLabel,
    this.nextE1rmKg,
  });

  final String name;

  /// Zobrazovaná skupina a podsval (např. Arms / Biceps).
  final String group;
  final String muscle;

  final RankValue rank;

  /// Skóre = e1RM / váha^0,67.
  final double score;

  /// e1RM, ze kterého rank vznikl (po vyhlazení a podlaze).
  final double e1rmKg;

  /// Nejlepší série, ze které se počítalo (váha jedné činky u jednoruček).
  final double bestWeightKg;
  final int bestReps;

  final int sets12w;
  final DateTime lastPerformedAt;
  final bool perHand;

  /// Skóre z posledního tréninku (bez vyhlazení).
  final double latestScore;

  final double allTimeE1rmKg;

  final String? nextRankLabel;
  final double? nextE1rmKg;

  bool get hasFreshData => sets12w > 0;
}

class RankMuscle {
  const RankMuscle({
    required this.name,
    required this.rank,
    required this.exercises,
  });

  final String name;
  final RankValue? rank;
  final List<RankedExercise> exercises;

  bool get isEmpty => exercises.isEmpty;
}

class RankGroup {
  const RankGroup({
    required this.name,
    required this.rank,
    required this.muscles,
  });

  final String name;
  final RankValue? rank;
  final List<RankMuscle> muscles;

  int get rankedExercises =>
      muscles.fold(0, (sum, muscle) => sum + muscle.exercises.length);

  bool get isEmpty => rankedExercises == 0;
}

/// Celý rank strom: cviky → podsvaly → skupiny → global.
class RankReport {
  const RankReport({
    required this.bodyWeightKg,
    required this.sex,
    required this.global,
    required this.groups,
    required this.rankedExerciseCount,
    required this.rankedSets12w,
    required this.notRankedExerciseNames,
  });

  const RankReport.empty()
      : bodyWeightKg = null,
        sex = RankSex.male,
        global = null,
        groups = const [],
        rankedExerciseCount = 0,
        rankedSets12w = 0,
        notRankedExerciseNames = const [];

  final double? bodyWeightKg;
  final RankSex sex;
  final RankValue? global;
  final List<RankGroup> groups;
  final int rankedExerciseCount;
  final int rankedSets12w;

  /// Cviky, které uživatel dělal, ale zatím nemají standard.
  final List<String> notRankedExerciseNames;

  bool get hasBodyWeight => bodyWeightKg != null && bodyWeightKg! > 0;

  bool get globalUnlocked =>
      rankedExerciseCount >= kRankGlobalUnlockCount && global != null;

  int get globalUnlockRemaining =>
      math.max(0, kRankGlobalUnlockCount - rankedExerciseCount);

  RankGroup? groupByName(String name) {
    for (final group in groups) {
      if (group.name == name) return group;
    }
    return null;
  }

  RankMuscle? muscleByName(String groupName, String muscleName) {
    final group = groupByName(groupName);
    if (group == null) return null;
    for (final muscle in group.muscles) {
      if (muscle.name == muscleName) return muscle;
    }
    return null;
  }
}

class _SessionBest {
  const _SessionBest({
    required this.date,
    required this.e1rmKg,
    required this.weightKg,
    required this.reps,
    required this.sets,
  });

  final DateTime date;
  final double e1rmKg;
  final double weightKg;
  final int reps;
  final int sets;
}

/// Zobrazovaná skupina pro název z databáze.
///
/// Biceps/Triceps/Forearms se slévají do Arms, Core do Abs.
/// Neck a Cardio vrací `null` – ty se nerankují.
String? rankDisplayGroup(String muscleGroup) {
  switch (muscleGroup) {
    case 'Biceps':
    case 'Triceps':
    case 'Forearms':
      return 'Arms';
    case 'Back':
      return 'Back';
    case 'Legs':
      return 'Legs';
    case 'Chest':
      return 'Chest';
    case 'Shoulders':
      return 'Shoulders';
    case 'Core':
      return 'Abs';
    default:
      return null;
  }
}

/// Zobrazovaný podsval. Chest, Shoulders a Abs držíme jako jeden uzel.
String? rankDisplayMuscle(String muscleGroup, String subMuscle) {
  switch (muscleGroup) {
    case 'Chest':
    case 'Shoulders':
    case 'Core':
      return rankDisplayGroup(muscleGroup);
    default:
      return subMuscle;
  }
}

/// Vypočítá celý rank strom z historie tréninků.
///
/// Čistá funkce – žádný Supabase, žádné UI. Díky tomu se dá snadno
/// testovat a případně přepočítávat jinde.
RankReport buildRankReport({
  required List<RankExerciseHistory> history,
  required double? bodyWeightKg,
  RankSex sex = RankSex.male,
  DateTime? now,
}) {
  if (bodyWeightKg == null || bodyWeightKg <= 0) {
    return RankReport.empty();
  }

  final current = now ?? DateTime.now();
  final cutoff = current.subtract(const Duration(days: kRankWindowDays));
  final bwScore = math.pow(bodyWeightKg, 0.67).toDouble();

  final ranked = <RankedExercise>[];
  final notRanked = <String>[];
  var rankedSets12w = 0;

  for (final entry in history) {
    final standard = rankStandardFor(entry.name);
    if (standard == null) {
      notRanked.add(entry.name);
      continue;
    }

    final group = rankDisplayGroup(entry.muscleGroup);
    final muscle = rankDisplayMuscle(entry.muscleGroup, entry.subMuscle);
    if (group == null || muscle == null) {
      notRanked.add(entry.name);
      continue;
    }

    final bests = <_SessionBest>[];
    var sets12w = 0;

    for (final session in entry.sessions) {
      RankSetLog? top;
      var counted = 0;
      for (final set in session.sets) {
        if (!set.countsForRank) continue;
        counted++;
        if (top == null || set.e1rmKg > top.e1rmKg) top = set;
      }
      if (top == null) continue;
      if (!session.date.isBefore(cutoff)) sets12w += counted;
      bests.add(
        _SessionBest(
          date: session.date,
          e1rmKg: top.e1rmKg,
          weightKg: top.weightKg,
          reps: top.reps,
          sets: counted,
        ),
      );
    }

    if (bests.isEmpty) continue;
    bests.sort((a, b) => b.date.compareTo(a.date));

    final allTimeBest = bests
        .map((best) => best.e1rmKg)
        .reduce((a, b) => a > b ? a : b);
    final recent = bests
        .where((best) => !best.date.isBefore(cutoff))
        .take(kRankSessionCount)
        .toList();

    // Vyhlazení: nejnovější trénink má největší váhu, ale jeden
    // povedený den tě nevyšvihne a jeden slabý tě neshodí.
    var smoothed = 0.0;
    var usedWeight = 0.0;
    const weights = [0.5, 0.3, 0.2];
    for (var i = 0; i < recent.length; i++) {
      smoothed += recent[i].e1rmKg * weights[i];
      usedWeight += weights[i];
    }

    final floor = allTimeBest * kRankFloorFactor;
    final e1rm = recent.isEmpty
        ? floor
        : math.max(smoothed / usedWeight, floor);

    final score = e1rm / bwScore;
    final scale = standard.scaleFor(bodyWeightKg: bodyWeightKg, sex: sex);
    final rank = scale.rankForScore(score);

    final display = recent.isNotEmpty ? recent.first : bests.first;
    final latestScore = bests.first.e1rmKg / bwScore;

    String? nextRankLabel;
    double? nextE1rmKg;
    if (rank.tier != RankTier.alpha) {
      final nextPoints = rank.tier.index * 3 + rank.division!;
      final nextScore = scale.scoreAt(nextPoints.toDouble());
      nextRankLabel = RankValue(nextPoints.toDouble()).label;
      nextE1rmKg = nextScore * bwScore;
    }

    rankedSets12w += sets12w;
    ranked.add(
      RankedExercise(
        name: entry.name,
        group: group,
        muscle: muscle,
        rank: rank,
        score: score,
        e1rmKg: e1rm,
        bestWeightKg: display.weightKg,
        bestReps: display.reps,
        sets12w: sets12w,
        lastPerformedAt: bests.first.date,
        perHand: standard.perHand,
        latestScore: latestScore,
        allTimeE1rmKg: allTimeBest,
        nextRankLabel: nextRankLabel,
        nextE1rmKg: nextE1rmKg,
      ),
    );
  }

  // ---------- Sestavení stromu ----------
  final groups = <RankGroup>[];

  for (final groupName in kRankGroupOrder) {
    final muscles = <RankMuscle>[];

    for (final muscleName in kRankMusclesByGroup[groupName]!) {
      final exercises = ranked
          .where((e) => e.group == groupName && e.muscle == muscleName)
          .toList()
        ..sort((a, b) => b.rank.points.compareTo(a.rank.points));

      double? musclePoints;
      if (exercises.isNotEmpty) {
        var weighted = 0.0;
        var weightSum = 0.0;
        for (final exercise in exercises) {
          // Víc sérií = větší vliv, ale od 12 sérií už ne.
          // Cvik bez čerstvých dat má váhu 1, aby úplně nezmizel.
          final weight = exercise.sets12w == 0
              ? 1.0
              : math.min(exercise.sets12w, 12).toDouble();
          weighted += exercise.rank.points * weight;
          weightSum += weight;
        }
        musclePoints = weighted / weightSum;
      }

      muscles.add(
        RankMuscle(
          name: muscleName,
          rank: musclePoints == null ? null : RankValue(musclePoints),
          exercises: exercises,
        ),
      );
    }

    final available = muscles.where((m) => m.rank != null).toList();
    final groupRank = available.isEmpty
        ? null
        : RankValue(
            available.fold<double>(0, (sum, m) => sum + m.rank!.points) /
                available.length,
          );

    groups.add(
      RankGroup(name: groupName, rank: groupRank, muscles: muscles),
    );
  }

  // ---------- Global ----------
  final groupRanks = groups.where((g) => g.rank != null).toList();
  RankValue? global;
  if (ranked.length >= kRankGlobalUnlockCount && groupRanks.isNotEmpty) {
    global = RankValue(
      groupRanks.fold<double>(0, (sum, g) => sum + g.rank!.points) /
          groupRanks.length,
    );
  }

  notRanked.sort();

  return RankReport(
    bodyWeightKg: bodyWeightKg,
    sex: sex,
    global: global,
    groups: groups,
    rankedExerciseCount: ranked.length,
    rankedSets12w: rankedSets12w,
    notRankedExerciseNames: notRanked,
  );
}
