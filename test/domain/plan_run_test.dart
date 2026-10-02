import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/plan_position.dart';
import 'package:chovos_hayom/domain/usecases/plan_run.dart';
import 'package:flutter_test/flutter_test.dart';

/// #41 — the plan as a real, editable entity: a chain of sefarim, a unit range
/// per sefer, two independent wrap settings, a start date, and one pacing mode.
///
/// Written before the implementation, so the contract is the tests.
///
/// **The one thing this file exists to pin down** is that a wrapping plan is
/// *infinite*. The owner's ruling: progress on such a plan is just how many units
/// have been done, the plan screen shows a bare count and never a percentage,
/// and "which unit am I on" belongs to the calendar (#42), not here. So there is
/// deliberately **no lap counter anywhere in this file** — an earlier draft of
/// this work tried to model one, and it was answering a question about a plan
/// that has no end to be a fraction of.
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

LearningEvent undone(String node, int unit, DateTime day) => LearningEvent(
  id: 'e${_seq++}',
  profileId: 'p',
  nodeId: node,
  unitIndex: unit,
  action: EventAction.undone,
  occurredAt: day,
  loggedAt: day,
);

/// The day the plan is asked about, and the day everything in these tests was
/// learned.
///
/// **`today` is a distinct, *earlier* day from [asOf]** — and that is the whole
/// reason. Every count here is "done **by** [asOf]", and a unit learned *on*
/// [asOf] is deliberately not counted: it is what stops a plan reporting itself
/// finished on the day it finishes. Dating every event on [asOf] therefore
/// counts nothing, which is correct behaviour and a very quiet way to write a
/// test that appears to prove the opposite.
final today = DateTime.utc(2026, 2, 20);
final asOf = Day.of(DateTime.utc(2026, 3, 1));

/// A leaf with 30 units numbered from 2, so a range is easy to state and a
/// wrap is easy to reach: `2..25` leaves 2 at the bottom and 25 at the top.
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

/// A one-sefer plan over the whole of Yoma, wrapping.
///
/// The start-day parameter is named `from` rather than `startDay` because a
/// named parameter cannot share a name with the field it is assigned to and
/// still default to a value — `startDay: startDay` in a default-valued
/// signature does not compile.
LearningPlan Function({int? startUnit, int? endUnit, bool wrapRange, Day? from})
plan = ({startUnit, endUnit, wrapRange = false, from}) => LearningPlan(
  id: 'p',
  name: 'P',
  items: [
    PlanItem(
      id: 'i1',
      nodeId: 'yoma',
      startUnit: startUnit,
      endUnit: endUnit,
      wrapsRange: wrapRange,
    ),
  ],
  startDay: from,
);

