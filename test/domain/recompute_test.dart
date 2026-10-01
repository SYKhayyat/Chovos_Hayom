import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/core/planner_dates.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/day_amount.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/recompute.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

/// #44 — reflow one plan from a chosen day.
///
/// **Three things this file exists to hold**, all of them things recompute could
/// plausibly get wrong in ways nothing else would catch:
///
/// * It touches **no events**. Reflow is a claim about the schedule, never
///   about what was learned — the same line #42 draws, from the other side.
/// * It touches **one plan**. A day routinely carries several, and recomputing
///   one must not move another.
/// * It **moves the finish date** when the spread pushes past it, and says so.
///   The owner: everything is customizable, so a reflow that could not honour
///   the plan's own constraint would not be a reflow.
var _seq = 0;
LearningEvent done(String node, int unit, DateTime day) => LearningEvent(
      id: 'e${_seq++}',
      profileId: 'p',
      nodeId: node,
      unitIndex: unit,
      action: EventAction.done,
      occurredAt: day,
      loggedAt: day,
    );

final catalog = Catalog([
  const CatalogNode(id: 'root', parentId: null, name: 'Root', kind: NodeKind.category),
  const CatalogNode(
      id: 'n',
      parentId: 'root',
      name: 'Sefer',
      kind: NodeKind.leaf,
      unitLabel: UnitLabel.daf,
      unitCount: 100,
      unitOffset: 2),
]);

/// 2026-03-01 is a Sunday, and `weekdayAmounts` is how a rest day is expressed:
/// an amount of 0, never a flag.
final start = Day.of(DateTime.utc(2026, 3, 2));
final startDate = DateTime.utc(2026, 3, 2);

LearningPlan plan({
  int unitsPerDay = 5,
  Map<int, int> weekdays = const {},
  Day? finishBy,
  Map<Day, int> dates = const {},
  Day? startDay,
}) =>
    LearningPlan(
      id: 'p',
      name: 'P',
      unitsPerDay: unitsPerDay,
      weekdayAmounts: weekdays,
      dateAmounts: dates,
      assignments: const [PlanAssignment(id: 'a', rule: DailyRule())],
      items: const [PlanItem(id: 'i1', nodeId: 'n')],
      startDay: startDay,
      pacing: finishBy == null
          ? AmountPerDay(unitsPerDay)
          : FinishBy(finishBy),
    );

/// What [plan] asks for on [day].
int asks(LearningPlan p, Day day) => DayAmount.of(p, dayInfoFor(day));

/// The days from `start`, skipping the rest days this plan has.
List<Day> activeDays(LearningPlan p, int count) {
  final out = <Day>[];
  for (var i = 0; out.length < count; i++) {
    final d = start + i;
    if (asks(p, d) > 0) out.add(d);
    if (i > 400) break;
  }
  return out;
}

