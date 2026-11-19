// Generuje `lib/features/rank/rank_standards_data.dart` z veřejných tabulek
// Strength Level.
//
// Co dělá:
//  1. Vezme kurátorovanou mapu z `tool/rank_standards_mapping.dart`
//     (náš cvik -> slug Strength Levelu).
//  2. Stáhne stránku každého cviku a přečte obě tabulky "By Bodyweight"
//     (kg) – mužskou i ženskou.
//  3. Zapíše je do `rank_standards_data.dart` spolu se seznamem cviků.
//
// Žádné kilogramy se nepíšou ručně. Když se tabulka nedá přečíst, generátor
// spadne – radši žádná data než tichý odhad.
//
// Spuštění: dart run tool/generate_rank_standards.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'rank_standards_mapping.dart';

String _keyOf(String name) {
  final buffer = StringBuffer();
  for (final rune in name.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    if (RegExp('[a-z0-9]').hasMatch(char)) buffer.write(char);
  }
  return buffer.toString();
}

Future<String> _get(String url) async {
  final client = HttpClient()..autoUncompress = true;
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'AlphaLift standards sync',
    );
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} for $url');
    }
    return await response
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();
  } finally {
    client.close();
  }
}

List<List<String>> _rowsOf(String table) {
  final rowRe = RegExp(r'<tr>([\s\S]*?)</tr>');
  final cellRe = RegExp(r'<t[hd][^>]*>([\s\S]*?)</t[hd]>');
  return [
    for (final row in rowRe.allMatches(table))
      [
        for (final cell in cellRe.allMatches(row.group(1)!))
          cell.group(1)!.replaceAll(RegExp('<[^>]+>'), '').trim(),
      ],
  ];
}

/// Najde obě tabulky "By Bodyweight" (muži i ženy) na stránce cviku.
Map<String, List<List<int>>> _parseBodyweightTables(String html) {
  final tableRe = RegExp(r'<table[\s\S]*?<\/table>');
  final result = <String, List<List<int>>>{};

  for (final match in tableRe.allMatches(html)) {
    final rows = _rowsOf(match.group(0)!);
    if (rows.isEmpty || rows.first.length != 6) continue;
    if (rows.first[0] != 'BW') continue;

    // Nejbližší předchozí přepínač pohlaví určuje, čí tabulka to je.
    final before = html.substring(math.max(0, match.start - 2500), match.start);
    final marker = before.lastIndexOf('data-gender="');
    if (marker < 0) {
      throw StateError('Nepodařilo se určit pohlaví tabulky');
    }
    final raw = before.substring(marker + 'data-gender="'.length);
    final gender = raw.startsWith('female') ? 'female' : 'male';

    final parsed = <List<int>>[];
    for (final row in rows.skip(1)) {
      if (row.length != 6) continue;
      final numbers = row.map(int.tryParse).toList();
      if (numbers.any((n) => n == null)) continue;
      parsed.add(numbers.cast<int>());
    }
    parsed.sort((a, b) => a[0].compareTo(b[0]));
    if (parsed.length < 5) {
      throw StateError('Málo řádků pro $gender: ${parsed.length}');
    }
    result[gender] = parsed;
  }

  if (!result.containsKey('male') || !result.containsKey('female')) {
    throw StateError('Chybí mužská nebo ženská tabulka');
  }
  return result;
}

void _writeRows(StringBuffer out, List<List<int>> rows) {
  for (final row in rows) {
    out.writeln('        [${row.join(', ')}],');
  }
}

Future<Map<String, List<List<int>>>> _tablesFor(String slug) async {
  // Disk cache, aby se při ladení nestahovalo pořád dokola.
  final cacheDir = Directory(
    '${Platform.environment['TEMP'] ?? '.'}\\opencode\\rankcache',
  );
  await cacheDir.create(recursive: true);
  final cacheFile = File('${cacheDir.path}\\$slug.html');
  String html;
  if (cacheFile.existsSync()) {
    html = cacheFile.readAsStringSync();
  } else {
    html = await _get('https://strengthlevel.com/strength-standards/$slug/kg');
    await cacheFile.writeAsString(html);
  }
  return _parseBodyweightTables(html);
}

