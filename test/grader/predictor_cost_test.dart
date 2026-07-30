import 'package:flutter_test/flutter_test.dart';

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
void main() {
  test('an amount of 0.0001/day answers within a frame budget', () {
    final sw = Stopwatch()..start();
    final date = Predictor.finishDateWithCycle(
      remaining: 2711, // Shas
      amounts: const [0.0001], // "a tenth of a thousandth of a daf a day"
      startIndex: 0,
      from: DateTime(2026, 7, 29),
    );
    sw.stop();

    expect(date, isNull, reason: 'it does give up rather than hang forever');
    // 16ms is one frame at 60Hz. This runs in build(), on every keystroke.
    expect(sw.elapsedMilliseconds, lessThan(16),
        reason: 'the calculator spent ${sw.elapsedMilliseconds}ms in build() '
            'walking 200,000 days before saying "never finishes"');
  });
}
