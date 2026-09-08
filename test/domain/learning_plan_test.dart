import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

/// The planner data model and the on-demand scheduler of Phase 1 (#10): what a
/// plan is, how it serialises, and the window-generated schedule it produces.
/// Written before the implementation so the contract is the tests.
void main() {
  DayInfo info({
    int ordinal = 0,
    int weekday = DateTime.monday,
    int dayOfMonth = 1,
    int? hebrewDayOfMonth,
    int? hebrewMonth,
  }) =>
      DayInfo(
        day: Day(ordinal),
        weekday: weekday,
        dayOfMonth: dayOfMonth,
        hebrewDayOfMonth: hebrewDayOfMonth,
        hebrewMonth: hebrewMonth,
        hebrewYear: hebrewDayOfMonth == null ? null : 5787,
      );

  /// A Gregorian reader for the schedule tests: real weekdays and day-of-month,
  /// no Hebrew fields.
  DayInfo reader(Day d) => DayInfo(
        day: d,
        weekday: d.weekday,
        dayOfMonth: d.midnight.day,
      );

  LearningPlan plan() => const LearningPlan(
        id: 'shas',
        name: 'Shas',
        displayCalendar: RuleCalendar.hebrew,
        assignments: [
          PlanAssignment(
            id: 'gemara',
            rule: DailyRule(),
            targetNodeId: 'shas.bavli',
          ),
          PlanAssignment(
            id: 'chumash',
            rule: OrRule([
              WeekdayRule(weekdays: {DateTime.wednesday}),
              HebrewDayRule(day: 1),
            ]),
            targetNodeId: 'torah',
            unitsPerFiring: 2,
            label: 'blitz',
          ),
        ],
      );

  group('PlanAssignment', () {
    test('round-trips with and without target, units and label', () {
      const a = PlanAssignment(
        id: 'a',
        rule: DailyRule(),
        targetNodeId: 'x',
        unitsPerFiring: 2,
        label: 'blitz',
      );
      expect(PlanAssignment.fromJson(a.toJson()), a);

      const bare = PlanAssignment(
        id: 'b',
        rule: WeekdayRule(weekdays: {DateTime.saturday}),
      );
      expect(PlanAssignment.fromJson(bare.toJson()), bare);
    });

    test('is a value type', () {
      const a = PlanAssignment(id: 'a', rule: DailyRule());
      expect(a, const PlanAssignment(id: 'a', rule: DailyRule()));
      expect(a, isNot(const PlanAssignment(id: 'b', rule: DailyRule())));
      expect(a, isNot(const PlanAssignment(id: 'a', rule: NotRule(DailyRule()))));
    });

    test('a non-positive unitsPerFiring is refused by JSON', () {
      expect(
        () => PlanAssignment.fromJson(
            {'id': 'a', 'rule': {'type': 'daily'}, 'unitsPerFiring': -1}),
        throwsFormatException,
      );
      expect(
        () => PlanAssignment.fromJson(
            {'id': 'a', 'rule': {'type': 'daily'}, 'unitsPerFiring': 0}),
        throwsFormatException,
      );
    });

    test('a malformed inner rule is refused by JSON', () {
      expect(
        () => PlanAssignment.fromJson(
            {'id': 'a', 'rule': {'type': 'nonsense'}}),
        throwsFormatException,
      );
    });
  });

  group('LearningPlan', () {
    test('round-trips', () {
      final p = plan();
      expect(LearningPlan.fromJson(p.toJson()), p);
    });

    test('is a value type', () {
      expect(plan(), plan());
      expect(plan(), isNot(const LearningPlan(id: 'other', name: 'Shas')));
      expect(
        plan(),
        isNot(const LearningPlan(id: 'shas', name: 'Shas',
            displayCalendar: RuleCalendar.gregorian)),
      );
    });

    test('hasHebrewRules reflects the assignments', () {
      expect(plan().hasHebrewRules, isTrue);
      const gregorian = LearningPlan(
        id: 'g',
        name: 'G',
        assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
      );
      expect(gregorian.hasHebrewRules, isFalse);
    });

    test('unknown display calendar falls back to Gregorian', () {
      final json = plan().toJson()..['displayCalendar'] = 'lunar';
      expect(LearningPlan.fromJson(json).displayCalendar, RuleCalendar.gregorian);
    });
  });

  group('PlannerSchedule.assignmentsOn', () {
    test('returns the matching assignments in plan order', () {
      final p = plan();
      final wednesday = info(
        weekday: DateTime.wednesday,
        dayOfMonth: 15,
        hebrewDayOfMonth: 15,
        hebrewMonth: HebrewMonth.tishrei,
      );
      final result = PlannerSchedule.assignmentsOn(p, wednesday);
      expect(result.map((a) => a.id), ['gemara', 'chumash']);
    });

    test('returns nothing when no rule fires', () {
      const p = LearningPlan(
        id: 'p',
        name: 'P',
        assignments: [
          PlanAssignment(
              id: 'a', rule: WeekdayRule(weekdays: {DateTime.saturday})),
        ],
      );
      final monday = info(weekday: DateTime.monday, dayOfMonth: 15);
      expect(PlannerSchedule.assignmentsOn(p, monday), isEmpty);
    });

    test('overlapping assignments both fire — daily + Wednesdays', () {
      final p = plan();
      final result = PlannerSchedule.assignmentsOn(
        p,
        info(
          weekday: DateTime.wednesday,
          dayOfMonth: 15,
          hebrewDayOfMonth: 15,
          hebrewMonth: HebrewMonth.tishrei,
        ),
      );
      expect(result, hasLength(2));
    });

    test('a Hebrew rule without Hebrew fields fails loudly through the engine',
        () {
      const p = LearningPlan(
        id: 'h',
        name: 'H',
        assignments: [PlanAssignment(id: 'a', rule: HebrewDayRule(day: 1))],
      );
      expect(() => PlannerSchedule.assignmentsOn(p, info()), throwsStateError);
    });
  });

  group('PlannerSchedule.daysOn', () {
    test('yields every day on which any assignment fires, ascending, deduped',
        () {
      const p = LearningPlan(
        id: 'p',
        name: 'P',
        assignments: [
          PlanAssignment(
              id: 'a', rule: WeekdayRule(weekdays: {DateTime.monday})),
          PlanAssignment(id: 'b', rule: DayOfMonthRule(days: {1})),
        ],
      );
      // Day(0) is 1970-01-01, a Thursday. Mondays in 0..13 are ordinals 4, 11;
      // day-of-month 1 in 0..13 is ordinal 0 (Jan 1). Union: 0, 4, 11.
      final days =
          PlannerSchedule.daysOn(p, reader, const Day(0), const Day(13)).toList();
      expect(days, [const Day(0), const Day(4), const Day(11)]);
    });

    test('a single-day window yields that day when it fires, else nothing', () {
      const monday = LearningPlan(
        id: 'm',
        name: 'M',
        assignments: [
          PlanAssignment(
              id: 'a', rule: WeekdayRule(weekdays: {DateTime.monday})),
        ],
      );
      expect(
        PlannerSchedule.daysOn(monday, reader, const Day(4), const Day(4))
            .toList(),
        [const Day(4)],
      );
      expect(
        PlannerSchedule.daysOn(monday, reader, const Day(3), const Day(3))
            .toList(),
        isEmpty,
      );
    });

    test('an inverted window yields nothing', () {
      const p = LearningPlan(
        id: 'p',
        name: 'P',
        assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
      );
      expect(
        PlannerSchedule.daysOn(p, reader, const Day(13), const Day(0)).toList(),
        isEmpty,
      );
    });

    test('adjacent windows compose with a full window', () {
      const p = LearningPlan(
        id: 'p',
        name: 'P',
        assignments: [
          PlanAssignment(
              id: 'a', rule: WeekdayRule(weekdays: {DateTime.monday})),
        ],
      );
      final left = PlannerSchedule.daysOn(p, reader, const Day(0), const Day(10));
      final right = PlannerSchedule.daysOn(p, reader, const Day(11), const Day(20));
      final whole = PlannerSchedule.daysOn(p, reader, const Day(0), const Day(20));
      expect([...left, ...right], whole.toList());
    });

    test('a twenty-year daily window generates every day, in bounds, on demand',
        () {
      const p = LearningPlan(
        id: 'p',
        name: 'P',
        assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
      );
      const from = Day(0);
      final to = from + 7300;
      final days = PlannerSchedule.daysOn(p, reader, from, to).toList();
      expect(days, hasLength(7301));
      expect(days.first, from);
      expect(days.last, to);
      for (final d in days) {
        expect(d, greaterThanOrEqualTo(from));
        expect(d, lessThanOrEqualTo(to));
      }
    });

    test('a Hebrew rule over a synthetic month-cycle fires every 30 days', () {
      const p = LearningPlan(
        id: 'p',
        name: 'P',
        assignments: [PlanAssignment(id: 'a', rule: HebrewDayRule(day: 1))],
      );
      DayInfo hebrewReader(Day d) => DayInfo(
            day: d,
            weekday: d.weekday,
            dayOfMonth: d.midnight.day,
            hebrewDayOfMonth: (d.ordinal % 30) + 1,
            hebrewMonth: ((d.ordinal ~/ 30) % 13) + 1,
          );
      final days = PlannerSchedule.daysOn(p, hebrewReader, const Day(0), const Day(200)).toList();
      expect(days, [for (var o = 0; o <= 200; o += 30) Day(o)]);
    });

    test('a Hebrew rule with a reader that supplies no Hebrew fails loudly',
        () {
      const p = LearningPlan(
        id: 'p',
        name: 'P',
        assignments: [PlanAssignment(id: 'a', rule: HebrewDayRule(day: 1))],
      );
      expect(
        () => PlannerSchedule.daysOn(p, reader, const Day(0), const Day(5)).toList(),
        throwsStateError,
      );
    });
  });
}