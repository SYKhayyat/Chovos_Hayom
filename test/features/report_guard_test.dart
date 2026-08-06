import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The rules this file enforces, because the last time they were only stated
/// they were broken within a month:
///
/// 1. **A report section is a body, not a screen.** The five sections under
///    `lib/features/reports/` share one `Scaffold`, one `AppBar` and one tab
///    controller, which live in `report_screen.dart`. A section that grows its
///    own `Scaffold` has quietly become a route again, and the drawer row and
///    the `DpadScroll` copy follow it back.
///
/// 2. **A goal is rendered in one place.** The unit grid's banner and the Goals
///    section used to write the same three facts out separately, against two ARB
///    templates that differed only in their first word. `goal_status.dart` is
///    where that sentence lives; `l10n.goalStatus` may only be read there.
///
/// 3. **There is one form that records learning.** `add_chazara_sheet.dart` was
///    the log sheet again, and every one of the three ways it had drifted was a
///    regression: the wall clock instead of `clockProvider`, no session timer,
///    and a second ARB key asking for the same duration. A second sheet built
///    out of a manual-date switch plus a duration field is that file coming
///    back.
///
/// Each ban carries a sample of the shape it must catch, so the guard cannot rot
/// into a regex that matches nothing — which is how every source-scanning check
/// dies. Verified by feeding it violations, not by assuming.
void main() {
  const escapeHatch = 'report-shape: ok';

  /// The file each rule is *supposed* to live in.
  const homes = <String, String>{
    'Scaffold': 'lib/features/reports/report_screen.dart',
    'goalStatus': 'lib/features/common/goal_status.dart',
    'logSheetManualDateTime': 'lib/features/unit_grid/log_unit_sheet.dart',
  };

  const bans = <({String why, String pattern, String sample, String home})>[
    (
      why: 'a report section with a Scaffold of its own is a route again — '
          'the shell in report_screen.dart owns the only one',
      pattern: r'\bScaffold\(',
      sample: '      body: Scaffold(appBar: AppBar()),',
      home: 'Scaffold',
    ),
    (
      why: 'renders the goal sentence outside goal_status.dart — that is how '
          'the banner and the row came to say the same thing two ways',
      pattern: r'l10n\.goalStatus\(|\.goalStatus\(',
      sample: 'final text = l10n.goalStatus(date, rate, status);',
      home: 'goalStatus',
    ),
    (
      why: 'builds a second date/duration logging form — there is one, in '
          'log_unit_sheet.dart, and it takes an action instead',
      pattern: r'logSheetManualDateTime',
      sample: 'title: Text(l10n.logSheetManualDateTime),',
      home: 'logSheetManualDateTime',
    ),
  ];

  /// Rule 1 applies only inside `reports/`; the other two apply to all of `lib`.
  const scopes = <String, String>{'Scaffold': 'lib/features/reports/'};

  List<({int line, String text})> codeLines(String source) {
    final out = <({int line, String text})>[];
    var inBlock = false;
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      if (raw.contains(escapeHatch)) continue;
      var text = raw;
      if (inBlock) {
        final end = text.indexOf('*/');
        if (end < 0) continue;
        text = text.substring(end + 2);
        inBlock = false;
      }
      final block = text.indexOf('/*');
      if (block >= 0) {
        final end = text.indexOf('*/', block + 2);
        if (end < 0) {
          text = text.substring(0, block);
          inBlock = true;
        } else {
          text = text.substring(0, block) + text.substring(end + 2);
        }
      }
      final line = text.indexOf('//');
      if (line >= 0) text = text.substring(0, line);
      if (text.trim().isEmpty) continue;
      out.add((line: i + 1, text: text));
    }
    return out;
  }

  test('the regexes actually match the shapes they ban', () {
    for (final ban in bans) {
      expect(RegExp(ban.pattern).hasMatch(ban.sample), isTrue,
          reason: 'the pattern for "${ban.why}" no longer matches its own '
              'sample, so it is guarding nothing');
    }
  });

  test('every home file still exists to be excused', () {
    for (final home in homes.values) {
      expect(File(home).existsSync(), isTrue,
          reason: '$home is where one of these rules is allowed to live; if it '
              'moved, this guard is pointing at nothing');
    }
  });

  test('the four report screens are gone, and did not come back as routes', () {
    for (final dead in [
      'lib/features/stats',
      'lib/features/calculator',
      'lib/features/goals',
      'lib/features/siyum',
      'lib/features/mefarshim',
      'lib/features/unit_grid/add_chazara_sheet.dart',
    ]) {
      expect(File(dead).existsSync() || Directory(dead).existsSync(), isFalse,
          reason: '$dead is a report section (or the second log form) that has '
              'grown back into a file of its own');
    }
  });

  test('lib/ keeps each of these in exactly one place', () {
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.contains('/l10n/generated/') || path.endsWith('.g.dart')) {
        continue;
      }

      final lines = codeLines(entity.readAsStringSync());
      for (final ban in bans) {
        if (path.endsWith(homes[ban.home]!)) continue;
        final scope = scopes[ban.home];
        if (scope != null && !path.contains(scope)) continue;
        for (final line in lines) {
          if (!RegExp(ban.pattern).hasMatch(line.text)) continue;
          violations.add('$path:${line.line} ${ban.why}\n'
              '    ${line.text.trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Each of these has one home, named above.\n\n'
          '${violations.join('\n')}\n\n'
          'If a line genuinely needs the shape, mark it '
          '`// $escapeHatch — <reason>`.',
    );
  });
}
