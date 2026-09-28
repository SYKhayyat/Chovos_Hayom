import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/plan_position.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:chovos_hayom/domain/usecases/spillover.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// A four-step sequence in the shape the requester described: Yoma, then Sukkah,
/// then Chagigah, then Moed. Each is two units so the boundaries are easy to hit
/// exactly.
final catalog = Catalog([
  const   CatalogNode(id: 'root', parentId: null, name: 'Root', kind: NodeKind.category),
  const   CatalogNode(
      id: 'yoma',
      parentId: 'root',
      name: 'Yoma',
      kind: NodeKind.leaf,
      unitLabel: UnitLabel.daf,
      unitCount: 2,
      unitOffset: 1),
  const   CatalogNode(
      id: 'sukkah',
      parentId: 'root',
      name: 'Sukkah',
      kind: NodeKind.leaf,
      unitLabel: UnitLabel.daf,
      unitCount: 2,
      unitOffset: 1),
  const   CatalogNode(
      id: 'chagigah',
      parentId: 'root',
      name: 'Chagigah',
      kind: NodeKind.leaf,
      unitLabel: UnitLabel.daf,
      unitCount: 2,
      unitOffset: 1),
  const   CatalogNode(
      id: 'moed',
      parentId: 'root',
      name: 'Moed',
      kind: NodeKind.category,
  ),
  const   CatalogNode(
      id: 'moed.shabbos',
      parentId: 'moed',
      name: 'Shabbos',
      kind: NodeKind.leaf,
      unitLabel: UnitLabel.perek,
      unitCount: 2,
      unitOffset: 1),
]);

final today = Day.of(DateTime(2026, 1, 10));

LearningPlan sequence({
  bool flows = true,
  List<PlanItem>? items,
  int unitsPerDay = 2,
  SpilloverMode spillover = SpilloverMode.ignore,
}) =>
    LearningPlan(
      id: 'chain',
      name: 'Chain',
      unitsPerDay: unitsPerDay,
      spillover: spillover,
      flowsToNextItem: flows,
      items: items ??
          const [
            PlanItem(id: 'i1', nodeId: 'yoma'),
            PlanItem(id: 'i2', nodeId: 'sukkah'),
            PlanItem(id: 'i3', nodeId: 'chagigah'),
            PlanItem(id: 'i4', nodeId: 'moed'),
          ],
    );

