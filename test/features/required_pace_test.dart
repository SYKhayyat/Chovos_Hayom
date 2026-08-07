import 'dart:io';

import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/usecases/predictor.dart';
import 'package:chovos_hayom/features/common/naming.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/source_scan.dart';

/// A required daily pace is rendered in two places — the goal line and the
/// Calculator's *By date* answer — and both wrote `toStringAsFixed(2)` for
/// themselves.
///
/// The duplication is the finding. The **rounding** is what the duplication was
/// hiding: both of them rounded to nearest, and a *requirement* rounded down is
/// a number you can follow exactly and still miss.
void main() {
  group('requiredPerDayText', () {
    test('rounds up, because a requirement understated is not a requirement',
        () {
      // 100 dapim in 30 days. 3.33 a day for 30 days is 99.9.
      expect(requiredPerDayText(100 / 30), '3.34');
      // 155 in 91 — the goal in `report_screen_test.dart`. 1.70 x 91 = 154.7.
      expect(requiredPerDayText(155 / 91), '1.71');
    });

    test('leaves a rate that already lands on two decimals alone', () {
      // The trap in rounding up: 3.33 is 3.3300000000000000710… in binary, so
      // `(rate * 100).ceil()` is 334 and an exact answer would be inflated.
      expect(requiredPerDayText(3.33), '3.33');
      expect(requiredPerDayText(333 / 100), '3.33');
      expect(requiredPerDayText(2), '2.00');
      expect(requiredPerDayText(0), '0.00');
      expect(requiredPerDayText(0.5), '0.50');
    });

    test('a rate below a hundredth still reads as something to do', () {
      // One daf left and three years to do it in. Rounding to nearest reads
      // "0.00 per day", which is advice to stop.
      expect(requiredPerDayText(1 / 1000), '0.01');
    });

    test('an impossible target does not render as "Infinity"', () {
      // The Calculator catches this before it gets here and says "pick a future
      // date"; the goal line cannot produce it at all. Guarded anyway, because
      // the failure would be a word in the middle of a sentence.
      expect(requiredPerDayText(double.infinity), '—');
      expect(requiredPerDayText(double.nan), '—');
    });

    test('what the goal line and the Calculator both feed it', () {
      // Same function, same arguments, in both places — so this is the number
      // on both screens, and the test above is what it looks like.
      final rate = Predictor.requiredPerDay(
        remaining: 155,
        from: Day.of(DateTime(2026, 1, 10)),
        target: Day.of(DateTime(2026, 4, 11)),
      );
      expect(requiredPerDayText(rate), '1.71');
    });
  });

  /// And the rule, rather than the two sites that currently obey it.
  ///
  /// The ban is per *file*: a file that has anything to do with a required pace
  /// must not also be formatting numbers, because that is the whole of how this
  /// quantity came to have two spellings. `avgPerDay` and `percent` on the
  /// Overview are deliberately untouched — those are measurements, they round
  /// to nearest, and they live in a file that never mentions `requiredPerDay`.
  test('nothing formats a required pace for itself', () {
    const escapeHatch = 'required-pace: ok';
    const home = 'lib/features/common/naming.dart';
    final formatting = RegExp(r'toStringAsFixed\(');
    final quantity = RegExp(r'\brequiredPerDay\b');

    expect(formatting.hasMatch('rate.toStringAsFixed(2)'), isTrue);
    expect(quantity.hasMatch('goal.requiredPerDay,'), isTrue);

    final violations = <String>[];
    for (final path in dartSourcesUnder()) {
      if (path == home) continue;
      final lines =
          codeLines(File(path).readAsStringSync(), escapeHatch: escapeHatch);
      if (!lines.any((l) => quantity.hasMatch(l.text))) continue;
      for (final line in lines) {
        if (!formatting.hasMatch(line.text)) continue;
        violations.add('$path:${line.line}\n    ${line.text.trim()}');
      }
    }

    expect(violations, isEmpty,
        reason: 'a required pace is rendered by requiredPerDayText, which is '
            'where the decision to round *up* lives — and rounding it down is '
            'advice that does not reach the '
            'date.\n\n${violations.join('\n')}');
  });
}
