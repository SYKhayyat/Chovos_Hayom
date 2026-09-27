import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/usecases/day_amount.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

/// A plan states *how much*, not just *when* (#24). The contract is a single
/// precedence chain and one special value: `0` is a real amount meaning "nothing
/// on this day", which is how a day off is expressed — there is no day-off flag,
/// because a flag and an amount would be two ways to say one thing and they could
/// disagree.
void main() {
  /// Day(0) is 1970-01-01, a Thursday. Real weekday, no Hebrew fields.
  DayInfo info(Day day) => DayInfo(
        day: day,
        weekday: day.weekday,
        dayOfMonth: day.midnight.day,
      );

  LearningPlan plan({
    int unitsPerDay = 10,
    Map<int, int> weekdayAmounts = const {},
    Map<Day, int> dateAmounts = const {},
  }) =>
      LearningPlan(
        id: 'p',
        name: 'P',
        unitsPerDay: unitsPerDay,
        weekdayAmounts: weekdayAmounts,
        dateAmounts: dateAmounts,
      );

  // Ordinals for the weekdays we care about, computed rather than hard-coded so
  // a mistake in the calendar maths cannot quietly move the fixtures.
  const monday = Day(4); // 1970-01-05
  const tuesday = Day(5);
  const thursday = Day(7);

  group('precedence', () {
    test('a plain day answers the plan base', () {
      expect(DayAmount.of(plan(), info(monday)), 10);
    });

    test('a weekday override beats the base', () {
      final p = plan(weekdayAmounts: {DateTime.tuesday: 5});
      expect(DayAmount.of(p, info(tuesday)), 5);
      expect(DayAmount.of(p, info(monday)), 10, reason: 'other days unaffected');
    });

    test('a date override beats a weekday override', () {
      final p = plan(
        weekdayAmounts: {DateTime.tuesday: 5},
        dateAmounts: {tuesday: 99},
      );
      expect(DayAmount.of(p, info(tuesday)), 99);
    });

    test('a date override beats the base with no weekday set', () {
      expect(DayAmount.of(plan(dateAmounts: {monday: 3}), info(monday)), 3);
    });

    test('overrides are not conflicts: they layer by specificity', () {
      // Sunday has nothing said about it anywhere, so it is the base. That is
      // the hierarchy working, not three entries fighting.
      final p = plan(
        unitsPerDay: 10,
        weekdayAmounts: {DateTime.tuesday: 5, DateTime.thursday: 7},
        dateAmounts: {monday: 1, thursday: 0},
      );
      expect(DayAmount.of(p, info(monday)), 1);
      expect(DayAmount.of(p, info(tuesday)), 5);
      expect(DayAmount.of(p, info(thursday)), 0, reason: 'date beats weekday');
      expect(DayAmount.of(p, info(const Day(6))), 10, reason: 'Wednesday, unsaid');
    });
  });

  group('arbitrary weekday subsets', () {
    test('one weekday alone', () {
      final p = plan(weekdayAmounts: {DateTime.wednesday: 20});
      expect(DayAmount.of(p, info(const Day(6))), 20);
      expect(DayAmount.of(p, info(const Day(4))), 10);
    });

    test('two weekdays, each with its own amount', () {
      // "Tuesday and Thursday different" — a two-way Shabbos/weekday split
      // cannot say this.
      final p = plan(weekdayAmounts: {DateTime.tuesday: 5, DateTime.thursday: 15});
      expect(DayAmount.of(p, info(tuesday)), 5);
      expect(DayAmount.of(p, info(thursday)), 15);
      expect(DayAmount.of(p, info(monday)), 10);
    });

    test('all seven days set is legal and each is its own', () {
      final p = plan(
        weekdayAmounts: {
          for (var w = DateTime.monday; w <= DateTime.sunday; w++) w: w,
        },
      );
      for (var w = DateTime.monday; w <= DateTime.sunday; w++) {
        expect(DayAmount.of(p, info(monday + (w - DateTime.monday))), w);
      }
    });
  });

  group('zero is an amount, not an absence', () {
    test('a date amount of 0 is a day off', () {
      final p = plan(dateAmounts: {monday: 0});
      expect(DayAmount.of(p, info(monday)), 0);
    });

    test('a weekday amount of 0 rests that weekday', () {
      final p = plan(weekdayAmounts: {DateTime.sunday: 0});
      expect(DayAmount.of(p, info(const Day(3))), 0); // 1970-01-04, a Sunday
      expect(DayAmount.of(p, info(monday)), 10);
    });

    test('a date of 0 beats a weekday of 5', () {
      final p = plan(
        weekdayAmounts: {DateTime.tuesday: 5},
        dateAmounts: {tuesday: 0},
      );
      expect(DayAmount.of(p, info(tuesday)), 0,
          reason: 'the most specific statement wins, even when it is zero');
    });

    test('a base of 0 rests the whole plan', () {
      expect(DayAmount.of(plan(unitsPerDay: 0), info(monday)), 0);
    });
  });

  group('persistence', () {
    test('amounts and both override maps round-trip', () {
      final p = plan(
        unitsPerDay: 12,
        weekdayAmounts: {DateTime.tuesday: 5, DateTime.sunday: 0},
        dateAmounts: {monday: 0, thursday: 30},
      );
      expect(LearningPlan.fromJson(p.toJson()), p);
    });

    test('a plan with no amounts still round-trips', () {
      const bare = LearningPlan(id: 'b', name: 'B');
      expect(LearningPlan.fromJson(bare.toJson()), bare);
    });

    test('a plan written before this feature loads with the base amount', () {
      // Backwards compatibility: JSON with no amount keys must mean one unit a
      // day, not a crash and not zero.
      final loaded = LearningPlan.fromJson({'id': 'p', 'name': 'P'});
      expect(loaded.unitsPerDay, 1);
      expect(loaded.weekdayAmounts, isEmpty);
      expect(loaded.dateAmounts, isEmpty);
    });

    test('a negative base is refused', () {
      expect(
        () => LearningPlan.fromJson(
            {'id': 'p', 'name': 'P', 'unitsPerDay': -1}),
        throwsFormatException,
      );
    });

    test('a negative override amount is refused', () {
      expect(
        () => LearningPlan.fromJson({
          'id': 'p',
          'name': 'P',
          'weekdayAmounts': {'2': -1},
        }),
        throwsFormatException,
      );
      expect(
        () => LearningPlan.fromJson({
          'id': 'p',
          'name': 'P',
          'dateAmounts': {'1970-01-05': -2},
        }),
        throwsFormatException,
      );
    });

    test('an out-of-range weekday is refused, not silently unreachable', () {
      // A stored 0 or 8 would be an override that can never fire — a setting the
      // user believes is in force and that silently does nothing.
      for (final bad in ['0', '8', '-1']) {
        expect(
          () => LearningPlan.fromJson({
            'id': 'p',
            'name': 'P',
            'weekdayAmounts': {bad: 5},
          }),
          throwsFormatException,
          reason: 'weekday $bad must be refused',
        );
      }
    });
  });

  group('value equality', () {
    test('a changed amount makes plans unequal', () {
      expect(plan(), plan());
      expect(plan(), isNot(plan(unitsPerDay: 11)));
      expect(
        plan(),
        isNot(plan(weekdayAmounts: {DateTime.tuesday: 5})),
      );
      expect(plan(), isNot(plan(dateAmounts: {monday: 5})));
    });

    test('a zero amount differs from a missing one', () {
      expect(
        plan(dateAmounts: {monday: 0}),
        isNot(plan(dateAmounts: {monday: 1})),
      );
      expect(plan(dateAmounts: {monday: 0}), isNot(plan()));
    });

    test('equal maps have equal hashes', () {
      expect(
        plan(weekdayAmounts: {DateTime.tuesday: 5, DateTime.sunday: 1}).hashCode,
        plan(weekdayAmounts: {DateTime.sunday: 1, DateTime.tuesday: 5}).hashCode,
      );
    });
  });
}
