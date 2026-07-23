import 'package:chovos_hayom/application/bulk_marker.dart';
import 'package:chovos_hayom/application/logging_service.dart';
import 'package:chovos_hayom/data/repositories/in_memory_progress_repository.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/layer_requirements.dart';
import 'package:chovos_hayom/domain/usecases/offered_layers.dart';
import 'package:flutter_test/flutter_test.dart';

/// cat ─┬─ a (units 2,3,4)
///      └─ b (units 1,2)
Catalog buildCatalog() => Catalog([
      const CatalogNode(
          id: 'cat', parentId: null, name: 'Cat', kind: NodeKind.category),
      const CatalogNode(
          id: 'a',
          parentId: 'cat',
          name: 'A',
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.daf,
          unitOffset: 2,
          unitCount: 3),
      const CatalogNode(
          id: 'b',
          parentId: 'cat',
          name: 'B',
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.daf,
          unitOffset: 1,
          unitCount: 2),
    ]);

void main() {
  late InMemoryProgressRepository repo;
  late int counter;
  late LoggingService logger;
  final catalog = buildCatalog();

  setUp(() {
    repo = InMemoryProgressRepository();
    counter = 0;
    logger = LoggingService(
      repository: repo,
      profileId: 'p',
      now: () => DateTime(2026, 1, 1, 8),
      idGen: () => 'e${counter++}',
    );
  });

  Future<BulkMarker> marker() async {
    final fold = FoldLog.fold(await repo.getEvents('p'));
    return BulkMarker(
      catalog: catalog,
      fold: fold,
      required: LayerRequirements(),
      offered: OfferedLayers(),
      logger: logger,
    );
  }

  Future<LogFold> currentFold() async =>
      FoldLog.fold(await repo.getEvents('p'));

  test('finish-all on a category cascades to every descendant leaf', () async {
    final result = await (await marker())
        .finish(nodeId: 'cat', selection: const RequiredLayerSelection());

    expect(result.unitsAffected, 5); // a:3 + b:2
    expect(result.addedEventIds, hasLength(5));
    final fold = await currentFold();
    expect(fold.doneUnits('a'), {2, 3, 4});
    expect(fold.doneUnits('b'), {1, 2});
  });

  test('finish skips units already satisfying the target (no redundant events)',
      () async {
    await logger.markDone('a', 2); // pre-mark one unit
    final result = await (await marker())
        .finish(nodeId: 'a', selection: const RequiredLayerSelection());

    expect(result.unitsAffected, 2); // only a3, a4
    expect((await repo.getEvents('p')), hasLength(3)); // 1 pre + 2 new
  });

  test('single-layer finish marks just that layer across the leaf', () async {
    final result = await (await marker())
        .finish(nodeId: 'a', selection: const SingleLayerSelection('rashi'));

    expect(result.unitsAffected, 3);
    final fold = await currentFold();
    expect(fold.completedLayers('a', 2), {'rashi'});
    expect(fold.completedLayers('a', 4), {'rashi'});
    // rashi isn't required, so the unit is NOT done by text-only rules.
    expect(fold.doneUnits('a'), isEmpty);
  });

  test('range bounds a finish to the chosen units (inclusive)', () async {
    final result = await (await marker()).finish(
      nodeId: 'a',
      selection: const RequiredLayerSelection(),
      range: const UnitRange(3, 4),
    );

    expect(result.unitsAffected, 2);
    expect((await currentFold()).doneUnits('a'), {3, 4});
  });

  test('clear-all un-marks every learned layer on each unit', () async {
    await logger.markDone('a', 2, layers: ['main', 'rashi']);
    await logger.markDone('a', 3);

    final result = await (await marker()).clear(nodeId: 'a');
    expect(result.unitsAffected, 2);
    expect((await currentFold()).doneUnits('a'), isEmpty);
  });

  test('undo removes exactly the events a bulk action added', () async {
    final result = await (await marker())
        .finish(nodeId: 'cat', selection: const RequiredLayerSelection());
    await repo.removeEvents(result.addedEventIds);

    final fold = await currentFold();
    expect(fold.doneUnits('a'), isEmpty);
    expect(fold.doneUnits('b'), isEmpty);
    expect(await repo.getEvents('p'), isEmpty);
  });

  test('finish on an already-complete node reports nothing to change', () async {
    await (await marker())
        .finish(nodeId: 'a', selection: const RequiredLayerSelection());
    final again = await (await marker())
        .finish(nodeId: 'a', selection: const RequiredLayerSelection());
    expect(again.isEmpty, isTrue);
    expect(again.unitsAffected, 0);
  });
}
