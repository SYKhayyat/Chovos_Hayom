import '../entities/catalog_node.dart';
import '../entities/progress_node.dart';
import 'fold_log.dart';

/// A completed node — a mesechta, a sefer, a seder, or the whole of Shas — and
/// when its final unit was learned.
class Siyum {
  const Siyum({
    required this.node,
    required this.completedOn,
    required this.units,
    required this.depth,
  });

  final CatalogNode node;

  /// The date the last-learned unit under this node was learned (`occurredAt`).
  final DateTime completedOn;

  /// Number of units it covers (== the node's rolled-up total).
  final int units;

  /// How deep in the tree it sits (0 = a root). Lets the UI lead with the
  /// bigger simcha: finishing Seder Moed outranks finishing Beitza.
  final int depth;

  /// A siyum on a category is a siyum on everything under it.
  bool get isCategory => !node.isLeaf;
}

/// Derives siyumim — nodes that are fully complete — from the rolled-up progress
/// forest.
///
/// Nothing is stored: a siyum exists iff every unit under a node is currently
/// done. It reads the forest [RollUp] already built and the shared [LogFold],
/// rather than folding the log a second time.
///
/// Every level counts. Finishing a mesechta is a siyum; so is finishing a seder,
/// or Nach, or Shas — and an app whose emotional payoff is the siyum should not
/// stay silent for the biggest ones.
class SiyumFinder {
  const SiyumFinder._();

  /// All completed nodes, most-recently-finished first; ties break with the
  /// larger siyum (more units) first.
  static List<Siyum> completed(List<ProgressNode> forest, LogFold fold) {
    final out = <Siyum>[];

    /// Returns the latest learned-date anywhere under [n], recording a siyum on
    /// the way back up if [n] is complete.
    DateTime? visit(ProgressNode n, int depth) {
      DateTime? last;
      void consider(DateTime? d) {
        if (d != null && (last == null || d.isAfter(last!))) last = d;
      }

      if (n.children.isEmpty) {
        // A complete leaf has every in-range unit done, so the latest date over
        // its marked units is the date it was finished.
        final byUnit = fold.doneAtByNode[n.id];
        if (byUnit != null) {
          byUnit.forEach((unit, at) {
            if (n.node.containsUnit(unit)) consider(at);
          });
        }
      } else {
        for (final child in n.children) {
          consider(visit(child, depth + 1));
        }
      }

      final finishedOn = last;
      if (n.isComplete && finishedOn != null) {
        out.add(Siyum(
          node: n.node,
          completedOn: finishedOn,
          units: n.total,
          depth: depth,
        ));
      }
      return finishedOn;
    }

    for (final root in forest) {
      visit(root, 0);
    }

    out.sort((a, b) {
      final byDate = b.completedOn.compareTo(a.completedOn);
      return byDate != 0 ? byDate : b.units.compareTo(a.units);
    });
    return out;
  }
}