void main() {
  setUp(() => _seq = 0);

  group('PlanItem and the sequence', () {
    test('items round-trip through JSON, in order', () {
      final p = sequence();
      final restored = LearningPlan.fromJson(p.toJson());
      expect(restored, p);
      expect(restored.items.map((i) => i.nodeId),
          ['yoma', 'sukkah', 'chagigah', 'moed'],
          reason: 'order is the whole point of a sequence');
      expect(restored.flowsToNextItem, isTrue);
    });

    test('a plan with no sequence round-trips and does not flow', () {
      const bare = LearningPlan(id: 'b', name: 'B');
      final restored = LearningPlan.fromJson(bare.toJson());
      expect(restored, bare);
      expect(restored.items, isEmpty);
      expect(restored.flowsToNextItem, isFalse,
          reason: 'flowing is opt-in; a plan that lists four seferim and stops '
              'at the first is expressing an intention, not a bug');
    });

    test('the flow toggle and the items are part of equality', () {
      expect(sequence(), sequence());
      expect(sequence(), isNot(sequence(flows: false)));
      expect(
        sequence(),
        isNot(sequence(items: const [PlanItem(id: 'i1', nodeId: 'yoma')])),
      );
    });

    test('PlanItem is a value type', () {
      expect(
        const PlanItem(id: 'a', nodeId: 'n'),
        const PlanItem(id: 'a', nodeId: 'n'),
      );
      expect(
        const PlanItem(id: 'a', nodeId: 'n'),
        isNot(const PlanItem(id: 'a', nodeId: 'n', label: 'x')),
      );
    });
  });

  group('totals', () {
    test('a category item counts every unit under it', () {
      // Yoma 2 + Sukkah 2 + Chagigah 2 + Moed(Shabbos) 2 = 8.
      expect(PlanProgress.totalUnits(sequence(), catalog), 8);
    });

    test('an item whose node is not in the catalog contributes nothing', () {
      final p = sequence(
        items: const [
          PlanItem(id: 'i1', nodeId: 'yoma'),
          PlanItem(id: 'gone', nodeId: 'deleted-node'),
        ],
      );
      expect(PlanProgress.totalUnits(p, catalog), 2);
    });

    test('with no sequence the totals come from the assignment targets', () {
      const p = LearningPlan(
        id: 'p',
        name: 'P',
        assignments: [
          PlanAssignment(id: 'a', rule: DailyRule(), targetNodeId: 'yoma'),
        ],
      );
      expect(PlanProgress.totalUnits(p, catalog), 2);
    });
  });

  group('where you are holding', () {
    test('nothing done: the first item, first unit', () {
      final pos = PlanProgress.positionOn(
          sequence(), catalog, FoldLog.fold([]), today);
      expect(pos.itemIndex, 0);
      expect(pos.itemId, 'i1');
      expect(pos.nodeId, 'yoma');
      expect(pos.unitIndex, 1);
      expect(pos.remaining, 8);
      expect(pos.isComplete, isFalse);
    });

    test('advances through the units of an item', () {
      final fold = FoldLog.fold([done('yoma', 1, DateTime(2026, 1, 1))]);
      final pos =
          PlanProgress.positionOn(sequence(), catalog, fold, today);
      expect(pos.itemId, 'i1');
      expect(pos.unitIndex, 2, reason: 'daf 1 done, so daf 2 is next');
      expect(pos.remaining, 7);
    });

    test('flows to the next item on a boundary when told to', () {
      final fold = FoldLog.fold([
        for (var u = 1; u <= 2; u++) done('yoma', u, DateTime(2026, 1, 1)),
      ]);
      final pos = PlanProgress.positionOn(sequence(), catalog, fold, today);
      expect(pos.itemIndex, 1, reason: 'Yoma is finished, so Sukkah');
      expect(pos.itemId, 'i2');
      expect(pos.nodeId, 'sukkah');
      expect(pos.unitIndex, 1);
    });

    test('stops at the end of the first item when flow is off', () {
      final fold = FoldLog.fold([
        for (var u = 1; u <= 2; u++) done('yoma', u, DateTime(2026, 1, 1)),
      ]);
      final pos =
          PlanProgress.positionOn(sequence(flows: false), catalog, fold, today);
      expect(pos.isComplete, isTrue,
          reason: 'Yoma is done and we are not told to continue');
      expect(pos.remaining, 6, reason: 'the rest is genuinely still owed');
    });

    test('a category item reports the leaf, not the category, as the unit', () {
      // The position is "Moed, Shabbos perek 2" — the item is the category, the
      // unit belongs to the leaf underneath it.
      final fold = FoldLog.fold([
        for (final id in ['yoma', 'sukkah', 'chagigah'])
          for (var u = 1; u <= 2; u++) done(id, u, DateTime(2026, 1, 1)),
        done('moed.shabbos', 1, DateTime(2026, 1, 1)),
      ]);
      final pos = PlanProgress.positionOn(sequence(), catalog, fold, today);
      expect(pos.itemId, 'i4');
      expect(pos.nodeId, 'moed');
      expect(pos.unitNodeId, 'moed.shabbos');
      expect(pos.unitIndex, 2);
      expect(pos.remaining, 1);
    });

    test('a unit learned today does not count as done today', () {
      // Learning something *on* today has not been done *by* today, or a plan
      // could report itself finished on the very day it finishes.
      final fold = FoldLog.fold([
        for (final id in ['yoma', 'sukkah', 'chagigah'])
          for (var u = 1; u <= 2; u++) done(id, u, today.midnight),
        for (var u = 1; u <= 2; u++) done('moed.shabbos', u, today.midnight),
      ]);
      final pos = PlanProgress.positionOn(sequence(), catalog, fold, today);
      expect(pos.isComplete, isFalse);
      expect(pos.remaining, 8);
      // ...but by tomorrow it has.
      final tomorrow = PlanProgress.positionOn(
          sequence(), catalog, fold, today + 1);
      expect(tomorrow.isComplete, isTrue);
    });

    test('an item whose node was deleted is skipped, not fatal', () {
      final p = sequence(
        items: const [
          PlanItem(id: 'i1', nodeId: 'deleted-node'),
          PlanItem(id: 'i2', nodeId: 'yoma'),
        ],
      );
      final pos = PlanProgress.positionOn(p, catalog, FoldLog.fold([]), today);
      expect(pos.itemId, 'i2', reason: 'a custom node can be deleted underneath');
      expect(pos.nodeId, 'yoma');
    });

    test('a fully-finished sequence reads as complete', () {
      final fold = FoldLog.fold([
        for (final id in ['yoma', 'sukkah', 'chagigah'])
          for (var u = 1; u <= 2; u++) done(id, u, DateTime(2026, 1, 1)),
        for (var u = 1; u <= 2; u++)
          done('moed.shabbos', u, DateTime(2026, 1, 1)),
      ]);
      final pos = PlanProgress.positionOn(sequence(), catalog, fold, today + 1);
      expect(pos.isComplete, isTrue);
      expect(pos.remaining, 0);
      expect(pos.unitIndex, isNull);
    });

    test('a plan with no sequence still reports a position', () {
      const p = LearningPlan(
        id: 'p',
        name: 'P',
        assignments: [
          PlanAssignment(id: 'a', rule: DailyRule(), targetNodeId: 'yoma'),
        ],
      );
      final pos = PlanProgress.positionOn(p, catalog, FoldLog.fold([]), today);
      expect(pos.itemIndex, -1, reason: 'no sequence to index into');
      expect(pos.nodeId, 'yoma');
      expect(pos.unitIndex, 1);
    });
  });

  group('the projected siyum day', () {
    DayInfo info(Day day) => DayInfo(
          day: day,
          weekday: day.weekday,
          dayOfMonth: day.midnight.day,
        );

    test('is derived from cumulative amounts, never stored', () {
      // 6 units left at 2/day: three days.
      final finish = PlanSchedule.projectedFinishDay(
        sequence(),
        remaining: 6,
        info: info,
        from: today,
        to: today + 30,
      );
      expect(finish, today + 2);
    });

    test('a faster plan finishes sooner', () {
      final slow = PlanSchedule.projectedFinishDay(sequence(unitsPerDay: 2),
          remaining: 6, info: info, from: today, to: today + 30);
      final fast = PlanSchedule.projectedFinishDay(sequence(unitsPerDay: 6),
          remaining: 6, info: info, from: today, to: today + 30);
      expect(slow, today + 2);
      expect(fast, today, reason: 'six at six a day is today');
    });

    test('nothing remaining finishes today', () {
      expect(
        PlanSchedule.projectedFinishDay(sequence(),
            remaining: 0, info: info, from: today, to: today + 30),
        today,
      );
    });

    test('more remaining than the window holds answers honestly', () {
      expect(
        PlanSchedule.projectedFinishDay(sequence(),
            remaining: 999, info: info, from: today, to: today + 3),
        isNull,
      );
    });

    test('a day off pushes the finish out, because the amount is 0', () {
      final p = LearningPlan(
        id: 'p',
        name: 'P',
        unitsPerDay: 2,
        dateAmounts: {today: 0},
      );
      // 2 units at 2/day would be today; today asks 0, so it is tomorrow.
      expect(
        PlanSchedule.projectedFinishDay(p,
            remaining: 2, info: info, from: today, to: today + 10),
        today + 1,
      );
    });

    test('a shortfall already owed is carried into the projection', () {
      // 2 units left but already 2 behind: the balance starts owed, so the
      // catch-up day asks for more and the answer can differ.
      final p = sequence(spillover: SpilloverMode.catchUp);
      final finish = PlanSchedule.projectedFinishDay(
        p,
        remaining: 4,
        info: info,
        from: today,
        to: today + 30,
        owedAtStart: 2,
      );
      // today: asks 2 + 2 owed = 4, which covers the 4 remaining.
      expect(finish, today);
    });

    test('agrees with the log when nothing is owed and the rate is flat', () {
      // The invariant that matters: a flat plan at 2/day with nothing owed
      // reduces to the plain remaining/rate answer, so the projection cannot
      // drift from the schedule walk it is built on.
      final walk = PlanSchedule.walk(sequence(),
          info: info, from: today, to: today + 10, owedAtStart: 0, doneOn: (_) => 0);
      var covered = 0;
      var byHand = today;
      for (final day in walk) {
        covered += day.amount;
        if (covered >= 8) {
          byHand = day.day;
          break;
        }
      }
      expect(
        PlanSchedule.projectedFinishDay(sequence(),
            remaining: 8, info: info, from: today, to: today + 10),
        byHand,
      );
    });
  });

  group('PlanPosition is a value type', () {
    test('equal positions compare equal', () {
      const a = PlanPosition(
        itemIndex: 1,
        itemId: 'i',
        nodeId: 'n',
        unitNodeId: 'n',
        unitIndex: 3,
        remaining: 5,
      );
      expect(a, a);
      expect(
        a,
        const PlanPosition(
          itemIndex: 1,
          itemId: 'i',
          nodeId: 'n',
          unitNodeId: 'n',
          unitIndex: 3,
          remaining: 5,
        ),
      );
      expect(a.hashCode, a.hashCode);
      expect(
        a,
        isNot(const PlanPosition(
          itemIndex: 2,
          itemId: 'i',
          nodeId: 'n',
          unitNodeId: 'n',
          unitIndex: 3,
          remaining: 5,
        )),
      );
    });
  });
}