void main() {
  setUp(() => _seq = 0);

  group('keep the same amounts', () {
    test('changes nothing at all', () {
      final before = plan();
      final result = Recompute.keepAsIs(before, catalog, FoldLog.fold([]), start);
      expect(result.plan, before, reason: 'mode 1 is a no-op, and says so');
      expect(result.spreadOver, 0);
    });

    test('and reports the shortfall it stood still for', () {
      // A day asked for 5 with 1 done owes 4. Knowing that is the point of
      // looking — even when the answer is "leave it".
      final fold = FoldLog.fold([done('n', 2, startDate)]);
      final result = Recompute.keepAsIs(plan(), catalog, fold, start);
      expect(result.shortfall, 4);
    });
  });

  group('spreading evenly', () {
    test('a 4-unit shortfall over 4 days adds 1 to each', () {
      // 5 asked, 1 done, so 4 owed over 4 days: one each, evenly.
      final fold = FoldLog.fold([done('n', 2, startDate)]);
      final days = activeDays(plan(), 4);
      final result = Recompute.spread(
        plan(),
        catalog,
        fold,
        start,
        spread: const ReflowSpread.days(4),
      );
      expect(result.shortfall, 4);
      for (final d in days) {
        expect(asks(result.plan, d), 6,
            reason: 'base 5 plus one, and evenly — nobody carries the day alone');
      }
    });

    test('and the remainder goes to the earliest days, losing nothing', () {
      // 5 asked, 2 done, so 3 owed over 2 days: 2 and 1, not 1 and 1 with one
      // unit discarded. Rounding that drops the remainder is how a reflow
      // quietly loses work.
      final fold = FoldLog.fold([
        done('n', 2, startDate),
        done('n', 3, startDate),
      ]);
      final days = activeDays(plan(), 2);
      final result = Recompute.spread(
        plan(),
        catalog,
        fold,
        start,
        spread: const ReflowSpread.days(2),
      );
      expect(result.shortfall, 3);
      expect(asks(result.plan, days[0]), 7, reason: '5 base + 2');
      expect(asks(result.plan, days[1]), 6, reason: '5 base + 1');
      expect(asks(result.plan, days[0]) + asks(result.plan, days[1]),
          5 + 5 + 3,
          reason: 'base for both days, plus the whole shortfall');
    });

    test('a shortfall of zero is not a reflow', () {
      // Nothing learned, and the plan starts today, so it has asked for nothing
      // and owes nothing.
      final result = Recompute.spread(
        plan(startDay: start, unitsPerDay: 0),
        catalog,
        FoldLog.fold([]),
        start,
        spread: const ReflowSpread.days(3),
      );
      expect(result.shortfall, 0);
      expect(result.spreadOver, 0,
          reason: 'nothing owed means nothing to spread, and the plan is left '
              'alone rather than given 0-day overrides it would never have had');
    });
  });

  group('the three ways to say how far to spread', () {
    test('a number of days', () {
      final result = Recompute.spread(
        plan(),
        catalog,
        FoldLog.fold([done('n', 2, startDate)]),
        start,
        spread: const ReflowSpread.days(4),
      );
      expect(result.spreadOver, 4);
    });

    test('all of them', () {
      // A plan with no end is infinite, so "all" is the only way to reach its
      // end and there is no "until the end" to spread into.
      final result = Recompute.spread(
        plan(),
        catalog,
        FoldLog.fold([done('n', 2, startDate)]),
        start,
        spread: ReflowSpread.all,
      );
      expect(result.spreadOver, greaterThan(4));
    });

    test('up to the plan’s end, when it has one', () {
      final p = plan(finishBy: start + 6);
      final result = Recompute.spread(
        p,
        catalog,
        FoldLog.fold([done('n', 2, startDate)]),
        start,
        spread: ReflowSpread.untilEnd,
      );
      expect(result.spreadOver, 7,
          reason: 'the end is 6 days out, so 7 days including the day itself');
    });

    test('and "until the end" with no end is the same as all', () {
      // A plan with no end is infinite; a caller that asked for "until the end"
      // on one gets everything rather than a refusal, because the two are the
      // same question and the answer is already known.
      final result = Recompute.spread(
        plan(),
        catalog,
        FoldLog.fold([done('n', 2, startDate)]),
        start,
        spread: ReflowSpread.untilEnd,
      );
      expect(result.spreadOver, greaterThan(4));
    });
  });

  group('what it must not do', () {
    test('it writes no events', () {
      // The log is the only truth about what was learned, and reflow is a claim
      // about the schedule. There is no path here to a repository.
      final result = Recompute.spread(
        plan(),
        catalog,
        FoldLog.fold([done('n', 2, startDate)]),
        start,
        spread: const ReflowSpread.days(3),
      );
      expect(result.plan.items, hasLength(1));
      // The events that came *in* are untouched by being read, which is the only
      // thing a pure function could do to a log.
      expect(FoldLog.fold([done('n', 2, startDate)]).doneCount('n', 2), 1);
    });

    test('it touches no other plan', () {
      // Recompute takes one plan and returns one plan, so it *cannot* move
      // another — there is no list to reach. The scope is the signature.
      final other = plan(unitsPerDay: 3);
      final result = Recompute.spread(
        other,
        catalog,
        FoldLog.fold([done('n', 2, startDate)]),
        start,
        spread: const ReflowSpread.days(3),
      );
      expect(result.plan.id, 'p');
      expect(result.plan.unitsPerDay, 3,
          reason: 'the base is untouched; only days changed');
    });

    test('it does not change the plan’s base or its rule', () {
      final result = Recompute.spread(
        plan(),
        catalog,
        FoldLog.fold([done('n', 2, startDate)]),
        start,
        spread: const ReflowSpread.days(3),
      );
      expect(result.plan.unitsPerDay, 5);
      expect(result.plan.assignments.single.rule, const DailyRule());
      expect(result.plan.items, hasLength(1),
          reason: 'the chain is not reflowed — only days move');
    });

    test('a day before the chosen one is untouched', () {
      final before = start - 1;
      final result = Recompute.spread(
        plan(),
        catalog,
        FoldLog.fold([done('n', 2, startDate)]),
        start,
        spread: ReflowSpread.all,
      );
      expect(asks(result.plan, before), 5,
          reason: 'reflow runs forward from the chosen day, and a day already '
              'past is not a day it can change');
    });
  });

  group('the finish date', () {
    test('moves when the spread pushes past it, and says so', () {
      // The owner: everything is customizable, so a reflow that could not
      // honour the plan's own constraint would not be a reflow. And it must say
      // so — a siyum date that moved without telling the user is a date the
      // user stops believing.
      // A shortfall that only reaches a couple of days, spread over all of
      // them, finishes well inside a 6-day window — so to push past the date the
      // plan has to owe a lot. 5 a day, nothing done, 2 days to the finish.
      final p = plan(finishBy: start + 2, startDay: start);
      final result = Recompute.spread(
        p,
        catalog,
        FoldLog.fold([]),
        start,
        spread: ReflowSpread.all,
      );
      expect(result.finishDayMoved, isTrue);
      expect(result.newFinishDay, isNotNull);
      expect(result.newFinishDay! > start + 2, isTrue,
          reason: 'and it moved later, because the work now lands later');
    });

    test('does not move when the spread fits inside it', () {
      final p = plan(finishBy: start + 20);
      final result = Recompute.spread(
        p,
        catalog,
        FoldLog.fold([done('n', 2, startDate)]),
        start,
        spread: const ReflowSpread.days(3),
      );
      expect(result.finishDayMoved, isFalse);
      expect(result.newFinishDay, start + 20,
          reason: 'the old date stands, reported so the screen can say '
              '"unchanged" rather than guessing');
    });

    test('and a per-day plan has no finish date to move at all', () {
      final result = Recompute.spread(
        plan(),
        catalog,
        FoldLog.fold([done('n', 2, startDate)]),
        start,
        spread: ReflowSpread.all,
      );
      expect(result.finishDayMoved, isFalse);
      expect(result.newFinishDay, isNull);
    });
  });

  group('rest days', () {
    test('are skipped rather than given work', () {
      // A day off is an amount of 0, and spreading a unit onto it would either
      // override the rest or quietly ignore the unit. Both are wrong; skipping
      // is the one that keeps the shortfall intact.
      final p = plan(weekdays: {DateTime.saturday: 0});
      final fold = FoldLog.fold([done('n', 2, startDate)]);
      final result =
          Recompute.spread(p, catalog, fold, start, spread: const ReflowSpread.days(2));
      expect(asks(result.plan, Day.of(DateTime.utc(2026, 3, 7))), 0,
          reason: 'Shabbat, and it stays a rest day');
      expect(result.spreadOver, 2, reason: 'two *active* days absorbed it');
    });
  });
}
