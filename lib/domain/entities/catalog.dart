import 'catalog_node.dart';

/// An indexed, immutable view over a set of [CatalogNode]s forming a tree.
class Catalog {
  Catalog(List<CatalogNode> nodes)
      : _byId = {for (final n in nodes) n.id: n},
        _childrenByParent = _groupChildren(nodes);

  final Map<String, CatalogNode> _byId;
  final Map<String?, List<CatalogNode>> _childrenByParent;

  static Map<String?, List<CatalogNode>> _groupChildren(
      List<CatalogNode> nodes) {
    final map = <String?, List<CatalogNode>>{};
    for (final n in nodes) {
      (map[n.parentId] ??= []).add(n);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.sortOrder != b.sortOrder
          ? a.sortOrder.compareTo(b.sortOrder)
          : a.name.compareTo(b.name));
    }
    return map;
  }

  Iterable<CatalogNode> get all => _byId.values;

  /// Root nodes (no parent).
  List<CatalogNode> get roots => childrenOf(null);

  CatalogNode? byId(String id) => _byId[id];

  List<CatalogNode> childrenOf(String? parentId) =>
      List.unmodifiable(_childrenByParent[parentId] ?? const []);

  /// All leaf descendants of [nodeId] (inclusive if it is itself a leaf).
  Iterable<CatalogNode> leavesUnder(String nodeId) sync* {
    final node = _byId[nodeId];
    if (node == null) return;
    if (node.isLeaf) {
      yield node;
      return;
    }
    for (final child in childrenOf(nodeId)) {
      yield* leavesUnder(child.id);
    }
  }
}
