import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/plan_rate.dart';
import 'package:chovos_hayom/domain/usecases/plan_run.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

/// #47 — a screen per plan: where it stands, and how fast it is actually moving.
///
/// Written before the screen, so the contract is the tests.
///
/// **The three things this file exists to pin down**, each of which is a way the
/// number on that screen could be wrong rather than merely unhelpful:
///
/// - **An endless plan reports a count, never a fraction.** No denominator is
///   invented for it (`totalUnits` is null), and `isComplete` is false even when
///   every unit is currently marked done — it has no end to have finished.
/// - **The rate is per *active* day, not per calendar day.** A plan that fires
///   only on Shabbos, kept up on perfectly, must not read as running at a
///   seventh of the rate the user set.
/// - **A plan that names nothing to work through reports that, rather than an
///   infinite plan with nothing done.**
var _seq = 0;

LearningEvent done(String node, int unit, Day day) => LearningEvent(
  id: 'e${_seq++}',
  profileId: 'p',
  nodeId: node,
  unitIndex: unit,
  action: EventAction.done,
  occurredAt: day.midnight,
  loggedAt: day.midnight,
);

LearningEvent undone(String node, int unit, Day day) => LearningEvent(
  id: 'e${_seq++}',
  profileId: 'p',
  nodeId: node,
  unitIndex: unit,
  action: EventAction.undone,
  occurredAt: day.midnight,
  loggedAt: day.midnight,
);

/// The day the standing is asked about. Work dated on it is deliberately *not*
/// counted: every count here is "done **by** the day asked about", which is what
/// stops a plan reporting itself finished on the day it finishes.
final today = Day.of(DateTime.utc(2026, 3, 10));

/// A leaf with 30 units numbered from 2, so a range reads the same way a sefer
/// does, and a small one beside it.
final catalog = Catalog([
  const CatalogNode(
    id: 'root',
    parentId: null,
    name: 'Root',
    kind: NodeKind.category,
  ),
  const CatalogNode(
    id: 'yoma',
    parentId: 'root',
    name: 'Yoma',
    kind: NodeKind.leaf,
    unitLabel: UnitLabel.daf,
    unitCount: 30,
    unitOffset: 2,
  ),
  const CatalogNode(
    id: 'sukkah',
    parentId: 'root',
    name: 'Sukkah',
    kind: NodeKind.leaf,
    unitLabel: UnitLabel.daf,
    unitCount: 8,
    unitOffset: 2,
  ),
]);

/// A daily plan over part of Yoma, the shape most plans in the app have.
LearningPlan plan({
  int unitsPerDay = 5,
  int? startUnit,
  int? endUnit,
  bool wraps = false,
  Day? from,
  RecurrenceRule? rule,
}) => LearningPlan(
  id: 'p',
  name: 'P',
  unitsPerDay: unitsPerDay,
  items: [
    PlanItem(
      id: 'i1',
      nodeId: 'yoma',
      startUnit: startUnit,
      endUnit: endUnit,
      wrapsRange: wraps,
    ),
  ],
  startDay: from,
  assignments: [PlanAssignment(id: 'a', rule: rule ?? const DailyRule())],
);

