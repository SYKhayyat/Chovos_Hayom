import '../entities/layer.dart';
import 'inherited_layer_set.dart';

/// Resolves which layers are *offered* on a unit — the mefarshim you may check
/// off there, independent of whether they gate completion.
///
/// This is deliberately separate from `LayerRequirements`: adding a meforish to
/// the offered set makes it checkable everywhere under a node **without** making
/// it part of the definition of done. A thin, semantic wrapper over
/// [InheritedLayerSet] with the same `{main}` default, so an unconfigured unit
/// offers exactly the text — the pre-layers behaviour.
class OfferedLayers {
  OfferedLayers({
    Map<String, Set<String>> nodeConfig = const {},
    Map<String, Map<int, Set<String>>> unitConfig = const {},
    Map<String, String?> parentOf = const {},
  }) : _set = InheritedLayerSet(
          nodeConfig: nodeConfig,
          unitConfig: unitConfig,
          parentOf: parentOf,
          defaultSet: _defaultOffered,
        );

  final InheritedLayerSet _set;

  static const _defaultOffered = <String>{mainLayerId};

  /// The offered layer set that applies to [nodeId] (node level, inherited).
  Set<String> forNode(String nodeId) => _set.forNode(nodeId);

  /// The offered set for a specific unit — a per-unit override if present,
  /// otherwise the node-level set.
  Set<String> forUnit(String nodeId, int unitIndex) =>
      _set.forUnit(nodeId, unitIndex);
}
