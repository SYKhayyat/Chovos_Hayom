import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/day_ledger.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

/// #42's day ledger: a day's units come from the plan, ticked against the log.
///
/// **The two claims this file exists to keep apart.** A unit ticked in the
/// *calendar* is a fact about the world, so every other view must know at once.
/// A unit ticked in the *unit grid* is still a unit the plan asked for — it must
/// not disappear from the plan, or the calendar stops being worth opening and
/// the gap between planned and done is gone with it.
var _seq = 0;
LearningEvent done(String node, int unit, DateTime day, {String? planId}) =>
    LearningEvent(
      id: 'e${_seq++}',
      profileId: 'p',
      nodeId: node,
      unitIndex: unit,
      action: EventAction.done,
      occurredAt: day,
      loggedAt: day,
      planId: planId,
    );

final thursday = DateTime.utc(2026, 3, 5);
final monday = DateTime.utc(2026, 3, 2);

final catalog = Catalog([
  const CatalogNode(id: 'root', parentId: null, name: 'Root', kind: NodeKind.category),
  const CatalogNode(
      id: 'shabbos',
      parentId: 'root',
      name: 'Shabbos',
      kind: NodeKind.leaf,
      unitLabel: UnitLabel.daf,
      unitCount: 10,
      unitOffset: 2),
]);

LearningPlan plan({int unitsPerDay = 3, PlanPacing? pacing}) => LearningPlan(
      id: 'daf-yomi',
      name: 'Daf Yomi',
      unitsPerDay: unitsPerDay,
      assignments: const [PlanAssignment(id: 'a', rule: DailyRule())],
      items: const [PlanItem(id: 'i1', nodeId: 'shabbos')],
      pacing: pacing ?? AmountPerDay(unitsPerDay),
    );

