import '../domain/entities/catalog.dart';
import '../domain/entities/catalog_node.dart';
import '../domain/entities/enums.dart';
import '../domain/usecases/fold_log.dart';
import '../domain/usecases/layer_requirements.dart';
import '../domain/usecases/offered_layers.dart';
import 'logging_service.dart';

/// An inclusive range of unit indices, `[start, end]`. Used to bound a bulk
/// action to part of a leaf (e.g. "finish dapim 10–20").
class UnitRange {
  const UnitRange(this.start, this.end);
  final int start;
  final int end;

  bool contains(int unit) => unit >= start && unit <= end;
}

/// What a bulk action operates on.
///
/// - [SingleLayerSelection] — one specific layer (the text, or one meforish)
///   across every targeted unit.
/// - [RequiredLayerSelection] — each unit's own *required* set (so "finish all"
///   marks exactly what each unit needs, honouring per-node/per-unit overrides).
/// - [AllLayersSelection] — every layer currently completed on a unit; only
///   meaningful for *clear* (there is no "all possible" to finish).
sealed class LayerSelection {
  const LayerSelection();
}

class SingleLayerSelection extends LayerSelection {
  const SingleLayerSelection(this.layerId);
  final String layerId;
}

class RequiredLayerSelection extends LayerSelection {
  const RequiredLayerSelection();
}

class AllLayersSelection extends LayerSelection {
  const AllLayersSelection();
}

/// A planned-but-not-yet-written bulk action: exactly the marks that would be
/// appended, with the no-ops already stripped out.
///
/// Planning is separated from committing so the UI can tell the user what a
/// destructive action will actually do — "this marks 2,711 units" — *before* it
/// happens, using the same numbers the write will use rather than an estimate.
class BulkPlan {
  const BulkPlan(this.marks);

  final List<BulkMark> marks;

  /// Units this would touch. One mark per unit, so this is the count the
  /// confirmation dialog shows.
  int get unitsAffected => marks.length;

  bool get isEmpty => marks.isEmpty;
}

/// The outcome of a committed bulk action: the batch it wrote (undo it by id,
/// durably — see [BatchHistory]), the ids of its events, and the units touched.
class BulkResult {
  const BulkResult({
    required this.addedEventIds,
    required this.unitsAffected,
    this.batchId,
  });
  final List<String> addedEventIds;
  final int unitsAffected;

  /// The shared batch id of the appended events, or null if nothing was written.
  final String? batchId;

  bool get isEmpty => addedEventIds.isEmpty;
}

/// Finishes or clears many units at once, from a single leaf or a whole category
/// (cascading to every descendant leaf). Marks that would be no-ops — a layer
/// already learned, a unit with nothing to clear — are skipped, so the event log
/// never grows with redundant rows and big categories stay fast.
///
/// Pure orchestration: it reads the current [fold] and the two resolvers to plan
/// the minimal set of marks, then commits them through [LoggingService.logBatch]
/// in one transaction.
class BulkMarker {
  BulkMarker({
    required this.catalog,
    required this.fold,
    required this.required,
    required this.offered,
    required this.logger,
  });

  final Catalog catalog;
  final LogFold fold;
  final LayerRequirements required;
  final OfferedLayers offered;
  final LoggingService logger;

  /// Plan marking units done under [nodeId] according to [selection]. [range]
  /// bounds the units (leaf-level only; ignored for a category cascade where
  /// units span many leaves). Writes nothing — pass the result to [commit].
  BulkPlan planFinish({
    required String nodeId,
    required LayerSelection selection,
    UnitRange? range,
  }) {
    final marks = <BulkMark>[];
    for (final (leaf, unit) in _targetUnits(nodeId, range)) {
      final have = fold.completedLayers(leaf.id, unit);
      final toAdd = _finishLayersFor(leaf.id, unit, selection, have);
      if (toAdd.isNotEmpty) {
        marks.add(BulkMark(
            nodeId: leaf.id,
            unitIndex: unit,
            action: EventAction.done,
            layers: toAdd));
      }
    }
    return BulkPlan(marks);
  }

  /// Plan un-marking units under [nodeId]. With no [selection] (or
  /// [AllLayersSelection]) every learned layer on each unit is cleared; a
  /// [SingleLayerSelection] clears just that layer. Writes nothing.
  BulkPlan planClear({
    required String nodeId,
    LayerSelection selection = const AllLayersSelection(),
    UnitRange? range,
  }) {
    final marks = <BulkMark>[];
    for (final (leaf, unit) in _targetUnits(nodeId, range)) {
      final have = fold.completedLayers(leaf.id, unit);
      if (have.isEmpty) continue;
      final toRemove = switch (selection) {
        SingleLayerSelection(:final layerId) =>
          have.contains(layerId) ? <String>[layerId] : const <String>[],
        _ => have.toList(),
      };
      if (toRemove.isNotEmpty) {
        marks.add(BulkMark(
            nodeId: leaf.id,
            unitIndex: unit,
            action: EventAction.undone,
            layers: toRemove));
      }
    }
    return BulkPlan(marks);
  }

  /// Plan and commit in one step. The UI plans first (so it can confirm with a
  /// real count); this is the convenience path for callers that don't need to.
  Future<BulkResult> finish({
    required String nodeId,
    required LayerSelection selection,
    UnitRange? range,
  }) =>
      commit(planFinish(nodeId: nodeId, selection: selection, range: range));

  Future<BulkResult> clear({
    required String nodeId,
    LayerSelection selection = const AllLayersSelection(),
    UnitRange? range,
  }) =>
      commit(planClear(nodeId: nodeId, selection: selection, range: range));

  /// The layers to *add* for one unit under [selection], excluding any already
  /// learned. Empty means "nothing to do — skip this unit".
  List<String> _finishLayersFor(
      String leafId, int unit, LayerSelection selection, Set<String> have) {
    final want = switch (selection) {
      SingleLayerSelection(:final layerId) => {layerId},
      RequiredLayerSelection() => required.forUnit(leafId, unit),
      // "Finish all possible" isn't well defined; treat as the required set.
      AllLayersSelection() => required.forUnit(leafId, unit),
    };
    return [
      for (final l in want)
        if (!have.contains(l)) l,
    ];
  }

  /// Every (leaf, unitIndex) pair the action should visit. For a leaf node this
  /// is its own units (optionally bounded by [range]); for a category it is the
  /// union over all descendant leaves (range ignored).
  Iterable<(CatalogNode, int)> _targetUnits(String nodeId, UnitRange? range) sync* {
    final node = catalog.byId(nodeId);
    if (node == null) return;
    final singleLeaf = node.isLeaf;
    for (final leaf in catalog.leavesUnder(nodeId)) {
      for (final unit in leaf.unitIndices) {
        if (singleLeaf && range != null && !range.contains(unit)) continue;
        yield (leaf, unit);
      }
    }
  }

  /// Write a [BulkPlan] as one batch. Safe to call with an empty plan.
  Future<BulkResult> commit(BulkPlan plan) async {
    if (plan.isEmpty) {
      return const BulkResult(addedEventIds: [], unitsAffected: 0);
    }
    final events = await logger.logBatch(plan.marks);
    return BulkResult(
      addedEventIds: [for (final e in events) e.id],
      unitsAffected: plan.unitsAffected,
      batchId: events.first.batchId,
    );
  }
}
