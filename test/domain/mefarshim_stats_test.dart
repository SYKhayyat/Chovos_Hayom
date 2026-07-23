import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/mefarshim_stats.dart';
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

  test('tallies learned units per layer, most-learned first', () {
    final fold = FoldLog.fold([
      done('a', 2, ['main', 'rashi'], 0),
      done('a', 3, ['main', 'rashi'], 1),
      done('a', 4, ['main'], 2),
    ]);

    final stats = MefarshimStats.compute(catalog, fold);
    final byId = {for (final s in stats) s.layerId: s.learnedUnits};

    expect(byId['main'], 3);
    expect(byId['rashi'], 2);
    // Sorted descending by count.
    expect(stats.first.layerId, 'main');
  });

  test('ignores marks outside a leaf’s valid unit range', () {
    final fold = FoldLog.fold([
      done('a', 2, ['main'], 0),
      done('a', 99, ['main'], 1), // out of range for leaf a
    ]);
    final stats = MefarshimStats.compute(catalog, fold);
    expect(stats.single.learnedUnits, 1);
  });
}
