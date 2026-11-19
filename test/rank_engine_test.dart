import 'dart:io';
import 'dart:math' as math;

import 'package:alphalift/features/rank/rank_engine.dart';
import 'package:alphalift/features/rank/rank_model.dart';
import 'package:alphalift/features/rank/rank_standards.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 18, 12);

RankSessionLog _session(int daysAgo, List<(double, int)> sets) => RankSessionLog(
      date: _now.subtract(Duration(days: daysAgo)),
      sets: [
        for (final (weight, reps) in sets)
          RankSetLog(weightKg: weight, reps: reps),
      ],
    );

RankExerciseHistory _history(
  String name,
  List<RankSessionLog> sessions, {
  String group = 'Chest',
  String sub = 'Middle Chest',
}) =>
    RankExerciseHistory(
      name: name,
      muscleGroup: group,
      subMuscle: sub,
      sessions: sessions,
    );

RankReport _report(
  List<RankExerciseHistory> history, {
  double bodyWeightKg = 98,
  RankSex sex = RankSex.male,
}) =>
    buildRankReport(
      history: history,
      bodyWeightKg: bodyWeightKg,
      sex: sex,
      now: _now,
    );

RankedExercise _exercise(RankReport report, String name) {
  for (final group in report.groups) {
    for (final muscle in group.muscles) {
      for (final exercise in muscle.exercises) {
        if (exercise.name == name) return exercise;
      }
    }
  }
  fail('Cvik $name v reportu neni');
}

