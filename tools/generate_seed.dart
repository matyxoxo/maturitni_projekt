// Generuje supabase/seed.sql z datasetu hasaneyldrm/exercises-dataset.
// Spustit: dart run tools/generate_seed.dart
import 'dart:convert';
import 'dart:io';

const datasetDir =
    r'C:\Users\matej\AppData\Local\Temp\opencode\exercises-dataset';
const supabaseUrl = 'https://ydgofprtqohzhjfwjtqq.supabase.co';
const bucket = 'exercise-gifs';
const outPath = r'C:\Users\matej\skola\alphalift\supabase\seed.sql';

const muscleGroups = <String, List<String>>{
  'Chest': ['Upper Chest', 'Middle Chest', 'Lower Chest'],
  'Back': ['Lats', 'Upper Back', 'Traps', 'Lower Back'],
  'Legs': [
    'Quadriceps',
    'Hamstrings',
    'Calves',
    'Glutes',
    'Adductors',
    'Abductors',
  ],
  'Shoulders': ['Front Delts', 'Side Delts', 'Rear Delts'],
  'Biceps': ['Biceps'],
  'Triceps': ['Triceps'],
  'Core': ['Abs', 'Obliques'],
  'Forearms': ['Forearms'],
  'Neck': ['Neck'],
  'Cardio': ['Steady State'],
};

String esc(String s) => s.replaceAll("'", "''");

(String, String)? mapExercise(Map<String, dynamic> ex) {
  final target = (ex['target'] ?? '').toString().toLowerCase();
  final muscleGroup = (ex['muscle_group'] ?? '').toString().toLowerCase();
  final name = (ex['name'] ?? '').toString().toLowerCase();
  final category = (ex['category'] ?? '').toString().toLowerCase();

  switch (target) {
    case 'abs':
      final oblique = muscleGroup.contains('oblique') ||
          RegExp(
                  r'oblique|side bend|woodchop|wood chop|russian twist|side crunch|heel touch|side plank')
              .hasMatch(name);
      return ('Core', oblique ? 'Obliques' : 'Abs');
    case 'pectorals':
      if (name.contains('incline')) return ('Chest', 'Upper Chest');
      if (name.contains('decline')) return ('Chest', 'Lower Chest');
      return ('Chest', 'Middle Chest');
    case 'biceps':
      return ('Biceps', 'Biceps');
    case 'triceps':
      return ('Triceps', 'Triceps');
    case 'glutes':
      return ('Legs', 'Glutes');
    case 'delts':
      if (RegExp(r'rear|reverse|face pull').hasMatch(name)) {
        return ('Shoulders', 'Rear Delts');
      }
      if (RegExp(r'front raise|overhead press|arnold|mil press|military press')
          .hasMatch(name)) {
        return ('Shoulders', 'Front Delts');
      }
      return ('Shoulders', 'Side Delts');
    case 'upper back':
    case 'serratus anterior':
      return ('Back', 'Upper Back');
    case 'lats':
      return ('Back', 'Lats');
    case 'traps':
      return ('Back', 'Traps');
    case 'spine':
      return ('Back', 'Lower Back');
    case 'quads':
      return ('Legs', 'Quadriceps');
    case 'hamstrings':
      return ('Legs', 'Hamstrings');
    case 'calves':
      return ('Legs', 'Calves');
    case 'adductors':
      return ('Legs', 'Adductors');
    case 'abductors':
      return ('Legs', 'Abductors');
    case 'forearms':
      return ('Forearms', 'Forearms');
    case 'levator scapulae':
      return ('Neck', 'Neck');
    case 'cardiovascular system':
      return ('Cardio', 'Steady State');
  }
  // fallback podle category
  if (category == 'cardio') return ('Cardio', 'Steady State');
  if (category == 'neck') return ('Neck', 'Neck');
  if (category == 'lower arms') return ('Forearms', 'Forearms');
  return null;
}

String mapType(Map<String, dynamic> ex) {
  final target = (ex['target'] ?? '').toString().toLowerCase();
  final category = (ex['category'] ?? '').toString().toLowerCase();
  final name = (ex['name'] ?? '').toString().toLowerCase();
  final equipment = (ex['equipment'] ?? '').toString().toLowerCase();

  if (category == 'cardio' || target == 'cardiovascular system') {
    return 'distance_duration';
  }
  if (RegExp(
          r'\bplank\b|body saw|l-sit|v-sit|dead hang|hold\b|bar hang|support hold')
      .hasMatch(name)) {
    return 'duration';
  }
  if (equipment == 'weighted') return 'weighted_bodyweight';
  if (equipment == 'assisted') return 'assisted_bodyweight';
  if (equipment == 'body weight') return 'bodyweight_reps';
  return 'weight_reps';
}

