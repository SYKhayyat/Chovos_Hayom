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

  test('planning writes nothing and reports the count the commit will use',
      () async {
    final m = await marker();
    final plan =
        m.planFinish(nodeId: 'cat', selection: const RequiredLayerSelection());

    expect(plan.unitsAffected, 5);
    expect(await repo.getEvents('p'), isEmpty, reason: 'planning is read-only');

    final result = await m.commit(plan);
    expect(result.unitsAffected, plan.unitsAffected);
  });

  test('a plan that would change nothing is empty, so the UI can say so',
      () async {
    await (await marker())
        .finish(nodeId: 'a', selection: const RequiredLayerSelection());
    final plan = (await marker())
        .planFinish(nodeId: 'a', selection: const RequiredLayerSelection());
    expect(plan.isEmpty, isTrue);
  });

  test('every event of one bulk action shares a batch id', () async {
    final result = await (await marker())
        .finish(nodeId: 'cat', selection: const RequiredLayerSelection());

    expect(result.batchId, isNotNull);
    final events = await repo.getEvents('p');
    expect(events.map((e) => e.batchId).toSet(), {result.batchId});
    // Distinct from every event id, so undo-by-batch can't collide with them.
    expect(events.map((e) => e.id), isNot(contains(result.batchId)));
  });

  test('two bulk actions get different batch ids', () async {
    final first = await (await marker())
        .finish(nodeId: 'a', selection: const RequiredLayerSelection());
    final second = await (await marker())
        .finish(nodeId: 'b', selection: const RequiredLayerSelection());
    expect(first.batchId, isNot(second.batchId));
  });

  test('undo by batch id reverts exactly that batch, days later', () async {
    final first = await (await marker())
        .finish(nodeId: 'a', selection: const RequiredLayerSelection());
    await (await marker())
        .finish(nodeId: 'b', selection: const RequiredLayerSelection());

    // No held event-id list — just the batch id, which the log itself carries.
    final removed = await repo.removeBatch('p', first.batchId!);

    expect(removed, 3);
    final fold = await currentFold();
    expect(fold.doneUnits('a'), isEmpty, reason: 'the undone batch');
    expect(fold.doneUnits('b'), {1, 2}, reason: 'the other batch is untouched');
  });

  test('a single mark carries no batch id, so it never joins the undo list',
      () async {
    await logger.markDone('a', 2);
    expect((await repo.getEvents('p')).single.batchId, isNull);
  });
}