Future<void> main() async {
  // Kontrola duplicit v mapě – jedna naše jména i slugy musí být unikátní.
  final seenNames = <String>{};
  final seenSlugs = <String>{};
  for (final mapping in rankMappings) {
    if (!seenNames.add(_keyOf(mapping.ourName))) {
      throw StateError('Duplicitní náš cvik: ${mapping.ourName}');
    }
    if (!seenSlugs.add(mapping.slug)) {
      throw StateError('Duplicitní slug: ${mapping.slug}');
    }
  }

  final out = StringBuffer()
    ..writeln('// GENEROVANÝ SOUBOR – neupravovat ručně.')
    ..writeln('//')
    ..writeln('// Zdroj: Strength Level, veřejná tabulka "By Bodyweight" (kg).')
    ..writeln('// Na každé stránce cviku jsou zvlášť mužská a ženská tabulka.')
    ..writeln('// Hodnoty jsou publikované kilogramy pro Beginner, Novice,')
    ..writeln(
      '// Intermediate, Advanced a Elite (5., 20., 50., 80. a 95. percentil).',
    )
    ..writeln('//')
    ..writeln('// Regenerace: dart run tool/generate_rank_standards.dart')
    ..writeln()
    ..writeln('/// Tabulka jednoho cviku pro obě pohlaví.')
    ..writeln('///')
    ..writeln('/// Každý řádek: [váha těla kg, Beginner, Novice, Intermediate,')
    ..writeln('/// Advanced, Elite].')
    ..writeln('class RankTableData {')
    ..writeln(
      '  const RankTableData({required this.male, required this.female});',
    )
    ..writeln()
    ..writeln('  final List<List<int>> male;')
    ..writeln('  final List<List<int>> female;')
    ..writeln('}')
    ..writeln()
    ..writeln('/// Jeden rankovaný cvik a jeho předloha na Strength Levelu.')
    ..writeln('class RankStandardEntry {')
    ..writeln('  const RankStandardEntry({')
    ..writeln('    required this.name,')
    ..writeln('    required this.slug,')
    ..writeln('    this.perHand = false,')
    ..writeln('    this.aliases = const [],')
    ..writeln('  });')
    ..writeln()
    ..writeln('  final String name;')
    ..writeln('  final String slug;')
    ..writeln('  final bool perHand;')
    ..writeln('  final List<String> aliases;')
    ..writeln('}')
    ..writeln()
    ..writeln('const Map<String, RankTableData> rankTableData = {');

  for (final mapping in rankMappings) {
    final tables = await _tablesFor(mapping.slug);
    final male = tables['male']!;
    final female = tables['female']!;

    out.writeln("  '${_keyOf(mapping.ourName)}': RankTableData(");
    out.writeln('    male: [');
    _writeRows(out, male);
    out.writeln('    ],');
    out.writeln('    female: [');
    _writeRows(out, female);
    out.writeln('    ],');
    out.writeln('  ),');

    stdout.writeln(
      'OK  ${mapping.ourName} -> ${mapping.slug} '
      '(M ${male.length} řádků, Ž ${female.length} řádků)',
    );
  }

  out.writeln('};');
  out.writeln();
  out.writeln('const List<RankStandardEntry> rankStandardEntries = [');

  for (final mapping in rankMappings) {
    final aliasPart = mapping.aliases.isEmpty
        ? ''
        : ",\n    aliases: [${mapping.aliases.map((a) => "'$a'").join(', ')}]";
    final handPart = mapping.perHand ? ',\n    perHand: true' : '';
    out.writeln(
      "  RankStandardEntry(\n"
      "    name: '${mapping.ourName}',\n"
      "    slug: '${mapping.slug}'$handPart$aliasPart,\n"
      '  ),',
    );
  }

  out.writeln('];');

  final file = File('lib/features/rank/rank_standards_data.dart');
  await file.writeAsString(out.toString());
  stdout.writeln();
  stdout.writeln('Zapsáno ${file.path} (${out.length} znaků)');
  stdout.writeln('Cviků: ${rankMappings.length}');
}
