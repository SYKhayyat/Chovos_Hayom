import '../../core/day.dart';
import '../../core/planner_dates.dart';
import '../entities/catalog.dart';
import '../entities/catalog_node.dart';
import '../entities/layer.dart';
import 'day_amount.dart';
import 'fold_log.dart';
import 'layer_roles.dart';
import 'learning_plan.dart';
import 'plan_run.dart';

/// One unit a day's ledger offers, and what the log says about it.
///
/// **Three states, not two**, and the third is the one this type exists for. A
/// unit can be done on the day being looked at, done on a *different* day, or
/// not done. "Done elsewhere" is a separate claim: ticking it Thursday when you
/// actually did it Monday does not make Thursday look done, and the difference
/// is the user's business — a backlog is what the plan's pacing acts on next.
///
/// **[occurrence] is which pass of the unit this row is** (#50), and without it
/// a plan that asks for the same unit three times offers three identical rows
/// with the same key and the same state, so ticking one marks all three.
class LedgerUnit {
  const LedgerUnit({
    required this.nodeId,
    required this.unitIndex,
    required this.doneHere,
    required this.doneCount,
    required this.doneOn,
    this.doneToday = 0,
    this.occurrence = 0,
  });

  /// The leaf the unit belongs to.
  final String nodeId;
  final int unitIndex;

  /// Which pass of this unit the row is: `0` for the first, `1` for the second,
  /// and so on. Always `0` unless the plan asked for more of this unit than the
  /// sefer holds.
  final int occurrence;

  /// Done **on the day this ledger is for** — and for pass [occurrence]
  /// specifically, so three passes show as three separate claims rather than one
  /// row that is true three times.
  final bool doneHere;

  /// How many times, ever. More than one is real: a unit learned seven years ago
  /// and again this month, or covered by two plans on the same day.
  final int doneCount;

  /// How many of those passes were **on this day**.
  ///
  /// Kept apart from [doneCount] because "already done elsewhere" has to mean
  /// satisfied *by another day's work*: a unit done twice today and once last week
  /// is owed its third pass today, and adding yesterday's pass into the count
  /// would quietly satisfy it.
  final int doneToday;

  /// The day it *was* done, when not done here. Null when never done.
  final Day? doneOn;

  /// Done, but not on this day. Shown rather than hidden.
  ///
  /// **Satisfied by *another day's* work, against [occurrence]** — the rule Daf
  /// Yomi has always relied on, generalised from "the unit" to "this pass of the
  /// unit". A unit learned last week is not owed again; a unit done twice today
  /// is still owed its third pass, and counting yesterday's pass into the
  /// comparison would quietly satisfy it.
  bool get doneElsewhere {
    if (doneHere) return false;
    return doneCount - doneToday > occurrence;
  }

  @override
  bool operator ==(Object other) =>
      other is LedgerUnit &&
      other.nodeId == nodeId &&
      other.unitIndex == unitIndex &&
      other.occurrence == occurrence &&
      other.doneHere == doneHere &&
      other.doneCount == doneCount &&
      other.doneToday == doneToday &&
      other.doneOn == doneOn;

  @override
  int get hashCode => Object.hash(
    nodeId,
    unitIndex,
    occurrence,
    doneHere,
    doneCount,
    doneToday,
    doneOn,
  );

  @override
  String toString() =>
      'LedgerUnit($nodeId $unitIndex'
      '${occurrence == 0 ? '' : ' #$occurrence'}, '
      'here: $doneHere, count: $doneCount, on: $doneOn)';
}

/// The day's ledger: the units the plans asked for, with the log applied.
///
/// **The plan is the list; the log is what has been ticked against it.** A unit
/// ticked in the unit grid still appears here, because the plan still asks for
/// it, and the only way anything leaves is a deliberate planning act. A ledger
/// built from the log would shrink as the learner works, and the gap between
/// planned and done is the thing worth seeing.
class DayLedger {
  const DayLedger._();

