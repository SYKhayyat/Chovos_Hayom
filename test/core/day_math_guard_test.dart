import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/source_scan.dart';

/// The rule this file enforces: **`lib/core/day.dart` is the only place in the
/// app that does calendar-day arithmetic.**
///
/// That rule was already true in prose. Four files carried a byte-identical
/// private `_dayNumber`, each with a comment explaining why the shared day
/// ordinal mattered, and one of them said outright that it was "the same key
/// `PaceEngine` and `ChazaraSchedule` use" — and then wrote a fourth copy
/// anyway. A comment cannot fail CI, so it does not stop the fifth.
///
/// This does. It reads `lib/` and rejects the four shapes that a day-math copy
/// is written in, because each of them is either the old convention or a way of
/// getting the day count wrong:
///
/// * `86400000` — the whole-day ordinal, computed by hand.
/// * `.difference(…).inDays` — a `Duration` truncated to days. The
///   spring-forward day is 23 hours long, so it reads as zero.
/// * `DateTime(x.year, x.month, x.day)` — a local midnight, by hand. It is the
///   representation `Day` deliberately does not store, for the two reasons
///   above and below.
/// * `Duration(days: n)` — stepping a date by elapsed time. Adding 24 hours to
///   a local midnight lands on 01:00 or 23:00 twice a year.
///
/// **It is a speed bump, not a wall.** A line that genuinely needs one of these
/// says so with a trailing `// day-math: ok — <reason>` and is skipped. The
/// point is that the next copy has to be argued for, not merely typed.
void main() {
  /// Each ban, and a sample of the shape it must catch — so the guard cannot
  /// rot into a regex that no longer matches anything, which is the failure
  /// mode of every source-scanning check ever written.
  const bans = <({String why, String pattern, String sample})>[
    (
      why: 'computes a day ordinal by hand — use Day.of()',
      pattern: r'86400000',
      sample: 'DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch '
          '~/ 86400000;',
    ),
    (
      why: 'takes a day count from a Duration, which truncates a 23-hour '
          'day to zero — use Day.difference()',
      pattern: r'\.difference\([^)]*\)\.inDays',
      sample: 'final days = b.difference(a).inDays;',
    ),
    (
      why: 'truncates a DateTime to local midnight by hand — use Day.of(), '
          'and Day.midnight only where a DateTime has to leave',
      pattern: r'DateTime\(\s*\w+\.year\s*,\s*\w+\.month\s*,\s*\w+\.day\s*\)',
      sample: 'final today = DateTime(now.year, now.month, now.day);',
    ),
    (
      why: 'steps a date by elapsed time, which shifts by an hour across a '
          'DST boundary — use Day + n',
      pattern: r'Duration\(\s*days:',
      sample: 'from.add(const Duration(days: 180))',
    ),
  ];

  /// `day.dart` is where all four shapes are *supposed* to live.
  const home = 'lib/core/day.dart';

  /// Comments are stripped before matching, so the doc comments that explain
  /// these bans — including the ones in this file's own subject matter — do not
  /// trip them. The escape-hatch marker is read from the raw line first.
  const escapeHatch = 'day-math: ok';

  test('the regexes actually match the shapes they ban', () {
    for (final ban in bans) {
      expect(RegExp(ban.pattern).hasMatch(ban.sample), isTrue,
          reason: 'the pattern for "${ban.why}" no longer matches its own '
              'sample, so it is guarding nothing');
    }
  });

  test('comments and the escape hatch are not scanned', () {
    final scanned = codeLines('''
/// A doc comment mentioning Duration(days: 1).
// A line comment mentioning 86400000.
/* A block
   comment mentioning b.difference(a).inDays. */
final ok = DateTime(x.year, x.month, x.day); // day-math: ok — deliberate
final real = 86400000;
''', escapeHatch: escapeHatch);
    expect(scanned, hasLength(1));
    expect(scanned.single.text, contains('final real'));
  });

  test('lib/ does calendar-day arithmetic in exactly one place', () {
    final violations = <String>[];

    for (final path in dartSourcesUnder()) {
      if (path.endsWith(home)) continue;

      for (final line
          in codeLines(File(path).readAsStringSync(), escapeHatch: escapeHatch)) {
        for (final ban in bans) {
          if (!RegExp(ban.pattern).hasMatch(line.text)) continue;
          violations.add('$path:${line.line} ${ban.why}\n'
              '    ${line.text.trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Calendar-day arithmetic belongs in lib/core/day.dart and '
          'nowhere else.\n\n${violations.join('\n')}\n\n'
          'If a line genuinely needs the raw form, mark it '
          '`// $escapeHatch — <reason>`.',
    );
  });
}
