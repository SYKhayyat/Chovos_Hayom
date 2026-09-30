import '../../core/day.dart';
import '../entities/catalog.dart';
import '../entities/catalog_node.dart';
import '../entities/layer.dart';
import 'fold_log.dart';
import 'layer_roles.dart';
import 'learning_plan.dart';

/// The units one sefer of a plan actually covers, once the item's bounds have
/// been applied to what the catalog says the sefer has.
///
/// **A range is an interval over a sefer's own unit numbering**, so it is
/// resolved against the catalog rather than trusted: a range of 2-25 on a sefer
/// whose units run 2..6 is a range the sefer cannot supply, and answering it
/// with something in range would be a setting the user believes is in force
/// that silently covers the wrong units.
class PlanRange {
  const PlanRange({
    required this.node,
    required this.first,
    required this.last,
    required this.wraps,
  });

  /// The sefer this range is inside. Carried because a range over a *category*
  /// spans every leaf under it, and callers need to know what they are walking.
  final CatalogNode node;

  /// First unit covered, inclusive.
  final int first;

  /// Last unit covered, inclusive.
  final int last;

  /// Whether reaching [last] returns to [first] rather than ending the run.
  final bool wraps;

  /// How many units one pass over this range covers. Zero for an empty range,
  /// which is a range whose bounds do not meet rather than an infinite one.
  int get length => last >= first ? last - first + 1 : 0;

  /// The units of this range, ascending. Generated, never materialised beyond
  /// the range itself.
  Iterable<int> get units => [for (var u = first; u <= last; u++) u];

  /// The units of this range when [node] is a leaf; otherwise every unit of
  /// every leaf under it, in catalog order.
  ///
  /// **A category item is one step, not one per leaf** — "Yoma, Sukkah, Chagigah,
  /// then Moed" means Moed is a single step, and expanding it would make the
  /// chain unreadable and the total wrong to read.
  Iterable<(CatalogNode, int)> walk(Catalog catalog) sync* {
    if (node.isLeaf) {
      for (final u in units) {
        yield (node, u);
      }
      return;
    }
    for (final leaf in catalog.leavesUnder(node.id)) {
      for (var u = leaf.unitOffset; u < leaf.unitOffset + leaf.unitCount; u++) {
        yield (leaf, u);
      }
    }
  }

  /// The range for item [index] of [plan], or null when the plan has no such
  /// item or its node is not in the catalog.
  ///
  /// Null for a deleted node rather than fatal: a custom sefer can be removed
  /// out from under a plan, and the plan must keep opening.
  static PlanRange? resolve(LearningPlan plan, Catalog catalog, int index) {
    if (index < 0 || index >= plan.items.length) return null;
    final item = plan.items[index];
    final node = catalog.byId(item.nodeId);
    if (node == null) return null;
    final naturalFirst = _firstUnitOf(node, catalog);
    final naturalLast = _lastUnitOf(node, catalog);
    final first = item.startUnit ?? naturalFirst;
    final last = item.endUnit ?? naturalLast;
    // **Clamped against this sefer's own numbering, not against 1.** Units are
    // numbered from wherever the sefer starts — Bavli from 2, Yerushalmi from
    // 1 — so a stored range below the sefer's first unit covers a unit that does
    // not exist. Clamping it to the first real unit would quietly cover units
    // the user did not ask for, which is the failure this feature is most able
    // to produce: a setting that reads as in force and is not.
    if (first < naturalFirst) {
      throw FormatException(
          'startUnit $first is below ${node.name}\'s first unit '
          '($naturalFirst)');
    }
    if (last < first) {
      throw FormatException(
          'endUnit ($last) is before startUnit ($first)');
    }
    return PlanRange(node: node, first: first, last: last, wraps: item.wrapsRange);
  }

  /// The sefer's own first unit — the node's offset for a leaf, and the earliest
  /// offset among its leaves for a category.
  static int _firstUnitOf(CatalogNode node, Catalog catalog) {
    if (node.isLeaf) return node.unitOffset;
    var first = 1 << 62;
    for (final leaf in catalog.leavesUnder(node.id)) {
      if (leaf.unitOffset < first) first = leaf.unitOffset;
    }
    return first;
  }

  static int _lastUnitOf(CatalogNode node, Catalog catalog) {
    if (node.isLeaf) return node.unitOffset + node.unitCount - 1;
    var last = 0;
    for (final leaf in catalog.leavesUnder(node.id)) {
      final end = leaf.unitOffset + leaf.unitCount - 1;
      if (end > last) last = end;
    }
    return last;
  }

  @override
  bool operator ==(Object other) =>
      other is PlanRange &&
      other.node.id == node.id &&
      other.first == first &&
      other.last == last &&
      other.wraps == wraps;

  @override
  int get hashCode => Object.hash(node.id, first, last, wraps);

  @override
  String toString() => 'PlanRange(${node.id} $first..$last, wraps: $wraps)';
}

/// Progress **within** one sefer's range, and the totals that go with it.
///
/// **This is a fold reader, not a schedule.** It answers "what has been done",
/// which the log is the only authority on. What a day *asks* for is
/// [PlannerSchedule]'s business, and the two meet in the projection —
/// deliberately kept apart so neither can drift into being the other's answer.
///
/// **There is no lap counter in here, on purpose.** A wrapping range is
/// infinite, so "which round am I on" has nothing to be a fraction of and
/// nothing to be useful for: the position is the first unit not marked done, and
/// once they are all done it is the start of the range again. Progress on such
/// a plan is a bare count of units done (see [totalUnits] returning null), and
/// learning a unit twice is recorded on the unit, not here.
class PlanRunProgress {
  const PlanRunProgress._();

