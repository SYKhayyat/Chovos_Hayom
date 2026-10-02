import 'fold_log.dart';

/// One unit and how many passes it has had.
///
/// A value type because it is shown in a list and compared on every rebuild, and
/// because a bare `(String, int)` pair is the sort of thing that gets
/// transposed once and reads as somebody else's unit.
class ChazaraPass {
  const ChazaraPass({
    required this.nodeId,
    required this.unitIndex,
    required this.passes,
  });

  final String nodeId;
  final int unitIndex;

  /// One for a unit that has only been learned, more for each later pass.
  final int passes;

  @override
  bool operator ==(Object other) =>
      other is ChazaraPass &&
      other.nodeId == nodeId &&
      other.unitIndex == unitIndex &&
      other.passes == passes;

  @override
  int get hashCode => Object.hash(nodeId, unitIndex, passes);

  @override
  String toString() => 'ChazaraPass($nodeId $unitIndex, $passes)';
}

/// Chazara is one rule: **learned means chazara**.
///
/// This replaces a spaced-repetition scheduler that decided when things *should*
/// come back, and needed stored per-unit review dates to do it. A scheduler needs
/// state about when you last reviewed and a policy about how long until next
/// time, and that state has to be correct from day one or it quietly lies — the
/// state is the problem, not the schedule.
///
/// The rule needs none of it. A unit's first pass *is* its learning, and every
/// later pass is a `reviewed` event beside it, so the count is a fold over the
/// log that this repository already computes. That is the whole substitution:
/// [LogFold.chazaraCount] is the report, and nothing is stored.
///
/// **Which matters for the day ledger (#42).** Ticking a unit there writes a
/// `done` event, and under the old rule that unit was not chazara'd — so the
/// calendar would have ticked a box and the chazara report would not have moved.
/// Under this one it is, with **no second event written**: only `done` is ever
/// written and the pass count is derived, so the two can never both write review
/// state and disagree about it.
class Chazara {
  const Chazara._();

  /// **False, permanently.** There is no schedule to have one.
  ///
  /// Stated as a constant rather than left implicit because the question "what is
  /// due today" used to have an answer and its absence is a *change*, not a
  /// missing feature. A caller that wants a due list has to be told, at the point
  /// where it would have asked, rather than quietly receiving an empty list and
  /// rendering an empty screen.
  static const hasSchedule = false;

  /// Every unit with at least one pass, most-passed first.
  ///
  /// **Sorted by passes, descending**, because that is what a report is read for
  /// — "what have I been over most" — and it is not the order a unit-indexed map
  /// happens to produce. Ties break on node and unit so the order is stable
  /// across rebuilds rather than depending on iteration order.
  static List<ChazaraPass> reviewedUnits(LogFold fold) {
    final out = <ChazaraPass>[];
    fold.doneCountByNode.forEach((nodeId, byUnit) {
      byUnit.forEach((unit, byDay) {
        // A unit whose every day has been un-ticked has no passes left, and
        // `doneCountByNode` is emptied for it, so it never arrives here — the
        // count and the learned-state cannot disagree by construction.
        final passes = fold.chazaraCount(nodeId, unit);
        if (passes > 0) {
          out.add(ChazaraPass(nodeId: nodeId, unitIndex: unit, passes: passes));
        }
      });
    });
    out.sort((a, b) {
      final byPasses = b.passes.compareTo(a.passes);
      if (byPasses != 0) return byPasses;
      final byNode = a.nodeId.compareTo(b.nodeId);
      return byNode != 0 ? byNode : a.unitIndex.compareTo(b.unitIndex);
    });
    return out;
  }

  /// Units with **more than one** pass, which is the "learned it again" report.
  ///
  /// Distinct from [reviewedUnits] because "you have chazara'd this" and "you
  /// have been over this more than once" are different questions, and the second
  /// is the one that answers "what am I actually keeping up with".
  static List<ChazaraPass> repeatedUnits(LogFold fold) => [
    for (final p in reviewedUnits(fold))
      if (p.passes > 1) p,
  ];
}
