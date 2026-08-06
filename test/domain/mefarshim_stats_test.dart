import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/mefarshim_stats.dart';
import 'package:chovos_hayom/domain/usecases/roll_up.dart';
import 'package:flutter_test/flutter_test.dart';

LearningEvent done(String node, int unit, List<String> layers, int seq) {
  final t = DateTime(2026, 1, 1).add(Duration(seconds: seq));
  return LearningEvent(
    id: '$node-$unit-$seq',
    profileId: 'p',
    nodeId: node,
    unitIndex: unit,
    action: EventAction.done,
    occurredAt: t,
    loggedAt: t,
    layers: layers,
  );
}

void main() {
  final catalog = Catalog([
    const CatalogNode(
        id: 'a',
        parentId: null,
        name: 'A',
        kind: NodeKind.leaf,
        unitLabel: UnitLabel.daf,
        unitOffset: 2,
        unitCount: 3), // 2,3,4
  ]);

  List<MefarshimStat> statsFor(List<LearningEvent> events,
          [Catalog? c]) =>
      MefarshimStats.of(RollUp.buildForest(c ?? catalog, FoldLog.fold(events)));

  test('tallies learned units per layer, most-learned first', () {
    final stats = statsFor([
      done('a', 2, ['main', 'rashi'], 0),
      done('a', 3, ['main', 'rashi'], 1),
      done('a', 4, ['main'], 2),
    ]);
    final byId = {for (final s in stats) s.layerId: s.learnedUnits};

    expect(byId['main'], 3);
    expect(byId['rashi'], 2);
    // Sorted descending by count.
    expect(stats.first.layerId, 'main');
  });

  test('ignores marks outside a leaf’s valid unit range', () {
    final stats = statsFor([
      done('a', 2, ['main'], 0),
      done('a', 99, ['main'], 1), // out of range for leaf a
    ]);
    expect(stats.single.learnedUnits, 1);
  });

  test('sums across roots, so a top-level custom sefer is counted', () {
    final two = Catalog([
      ...catalog.all,
      const CatalogNode(
          id: 'b',
          parentId: null,
          name: 'B',
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.daf,
          unitOffset: 1,
          unitCount: 2),
    ]);
    final stats = statsFor([
      done('a', 2, ['main'], 0),
      done('b', 1, ['main'], 1),
    ], two);
    expect(stats.single.learnedUnits, 2);
  });

  // The property that was missing when these numbers had two derivations: this
  // table and the per-node bars on the dashboard are the same arithmetic, and
  // nothing held them to it. Now the table *is* the roll-up, summed.
  test('every total equals the sum of the same layer over the tree', () {
    final nested = Catalog([
      const CatalogNode(
          id: 'root', parentId: null, name: 'Root', kind: NodeKind.category),
      const CatalogNode(
          id: 'x',
          parentId: 'root',
          name: 'X',
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.daf,
          unitOffset: 1,
          unitCount: 4),
      const CatalogNode(
          id: 'y',
          parentId: 'root',
          name: 'Y',
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.daf,
          unitOffset: 1,
          unitCount: 4),
    ]);
    final forest = RollUp.buildForest(
        nested,
        FoldLog.fold([
          done('x', 1, ['main', 'rashi'], 0),
          done('x', 2, ['main'], 1),
          done('y', 1, ['main', 'rashi'], 2),
          done('y', 9, ['main', 'rashi'], 3), // out of range
        ]));

    final stats = {
      for (final s in MefarshimStats.of(forest)) s.layerId: s.learnedUnits
    };
    final leaves = forest.single.children;
    for (final layerId in stats.keys) {
      expect(stats[layerId],
          leaves.fold<int>(0, (n, leaf) => n + leaf.learnedFor(layerId)),
          reason: '$layerId disagrees with the bars it is drawn from');
    }
    expect(stats['main'], 3);
    expect(stats['rashi'], 2);
  });

  test('a node with no marks contributes no row', () {
    expect(statsFor(const []), isEmpty);
  });
}
