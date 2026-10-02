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
    this.finishedAgain = 0,
    this.finishedAgainAgain = 0,
  });

  final CatalogNode node;
  final int learned;
  final int total;
  final List<ProgressNode> children;

  /// layer id -> number of in-range units under this node that have that layer
  /// learned (e.g. how many dapim have Rashi). Denominator is [total]. Rolled up
  /// from every descendant leaf; empty for a node with no layered progress.
  final Map<String, int> learnedByLayer;

  /// Units under this node finished **more than once**, and **more than twice**
  /// (#46). Each is one extra line on this node's progress bar.
  ///
  /// **Why these are two fields and not a list.** A bar draws one line per round
  /// it has something to show, so what a parent needs is the *sum* of its
  /// children's counts — which is a plain addition. A list of per-round counts
  /// would need a length-agnostic sum at every level, and would answer a
  /// question no caller asks: "which round has this one unit in". The rounds
  /// this bar can show are fixed and few, so they are named.
  ///
  /// Always <= [learned]: a unit cannot have been finished again without having
  /// been finished. That is an invariant the roll-up cannot break — it only
  /// ever adds a child's count to its own — and a test states it.
  final int finishedAgain;
  final int finishedAgainAgain;

  /// The deepest round any unit under this node has reached: 1 when only some
  /// are learned, 2 when any has been finished twice, 3 and up beyond that.
  ///
  /// The bar draws three lines and no more, so it needs to know whether there
  /// are rounds it is *not* drawing — otherwise a sefer with nine rounds looks
  /// exactly like one with three, which is a claim this widget cannot support.
  int get maxRound => finishedAgainAgain > 0
      ? 3
      : (finishedAgain > 0 ? 2 : (learned > 0 ? 1 : 0));

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
          // Before `node`, because a repeated finish moves these and nothing
          // else on an ancestor, so they are the cheapest thing that can tell
          // two otherwise-identical nodes apart.
          other.finishedAgain == finishedAgain &&
          other.finishedAgainAgain == finishedAgainAgain &&
          identical(other.node, node) &&
          mapEquals(other.learnedByLayer, learnedByLayer) &&
          listEquals(other.children, children);

  /// Deliberately shallow. Hashing a subtree would walk it, and equal objects
  /// are only *required* to share a hash — collisions are legal. Nothing in the
  /// app keys a map on a [ProgressNode]; this exists so that if something ever
  /// does, it is correct rather than fast.
  @override
  int get hashCode =>
      Object.hash(node.id, learned, total, finishedAgain, children.length);
}
