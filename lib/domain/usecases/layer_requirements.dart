import '../entities/layer.dart';

/// A stored required-layer setting: the layers pinned at [nodeId], for a single
/// [unitIndex] override or, when [unitIndex] is -1, the node-level default.
class LayerRequirementEntry {
  const LayerRequirementEntry({
    required this.nodeId,
    required this.unitIndex,
    required this.layers,
  });

  final String nodeId;
  final int unitIndex; // -1 == node level
  final Set<String> layers;

  bool get isNodeLevel => unitIndex < 0;

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'unitIndex': unitIndex,
        'layers': layers.toList(),
      };

  factory LayerRequirementEntry.fromJson(Map<String, dynamic> json) =>
      LayerRequirementEntry(
        nodeId: json['nodeId'] as String,
        unitIndex: (json['unitIndex'] as num?)?.toInt() ?? -1,
        layers: {for (final l in (json['layers'] as List? ?? [])) l as String},
      );
}

/// Resolves which layers are *required* for a unit to count as complete.
///
/// Configuration is sparse and inherited: a required set can be pinned at any
/// node (usually high — a whole Shas or a mesechta) and applies to every
/// descendant unless a nearer node, or the unit itself, overrides it. When
/// nothing is configured anywhere the answer is `{main}` — the text alone —
/// which is exactly the pre-layers behaviour, so existing progress is preserved.
///
/// Node-level resolution is memoized, so a full rollup stays O(nodes), not
/// O(nodes × depth).
class LayerRequirements {
  LayerRequirements({
    this.nodeConfig = const {},
    this.unitConfig = const {},
    this.parentOf = const {},
  });

  final Map<String, Set<String>> nodeConfig;
  final Map<String, Map<int, Set<String>>> unitConfig;
  final Map<String, String?> parentOf;
  final Map<String, Set<String>> _nodeCache = {};

  static const _defaultRequired = <String>{mainLayerId};

  /// The required layer set that applies to [nodeId] (node level, inherited).
  Set<String> forNode(String nodeId) {
    final cached = _nodeCache[nodeId];
    if (cached != null) return cached;

    Set<String> resolved;
    final own = nodeConfig[nodeId];
    if (own != null) {
      resolved = own.isEmpty ? _defaultRequired : own;
    } else {
      final parent = parentOf[nodeId];
      resolved = parent != null ? forNode(parent) : _defaultRequired;
    }
    _nodeCache[nodeId] = resolved;
    return resolved;
  }

  /// The required set for a specific unit — a per-unit override if present,
  /// otherwise the node-level set.
  Set<String> forUnit(String nodeId, int unitIndex) {
    final override = unitConfig[nodeId]?[unitIndex];
    if (override != null) return override.isEmpty ? _defaultRequired : override;
    return forNode(nodeId);
  }

  /// True when this unit needs more than just the primary text — i.e. the UI
  /// should show per-layer controls rather than a plain done toggle.
  bool hasLayers(String nodeId, int unitIndex) {
    final req = forUnit(nodeId, unitIndex);
    return req.length > 1 || !req.contains(mainLayerId);
  }
}
