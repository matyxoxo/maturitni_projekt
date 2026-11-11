import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
//  Zakladni data profilu
// ============================================================

/// Data profilu prihlaseneho uzivatele + zakladni statistiky.
class ProfileData {
  const ProfileData({
    required this.username,
    required this.email,
    required this.bodyWeightKg,
    required this.profilePhotoUrl,
    required this.fullName,
    required this.memberSince,
    required this.workoutCount,
    required this.totalVolumeKg,
    required this.avgDurationSeconds,
    required this.lastWorkoutAt,
  });

  final String username;
  final String email;
  final double? bodyWeightKg;
  final String? profilePhotoUrl;
  final String? fullName;
  final DateTime memberSince;
  final int workoutCount;
  final double totalVolumeKg;
  final int? avgDurationSeconds;
  final DateTime? lastWorkoutAt;
}

/// Profil + statistiky prihlaseneho uzivatele.
///
/// Objem se pocita v Dartu z workout_sets (v DB neni ulozeny).
final profileProvider = FutureProvider<ProfileData>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw Exception('Not signed in.');

  final userRow = await client
      .from('users')
      .select(
        'username, email, body_weight_kg, profile_photo_url, full_name, created_at',
      )
      .eq('id', userId)
      .single();

  final workoutRows = await client
      .from('workouts')
      .select('''
        created_at, duration_seconds,
        workout_exercises (
          workout_sets (weight_kg, reps_count)
        )
      ''')
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  var volume = 0.0;
  var durationSum = 0;
  var durationCount = 0;
  for (final row in workoutRows) {
    final duration = row['duration_seconds'] as int?;
    if (duration != null) {
      durationSum += duration;
      durationCount++;
    }
    for (final ex in (row['workout_exercises'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()) {
      for (final set in (ex['workout_sets'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()) {
        volume += ((set['weight_kg'] as num?)?.toDouble() ?? 0) *
            (set['reps_count'] as int? ?? 0);
      }
    }
  }

  return ProfileData(
    username: userRow['username'] as String,
    email: userRow['email'] as String,
    bodyWeightKg: (userRow['body_weight_kg'] as num?)?.toDouble(),
    profilePhotoUrl: userRow['profile_photo_url'] as String?,
    fullName: userRow['full_name'] as String?,
    memberSince: DateTime.parse(userRow['created_at'] as String),
    workoutCount: workoutRows.length,
    totalVolumeKg: volume,
    avgDurationSeconds:
        durationCount > 0 ? durationSum ~/ durationCount : null,
    lastWorkoutAt: workoutRows.isEmpty
        ? null
        : DateTime.parse(workoutRows.first['created_at'] as String),
  );
});

// ============================================================
//  Historie workoutu (kalendar + graf)
// ============================================================

/// Jeden workout pro kalendar/graf (jen datum a delka).
class WorkoutHistoryEntry {
  const WorkoutHistoryEntry({required this.createdAt, this.durationSeconds});

  final DateTime createdAt;
  final int? durationSeconds;
}

/// Vsechny workouty prihlaseneho uzivatele (lehoucky dotaz – jen datumy).
final workoutHistoryProvider =
    FutureProvider<List<WorkoutHistoryEntry>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  final rows = await Supabase.instance.client
      .from('workouts')
      .select('created_at, duration_seconds')
      .eq('user_id', userId)
      .order('created_at', ascending: false);
  return rows
      .map((row) => WorkoutHistoryEntry(
            createdAt: DateTime.parse(row['created_at'] as String),
            durationSeconds: row['duration_seconds'] as int?,
          ))
      .toList();
});

/// Hodiny cviceni po tydnech – poslednich [weeks] tydnu (od nejstarsiho).
class WeeklyHours {
  const WeeklyHours({required this.weekStart, required this.hours});

  final DateTime weekStart;
  final double hours;
}

