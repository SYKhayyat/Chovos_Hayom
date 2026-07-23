import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/roll_up.dart';
import 'package:flutter_test/flutter_test.dart';

Catalog _catalog() => Catalog(const [
      CatalogNode(id: 'root', parentId: null, name: 'Root', kind: NodeKind.category),
      CatalogNode(
          id: 'a',
          parentId: 'root',
          name: 'A',
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.daf,
          unitCount: 3,
          unitOffset: 2), // valid units: 2,3,4
      CatalogNode(
          id: 'b',
          parentId: 'root',
          name: 'B',
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.perek,
          unitCount: 2,
          unitOffset: 1), // valid units: 1,2
    ]);

/// Builds a text-only (`{main}`) completed-layer map from done unit sets.
Map<String, Map<int, Set<String>>> _completed(Map<String, Set<int>> done) => {
      for (final e in done.entries)
        e.key: {for (final u in e.value) u: {'main'}}
    };

void main() {
  group('RollUp', () {
    test('leaf learned counts done units in range', () {
      final fold = LogFold(_completed({'a': {2, 3}}), {});
      final root = RollUp.buildForest(_catalog(), fold).single;
      final a = root.children.firstWhere((n) => n.id == 'a');
      expect(a.learned, 2);
      expect(a.total, 3);
    });

    test('out-of-range done units are ignored (learned never exceeds total)', () {
      final fold = LogFold(_completed({'a': {2, 3, 4, 99}}), {});
      final root = RollUp.buildForest(_catalog(), fold).single;
      final a = root.children.firstWhere((n) => n.id == 'a');
      expect(a.learned, 3);
      expect(a.total, 3);
      expect(a.isComplete, isTrue);
    });

    test('parent aggregates children', () {
      final fold = LogFold(_completed({'a': {2, 3}, 'b': {1}}), {});
      final root = RollUp.buildForest(_catalog(), fold).single;
      expect(root.learned, 3);
      expect(root.total, 5);
      expect(root.remaining, 2);
      expect(root.percent, closeTo(60.0, 0.001));
    });

    test('per-layer coverage is counted per leaf and rolled up, in range', () {
      final fold = LogFold({
        'a': {
          2: {'main', 'rashi'},
          3: {'main', 'rashi'},
          4: {'main'},
          99: {'rashi'}, // out of range — ignored
        },
        'b': {
          1: {'main', 'rashi'},
        },
      }, {});
      final root = RollUp.buildForest(_catalog(), fold).single;
      final a = root.children.firstWhere((n) => n.id == 'a');

      expect(a.learnedFor('rashi'), 2); // units 2,3 (99 ignored)
      expect(a.learnedFor('main'), 3);
      // Root sums Rashi across A (2) and B (1).
      expect(root.learnedFor('rashi'), 3);
      expect(root.learnedFor('main'), 4);
      expect(root.learnedFor('tosafos'), 0);
    });
  });
}