  /// How many units [plan] covers, or **null when it has no total** — an open
  /// range, or one that wraps.
  ///
  /// Null and not zero, and the difference is the whole point: zero is "there is
  /// nothing to do", which is a different statement from "there is no end to
  /// count to". Only a finite plan can be reported as a fraction, and inventing
  /// a denominator for an endless one is the kind of number this repository's
  /// rules exist to stop.
  static int? totalUnits(LearningPlan plan, Catalog catalog) {
    var total = 0;
    var any = false;
    for (var i = 0; i < plan.items.length; i++) {
      final range = PlanRange.resolve(plan, catalog, i);
      if (range == null) continue;
      any = true;
      if (range.wraps) return null;
      total += _rangeUnits(range, catalog);
    }
    if (!any) return null;
    return total;
  }

  /// Units already done across the whole of [plan], counted only if actually
  /// done **before** [asOf].
  ///
  /// **A count, never a fraction.** This is the whole of progress for an
  /// infinite plan, and it counts each unit once however many times it was
  /// learned: a unit re-learned is a fact the unit grid shows as "learnt twice",
  /// and counting it twice here would make a plan's count drift above the range
  /// it covers.
  static int doneUnits(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day asOf, {
    LayerRoles? layers,
  }) {
    var done = 0;
    for (var i = 0; i < plan.items.length; i++) {
      done += doneInRange(plan, catalog, fold, asOf, i, layers: layers);
    }
    return done;
  }

  /// The units of item [index]'s range, counted only if actually done **before**
  /// [asOf].
  ///
  /// A unit learned *on* [asOf] has not been done *by* [asOf], and treating it
  /// as done would let a plan report itself finished on the day it finishes.
  static int doneInRange(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day asOf,
    int index, {
    LayerRoles? layers,
  }) {
    final range = PlanRange.resolve(plan, catalog, index);
    if (range == null) return 0;
    var done = 0;
    for (final (node, unit) in range.walk(catalog)) {
      // **Per node, not once for the range.** A required set is a fact about the
      // node — a mesechta can demand mefarshim where the next one does not — so
      // resolving it once against an arbitrary node id makes every unit in a
      // multi-leaf range answer the wrong question. It is also the same default
      // `PlanCompletion` uses, so a unit cannot be "done" here and owed there.
      final required = layers?.requiredFor(node.id) ?? {mainLayerId};
      final at = fold.doneAt(node.id, unit);
      if (at == null || Day.of(at) >= asOf) continue;
      if (required.every(fold.completedLayers(node.id, unit).contains)) done++;
    }
    return done;
  }

  /// **The whole of #41's position rule**, in one function: the first unit in
  /// the range not marked done, or — when they are all done — the start of the
  /// range if it wraps, and **null** if it does not.
  ///
  /// Null for a finished non-wrapping range is the answer, not a gap. Such a
  /// plan is finished, and quietly starting it over would be the one thing the
  /// wrap setting exists to let the user choose.
  ///
  /// Which is why a wrapped range and an unwrapped one answer the same log
  /// differently, and why the log needs no lap: the rule only ever asks what is
  /// *not done*, and learning a unit a second time does not change that.
  static int? unitOn(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day asOf, {
    LayerRoles? layers,
  }) =>
      unitInRange(plan, catalog, fold, asOf, 0, layers: layers);

  /// As [unitOn], but for item [index] of the chain.
  static int? unitInRange(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day asOf,
    int index, {
    LayerRoles? layers,
  }) {
    final range = PlanRange.resolve(plan, catalog, index);
    if (range == null) return null;
    if (range.node.isLeaf) {
      final required = _requiredFor(layers, range.node.id);
      for (var u = range.first; u <= range.last; u++) {
        if (!_isDone(fold, range.node.id, u, asOf, required)) return u;
      }
      return range.wraps ? range.first : null;
    }
    for (final (node, unit) in range.walk(catalog)) {
      if (!_isDone(fold, node.id, unit, asOf, _requiredFor(layers, node.id))) {
        return unit;
      }
    }
    return range.wraps ? range.first : null;
  }

  /// Whether [unit] of [nodeId] was done **by** [asOf].
  ///
  /// The date check is inside rather than around the loop so a unit learned
  /// today is still owed today — the rule that stops a plan reporting itself
  /// finished on the day it finishes.
  static bool _isDone(
    LogFold fold,
    String nodeId,
    int unit,
    Day asOf,
    Set<String> required,
  ) {
    if (!required.every(fold.completedLayers(nodeId, unit).contains)) {
      return false;
    }
    final at = fold.doneAt(nodeId, unit);
    return at != null && Day.of(at) < asOf;
  }

  static int _rangeUnits(PlanRange range, Catalog catalog) =>
      range.node.isLeaf ? range.length : range.walk(catalog).length;

  static Set<String> _requiredFor(LayerRoles? layers, String nodeId) =>
      layers?.requiredFor(nodeId) ?? {mainLayerId};
}