/// Spocita hodiny po tydnech z historie workoutu.
///
/// Tyden zacina v pondeli. Vraci [weeks] polozek od nejstarsiho tydne.
List<WeeklyHours> computeWeeklyHours(
  List<WorkoutHistoryEntry> entries, {
  int weeks = 8,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Pondeli aktualniho tydne.
  final currentWeekStart =
      today.subtract(Duration(days: today.weekday - 1));

  final buckets = <DateTime, double>{};
  for (var i = weeks - 1; i >= 0; i--) {
    final start = currentWeekStart.subtract(Duration(days: 7 * i));
    buckets[start] = 0;
  }

  for (final entry in entries) {
    final day = DateTime(
      entry.createdAt.year,
      entry.createdAt.month,
      entry.createdAt.day,
    );
    final weekStart = day.subtract(Duration(days: day.weekday - 1));
    if (buckets.containsKey(weekStart)) {
      buckets[weekStart] =
          buckets[weekStart]! + (entry.durationSeconds ?? 0) / 3600;
    }
  }

  return [
    for (final start in buckets.keys.toList()..sort((a, b) => a.compareTo(b)))
      WeeklyHours(weekStart: start, hours: buckets[start]!),
  ];
}

/// Pocet workoutu v jednotlivych dnech (klice jsou den v roce).
Map<DateTime, int> workoutDayCounts(List<WorkoutHistoryEntry> entries) {
  final counts = <DateTime, int>{};
  for (final entry in entries) {
    final day = DateTime(
      entry.createdAt.year,
      entry.createdAt.month,
      entry.createdAt.day,
    );
    counts[day] = (counts[day] ?? 0) + 1;
  }
  return counts;
}

// ============================================================
//  Follows (pratele)
// ============================================================

/// Pocet followers a following prihlaseneho uzivatele.
class FollowCounts {
  const FollowCounts({required this.followers, required this.following});

  final int followers;
  final int following;
}

final followCountsProvider = FutureProvider<FollowCounts>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const FollowCounts(followers: 0, following: 0);

  final followers = await client
      .from('follows')
      .select('follower_user_id')
      .eq('following_user_id', userId);
  final following = await client
      .from('follows')
      .select('following_user_id')
      .eq('follower_user_id', userId);
  return FollowCounts(
    followers: followers.length,
    following: following.length,
  );
});

/// ID uzivatelu, ktere sleduje prihlaseny uzivatel (pro oznaceni ve vyhledavani).
final myFollowingProvider = FutureProvider<Set<String>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return {};
  final rows = await Supabase.instance.client
      .from('follows')
      .select('following_user_id')
      .eq('follower_user_id', userId);
  return rows
      .map((row) => row['following_user_id'] as String)
      .toSet();
});

/// Sleduje / prestava sledovat uzivatele. Vrati true pri uspechu.
Future<bool> setFollow(String targetUserId, {required bool follow}) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return false;
  try {
    if (follow) {
      await client.from('follows').insert({
        'follower_user_id': userId,
        'following_user_id': targetUserId,
      });
    } else {
      await client
          .from('follows')
          .delete()
          .eq('follower_user_id', userId)
          .eq('following_user_id', targetUserId);
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Uzivatel vyhledavany podle jmena (krome sebe).
final searchUsersProvider =
    FutureProvider.family<List<PublicUser>, String>((ref, query) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];
  final trimmed = query.trim();
  final builder = client
      .from('users')
      .select('id, username, profile_photo_url, full_name')
      .neq('id', userId);
  final filtered = trimmed.isEmpty
      ? builder
      : builder.ilike('username', '%$trimmed%');
  final rows = await filtered.order('username').limit(30);
  return rows.map(PublicUser.fromRow).toList();
});

/// Verejny uzivatel (pro vyhledavani pratel).
class PublicUser {
  const PublicUser({
    required this.id,
    required this.username,
    required this.profilePhotoUrl,
    required this.fullName,
  });

  final String id;
  final String username;
  final String? profilePhotoUrl;
  final String? fullName;

  factory PublicUser.fromRow(Map<String, dynamic> row) {
    return PublicUser(
      id: row['id'] as String,
      username: row['username'] as String,
      profilePhotoUrl: row['profile_photo_url'] as String?,
      fullName: row['full_name'] as String?,
    );
  }
}

// ============================================================
//  Uprava profilu
// ============================================================

/// Ulozi upravene udaje profilu. Vrati chybovou hlasku nebo null pri uspechu.
Future<String?> updateProfile({
  String? username,
  double? bodyWeightKg,
  String? fullName,
  String? profilePhotoUrl,
}) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return 'Not signed in.';

  final updates = <String, dynamic>{};
  if (username != null) updates['username'] = username;
  if (bodyWeightKg != null) updates['body_weight_kg'] = bodyWeightKg;
  if (fullName != null) updates['full_name'] = fullName;
  if (profilePhotoUrl != null) updates['profile_photo_url'] = profilePhotoUrl;
  if (updates.isEmpty) return null;

  try {
    await client.from('users').update(updates).eq('id', userId);
    return null;
  } on PostgrestException catch (e) {
    if (e.code == '23505') return 'This username is already taken.';
    return e.message;
  } catch (_) {
    return 'Could not save changes. Please try again.';
  }
}
