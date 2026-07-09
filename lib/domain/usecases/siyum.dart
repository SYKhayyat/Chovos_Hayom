import '../entities/catalog.dart';
import '../entities/catalog_node.dart';
import '../entities/enums.dart';
import '../entities/learning_event.dart';
import 'fold_log.dart';

/// A completed sefer/mesechta and when its final unit was learned.
class Siyum {
  const Siyum({
    required this.node,
    required this.completedOn,
    required this.units,
  });

  final CatalogNode node;

  /// The date the last-learned unit of this leaf was learned (`occurredAt`).
  final DateTime completedOn;

  /// Number of units (== node.unitCount for a full siyum).
  final int units;
}

/// Derives siyumim — leaves that are fully complete — straight from the log.
/// Nothing is stored: a siyum exists iff every unit of a leaf is currently done.
class SiyumFinder {
  const SiyumFinder._();

  /// All completed leaves, most-recently-finished first.
  static List<Siyum> completed(Catalog catalog, Iterable<LearningEvent> events) {
    final fold = FoldLog.fold(events);

    // Latest `done` date per (node, unit), for dating the siyum.
    final lastDone = <String, DateTime>{};
    for (final e in events) {
      if (e.action != EventAction.done) continue;
      final key = '${e.nodeId} ${e.unitIndex}';
      final cur = lastDone[key];
      if (cur == null || e.occurredAt.isAfter(cur)) lastDone[key] = e.occurredAt;
    }

    final out = <Siyum>[];
    for (final node in catalog.all) {
      if (!node.isLeaf || node.unitCount <= 0) continue;
      final done = fold.doneUnits(node.id);

      var count = 0;
      DateTime? last;
      for (final unit in node.unitIndices) {
        if (!done.contains(unit)) continue;
        count++;
        final d = lastDone['${node.id} $unit'];
        if (d != null && (last == null || d.isAfter(last))) last = d;
      }

      if (count == node.unitCount && last != null) {
        out.add(Siyum(node: node, completedOn: last, units: count));
      }
    }
    out.sort((a, b) => b.completedOn.compareTo(a.completedOn));
    return out;
  }
}
