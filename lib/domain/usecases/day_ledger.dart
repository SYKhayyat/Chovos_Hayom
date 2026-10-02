import '../../core/day.dart';
import '../../core/planner_dates.dart';
import '../entities/catalog.dart';
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
class LedgerUnit {
  const LedgerUnit({
    required this.nodeId,
    required this.unitIndex,
    required this.doneHere,
    required this.doneCount,
    required this.doneOn,
  });

  /// The leaf the unit belongs to.
  final String nodeId;
  final int unitIndex;

  /// Done **on the day this ledger is for**.
  final bool doneHere;

  /// How many times, ever. More than one is real: a unit learned seven years ago
  /// and again this month, or covered by two plans on the same day.
  final int doneCount;

  /// The day it *was* done, when not done here. Null when never done.
  final Day? doneOn;

  /// Done, but not on this day. Shown rather than hidden.
  bool get doneElsewhere => !doneHere && doneCount > 0;

  @override
  bool operator ==(Object other) =>
      other is LedgerUnit &&
      other.nodeId == nodeId &&
      other.unitIndex == unitIndex &&
      other.doneHere == doneHere &&
      other.doneCount == doneCount &&
      other.doneOn == doneOn;

  @override
  int get hashCode =>
      Object.hash(nodeId, unitIndex, doneHere, doneCount, doneOn);

  @override
  String toString() =>
      'LedgerUnit($nodeId $unitIndex, here: $doneHere, '
      'count: $doneCount, on: $doneOn)';
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
  /// has. The shortfall shows as a short ledger — visible — rather than as the
  /// same units offered twice, which would be a number the log has no event for
  /// and the grid no cell to show.
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
    for (final range in PlanRange.rangesOf(plan, catalog)) {
      if (out.length >= amount) break;
      if (range == null) continue;
      for (final (node, unit) in range.walk(catalog)) {
        if (out.length >= amount) break;
        out.add(_unit(node.id, unit, fold, day, layers));
      }
    }
    return out;
  }

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

  /// One unit's row.
  static LedgerUnit _unit(
    String nodeId,
    int unit,
    LogFold fold,
    Day day,
    LayerRoles? layers,
  ) {
    final required = layers?.requiredFor(nodeId) ?? {mainLayerId};
    final learned = required.every(fold.completedLayers(nodeId, unit).contains);
    final at = fold.doneAt(nodeId, unit);
    // **Counted only while the unit still counts as learned.** A count is
    // history, and history is real even after an un-mark; but a unit the user has
    // un-ticked is not owed work, so the ledger must not offer it as either done
    // or still-outstanding. The raw count is kept for display.
    return LedgerUnit(
      nodeId: nodeId,
      unitIndex: unit,
      doneHere: learned && fold.doneCountOn(nodeId, unit, day) > 0,
      doneCount: learned ? fold.doneCount(nodeId, unit) : 0,
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
