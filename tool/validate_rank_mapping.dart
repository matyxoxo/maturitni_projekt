// Kontrola kurátorované mapy proti katalogu cviků a metadatům Strength Levelu.
//
// Spuštění: dart run tool/validate_rank_mapping.dart
//
// Očekává `our.tsv` a `sl.json` z `tool/rank_mapping_analysis.dart`
// v dočasném adresáři. Nic nezapisuje, jen hlásí chyby.

import 'dart:convert';
import 'dart:io';

import 'rank_standards_mapping.dart';

String _keyOf(String name) {
  final buffer = StringBuffer();
  for (final rune in name.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    if (RegExp('[a-z0-9]').hasMatch(char)) buffer.write(char);
  }
  return buffer.toString();
}

void main() {
  final dir = Directory(
    '${Platform.environment['TEMP'] ?? '.'}\\opencode\\rankmap',
  );
  final ourLines = File('${dir.path}\\our.tsv')
      .readAsStringSync()
      .split('\n')
      .skip(1);
  final ours = <String, String>{};
  for (final line in ourLines) {
    final parts = line.split('\t');
    if (parts.length >= 5) ours[_keyOf(parts[0])] = parts[3];
  }

  final sl = (jsonDecode(
    File('${dir.path}\\sl.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();
  final bySlug = <String, Map<String, dynamic>>{
    for (final e in sl) e['name_url'] as String: e,
  };

  var errors = 0;
  void error(String message) {
    errors++;
    stdout.writeln('CHYBA  $message');
  }

  final slugCount = <String, int>{};
  for (final mapping in rankMappings) {
    final ourType = ours[_keyOf(mapping.ourName)];
    if (ourType == null) {
      error('${mapping.ourName} není v katalogu');
    } else if (ourType != 'weight_reps') {
      error('${mapping.ourName} má typ $ourType, ne weight_reps');
    }

    final slExercise = bySlug[mapping.slug];
    if (slExercise == null) {
      error('${mapping.ourName}: slug ${mapping.slug} na Strength Levelu není');
      continue;
    }
    slugCount[mapping.slug] = (slugCount[mapping.slug] ?? 0) + 1;

    final isDumbbell = slExercise['category'] == 'Dumbbell';
    if (mapping.perHand != isDumbbell) {
      error(
        '${mapping.ourName}: perHand=${mapping.perHand}, '
        'ale Strength Level kategorie je ${slExercise['category']}',
      );
    }
    final type = slExercise['type'];
    if (type != 'Weight/Reps') {
      error('${mapping.ourName}: Strength Level typ je $type');
    }
  }

  for (final entry in slugCount.entries) {
    if (entry.value > 1) {
      error('Slug ${entry.key} je použitý ${entry.value}×');
    }
  }

  // Alias nesmí kolidovat s jiným naším cvikem.
  final canonical = {
    for (final m in rankMappings) _keyOf(m.ourName): m.ourName,
  };
  for (final mapping in rankMappings) {
    for (final alias in mapping.aliases) {
      final key = _keyOf(alias);
      final other = canonical[key];
      if (other != null && other != mapping.ourName) {
        error('Alias "$alias" u ${mapping.ourName} koliduje s $other');
      }
    }
  }

  stdout.writeln();
  stdout.writeln('Mapování: ${rankMappings.length} cviků');
  stdout.writeln('Unikátních slugů: ${slugCount.length}');
  final weightedSl = sl.where((e) => e['type'] == 'Weight/Reps').toList();
  stdout.writeln(
    'Strength Level cviků celkem: ${sl.length} '
    '(Weight/Reps: ${weightedSl.length})',
  );

  // Pokrytí podle naší svalové skupiny.
  final perMuscle = <String, int>{};
  for (final mapping in rankMappings) {
    final line = ourLines.firstWhere(
      (l) => _keyOf(l.split('\t').first) == _keyOf(mapping.ourName),
      orElse: () => '',
    );
    final muscle = line.isEmpty ? '?' : line.split('\t')[1];
    perMuscle[muscle] = (perMuscle[muscle] ?? 0) + 1;
  }
  stdout.writeln();
  stdout.writeln('Podle svalové skupiny:');
  for (final entry
      in perMuscle.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))) {
    stdout.writeln('  ${entry.key}: ${entry.value}');
  }

  final mappedSlugs = rankMappings.map((m) => m.slug).toSet();
  final unmapped =
      weightedSl
          .where((e) => !mappedSlugs.contains(e['name_url']))
          .map((e) => '${e['name']} [${e['category']}]')
          .toList()
        ..sort();
  stdout.writeln();
  stdout.writeln('Nemapované Weight/Reps cviky (${unmapped.length}):');
  for (final name in unmapped) {
    stdout.writeln('  - $name');
  }
  if (errors == 0) {
    stdout.writeln('Bez chyb.');
  } else {
    stdout.writeln('Chyb: $errors');
    exitCode = 1;
  }
}
