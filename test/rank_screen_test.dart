import 'package:alphalift/core/theme.dart';
import 'package:alphalift/features/rank/rank_engine.dart';
import 'package:alphalift/features/rank/rank_muscle_screen.dart';
import 'package:alphalift/features/rank/rank_repository.dart';
import 'package:alphalift/features/rank/rank_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 18, 12);

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

RankSessionLog _session(int daysAgo, List<(double, int)> sets) =>
    RankSessionLog(
      date: _now.subtract(Duration(days: daysAgo)),
      sets: [
        for (final (weight, reps) in sets)
          RankSetLog(weightKg: weight, reps: reps),
      ],
    );

List<RankExerciseHistory> _tenExercises() => [
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

Widget _app(RankReport report, {Widget home = const RankScreen()}) =>
    ProviderScope(
      overrides: [
        rankReportProvider.overrideWith((ref) async => report),
      ],
      child: MaterialApp(theme: AppTheme.dark, home: home),
    );

void main() {
  testWidgets('Rank screen shows overall rank and all muscle groups', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final report = buildRankReport(
      history: _tenExercises(),
      bodyWeightKg: 98,
      now: _now,
    );

    await tester.pumpWidget(_app(report));
    await tester.pumpAndSettle();

    expect(find.text('OVERALL RANK'), findsOneWidget);
    expect(find.text(report.global!.label), findsWidgets);
    expect(find.text('Arms'), findsOneWidget);
    expect(find.text('Legs'), findsOneWidget);

    for (final label in [
      'Biceps',
      'Forearms',
      'Quadriceps',
      'Back',
      'Upper Back',
      'Chest',
      'Shoulders',
      'Abs',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'Chybi $label');
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('Rank screen fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final report = buildRankReport(
      history: _tenExercises(),
      bodyWeightKg: 98,
      now: _now,
    );

    await tester.pumpWidget(_app(report));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Rank screen shows the locked state under 10 exercises', (
    tester,
  ) async {
    final report = buildRankReport(
      history: _tenExercises().take(4).toList(),
      bodyWeightKg: 98,
      now: _now,
    );

    await tester.pumpWidget(_app(report));
    await tester.pumpAndSettle();

    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('4 / 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Muscle detail lists each exercise with its rank', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final report = buildRankReport(
      history: _tenExercises(),
      bodyWeightKg: 98,
      now: _now,
    );

    await tester.pumpWidget(
      _app(
        report,
        home: const RankMuscleScreen(
          groupName: 'Chest',
          muscleName: 'Chest',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Smith Bench Press'), findsOneWidget);
    expect(find.text('BEST SET'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