  /// The units [day] owes for [plan], in range order.
  ///
  /// A plan asking for more units than its ranges hold is answered with what it
  /// has, **unless a range wraps** — and that is the whole of "do this N times a
  /// day" (#50).
  ///
  /// **A wrapping range cycles.** The wrap setting is the user saying "when you
  /// reach the end, go round again", so a plan asking for three over a range of
  /// one is asking for that unit three times, and the ledger hands out three
  /// rows for it. Before this it handed back **one** and the count line read
  /// "0 of 1 done" for a plan asking three — a number about the plan's size
  /// where the reader was asking about the plan's day.
  ///
  /// **A range that does not wrap still stops at its end**, short ledger and
  /// visible. It has nothing more to offer, and repeating its units would be
  /// inventing work the plan did not ask for; the two cases are exactly what
  /// tells them apart.
  ///
  /// **Over [PlanRange.rangesOf], not over `plan.items` directly.** A plan can
  /// name what to work through in its assignments rather than in a sequence, and
  /// a ledger that only walked the sequence offered such a plan no row at all —
  /// which reads on the day sheet as "nothing is scheduled here" about a plan
  /// that is plainly scheduled.
  static List<LedgerUnit> unitsFor(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day day, {
    LayerRoles? layers,
  }) {
    final amount = DayAmount.of(plan, dayInfoFor(day));
    if (amount <= 0) return const [];

    final out = <LedgerUnit>[];
    // **Passes of each unit, not rows.** Two units on the same day are both
    // their first occurrence; only a unit coming round again is its second. The
    // row's own index would have made Daf Yomi's first three dapim read as three
    // passes of one unit.
    final seen = <(String, int), int>{};
    for (final range in PlanRange.rangesOf(plan, catalog)) {
      if (out.length >= amount) break;
      if (range == null) continue;
      for (final (node, unit) in _walk(range, catalog, range.wraps)) {
        if (out.length >= amount) break;
        final occurrence = seen.update(
          (node.id, unit),
          (n) => n + 1,
          ifAbsent: () => 0,
        );
        out.add(_unit(node.id, unit, fold, day, layers, occurrence));
      }
    }
    return out;
  }

  /// One range's units, **round again** when it [wraps] and the day's amount is
  /// not yet met.
  ///
  /// **Generated, never held.** `PlanRange.walk` is a generator, so a second
  /// round is a second walk rather than a copy of the first — which matters
  /// because a range can be a whole category and a day asks for three of it.
  ///
  /// **From the start, not from where it stopped.** That is what "go round
  /// again" means, and it keeps a day's sequence a predictable shape: a range of
  /// `a, b` asked for five is `a b a b a`. The occurrence is the row's own index
  /// in the day's ledger, so the two cannot drift apart.
  static Iterable<(CatalogNode, int)> _walk(
    PlanRange range,
    Catalog catalog,
    bool wraps,
  ) sync* {
    if (!wraps) {
      yield* range.walk(catalog);
      return;
    }
    for (var round = 0; round < _horizon; round++) {
      yield* range.walk(catalog);
    }
  }

  /// How many times a wrapping range may go round for one day.
  ///
  /// The day's own amount already bounds it — the caller stops at `amount` — so
  /// this is a backstop against a malformed amount rather than a policy.
  static const _horizon = 1000;

  /// The ledger for every plan that asks for something on [day], dropping the
  /// ones that owe nothing.
  ///
  /// A plan whose weekday or date override says `0` is a **deliberate day off**,
  /// so it contributes no ledger at all. That is the same "0 means nothing
  /// today, not not-configured" rule the calendar and the editor keep, and
  /// losing it here would make a day off look like an absence.
  static List<({LearningPlan plan, List<LedgerUnit> units})> forDay(
    List<LearningPlan> plans,
    Catalog catalog,
    LogFold fold,
    Day day, {
    LayerRoles? layers,
  }) => [
    for (final plan in plans)
      if (PlannerSchedule.assignmentsOn(plan, dayInfoFor(day)).isNotEmpty)
        () {
          final units = unitsFor(plan, catalog, fold, day, layers: layers);
          return (plan: plan, units: units);
        }(),
  ].where((e) => e.units.isNotEmpty).toList();

  /// One unit's row, for pass [occurrence] of it on this day.
  ///
  /// **[occurrence] is what makes "three times a day" three claims rather than
  /// one**, and it needs no new stored state: the log already counts how many
  /// times a unit was done on a day (`LogFold.doneCountOn`), so the *k*th row of
  /// a unit is done when the day has counted more than *k* passes of it.
  static LedgerUnit _unit(
    String nodeId,
    int unit,
    LogFold fold,
    Day day,
    LayerRoles? layers,
    int occurrence,
  ) {
    final required = layers?.requiredFor(nodeId) ?? {mainLayerId};
    final learned = required.every(fold.completedLayers(nodeId, unit).contains);
    final at = fold.doneAt(nodeId, unit);
    // **Counted only while the unit still counts as learned.** A count is
    // history, and history is real even after an un-mark; but a unit the user has
    // un-ticked is not owed work, so the ledger must not offer it as either done
    // or still-outstanding. The raw count is kept for display.
    final passesToday = fold.doneCountOn(nodeId, unit, day);
    return LedgerUnit(
      nodeId: nodeId,
      unitIndex: unit,
      occurrence: occurrence,
      doneHere: learned && passesToday > occurrence,
      doneCount: learned ? fold.doneCount(nodeId, unit) : 0,
      doneToday: learned ? passesToday : 0,
      doneOn: learned && at != null ? Day.of(at) : null,
    );
  }

  /// How many of [units] were done on the day itself.
  static int doneOnDay(List<LedgerUnit> units) =>
      units.where((u) => u.doneHere).length;

  /// How many are still owed: never done.
  static int owed(List<LedgerUnit> units) =>
      units.where((u) => !u.doneHere && !u.doneElsewhere).length;
}
