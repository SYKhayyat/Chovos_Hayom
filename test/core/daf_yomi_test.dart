import 'package:flutter_test/flutter_test.dart';

import 'package:chovos_hayom/core/daf_yomi.dart';

/// The two calendar-computed cycles, which had no test at all.
///
/// Three production files import this — `cycles.dart`, `naming.dart` and
/// `cycles_screen.dart` — and what it answers is *today's daf*, on the screen a
/// Daf Yomi learner opens first. It is also the only place in the app that
/// delegates an answer to a third-party package, which makes it the one place a
/// dependency bump can change what the user is told without changing a line
/// here.
///
/// The dates below are checked against the published cycle rather than against
/// what the code returns, so this is a test of the answer and not a snapshot of
/// the implementation.
void main() {
  CalendarCycle cycleFor(String id) =>
      CalendarCycle.all.firstWhere((c) => c.id == id);

  group('Bavli', () {
    final bavli = cycleFor(CalendarCycle.bavliId);

    test('the 14th cycle began with Berachos 2 on 2020-01-05', () {
      final day = bavli.unitsOn(DateTime(2020, 1, 5)).single;

      expect(day.sefer, 'Berachos');
      expect(day.unit, 2);
      expect(day.seferHebrew, isNotEmpty,
          reason: 'the Hebrew name is what a Hebrew reader sees; a cycle that '
              'only had the transliteration would render the mesechta in '
              'English inside a Hebrew line');
    });

    test('the day after is the next daf', () {
      expect(bavli.unitsOn(DateTime(2020, 1, 6)).single.unit, 3);
    });

    test('it rolls over to the next mesechta rather than running off the end',
        () {
      // Berachos ends at daf 64, so day 63 of the cycle is the last one and the
      // day after starts Shabbos.
      final last = bavli.unitsOn(DateTime(2020, 3, 7)).single;
      final next = bavli.unitsOn(DateTime(2020, 3, 8)).single;

      expect((last.sefer, last.unit), ('Berachos', 64));
      expect((next.sefer, next.unit), ('Shabbos', 2));
    });

    test('a date before the cycle began answers nothing, rather than throwing',
        () {
      // The cycle starts in 1923. `unitsOn` is called straight from a build
      // method, so the out-of-range case has to be an empty list and not an
      // exception — this is what the bare `catch (_)` is for.
      expect(bavli.unitsOn(DateTime(1900, 1, 1)), isEmpty);
    });

    test('every day of a year has exactly one daf', () {
      // The Bavli cycle skips nothing — not Yom Kippur, not Tisha B'Av. A gap
      // here would show the user an empty "today" on a day they are expected to
      // learn.
      var date = DateTime(2026, 1, 1);
      while (date.year == 2026) {
        expect(bavli.unitsOn(date), hasLength(1), reason: '$date');
        date = DateTime(date.year, date.month, date.day + 1);
      }
    });
  });

  group('Yerushalmi', () {
    final yerushalmi = cycleFor(CalendarCycle.yerushalmiId);

    test('an ordinary day has one daf', () {
      final day = yerushalmi.unitsOn(DateTime(2026, 1, 5));

      expect(day, hasLength(1));
      expect(day.single.unit, greaterThan(0));
      expect(day.single.sefer, isNotEmpty);
    });

    test('Yom Kippur and Tisha B\'Av are skipped, not reported as daf 0', () {
      // The calculator returns daf 0 on those two days. Passing that through
      // would put "daf 0" on the dashboard; the cycle has no unit that day.
      expect(yerushalmi.unitsOn(DateTime(2026, 9, 21)), isEmpty,
          reason: 'Yom Kippur 5787');
      expect(yerushalmi.unitsOn(DateTime(2026, 7, 23)), isEmpty,
          reason: "Tisha B'Av 5786");
    });

    test('the day either side of a skip still has its daf', () {
      expect(yerushalmi.unitsOn(DateTime(2026, 9, 20)), hasLength(1));
      expect(yerushalmi.unitsOn(DateTime(2026, 9, 22)), hasLength(1));
    });
  });

  test('both cycles are listed, with distinct ids', () {
    expect(CalendarCycle.all.map((c) => c.id).toSet(),
        {CalendarCycle.bavliId, CalendarCycle.yerushalmiId});
    for (final c in CalendarCycle.all) {
      expect(c.name, isNotEmpty);
      expect(c.description, isNotEmpty);
    }
  });
}
