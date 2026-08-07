import 'dart:io';

import 'package:chovos_hayom/core/parse.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/source_scan.dart';

/// "Is this a positive integer" had six hand-written answers for two settings,
/// and they were not the same answer.
///
/// `2, 5, x` in the chazara intervals silently kept `[2, 5]`; `x` in the backup
/// interval — two rows down the same screen — closed the dialog and complained.
/// One parse now, and the layers differ only in what they do about a failure.
void main() {
  group('positiveInt', () {
    test('reads a number a person typed, spaces and all', () {
      expect(positiveInt('7'), 7);
      expect(positiveInt('  30  '), 30);
    });

    test('everything that is not one reads as null', () {
      // The three failures the call sites used to distinguish and then treat
      // identically.
      expect(positiveInt(null), isNull, reason: 'absent');
      expect(positiveInt(''), isNull);
      expect(positiveInt('x'), isNull, reason: 'not a number');
      expect(positiveInt('3.5'), isNull, reason: 'not an integer');
      expect(positiveInt('-4'), isNull, reason: 'not positive');
      expect(positiveInt('0'), isNull,
          reason: 'every quantity this parses is a count of days or units, and '
              'none of them means anything at zero');
    });
  });

  group('nonNegativeInt', () {
    test('zero is a real answer, for the one quantity where it is', () {
      // A leaf's first unit index: 0 for a sefer numbered from zero, 2 for a
      // gemara starting on daf ב.
      expect(nonNegativeInt('0'), 0);
      expect(nonNegativeInt('2'), 2);
      expect(nonNegativeInt('-1'), isNull);
      expect(nonNegativeInt('x'), isNull);
    });
  });

  group('positiveIntList', () {
    test('reads the list', () {
      expect(positiveIntList('1, 3, 7, 16, 35, 70').values,
          [1, 3, 7, 16, 35, 70]);
      expect(positiveIntList('1,3,7').values, [1, 3, 7]);
    });

    test('keeps what it could not read, rather than dropping it silently', () {
      // The whole difference between the two settings. Discarding the rejects
      // is what let `2, 5, x` save a shorter schedule than the one that was
      // typed, with nothing said.
      final parsed = positiveIntList('2, 5, x, 0, -1');
      expect(parsed.values, [2, 5]);
      expect(parsed.rejected, ['x', '0', '-1']);
      expect(parsed.isValid, isFalse);
    });

    test('a trailing comma is a typing artefact, not a value', () {
      final parsed = positiveIntList('2, 5, ');
      expect(parsed.values, [2, 5]);
      expect(parsed.rejected, isEmpty);
      expect(parsed.isValid, isTrue);
      expect(positiveIntList('2,,5').values, [2, 5]);
    });

    test('empty is valid and empty — the caller decides what that means', () {
      // The loader falls back to the defaults; the dialog refuses. Both are
      // right, and neither belongs in the parse.
      final parsed = positiveIntList('   ');
      expect(parsed.values, isEmpty);
      expect(parsed.isValid, isTrue);
    });
  });

  /// And the rule, rather than the ten sites that currently obey it.
  test('nothing parses an integer out of user text for itself', () {
    const escapeHatch = 'parse: ok';
    const home = 'lib/core/parse.dart';
    // Reading a *stored* string that the app itself wrote is a different
    // question — a sort level, a JSON field — and does not go through here.
    const allowed = {
      'lib/application/sorting.dart',
      'lib/application/settings.dart',
    };
    final banned = RegExp(r'int\.tryParse\(');

    expect(banned.hasMatch('final n = int.tryParse(text.trim()) ?? 0;'), isTrue);

    final violations = <String>[];
    for (final path in dartSourcesUnder()) {
      if (path == home || allowed.contains(path)) continue;
      for (final line
          in codeLines(File(path).readAsStringSync(), escapeHatch: escapeHatch)) {
        if (!banned.hasMatch(line.text)) continue;
        violations.add('$path:${line.line}\n    ${line.text.trim()}');
      }
    }

    expect(violations, isEmpty,
        reason: 'use positiveInt / nonNegativeInt / positiveIntList — the '
            'hand-written versions of this disagreed about what happens to '
            'input none of them could use.\n\n${violations.join('\n')}\n\n'
            'If a line genuinely needs the raw form, mark it '
            '`// $escapeHatch — <reason>`.');
  });
}
