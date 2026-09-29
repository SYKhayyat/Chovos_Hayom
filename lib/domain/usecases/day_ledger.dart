import '../entities/learning_event.dart';
import 'fold_log.dart';
import 'learning_plan.dart';

/// One unit a plan asks for on a particular day, resolved to something that can
/// actually be marked.
///
/// **Why this exists.** The planner calendar knew what each day *asked for* and
/// the unit grid knew what you *did*, and the two never met: the calendar wrote
/// only date overrides on plans, and the grid wrote only the event log. So a
/// person could not answer "did I do Thursday?" from the calendar, and could not
/// say "I did it" from there. This is the join, and it is deliberately a
/// *domain* object with no widgets in it, because the arithmetic — which units a
/// day owes, and which of them are done — is the part that is worth testing on
/// its own and the part that both views must agree about.
class DayUnit {
  const DayUnit({
    required this.nodeId,
    required this.unitIndex,
    required this.planId,
    required this.planName,
    this.label,
  });

  /// The catalog node this unit is in.
  final String nodeId;

  /// Which unit of that node.
  final int unitIndex;

  /// The plan that asked for it, so the calendar can say *why* this is on the
  /// day rather than just that it is.
  final String planId;
  final String planName;

  /// The item's own label, when the plan gives it one that is not the node's.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is DayUnit &&
      other.nodeId == nodeId &&
      other.unitIndex == unitIndex &&
      other.planId == planId;

  @override
  int get hashCode => Object.hash(nodeId, unitIndex, planId);

  @override
  String toString() => 'DayUnit($nodeId#$unitIndex from $planId)';
}

/// A day's ledger: what was asked for, and what was done.
class DayLedger {
  const DayLedger({
    required this.units,
    required this.doneHere,
    required this.doneElsewhere,
  });

  /// The units the day asks for, in plan order then unit order.
  final List<DayUnit> units;

  /// Of [units], those marked done — and marked *on this day*.
  ///
  /// Two sets, not one boolean per unit, because "done, but on Tuesday" and
  /// "done today" are different claims and a calendar that conflates them will
  /// tell a person they finished Thursday when they finished it on Monday.
  final Set<DayUnit> doneHere;

  /// Of [units], those already done on some *other* day. Shown, not hidden: a
  /// backlog is the reader's business, and the plan's spillover mode decides
  /// what happens next, not this screen.
  final Set<DayUnit> doneElsewhere;

  /// How many of [units] are done, counting both.
  int get doneCount => doneHere.length + doneElsewhere.length;

  /// The units still outstanding on this day.
  List<DayUnit> get outstanding =>
      [for (final u in units) if (!doneHere.contains(u) && !doneElsewhere.contains(u)) u];

  /// Whether the day's work is finished. **Empty is finished**: a day that asks
  /// for nothing is not a day of failure, and a progress bar that reads 0/0 is
  /// not the same statement as one that reads 0/6.
  bool get complete => outstanding.isEmpty;

  /// Builds the ledger for one day.
  ///
  /// [fold] is the current log, [config] the plans, and [unitCount] how many
  /// units each catalog node has — needed because a day can ask for more units
  /// than a node has, and a unit that does not exist cannot be marked.
  ///
  /// [isDoneDay] decides which day counts as "done here", and is a parameter
  /// rather than a comparison against today so that *this* file never has an
  /// opinion about what "today" is. The caller passes the day being shown, which
  /// is the whole reason a past day can be inspected at all.
  static DayLedger build({
    required PlansConfig config,
    required LogFold fold,
    required bool Function(DateTime when) isDoneDay,
    required int Function(String nodeId) unitCount,
  }) {
    return DayLedger._empty();
  }

  /// Placeholder so the shape is fixed while the arithmetic lands.
  static DayLedger _empty() => const DayLedger(
        units: [],
        doneHere: {},
        doneElsewhere: {},
      );

  /// The units [day] asks for, resolved to concrete units and in order.
  ///
  /// **The next unlearned ones, not the first ones.** A plan that says "Mishna
  /// Berura, 6 a day" means the six you have not done, and resolving it to units
  /// 1-6 every time would put a month-2 day in the same place as a month-1 day
  /// and make the checkbox mark something already marked.
  ///
  /// Assignments with no target node — a plan over "any sefer" — contribute
  /// nothing here, and the caller says so in words rather than inventing a node
  /// to attach a checkbox to. That is the honest answer: there is no unit to
  /// tick until a person has chosen one.
  static List<DayUnit> unitsFor(
    PlansConfig config,
    DayInfo dayInfo,
    LogFold fold,
    int Function(String nodeId) unitCount,
  ) {
    final out = <DayUnit>[];
    for (final plan in config.plans) {
      final amount = DayAmount.of(plan, dayInfo);
      if (amount <= 0) continue;
      for (final assignment in PlannerSchedule.assignmentsOn(plan, dayInfo)) {
        final nodeId = assignment.targetNodeId;
        if (nodeId == null) continue;
        final total = unitCount(nodeId);
        if (total <= 0) continue;
        final already = fold.doneUnits(nodeId);
        for (final index in _nextUnlearned(total, already, amount)) {
          out.add(DayUnit(
            nodeId: nodeId,
            unitIndex: index,
            planId: plan.id,
            planName: plan.name,
          ));
        }
      }
    }
    return out;
  }

  /// The first [want] indices in `0 until total` that are not in [done].
  ///
  /// Falls back to the first indices when the node is already finished, because
  /// a day that still asks for work on a node with none left should offer the
  /// units a person can *undo* rather than silently showing nothing. Refusing
  /// would hide the only way back.
  static List<int> _nextUnlearned(int total, Set<int> done, int want) {
    final out = <int>[];
    for (var i = 0; i < total && out.length < want; i++) {
      if (!done.contains(i)) out.add(i);
    }
    if (out.isEmpty) {
      for (var i = 0; i < total && out.length < want; i++) {
        out.add(i);
      }
    }
    return out;
  }
}
