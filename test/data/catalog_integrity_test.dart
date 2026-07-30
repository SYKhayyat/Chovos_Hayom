import 'dart:io';

import 'package:chovos_hayom/data/catalog/json_catalog_repository.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
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

    // The Hebrew names are what the app shows under a Hebrew locale. They were
    // absent for a long time — `nameHebrew` was carried through the JSON, the
    // database, the backup format and the search index and never populated —
    // so every sefer read as its transliteration. These two guard the data
    // rather than the code: a future catalog edit must not quietly drop one.
    test('every node has a Hebrew name', () {
      final unnamed = [
        for (final n in all)
          if ((n.nameHebrew ?? '').trim().isEmpty) n.id,
      ];
      expect(unnamed, isEmpty, reason: 'no Hebrew name for: $unnamed');
    });

    test('a node and its ancestors identify it uniquely, in both languages', () {
      // This *was* "names are unique", held up by a "(Shas)"-style suffix typed
      // into 120 of the 312 names. That made every row inside Shas read "Moed
      // (Shas)", where the suffix says nothing, while Mishnayos masechtos were
      // left bare — and a name is not where a node's position belongs. The
      // suffixes are gone and the qualifier is derived from the ancestors, so
      // the property the flat lists (search results, the calculator's dropdown,
      // both cycle pickers) actually need is this one: name *plus path* is
      // unique. Asserted in both languages, since the Hebrew is what a Hebrew
      // reader disambiguates by.
      String path(CatalogNode n, String Function(CatalogNode) name) {
        final parts = <String>[];
        var current = n.parentId == null ? null : catalog.byId(n.parentId!);
        while (current != null && current.parentId != null) {
          parts.add(name(current));
          current = catalog.byId(current.parentId!);
        }
        return parts.reversed.join(' · ');
      }

      for (final name in <String Function(CatalogNode)>[
        (n) => n.name,
        (n) => n.nameHebrew!,
      ]) {
        final seen = <String, String>{};
        final clashes = <String>[];
        for (final n in all) {
          final key = '${name(n)} — ${path(n, name)}';
          final first = seen[key];
          if (first != null) {
            clashes.add('$key: $first and ${n.id}');
          } else {
            seen[key] = n.id;
          }
        }
        expect(clashes, isEmpty);
      }
    });

    test('no name carries its own position as a suffix', () {
      // The specific thing that was removed, asserted so it cannot creep back in
      // one node at a time. A parenthetical naming an ancestor is the data doing
      // the display layer's job.
      final corpora = {
        for (final n in all)
          if (n.parentId == null || catalog.byId(n.parentId!)?.parentId == null)
            n.name,
      };
      final offenders = [
        for (final n in all)
          for (final corpus in corpora)
            if (n.name.endsWith('($corpus)')) '${n.id}: ${n.name}',
      ];
      expect(offenders, isEmpty);
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
