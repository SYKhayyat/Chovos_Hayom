import '../entities/catalog.dart';
import '../entities/catalog_node.dart';
import '../entities/layer.dart';
import 'fold_log.dart';
import 'layer_roles.dart';
import 'learning_plan.dart';
import '../../core/day.dart';

class PlanCompletion {
  const PlanCompletion._();

  static bool nodeCompleteBefore(
    CatalogNode node,
    Catalog catalog,
    LogFold fold,
    Day day, {
    LayerRoles? layers,
  }) {
    final leaves = catalog.leavesUnder(node.id).toList();
    if (leaves.isEmpty) return false;
    for (final leaf in leaves) {
      final required = layers?.requiredFor(leaf.id) ?? {mainLayerId};
      for (var unit = leaf.unitOffset;
          unit < leaf.unitOffset + leaf.unitCount;
          unit++) {
        final completed = fold.completedLayers(leaf.id, unit);
        if (!required.every(completed.contains)) return false;
        final doneAt = fold.doneAt(leaf.id, unit);
        if (doneAt == null || Day.of(doneAt) >= day) return false;
      }
    }
    return true;
  }

  static bool hasProgress(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day day, {
    LayerRoles? layers,
  }) {
    for (final assignment in plan.assignments) {
      final targetId = assignment.targetNodeId;
      if (targetId == null) continue;
      final target = catalog.byId(targetId);
      if (target == null) continue;
      for (final leaf in catalog.leavesUnder(target.id)) {
        final required = layers?.requiredFor(leaf.id) ?? {mainLayerId};
        for (var unit = leaf.unitOffset;
            unit < leaf.unitOffset + leaf.unitCount;
            unit++) {
          final doneAt = fold.doneAt(leaf.id, unit);
          if (doneAt != null &&
              Day.of(doneAt) < day &&
              required.every(fold.completedLayers(leaf.id, unit).contains)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static bool completeBefore(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day day, {
    LayerRoles? layers,
  }) {
    if (plan.assignments.isEmpty) return false;
    for (final assignment in plan.assignments) {
      final targetId = assignment.targetNodeId;
      if (targetId == null) return false;
      final target = catalog.byId(targetId);
      if (target == null ||
          !nodeCompleteBefore(target, catalog, fold, day, layers: layers)) {
        return false;
      }
    }
    return true;
  }
}
