import 'package:chovos_hayom/core/day.dart';
import 'package:flutter_test/flutter_test.dart';

/// `Day` replaced nine hand-rolled answers to "which calendar day is this",
/// written in two conventions that disagreed. These are the properties that
/// make one answer enough.
///
/// The DST tests below are the reason the type exists, and they are written so
/// they are *meaningful in every timezone*: each asserts a property that must
/// hold everywhere, rather than naming an hour that only a US host would see.
/// On a host with DST they fail against the old local-`DateTime` arithmetic; on
/// a UTC CI host they are cheap tautologies. Either way they never go yellow,
/// which is what a regression test in a timezone-dependent area has to do.
void main() {
  group('identity', () {
    test('the same calendar day is the same Day, whatever the clock says', () {
      expect(Day.of(DateTime(2026, 8, 5)), Day.of(DateTime(2026, 8, 5, 23, 59)));
      expect(Day.of(DateTime(2026, 8, 5, 0, 0, 1)).hashCode,
          Day.of(DateTime(2026, 8, 5, 12)).hashCode);
    });

    test('different calendar days are different Days', () {
      expect(Day.of(DateTime(2026, 8, 5)) == Day.of(DateTime(2026, 8, 6)),
          isFalse);
    });

    test('a Day is usable as a map key and a set member', () {
      final counts = <Day, int>{};
      counts[Day.of(DateTime(2026, 8, 5, 9))] = 1;
      counts[Day.of(DateTime(2026, 8, 5, 21))] =
          (counts[Day.of(DateTime(2026, 8, 5))] ?? 0) + 1;
      expect(counts, hasLength(1));
      expect(counts.values.single, 2);
    });

    test('ordinal is anchored to the Unix epoch', () {
      expect(Day.of(DateTime.utc(1970, 1, 1)).ordinal, 0);
      expect(Day.of(DateTime.utc(1970, 1, 2)).ordinal, 1);
      expect(Day.of(DateTime.utc(1969, 12, 31)).ordinal, -1);
    });
  });

  group('arithmetic', () {
    test('adding and subtracting days round-trips', () {
      final d = Day.of(DateTime(2026, 8, 5));
      expect(d + 10 - 10, d);
      expect((d + 1).difference(d), 1);
      expect((d - 1).difference(d), -1);
      expect(d.difference(d), 0);
    });

    test('difference counts calendar days across a month and a year end', () {
      expect(
        Day.of(DateTime(2026, 9, 1)).difference(Day.of(DateTime(2026, 8, 1))),
        31,
      );
      expect(
        Day.of(DateTime(2027, 1, 1)).difference(Day.of(DateTime(2026, 1, 1))),
        365,
      );
      // 2028 is a leap year.
      expect(
        Day.of(DateTime(2029, 1, 1)).difference(Day.of(DateTime(2028, 1, 1))),
        366,
      );
    });

    test('ordering agrees with the calendar', () {
      final a = Day.of(DateTime(2026, 8, 5));
      final b = Day.of(DateTime(2026, 8, 6));
      expect(a < b, isTrue);
      expect(b > a, isTrue);
      expect(a <= Day.of(DateTime(2026, 8, 5, 23)), isTrue);
      expect(a >= Day.of(DateTime(2026, 8, 5, 1)), isTrue);
      expect([b, a]..sort(), [a, b]);
    });

    test('weekday is derived from the ordinal, not from a DateTime', () {
      // 1970-01-01 was a Thursday — the anchor the formula is built on.
      expect(const Day(0).weekday, DateTime.thursday);
      // And it keeps agreeing with DateTime on ordinary days.
      for (final probe in [
        DateTime(2026, 8, 5),
        DateTime(2026, 1, 1),
        DateTime(1999, 12, 31),
        DateTime(1965, 6, 3),
      ]) {
        expect(Day.of(probe).weekday, probe.weekday, reason: '$probe');
      }
    });

    test('weekday cycles correctly, including before the epoch', () {
      for (var i = -400; i < 400; i++) {
        expect(Day(i).weekday, inInclusiveRange(1, 7));
        expect(Day(i + 7).weekday, Day(i).weekday);
      }
    });
  });

  group('the DateTime boundary', () {
    test('midnight round-trips back to the same Day', () {
      for (final probe in [
        DateTime(2026, 8, 5, 13, 37),
        DateTime(2026, 1, 1),
        DateTime(2026, 12, 31, 23, 59, 59),
      ]) {
        final day = Day.of(probe);
        expect(Day.of(day.midnight), day, reason: '$probe');
        expect(day.midnight.hour, 0, reason: '$probe');
        expect(day.midnight.isUtc, isFalse, reason: '$probe');
      }
    });

    test('contains answers for an instant anywhere in the day', () {
      final day = Day.of(DateTime(2026, 8, 5));
      expect(day.contains(DateTime(2026, 8, 5)), isTrue);
      expect(day.contains(DateTime(2026, 8, 5, 23, 59, 59)), isTrue);
      expect(day.contains(DateTime(2026, 8, 6)), isFalse);
    });

    test('toString is the ISO calendar date', () {
      expect(Day.of(DateTime(2026, 8, 5)).toString(), '2026-08-05');
      expect(Day.of(DateTime(2026, 12, 31)).toString(), '2026-12-31');
    });
  });

  group('daylight saving — the reason this type exists', () {
    // Every consecutive pair of days in a year, in the host's own timezone.
    // Whatever zone CI runs in, if it observes DST the transition days are in
    // here; `Day` must call every one of them exactly one day apart.
    test('consecutive calendar days are always exactly one day apart', () {
      var day = Day.of(DateTime(2026, 1, 1));
      for (var i = 0; i < 365; i++) {
        final next = day + 1;
        expect(next.difference(day), 1, reason: 'from $day to $next');
        // Counting forward must agree with naming the date outright — the two
        // ways the old code arrived at "tomorrow", which disagreed on the two
        // transition days.
        final named = Day.of(DateTime(
            day.midnight.year, day.midnight.month, day.midnight.day + 1));
        expect(next, named, reason: 'counted $next vs named $named');
        day = next;
      }
    });

    test('stepping a year forward and back returns to the same day', () {
      final start = Day.of(DateTime(2026, 1, 1));
      var cursor = start;
      for (var i = 0; i < 365; i++) {
        cursor += 1;
      }
      for (var i = 0; i < 365; i++) {
        cursor -= 1;
      }
      expect(cursor, start);
    });

    test('every midnight in a year is a real local midnight', () {
      // A local midnight that does not exist (the spring-forward hour in zones
      // that shift at 00:00, e.g. some of South America) is the one case where
      // `DateTime` cannot honour the request. Whatever it returns, the day it
      // belongs to must still be the day we asked for — otherwise a heatmap
      // column or a chart tick silently jumps.
      var day = Day.of(DateTime(2026, 1, 1));
      for (var i = 0; i < 365; i++) {
        expect(Day.of(day.midnight), day, reason: '$day');
        day += 1;
      }
    });

    test(
        'the naive local-DateTime forms this type replaced are not equivalent '
        'to it', () {
      // A negative control in the spirit of sheet_insets_test: if this ever
      // stops finding a disagreement on a DST host, the sweep above has stopped
      // being able to catch the regression it was written for. It is skipped
      // rather than failed on a host without DST, because there is nothing
      // wrong there — the check simply has nothing to say.
      var sawDstShift = false;
      var day = Day.of(DateTime(2026, 1, 1));
      for (var i = 0; i < 365; i++) {
        final a = day.midnight;
        final b = (day + 1).midnight;
        if (b.difference(a).inHours != 24) sawDstShift = true;
        day += 1;
      }
      if (!sawDstShift) {
        markTestSkipped('host timezone does not observe DST in 2026');
        return;
      }
      // On a DST host, at least one consecutive pair breaks `.inDays`, and
      // `Day` gets all 365 right — which is the whole claim.
      var naiveWrong = 0;
      day = Day.of(DateTime(2026, 1, 1));
      for (var i = 0; i < 365; i++) {
        if ((day + 1).midnight.difference(day.midnight).inDays != 1) {
          naiveWrong++;
        }
        day += 1;
      }
      expect(naiveWrong, greaterThan(0),
          reason: 'the old .difference().inDays form should misread a '
              'transition day');
    });
  });
}
