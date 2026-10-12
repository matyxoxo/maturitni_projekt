import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.exerciseType,
    required this.equipment,
    required this.gifUrl,
    required this.muscleGroup,
    required this.subMuscleGroup,
  });

  final String id;
  final String name;
  final String exerciseType;
  final String? equipment;
  final String? gifUrl;
  final String muscleGroup;
  final String subMuscleGroup;

  factory Exercise.fromRow(Map<String, dynamic> row) {
    final sub = row['sub_muscle_groups'] as Map<String, dynamic>?;
    final group = sub?['muscle_groups'] as Map<String, dynamic>?;
    return Exercise(
      id: row['exercise_id'] as String,
      name: row['exercise_name'] as String,
      exerciseType: row['exercise_type'] as String,
      equipment: row['equipment'] as String?,
      gifUrl: row['exercise_icon_url'] as String?,
      muscleGroup: group?['muscle_group_name'] as String? ?? '',
      subMuscleGroup: sub?['sub_muscle_name'] as String? ?? '',
    );
  }
}

final exercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  const pageSize = 1000;
  final rows = <Map<String, dynamic>>[];
  var from = 0;
  while (true) {
    final batch = await Supabase.instance.client
        .from('exercises')
        .select('''
          exercise_id, exercise_name, exercise_type, equipment,
          exercise_icon_url,
          sub_muscle_groups (sub_muscle_name, muscle_groups (muscle_group_name))
        ''')
        .or('user_id.is.null,user_id.eq.$userId')
        .order('exercise_name')
        .range(from, from + pageSize - 1);
    rows.addAll(batch);
    if (batch.length < pageSize) break;
    from += pageSize;
  }
  return rows.map(Exercise.fromRow).toList();
});

final muscleGroupsProvider = Provider<List<String>>((ref) {
  final exercises = ref.watch(exercisesProvider).value ?? [];
  final groups = exercises.map((e) => e.muscleGroup).toSet().toList()..sort();
  return groups;
});

const _freeWeightEquipment = {
  'barbell', 'dumbbell', 'ez bar', 'ez-bar', 'olympic bar',
  'kettlebell', 'trap bar',
};

int _matchScore(Exercise e, String q) {
  final name = e.name.toLowerCase();
  if (name == q) return 100;
  if (name.startsWith(q)) return 70;
  if (RegExp('\\b${RegExp.escape(q)}').hasMatch(name)) return 60;
  if (name.contains(q)) return 40;
  if (e.subMuscleGroup.toLowerCase().contains(q)) return 30;
  if (e.muscleGroup.toLowerCase().contains(q)) return 30;
  if (e.equipment?.toLowerCase().contains(q) ?? false) return 20;
  if (q.contains(' ')) {
    final haystack = [
      name,
      e.subMuscleGroup.toLowerCase(),
      e.muscleGroup.toLowerCase(),
      e.equipment?.toLowerCase() ?? '',
    ].join(' ');
    final tokens = q.split(RegExp(r'\s+'));
    if (tokens.every(haystack.contains)) return 35;
  }
  return -1;
}

int _freeWeightBonus(Exercise e) {
  final equipment = e.equipment?.toLowerCase() ?? '';
  return _freeWeightEquipment.any(equipment.contains) ? 15 : 0;
}

List<Exercise> filterExercises(
  List<Exercise> exercises, {
  required String query,
  String? muscleGroup,
}) {
  var result = exercises;
  if (muscleGroup != null) {
    result = result.where((e) => e.muscleGroup == muscleGroup).toList();
  }
  if (query.trim().isEmpty) return result;

  final q = query.trim().toLowerCase();
  final scored = <MapEntry<Exercise, int>>[];
  for (final e in result) {
    final score = _matchScore(e, q);
    if (score >= 0) {
      scored.add(MapEntry(e, score + _freeWeightBonus(e)));
    }
  }
  scored.sort((a, b) {
    if (a.value != b.value) return b.value.compareTo(a.value);
    final byLength = a.key.name.length.compareTo(b.key.name.length);
    if (byLength != 0) return byLength;
    return a.key.name.compareTo(b.key.name);
  });
  return scored.map((entry) => entry.key).toList();
}
