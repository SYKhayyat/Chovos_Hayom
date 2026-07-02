import 'package:chovos_hayom/domain/usecases/predictor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Predictor (forward)', () {
    test('daysToFinish rounds up', () {
      expect(Predictor.daysToFinish(remaining: 10, perDay: 3), 4);
      expect(Predictor.daysToFinish(remaining: 0, perDay: 3), 0);
      expect(Predictor.daysToFinish(remaining: 10, perDay: 0), -1);
    });

    test('finishDate projects forward', () {
      final from = DateTime(2026, 1, 1);
      expect(
        Predictor.finishDate(remaining: 10, perDay: 5, from: from),
        DateTime(2026, 1, 3),
      );
      expect(Predictor.finishDate(remaining: 10, perDay: 0, from: from), isNull);
    });
  });

  group('Predictor (backward / recommendation)', () {
    test('requiredPerDay divides remaining by days available', () {
      expect(
        Predictor.requiredPerDay(
            remaining: 10, from: DateTime(2026, 1, 1), target: DateTime(2026, 1, 11)),
        closeTo(1.0, 0.001),
      );
    });

    test('requiredPerDay is infinity when target is today or past', () {
      expect(
        Predictor.requiredPerDay(
            remaining: 10, from: DateTime(2026, 1, 11), target: DateTime(2026, 1, 11)),
        double.infinity,
      );
    });

    test('requiredPerDay is zero when nothing remains', () {
      expect(
        Predictor.requiredPerDay(
            remaining: 0, from: DateTime(2026, 1, 1), target: DateTime(2026, 2, 1)),
        0,
      );
    });
  });

  group('Predictor (Shabbos-aware)', () {
    test('equal weekday/Shabbos amounts reduce to a flat pace', () {
      final from = DateTime(2026, 1, 1);
      // 10 units at 2/day -> 5 learning days -> finishes on day index 4.
      expect(
        Predictor.finishDateWithShabbos(
            remaining: 10, weekdayAmount: 2, shabbosAmount: 2, from: from),
        DateTime(2026, 1, 5),
      );
    });

    test('returns null when nothing is ever learned', () {
      expect(
        Predictor.finishDateWithShabbos(
            remaining: 10,
            weekdayAmount: 0,
            shabbosAmount: 0,
            from: DateTime(2026, 1, 1)),
        isNull,
      );
    });
  });
}
