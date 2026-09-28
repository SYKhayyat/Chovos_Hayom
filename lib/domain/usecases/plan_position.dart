import '../../core/day.dart';
import '../entities/catalog.dart';
import '../entities/catalog_node.dart';
import '../entities/layer.dart';
import 'fold_log.dart';
import 'layer_roles.dart';
import 'learning_plan.dart';

/// Where a learner has got to in a plan's sequence: which item, and which unit
/// of it.
///
/// A value type because this is shown ("you are on Sukkah, daf 12") and derived
/// constantly, and because the projection in #26 has to agree with the today
/// screen about the same question. One [PlanPosition] produced by one function
/// is the only way they can.
class PlanPosition {
  const PlanPosition({
    required this.itemIndex,
    required this.itemId,
    required this.nodeId,
    required this.unitNodeId,
    required this.unitIndex,
    required this.remaining,
  });

  /// Index into [LearningPlan.items], or -1 when the plan has no sequence.
  final int itemIndex;

  /// The item being worked on, or null when there is nothing left to do.
  final String? itemId;

  /// The catalog node under the current item, or null.
  final String? nodeId;

  /// The leaf the next unit belongs to. Differs from [nodeId] when the item is a
  /// category: the position is "Shabbos, daf 12", so the leaf is Shabbos while
  /// the item is Moed.
  final String? unitNodeId;

  /// The next unit to learn, or null when everything is done.
  final int? unitIndex;

  /// Units still owed across the whole plan, sequence included.
  final int remaining;

  /// True when nothing is left. [unitIndex] is null whenever this is true.
  bool get isComplete => unitIndex == null;

  @override
  bool operator ==(Object other) =>
      other is PlanPosition &&
      other.itemIndex == itemIndex &&
      other.itemId == itemId &&
      other.nodeId == nodeId &&
      other.unitNodeId == unitNodeId &&
      other.unitIndex == unitIndex &&
      other.remaining == remaining;

  @override
  int get hashCode =>
      Object.hash(itemIndex, itemId, nodeId, unitNodeId, unitIndex, remaining);

  @override
  String toString() => 'PlanPosition(item: $itemId, unit: $unitIndex, '
      'remaining: $remaining)';
}

/// Reads a plan's position and totals out of the log.
///
/// **This is a fold reader, not a schedule.** It answers "what has been done",
/// which the log is the only authority on. What a day *asks* for is
/// [PlanSchedule]'s business, and the two meet in the projection — deliberately
/// kept apart so neither can drift into being the other's answer.
class PlanProgress {
  const PlanProgress._();

  /// The first unit still owed anywhere under [node], as of the log, or null if
  /// there is none.
  ///
  /// Pass [asOf] to ask "as of this day"; leave it null to ask "that has not been
  /// logged at all", which is the today screen's question. The distinction is not
  /// cosmetic — with [asOf] set, a unit learned *on* that day is not yet owed,
  /// which is what stops a plan reporting itself finished on the day it finishes.
  /// Without the parameter, the two answers disagreed: the remaining count
  /// ignored today's marks while the next-unit lookup did not, so one plan
  /// reported zero remaining and a next unit at the same time.
  ///
  /// Extracted from the today screen's private copy so the two cannot disagree
  /// about the same unit: they walked the same leaves in the same order, and two
  /// implementations of "the next unit" is how a learner ends up with the app
  /// offering one daf and the projection counting another.
  static (CatalogNode, int)? nextUnitUnder(
    CatalogNode node,
    Catalog catalog,
    LogFold fold, {
    LayerRoles? layers,
    Day? asOf,
  }) {
    for (final leaf in catalog.leavesUnder(node.id)) {
      final required = _requiredFor(layers, leaf.id);
      for (var unit = leaf.unitOffset;
          unit < leaf.unitOffset + leaf.unitCount;
          unit++) {
        // A unit learned on or after [asOf] has not been done *by* [asOf], so it
        // is the next one owed. Returning rather than skipping is the whole
        // point: skipping it would march past the owed unit and report the plan
        // finished on the day it finished.
        if (asOf != null) {
          final at = fold.doneAt(leaf.id, unit);
          if (at != null && Day.of(at) >= asOf) return (leaf, unit);
        }
        final completed = fold.completedLayers(leaf.id, unit);
        if (!required.every(completed.contains)) return (leaf, unit);
      }
    }
    return null;
  }

  /// Total units under every item of [plan], counting a node that appears in more
  /// than one item once per item — a sequence may legitimately revisit a sefer.
  static int totalUnits(
    LearningPlan plan,
    Catalog catalog,
  ) {
    var total = 0;
    for (final item in plan.items) {
      final node = catalog.byId(item.nodeId);
      if (node != null) total += _unitsUnder(node, catalog);
    }
    if (plan.items.isEmpty) {
      // No sequence: the plan's content is whatever its assignments target.
      for (final assignment in plan.assignments) {
        final id = assignment.targetNodeId;
        final node = id == null ? null : catalog.byId(id);
        if (node != null) total += _unitsUnder(node, catalog);
      }
    }
    return total;
  }

