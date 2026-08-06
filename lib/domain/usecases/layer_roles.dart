import '../entities/layer.dart';
import 'fold_log.dart';
import 'inherited_layer_roles.dart';

/// A stored layer setting: the roles pinned at [nodeId], for a single
/// [unitIndex] override or, when [unitIndex] is -1, the node-level default.
///
/// One entry carries the whole answer for that node — which mefarshim are
/// checkable and which of those gate completion. It used to take two entries in
/// two tables, and a node could end up with one of them and not the other (the
/// meforish-delete cascade did exactly that whenever one set emptied out and the
/// other didn't). There is one entry now, so there is nothing to half-write.
class LayerConfigEntry {
  const LayerConfigEntry({
    required this.nodeId,
    required this.unitIndex,
    required this.roles,
  });

  final String nodeId;
  final int unitIndex; // -1 == node level
  final Map<String, LayerRole> roles;

  bool get isNodeLevel => unitIndex < 0;

  /// Every layer that may be ticked here — optional and required alike.
  Set<String> get checkable => roles.keys.toSet();

  /// Only the layers that gate completion.
  Set<String> get required => {
        for (final e in roles.entries)
          if (e.value == LayerRole.required) e.key,
      };

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'unitIndex': unitIndex,
        'roles': {for (final e in roles.entries) e.key: e.value.name},
      };

  /// Reads both the current shape and the two legacy ones.
  ///
  /// Backups written before the collapse carried a bare `layers` list in two
  /// separate arrays — `requirements` and `offered` — where membership was the
  /// whole meaning. [legacyRole] says which array this entry came out of, so the
  /// list can be read back as roles; [BackupData] then merges the two arrays by
  /// (node, unit). Without this an old backup would silently import as
  /// everything-optional and quietly un-complete the user's tree.
  factory LayerConfigEntry.fromJson(
    Map<String, dynamic> json, {
    LayerRole legacyRole = LayerRole.required,
  }) {
    final rawRoles = json['roles'];
    final roles = <String, LayerRole>{};
    if (rawRoles is Map) {
      for (final e in rawRoles.entries) {
        roles['${e.key}'] = LayerRole.fromName(e.value as String?);
      }
    } else {
      for (final l in (json['layers'] as List? ?? const [])) {
        roles[l as String] = legacyRole;
      }
    }
    return LayerConfigEntry(
      nodeId: json['nodeId'] as String,
      unitIndex: (json['unitIndex'] as num?)?.toInt() ?? -1,
      roles: roles,
    );
  }

  /// This entry with [layerId] removed, or null when nothing would be left —
  /// which the caller should treat as "clear the setting", so the node falls
  /// back to inheritance rather than being pinned to an empty map.
  LayerConfigEntry? without(String layerId) {
    if (!roles.containsKey(layerId)) return this;
    final remaining = {...roles}..remove(layerId);
    if (remaining.isEmpty) return null;
    return LayerConfigEntry(
        nodeId: nodeId, unitIndex: unitIndex, roles: remaining);
  }
}

/// The single place every layer question is answered: what may be ticked on a
/// unit, what gates its completion, how full its bar is, and where the answer
/// was pinned.
///
/// This replaces three classes — `LayerRequirements`, `OfferedLayers` and the
/// `UnitLayerView` that existed to reconcile them. The first two were the same
/// forty lines with one word search-replaced, over the same engine, with the
/// same default; the third was the tax for having two. The reconciliation they
/// needed (`checkable = offered ∪ required`) was also written out by hand at
/// three call sites that never went through `UnitLayerView` at all, and those
/// are the ones that would have disagreed.
class LayerRoles {
  LayerRoles({
    Map<String, Map<String, LayerRole>> nodeConfig = const {},
    Map<String, Map<int, Map<String, LayerRole>>> unitConfig = const {},
    Map<String, String?> parentOf = const {},
  }) : _set = InheritedLayerRoles(
          nodeConfig: nodeConfig,
          unitConfig: unitConfig,
          parentOf: parentOf,
        );

  /// Build the resolver from stored entries — the shape both the repository and
  /// a backup hold them in.
  ///
  /// The provider used to split entries into node/unit maps inline, and so did
  /// anything else that needed a resolver for a *different* set of entries than
  /// the live one (the restore preview, which has to answer "what will be marked
  /// once these settings land"). Two copies of one transformation is how a
  /// preview and an outcome come to disagree, so there is one.
  factory LayerRoles.fromEntries(
    Iterable<LayerConfigEntry> entries, {
    Map<String, String?> parentOf = const {},
  }) {
    final nodeConfig = <String, Map<String, LayerRole>>{};
    final unitConfig = <String, Map<int, Map<String, LayerRole>>>{};
    for (final e in entries) {
      if (e.isNodeLevel) {
        nodeConfig[e.nodeId] = e.roles;
      } else {
        (unitConfig[e.nodeId] ??= {})[e.unitIndex] = e.roles;
      }
    }
    return LayerRoles(
        nodeConfig: nodeConfig, unitConfig: unitConfig, parentOf: parentOf);
  }

  final InheritedLayerRoles _set;

  /// The full role map that applies to [nodeId] (node level, inherited).
  Map<String, LayerRole> forNode(String nodeId) => _set.forNode(nodeId);

  /// The full role map for a specific unit — a per-unit override if present,
  /// otherwise the node-level map.
  Map<String, LayerRole> forUnit(String nodeId, int unitIndex) =>
      _set.forUnit(nodeId, unitIndex);

  /// Layers that gate completion for this unit.
  Set<String> requiredFor(String nodeId, int unitIndex) =>
      _required(forUnit(nodeId, unitIndex));

  /// Every layer that may be checked off on this unit.
  Set<String> checkableFor(String nodeId, int unitIndex) =>
      forUnit(nodeId, unitIndex).keys.toSet();

  /// Layers that gate completion at node level (inherited).
  Set<String> requiredForNode(String nodeId) => _required(forNode(nodeId));

  /// Every layer checkable anywhere under [nodeId] by default — what a node-wide
  /// action (the bulk sheet, the per-meforish bars) should offer.
  Set<String> checkableForNode(String nodeId) => forNode(nodeId).keys.toSet();

  /// The nearest node ([nodeId] or an ancestor) with an explicit pin, or null
  /// when the answer is the default. See [InheritedLayerRoles].
  String? pinnedSource(String nodeId) => _set.pinnedSource(nodeId);

  /// True when the unit should present a per-layer checklist rather than a plain
  /// one-tap toggle — i.e. it offers more than just the text.
  bool isLayered(String nodeId, int unitIndex) {
    final checkable = forUnit(nodeId, unitIndex);
    return checkable.length > 1 || !checkable.containsKey(mainLayerId);
  }

  /// Fraction (0..1) of *required* layers already learned — drives the grid's
  /// partial fill. Optional layers never inflate this.
  double fraction(String nodeId, int unitIndex, LogFold fold) {
    final req = requiredFor(nodeId, unitIndex);
    if (req.isEmpty) return 0;
    final have = fold.completedLayers(nodeId, unitIndex);
    return req.where(have.contains).length / req.length;
  }

  static Set<String> _required(Map<String, LayerRole> roles) => {
        for (final e in roles.entries)
          if (e.value == LayerRole.required) e.key,
      };
}
