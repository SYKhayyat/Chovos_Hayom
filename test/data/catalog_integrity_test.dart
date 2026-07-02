import 'dart:io';

import 'package:chovos_hayom/data/catalog/json_catalog_repository.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reads the real asset from disk (CWD is the package root under `flutter test`).
  final catalog =
      JsonCatalogRepository.parse(File('assets/catalog/catalog.json').readAsStringSync());
  final all = catalog.all.toList();

  group('catalog integrity', () {
    test('has a single root named Kol HaTorah Kula', () {
      expect(catalog.roots, hasLength(1));
      expect(catalog.roots.single.id, 'all');
      expect(catalog.roots.single.name, 'Kol HaTorah Kula');
    });

    test('node ids are unique', () {
      final ids = all.map((n) => n.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every non-root parentId resolves to an existing node', () {
      for (final n in all) {
        if (n.parentId != null) {
          expect(catalog.byId(n.parentId!), isNotNull,
              reason: '${n.id} has orphan parent ${n.parentId}');
        }
      }
    });

    test('every leaf has a positive unit count, an offset, and a label', () {
      final leaves = all.where((n) => n.isLeaf);
      expect(leaves, isNotEmpty);
      for (final leaf in leaves) {
        expect(leaf.unitCount, greaterThan(0), reason: leaf.id);
        expect(leaf.unitOffset, greaterThanOrEqualTo(1), reason: leaf.id);
        expect(leaf.unitLabel, isNotNull, reason: leaf.id);
      }
    });

    test('categories are never leaves and vice versa', () {
      for (final n in all) {
        final hasChildren = catalog.childrenOf(n.id).isNotEmpty;
        if (n.isLeaf) expect(hasChildren, isFalse, reason: '${n.id} leaf w/ children');
      }
    });

    test('known values ported correctly', () {
      final shabbos = catalog.byId('shabbosShas')!;
      expect(shabbos.unitCount, 156);
      expect(shabbos.unitOffset, 2);
      expect(shabbos.unitLabel, UnitLabel.daf);

      // Tanach is famously 929 perakim — a good canary for the whole port.
      expect(_leafSum(catalog, 'tanach'), 929);
    });
  });
}

int _leafSum(Catalog catalog, String id) {
  final node = catalog.byId(id);
  if (node == null) return 0;
  if (node.isLeaf) return node.unitCount;
  var sum = 0;
  for (final c in catalog.childrenOf(id)) {
    sum += _leafSum(catalog, c.id);
  }
  return sum;
}
