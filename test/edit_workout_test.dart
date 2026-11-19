import 'package:alphalift/core/theme.dart';
import 'package:alphalift/features/home/home_repository.dart';
import 'package:alphalift/features/workout/edit_workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemoryAsyncStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }
}

const _workoutId = 'workout-1';

final _detail = WorkoutDetail(
  workoutId: _workoutId,
  title: 'Push day',
  createdAt: DateTime(2026, 11, 16, 18, 30),
  durationSeconds: 45 * 60,
  username: 'tester',
  profilePhotoUrl: null,
  userId: 'user-1',
  exercises: const [
    WorkoutDetailExercise(
      orderIndex: 0,
      exerciseId: 'exercise-1',
      name: 'Bench Press',
      exerciseType: 'weight_reps',
      muscleGroup: 'Chest',
      subMuscleGroup: 'Mid Chest',
      equipment: 'barbell',
      gifUrl: null,
      sets: [
        WorkoutSetDetail(
          setNumber: 1,
          weightKg: 20,
          repsCount: 10,
          durationSeconds: null,
          distanceMeters: null,
          setType: 'normal',
          isCompleted: true,
        ),
      ],
    ),
  ],
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _MemoryAsyncStorage(),
      ),
    );
  });

  testWidgets('edit screen loads saved workout values', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider.overrideWith((ref, id) async => _detail),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const EditWorkoutScreen(workoutId: _workoutId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit workout'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields, hasLength(3));
    expect(fields[0].controller!.text, 'Push day');
    expect(fields[1].controller!.text, '20');
    expect(fields[2].controller!.text, '10');

    // Zmena vahy se hned propise do lokalniho modelu.
    await tester.enterText(find.byType(TextField).at(1), '32.5');
    await tester.pump();
    final updated = tester
        .widgetList<TextField>(find.byType(TextField))
        .elementAt(1);
    expect(updated.controller!.text, '32.5');
  });
}
