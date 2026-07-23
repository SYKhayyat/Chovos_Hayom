import '../entities/layer.dart';
import 'fold_log.dart';
import 'layer_requirements.dart';
import 'offered_layers.dart';

/// The single place that reconciles the two layer sets for one unit:
///
/// - **required** — layers that gate completion (a unit is done when all are
///   learned). Drives progress, roll-ups, siyum, everything derived.
/// - **checkable** — every layer you may tick on the unit: the *offered* set
///   unioned with *required* (so a required layer is always tickable, even if a
///   lower node's offered override forgot it).
///
/// Keeping this reconciliation in one pure, testable place means the grid, the
/// per-unit sheet, and the bulk actions all agree on what "done", "layered" and
/// "checkable" mean.
class UnitLayerView {
  const UnitLayerView({required this.required, required this.offered});

  final LayerRequirements required;
  final OfferedLayers offered;

  /// Layers that gate completion for this unit.
  Set<String> requiredFor(String nodeId, int unit) =>
      required.forUnit(nodeId, unit);

  /// Every layer that may be checked off on this unit (offered ∪ required).
  Set<String> checkableFor(String nodeId, int unit) =>
      {...offered.forUnit(nodeId, unit), ...requiredFor(nodeId, unit)};

  /// True when the unit should present a per-layer checklist rather than a plain
  /// one-tap toggle — i.e. it offers more than just the text.
  bool isLayered(String nodeId, int unit) {
    final checkable = checkableFor(nodeId, unit);
    return checkable.length > 1 || !checkable.contains(mainLayerId);
  }

  /// Fraction (0..1) of *required* layers already learned — drives the grid's
  /// partial fill. Optional (offered-only) layers never inflate this.
  double fraction(String nodeId, int unit, LogFold fold) {
    final req = requiredFor(nodeId, unit);
    if (req.isEmpty) return 0;
    final have = fold.completedLayers(nodeId, unit);
    return req.where(have.contains).length / req.length;
  }
}
