import 'package:chovos_hayom/application/catalog_editor.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// The structural rules of a clone, asserted against the function the app
/// actually calls.
///
/// This file used to open with a copy of `cloneStructure`'s walk, lifted out
/// because the method needs a `WidgetRef` — so every assertion below was made
/// about the transcription rather than about the shipped code, and a divergence
/// between the two was invisible by construction. `cloneOf` is now the shared
/// part, and the `WidgetRef` is left holding only the write.
void main() {
  final catalog = Catalog(const [
    CatalogNode(
        id: 'chumash', parentId: null, name: 'Chumash', kind: NodeKind.category),
    CatalogNode(
      id: 'bereishis',
      parentId: 'chumash',
      name: 'Bereishis',
      kind: NodeKind.leaf,
      unitLabel: UnitLabel.perek,
      unitCount: 3,
      unitOffset: 1,
      unitNames: ['Bereishis', 'Noach', 'Lech Lecha'],
    ),
  ]);

  /// Ids a reader can follow, in mint order.
  List<CatalogNode> clone(CatalogNode root) {
    var n = 0;
    return cloneOf(catalog, root, newId: () => 'new${n++}');
  }

  test('cloning a subtree keeps its named units', () {
    // Named units are structure, not progress. Dropping them turned a clone of
    // Chumash into a list of numbers.
    final leaf =
        clone(catalog.byId('chumash')!).firstWhere((n) => n.name == 'Bereishis');

    expect(leaf.unitNames, ['Bereishis', 'Noach', 'Lech Lecha']);
    expect(leaf.unitDisplay(2), 'Noach');
    expect(leaf.unitCount, 3);
    expect(leaf.unitOffset, 1);
  });

  test('the clone is a fresh subtree, re-parented onto the new root', () {
    final nodes = clone(catalog.byId('chumash')!);
    final root = nodes.firstWhere((n) => n.name == 'Chumash (copy)');
    final leaf = nodes.firstWhere((n) => n.name == 'Bereishis');

    expect(nodes.map((n) => n.id), isNot(contains('chumash')),
        reason: 'nothing keeps an id from the tree it was copied out of');
    expect(leaf.parentId, root.id, reason: 'children point at the new root');
    expect(root.parentId, isNull, reason: 'cloned in as a sibling');
  });

  test('only the root is renamed', () {
    // The copy is one tree the user has to be able to find; renaming its
    // insides would make every leaf in it read "(copy)" as well.
    final nodes = clone(catalog.byId('chumash')!);

    expect(nodes.where((n) => n.name.endsWith('(copy)')).length, 1);
  });

  test('cloning a leaf is one node that keeps its place in the tree', () {
    final nodes = clone(catalog.byId('bereishis')!);

    expect(nodes, hasLength(1));
    expect(nodes.single.name, 'Bereishis (copy)');
    expect(nodes.single.parentId, 'chumash',
        reason: 'a leaf copy is a sibling of the original, under the real '
            'parent — which is a built-in id, not a minted one');
  });
}
