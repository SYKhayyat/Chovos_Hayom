import '../entities/catalog.dart';
import '../entities/catalog_node.dart';
import '../entities/progress_node.dart';
import 'fold_log.dart';
import 'layer_requirements.dart';

/// Builds a [ProgressNode] tree by rolling leaf progress up through the catalog.
///
/// Leaf `learned` = count of done units that fall within the leaf's valid range
/// (`[unitOffset, unitOffset + unitCount)`); out-of-range marks are ignored so a
/// stale/incorrect event can never push `learned` above `total`.
class RollUp {
  const RollUp._();

  /// Build the full tree from the catalog roots. [required] resolves which
  /// layers each unit needs to count as complete (null = text-only).
  static List<ProgressNode> buildForest(Catalog catalog, LogFold fold,
          [LayerRequirements? required]) =>
      [for (final root in catalog.roots) _build(catalog, root, fold, required)];

  /// Build the subtree rooted at [nodeId], or null if it doesn't exist.
  static ProgressNode? buildNode(Catalog catalog, String nodeId, LogFold fold,
      [LayerRequirements? required]) {
    final node = catalog.byId(nodeId);
    return node == null ? null : _build(catalog, node, fold, required);
  }

  static ProgressNode _build(Catalog catalog, CatalogNode node, LogFold fold,
      LayerRequirements? required) {
    if (node.isLeaf) {
      final done = fold.doneUnits(node.id, required);
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
      return ProgressNode(
        node: node,
        learned: learned,
        total: node.unitCount,
        children: const [],
        learnedByLayer: byLayer,
      );
    }

    final children = [
      for (final child in catalog.childrenOf(node.id))
        _build(catalog, child, fold, required),
    ];
    var learned = 0;
    var total = 0;
    final byLayer = <String, int>{};
    for (final c in children) {
      learned += c.learned;
      total += c.total;
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
    );
  }
}