void main() {
  setUp(() => _seq = 0);

  final day = Day.of(thursday);

  group('a day owes what the plan asks', () {
    test('with nothing done, the first units are all owed', () {
      final units =
          DayLedger.unitsFor(plan(), catalog, FoldLog.fold([]), day);
      expect(units, hasLength(3));
      expect(units.map((u) => u.unitIndex), [2, 3, 4]);
      expect(DayLedger.owed(units), 3);
      expect(DayLedger.doneOnDay(units), 0);
    });

    test('the amount decides how many', () {
      expect(
        DayLedger.unitsFor(plan(unitsPerDay: 5), catalog, FoldLog.fold([]), day),
        hasLength(5),
      );
    });

    test('a day asking for nothing has no ledger, rather than an empty one', () {
      // A deliberate zero is a day off, and a day off is not a day of six
      // outstanding units — the distinction the whole planner keeps.
      const off = LearningPlan(
        id: 'off',
        name: 'Off',
        unitsPerDay: 0,
        assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
        items: [PlanItem(id: 'i1', nodeId: 'shabbos')],
      );
      expect(DayLedger.unitsFor(off, catalog, FoldLog.fold([]), day), isEmpty);
    });

    test('a plan asking for more than its sefer has is short, not padded', () {
      // Shabbos here holds 10 units, so a plan asking 30 gets 10 — and the
      // shortfall is visible as a short list rather than as the same unit
      // offered three times, which the log has no events for.
      final units =
          DayLedger.unitsFor(plan(unitsPerDay: 30), catalog, FoldLog.fold([]), day);
      expect(units, hasLength(10));
      expect(units.map((u) => u.unitIndex).toSet(), hasLength(10));
    });
  });

  group('ticking, in both directions of the asymmetry', () {
    test('a unit ticked in the calendar shows as done here', () {
      final fold = FoldLog.fold([done('shabbos', 2, thursday)]);
      final units = DayLedger.unitsFor(plan(), catalog, fold, day);
      expect(units.first.doneHere, isTrue);
      expect(DayLedger.doneOnDay(units), 1);
      expect(DayLedger.owed(units), 2);
    });

    test('a unit ticked in the GRID is still in the plan’s list', () {
      // **The claim that matters most.** A grid tick carries no plan id — it is
      // a fact about the learner — and it must still leave the unit in the day's
      // ledger, because the plan still asks for it. A ledger built from the log
      // would drop it and the calendar would stop showing what is outstanding.
      final fold = FoldLog.fold([done('shabbos', 2, thursday)]);
      final units = DayLedger.unitsFor(plan(), catalog, fold, day);
      expect(units, hasLength(3),
          reason: 'the plan asks for three, so three rows are shown');
      expect(units.map((u) => u.unitIndex), contains(2),
          reason: 'and the one already done is one of them, ticked');
    });

    test('a unit done on ANOTHER day is neither done here nor outstanding', () {
      // Ticking it Thursday when you did it Monday does not make Thursday look
      // done — and it is not work still owed either. Shown, and its own state.
      final fold = FoldLog.fold([done('shabbos', 2, monday)]);
      final units = DayLedger.unitsFor(plan(), catalog, fold, day);
      final u = units.first;
      expect(u.doneHere, isFalse);
      expect(u.doneElsewhere, isTrue);
      expect(u.doneOn, Day.of(monday));
      // **Owed counts only what was never done**, so it is 2 and not 3. The
      // unit done on Monday is not work still outstanding — it is a fact about
      // Monday, and adding it to today's outstanding would tell the learner they
      // owe something they already did. It has its own state, and its own count.
      expect(DayLedger.owed(units), 2);
      expect(DayLedger.doneOnDay(units), 0);
      expect(units.where((u) => u.doneElsewhere), hasLength(1));
    });

    test('so the three states are distinct and countable', () {
      final fold = FoldLog.fold([
        done('shabbos', 2, thursday), // done here
        done('shabbos', 3, monday), // done elsewhere
        // 4 never done
      ]);
      final units = DayLedger.unitsFor(plan(), catalog, fold, day);
      expect(units[0].doneHere, isTrue);
      expect(units[1].doneElsewhere, isTrue);
      expect(units[2].doneCount, 0);
      expect(DayLedger.doneOnDay(units), 1);
    });
  });

  group('a unit done twice', () {
    test('keeps the count and is done here once, not twice', () {
      // Two plans covering it, both ticked on this day. The count is two — the
      // owner's ruling — but the row is a single unit, and a day does not offer
      // the same daf twice because two of its plans asked for it.
      final fold = FoldLog.fold([
        done('shabbos', 2, thursday, planId: 'daf-yomi'),
        done('shabbos', 2, thursday, planId: 'slow'),
      ]);
      final units = DayLedger.unitsFor(plan(), catalog, fold, day);
      expect(units, hasLength(3));
      expect(units.first.doneCount, 2);
      expect(units.first.doneHere, isTrue);
    });

    test('and done long ago and now reads as two, not one', () {
      final fold = FoldLog.fold([
        done('shabbos', 2, DateTime.utc(2019, 5, 1)),
        done('shabbos', 2, thursday),
      ]);
      final units = DayLedger.unitsFor(plan(), catalog, fold, day);
      expect(units.first.doneCount, 2);
      expect(units.first.doneOn, day, reason: 'the latest day is what "when" means');
    });
  });

  group('un-ticking', () {
    test('makes a unit outstanding again', () {
      final fold = FoldLog.fold([
        done('shabbos', 2, thursday),
        LearningEvent(
          id: 'u1',
          profileId: 'p',
          nodeId: 'shabbos',
          unitIndex: 2,
          action: EventAction.undone,
          occurredAt: thursday,
          loggedAt: thursday,
        ),
      ]);
      final units = DayLedger.unitsFor(plan(), catalog, fold, day);
      expect(units.first.doneHere, isFalse);
      expect(units.first.doneCount, 0);
      expect(DayLedger.owed(units), 3);
    });
  });

  group('across several plans', () {
    test('each plan gets its own ledger, and a silent one is dropped', () {
      const off = LearningPlan(
        id: 'off',
        name: 'Off',
        unitsPerDay: 0,
        assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
        items: [PlanItem(id: 'i1', nodeId: 'shabbos')],
      );
      final ledgers = DayLedger.forDay(
        [plan(), off],
        catalog,
        FoldLog.fold([]),
        day,
      );
      expect(ledgers, hasLength(1), reason: 'the day off has nothing to show');
      expect(ledgers.single.plan.id, 'daf-yomi');
    });
  });
}
