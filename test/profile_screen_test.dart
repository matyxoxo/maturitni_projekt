import 'package:alphalift/core/theme.dart';
import 'package:alphalift/features/home/feed_repository.dart';
import 'package:alphalift/features/profile/profile_repository.dart';
import 'package:alphalift/features/profile/profile_screen.dart';
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

  testWidgets('public profile renders header and workouts section',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(
            (ref, id) async => ProfileData(
              username: 'friend',
              email: 'friend@example.com',
              bodyWeightKg: 80,
              profilePhotoUrl: null,
              fullName: 'Friend Name',
              memberSince: DateTime(2025, 1, 1),
              workoutCount: 3,
              totalVolumeKg: 1200,
              avgDurationSeconds: 3600,
              lastWorkoutAt: DateTime(2025, 2, 1),
            ),
          ),
          followCountsProvider.overrideWith(
            (ref, id) async => const FollowCounts(followers: 2, following: 3),
          ),
          workoutHistoryProvider.overrideWith(
            (ref, id) async => [
              WorkoutHistoryEntry(
                createdAt: DateTime(2025, 2, 1),
                durationSeconds: 3600,
              ),
            ],
          ),
          userFeedProvider.overrideWith(
            (ref, id) async => <FeedWorkout>[],
          ),
          myFollowingProvider.overrideWith((ref) async => <String>{}),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const ProfileScreen(userId: 'other-user-id'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Friend Name'), findsOneWidget);
    expect(find.text('@friend'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('No workouts yet.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Recent workouts'), findsOneWidget);
    expect(find.text('No workouts yet.'), findsOneWidget);
  });
}