void main() {
  setUp(() => _seq = 0);

  group('an open-ended plan reports a count and nothing else', () {
    test('a wrapping plan has no total, so no fraction can be shown', () {
      final standing = PlanRate.of(
        plan(startUnit: 2, endUnit: 25, wraps: true, from: today - 4),
        catalog,
        FoldLog.fold([done('yoma', 2, today - 3)]),
        today,
      );
      expect(standing.isFinite, isFalse);
      expect(standing.total, isNull);
      expect(standing.done, 1);
      expect(
        standing.isComplete,
        isFalse,
        reason: 'it has no end, so there is nothing to have finished',
      );
    });

    test('a range with no last unit is endless too', () {
      // The two together are the endless case #41 named: no endUnit *and* a wrap.
      final standing = PlanRate.of(
        plan(wraps: true, from: today - 4),
        catalog,
        FoldLog.fold([done('yoma', 2, today - 3)]),
        today,
      );
      expect(standing.total, isNull);
    });

    test('a finite plan can be a fraction', () {
      final standing = PlanRate.of(
        plan(startUnit: 2, endUnit: 25, from: today - 4),
        catalog,
        FoldLog.fold([for (var u = 2; u <= 6; u++) done('yoma', u, today - 3)]),
        today,
      );
      expect(standing.total, 24);
      expect(standing.done, 5);
      expect(standing.isFinite, isTrue);
      expect(standing.isComplete, isFalse);
    });

    test('a finished finite plan says so', () {
      final standing = PlanRate.of(
        plan(startUnit: 2, endUnit: 5, from: today - 4),
        catalog,
        FoldLog.fold([for (var u = 2; u <= 5; u++) done('yoma', u, today - 3)]),
        today,
      );
      expect(standing.total, 4);
      expect(standing.done, 4);
      expect(standing.isComplete, isTrue);
    });
  });

  group('a plan that names nothing says so rather than reporting zero', () {
    test('no sefer in the sequence and no assignment target', () {
      // The plan the plan editor makes: a name, a rule and an amount, with no
      // sefer named. Reading its null total as "endless" would report a real
      // schedule as an infinite plan with nothing done.
      const bare = LearningPlan(
        id: 'p',
        name: 'P',
        unitsPerDay: 5,
        assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
      );
      final standing = PlanRate.of(
        bare,
        catalog,
        FoldLog.fold([done('yoma', 2, today - 3)]),
        today,
      );
      expect(standing.isEmpty, isTrue);
      expect(
        standing.averagePerDay,
        isNull,
        reason:
            'there is nothing to average, and 0 would be a claim about work',
      );
      expect(standing.done, 0);
    });

    test('an assignment target counts as content', () {
      // The fallback the plan list's own total already makes: no sequence, but
      // an assignment names a sefer, so the plan covers its units.
      const targeted = LearningPlan(
        id: 'p',
        name: 'P',
        unitsPerDay: 1,
        assignments: [
          PlanAssignment(id: 'a', rule: DailyRule(), targetNodeId: 'yoma'),
        ],
      );
      final standing = PlanRate.of(
        targeted,
        catalog,
        FoldLog.fold([done('yoma', 2, today - 3), done('yoma', 3, today - 2)]),
        today,
      );
      expect(standing.isEmpty, isFalse);
      expect(standing.total, 30, reason: 'Yoma is 30 units from 2');
      expect(standing.done, 2);
    });

    test('a target the catalog does not have is not content', () {
      const gone = LearningPlan(
        id: 'p',
        name: 'P',
        unitsPerDay: 1,
        assignments: [
          PlanAssignment(
            id: 'a',
            rule: DailyRule(),
            targetNodeId: 'deleted-node',
          ),
        ],
      );
      expect(
        PlanRate.of(gone, catalog, FoldLog.fold([]), today).isEmpty,
        isTrue,
      );
    });

    test('the range list agrees with the total, on both sides of the fork', () {
      // One walk, so the screen cannot see an empty plan as an endless one.
      expect(
        PlanRange.rangesOf(const LearningPlan(id: 'p', name: 'P'), catalog),
        isEmpty,
      );
      expect(
        PlanRange.rangesOf(plan(), catalog).single,
        isNotNull,
        reason: 'one item, one range',
      );
      expect(
        PlanRange.rangesOf(
          const LearningPlan(
            id: 'p',
            name: 'P',
            items: [
              PlanItem(id: 'a', nodeId: 'yoma'),
              PlanItem(id: 'b', nodeId: 'gone'),
            ],
          ),
          catalog,
        ),
        hasLength(2),
        reason:
            'a deleted node leaves a hole rather than sliding the chain down '
            'one, which would hand the plan the wrong sefer',
      );
    });
  });

  group('the rate is per day the plan asked for, not per calendar day', () {
    test('a Shabbos-only plan kept up on is not reported as falling behind', () {
      // The visible mis-report this whole rule exists to stop. Ten units a
      // Shabbos, done perfectly, is 10 ÷ 7 ≈ 1.43 against a calendar — read
      // against an asked 10 it looks like running at a seventh of pace, when it
      // is exactly on it.
      //
      // 2026-03-10 is a Tuesday, so the Shabbos before it is 07-03.
      final shabbos = Day.of(DateTime.utc(2026, 3, 7));
      final shabbosPlan = plan(
        unitsPerDay: 10,
        startUnit: 2,
        endUnit: 25,
        from: shabbos,
        rule: const WeekdayRule(weekdays: {DateTime.saturday}),
      );
      final standing = PlanRate.of(
        shabbosPlan,
        catalog,
        FoldLog.fold([for (var u = 2; u <= 11; u++) done('yoma', u, shabbos)]),
        today,
      );

      expect(standing.activeDays, 1, reason: 'one Shabbos in the window');
      expect(
        standing.averagePerDay,
        10,
        reason: 'ten units on the one day asked',
      );
      expect(standing.askedPerDay, 10);
      expect(
        standing.isBehind,
        isFalse,
        reason:
            'exactly on the rate it was set to, and a calendar-day '
            'average would say otherwise',
      );
    });

    test('a plan doing less than it asks is behind', () {
      // The issue's own case: asks seven a day, doing three. Three days elapsed
      // (Sat 07, Sun 08, Mon 09 — `today` is a Tuesday and is excluded from the
      // window), and three units were done on one of them.
      final standing = PlanRate.of(
        plan(unitsPerDay: 7, startUnit: 2, endUnit: 25, from: today - 3),
        catalog,
        FoldLog.fold([for (var u = 2; u <= 4; u++) done('yoma', u, today - 3)]),
        today,
      );
      expect(standing.activeDays, 3);
      expect(standing.askedPerDay, 7);
      expect(
        standing.averagePerDay,
        closeTo(1, 0.001),
        reason: 'three units on one of the three days it asked for',
      );
      expect(standing.isBehind, isTrue);
    });

    test('a plan doing more than it asks is not behind', () {
      final standing = PlanRate.of(
        plan(unitsPerDay: 2, startUnit: 2, endUnit: 25, from: today - 3),
        catalog,
        FoldLog.fold([for (var u = 2; u <= 9; u++) done('yoma', u, today - 3)]),
        today,
      );
      expect(
        standing.averagePerDay,
        closeTo(8 / 3, 0.001),
        reason: 'eight units on one of the three days it asked for',
      );
      expect(standing.isBehind, isFalse);
    });

    test('a day off is in neither side of the rate', () {
      // An amount of 0 is a deliberate rest day: the plan asked for nothing, so
      // there was nothing to fall behind on. Counting it in the denominator
      // would drag every rate down by the number of days off.
      final resting = LearningPlan(
        id: 'p',
        name: 'P',
        unitsPerDay: 5,
        dateAmounts: {today - 2: 0, today - 1: 0},
        startDay: today - 3,
        items: const [PlanItem(id: 'i1', nodeId: 'yoma')],
        assignments: const [PlanAssignment(id: 'a', rule: DailyRule())],
      );
      final standing = PlanRate.of(
        resting,
        catalog,
        FoldLog.fold([for (var u = 2; u <= 6; u++) done('yoma', u, today - 3)]),
        today,
      );
      expect(
        standing.activeDays,
        1,
        reason: 'three days elapsed, two of them deliberately off',
      );
      expect(standing.averagePerDay, 5, reason: '5 units on the one day asked');
    });

    test('a day the plan does not fire on is not a day off', () {
      // The distinction the previous test needs the other half of: a plan with
      // no assignment on a day had nothing to do there, which is not the same
      // claim as being on that day and asking for nothing — but neither of them
      // is a day that could have been fallen behind on.
      final standing = PlanRate.of(
        plan(
          unitsPerDay: 5,
          startUnit: 2,
          endUnit: 25,
          from: today - 3,
          rule: const WeekdayRule(weekdays: {DateTime.monday}),
        ),
        catalog,
        FoldLog.fold([done('yoma', 2, today - 3)]),
        today,
      );
      // 2026-03-10 is a Tuesday, so the Monday in that window is 09-03.
      expect(standing.activeDays, 1);
      expect(standing.averagePerDay, 1);
    });

    test('the asked rate averages the overrides in', () {
      // A plan asking 7 with 3 on Fridays is asked under 7, and reporting 7
      // would make a deliberately light Friday look like a shortfall.
      final varied = LearningPlan(
        id: 'p',
        name: 'P',
        unitsPerDay: 7,
        weekdayAmounts: const {DateTime.friday: 3},
        startDay: today - 6,
        items: const [PlanItem(id: 'i1', nodeId: 'yoma')],
        assignments: const [PlanAssignment(id: 'a', rule: DailyRule())],
      );
      final standing = PlanRate.of(varied, catalog, FoldLog.fold([]), today);
      // 04-03 .. 09-03 is six days, and the Friday among them (06-03) asks 3.
      expect(standing.activeDays, 6);
      expect(standing.askedPerDay, closeTo((7 * 5 + 3) / 6, 0.001));
    });
  });

  group('re-learning counts, and double-counting a tick does not', () {
    test('a unit re-learned on a later day counts again', () {
      // The endless plan's whole progress is re-learning: Daf Yomi goes round
      // for ever, and "first time only" would decay its rate to zero on exactly
      // the plans that need it most.
      final standing = PlanRate.of(
        plan(startUnit: 2, endUnit: 25, wraps: true, from: today - 3),
        catalog,
        FoldLog.fold([
          for (var u = 2; u <= 6; u++) done('yoma', u, today - 3),
          for (var u = 2; u <= 4; u++) done('yoma', u, today - 2),
        ]),
        today,
      );
      expect(
        standing.averagePerDay,
        closeTo(8 / 3, 0.001),
        reason: '5 units then 3 more, over the three days it asked for',
      );
      expect(
        standing.done,
        5,
        reason:
            'a count of *units*, not of ticks — five distinct units are done, '
            'and the 3 re-learns are days of work rather than progress. This '
            'is the whole difference between the standing and the rate',
      );
    });

    test('three ticks of one unit in a day is one day of work', () {
      final thrice = FoldLog.fold([
        done('yoma', 2, today - 3),
        done('yoma', 2, today - 3),
        done('yoma', 2, today - 3),
      ]);
      final standing = PlanRate.of(
        plan(unitsPerDay: 1, startUnit: 2, endUnit: 25, from: today - 3),
        catalog,
        thrice,
        today,
      );
      expect(
        standing.averagePerDay,
        closeTo(1 / 3, 0.001),
        reason:
            'a duplicate tap on one daf is one daf\'s work; a rate that counted '
            'it three times would let a mis-tap make a plan look as though it '
            'were flying',
      );
      expect(standing.done, 1);
    });

    test('an un-marked unit stops counting', () {
      // The rule the standing is counted by too: a unit the user has un-ticked
      // has nothing on it to have been done.
      final standing = PlanRate.of(
        plan(unitsPerDay: 5, startUnit: 2, endUnit: 25, from: today - 3),
        catalog,
        FoldLog.fold([
          for (var u = 2; u <= 6; u++) done('yoma', u, today - 3),
          undone('yoma', 4, today - 2),
        ]),
        today,
      );
      expect(standing.done, 4);
      expect(
        standing.averagePerDay,
        closeTo(4 / 3, 0.001),
        reason: 'the un-marked unit is not a unit done on any day',
      );
    });
  });

  group('the window', () {
    test('starts at the plan\'s own start date when it has one', () {
      final standing = PlanRate.of(
        plan(unitsPerDay: 5, startUnit: 2, endUnit: 25, from: today - 9),
        catalog,
        FoldLog.fold([done('yoma', 2, today - 3)]),
        today,
      );
      expect(standing.since, today - 9);
      expect(
        standing.activeDays,
        9,
        reason: '09-03 .. 09-03 exclusive: nine whole days',
      );
    });

    test('and at the first day worked when the plan has no start date', () {
      // `startDay` null means *today*, and a rate averaged over one unfinished
      // day is not a rate — so the first day with work in it is the window.
      final standing = PlanRate.of(
        plan(unitsPerDay: 5, startUnit: 2, endUnit: 25),
        catalog,
        FoldLog.fold([done('yoma', 2, today - 2), done('yoma', 3, today - 1)]),
        today,
      );
      expect(standing.since, today - 2);
      expect(standing.activeDays, 2);
      expect(standing.averagePerDay, 1);
    });

    test('a plan with no start and no work has no window', () {
      final standing = PlanRate.of(
        plan(unitsPerDay: 5, startUnit: 2, endUnit: 25),
        catalog,
        FoldLog.fold([]),
        today,
      );
      expect(
        standing.isEmpty,
        isFalse,
        reason:
            'the plan does name a sefer; it just has not been worked on, which '
            'is a different thing to tell the user than a plan that names '
            'nothing',
      );
      expect(standing.total, 24, reason: 'the counts are still real');
      expect(standing.averagePerDay, isNull);
      expect(
        standing.recentPerDay,
        isNull,
        reason: 'a fresh plan is not behind, it has not started',
      );
    });

    test('a plan whose start date has not arrived has no window', () {
      final standing = PlanRate.of(
        plan(unitsPerDay: 5, startUnit: 2, endUnit: 25, from: today + 5),
        catalog,
        FoldLog.fold([done('yoma', 2, today - 1)]),
        today,
      );
      expect(
        standing.isEmpty,
        isFalse,
        reason: 'it names a sefer and simply has not begun',
      );
      expect(
        standing.averagePerDay,
        isNull,
        reason: 'a plan asking to begin next month is not running slowly',
      );
      expect(standing.isBehind, isFalse);
    });

    test('the day asked about is excluded, so the average is over whole days', () {
      // A rate averaged over a partly-finished day is depressed by work not yet
      // done rather than by work not done. This is deliberately the opposite of
      // what the shortfall does with the same day, which wants that day's work
      // counted; both reasons are written where they are applied.
      final standing = PlanRate.of(
        plan(unitsPerDay: 5, startUnit: 2, endUnit: 25, from: today - 2),
        catalog,
        FoldLog.fold([
          for (var u = 2; u <= 6; u++) done('yoma', u, today - 2),
          for (var u = 7; u <= 11; u++) done('yoma', u, today),
        ]),
        today,
      );
      expect(standing.activeDays, 2, reason: '08-03 and 09-03, not today');
      expect(
        standing.averagePerDay,
        closeTo(2.5, 0.001),
        reason: "today's five units are work not yet done, not work not done",
      );
      expect(
        standing.done,
        5,
        reason: 'every count here is "done **by** the day asked about"',
      );
    });

    test('the recent figure covers a week, and less on a young plan', () {
      final old = PlanRate.of(
        plan(unitsPerDay: 5, startUnit: 2, endUnit: 25, from: today - 30),
        catalog,
        FoldLog.fold([for (var u = 2; u <= 6; u++) done('yoma', u, today - 1)]),
        today,
      );
      expect(old.recentDays, PlanRate.recentWindow);
      expect(
        old.recentPerDay,
        closeTo(5 / PlanRate.recentWindow, 0.001),
        reason: 'five units on one of the last seven days the plan asked on',
      );

      final young = PlanRate.of(
        plan(unitsPerDay: 5, startUnit: 2, endUnit: 25, from: today - 2),
        catalog,
        FoldLog.fold([for (var u = 2; u <= 6; u++) done('yoma', u, today - 1)]),
        today,
      );
      expect(
        young.recentDays,
        2,
        reason: 'a recent window on a young plan is short, and says so',
      );
      expect(young.recentPerDay, closeTo(2.5, 0.001));
    });

    test('both windows are reported, because they disagree', () {
      // A plan that started well and stopped three weeks ago. A whole-plan
      // average averages the good start into the answer; a recent window is
      // noisy on a young plan. The issue asks which to show, and the answer is
      // both, each named with the window it covers.
      //
      // The work is dated well outside the recent window, which is the whole
      // point: the two figures have to be able to disagree, and they can only
      // do that if the good days are old.
      final standing = PlanRate.of(
        plan(unitsPerDay: 5, startUnit: 2, endUnit: 25, from: today - 30),
        catalog,
        FoldLog.fold([
          for (var u = 2; u <= 6; u++) done('yoma', u, today - 21),
        ]),
        today,
      );
      expect(standing.activeDays, 30);
      expect(
        standing.averagePerDay,
        closeTo(5 / 30, 0.001),
        reason: 'the whole-plan average is dragged up by the good start',
      );
      expect(
        standing.recentPerDay,
        0,
        reason: 'and the recent figure is the one that says it has stopped',
      );
      expect(standing.isBehind, isTrue);
    });
  });

  group('PlanStanding is a value type', () {
    test('and compares all of its fields', () {
      final standing = PlanRate.of(
        plan(unitsPerDay: 5, startUnit: 2, endUnit: 25, from: today - 3),
        catalog,
        FoldLog.fold([done('yoma', 2, today - 3)]),
        today,
      );
      expect(
        PlanRate.of(
          plan(unitsPerDay: 5, startUnit: 2, endUnit: 25, from: today - 3),
          catalog,
          FoldLog.fold([done('yoma', 2, today - 3)]),
          today,
        ),
        standing,
        reason:
            'same log and plan must compare equal, or every rebuild notifies',
      );

      final more = PlanRate.of(
        plan(unitsPerDay: 5, startUnit: 2, endUnit: 25, from: today - 3),
        catalog,
        FoldLog.fold([done('yoma', 2, today - 3), done('yoma', 3, today - 2)]),
        today,
      );
      expect(more, isNot(standing));
    });

    test('equal standings collapse in a set, which needs hashCode', () {
      // `==` on its own is not enough to be a set member or a map key, and a
      // value type that compares equal but hashes differently is one of the
      // silent failures — anything keyed on it would keep a stale copy per
      // rebuild, which is exactly the cost `LogFold` declines to pay.
      PlanStanding standing() => PlanRate.of(
        plan(unitsPerDay: 5, startUnit: 2, endUnit: 25, from: today - 3),
        catalog,
        FoldLog.fold([done('yoma', 2, today - 3)]),
        today,
      );
      expect(standing().hashCode, standing().hashCode);
      expect({standing(), standing()}, hasLength(1));
      expect({
        standing(),
        PlanRate.of(
          plan(unitsPerDay: 5, startUnit: 2, endUnit: 25, from: today - 3),
          catalog,
          FoldLog.fold([
            done('yoma', 2, today - 3),
            done('yoma', 3, today - 2),
          ]),
          today,
        ),
      }, hasLength(2));
    });

    test('and its printed form names the two halves apart', () {
      // A debugging aid, and one that rots untested: the count and the rate are
      // different questions, and a string printing one where the other is meant
      // sends whoever reads the log looking in the wrong place.
      final finite = PlanRate.of(
        plan(unitsPerDay: 5, startUnit: 2, endUnit: 5, from: today - 3),
        catalog,
        FoldLog.fold([done('yoma', 2, today - 3)]),
        today,
      );
      expect(finite.toString(), contains('1 of 4'));
      expect(finite.toString(), contains('average:'));

      final endless = PlanRate.of(
        plan(startUnit: 2, endUnit: 25, wraps: true, from: today - 3),
        catalog,
        FoldLog.fold([done('yoma', 2, today - 3)]),
        today,
      );
      expect(
        endless.toString(),
        contains('no total'),
        reason:
            'the null total is the whole point of an endless plan, and it '
            'is the one a reader of the log cannot reconstruct',
      );
    });
  });
}
