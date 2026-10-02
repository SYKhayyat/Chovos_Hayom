import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/day_ledger.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/plan_run.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

/// #50, part 1 — "do this N times a day", rather than merely "N units a day".
///
/// **The gap this file exists to pin.** A plan's amount is units per day and its
/// range is a run through units. A plan that means *the same unit three times*
/// has no way to say so: asked for three on a range of one, the ledger handed
/// back **one row** and the count line read "0 of 1 done" — a plan asking for
/// three reporting one, which is the exact shape of the visible mis-report this
/// repository keeps building rules to refuse.
///
/// **No new stored state, which is the load-bearing part.** The log already
/// counts passes per unit per day (`LogFold.doneCountOn`), so a third repetition
/// is a third `done` event and nothing else has to be stored to know about it.
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

final day = Day.of(DateTime.utc(2026, 3, 5));

final catalog = Catalog([
  const CatalogNode(
    id: 'root',
    parentId: null,
    name: 'Root',
    kind: NodeKind.category,
  ),
  const CatalogNode(
    id: 's',
    parentId: 'root',
    name: 'S',
    kind: NodeKind.leaf,
    unitLabel: UnitLabel.daf,
    unitCount: 10,
    unitOffset: 2,
  ),
]);

/// A plan over `start..end`, wrapping if asked.
LearningPlan plan({
  required int perDay,
  required int start,
  required int end,
  bool wraps = false,
}) => LearningPlan(
  id: 'p',
  name: 'P',
  unitsPerDay: perDay,
  items: [
    PlanItem(
      id: 'i1',
      nodeId: 's',
      startUnit: start,
      endUnit: end,
      wrapsRange: wraps,
    ),
  ],
  assignments: const [PlanAssignment(id: 'a', rule: DailyRule())],
);

List<LedgerUnit> unitsFor(LearningPlan p, LogFold fold) =>
    DayLedger.unitsFor(p, catalog, fold, day);

