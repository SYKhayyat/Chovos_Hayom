import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/mefarshim_stats.dart';
import 'package:chovos_hayom/domain/usecases/roll_up.dart';
import 'package:chovos_hayom/domain/usecases/siyum.dart';
import 'package:flutter_test/flutter_test.dart';

/// A leaf that records every time something walks its full unit range.
///
/// Deriving progress must cost what the user has *learned*, not what exists —
/// otherwise every tap on a daf pays for all 12,000 units of the catalog, and
/// the app gets slower for exactly the users with the most history. This makes
/// that a property the suite can assert rather than a claim in a comment.
class _CountingLeaf extends CatalogNode {
  _CountingLeaf({
    required super.id,
    required super.parentId,
    required super.name,
    required int units,
  }) : super(
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.daf,
          unitCount: units,
          unitOffset: 1,
        );

  int fullScans = 0;

  @override
  Iterable<int> get unitIndices {
    fullScans++;
    return super.unitIndices;
  }
}

LearningEvent done(String node, int unit, {List<String> layers = const ['main']}) =>
    LearningEvent(
      id: '$node-$unit-${layers.join()}',
      profileId: 'p',
      nodeId: node,
      unitIndex: unit,
      action: EventAction.done,
      occurredAt: DateTime(2026, 1, 1),
      loggedAt: DateTime(2026, 1, 1),
      layers: layers,
    );

void main() {
  late _CountingLeaf huge;
  late Catalog catalog;

  setUp(() {
    // Far larger than Shas, so a full-range walk would be unmistakable.
    huge = _CountingLeaf(
        id: 'huge', parentId: 'root', name: 'Huge', units: 500000);
    catalog = Catalog([
      const CatalogNode(
          id: 'root', parentId: null, name: 'Root', kind: NodeKind.category),
      huge,
    ]);
  });

  test('rolling up a barely-touched leaf never walks its whole unit range', () {
    final fold = FoldLog.fold([
      done('huge', 1, layers: ['main', 'rashi']),
      done('huge', 2),
    ]);

    final root = RollUp.buildForest(catalog, fold).single;

    expect(huge.fullScans, 0,
        reason: 'per-layer coverage must walk the marked units, not all 500k');
    expect(root.learned, 2);
    expect(root.total, 500000);
    expect(root.learnedFor('rashi'), 1);
  });

  test('finding siyumim never walks the range of an unfinished leaf', () {
    final fold = FoldLog.fold([done('huge', 1)]);
    final forest = RollUp.buildForest(catalog, fold);
    huge.fullScans = 0;

    expect(SiyumFinder.completed(forest, fold), isEmpty);
    expect(huge.fullScans, 0);
  });

  test('per-meforish totals scale with what is learned, not the catalog', () {
    final fold = FoldLog.fold([
      done('huge', 1, layers: ['main', 'rashi']),
      done('huge', 2, layers: ['main']),
    ]);
    huge.fullScans = 0;

    final stats = MefarshimStats.compute(catalog, fold);

    expect(huge.fullScans, 0);
    expect(stats.firstWhere((s) => s.layerId == 'main').learnedUnits, 2);
    expect(stats.firstWhere((s) => s.layerId == 'rashi').learnedUnits, 1);
  });

  test('out-of-range marks still cannot inflate learned', () {
    // The clamp has to survive the switch from walking units to walking marks.
    const small = CatalogNode(
        id: 'small',
        parentId: 'root',
        name: 'Small',
        kind: NodeKind.leaf,
        unitLabel: UnitLabel.daf,
        unitCount: 2,
        unitOffset: 1);
    final c = Catalog([
      const CatalogNode(
          id: 'root', parentId: null, name: 'Root', kind: NodeKind.category),
      small,
    ]);
    final fold = FoldLog.fold([
      done('small', 1, layers: ['main', 'rashi']),
      done('small', 2),
      done('small', 900, layers: ['main', 'rashi']), // out of range
    ]);

    final root = RollUp.buildForest(c, fold).single;
    expect(root.learned, 2);
    expect(root.learnedFor('rashi'), 1, reason: 'the stray mark is not counted');
  });
}
