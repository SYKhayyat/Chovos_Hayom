import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

/// The recurrence-rule half of planner Phase 1 (#10): the rule model, its
/// combinations, its calendar declaration, and its JSON contract. Written
/// before the implementation so the contract is the tests.
void main() {
  DayInfo info({
    int ordinal = 0,
    int weekday = DateTime.monday,
    int dayOfMonth = 1,
    int? hebrewDayOfMonth,
    int? hebrewMonth,
    int? hebrewYear,
  }) =>
      DayInfo(
        day: Day(ordinal),
        weekday: weekday,
        dayOfMonth: dayOfMonth,
        hebrewDayOfMonth: hebrewDayOfMonth,
        hebrewMonth: hebrewMonth,
        hebrewYear: hebrewYear,
      );

  void roundTrips(RecurrenceRule rule) {
    final json = rule.toJson();
    final back = RecurrenceRule.fromJson(json);
    expect(back, rule, reason: '$json did not round-trip');
  }

  group('DailyRule', () {
    test('matches every day, Hebrew fields present or not', () {
      const rule = DailyRule();
      expect(rule.matches(info()), isTrue);
      expect(rule.matches(info(weekday: DateTime.sunday, dayOfMonth: 31)), isTrue);
      expect(
        rule.matches(
            info(hebrewDayOfMonth: 1, hebrewMonth: HebrewMonth.tishrei)),
        isTrue,
      );
    });

    test('declares a calendar and round-trips', () {
      const rule = DailyRule();
      expect(rule.calendar, RuleCalendar.gregorian);
      roundTrips(rule);
    });
  });

  group('WeekdayRule', () {
    test('matches exactly the listed weekdays', () {
      const rule = WeekdayRule(weekdays: {DateTime.monday, DateTime.friday});
      expect(rule.matches(info(weekday: DateTime.monday)), isTrue);
      expect(rule.matches(info(weekday: DateTime.friday)), isTrue);
      expect(rule.matches(info(weekday: DateTime.saturday)), isFalse);
      expect(rule.matches(info(weekday: DateTime.tuesday)), isFalse);
    });

    test('an empty set matches nothing', () {
      const rule = WeekdayRule(weekdays: {});
      expect(rule.matches(info()), isFalse);
    });

    test('declares a calendar, round-trips, and compares order-insensitively',
        () {
      const rule = WeekdayRule(weekdays: {DateTime.friday, DateTime.monday});
      expect(rule.calendar, RuleCalendar.gregorian);
      roundTrips(rule);
      expect(rule,
          const WeekdayRule(weekdays: {DateTime.monday, DateTime.friday}));
      expect(rule, isNot(const WeekdayRule(weekdays: {DateTime.friday})));
    });
  });

  group('DayOfMonthRule', () {
    test('matches only the listed Gregorian day numbers', () {
      const rule = DayOfMonthRule(days: {1, 15});
      expect(rule.matches(info(dayOfMonth: 1)), isTrue);
      expect(rule.matches(info(dayOfMonth: 15)), isTrue);
      expect(rule.matches(info(dayOfMonth: 2)), isFalse);
      expect(rule.matches(info(dayOfMonth: 31)), isFalse);
    });

    test('an empty set matches nothing', () {
      const rule = DayOfMonthRule(days: {});
      expect(rule.matches(info()), isFalse);
    });

    test('declares a calendar and round-trips', () {
      const rule = DayOfMonthRule(days: {31, 1});
      expect(rule.calendar, RuleCalendar.gregorian);
      roundTrips(rule);
    });
  });

  group('HebrewDayRule', () {
    test('matches a day of every Hebrew month when no month is pinned', () {
      const rule = HebrewDayRule(day: 1);
      expect(
          rule.matches(
              info(hebrewDayOfMonth: 1, hebrewMonth: HebrewMonth.nissan)),
          isTrue);
      expect(
          rule.matches(
              info(hebrewDayOfMonth: 1, hebrewMonth: HebrewMonth.tishrei)),
          isTrue);
      expect(
          rule.matches(
              info(hebrewDayOfMonth: 2, hebrewMonth: HebrewMonth.nissan)),
          isFalse);
    });

    test('with a pinned month, matches only that month', () {
      const rule = HebrewDayRule(day: 1, month: HebrewMonth.tishrei);
      expect(
          rule.matches(
              info(hebrewDayOfMonth: 1, hebrewMonth: HebrewMonth.tishrei)),
          isTrue);
      expect(
          rule.matches(
              info(hebrewDayOfMonth: 1, hebrewMonth: HebrewMonth.nissan)),
          isFalse);
    });

    test('the 30th matches only months the reader reports a 30th for', () {
      const rule = HebrewDayRule(day: 30);
      expect(
          rule.matches(
              info(hebrewDayOfMonth: 30, hebrewMonth: HebrewMonth.cheshvan)),
          isTrue);
      expect(
          rule.matches(
              info(hebrewDayOfMonth: 29, hebrewMonth: HebrewMonth.cheshvan)),
          isFalse);
    });

    test('fails loudly when the Hebrew fields are absent', () {
      const rule = HebrewDayRule(day: 1);
      expect(() => rule.matches(info()), throwsStateError);
    });

    test('declares the Hebrew calendar and round-trips with and without month',
        () {
      const pinned = HebrewDayRule(day: 1, month: HebrewMonth.tishrei);
      const unpinned = HebrewDayRule(day: 1);
      expect(pinned.calendar, RuleCalendar.hebrew);
      expect(unpinned.calendar, RuleCalendar.hebrew);
      roundTrips(pinned);
      roundTrips(unpinned);
      expect(pinned, isNot(unpinned));
    });
  });

  group('combinations', () {
    test('OrRule fires when any child fires', () {
      const rule = OrRule([
        WeekdayRule(weekdays: {DateTime.saturday}),
        DayOfMonthRule(days: {1}),
      ]);
      expect(rule.matches(info(weekday: DateTime.saturday, dayOfMonth: 15)),
          isTrue);
      expect(rule.matches(info(weekday: DateTime.monday, dayOfMonth: 1)),
          isTrue);
      expect(rule.matches(info(weekday: DateTime.monday, dayOfMonth: 15)),
          isFalse);
    });

    test('an empty OrRule matches nothing', () {
      expect(const OrRule([]).matches(info()), isFalse);
    });

    test('AndRule fires only when every child fires', () {
      const rule = AndRule([
        DayOfMonthRule(days: {1}),
        WeekdayRule(weekdays: {DateTime.wednesday}),
      ]);
      expect(rule.matches(info(weekday: DateTime.wednesday, dayOfMonth: 1)),
          isTrue);
      expect(rule.matches(info(weekday: DateTime.monday, dayOfMonth: 1)),
          isFalse);
    });

    test('an empty AndRule matches everything', () {
      expect(const AndRule([]).matches(info()), isTrue);
    });

    test('"every day except Shabbos" is an AndRule of daily and not-Shabbos',
        () {
      const rule = AndRule([
        DailyRule(),
        NotRule(WeekdayRule(weekdays: {DateTime.saturday})),
      ]);
      expect(rule.matches(info(weekday: DateTime.friday)), isTrue);
      expect(rule.matches(info(weekday: DateTime.saturday)), isFalse);
      expect(rule.matches(info(weekday: DateTime.sunday)), isTrue);
    });

    test('a composite is Hebrew when any part is', () {
      expect(
        const OrRule([DailyRule(), HebrewDayRule(day: 1)]).calendar,
        RuleCalendar.hebrew,
      );
      expect(
        const OrRule(
                [DailyRule(), WeekdayRule(weekdays: {DateTime.monday})])
            .calendar,
        RuleCalendar.gregorian,
      );
      expect(
        const NotRule(HebrewDayRule(day: 1)).calendar,
        RuleCalendar.hebrew,
      );
    });

    test('nested rules round-trip', () {
      const rule = AndRule([
        OrRule([
          DailyRule(),
          HebrewDayRule(day: 1, month: HebrewMonth.tishrei),
        ]),
        NotRule(WeekdayRule(weekdays: {DateTime.saturday})),
      ]);
      roundTrips(rule);
    });
  });

  group('JSON', () {
    test('unknown rule types are refused loudly', () {
      expect(() => RecurrenceRule.fromJson({'type': 'fortnightly'}),
          throwsFormatException);
      expect(() => RecurrenceRule.fromJson({}), throwsFormatException);
    });

    test('invalid day numbers in a DayOfMonthRule are refused', () {
      expect(
          () => RecurrenceRule.fromJson({'type': 'dayOfMonth', 'days': [32]}),
          throwsFormatException);
      expect(
          () => RecurrenceRule.fromJson({'type': 'dayOfMonth', 'days': [0]}),
          throwsFormatException);
    });

    test('invalid weekdays are refused', () {
      expect(
          () => RecurrenceRule.fromJson({'type': 'weekdays', 'weekdays': [0]}),
          throwsFormatException);
      expect(
          () => RecurrenceRule.fromJson({'type': 'weekdays', 'weekdays': [8]}),
          throwsFormatException);
    });

    test('an out-of-range Hebrew day or month is refused', () {
      expect(
          () => RecurrenceRule.fromJson({'type': 'hebrewDay', 'day': 0}),
          throwsFormatException);
      expect(
          () => RecurrenceRule.fromJson({'type': 'hebrewDay', 'day': 31}),
          throwsFormatException);
      expect(
          () => RecurrenceRule.fromJson(
              {'type': 'hebrewDay', 'day': 1, 'month': 0}),
          throwsFormatException);
      expect(
          () => RecurrenceRule.fromJson(
              {'type': 'hebrewDay', 'day': 1, 'month': 14}),
          throwsFormatException);
    });

    test('a malformed composite is refused', () {
      expect(() => RecurrenceRule.fromJson({'type': 'or'}),
          throwsFormatException);
      expect(() => RecurrenceRule.fromJson({'type': 'not', 'rule': {}}),
          throwsFormatException);
      expect(
          () => RecurrenceRule.fromJson(
              {'type': 'and', 'rules': [{'type': 'nonsense'}]}),
          throwsFormatException);
    });
  });

  group('DayInfo', () {
    test('is a value: equal fields compare equal, different fields do not', () {
      expect(info(ordinal: 5, weekday: DateTime.friday),
          info(ordinal: 5, weekday: DateTime.friday));
      expect(info(ordinal: 5), isNot(info(ordinal: 6)));
      expect(info(hebrewDayOfMonth: 1), isNot(info(hebrewDayOfMonth: 2)));
    });
  });
}