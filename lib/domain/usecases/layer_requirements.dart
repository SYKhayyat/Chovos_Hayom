import '../entities/layer.dart';
import 'inherited_layer_set.dart';

/// A stored layer-set setting: the layers pinned at [nodeId], for a single
/// [unitIndex] override or, when [unitIndex] is -1, the node-level default.
///
/// The same shape backs both the *required* set and the *offered* set — they
/// differ only in which table/list they live in and what they mean, so one
/// entry type serves both.
class LayerConfigEntry {
  const LayerConfigEntry({
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

  factory LayerConfigEntry.fromJson(Map<String, dynamic> json) =>
      LayerConfigEntry(
        nodeId: json['nodeId'] as String,
        unitIndex: (json['unitIndex'] as num?)?.toInt() ?? -1,
        layers: {for (final l in (json['layers'] as List? ?? [])) l as String},
      );
}

/// Legacy name kept so existing call sites and imports keep compiling. The
/// entry is not requirement-specific; new code should prefer [LayerConfigEntry].
typedef LayerRequirementEntry = LayerConfigEntry;

/// Resolves which layers are *required* for a unit to count as complete.
///
/// A thin, semantic wrapper over [InheritedLayerSet] whose default is `{main}` —
/// the text alone — which is exactly the pre-layers behaviour, so existing
/// progress is preserved when nothing is configured.
class LayerRequirements {
  LayerRequirements({
    Map<String, Set<String>> nodeConfig = const {},
    Map<String, Map<int, Set<String>>> unitConfig = const {},
    Map<String, String?> parentOf = const {},
  }) : _set = InheritedLayerSet(
          nodeConfig: nodeConfig,
          unitConfig: unitConfig,
          parentOf: parentOf,
          defaultSet: _defaultRequired,
        );

  final InheritedLayerSet _set;

  static const _defaultRequired = <String>{mainLayerId};

  /// The required layer set that applies to [nodeId] (node level, inherited).
  Set<String> forNode(String nodeId) => _set.forNode(nodeId);

  /// The required set for a specific unit — a per-unit override if present,
  /// otherwise the node-level set.
  Set<String> forUnit(String nodeId, int unitIndex) =>
      _set.forUnit(nodeId, unitIndex);

  /// True when this unit needs more than just the primary text — i.e. its
  /// *required* set alone already implies layered controls. Whether the UI shows
  /// a checklist also depends on the *offered* set (see [UnitLayerView]).
  bool hasLayers(String nodeId, int unitIndex) {
    final req = forUnit(nodeId, unitIndex);
    return req.length > 1 || !req.contains(mainLayerId);
  }
}