void main() {
  group('RankValue', () {
    test('mapuje body na nazvy ranku', () {
      expect(const RankValue(0).label, 'Iron I');
      expect(const RankValue(3).label, 'Bronze I');
      expect(const RankValue(6).label, 'Silver I');
      expect(const RankValue(12).label, 'Platinum I');
      expect(const RankValue(24).label, 'Alpha');
      expect(const RankValue(25).label, 'Alpha');
    });

    test('Alpha se nedeli na divize', () {
      expect(const RankValue(24.5).division, isNull);
      expect(const RankValue(17.5).division, 3);
    });

    test('postup k dalsimu ranku', () {
      expect(const RankValue(9).nextLabel, 'Gold II');
      expect(const RankValue(11.9).nextLabel, 'Platinum I');
      expect(const RankValue(24.2).nextLabel, isNull);
    });
  });

  group('Jeden cvik', () {
    test('100 kg x 2 pri 98 kg je Silver II', () {
      final report = _report([
        _history('Barbell Bench Press', [_session(1, [(100, 2)])]),
      ]);
      final bench = _exercise(report, 'Barbell Bench Press');

      expect(bench.rank.label, 'Silver II');
      expect(bench.e1rmKg, closeTo(100 * (1 + 1 / 30), 0.001));
      expect(bench.sets12w, 1);
    });

    test('lehci clovek dostane vyssi rank za stejnou vahu', () {
      final session = [_session(1, [(100, 2)])];
      final heavy = _report([_history('Barbell Bench Press', session)]);
      final light = _report(
        [_history('Barbell Bench Press', session)],
        bodyWeightKg: 80,
      );

      final heavyPoints = _exercise(heavy, 'Barbell Bench Press').rank.points;
      final lightPoints = _exercise(light, 'Barbell Bench Press').rank.points;

      expect(lightPoints, greaterThan(heavyPoints));
      expect(
        _exercise(light, 'Barbell Bench Press').rank.tier,
        RankTier.gold,
      );
    });

    test('rank je hned po prvnim treninku', () {
      final report = _report([
        _history('Barbell Bench Press', [_session(0, [(75, 5)])]),
      ]);
      expect(_exercise(report, 'Barbell Bench Press').rank.tier.index,
          greaterThanOrEqualTo(1));
      expect(_exercise(report, 'Barbell Bench Press').sets12w, 1);
    });

    test('rozcvicka, drop sety a neplatna opakovani se ignoruji', () {
      final session = RankSessionLog(
        date: _now,
        sets: const [
          RankSetLog(weightKg: 200, reps: 1, setType: 'warmup'),
          RankSetLog(weightKg: 200, reps: 1, setType: 'drop_set'),
          RankSetLog(weightKg: 200, reps: 1, isCompleted: false),
          RankSetLog(weightKg: 0, reps: 10),
          RankSetLog(weightKg: 60, reps: 31),
          RankSetLog(weightKg: 0, reps: 0),
          RankSetLog(weightKg: 80, reps: 5),
        ],
      );
      final report = _report([
        _history('Barbell Bench Press', [session]),
      ]);
      final bench = _exercise(report, 'Barbell Bench Press');

      expect(bench.sets12w, 1);
      expect(bench.e1rmKg, closeTo(80 * (1 + 4 / 30), 0.001));
    });

    test('tri stejne treninky daji stejny rank jako jeden', () {
      final once = _report([
        _history('Barbell Bench Press', [_session(20, [(100, 2)])]),
      ]);
      final thrice = _report([
        _history('Barbell Bench Press', [
          _session(20, [(100, 2)]),
          _session(13, [(100, 2)]),
          _session(6, [(100, 2)]),
        ]),
      ]);

      expect(
        _exercise(thrice, 'Barbell Bench Press').rank.points,
        closeTo(_exercise(once, 'Barbell Bench Press').rank.points, 1e-6),
      );
    });

    test('novy rekord zvedne rank hned', () {
      final old = _report([
        _history('Barbell Bench Press', [
          _session(14, [(100, 5)]),
          _session(7, [(100, 5)]),
          _session(0, [(100, 5)]),
        ]),
      ]);
      final pr = _report([
        _history('Barbell Bench Press', [
          _session(14, [(100, 5)]),
          _session(7, [(100, 5)]),
          _session(0, [(120, 1)]),
        ]),
      ]);

      expect(
        _exercise(pr, 'Barbell Bench Press').rank.points,
        greaterThan(_exercise(old, 'Barbell Bench Press').rank.points),
      );
    });

    test('rank neklesne pod 85 % historickeho maxima', () {
      final report = _report([
        _history('Barbell Bench Press', [
          _session(60, [(150, 1)]),
          _session(1, [(100, 1)]),
        ]),
      ]);
      final bench = _exercise(report, 'Barbell Bench Press');

      expect(bench.allTimeE1rmKg, closeTo(150, 0.001));
      expect(bench.e1rmKg, closeTo(150 * 0.85, 0.001));
    });

    test('po pauze rank zustane, ale sets12w je nula', () {
      final report = _report([
        _history('Barbell Bench Press', [_session(120, [(120, 1)])]),
      ]);
      final bench = _exercise(report, 'Barbell Bench Press');

      expect(bench.sets12w, 0);
      expect(bench.e1rmKg, closeTo(120 * 0.85, 0.001));
      expect(bench.rank.points, greaterThan(0));
    });
  });

  group('Strom a prumerovani', () {
    test('podsval je vazeny prumer cviku podle poctu serii', () {
      final report = _report([
        _history(
          'Barbell Bench Press',
          [for (var i = 0; i < 12; i++) _session(i, [(100, 5)])],
        ),
        _history(
          'Smith Bench Press',
          [_session(2, [(60, 5)])],
        ),
      ]);

      final chest = report.groupByName('Chest')!.muscles.single;
      final bench = _exercise(report, 'Barbell Bench Press');
      final smith = _exercise(report, 'Smith Bench Press');
      final expected = (bench.rank.points * 12 + smith.rank.points) / 13;

      expect(chest.rank!.points, closeTo(expected, 1e-6));
    });

    test('skupina je equal-weight prumer podsvalu', () {
      final report = _report([
        _history(
          'Barbell Full Squat',
          [_session(1, [(140, 3)])],
          group: 'Legs',
          sub: 'Quadriceps',
        ),
        _history(
          'Lever Lying Leg Curl',
          [_session(1, [(60, 8)])],
          group: 'Legs',
          sub: 'Hamstrings',
        ),
      ]);

      final legs = report.groupByName('Legs')!;
      final quads = legs.muscles.firstWhere((m) => m.name == 'Quadriceps');
      final hams = legs.muscles.firstWhere((m) => m.name == 'Hamstrings');

      expect(
        legs.rank!.points,
        closeTo((quads.rank!.points + hams.rank!.points) / 2, 1e-6),
      );
    });

    test('Chest, Shoulders a Abs maji jediny uzel', () {
      final report = _report([
        _history(
          'Barbell Bench Press',
          [_session(1, [(100, 5)])],
          sub: 'Upper Chest',
        ),
        _history(
          'Barbell Seated Overhead Press',
          [_session(1, [(60, 5)])],
          group: 'Shoulders',
          sub: 'Front Delts',
        ),
        _history(
          'Cable Kneeling Crunch',
          [_session(1, [(60, 10)])],
          group: 'Core',
          sub: 'Obliques',
        ),
      ]);

      expect(report.groupByName('Chest')!.muscles.map((m) => m.name), ['Chest']);
      expect(
        report.groupByName('Shoulders')!.muscles.map((m) => m.name),
        ['Shoulders'],
      );
      expect(report.groupByName('Abs')!.muscles.map((m) => m.name), ['Abs']);
    });

    test('Neck a Cardio se nerankuji', () {
      final report = _report([
        _history(
          'Barbell Bench Press',
          [_session(1, [(100, 5)])],
        ),
        _history(
          'Lever Seated Crunch',
          [_session(1, [(50, 10)])],
          group: 'Neck',
          sub: 'Neck',
        ),
      ]);

      expect(report.rankedExerciseCount, 1);
      expect(report.notRankedExerciseNames, contains('Lever Seated Crunch'));
    });

    test('cvik bez standardu se zobrazi jako not ranked', () {
      final report = _report([
        _history(
          'Band One Arm Twisting Chest Press',
          [_session(1, [(20, 10)])],
        ),
      ]);

      expect(report.rankedExerciseCount, 0);
      expect(
        report.notRankedExerciseNames,
        contains('Band One Arm Twisting Chest Press'),
      );
    });

    test('prazdna skupina ma rank null', () {
      final report = _report([
        _history('Barbell Bench Press', [_session(1, [(100, 5)])]),
      ]);

      expect(report.groupByName('Legs')!.rank, isNull);
      expect(report.groupByName('Legs')!.isEmpty, isTrue);
    });
  });

  group('Global', () {
    List<RankExerciseHistory> tenExercises() => [
          _history('Barbell Bench Press', [_session(1, [(100, 5)])]),
          _history('Smith Bench Press', [_session(1, [(90, 5)])]),
          _history(
            'Barbell Bent Over Row',
            [_session(1, [(90, 5)])],
            group: 'Back',
            sub: 'Upper Back',
          ),
          _history(
            'Lever T Bar Row',
            [_session(1, [(70, 6)])],
            group: 'Back',
            sub: 'Upper Back',
          ),
          _history(
            'Barbell Full Squat',
            [_session(1, [(140, 3)])],
            group: 'Legs',
            sub: 'Quadriceps',
          ),
          _history(
            'Barbell Deadlift',
            [_session(1, [(180, 2)])],
            group: 'Legs',
            sub: 'Hamstrings',
          ),
          _history(
            'Barbell Seated Overhead Press',
            [_session(1, [(60, 5)])],
            group: 'Shoulders',
            sub: 'Front Delts',
          ),
          _history(
            'Barbell Curl',
            [_session(1, [(40, 8)])],
            group: 'Biceps',
            sub: 'Biceps',
          ),
          _history(
            'Dumbbell Biceps Curl',
            [_session(1, [(20, 8)])],
            group: 'Biceps',
            sub: 'Biceps',
          ),
          _history(
            'Cable Kneeling Crunch',
            [_session(1, [(60, 10)])],
            group: 'Core',
            sub: 'Abs',
          ),
        ];

    test('odemkne se az od 10 rankovanych cviku', () {
      final nine = _report(tenExercises().take(9).toList());
      final ten = _report(tenExercises());

      expect(nine.global, isNull);
      expect(nine.globalUnlockRemaining, 1);
      expect(ten.global, isNotNull);
      expect(ten.globalUnlocked, isTrue);
      expect(ten.globalUnlockRemaining, 0);
    });

    test('global je equal-weight prumer dostupnych skupin', () {
      final report = _report(tenExercises());
      final groups = report.groups.where((g) => g.rank != null).toList();

      expect(groups.length, 6);
      expect(
        report.global!.points,
        closeTo(
          groups.fold<double>(0, (sum, g) => sum + g.rank!.points) /
              groups.length,
          1e-6,
        ),
      );
    });

    test('bez vahy tela se nic nepocita', () {
      final report = buildRankReport(
        history: tenExercises(),
        bodyWeightKg: null,
        now: _now,
      );

      expect(report.global, isNull);
      expect(report.groups, isEmpty);
      expect(report.hasBodyWeight, isFalse);
    });
  });

  group('Standardy', () {
    test('najdou se i s jinou velikosti pismen a mezerami', () {
      expect(rankStandardFor('barbell  bench press'), isNotNull);
      expect(rankStandardFor('BARBELL BENCH PRESS'), isNotNull);
      expect(rankStandardFor('Neznamy cvik'), isNull);
    });

    test('jednorucky maji prahy na jednu cinku', () {
      expect(rankStandardIsPerHand('Dumbbell Bench Press'), isTrue);
      expect(rankStandardIsPerHand('Barbell Bench Press'), isFalse);
    });

    test('Iron a Bronze jsou beginner-friendly', () {
      final scale =
          rankStandardFor('Sled Hack Squat')!.scaleFor(bodyWeightKg: 98);
      final bwScore = math.pow(98, 0.67).toDouble();

      // 60 kg je jeste Iron, 100 kg uz Bronze.
      expect(scale.rankForScore(60 / bwScore).tier, RankTier.iron);
      expect(scale.rankForScore(100 / bwScore).tier, RankTier.bronze);
    });

    test('zenska tabulka da za stejny vykon vyssi rank', () {
      final session = [_session(1, [(60, 5)])];
      final male = _report([_history('Barbell Bench Press', session)]);
      final female = _report(
        [_history('Barbell Bench Press', session)],
        sex: RankSex.female,
      );

      expect(
        _exercise(female, 'Barbell Bench Press').rank.points,
        greaterThan(_exercise(male, 'Barbell Bench Press').rank.points),
      );
    });

    test('vsechny rankovane cviky maji data pro obe pohlavi', () {
      expect(rankStandards.length, greaterThanOrEqualTo(100));
      for (final standard in rankStandards) {
        expect(standard.data.male.length, greaterThanOrEqualTo(5),
            reason: standard.name);
        expect(standard.data.female.length, greaterThanOrEqualTo(5),
            reason: standard.name);

        for (final sex in RankSex.values) {
          for (final bw in [50.0, 80.0, 98.0, 120.0]) {
            final scale = standard.scaleFor(bodyWeightKg: bw, sex: sex);
            expect(scale.thresholds, hasLength(8), reason: standard.name);
            // Strength Level má u nejnižšího řádku některých lehkých cviků
            // Beginner = 0 kg. To je publikovaná hodnota, ne chyba.
            expect(scale.thresholds.every((t) => t >= 0), isTrue,
                reason: '${standard.name} / $sex / $bw');
          }
        }
      }
    });

    test('klicove varianty se nemichaji', () {
      // Barbell hack squat a strojovy hack squat jsou dva ruzne cviky.
      expect(
        rankStandardFor('Barbell Hack Squat')!.name,
        'Barbell Hack Squat',
      );
      expect(rankStandardFor('Sled Hack Squat')!.name, 'Sled Hack Squat');
      expect(
        rankStandardFor('Barbell Hack Squat')!.data.male,
        isNot(rankStandardFor('Sled Hack Squat')!.data.male),
      );

      // Obecny dumbbell curl neni seated varianta.
      expect(rankStandardFor('Dumbbell Biceps Curl')!.name, 'Dumbbell Biceps Curl');
      expect(
        rankStandardFor('Dumbbell Seated Bicep Curl')!.name,
        'Dumbbell Seated Bicep Curl',
      );

      // Kazdy cvik ma vlastni tabulku, ne tabulku souseda.
      final keys = rankStandards.map((s) => s.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('kazdy mapovany cvik existuje v seedu', () {
      final lines = File('supabase/seed.sql').readAsLinesSync();
      final start = lines.indexWhere(
        (l) => l.contains('with data(muscle, sub, name, type, equipment'),
      );
      expect(start, greaterThanOrEqualTo(0), reason: 'chybi blok katalogu');
      final end = lines.indexWhere(
        (l) => l.contains('insert into public.exercises'),
        start,
      );
      expect(end, greaterThan(start));

      final rowRe = RegExp(r"^\s*\('([^']*)',\s*'([^']*)',\s*'([^']*)'");
      final names = <String>{};
      for (final line in lines.sublist(start, end)) {
        final match = rowRe.firstMatch(line);
        if (match != null) names.add(rankExerciseKey(match.group(3)!));
      }
      expect(names.length, greaterThan(1000));

      final missing = [
        for (final standard in rankStandards)
          if (!names.contains(standard.key)) standard.name,
      ];
      expect(missing, isEmpty, reason: 'Cviky mimo katalog: $missing');
    });

    test('tabulky jsou monotonni a nikdo nesdili cizi data', () {
      final signatures = <String, String>{};
      for (final standard in rankStandards) {
        for (final rows in [standard.data.male, standard.data.female]) {
          for (var r = 0; r < rows.length; r++) {
            for (var c = 2; c <= 5; c++) {
              expect(rows[r][c], greaterThanOrEqualTo(rows[r][c - 1]),
                  reason: '${standard.name} radek ${rows[r][0]} kg');
            }
            if (r > 0) {
              expect(rows[r][0], greaterThan(rows[r - 1][0]),
                  reason: standard.name);
              for (var c = 1; c <= 5; c++) {
                expect(rows[r][c], greaterThanOrEqualTo(rows[r - 1][c]),
                    reason: '${standard.name} sloupec $c');
              }
            }
          }
        }

        final signature = '${standard.data.male}|${standard.data.female}';
        final other = signatures[signature];
        expect(other, isNull,
            reason: '${standard.name} ma stejna data jako $other');
        signatures[signature] = standard.name;
      }
    });

    test('drive odhadovane stroje maji realna data', () {
      final dip = rankStandardFor('Lever Seated Dip')!;
      final crunch = rankStandardFor('Lever Seated Crunch')!;

      expect(dip.data.male, isNotEmpty);
      expect(dip.data.female, isNotEmpty);
      expect(crunch.data.male, isNotEmpty);
      expect(crunch.data.female, isNotEmpty);

      // Aliasy na nazvy ze Strength Levelu miri na stejny standard.
      expect(rankStandardFor('Seated Dip Machine')?.name, 'Lever Seated Dip');
      expect(
        rankStandardFor('Machine Seated Crunch')?.name,
        'Lever Seated Crunch',
      );
    });
  });
}
