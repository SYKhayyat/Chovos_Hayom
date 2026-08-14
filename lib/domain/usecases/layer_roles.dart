import '../entities/layer.dart';
import 'fold_log.dart';
import 'inherited_layer_roles.dart';

/// A stored layer setting: the roles pinned at [nodeId].
///
/// One entry carries the whole answer for that node — which mefarshim are
/// checkable and which of those gate completion. It used to take two entries in
/// two tables, and a node could end up with one of them and not the other (the
/// meforish-delete cascade did exactly that whenever one set emptied out and the
/// other didn't). There is one entry now, so there is nothing to half-write.
///
/// It also used to carry a `unitIndex`, so that a setting could be pinned on a
/// single unit rather than a node. Nothing ever wrote one: the config sheet is
/// the only writer and it is opened from a node, so `-1` — the node-level
/// sentinel — was the only value the column ever held, in the schema, in the
/// resolver, in the backup format and in every method that took a scope. A
/// dimension that only ever has one value is not a feature that hasn't shipped;
/// it is three layers agreeing to carry a constant. Pinning a meforish on one
/// daf of a mesechta is a real thing to want, and if it is ever wanted it wants
/// a UI, a story for what a chazara against it means, and a resolver test —
/// none of which the dead column was ever going to supply.
class LayerConfigEntry {
  const LayerConfigEntry({
    required this.nodeId,
    required this.roles,
  });

  final String nodeId;
  final Map<String, LayerRole> roles;

  /// Every layer that may be ticked here — optional and required alike.
  Set<String> get checkable => roles.keys.toSet();

  /// Only the layers that gate completion.
  Set<String> get required => {
        for (final e in roles.entries)
          if (e.value == LayerRole.required) e.key,
      };

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'roles': {for (final e in roles.entries) e.key: e.value.name},
      };

  /// Reads the current shape and the two legacy ones.
  ///
  /// Backups written before the collapse carried a bare `layers` list in two
  /// separate arrays — `requirements` and `offered` — where membership was the
  /// whole meaning. [legacyRole] says which array this entry came out of, so the
  /// list can be read back as roles; [BackupData] then merges the two arrays by
  /// node. Without this an old backup would silently import as
  /// everything-optional and quietly un-complete the user's tree.
  ///
  /// A `unitIndex` in an older file is ignored here and the entry carrying it is
  /// dropped upstream — see `BackupService.parse`, which is where a scope this
  /// build has no room for has to be noticed rather than silently folded into
  /// its node.
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
    return LayerConfigEntry(nodeId: nodeId, roles: remaining);
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
    Map<String, String?> parentOf = const {},
  }) : _set = InheritedLayerRoles(
          nodeConfig: nodeConfig,
          parentOf: parentOf,
        );

  /// Build the resolver from stored entries — the shape both the repository and
  /// a backup hold them in.
  ///
  /// The provider used to lay the entries out into the resolver's shape inline,
  /// and so did anything else that needed a resolver for a *different* set of
  /// entries than the live one (the restore preview, which has to answer "what
  /// will be marked once these settings land"). Two copies of one transformation
  /// is how a preview and an outcome come to disagree, so there is one.
  factory LayerRoles.fromEntries(
    Iterable<LayerConfigEntry> entries, {
    Map<String, String?> parentOf = const {},
  }) =>
      LayerRoles(
        nodeConfig: {for (final e in entries) e.nodeId: e.roles},
        parentOf: parentOf,
      );

  final InheritedLayerRoles _set;
  final Map<String, Set<String>> _requiredCache = {};

  /// The full role map that applies to [nodeId], inherited from its ancestors.
  Map<String, LayerRole> forNode(String nodeId) => _set.forNode(nodeId);

  /// Layers that gate completion at [nodeId] — and therefore on every unit of
  /// it.
  ///
  /// Memoized because the callers are loops over a whole tree (the fold's
  /// per-unit completion check, the chazara schedule, a bulk mark), and
  /// [_required] builds a set each time it runs. `forNode` is memoized under it
  /// for the same reason.
  Set<String> requiredFor(String nodeId) =>
      _requiredCache[nodeId] ??= _required(forNode(nodeId));

  /// Every layer checkable under [nodeId] — what a node-wide action (the bulk
  /// sheet, the per-meforish bars) should offer.
  Set<String> checkableFor(String nodeId) => forNode(nodeId).keys.toSet();

  /// The nearest node ([nodeId] or an ancestor) with an explicit pin, or null
  /// when the answer is the default. See [InheritedLayerRoles].
  String? pinnedSource(String nodeId) => _set.pinnedSource(nodeId);

  /// True when a unit of [nodeId] should present a per-layer checklist rather
  /// than a plain one-tap toggle — i.e. it offers more than just the text.
  bool isLayered(String nodeId) {
    final checkable = forNode(nodeId);
    return checkable.length > 1 || !checkable.containsKey(mainLayerId);
  }

  /// Fraction (0..1) of *required* layers already learned on [unitIndex] —
  /// drives the grid's partial fill. Optional layers never inflate this.
  double fraction(String nodeId, int unitIndex, LogFold fold) {
    final req = requiredFor(nodeId);
    if (req.isEmpty) return 0;
    final have = fold.completedLayers(nodeId, unitIndex);
    return req.where(have.contains).length / req.length;
  }

  static Set<String> _required(Map<String, LayerRole> roles) => {
        for (final e in roles.entries)
          if (e.value == LayerRole.required) e.key,
      };
}
