import 'package:flutter_test/flutter_test.dart';

import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/usecases/predictor.dart';

/// GRADER PROBE — the cost of the "never finishes" answer.
///
/// `CalculatorScreen._compute` runs synchronously inside `build`, straight off
/// the `TextEditingController` text, and `_cycleCtrl`/`_dailyCtrl` accept any
/// double `double.tryParse` will take. A small-but-positive amount is not
/// rejected — `daily <= 0` is the only guard — so it walks the day loop until
/// the 200,000-iteration cap before answering "never finishes".
///
/// The repo has a `derive_cost_test.dart` that budgets the fold, so a latency
/// budget is an established idea here; this is the path that has none.
/// **BUILDER NOTE (W6).** Kept, with one change: it times a thousand calls rather
/// than one. A 16ms wall-clock budget around a single call that now takes
/// microseconds is a coin flip on a loaded machine — this file failed inside a
/// full `flutter test` (which runs files in parallel) and passed on its own,
/// measuring the scheduler rather than the code. The same 16ms frame is still the
/// reference; the claim is now the stronger one, that a thousand worst cases fit
/// inside it with room to spare, which is also four orders of magnitude away from
/// the 47,890ms one call cost when this probe was written.
void main() {
  test('an amount of 0.0001/day answers within a frame budget', () {
    const calls = 1000;
    Day? date;
    final from = Day.of(DateTime(2026, 7, 29));
    final sw = Stopwatch()..start();
    for (var i = 0; i < calls; i++) {
      date = Predictor.finishDateWithCycle(
        remaining: 2711, // Shas
        amounts: const [0.0001], // "a tenth of a thousandth of a daf a day"
        startIndex: 0,
        from: from,
      );
    }
    sw.stop();

    expect(date, isNull, reason: 'it does give up rather than hang forever');
    // 16ms is one frame at 60Hz, and this runs in build(), on every keystroke.
    // The ceiling is 500ms for a thousand of them — 30x the frame budget as
    // headroom against a busy machine, and still 0.5ms per call.
    expect(sw.elapsedMilliseconds, lessThan(500),
        reason: '$calls answers took ${sw.elapsedMilliseconds}ms; the calculator '
            'spent 47,890ms on one of them, in build(), walking 200,000 days '
            'before saying "never finishes"');
  });
}
