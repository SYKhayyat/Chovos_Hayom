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

  group('calendar windows', () {
    // The three ranges are one derivation with three arguments, so these are
    // mostly about the properties that make paging and the arrows agree:
    // stepping out and back, and a step landing on the unit rather than on
    // whatever day of it the anchor happened to be.
    test('a day range is the anchor day itself', () {
      final anchor = d(2026, 1, 10); // a Saturday
      expect(calendarWindow(anchor, PlannerCalendarRange.day), [anchor]);
    });

    test('a week starts on the Monday on or before its anchor', () {
      // 10 Jan 2026 is a Saturday, so its week is Mon 5 - Sun 11 Jan.
      expect(calendarWindow(d(2026, 1, 10), PlannerCalendarRange.week), [
        d(2026, 1, 5),
        d(2026, 1, 6),
        d(2026, 1, 7),
        d(2026, 1, 8),
        d(2026, 1, 9),
        d(2026, 1, 10),
        d(2026, 1, 11),
      ]);
    });

    test('a month is six whole weeks from the Monday on or before the 1st', () {
      final window = calendarWindow(d(2026, 1, 10), PlannerCalendarRange.month);
      expect(window, hasLength(42));
      // 1 Jan 2026 is a Thursday, so the grid opens on Mon 29 Dec 2025 and
      // runs six whole weeks to Sun 8 Feb.
      expect(window.first, d(2025, 12, 29));
      expect(window.last, d(2026, 2, 8));
      // Six rows of seven, all consecutive — which is what makes a month's
      // page the same height as February's.
      for (var i = 1; i < window.length; i++) {
        expect(window[i], window[i - 1] + 1);
        expect(window[i].weekday, i % 7 + DateTime.monday);
      }
    });

    test('a month page holds every day of its month, plus its neighbours',
        () {
      // A 42-cell grid is six weeks, so a short month is padded with the tail
      // of the month before and the head of the one after. That is what a month
      // grid *is* — and it is why a month page overlaps its neighbour's on
      // spill days, which the day and week ranges never do.
      final window =
          calendarWindow(d(2026, 2, 10), PlannerCalendarRange.month).toSet();
      for (var day = 1; day <= 28; day++) {
        expect(window, contains(d(2026, 2, day)));
      }
      expect(window, contains(d(2026, 1, 26)), reason: 'padded at the front');
      expect(window.length, 42);
    });

    test('a range is named by its own first day, not by the page it opens on',
        () {
      // The distinction that keeps a heading honest. 1 Jan 2026 is a Thursday,
      // so January's page opens on Mon 29 Dec 2025 to fill six rows — and
      // printing that as the heading would put December's date over January.
      final anchor = d(2026, 1, 10);
      expect(PlannerCalendarRange.month.startFrom(anchor), d(2025, 12, 29),
          reason: 'the page opens on the padding day');
      expect(PlannerCalendarRange.month.namedDay(anchor), d(2026, 1, 1),
          reason: 'but the month is named by the 1st');

      // A week has no padding, so there is nothing to be confused about and the
      // two agree — which is what makes the day and month forms the exceptions.
      expect(PlannerCalendarRange.week.startFrom(anchor),
          PlannerCalendarRange.week.namedDay(anchor));
      expect(PlannerCalendarRange.day.startFrom(anchor),
          PlannerCalendarRange.day.namedDay(anchor));

      // A named day is always inside its own page, never outside it.
      for (final range in PlannerCalendarRange.values) {
        for (final day in [d(2026, 1, 1), d(2026, 2, 28), d(2026, 3, 31)]) {
          expect(calendarWindow(day, range),
              contains(range.namedDay(day)),
              reason: '$range must name a day it is showing');
        }
      }
    });

    test('every range steps by its own unit', () {
      final anchor = d(2026, 1, 10);
      expect(PlannerCalendarRange.day.step(anchor, 1), d(2026, 1, 11));
      expect(PlannerCalendarRange.week.step(anchor, 1), d(2026, 1, 12),
          reason: 'a week from Sat 10 Jan is Mon 12 Jan, not Sat 17 Jan');
      expect(PlannerCalendarRange.month.step(anchor, 1), d(2026, 2, 1));
    });

    test('stepping out and back returns the same page, for every range', () {
      // The property paging relies on: it moves the anchor and rebuilds rather
      // than accumulating an offset, so a page reached by a swipe and a page
      // reached by an arrow have to be the same page.
      //
      // Stated about the **window**, not the anchor, and the difference is the
      // point: a step normalises onto the unit's first day, so 15 Jan stepped
      // forward and back is 1 Jan — the same page, reached from a different
      // anchor. Asserting the anchor came back exactly would be asserting that
      // the step preserves a day-of-month it has no use for.
      for (final range in PlannerCalendarRange.values) {
        for (final anchor in [
          d(2026, 1, 1),
          d(2026, 1, 15),
          d(2026, 1, 31),
          d(2026, 2, 28),
          d(2024, 2, 29), // a leap day
          d(2026, 12, 31),
        ]) {
          final here = calendarWindow(anchor, range);
          for (final delta in [-7, -1, 1, 3, 12]) {
            expect(
              calendarWindow(range.step(range.step(anchor, delta), -delta), range),
              here,
              reason: '$range round trip from $anchor',
            );
          }
        }
      }
    });

    test('a month step from the 31st does not spill into the next month', () {
      // 31 Jan + 1 month is 1 Feb. Overflowing to 3 March is the bug this
      // shape exists to prevent: the day of the month is carried, and March
      // has no 31st to land on.
      expect(PlannerCalendarRange.month.step(d(2026, 1, 31), 1), d(2026, 2, 1));
      expect(PlannerCalendarRange.month.step(d(2026, 3, 31), 1), d(2026, 4, 1));
      expect(PlannerCalendarRange.month.step(d(2026, 1, 31), -1), d(2025, 12, 1));
    });

    test('stepping a month keeps the day of the month', () {
      // The month range's step starts from the 1st, so a 31st lands on the 1st
      // rather than being clamped day by day; this is the property that makes
      // twelve consecutive month steps equal one year.
      final anchor = d(2026, 1, 15);
      var moved = anchor;
      for (var i = 0; i < 12; i++) {
        moved = PlannerCalendarRange.month.step(moved, 1);
      }
      expect(moved, d(2027, 1, 1));
    });

    test('a page holds exactly its own days, whatever the anchor', () {
      for (final range in PlannerCalendarRange.values) {
        for (final anchor in [d(2026, 2, 1), d(2026, 2, 27), d(2026, 2, 28)]) {
          expect(calendarWindow(anchor, range), hasLength(range.dayCount),
              reason: '$range at $anchor');
        }
      }
    });

    test('a stepped day or week page shares no day with the one it came from',
        () {
      // Day and week pages are exact, so stepping one never repeats a day. The
      // month range is excluded on purpose and the reason is above: a 42-cell
      // grid pads with its neighbours' days, so consecutive month pages
      // deliberately share the spill.
      final anchor = d(2026, 1, 10);
      for (final range in [
        PlannerCalendarRange.day,
        PlannerCalendarRange.week,
      ]) {
        final here = calendarWindow(anchor, range).toSet();
        final next = calendarWindow(range.step(anchor, 1), range).toSet();
        final back = calendarWindow(range.step(anchor, -1), range).toSet();
        expect(here.intersection(next), isEmpty, reason: '$range forwards');
        expect(here.intersection(back), isEmpty, reason: '$range backwards');
      }
    });

    test("consecutive month pages cover the calendar without a gap", () {
      // The other half of the spill: January's own days and February's own days
      // are disjoint and adjacent, so paging forward loses nothing even though
      // the two pages overlap on padding.
      final january = calendarWindow(d(2026, 1, 10), PlannerCalendarRange.month)
          .where((day) => day.midnight.month == 1)
          .toSet();
      final february =
          calendarWindow(PlannerCalendarRange.month.step(d(2026, 1, 10), 1),
              PlannerCalendarRange.month)
              .where((day) => day.midnight.month == 2)
              .toSet();
      expect(january.length, 31);
      expect(february.length, 28);
      expect(january.intersection(february), isEmpty);
      expect(january.reduce((a, b) => a > b ? a : b) + 1,
          february.reduce((a, b) => a < b ? a : b));
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