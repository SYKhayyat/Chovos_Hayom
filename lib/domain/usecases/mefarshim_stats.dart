import '../entities/progress_node.dart';

/// How many units carry a given layer as learned — "how much Rashi (or the text,
/// or any meforish) have I done across everything."
class MefarshimStat {
  const MefarshimStat({required this.layerId, required this.learnedUnits});
  final String layerId;
  final int learnedUnits;
}

/// Tallies completed layers across the whole catalog, per meforish.
///
/// **Reads the rolled-up forest rather than the fold.** `RollUp` already counts
/// exactly this while it builds each leaf — the same walk over the units the
/// fold has marks for, with the same clamp to the leaf's valid range — and sums
/// it up the tree into [ProgressNode.learnedByLayer]. Deriving it a second time
/// from the fold meant one number with two implementations and no test holding
/// them to each other, which is the shape this codebase has already been bitten
/// by twice. Summing the roots is O(roots × layers) and cannot disagree with the
/// per-node bars on the dashboard, because it is the same arithmetic that drew
/// them.
class MefarshimStats {
  const MefarshimStats._();

  /// Per-layer totals across [forest], most-learned first.
  static List<MefarshimStat> of(List<ProgressNode> forest) {
    final counts = <String, int>{};
    for (final root in forest) {
      root.learnedByLayer.forEach((layerId, learned) {
        counts[layerId] = (counts[layerId] ?? 0) + learned;
      });
    }
    final stats = [
      for (final e in counts.entries)
        MefarshimStat(layerId: e.key, learnedUnits: e.value),
    ];
    stats.sort((a, b) => b.learnedUnits.compareTo(a.learnedUnits));
    return stats;
  }
}
