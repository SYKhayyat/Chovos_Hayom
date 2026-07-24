import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogNode cat(String id, String? parent) =>
    CatalogNode(id: id, parentId: parent, name: id, kind: NodeKind.category);

CatalogNode leaf(String id, String? parent, {int units = 3}) => CatalogNode(
      id: id,
      parentId: parent,
      name: id,
      kind: NodeKind.leaf,
      unitLabel: UnitLabel.daf,
      unitCount: units,
      unitOffset: 1,
    );

void main() {
  test('leavesUnder returns the leaves of a normal subtree', () {
    final c = Catalog([cat('root', null), leaf('a', 'root'), leaf('b', 'root')]);
    expect(c.leavesUnder('root').map((n) => n.id).toSet(), {'a', 'b'});
  });

  test('leavesUnder terminates on a parent cycle rather than hanging', () {
    // Two categories that point at each other — only reachable via a hand-edited
    // import (the validator rejects it), but leavesUnder is called from
    // BulkMarker and the cycle editor, where an unbounded recursion would hang
    // the app instead of failing cleanly. It must simply stop.
    final c = Catalog([cat('a', 'b'), cat('b', 'a')]);
    expect(c.leavesUnder('a'), isEmpty);
  });

  test('leavesUnder does not revisit a node reachable by two paths', () {
    // A category and a leaf both filed under it, plus a stray override that makes
    // the category its own parent. The leaf must be yielded once, not forever.
    final c = Catalog([cat('a', 'a'), leaf('x', 'a')]);
    expect(c.leavesUnder('a').map((n) => n.id).toList(), ['x']);
  });
}
