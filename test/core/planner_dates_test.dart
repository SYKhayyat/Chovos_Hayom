import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/core/planner_dates.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Hebrew-calendar reader (Phase 1, #10) and the engine fed by it: the
/// fixed points cited here were verified against kosher_dart directly before
/// being written down.
void main() {
  Day d(int y, int m, int day) => Day.of(DateTime(y, m, day));

  group('dayInfoFor', () {
    test('fills the Gregorian fields of a known Saturday', () {
      final info = dayInfoFor(d(2026, 9, 12));
      expect(info.day, d(2026, 9, 12));
      expect(info.weekday, DateTime.saturday);
      expect(info.dayOfMonth, 12);
    });

    test('reads the Hebrew fixed points', () {
      final rh = dayInfoFor(d(2026, 9, 12)); // 1 Tishrei 5787
      expect(rh.hebrewDayOfMonth, 1);
      expect(rh.hebrewMonth, HebrewMonth.tishrei);
      expect(rh.hebrewYear, 5787);

      final erev = dayInfoFor(d(2026, 9, 11)); // 29 Elul 5786
      expect(erev.hebrewDayOfMonth, 29);
      expect(erev.hebrewMonth, HebrewMonth.elul);
      expect(erev.hebrewYear, 5786);

      expect(dayInfoFor(d(2025, 9, 23)).hebrewMonth, HebrewMonth.tishrei); // RH 5786
      expect(dayInfoFor(d(2027, 10, 2)).hebrewYear, 5788); // RH 5788
    });

    test('Cheshvan 5786 is 29 days and rolls into Kislev', () {
      final last = dayInfoFor(d(2025, 11, 20));
      expect(last.hebrewMonth, HebrewMonth.cheshvan);
      expect(last.hebrewDayOfMonth, 29);
      final next = dayInfoFor(d(2025, 11, 21));
      expect(next.hebrewMonth, HebrewMonth.kislev);
      expect(next.hebrewDayOfMonth, 1);
    });

    test('Cheshvan 5787 is 30 days', () {
      final last = dayInfoFor(d(2026, 11, 10));
      expect(last.hebrewMonth, HebrewMonth.cheshvan);
      expect(last.hebrewDayOfMonth, 30);
      final next = dayInfoFor(d(2026, 11, 11));
      expect(next.hebrewMonth, HebrewMonth.kislev);
      expect(next.hebrewDayOfMonth, 1);
    });

    test('a leap year has an Adar II', () {
      final adarIi = dayInfoFor(d(2027, 3, 10)); // 1 Adar II 5787
      expect(adarIi.hebrewYear, 5787);
      expect(adarIi.hebrewMonth, HebrewMonth.adarIi);
      expect(adarIi.hebrewDayOfMonth, 1);
    });

    test('a ten-year walk is internally consistent and drifts correctly', () {
      DayInfo? previous;
      var day = d(2020, 1, 1);
      final end = d(2030, 1, 1);
      var walked = 0;
      while (day <= end) {
        final info = dayInfoFor(day);
        expect(info.weekday, day.midnight.weekday,
            reason: 'weekday disagrees with the Gregorian date on $day');
        expect(info.hebrewDayOfMonth, inInclusiveRange(1, 30));
        expect(info.hebrewMonth, inInclusiveRange(1, 13));
        expect(info.hebrewYear, inInclusiveRange(5500, 6000));
        if (previous != null) {
          if (info.hebrewMonth == previous.hebrewMonth) {
            expect(info.hebrewDayOfMonth, previous.hebrewDayOfMonth! + 1,
                reason: 'Hebrew day did not advance within $day');
          } else {
            expect(info.hebrewDayOfMonth, 1,
                reason: 'a Hebrew month change must land on day 1 ($day)');
            final old = previous.hebrewMonth!;
            final next = info.hebrewMonth!;
            final advance = next == old + 1 ||
                (old == 12 && (next == 13 || next == 1)) ||
                (old == 13 && next == 1);
            expect(advance, isTrue,
                reason: 'Hebrew months must advance in order ($day): '
                    '$old -> $next');
            if (next == HebrewMonth.tishrei) {
              expect(info.hebrewYear, previous.hebrewYear! + 1,
                  reason: 'the Hebrew year rolls over at Tishrei ($day)');
            } else {
              expect(info.hebrewYear, previous.hebrewYear,
                  reason: 'the Hebrew year must not roll over at Nissan ($day)');
            }
          }
        }
        previous = info;
        day = day + 1;
        walked++;
      }
      // 2020-01-01 through 2030-01-01 inclusive, three leap years among them.
      expect(walked, 3654);
    });
  });

  group('engine with the real reader', () {
    test('every 1st of Tishrei lands on the actual Rosh Hashanah dates', () {
      const plan = LearningPlan(
        id: 'rh',
        name: 'Rosh Hashanah',
        assignments: [
          PlanAssignment(
              id: 'a', rule: HebrewDayRule(day: 1, month: HebrewMonth.tishrei)),
        ],
      );
      final days =
          PlannerSchedule.daysOn(plan, dayInfoFor, d(2024, 1, 1), d(2029, 1, 1))
              .toList();
      expect(
        days.map((x) => x.toString()),
        ['2024-10-03', '2025-09-23', '2026-09-12', '2027-10-02', '2028-09-21'],
      );
    });

    test('the 30th of a short Hebrew month never fires', () {
      const plan = LearningPlan(
        id: 'p',
        name: 'P',
        assignments: [PlanAssignment(id: 'a', rule: HebrewDayRule(day: 30))],
      );
      final days =
          PlannerSchedule.daysOn(plan, dayInfoFor, d(2025, 10, 20), d(2026, 12, 5))
              .toList();
      for (final day in days) {
        final info = dayInfoFor(day);
        if (info.hebrewMonth == HebrewMonth.cheshvan &&
            info.hebrewYear == 5786) {
          expect(info.hebrewDayOfMonth, isNot(30),
              reason: 'Cheshvan 5786 is 29 days long; a 30th cannot fire');
        }
      }
      // Cheshvan 5787 is 30 days — the same rule must fire there.
      expect(
        days.any((day) {
          final i = dayInfoFor(day);
          return i.hebrewMonth == HebrewMonth.cheshvan &&
              i.hebrewYear == 5787 &&
              i.hebrewDayOfMonth == 30;
        }),
        isTrue,
      );
    });

    test('a Wednesday rule with the real reader lands on Wednesdays', () {
      const plan = LearningPlan(
        id: 'w',
        name: 'W',
        assignments: [
          PlanAssignment(
              id: 'a', rule: WeekdayRule(weekdays: {DateTime.wednesday})),
        ],
      );
      final days =
          PlannerSchedule.daysOn(plan, dayInfoFor, d(2026, 9, 1), d(2026, 9, 30))
              .toList();
      expect(days, isNotEmpty);
      for (final day in days) {
        expect(day.midnight.weekday, DateTime.wednesday);
      }
    });
  });
}