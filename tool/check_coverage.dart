// Reads `coverage/lcov.info` and fails when a layer has slipped.
//
// CI ran `flutter test --coverage` and uploaded `lcov.info` as an artifact, and
// **nothing read it**: no threshold, no badge, no diff. A number nobody looks at
// is a number that only ever goes down, and a gate that cannot fail is not a
// gate — which is this project's own argument, made about the stale-l10n check
// that was deleted for exactly that reason.
//
// So either the flag means something or it should go. This is the smallest
// version of meaning something.
//
// **The floors are a ratchet, not a target.** Each sits a few points below what
// the suite actually achieves today, so ordinary work never trips it and a real
// slide does. They are deliberately per layer: `domain/` is pure Dart with no
// framework, so 90% there is a low bar, while `features/` contains screens whose
// last few percent are error branches that need a broken database to reach.
// One blended number would hide a collapse in the first behind the second.
//
// Generated code is excluded and named as such — the localization table and the
// `.g.dart` files are not ours to cover, and including them made the headline
// number 63% while the code somebody wrote was at 79%.
//
// Usage: `dart run tool/check_coverage.dart` (after `flutter test --coverage`).
import 'dart:io';

/// The floor for each layer, and the reason it is where it is.
const floors = <String, ({int percent, String why})>{
  'domain': (
    percent: 90,
    why: 'pure Dart, no framework, no I/O — every fold, roll-up and predictor '
        'here is testable in milliseconds, so anything uncovered is a choice',
  ),
  'application': (
    percent: 85,
    why: 'the providers and services; a little of it is wiring that only a '
        'widget test reaches',
  ),
  'core': (percent: 85, why: 'day arithmetic, parsing, breakpoints — all pure'),
  'data': (
    percent: 70,
    why: 'hand-written repository code only; the migrations inside it run only '
        'against an old schema, which the schema tests do reach but not '
        'exhaustively',
  ),
  'features': (
    percent: 65,
    why: 'screens. The last few percent are error branches that need a broken '
        'database to reach, and are covered where it is worth building one',
  ),
};

/// The whole of the hand-written app.
const totalFloor = 75;

bool isGenerated(String path) =>
    path.endsWith('.g.dart') || path.contains('/l10n/generated/');

void main() {
  final lcov = File('coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln('coverage/lcov.info is missing — run '
        '`flutter test --coverage` first.');
    exit(1);
  }

  final byFile = <String, ({int hit, int found})>{};
  var current = '';
  var hit = 0;
  var found = 0;
  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3).replaceAll(r'\', '/');
      hit = 0;
      found = 0;
    } else if (line.startsWith('DA:')) {
      found++;
      if (int.parse(line.split(',').last) > 0) hit++;
    } else if (line.trim() == 'end_of_record') {
      byFile[current] = (hit: hit, found: found);
    }
  }
  if (byFile.isEmpty) {
    stderr.writeln('coverage/lcov.info has no records — the run produced '
        'nothing, which is not the same as everything being covered.');
    exit(1);
  }

  final groups = <String, ({int hit, int found})>{};
  var totalHit = 0;
  var totalFound = 0;
  for (final entry in byFile.entries) {
    if (isGenerated(entry.key)) continue;
    final layer =
        RegExp(r'lib/(\w+)/').firstMatch(entry.key)?.group(1) ?? 'lib';
    final g = groups[layer] ?? (hit: 0, found: 0);
    groups[layer] =
        (hit: g.hit + entry.value.hit, found: g.found + entry.value.found);
    totalHit += entry.value.hit;
    totalFound += entry.value.found;
  }

  String pct(int hit, int found) =>
      found == 0 ? '  n/a' : '${(100 * hit / found).toStringAsFixed(1)}%';

  final failures = <String>[];
  stdout.writeln('Coverage of hand-written lib/ '
      '(generated code excluded):');
  for (final layer in groups.keys.toList()..sort()) {
    final g = groups[layer]!;
    final floor = floors[layer];
    final percent = g.found == 0 ? 100.0 : 100 * g.hit / g.found;
    final mark = floor == null
        ? '        '
        : (percent >= floor.percent ? '  ok    ' : '  BELOW ');
    stdout.writeln('  ${layer.padRight(12)} ${pct(g.hit, g.found).padLeft(6)}'
        '$mark${floor == null ? '' : 'floor ${floor.percent}%'}'
        '  (${g.hit}/${g.found})');
    if (floor != null && percent < floor.percent) {
      failures.add('$layer is ${percent.toStringAsFixed(1)}%, below its '
          '${floor.percent}% floor — ${floor.why}');
    }
  }
  final totalPercent = 100 * totalHit / totalFound;
  stdout.writeln('  ${'TOTAL'.padRight(12)} '
      '${pct(totalHit, totalFound).padLeft(6)}'
      '${totalPercent >= totalFloor ? '  ok    ' : '  BELOW '}'
      'floor $totalFloor%  ($totalHit/$totalFound)');
  if (totalPercent < totalFloor) {
    failures.add('the whole of hand-written lib/ is '
        '${totalPercent.toStringAsFixed(1)}%, below its $totalFloor% floor');
  }

  // The least-covered files, always — the number is only useful if it points
  // somewhere. This is printed on success too, because a gate that speaks only
  // when it fails is one nobody learns anything from.
  final ranked = byFile.entries
      .where((e) => !isGenerated(e.key) && e.value.found >= 25)
      .toList()
    ..sort((a, b) => (a.value.hit / a.value.found)
        .compareTo(b.value.hit / b.value.found));
  stdout.writeln('\nLeast covered files with more than 25 lines:');
  for (final e in ranked.take(5)) {
    stdout.writeln('  ${pct(e.value.hit, e.value.found).padLeft(6)}  ${e.key}');
  }

  if (failures.isEmpty) {
    stdout.writeln('\nCoverage floors held.');
    return;
  }
  stderr.writeln('\n::error::Coverage has slipped.');
  for (final f in failures) {
    stderr.writeln('  - $f');
  }
  stderr.writeln('\nThe floors are in tool/check_coverage.dart, each with the '
      'reason it is where it is. Lowering one is a decision; make it '
      'deliberately, in that file, with the reason updated.');
  exit(1);
}