String titleCaseEquipment(String s) {
  if (s.isEmpty) return 'None';
  return s
      .split(' ')
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

String titleCaseName(String s) {
  final keep = {'and', 'or', 'to', 'of', 'in', 'with', 'on', 'the'};
  var i = 0;
  return s.split(' ').map((w) {
    if (w.isEmpty) return w;
    // zachovat zkratky typu 45°, 3/4 na zacatku
    if (RegExp(r'^\d').hasMatch(w)) return w;
    final lower = w.toLowerCase();
    if (i++ > 0 && keep.contains(lower)) return lower;
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
}

void main() {
  final jsonFile = File('$datasetDir${Platform.pathSeparator}data'
      '${Platform.pathSeparator}exercises.json');
  final list = jsonDecode(jsonFile.readAsStringSync()) as List<dynamic>;

  final sb = StringBuffer();
  sb.writeln('-- ============================================================');
  sb.writeln('-- AlphaLift - seed dat (generovano z hasaneyldrm/exercises-dataset)');
  sb.writeln('-- 1324 cviku s GIF animacemi. Spustit PO 0001_init.sql');
  sb.writeln('-- ============================================================');
  sb.writeln();
  sb.writeln('-- ---------- SVALOVE SKUPINY ----------');
  sb.writeln();
  sb.writeln('with data(name) as (');
  sb.writeln('  values');
  final groupNames = muscleGroups.keys.toList();
  for (var i = 0; i < groupNames.length; i++) {
    final comma = i == groupNames.length - 1 ? '' : ',';
    sb.writeln("    ('${esc(groupNames[i])}')$comma");
  }
  sb.writeln(')');
  sb.writeln('insert into public.muscle_groups (muscle_group_name)');
  sb.writeln('select name from data;');
  sb.writeln();
  sb.writeln('-- ---------- SVALOVE PODSKUPINY ----------');
  sb.writeln();
  sb.writeln('with data(muscle, sub) as (');
  sb.writeln('  values');
  final subRows = <String>[];
  muscleGroups.forEach((group, subs) {
    for (final sub in subs) {
      subRows.add("    ('${esc(group)}', '${esc(sub)}')");
    }
  });
  sb.writeln(subRows.join(',\n'));
  sb.writeln(')');
  sb.writeln('insert into public.sub_muscle_groups (muscle_group_id, sub_muscle_name)');
  sb.writeln('select mg.muscle_group_id, d.sub');
  sb.writeln('from data d');
  sb.writeln('join public.muscle_groups mg on mg.muscle_group_name = d.muscle;');
  sb.writeln();
  sb.writeln('-- ---------- KATALOG CVIKU (1324) ----------');
  sb.writeln();

  var unmapped = 0;
  final rows = <String>[];
  for (final raw in list) {
    final ex = raw as Map<String, dynamic>;
    final mapped = mapExercise(ex);
    if (mapped == null) {
      unmapped++;
      stderr.writeln('NEMAPUJE: ${ex['name']} | target=${ex['target']} '
          '| category=${ex['category']}');
      continue;
    }
    final (group, sub) = mapped;
    final name = titleCaseName((ex['name'] ?? '').toString());
    final type = mapType(ex);
    final equipment =
        titleCaseEquipment((ex['equipment'] ?? '').toString());
    final gifFile =
        (ex['gif_url'] ?? '').toString().split('/').last;
    final gifUrl = '$supabaseUrl/storage/v1/object/public/$bucket/$gifFile';
    rows.add("  ('${esc(group)}', '${esc(sub)}', '${esc(name)}', "
        "'$type', '${esc(equipment)}', '${esc(gifUrl)}')");
  }

  sb.writeln('with data(muscle, sub, name, type, equipment, gif_url) as (');
  sb.writeln('  values');
  sb.writeln(rows.join(',\n'));
  sb.writeln(')');
  sb.writeln('insert into public.exercises '
      '(sub_muscle_id, exercise_name, exercise_type, equipment, '
      'exercise_icon_url)');
  sb.writeln('select sg.sub_muscle_id, d.name, d.type, d.equipment, d.gif_url');
  sb.writeln('from data d');
  sb.writeln('join public.sub_muscle_groups sg on sg.sub_muscle_name = d.sub');
  sb.writeln('join public.muscle_groups mg');
  sb.writeln('  on mg.muscle_group_id = sg.muscle_group_id');
  sb.writeln('  and mg.muscle_group_name = d.muscle;');
  sb.writeln();
  sb.writeln('-- Pocet cviku: ${rows.length} (nemapovanych: $unmapped)');

  File(outPath).writeAsStringSync(sb.toString());
  stdout.writeln('Hotovo: $outPath (${rows.length} cviku, '
      '$unmapped nemapovanych)');
}