  /// Units already done under [plan], counted only if actually done **before**
  /// [asOf]. A unit learned on [asOf] has not been done *by* [asOf], and treating
  /// it as done would let a plan report itself finished on the day it finishes.
  static int doneUnits(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day asOf, {
    LayerRoles? layers,
  }) {
    var done = 0;
    for (final item in plan.items) {
      final node = catalog.byId(item.nodeId);
      if (node != null) done += _doneUnder(node, catalog, fold, asOf, layers);
    }
    if (plan.items.isEmpty) {
      for (final assignment in plan.assignments) {
        final id = assignment.targetNodeId;
        final node = id == null ? null : catalog.byId(id);
        if (node != null) {
          done += _doneUnder(node, catalog, fold, asOf, layers);
        }
      }
    }
    return done;
  }

  /// Where [plan] has got to as of [asOf].
  ///
  /// With [LearningPlan.flowsToNextItem] off, a finished first item ends the plan
  /// — the position reports complete rather than advancing, which is the
  /// difference between "I listed four seferim" and "work through these four".
  ///
  /// An item whose node is not in the catalog is skipped rather than fatal: a
  /// custom node can be deleted out from under a plan, and the plan must keep
  /// opening.
  static PlanPosition positionOn(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day asOf, {
    LayerRoles? layers,
  }) {
    final remaining = (totalUnits(plan, catalog) -
            doneUnits(plan, catalog, fold, asOf, layers: layers))
        .clamp(0, 1 << 62);

    if (plan.items.isEmpty) {
      // No sequence: the first assignment target with anything owing.
      for (final assignment in plan.assignments) {
        final id = assignment.targetNodeId;
        final node = id == null ? null : catalog.byId(id);
        if (node == null) continue;
        final next = nextUnitUnder(node, catalog, fold,
            layers: layers, asOf: asOf);
        if (next != null) {
          return PlanPosition(
            itemIndex: -1,
            itemId: null,
            nodeId: node.id,
            unitNodeId: next.$1.id,
            unitIndex: next.$2,
            remaining: remaining,
          );
        }
      }
      return PlanPosition(
        itemIndex: -1,
        itemId: null,
        nodeId: null,
        unitNodeId: null,
        unitIndex: null,
        remaining: remaining,
      );
    }

    for (var i = 0; i < plan.items.length; i++) {
      final item = plan.items[i];
      final node = catalog.byId(item.nodeId);
      if (node == null) continue;
      final next = nextUnitUnder(node, catalog, fold,
          layers: layers, asOf: asOf);
      if (next == null) {
        if (plan.flowsToNextItem) continue;
        // Stopped at the end of this item, by choice.
        return PlanPosition(
          itemIndex: i,
          itemId: item.id,
          nodeId: node.id,
          unitNodeId: null,
          unitIndex: null,
          remaining: remaining,
        );
      }
      return PlanPosition(
        itemIndex: i,
        itemId: item.id,
        nodeId: node.id,
        unitNodeId: next.$1.id,
        unitIndex: next.$2,
        remaining: remaining,
      );
    }

    // Every item is done — either the sequence ran out, or the first item
    // finished and we are not flowing on. Both read the same to the learner: the
    // plan is finished.
    return PlanPosition(
      itemIndex: plan.items.length,
      itemId: null,
      nodeId: null,
      unitNodeId: null,
      unitIndex: null,
      remaining: remaining,
    );
  }

  /// The layers a unit must carry at [nodeId]. With no roles configured, the main
  /// layer alone — the same default `PlanCompletion` uses, so a plan cannot be
  /// "complete" here while `PlanCompletion` says otherwise.
  static Set<String> _requiredFor(LayerRoles? layers, String nodeId) =>
      layers?.requiredFor(nodeId) ?? {mainLayerId};

  static int _unitsUnder(CatalogNode node, Catalog catalog) {
    if (node.isLeaf) return node.unitCount;
    var total = 0;
    for (final leaf in catalog.leavesUnder(node.id)) {
      total += leaf.unitCount;
    }
    return total;
  }

  static int _doneUnder(
    CatalogNode node,
    Catalog catalog,
    LogFold fold,
    Day asOf,
    LayerRoles? layers,
  ) {
    var done = 0;
    for (final leaf in catalog.leavesUnder(node.id)) {
      final required = _requiredFor(layers, leaf.id);
      for (var unit = leaf.unitOffset;
          unit < leaf.unitOffset + leaf.unitCount;
          unit++) {
        final at = fold.doneAt(leaf.id, unit);
        if (at == null || Day.of(at) >= asOf) continue;
        if (required.every(fold.completedLayers(leaf.id, unit).contains)) done++;
      }
    }
    return done;
  }
}
