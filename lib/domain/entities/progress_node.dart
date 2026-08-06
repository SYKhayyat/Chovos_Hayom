import '../../core/equality.dart';
import 'catalog_node.dart';

/// A node of the catalog tree annotated with derived progress. Produced by
/// [RollUp]; never persisted (see ARCHITECTURE.md §1).
///
/// **Has value equality, and that is load-bearing.** `RollUp.buildForest`
/// allocates all ~312 of these fresh every time the log changes, and
/// `progressNodeProvider` hands one to whoever asked for that id. Without `==`
/// Riverpod compares them by identity, so marking a daf in Shabbos re-notified
/// the provider for every node anyone had ever opened — the Berachos goal row
/// re-evaluated its pace because a *different* mesechta moved.
class ProgressNode {
  ProgressNode({
    required this.node,
    required this.learned,
    required this.total,
    required this.children,
    this.learnedByLayer = const {},
  });

  final CatalogNode node;
  final int learned;
  final int total;
  final List<ProgressNode> children;

  /// layer id -> number of in-range units under this node that have that layer
  /// learned (e.g. how many dapim have Rashi). Denominator is [total]. Rolled up
  /// from every descendant leaf; empty for a node with no layered progress.
  final Map<String, int> learnedByLayer;

  double get percent => total <= 0 ? 0 : 100 * learned / total;
  int get remaining => total - learned;
  bool get isComplete => total > 0 && learned >= total;

  /// Units under this node that have [layerId] learned (0 if none).
  int learnedFor(String layerId) => learnedByLayer[layerId] ?? 0;

  String get id => node.id;
  String get name => node.name;

  /// Deep over [children], and **identity** over [node].
  ///
  /// [CatalogNode] has no `==`, and giving it one here would be the wrong
  /// answer as well as a slower one. The catalog is loaded once and the merge
  /// in `mergedCatalogProvider` re-uses the same instances, so two forests
  /// built from an unchanged catalog carry the identical node objects — a
  /// pointer check. When the catalog *does* change (a rename, a custom
  /// override, a hidden subtree) the instance changes with it and every node
  /// that quotes it correctly compares unequal, which is exactly the rebuild
  /// that rename needs. Identity is both the cheap comparison and the true one.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressNode &&
          // Cheapest and most discriminating first: one marked unit moves
          // `learned` on the whole ancestor chain and nothing else on it.
          other.learned == learned &&
          other.total == total &&
          identical(other.node, node) &&
          mapEquals(other.learnedByLayer, learnedByLayer) &&
          listEquals(other.children, children);

  /// Deliberately shallow. Hashing a subtree would walk it, and equal objects
  /// are only *required* to share a hash — collisions are legal. Nothing in the
  /// app keys a map on a [ProgressNode]; this exists so that if something ever
  /// does, it is correct rather than fast.
  @override
  int get hashCode => Object.hash(node.id, learned, total, children.length);
}