void main() {
  setUp(() => _seq = 0);

  group('the sefer chain', () {
    test('an ordered chain of sefarim round-trips through JSON, in order', () {
      const p = LearningPlan(
        id: 'p',
        name: 'P',
        items: [
          PlanItem(id: 'a', nodeId: 'yoma'),
          PlanItem(id: 'b', nodeId: 'sukkah'),
        ],
      );
      final restored = LearningPlan.fromJson(p.toJson());
      expect(restored, p);
      expect(restored.items.map((i) => i.nodeId), ['yoma', 'sukkah']);
    });

    test('PlanItem is a value type, and its range is part of it', () {
      expect(
        const PlanItem(id: 'a', nodeId: 'n'),
        const PlanItem(id: 'a', nodeId: 'n'),
      );
      expect(
        const PlanItem(id: 'a', nodeId: 'n'),
        isNot(const PlanItem(id: 'a', nodeId: 'n', startUnit: 3)),
      );
      expect(
        const PlanItem(id: 'a', nodeId: 'n'),
        isNot(const PlanItem(id: 'a', nodeId: 'n', endUnit: 9)),
      );
      expect(
        const PlanItem(id: 'a', nodeId: 'n'),
        isNot(const PlanItem(id: 'a', nodeId: 'n', wrapsRange: true)),
      );
    });
  });

  group('the unit range', () {
    test('defaults to the whole sefer when no bounds are given', () {
      final range = PlanRange.resolve(plan(), catalog, 0);
      expect(range, isNotNull);
      expect(range!.first, 2, reason: 'Yoma starts at 2');
      expect(range.last, 31, reason: '30 units from 2 is 2..31 inclusive');
    });

    test('a supplied range is honoured as given', () {
      final range = PlanRange.resolve(
        plan(startUnit: 2, endUnit: 25),
        catalog,
        0,
      )!;
      expect(range.first, 2);
      expect(range.last, 25);
      expect(range.length, 24);
    });

    test('an open-ended range runs to the end of the sefer', () {
      final range = PlanRange.resolve(plan(startUnit: 10), catalog, 0)!;
      expect(range.first, 10);
      expect(range.last, 31);
    });

    test('a range starting below the first unit is refused, not clamped', () {
      // Yoma's units run from 2, so unit 1 does not exist. Clamping it to 2
      // would silently cover a unit the user did not ask for, and a sefer whose
      // units start at 1 would make the same stored plan mean something else —
      // a range the user believes is in force covering the wrong units, which is
      // the failure this feature is most able to produce.
      expect(
        () => PlanRange.resolve(plan(startUnit: 1, endUnit: 5), catalog, 0),
        throwsFormatException,
      );
      expect(
        () => PlanRange.resolve(plan(startUnit: 0, endUnit: 5), catalog, 0),
        throwsFormatException,
      );
    });

    test('a reversed range is refused at the JSON boundary too', () {
      // Checkable without a catalog, so it is refused there rather than waiting
      // for a sefer to be resolved.
      expect(
        () => LearningPlan.fromJson({
          'id': 'p',
          'name': 'P',
          'items': [
            {'id': 'a', 'nodeId': 'yoma', 'startUnit': 20, 'endUnit': 10},
          ],
        }),
        throwsFormatException,
      );
    });

    test('a range ending before it starts is refused', () {
      expect(
        () => PlanRange.resolve(plan(startUnit: 20, endUnit: 10), catalog, 0),
        throwsFormatException,
      );
    });

    test('a sefer that is not in the catalog has no range, and says so', () {
      const gone = LearningPlan(
        id: 'p',
        name: 'P',
        items: [PlanItem(id: 'a', nodeId: 'deleted-node')],
      );
      expect(
        PlanRange.resolve(gone, catalog, 0),
        isNull,
        reason: 'a node deleted out from under a plan must not be fatal',
      );
    });
  });

  group('the two wraps are independent settings', () {
    test('wrapping the range is about the units, not the chain', () {
      final single = plan(wrapRange: true);
      expect(
        single.items.single.wrapsRange,
        isTrue,
        reason:
            'a single-sefer plan has no chain to continue, and can still '
            'wrap its own range — which is the case that proves the two are '
            'separate mechanisms',
      );
      expect(single.flowsToNextItem, isFalse);
    });

    test('flowing to the next sefer is about the chain, not the range', () {
      const two = LearningPlan(
        id: 'p',
        name: 'P',
        items: [
          PlanItem(id: 'a', nodeId: 'yoma'),
          PlanItem(id: 'b', nodeId: 'sukkah'),
        ],
        flowsToNextItem: true,
      );
      expect(two.items.every((i) => i.wrapsRange), isFalse);
      expect(two.flowsToNextItem, isTrue);
    });
  });

  group('the start date', () {
    test('defaults to today when the plan does not name one', () {
      const p = LearningPlan(
        id: 'p',
        name: 'P',
        items: [PlanItem(id: 'a', nodeId: 'yoma')],
      );
      expect(
        p.startDay,
        isNull,
        reason: 'null means "today", and is not stored',
      );
      expect(p.startsOn(asOf), isTrue);
    });

    test('a plan that starts later has not started yet', () {
      final p = plan(from: asOf + 5);
      expect(p.startsOn(asOf), isFalse);
      expect(p.startsOn(asOf + 5), isTrue);
      expect(p.startsOn(asOf + 6), isTrue, reason: 'and keeps having started');
    });

    test('a plan that started yesterday is running', () {
      expect(plan(from: asOf - 1).startsOn(asOf), isTrue);
    });

    test('the start date round-trips and is part of equality', () {
      final p = plan(from: Day.of(DateTime.utc(2026, 6, 1)));
      expect(LearningPlan.fromJson(p.toJson()), p);
      expect(plan(from: asOf + 1), isNot(plan()));
    });
  });

  group('pacing — exactly one of amount-per-day or finish-by', () {
    test('an amount-per-day plan carries no finish date', () {
      const p = LearningPlan(
        id: 'p',
        name: 'P',
        items: [PlanItem(id: 'a', nodeId: 'yoma')],
        pacing: AmountPerDay(10),
      );
      expect(p.pacing.unitsPerDay, 10);
      expect(p.pacing.finishDay, isNull);
    });

    test('a finish-by plan carries no daily amount', () {
      final p = LearningPlan(
        id: 'p',
        name: 'P',
        items: const [PlanItem(id: 'a', nodeId: 'yoma')],
        pacing: FinishBy(Day.of(DateTime.utc(2026, 4, 1))),
      );
      expect(p.pacing.finishDay, isNotNull);
      expect(
        p.pacing.unitsPerDay,
        isNull,
        reason:
            'the two answer the same question; a plan holding both can '
            'contradict itself, which is why they are mutually exclusive by '
            'construction rather than by convention',
      );
    });

    test('both round-trip, and are distinct values', () {
      const perDay = LearningPlan(
        id: 'p',
        name: 'P',
        items: [PlanItem(id: 'a', nodeId: 'yoma')],
        pacing: AmountPerDay(10),
      );
      final finish = LearningPlan(
        id: 'p',
        name: 'P',
        items: const [PlanItem(id: 'a', nodeId: 'yoma')],
        pacing: FinishBy(Day.of(DateTime.utc(2026, 4, 1))),
      );
      expect(LearningPlan.fromJson(perDay.toJson()).pacing, perDay.pacing);
      expect(LearningPlan.fromJson(finish.toJson()).pacing, finish.pacing);
      expect(perDay, isNot(finish));
    });

    test('a negative amount is refused, as anywhere else in the planner', () {
      expect(
        () => LearningPlan.fromJson({
          'id': 'p',
          'name': 'P',
          'pacing': {'mode': 'amountPerDay', 'unitsPerDay': -1},
        }),
        throwsFormatException,
      );
    });

    test(
      'an unknown pacing mode is refused rather than silently defaulted',
      () {
        expect(
          () => LearningPlan.fromJson({
            'id': 'p',
            'name': 'P',
            'pacing': {'mode': 'whenever'},
          }),
          throwsFormatException,
        );
      },
    );
  });

  group('a wrapping plan is infinite', () {
    // The owner's ruling, and the reason this group exists. A wrapping plan has
    // no end, so it has no percentage and no "remaining"; progress is a count.

    test('a wrapping range has no total, so nothing can divide by it', () {
      final p = plan(startUnit: 2, endUnit: 25, wrapRange: true);
      expect(
        PlanRunProgress.totalUnits(p, catalog),
        isNull,
        reason:
            'null is not "zero units" — it is "there is no total to count '
            'to", which is the honest answer for an endless range',
      );
    });

    test('a wrapping range over a whole sefer has no total either', () {
      // No endUnit *and* a wrap: the two together are the endless case, and it
      // is the one the plan screen has to render without a fraction.
      const open = LearningPlan(
        id: 'p',
        name: 'P',
        items: [PlanItem(id: 'a', nodeId: 'yoma', wrapsRange: true)],
      );
      expect(PlanRunProgress.totalUnits(open, catalog), isNull);
    });

    test('a finite range does have a total', () {
      final finite = plan(startUnit: 2, endUnit: 25);
      expect(PlanRunProgress.totalUnits(finite, catalog), 24);
    });

    test('progress on an infinite plan is a bare count of units done', () {
      final fold = FoldLog.fold([
        done('yoma', 2, today),
        done('yoma', 3, today),
        done('yoma', 4, today),
      ]);
      final p = plan(startUnit: 2, endUnit: 25, wrapRange: true);
      expect(PlanRunProgress.doneUnits(p, catalog, fold, asOf), 3);
    });

    test('units learned again do not inflate the count', () {
      // Learning page 2 a second time is a real event in the log, and the unit
      // grid shows "learnt twice". The plan's count is how many units are done,
      // so it stays at one: this is the whole reason a count and a fraction are
      // different questions.
      final fold = FoldLog.fold([
        done('yoma', 2, today),
        done('yoma', 3, today),
      ]);
      final p = plan(startUnit: 2, endUnit: 25, wrapRange: true);
      expect(PlanRunProgress.doneUnits(p, catalog, fold, asOf), 2);
      expect(
        PlanRunProgress.totalUnits(p, catalog),
        isNull,
        reason: 'so there is nothing to divide by, and nothing to invent',
      );
    });
  });

  group('the position within a range', () {
    // "First not-done unit in the range, or the start of the range when they
    // are all done." No lap counter — see the file header.

    test('with nothing done it is the first unit of the range', () {
      final p = plan(startUnit: 2, endUnit: 25);
      final pos = PlanRunProgress.unitOn(p, catalog, FoldLog.fold([]), asOf);
      expect(pos, 2);
    });

    test('it advances as units are learned', () {
      final fold = FoldLog.fold([done('yoma', 2, today)]);
      final p = plan(startUnit: 2, endUnit: 25);
      expect(PlanRunProgress.unitOn(p, catalog, fold, asOf), 3);
    });

    test('it skips past a gap that is not at the front', () {
      // 2..6 done, so 7 is next even though 3 was un-ticked and re-learned: the
      // rule is "first not done", so a gap only pulls the pointer back to
      // itself.
      final fold = FoldLog.fold([
        done('yoma', 2, today),
        done('yoma', 3, today),
        done('yoma', 4, today),
        done('yoma', 5, today),
        done('yoma', 6, today),
      ]);
      expect(
        PlanRunProgress.unitOn(
          plan(startUnit: 2, endUnit: 25),
          catalog,
          fold,
          asOf,
        ),
        7,
      );
    });

    test(
      'an un-ticked unit becomes not-done again and pulls the pointer back',
      () {
        final fold = FoldLog.fold([
          done('yoma', 2, today),
          done('yoma', 3, today),
          done('yoma', 4, today),
          undone('yoma', 3, today),
        ]);
        expect(
          PlanRunProgress.unitOn(
            plan(startUnit: 2, endUnit: 25),
            catalog,
            fold,
            asOf,
          ),
          3,
        );
      },
    );

    group('wrapping', () {
      test('a non-wrapping range that is finished has no next unit', () {
        final fold = FoldLog.fold([
          for (var u = 2; u <= 25; u++) done('yoma', u, today),
        ]);
        expect(
          PlanRunProgress.unitOn(
            plan(startUnit: 2, endUnit: 25),
            catalog,
            fold,
            asOf,
          ),
          isNull,
          reason:
              'no wrap and no end: the range is finished, and saying so is '
              'the answer rather than starting it over',
        );
      });

      test(
        'a wrapping range that is finished starts again at its first unit',
        () {
          final fold = FoldLog.fold([
            for (var u = 2; u <= 25; u++) done('yoma', u, today),
          ]);
          expect(
            PlanRunProgress.unitOn(
              plan(startUnit: 2, endUnit: 25, wrapRange: true),
              catalog,
              fold,
              asOf,
            ),
            2,
          );
        },
      );

      test('a second lap of the same units does not advance the pointer', () {
        // **This is the case the whole no-lap-counter design turns on.** All 24
        // units learned, then 2-7 learned *again*: the log records 30 marks and
        // cannot say which lap any of them belongs to. So the rule reduces to
        // "first unit not marked done" — every unit is still marked done, so the
        // pointer stays at the start of the range.
        //
        // An earlier draft of this test expected 8, reasoning that "6 into the
        // second lap" must be derivable. It is not, and it does not need to be:
        // the owner ruled that a wrapping plan is *infinite*, so there is no lap
        // number, and progress is how many units are done (24 here, unchanged by
        // relearning). What the app can honestly say is which units are not yet
        // marked — and none are. The "learnt twice" fact lives on the unit grid,
        // where #46 puts it, and is deliberately not read here.
        final fold = FoldLog.fold([
          for (var u = 2; u <= 25; u++) done('yoma', u, today),
          for (var u = 2; u <= 7; u++)
            done('yoma', u, today.add(const Duration(days: 1))),
        ]);
        final p = plan(startUnit: 2, endUnit: 25, wrapRange: true);
        expect(PlanRunProgress.unitOn(p, catalog, fold, asOf), 2);
        expect(
          PlanRunProgress.doneUnits(p, catalog, fold, asOf),
          24,
          reason:
              '24 units are done; the 6 relearned do not inflate a count '
              'of units',
        );
      });

      test('un-ticking in a later lap pulls the pointer back to that unit', () {
        // The one thing a wrapping range *can* be sensitive to, and the reason
        // the rule reads the fold rather than counting marks: if a unit is no
        // longer marked done, it is genuinely owed again.
        final fold = FoldLog.fold([
          for (var u = 2; u <= 25; u++) done('yoma', u, today),
          undone('yoma', 9, today.add(const Duration(days: 1))),
        ]);
        expect(
          PlanRunProgress.unitOn(
            plan(startUnit: 2, endUnit: 25, wrapRange: true),
            catalog,
            fold,
            asOf,
          ),
          9,
        );
      });

      test('wrapping a single-sefer plan works with no chain in sight', () {
        // The case that proves the two wraps are orthogonal: one sefer, no
        // "continue" anywhere, and it still wraps its own range.
        final p = plan(startUnit: 2, endUnit: 4, wrapRange: true);
        final fold = FoldLog.fold([
          done('yoma', 2, today),
          done('yoma', 3, today),
          done('yoma', 4, today),
        ]);
        expect(PlanRunProgress.unitOn(p, catalog, fold, asOf), 2);
        expect(p.flowsToNextItem, isFalse);
      });
    });
  });

  group('through the chain', () {
    LearningPlan chain({required bool flows, int? endUnit}) => LearningPlan(
      id: 'p',
      name: 'P',
      items: [
        PlanItem(id: 'a', nodeId: 'yoma', endUnit: endUnit),
        const PlanItem(id: 'b', nodeId: 'sukkah'),
      ],
      flowsToNextItem: flows,
    );

    test('a plan that does not flow stops at the end of the first sefer', () {
      // The whole of Yoma is units 2..31, so "finished" means all thirty.
      final fold = FoldLog.fold([
        for (var u = 2; u <= 31; u++) done('yoma', u, today),
      ]);
      final pos = PlanProgress.positionOn(
        chain(flows: false),
        catalog,
        fold,
        asOf,
      );
      expect(pos.itemIndex, 0);
      expect(
        pos.isComplete,
        isTrue,
        reason:
            'listing four seferim and stopping at the first is an '
            'intention, not a bug',
      );
    });

    test('a plan that flows moves to the next sefer', () {
      final fold = FoldLog.fold([
        for (var u = 2; u <= 31; u++) done('yoma', u, today),
      ]);
      final pos = PlanProgress.positionOn(
        chain(flows: true),
        catalog,
        fold,
        asOf,
      );
      expect(pos.itemIndex, 1);
      expect(pos.nodeId, 'sukkah');
    });

    test('an item whose node was deleted is skipped, not fatal', () {
      const gone = LearningPlan(
        id: 'p',
        name: 'P',
        items: [
          PlanItem(id: 'a', nodeId: 'deleted-node'),
          PlanItem(id: 'b', nodeId: 'sukkah'),
        ],
        flowsToNextItem: true,
      );
      final pos = PlanProgress.positionOn(
        gone,
        catalog,
        FoldLog.fold([]),
        asOf,
      );
      expect(pos.itemIndex, 1);
    });

    test('a unit learned on the day asked about is still owed that day', () {
      // The day a plan finishes, it is not yet finished: this is what stops a
      // plan reporting itself complete on the day it completes. Dated on [asOf]
      // deliberately, which is the only date that exercises the rule.
      final learnedOnAsOf = FoldLog.fold([done('yoma', 2, asOf.midnight)]);
      expect(
        PlanProgress.positionOn(
          chain(flows: true),
          catalog,
          learnedOnAsOf,
          asOf,
        ).unitIndex,
        2,
        reason: 'learned on this day, so still owed on this day',
      );
      // A day later it is counted, and the pointer moves on.
      expect(
        PlanProgress.positionOn(
          chain(flows: true),
          catalog,
          learnedOnAsOf,
          asOf + 1,
        ).unitIndex,
        3,
      );
    });
  });
}
