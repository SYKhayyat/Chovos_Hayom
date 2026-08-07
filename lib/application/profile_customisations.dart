import '../domain/entities/catalog_node.dart';
import '../domain/entities/layer.dart';
import '../domain/repositories/progress_repository.dart';
import '../domain/usecases/layer_roles.dart';

/// Everything a profile has *made*, as opposed to everything it has learned.
///
/// Three collections that are never wanted apart — the sefarim you added or
/// edited, the mefarshim you added, and where each meforish applies — and they
/// were read as a hand-written triple at three call sites: the export, the
/// clear, and the restore's teardown.
///
/// The reason that matters is not the six duplicated lines. It is **where they
/// were read from**. All three used to come off their providers as
/// `.asData?.value ?? const []`, and a provider still in flight — or one nothing
/// on the screen keeps alive — reads as an *empty list*. That is invisible in a
/// list ("nothing yet", corrected next frame) and a silent lie anywhere a
/// decision is made from it: a backup that omits your custom sefarim and says
/// "Saved backup"; a clear that removes nothing and reports success. Two of the
/// three sites were fixed one at a time, each with its own paragraph explaining
/// why, and the third was written afterwards.
///
/// One reader, straight from the repository, and no parameter for a caller to
/// fill in wrongly.
class ProfileCustomisations {
  const ProfileCustomisations({
    required this.nodes,
    required this.layers,
    required this.configs,
  });

  const ProfileCustomisations.empty()
      : nodes = const [],
        layers = const [],
        configs = const [];

  /// Custom sefarim — new nodes, and per-profile overrides of built-in ones.
  final List<CatalogNode> nodes;

  /// Custom mefarshim.
  final List<Layer> layers;

  /// Which mefarshim apply where, and in what role.
  final List<LayerConfigEntry> configs;

  /// How many rows there are altogether — the number a destructive action has
  /// to be able to show before it performs itself.
  int get count => nodes.length + layers.length + configs.length;

  bool get isEmpty => count == 0;

  /// Read [profileId]'s, from the repository rather than from anything caching
  /// it.
  ///
  /// Sequential rather than `Future.wait`, deliberately: these are three reads
  /// against one SQLite connection, so there is nothing to overlap, and a
  /// deterministic order is what lets the export and the teardown be compared
  /// row for row when they disagree.
  static Future<ProfileCustomisations> of(
      ProgressRepository repo, String profileId) async {
    return ProfileCustomisations(
      nodes: await repo.getCustomNodes(profileId),
      layers: await repo.getCustomLayers(profileId),
      configs: await repo.getLayerConfigs(profileId),
    );
  }
}
