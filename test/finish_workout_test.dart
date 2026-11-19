import 'package:alphalift/core/theme.dart';
import 'package:alphalift/features/workout/active_workout_provider.dart';
import 'package:alphalift/features/workout/finish_workout_screen.dart';
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

/// Controller bez dotazu do DB (testovaci workout je prazdny).
class _FakeWorkoutController extends ActiveWorkoutController {
  @override
  ActiveWorkout build() {
    return ActiveWorkout(startedAt: DateTime.now(), exercises: []);
  }
}

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

  testWidgets('finish screen edits duration', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeWorkoutProvider.overrideWith(_FakeWorkoutController.new),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const FinishWorkoutScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Workout complete'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Started'), findsOneWidget);

    // Duration: otevre sheet a nastavi 30 minut.
    await tester.tap(find.text('Duration'));
    await tester.pumpAndSettle();
    expect(find.text('How long did the workout take?'), findsOneWidget);
    await tester.tap(find.text('30 min').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Set duration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set duration'));
    await tester.pumpAndSettle();
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('How long did the workout take?'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Discard workout'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Save workout'), findsOneWidget);
    expect(find.text('Discard workout'), findsOneWidget);
  });
}