void main() {
  setUp(() => _seq = 0);

  group('a wrapping range hands out the same unit again', () {
    test('the case the issue describes: one unit, three times a day', () {
      final units = unitsFor(
        plan(perDay: 3, start: 2, end: 2, wraps: true),
        FoldLog.fold([]),
      );
      expect(
        units,
        hasLength(3),
        reason:
            'the plan asked for three, and reporting one is the defect. The '
            'wrap setting is the user saying "go round again", and three a day '
            'over a one-unit range is three rounds of it',
      );
      expect(units.every((u) => u.unitIndex == 2), isTrue);
    });

    test('each row knows which pass of the unit it is', () {
      final units = unitsFor(
        plan(perDay: 3, start: 2, end: 2, wraps: true),
        FoldLog.fold([]),
      );
      expect(
        units.map((u) => u.occurrence),
        [0, 1, 2],
        reason:
            'three rows for one unit are indistinguishable without it — the '
            'same key three times over, and a tap on one that marked all three',
      );
    });

    test('a wider range cycles too, rather than stopping at its end', () {
      final units = unitsFor(
        plan(perDay: 5, start: 2, end: 3, wraps: true),
        FoldLog.fold([]),
      );
      expect(units.map((u) => u.unitIndex), [2, 3, 2, 3, 2]);
    });

    test('a range larger than the amount is unaffected', () {
      // The ordinary case, and the one that must not change: Daf Yomi asking 3
      // over a 156-daf sefer still offers three *different* units.
      final units = unitsFor(
        plan(perDay: 3, start: 2, end: 11, wraps: true),
        FoldLog.fold([]),
      );
      expect(units.map((u) => u.unitIndex), [2, 3, 4]);
      expect(
        units.map((u) => u.occurrence),
        [0, 0, 0],
        reason:
            'three different units are each their first pass; the occurrence '
            'counts passes of one unit, not rows',
      );
    });
  });

  group('a range that does not wrap still stops at its end', () {
    test('and says so with a short ledger rather than a repeat', () {
      // **Not cycling is the honest answer here**, and the two cases are what
      // tell them apart: a non-wrapping range asked for more than it holds has
      // nothing more to offer, and repeating its units would be inventing work
      // the plan did not ask for.
      final units = unitsFor(
        plan(perDay: 5, start: 2, end: 3),
        FoldLog.fold([]),
      );
      expect(units.map((u) => u.unitIndex), [2, 3]);
    });
  });

  group('a pass is a pass on a day, and only on that day', () {
    test('ticking one of three leaves the other two owed', () {
      final fold = FoldLog.fold([done('s', 2, day)]);
      final units = unitsFor(
        plan(perDay: 3, start: 2, end: 2, wraps: true),
        fold,
      );
      expect(units.map((u) => u.doneHere), [true, false, false]);
      expect(
        DayLedger.owed(units),
        2,
        reason: 'a plan asking three times with one done is two short',
      );
    });

    test('two ticks show as two done, not one unit done twice over', () {
      final fold = FoldLog.fold([done('s', 2, day), done('s', 2, day)]);
      final units = unitsFor(
        plan(perDay: 3, start: 2, end: 2, wraps: true),
        fold,
      );
      expect(units.map((u) => u.doneHere), [true, true, false]);
    });

    test('a pass done on another day does not count for this one', () {
      // **The same rule the ledger already had, applied per pass**: a unit
      // learned on Thursday is not evidence about Friday, and the third pass is
      // genuinely still owed.
      final fold = FoldLog.fold([done('s', 2, day - 1)]);
      final units = unitsFor(
        plan(perDay: 3, start: 2, end: 2, wraps: true),
        fold,
      );
      expect(
        units.map((u) => u.doneHere),
        [false, false, false],
        reason: 'yesterday\'s pass is not any of today\'s three',
      );
      expect(
        DayLedger.owed(units),
        2,
        reason:
            'the first is not owed, on the same rule Daf Yomi relies on: the '
            'plan already has that unit done, so ticking it here is no new '
            'work. The second and third passes are owed, which is the whole of '
            'what "three times a day" asks for',
      );
    });

    test('and a later pass is not read as an earlier one', () {
      // Two done today and one yesterday: today owes only its third.
      final fold = FoldLog.fold([
        done('s', 2, day - 1),
        done('s', 2, day),
        done('s', 2, day),
      ]);
      final units = unitsFor(
        plan(perDay: 3, start: 2, end: 2, wraps: true),
        fold,
      );
      expect(units.map((u) => u.doneHere), [true, true, false]);
      expect(units[2].doneElsewhere, isFalse, reason: 'it is simply owed');
    });
  });

  group('and it is not chazara', () {
    // The issue's open question: is "three times a day" a separate counter from
    // chazara, or the same fact? **Both facts are already in the log and they
    // are not the same one**, which settles it without a ruling.

    test('three passes in one day are one chazara pass, not three', () {
      final fold = FoldLog.fold([
        done('s', 2, day),
        done('s', 2, day),
        done('s', 2, day),
      ]);
      expect(
        fold.chazaraCount('s', 2),
        1,
        reason:
            '"learned means chazara" (#45): the first pass is the learning, and '
            'repeating it this morning is not three visits over three days',
      );
      expect(
        fold.doneCountOn('s', 2, day),
        3,
        reason:
            'while the day ledger counts three, and that is a different '
            'question about the same unit',
      );
    });

    test('chazara still counts a later return on a later day', () {
      final fold = FoldLog.fold([done('s', 2, day - 3), done('s', 2, day)]);
      expect(
        fold.chazaraCount('s', 2),
        1,
        reason:
            'a re-learn *replaces* the learning date and #45 counts passes as '
            'reviews + 1 — so a plain re-learn is still one pass, and the '
            'counter that moves is the day ledger\'s',
      );
    });
  });

  group('the plan standing is unaffected', () {
    test('repeats do not inflate a plan\'s progress', () {
      // The two counters answering different questions, kept apart: progress is
      // how many *units* are done and a repeated unit is not more progress.
      final p = plan(perDay: 3, start: 2, end: 2, wraps: true);
      final fold = FoldLog.fold([
        done('s', 2, day),
        done('s', 2, day),
        done('s', 2, day),
      ]);
      expect(PlanRunProgress.doneUnits(p, catalog, fold, day + 1), 1);
      expect(
        PlanRunProgress.totalUnits(p, catalog),
        isNull,
        reason: 'a wrapping range is still endless, so still no fraction',
      );
    });
  });

  group('a ledger row is a value type', () {
    LedgerUnit row({
      int unit = 2,
      int occurrence = 0,
      bool here = false,
      int count = 0,
      int today = 0,
      Day? on,
    }) => LedgerUnit(
      nodeId: 's',
      unitIndex: unit,
      occurrence: occurrence,
      doneHere: here,
      doneCount: count,
      doneToday: today,
      doneOn: on,
    );

    test('equal rows collapse in a set, which needs hashCode', () {
      // The occurrence is the newest field, and a field left out of the
      // comparison is the silent one: two rows of the same unit would compare
      // equal and the ledger would treat a second pass as the first.
      expect(row(), row());
      expect(row().hashCode, row().hashCode);
      expect({row(), row()}, hasLength(1));
    });

    test('and every field is part of what makes two rows equal', () {
      expect(row(), isNot(row(unit: 3)));
      expect(row(), isNot(row(occurrence: 1)));
      expect(row(), isNot(row(here: true)));
      expect(row(), isNot(row(count: 2)));
      expect(row(), isNot(row(today: 1)));
      expect(row(), isNot(row(on: day)));
    });

    test('and its printed form names the pass when there is one', () {
      expect(row().toString(), contains('LedgerUnit(s 2'));
      expect(
        row(occurrence: 2).toString(),
        contains('#2'),
        reason:
            'three rows for one unit are otherwise indistinguishable in a log '
            'or a test failure',
      );
    });
  });
}
