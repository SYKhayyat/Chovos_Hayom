import '../entities/catalog.dart';
import 'fold_log.dart';

/// How many units carry a given layer as learned — "how much Rashi (or the text,
/// or any meforish) have I done across everything."
class MefarshimStat {
  const MefarshimStat({required this.layerId, required this.learnedUnits});
  final String layerId;
  final int learnedUnits;
}

/// Tallies completed layers across the whole catalog, per meforish.
///
/// Single-pass over only the *marked* units in the fold (not every unit of
/// Torah), and clamped to each leaf's valid range so a stale event can't be
/// counted — cheap even for a full Shas.
class MefarshimStats {
  const MefarshimStats._();

  static List<MefarshimStat> compute(Catalog catalog, LogFold fold) {
    final counts = <String, int>{};
    fold.completedByNode.forEach((nodeId, byUnit) {
      final leaf = catalog.byId(nodeId);
      if (leaf == null || !leaf.isLeaf) return;
      byUnit.forEach((unit, layers) {
        if (!leaf.containsUnit(unit)) return;
        for (final layerId in layers) {
          counts[layerId] = (counts[layerId] ?? 0) + 1;
        }
      });
    });
    final stats = [
      for (final e in counts.entries)
        MefarshimStat(layerId: e.key, learnedUnits: e.value),
    ];
    stats.sort((a, b) => b.learnedUnits.compareTo(a.learnedUnits));
    return stats;
  }
}
