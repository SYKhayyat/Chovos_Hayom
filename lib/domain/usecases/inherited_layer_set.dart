/// A sparse, inherited set of layer ids resolved per node (and optionally per
/// unit). This is the shared engine behind both the *required* set (what a unit
/// needs to count as done) and the *offered* set (what a unit lets you check off
/// at all) — the two are the same shape and inheritance rules, only their
/// meaning and default differ.
///
/// Configuration is sparse: a set can be pinned at any node (usually high — a
/// whole Shas or a mesechta) and applies to every descendant unless a nearer
/// node, or the unit itself, overrides it. When nothing is configured anywhere
/// the answer is [defaultSet].
///
/// Node-level resolution is memoized, so a full rollup stays O(nodes), not
/// O(nodes × depth).
class InheritedLayerSet {
  InheritedLayerSet({
    this.nodeConfig = const {},
    this.unitConfig = const {},
    this.parentOf = const {},
    required this.defaultSet,
  });

  /// nodeId -> the set pinned at that node (empty means "revert to default").
  final Map<String, Set<String>> nodeConfig;

  /// nodeId -> (unit index -> per-unit override set).
  final Map<String, Map<int, Set<String>>> unitConfig;

  /// nodeId -> parent id, for walking inheritance upward.
  final Map<String, String?> parentOf;

  /// The answer when nothing is configured on a node or any ancestor.
  final Set<String> defaultSet;

  final Map<String, Set<String>> _nodeCache = {};

  /// The set that applies to [nodeId] at node level (inherited from ancestors).
  Set<String> forNode(String nodeId) {
    final cached = _nodeCache[nodeId];
    if (cached != null) return cached;

    Set<String> resolved;
    final own = nodeConfig[nodeId];
    if (own != null) {
      // An explicitly-empty pin means "reset to the default here", not "nothing".
      resolved = own.isEmpty ? defaultSet : own;
    } else {
      final parent = parentOf[nodeId];
      resolved = parent != null ? forNode(parent) : defaultSet;
    }
    _nodeCache[nodeId] = resolved;
    return resolved;
  }

  /// The set for a specific unit — a per-unit override if present, otherwise the
  /// node-level (inherited) set.
  Set<String> forUnit(String nodeId, int unitIndex) {
    final override = unitConfig[nodeId]?[unitIndex];
    if (override != null) return override.isEmpty ? defaultSet : override;
    return forNode(nodeId);
  }
}
