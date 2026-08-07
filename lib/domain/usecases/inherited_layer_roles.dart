import '../entities/layer.dart';

/// A sparse, inherited map of layer id -> [LayerRole], resolved per node (and
/// optionally per unit). This is the engine behind every layer question the app
/// asks: what may be ticked here, and what has to be ticked for the unit to
/// count.
///
/// It used to resolve a bare `Set<String>`, and was instantiated twice — once
/// for the *required* set and once for the *offered* set, with the same default
/// both times. Two resolvers over the same tree can be pinned at different
/// depths, which is how a node came to require a meforish it did not offer. One
/// resolver over a role map cannot: a layer's role is one answer, pinned in one
/// place.
///
/// Configuration is sparse: a map can be pinned at any node (usually high — a
/// whole Shas or a mesechta) and applies to every descendant unless a nearer
/// node, or the unit itself, overrides it. When nothing is configured anywhere
/// the answer is [defaultRoles].
///
/// Node-level resolution is memoized, so a full rollup stays O(nodes), not
/// O(nodes × depth).
class InheritedLayerRoles {
  InheritedLayerRoles({
    this.nodeConfig = const {},
    this.unitConfig = const {},
    this.parentOf = const {},
    this.defaultRoles = defaultLayerRoles,
  });

  /// nodeId -> the roles pinned at that node (empty means "revert to default").
  final Map<String, Map<String, LayerRole>> nodeConfig;

  /// nodeId -> (unit index -> per-unit override).
  final Map<String, Map<int, Map<String, LayerRole>>> unitConfig;

  /// nodeId -> parent id, for walking inheritance upward.
  final Map<String, String?> parentOf;

  /// The answer when nothing is configured on a node or any ancestor.
  final Map<String, LayerRole> defaultRoles;

  final Map<String, Map<String, LayerRole>> _nodeCache = {};

  /// The roles that apply to [nodeId] at node level (inherited from ancestors).
  ///
  /// Walks upward iteratively and refuses to visit a node twice. A parent cycle
  /// would otherwise loop forever — an unrecoverable hang on every rebuild, from
  /// data that is merely wrong.
  ///
  /// [Catalog] guarantees the relation it hands out cannot loop, and that covers
  /// every production read of this class but one: the restore preview builds a
  /// `parentOf` map **by hand**, from the merged catalog with a backup's rows
  /// laid over it, in order to show what the tree *will* look like before any of
  /// it is written (`settings_screen.dart`). That map has never been through a
  /// [Catalog], and it is exactly the case a hand-edited file can bend. So the
  /// guard stays, and its reason is that one call site rather than a general
  /// suspicion of the data.
  Map<String, LayerRole> forNode(String nodeId) {
    final cached = _nodeCache[nodeId];
    if (cached != null) return cached;

    // The chain from nodeId up to whatever answers, so each link can be
    // memoized with the same answer on the way back down.
    final chain = <String>[];
    final seen = <String>{};
    var current = nodeId;
    Map<String, LayerRole>? resolved;

    while (true) {
      final memo = _nodeCache[current];
      if (memo != null) {
        resolved = memo;
        break;
      }
      if (!seen.add(current)) {
        // A cycle: nothing above it can answer, so fall back to the default.
        resolved = defaultRoles;
        break;
      }
      chain.add(current);

      final own = nodeConfig[current];
      if (own != null) {
        // An explicitly-empty pin means "reset to the default here", not
        // "nothing".
        resolved = own.isEmpty ? defaultRoles : own;
        break;
      }
      final parent = parentOf[current];
      if (parent == null) {
        resolved = defaultRoles;
        break;
      }
      current = parent;
    }

    for (final id in chain) {
      _nodeCache[id] = resolved;
    }
    return resolved;
  }

  /// The nearest node — [nodeId] itself or an ancestor — that carries an
  /// explicit node-level pin, or null when nothing is configured anywhere up the
  /// chain (so the answer is the pure [defaultRoles]). Cycle-guarded like
  /// [forNode].
  ///
  /// Lets the UI tell "set here" from "inherited from Shas" from "default", so a
  /// config sheet doesn't silently pin an inherited answer as a node-level
  /// override the moment it opens.
  String? pinnedSource(String nodeId) {
    final seen = <String>{};
    var current = nodeId;
    while (true) {
      if (!seen.add(current)) return null;
      if (nodeConfig.containsKey(current)) return current;
      final parent = parentOf[current];
      if (parent == null) return null;
      current = parent;
    }
  }

  /// The roles for a specific unit — a per-unit override if present, otherwise
  /// the node-level (inherited) answer.
  Map<String, LayerRole> forUnit(String nodeId, int unitIndex) {
    final override = unitConfig[nodeId]?[unitIndex];
    if (override != null) return override.isEmpty ? defaultRoles : override;
    return forNode(nodeId);
  }
}
