import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_repository.dart';

// ============================================================
//  Feed: moje workouty + sledovani (razeno podle data)
// ============================================================

/// Jeden workout v feedu (moje i od pratel) vc. lajku a komentaru.
class FeedWorkout {
  const FeedWorkout({
    required this.workoutId,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.durationSeconds,
    required this.totalVolumeKg,
    required this.username,
    required this.profilePhotoUrl,
    required this.exercises,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
  });

  final String workoutId;
  final String userId;
  final String title;
  final DateTime createdAt;
  final int? durationSeconds;

  /// Vypocteno v Dartu z workout_sets (neni ulozeno v DB).
  final double totalVolumeKg;
  final String username;
  final String? profilePhotoUrl;
  final List<WorkoutExerciseBrief> exercises;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  bool isMine(String? myId) => myId != null && userId == myId;

  factory FeedWorkout.fromRow(Map<String, dynamic> row, String myId) {
    final user = row['users'] as Map<String, dynamic>?;
    final exerciseRows =
        (row['workout_exercises'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
          ..sort((a, b) =>
              (a['order_index'] as int? ?? 0)
                  .compareTo(b['order_index'] as int? ?? 0));
    final exercises = <WorkoutExerciseBrief>[];
    var volume = 0.0;
    for (final ex in exerciseRows) {
      if (ex['exercises'] != null) {
        exercises.add(
          WorkoutExerciseBrief(
            exerciseId: ex['exercises']['exercise_id'] as String,
            name: ex['exercises']['exercise_name'] as String,
            gifUrl: ex['exercises']['exercise_icon_url'] as String?,
          ),
        );
      }
      for (final set
          in (ex['workout_sets'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>()) {
        final weight = (set['weight_kg'] as num?)?.toDouble() ?? 0;
        final reps = set['reps_count'] as int? ?? 0;
        volume += weight * reps;
      }
    }

    final likes = (row['workout_likes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final comments =
        (row['workout_comments'] as List<dynamic>? ?? []).length;

    return FeedWorkout(
      workoutId: row['workout_id'] as String,
      userId: row['user_id'] as String,
      title: row['workout_title'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      durationSeconds: row['duration_seconds'] as int?,
      totalVolumeKg: volume,
      username: user?['username'] as String? ?? 'Unknown',
      profilePhotoUrl: user?['profile_photo_url'] as String?,
      exercises: exercises,
      likeCount: likes.length,
      commentCount: comments,
      likedByMe: likes.any((like) => like['user_id'] == myId),
    );
  }
}

const _feedSelect = '''
      workout_id, workout_title, created_at, duration_seconds, user_id,
      users (username, profile_photo_url),
      workout_exercises (
        order_index,
        exercises (exercise_id, exercise_name, exercise_icon_url),
        workout_sets (weight_kg, reps_count)
      ),
      workout_likes (user_id),
      workout_comments (comment_id)
    ''';

/// Sjednoceny feed: moje workouty + lide, ktere sleduji,
/// razeno od nejnovejsiho. Poslednich 50.
final feedProvider = FutureProvider<List<FeedWorkout>>((ref) async {
  final client = Supabase.instance.client;
  final myId = client.auth.currentUser?.id;
  if (myId == null) return [];

  final followingRows = await client
      .from('follows')
      .select('following_user_id')
      .eq('follower_user_id', myId);
  final userIds = <String>{
    myId,
    for (final row in followingRows)
      row['following_user_id'] as String,
  };

  final rows = await client
      .from('workouts')
      .select(_feedSelect)
      .inFilter('user_id', userIds.toList())
      .order('created_at', ascending: false)
      .limit(50);
  return rows.map((row) => FeedWorkout.fromRow(row, myId)).toList();
});

/// Workouty jednoho uzivatele (karty na jeho profilu).
final userFeedProvider =
    FutureProvider.family<List<FeedWorkout>, String>((ref, userId) async {
  final myId = Supabase.instance.client.auth.currentUser?.id;
  if (myId == null || userId.isEmpty) return [];
  final rows = await Supabase.instance.client
      .from('workouts')
      .select(_feedSelect)
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(50);
  return rows.map((row) => FeedWorkout.fromRow(row, myId)).toList();
});

// ============================================================
//  Lajky (optimistic stav)
// ============================================================

/// Optimistic prekryti stavu lajku: workoutId -> liked.
///
/// Kdyz je v mapce polozka, prebiji `likedByMe` z feedu (okamzita
/// reakce bez cekani na server).
class LikeOverridesNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {};

  void set(String workoutId, bool liked) {
    state = {...state, workoutId: liked};
  }

  void rollback(String workoutId, bool previous) {
    state = {...state, workoutId: previous};
  }
}

final likeOverridesProvider =
    NotifierProvider<LikeOverridesNotifier, Map<String, bool>>(
  LikeOverridesNotifier.new,
);

/// Stav lajku pro zobrazeni (override ?? server).
bool resolveLiked(Map<String, bool> overrides, FeedWorkout workout) =>
    overrides[workout.workoutId] ?? workout.likedByMe;

/// Pocet lajku pro zobrazeni s ohledem na optimistic prekryti.
int resolveLikeCount(
  Map<String, bool> overrides,
  FeedWorkout workout,
) {
  final nowLiked = resolveLiked(overrides, workout);
  return workout.likeCount -
      (workout.likedByMe ? 1 : 0) +
      (nowLiked ? 1 : 0);
}

/// Zapne / vypne lajk. Vrati true pri uspechu.
Future<bool> setWorkoutLike(String workoutId, {required bool liked}) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return false;
  try {
    if (liked) {
      await client.from('workout_likes').insert({
        'workout_id': workoutId,
        'user_id': userId,
      });
    } else {
      await client
          .from('workout_likes')
          .delete()
          .eq('workout_id', workoutId)
          .eq('user_id', userId);
    }
    return true;
  } catch (_) {
    return false;
  }
}

// ============================================================
//  Komentare
// ============================================================

/// Jeden komentar pod workoutem.
class WorkoutComment {
  const WorkoutComment({
    required this.commentId,
    required this.userId,
    required this.username,
    required this.profilePhotoUrl,
    required this.text,
    required this.createdAt,
  });

  final String commentId;
  final String userId;
  final String username;
  final String? profilePhotoUrl;
  final String text;
  final DateTime createdAt;

  factory WorkoutComment.fromRow(Map<String, dynamic> row) {
    final user = row['users'] as Map<String, dynamic>?;
    return WorkoutComment(
      commentId: row['comment_id'] as String,
      userId: row['user_id'] as String,
      username: user?['username'] as String? ?? 'Unknown',
      profilePhotoUrl: user?['profile_photo_url'] as String?,
      text: row['comment_text'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

/// Komentare jednoho workoutu (od nejstarsiho).
final workoutCommentsProvider =
    FutureProvider.family<List<WorkoutComment>, String>((ref, workoutId) async {
  final rows = await Supabase.instance.client
      .from('workout_comments')
      .select('''
        comment_id, user_id, comment_text, created_at,
        users (username, profile_photo_url)
      ''')
      .eq('workout_id', workoutId)
      .order('created_at', ascending: true);
  return rows.map(WorkoutComment.fromRow).toList();
});

/// Prida komentar. Vrati true pri uspechu.
Future<bool> addWorkoutComment(String workoutId, String text) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  final trimmed = text.trim();
  if (userId == null || trimmed.isEmpty) return false;
  try {
    await client.from('workout_comments').insert({
      'workout_id': workoutId,
      'user_id': userId,
      'comment_text': trimmed,
    });
    return true;
  } catch (_) {
    return false;
  }
}

/// Smaze vlastni komentar. Vrati true pri uspechu.
Future<bool> deleteWorkoutComment(String commentId) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return false;
  try {
    await client
        .from('workout_comments')
        .delete()
        .eq('comment_id', commentId)
        .eq('user_id', userId);
    return true;
  } catch (_) {
    return false;
  }
}

// ============================================================
//  Engagement pro detail workoutu (pocet lajku/komentaru)
// ============================================================

/// Pocet lajku, stav meho lajku a pocet komentaru u workoutu.
class WorkoutEngagement {
  const WorkoutEngagement({
    required this.likeCount,
    required this.likedByMe,
    required this.commentCount,
  });

  final int likeCount;
  final bool likedByMe;
  final int commentCount;
}

/// Lajky + komentare jednoho workoutu.
final workoutEngagementProvider =
    FutureProvider.family<WorkoutEngagement, String>((ref, workoutId) async {
  final client = Supabase.instance.client;
  final myId = client.auth.currentUser?.id;

  final likeRows = await client
      .from('workout_likes')
      .select('user_id')
      .eq('workout_id', workoutId);
  final commentRows = await client
      .from('workout_comments')
      .select('comment_id')
      .eq('workout_id', workoutId);

  return WorkoutEngagement(
    likeCount: likeRows.length,
    likedByMe: myId != null && likeRows.any((row) => row['user_id'] == myId),
    commentCount: commentRows.length,
  );
});

/// Lajky a pocet komentaru pro zobrazeni v detailu
/// (s ohledem na optimistic prekryti lajku).
int resolveEngagementLikeCount(
  Map<String, bool> overrides,
  String workoutId,
  WorkoutEngagement engagement,
) {
  final nowLiked = overrides[workoutId] ?? engagement.likedByMe;
  return engagement.likeCount -
      (engagement.likedByMe ? 1 : 0) +
      (nowLiked ? 1 : 0);
}

bool resolveEngagementLiked(
  Map<String, bool> overrides,
  String workoutId,
  WorkoutEngagement engagement,
) =>
    overrides[workoutId] ?? engagement.likedByMe;
