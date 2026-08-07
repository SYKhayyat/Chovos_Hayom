import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// [Catalog]'s promise: whatever you build it from, what comes out is a forest.
///
/// This is the file that has to fail if somebody ever "simplifies" the
/// constructor back to indexing the list, because eight walks across the app now
/// assume the promise instead of each keeping its own visited-set — and two of
/// them are unbounded loops without it. The shapes below are the ones a
/// hand-edited backup or a half-finished override row can actually produce.
CatalogNode n(String id, String? parent, {NodeKind kind = NodeKind.category}) =>
    CatalogNode(id: id, parentId: parent, name: id.toUpperCase(), kind: kind);

/// The property, stated once: from any node, following parents reaches a root in
/// a bounded number of steps, and every link on the way resolves.
void expectForest(Catalog catalog) {
  final all = catalog.all.toList();
  for (final start in all) {
    var current = start;
    var steps = 0;
    while (current.parentId != null) {
      final parent = catalog.byId(current.parentId!);
      expect(parent, isNotNull,
          reason: '${current.id} points at a parent that is not here');
      current = parent!;
      expect(++steps, lessThanOrEqualTo(all.length),
          reason: 'the chain above ${start.id} does not terminate');
    }
  }
  // Every node is reachable downward from some root, too — the same promise
  // read from the other end, which is the direction `cloneStructure` and the
  // hidden-subtree cascade walk.
  final reached = <String>{};
  void descend(String id) {
    if (!reached.add(id)) {
      fail('$id was reached twice walking down from the roots');
    }
    for (final child in catalog.childrenOf(id)) {
      descend(child.id);
    }
  }

  for (final root in catalog.roots) {
    descend(root.id);
  }
  expect(reached.length, all.length,
      reason: 'orphaned from every root: '
          '${all.map((x) => x.id).where((x) => !reached.contains(x)).toList()}');
}

void main() {
  group('a catalog is a forest whatever it is built from', () {
    test('a plain tree is left exactly as it was', () {
      final nodes = [n('root', null), n('a', 'root'), n('b', 'a')];
      final catalog = Catalog(nodes);
      expectForest(catalog);
      expect(catalog.byId('b')!.parentId, 'a');
      expect(catalog.byId('a')!.parentId, 'root');
      expect(catalog.roots.map((x) => x.id), ['root']);
    });

    test('a node that is its own parent becomes a root', () {
      final catalog = Catalog([n('root', null), n('a', 'a')]);
      expectForest(catalog);
      expect(catalog.byId('a')!.parentId, isNull);
    });

    test('a two-node loop is cut once, not flattened', () {
      final catalog = Catalog([n('a', 'b'), n('b', 'a')]);
      expectForest(catalog);
      // Exactly one link goes; the other survives, so the shape the user built
      // is not thrown away to repair it.
      expect(catalog.roots.map((x) => x.id), ['a']);
      expect(catalog.childrenOf('a').map((x) => x.id), ['b']);
    });

    test('a loop with a tail keeps the tail attached', () {
      final catalog = Catalog([n('tail', 'a'), n('a', 'b'), n('b', 'a')]);
      expectForest(catalog);
      expect(catalog.byId('tail')!.parentId, 'a');
      expect(catalog.roots.map((x) => x.id), ['a']);
    });

    test('the cut does not depend on the order the rows arrived in', () {
      final shapes = [
        [n('m', 'z'), n('z', 'k'), n('k', 'm')],
        [n('z', 'k'), n('k', 'm'), n('m', 'z')],
        [n('k', 'm'), n('m', 'z'), n('z', 'k')],
      ];
      for (final shape in shapes) {
        final catalog = Catalog(shape);
        expectForest(catalog);
        // The lowest id in the ring, every time — two devices restoring the
        // same file have to land on the same tree.
        expect(catalog.roots.map((x) => x.id), ['k'], reason: '$shape');
      }
    });

    test('a parent that is not in the catalog is detached, not dropped', () {
      final catalog = Catalog([n('root', null), n('orphan', 'nowhere')]);
      expectForest(catalog);
      // The point of detaching rather than deleting: before this, the node was
      // in `byId` and in search results and under no root at all, which is the
      // one state you cannot get out of from inside the app.
      expect(catalog.byId('orphan'), isNotNull);
      expect(catalog.roots.map((x) => x.id), containsAll(['root', 'orphan']));
    });

    test('a repeated id resolves to one node, and to the last one', () {
      // `childrenOf` and `byId` are built from the same set for this reason: if
      // the list kept both rows and the index kept one, a walk down and a walk
      // up would see different parents for the same id.
      final catalog = Catalog([n('a', null), n('b', 'a'), n('b', null)]);
      expectForest(catalog);
      expect(catalog.all.where((x) => x.id == 'b'), hasLength(1));
      expect(catalog.byId('b')!.parentId, isNull);
      expect(catalog.childrenOf('a'), isEmpty);
    });

    test('a repeated id that would loop against its own earlier row', () {
      final catalog = Catalog([n('a', 'b'), n('b', 'a'), n('b', null)]);
      expectForest(catalog);
      expect(catalog.roots.map((x) => x.id), ['b']);
      expect(catalog.childrenOf('b').map((x) => x.id), ['a']);
    });

    test('two independent loops are both cut', () {
      final catalog = Catalog([
        n('a', 'b'),
        n('b', 'a'),
        n('y', 'z'),
        n('z', 'y'),
        n('ok', null),
      ]);
      expectForest(catalog);
      expect(catalog.roots.map((x) => x.id).toSet(), {'a', 'y', 'ok'});
    });

    test('a chain dangling into a loop terminates from every start', () {
      final catalog = Catalog([
        n('t1', 't2'),
        n('t2', 'a'),
        n('a', 'b'),
        n('b', 'c'),
        n('c', 'a'),
        n('gone', 'vanished'),
      ]);
      expectForest(catalog);
    });

    test('an empty catalog is a forest', () {
      expectForest(Catalog(const []));
    });

    test('leavesUnder terminates and finds the leaves through a repaired loop',
        () {
      final catalog = Catalog([
        n('a', 'b'),
        n('b', 'a'),
        n('leaf', 'b', kind: NodeKind.leaf),
      ]);
      expectForest(catalog);
      expect(catalog.leavesUnder('a').map((x) => x.id), ['leaf']);
    });
  });
}
