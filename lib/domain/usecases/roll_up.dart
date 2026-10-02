import '../entities/catalog.dart';
import '../entities/catalog_node.dart';
import '../entities/progress_node.dart';
import 'fold_log.dart';
import 'layer_roles.dart';

/// Builds a [ProgressNode] tree by rolling leaf progress up through the catalog.
///
/// Leaf `learned` = count of done units that fall within the leaf's valid range
/// (`[unitOffset, unitOffset + unitCount)`); out-of-range marks are ignored so a
/// stale/incorrect event can never push `learned` above `total`.
class RollUp {
  const RollUp._();

  /// Build the full tree from the catalog roots. [layers] resolves which
  /// layers each unit needs to count as complete (null = text-only).
  static List<ProgressNode> buildForest(
    Catalog catalog,
    LogFold fold, [
    LayerRoles? layers,
  ]) => [for (final root in catalog.roots) _build(catalog, root, fold, layers)];

  /// Build the subtree rooted at [nodeId], or null if it doesn't exist.
  static ProgressNode? buildNode(
    Catalog catalog,
    String nodeId,
    LogFold fold, [
    LayerRoles? layers,
  ]) {
    final node = catalog.byId(nodeId);
    return node == null ? null : _build(catalog, node, fold, layers);
  }

  static ProgressNode _build(
    Catalog catalog,
    CatalogNode node,
    LogFold fold,
    LayerRoles? layers,
  ) {
    if (node.isLeaf) {
      final done = fold.doneUnits(node.id, layers);
      var learned = 0;
      for (final unit in done) {
        if (node.containsUnit(unit)) learned++;
      }
      // Per-layer coverage: count in-range units that have each layer learned.
      //
      // Walks the units the fold actually has marks for, not every unit of the
      // node. The difference is the whole catalog — 12,000 units of Torah, most
      // of them untouched — versus what the user has learned, on every rebuild.
      final byLayer = <String, int>{};
      fold.completedByNode[node.id]?.forEach((unit, layers) {
        if (!node.containsUnit(unit)) return;
        for (final layerId in layers) {
          byLayer[layerId] = (byLayer[layerId] ?? 0) + 1;
        }
      });
      // The extra rounds (#46), counted the same way `learned` is: over the units
      // this leaf actually has marks for, in range only. `chazaraCount` already
      // refuses a unit that is not fully learned, and passes the same `layers`
      // resolver, so a partly-done daf lands on neither line.
      final twice = fold.unitsWithPasses(node.id, 2, layers).length;
      final thrice = fold.unitsWithPasses(node.id, 3, layers).length;
      return ProgressNode(
        node: node,
        learned: learned,
        total: node.unitCount,
        children: const [],
        learnedByLayer: byLayer,
        finishedAgain: twice,
        finishedAgainAgain: thrice,
      );
    }

    final children = [
      for (final child in catalog.childrenOf(node.id))
        _build(catalog, child, fold, layers),
    ];
    var learned = 0;
    var total = 0;
    var twice = 0;
    var thrice = 0;
    final byLayer = <String, int>{};
    for (final c in children) {
      learned += c.learned;
      total += c.total;
      twice += c.finishedAgain;
      thrice += c.finishedAgainAgain;
      c.learnedByLayer.forEach((layerId, count) {
        byLayer[layerId] = (byLayer[layerId] ?? 0) + count;
      });
    }
    return ProgressNode(
      node: node,
      learned: learned,
      total: total,
      children: children,
      learnedByLayer: byLayer,
      finishedAgain: twice,
      finishedAgainAgain: thrice,
    );
  }
}
