import 'catalog_node.dart';

/// An indexed, immutable view over a set of [CatalogNode]s forming a **forest**.
///
/// The forest part is a guarantee, not a description. Every node reachable from
/// this catalog has a parent chain that terminates at a root in a finite number
/// of steps: no cycles, and no link pointing at a node that isn't here. Nodes
/// that arrive violating that are repaired on the way in (see [_asForest]) —
/// never dropped, so nothing the user owns disappears.
///
/// **Why it is a guarantee.** The bundled catalog is a tree, but the per-profile
/// override layer is not constrained to be: an override row whose id matches a
/// built-in *replaces* that node's parent, so one hand-edited row can re-parent
/// a sefer beneath its own descendant. Eight different places in this app then
/// walk that relation — leaves-under, layer inheritance, the breadcrumb, the
/// hidden-subtree cascade, the node editor's descendant ban, the clone, the bulk
/// history's common-ancestor — and each was left to decide for itself whether a
/// loop was possible. Six guessed "yes" and kept a visited-set; two guessed "no"
/// and are unbounded loops. The one that walks ancestors to caption an undo row
/// (`BulkHistoryScreen._commonAncestor`) grows a list forever on a cycle: not a
/// slow screen, a wedged process.
///
/// Adding a seventh and eighth visited-set would have been an eighth theory of
/// who is responsible. This is one theory: the relation cannot loop, so nobody
/// downstream has to ask. `test/domain/catalog_forest_test.dart` holds it.
class Catalog {
  Catalog(List<CatalogNode> nodes) : this._(_asForest(nodes));

  Catalog._(Map<String, CatalogNode> byId)
      : _byId = byId,
        _childrenByParent = _groupChildren(byId.values);

  final Map<String, CatalogNode> _byId;
  final Map<String?, List<CatalogNode>> _childrenByParent;

  /// [nodes] indexed by id, with every parent link that would break the forest
  /// detached — so the node it was on becomes a root.
  ///
  /// Returning the index rather than a list is not tidiness. `childrenOf` and
  /// `byId` have to be built from the *same* set of nodes or they can disagree
  /// about who a node's parent is, and a repeated id is enough to make them:
  /// the index keeps one row per id and the list keeps both, so `childrenOf(b)`
  /// would offer a stale `a` whose parent is `b` while `byId('a')` says
  /// otherwise. A walk down and a walk up then see different shapes, and the
  /// downward one can loop over a pair the upward one considers fine.
  ///
  /// Detaching rather than deleting is the whole point. A node whose parent has
  /// gone missing used to be *in* the catalog and reachable from no root — it
  /// answered `byId`, it turned up in search, and it was absent from the tree,
  /// which is the worst of the three options. As a root it is visible, and the
  /// node editor can re-file it. The same goes for a loop: the ring is cut at
  /// exactly one link, so the rest of the shape the user built survives.
  ///
  /// The cut is the lowest id in the ring — an arbitrary choice made
  /// deterministic on purpose, so the repair does not depend on the order rows
  /// came back from SQLite and two devices restoring the same file agree.
  ///
  /// One pass over the nodes, not one per node: a chain is walked until it
  /// reaches something already answered, and every id on it is answered by that
  /// walk. The scratch buffers are reused across chains, the index is the one
  /// the catalog was going to build anyway, and a clean input copies no nodes at
  /// all — this runs on every rebuild of the merged catalog, so it is O(n) with
  /// four set operations per node and nothing else.
  static Map<String, CatalogNode> _asForest(List<CatalogNode> nodes) {
    // Last row of a repeated id wins, which is what `insertOnConflictUpdate`
    // does in the table these come from, so the catalog agrees with storage.
    final byId = {for (final n in nodes) n.id: n};
    final settled = <String>{};
    final detach = <String>{};
    final path = <String>[];
    final onPath = <String>{};

    for (final start in byId.keys) {
      if (settled.contains(start)) continue;
      path.clear();
      onPath.clear();
      var current = start;
      while (true) {
        if (settled.contains(current)) break;
        if (!onPath.add(current)) {
          // A loop, and `path` from its first mention onward is the ring.
          final ring = path.sublist(path.indexOf(current));
          var cut = ring.first;
          for (final id in ring) {
            if (id.compareTo(cut) < 0) cut = id;
          }
          detach.add(cut);
          break;
        }
        path.add(current);
        final parent = byId[current]!.parentId;
        if (parent == null) break;
        if (!byId.containsKey(parent)) {
          detach.add(current);
          break;
        }
        current = parent;
      }
      settled.addAll(path);
    }

    for (final id in detach) {
      byId[id] = byId[id]!.copyWith(parentId: null);
    }
    return byId;
  }

  static Map<String?, List<CatalogNode>> _groupChildren(
      Iterable<CatalogNode> nodes) {
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
  Iterable<CatalogNode> leavesUnder(String nodeId) =>
      _leavesUnder(nodeId, <String>{});

  Iterable<CatalogNode> _leavesUnder(String nodeId, Set<String> seen) sync* {
    // The forest invariant already makes this terminate; `seen` is kept because
    // it is the invariant's own file and costs one set per call, so the class
    // that promises the tree is finite is not itself taking the promise on
    // trust. Every walk *outside* this file relies on the promise instead —
    // that is the point of having one, and adding a visited-set out there would
    // be a second opinion about a question that now has one answer.
    if (!seen.add(nodeId)) return;
    final node = _byId[nodeId];
    if (node == null) return;
    if (node.isLeaf) {
      yield node;
      return;
    }
    for (final child in childrenOf(nodeId)) {
      yield* _leavesUnder(child.id, seen);
    }
  }
}
