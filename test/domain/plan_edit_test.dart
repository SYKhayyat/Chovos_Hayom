import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/core/planner_dates.dart' as core_planner;
import 'package:chovos_hayom/domain/usecases/day_amount.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/plan_edit.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

/// #43 — `+` and `−` on a day, as **planning** commands.
///
/// **The distinction from #42 is the whole file.** A checkbox says "I did this"
/// and writes the log. `+`/`−` say "this is now what the day asks for" and touch
/// the plan only. Nothing here claims anything was learned, and a day can ask
/// for eight units and have none of them done — a legitimate state, not an
/// error.
void main() {
  // A Thursday and the Thursday after, because the "past days do not move on
  // their own" claim is only visible if there is a later day to *not* move.
  final thursday = Day.of(DateTime.utc(2026, 3, 5));
  final nextThursday = thursday + 7;

  /// [weekdayAmount] null means "no override"; **0 means a deliberate day off**,
  /// and the two are different plans. A helper that collapsed them would have
  /// been the same bug the whole planner is careful about, one level down.
  LearningPlan plan({int unitsPerDay = 2, int? weekdayAmount}) => LearningPlan(
    id: 'daf-yomi',
    name: 'Daf Yomi',
    unitsPerDay: unitsPerDay,
    weekdayAmounts: weekdayAmount == null
        ? const {}
        : {DateTime.thursday: weekdayAmount},
    assignments: const [PlanAssignment(id: 'a', rule: DailyRule())],
  );

  /// What the day asks for, which is the only thing these commands change.
  int asks(LearningPlan p, Day day) => DayAmount.of(p, _info(day));

  group('add', () {
    test('raises the day it is given, and only that day', () {
      final next = PlanEdit.addUnits(plan(), thursday, 3);
      expect(asks(next, thursday), 5);
      expect(
        asks(next, thursday + 1),
        2,
        reason: 'the next day is untouched: no reflow, and none is implied',
      );
      expect(asks(next, nextThursday), 2);
    });

    test('works on a day in the past, identically', () {
      // "I did extra on Tuesday" is the ordinary case, not an exotic one, and it
      // changes that date's target and nothing else.
      final tuesday = Day.of(DateTime.utc(2026, 3, 3));
      final next = PlanEdit.addUnits(plan(), tuesday, 4);
      expect(asks(next, tuesday), 6);
      expect(
        asks(next, thursday),
        2,
        reason:
            'later days do not move on their own; recompute is #44 and is '
            'asked for explicitly',
      );
    });

    test('a plan that was off that day can still be added to', () {
      // A weekday override of 0 is a day off. Adding must be able to lift it, or
      // there is no way to say "on this Thursday I did after all" — and a day
      // off is an amount, not a flag, so it is overridable.
      final off = plan(weekdayAmount: 0, unitsPerDay: 4);
      // The day asked for 0, so +3 asks for 3 — raised from what the day said,
      // not from the plan's base, or a day off could not be lifted by one unit.
      final next = PlanEdit.addUnits(off, thursday, 3);
      expect(
        asks(next, thursday),
        3,
        reason: 'raised from the day\'s own answer, which was 0',
      );
    });

    test('and so can a plan whose rule would not have fired', () {
      // A weekday plan on a day the rule skips. Forcing it onto the day is
      // exactly what this is for, and it works because the plan still carries a
      // rule — a date override alone would never make it fire.
      const weekdays = LearningPlan(
        id: 'weekdays',
        name: 'Weekdays',
        unitsPerDay: 2,
        assignments: [
          PlanAssignment(
            id: 'a',
            rule: WeekdayRule(weekdays: {DateTime.monday}),
          ),
        ],
      );
      final next = PlanEdit.addUnits(weekdays, thursday, 1);
      expect(
        asks(next, thursday),
        3,
        reason:
            'base 2 plus one, and the date override is what makes the '
            'plan fire on a day its rule skips',
      );
      expect(next.dateAmounts[thursday], 3);
      expect(
        next.assignments.single.rule,
        const WeekdayRule(weekdays: {DateTime.monday}),
        reason:
            'and the rule is untouched — a date override raises the day '
            'without rewriting when the plan fires',
      );
    });

    test('adding zero changes nothing observable', () {
      final next = PlanEdit.addUnits(plan(), thursday, 0);
      expect(asks(next, thursday), 2);
    });
  });

  group('remove', () {
    test('lowers the day by one unit at a time', () {
      final next = PlanEdit.removeUnit(plan(unitsPerDay: 5), thursday);
      expect(asks(next, thursday), 4);
    });

    test('never goes below zero, and says nothing rather than throwing', () {
      // Asking for fewer units than the day had is a limit, not an error — the
      // same rule the amount prompt already applies, so the two agree.
      final next = PlanEdit.removeUnit(plan(unitsPerDay: 1), thursday);
      expect(asks(next, thursday), 0);
    });

    test('does nothing at zero rather than going negative', () {
      final next = PlanEdit.removeUnit(plan(unitsPerDay: 0), thursday);
      expect(asks(next, thursday), 0);
    });
  });

  group('removing the plan from the day is not the same as an amount of zero', () {
    test('a zero says the plan was scheduled and asked for nothing', () {
      final off = PlanEdit.removeUnit(plan(unitsPerDay: 1), thursday);
      expect(asks(off, thursday), 0);
      expect(
        off.dateAmounts.containsKey(thursday),
        isTrue,
        reason: 'the day is still answered — the plan was on it',
      );
    });

    test('removing the plan says it had nothing to do that day at all', () {
      // A daily plan, removed from one day. The day then asks for nothing,
      // where a zero would have left it asking for nothing *and on the record*.
      final removed = PlanEdit.removePlanFromDay(plan(), thursday);
      expect(
        asks(removed, thursday),
        2,
        reason:
            'a daily plan still fires, so the base applies again — the '
            'difference from a zero is the *record*, which the next assertion '
            'is about rather than the number',
      );
      expect(
        removed.dateAmounts.containsKey(thursday),
        isFalse,
        reason:
            'no answer for the day, which is what "not scheduled" means — '
            'and it is why the two are distinct and both are offered',
      );
    });

    test('so removing undoes a lift made on that day, and nothing else', () {
      // The difference is only visible where a day was lifted above its own
      // answer, because that is the only case where the two differ in number.
      // A plan whose weekday already says 9 is **not** overridden on Thursday,
      // so removing Thursday must not touch it — an earlier version of this test
      // expected 2 here and was wrong about what the command does.
      const p = LearningPlan(
        id: 'p',
        name: 'P',
        unitsPerDay: 2,
        weekdayAmounts: {DateTime.thursday: 9},
        assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
      );
      expect(asks(p, thursday), 9);
      expect(
        asks(PlanEdit.removePlanFromDay(p, thursday), thursday),
        9,
        reason:
            'no date override, so there was nothing to remove; the '
            'weekday\'s own answer stands',
      );
      expect(PlanEdit.removePlanFromDay(p, thursday).dateAmounts, isEmpty);

      // Lifted on the day, then removed: back to what the weekday asks.
      final lifted = PlanEdit.addUnits(p, thursday, 4);
      expect(asks(lifted, thursday), 13);
      expect(
        asks(PlanEdit.removePlanFromDay(lifted, thursday), thursday),
        9,
        reason:
            'and this time the day did carry an override, so removing it '
            'uncovers the weekday underneath',
      );
    });

    test('removing a day that was never overridden is a no-op', () {
      final next = PlanEdit.removePlanFromDay(plan(), thursday);
      expect(next.dateAmounts, isEmpty);
      expect(
        asks(next, thursday),
        2,
        reason:
            'a DailyRule plan fires every day, so removing an override '
            'that is not there changes nothing — and does not invent one',
      );
    });
  });

  group('a day-level add', () {
    test('lands on a chosen existing plan', () {
      // A delta, so base 2 plus one asks for three.
      final next = PlanEdit.addUnits(plan(), thursday, 1);
      expect(next.dateAmounts[thursday], 3);
    });

    test('and a standalone add is a real, if tiny, plan', () {
      // The owner: adding to no plan is "as if there is a new tiny plan" — so it
      // gets an id, a name and a chain, and is editable like any other. Without
      // a real plan it could not be ticked later, because #42's ledger reads
      // the plan.
      final created = PlanEdit.standalonePlan(
        nodeId: 'shas.moed.shabbos',
        name: 'Shabbos',
        day: thursday,
        units: 2,
      );
      expect(created.id, isNotEmpty);
      expect(created.items, hasLength(1));
      expect(created.items.single.nodeId, 'shas.moed.shabbos');
      expect(asks(created, thursday), 2);
      expect(
        created.unitsPerDay,
        2,
        reason: 'so the ledger has something to read before the override',
      );
    });

    test('and it is a real plan, which means it can be ticked', () {
      final created = PlanEdit.standalonePlan(
        nodeId: 'shas.moed.shabbos',
        name: 'Shabbos',
        day: thursday,
        units: 2,
      );
      expect(
        LearningPlan.fromJson(created.toJson()),
        created,
        reason: 'it round-trips, so it survives a restart like any other plan',
      );
    });
  });
}

/// The day reader the amount lookup needs. Named with a prefix so this file
/// reads as what it is — a caller of the planner's own date helper.
DayInfo _info(Day day) => core_planner.dayInfoFor(day);
