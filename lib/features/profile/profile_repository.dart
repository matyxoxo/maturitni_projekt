import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
//  Zakladni data profilu
// ============================================================

/// Data profilu uzivatele + zakladni statistiky.
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

/// Profil + statistiky udaneho uzivatele (rodinny – podle userId).
///
/// Objem se pocita v Dartu z workout_sets (v DB neni ulozeny).
/// Prihlaseny uzivatel: `profileProvider(myId)`; invalidace cele rodiny:
/// `ref.invalidate(profileProvider)`.
final profileProvider =
    FutureProvider.family<ProfileData, String>((ref, userId) async {
  final client = Supabase.instance.client;

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

/// Jeden workout pro kalendar/graf (datum, delka, objem a opakovani).
class WorkoutHistoryEntry {
  const WorkoutHistoryEntry({
    required this.createdAt,
    this.durationSeconds,
    this.volumeKg = 0,
    this.reps = 0,
  });

  final DateTime createdAt;
  final int? durationSeconds;
  final double volumeKg;
  final int reps;
}

/// Vsechny workouty udaneho uzivatele (pro kalendar a graf aktivity).
final workoutHistoryProvider =
    FutureProvider.family<List<WorkoutHistoryEntry>, String>(
        (ref, userId) async {
  if (userId.isEmpty) return [];
  final rows = await Supabase.instance.client
      .from('workouts')
      .select('''
        created_at, duration_seconds,
        workout_exercises (
          workout_sets (weight_kg, reps_count)
        )
      ''')
      .eq('user_id', userId)
      .order('created_at', ascending: false);
  return rows.map((row) {
    var volume = 0.0;
    var reps = 0;
    final exercises =
        (row['workout_exercises'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    for (final exercise in exercises) {
      final sets = (exercise['workout_sets'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      for (final set in sets) {
        final setReps = set['reps_count'] as int? ?? 0;
        reps += setReps;
        volume += ((set['weight_kg'] as num?)?.toDouble() ?? 0) * setReps;
      }
    }
    return WorkoutHistoryEntry(
      createdAt: DateTime.parse(row['created_at'] as String),
      durationSeconds: row['duration_seconds'] as int?,
      volumeKg: volume,
      reps: reps,
    );
  }).toList();
});

/// Metrika, kterou umi graf aktivity zobrazit.
enum ActivityMetric { duration, volume, reps }

/// Souhrn jednoho tydne pro graf aktivity.
class WeeklyActivity {
  const WeeklyActivity({
    required this.weekStart,
    required this.durationSeconds,
    required this.volumeKg,
    required this.reps,
  });

  final DateTime weekStart;
  final int durationSeconds;
  final double volumeKg;
  final int reps;

  double value(ActivityMetric metric) {
    switch (metric) {
      case ActivityMetric.duration:
        return durationSeconds / 3600;
      case ActivityMetric.volume:
        return volumeKg;
      case ActivityMetric.reps:
        return reps.toDouble();
    }
  }
}

/// Spocita aktivitu po tydnech (tyden zacina v pondeli).
///
/// Vraci [weeks] polozek od nejstarsiho tydne po ten aktualni.
List<WeeklyActivity> computeWeeklyActivity(
  List<WorkoutHistoryEntry> entries, {
  int weeks = 12,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Pondeli aktualniho tydne.
  final currentWeekStart =
      today.subtract(Duration(days: today.weekday - 1));

  final starts = <DateTime>[
    for (var i = weeks - 1; i >= 0; i--)
      currentWeekStart.subtract(Duration(days: 7 * i)),
  ];
  final durationByWeek = {for (final start in starts) start: 0};
  final volumeByWeek = {for (final start in starts) start: 0.0};
  final repsByWeek = {for (final start in starts) start: 0};

  for (final entry in entries) {
    final day = DateTime(
      entry.createdAt.year,
      entry.createdAt.month,
      entry.createdAt.day,
    );
    final weekStart = day.subtract(Duration(days: day.weekday - 1));
    if (!durationByWeek.containsKey(weekStart)) continue;
    durationByWeek[weekStart] =
        durationByWeek[weekStart]! + (entry.durationSeconds ?? 0);
    volumeByWeek[weekStart] = volumeByWeek[weekStart]! + entry.volumeKg;
    repsByWeek[weekStart] = repsByWeek[weekStart]! + entry.reps;
  }

  return [
    for (final start in starts)
      WeeklyActivity(
        weekStart: start,
        durationSeconds: durationByWeek[start]!,
        volumeKg: volumeByWeek[start]!,
        reps: repsByWeek[start]!,
      ),
  ];
}

/// Souhrn jednoho dne pro graf aktivity.
class DailyActivity {
  const DailyActivity({
    required this.day,
    required this.durationSeconds,
    required this.volumeKg,
    required this.reps,
  });

  final DateTime day;
  final int durationSeconds;
  final double volumeKg;
  final int reps;

  double value(ActivityMetric metric) {
    switch (metric) {
      case ActivityMetric.duration:
        return durationSeconds / 3600;
      case ActivityMetric.volume:
        return volumeKg;
      case ActivityMetric.reps:
        return reps.toDouble();
    }
  }
}

/// Spocita aktivitu po dnech aktualniho tydne (pondeli -> nedele).
List<DailyActivity> computeDailyActivity(List<WorkoutHistoryEntry> entries) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Pondeli aktualniho tydne.
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final days = [
    for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i)),
  ];

  final durationByDay = {for (final day in days) day: 0};
  final volumeByDay = {for (final day in days) day: 0.0};
  final repsByDay = {for (final day in days) day: 0};

  for (final entry in entries) {
    final day = DateTime(
      entry.createdAt.year,
      entry.createdAt.month,
      entry.createdAt.day,
    );
    if (!durationByDay.containsKey(day)) continue;
    durationByDay[day] = durationByDay[day]! + (entry.durationSeconds ?? 0);
    volumeByDay[day] = volumeByDay[day]! + entry.volumeKg;
    repsByDay[day] = repsByDay[day]! + entry.reps;
  }

  return [
    for (final day in days)
      DailyActivity(
        day: day,
        durationSeconds: durationByDay[day]!,
        volumeKg: volumeByDay[day]!,
        reps: repsByDay[day]!,
      ),
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

/// Pocet followers a following udaneho uzivatele.
class FollowCounts {
  const FollowCounts({required this.followers, required this.following});

  final int followers;
  final int following;
}

final followCountsProvider =
    FutureProvider.family<FollowCounts, String>((ref, userId) async {
  final client = Supabase.instance.client;
  if (userId.isEmpty) {
    return const FollowCounts(followers: 0, following: 0);
  }

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

/// Seznam uzivatelu, kteri sleduji daneho uzivatele (followers).
final followersListProvider =
    FutureProvider.family<List<PublicUser>, String>((ref, userId) async {
  final client = Supabase.instance.client;
  if (userId.isEmpty) return [];
  final rows = await client
      .from('follows')
      .select('follower_user_id')
      .eq('following_user_id', userId);
  final ids = [
    for (final row in rows) row['follower_user_id'] as String,
  ];
  if (ids.isEmpty) return [];
  final users = await client
      .from('users')
      .select('id, username, profile_photo_url, full_name')
      .inFilter('id', ids)
      .order('username');
  return users.map(PublicUser.fromRow).toList();
});

/// Seznam uzivatelu, ktere dany uzivatel sleduje (following).
final followingListProvider =
    FutureProvider.family<List<PublicUser>, String>((ref, userId) async {
  final client = Supabase.instance.client;
  if (userId.isEmpty) return [];
  final rows = await client
      .from('follows')
      .select('following_user_id')
      .eq('follower_user_id', userId);
  final ids = [
    for (final row in rows) row['following_user_id'] as String,
  ];
  if (ids.isEmpty) return [];
  final users = await client
      .from('users')
      .select('id, username, profile_photo_url, full_name')
      .inFilter('id', ids)
      .order('username');
  return users.map(PublicUser.fromRow).toList();
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
