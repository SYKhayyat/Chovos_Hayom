import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/entities/profile.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/domain/usecases/layer_roles.dart';

import 'memory_database.dart';

/// A [ProgressRepository] whose event writes fail.
///
/// The write guard exists because a write *can* fail — a full disk, a locked
/// database, a schema the app can't open. There is no way to prove the app
/// reports that honestly without a repository that actually refuses, so this is
/// one. Everything else behaves normally, so a screen still loads and renders
/// before the failing write is attempted.
///
/// It used to `extend InMemoryProgressRepository` and override three methods.
/// It now *wraps* the real repository, which is the shape that survives the
/// double's deletion: everything not named here is the production code path,
/// so this class cannot drift from it — the compiler adds a member the moment
/// the interface grows one. That is the whole reason a wrapper beats a
/// subclass here, and it is why the delegation below is written out rather
/// than routed through `noSuchMethod`.
class FailingProgressRepository implements ProgressRepository {
  FailingProgressRepository({this.failWrites = true, this.failEventReads = false})
      : _inner = memoryRepository();

  final ProgressRepository _inner;

  /// Flip to false mid-test to check the success path on the same screen.
  bool failWrites;

  /// Makes `getEvents` refuse.
  ///
  /// Off by default, because a screen has to *load* before most tests can do
  /// anything. It exists for the operations that read the log rather than write
  /// it — an export, most of all: building a backup starts by reading every
  /// event, and that read failing is the realistic way an export dies. The
  /// stream (`watchEvents`) is deliberately left working, so the screen still
  /// renders and it is only the export that fails.
  bool failEventReads;

  /// What every refused call throws — matched in assertions so a test can be
  /// sure it saw *this* failure and not an incidental one.
  static const message = 'the database is not writable';

  @override
  Future<List<LearningEvent>> getEvents(String profileId) async {
    if (failEventReads) throw StateError(message);
    return _inner.getEvents(profileId);
  }

  @override
  Future<void> addEvent(LearningEvent event) async {
    if (failWrites) throw StateError(message);
    return _inner.addEvent(event);
  }

  @override
  Future<void> addEvents(List<LearningEvent> events) async {
    if (failWrites) throw StateError(message);
    return _inner.addEvents(events);
  }

  // --- everything below is the real repository, unchanged --------------------

  @override
  Stream<List<LearningEvent>> watchEvents(String profileId) =>
      _inner.watchEvents(profileId);

  @override
  Future<void> removeEvents(String profileId, List<String> eventIds) =>
      _inner.removeEvents(profileId, eventIds);

  @override
  Future<int> removeBatch(String profileId, String batchId) =>
      _inner.removeBatch(profileId, batchId);

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _inner.transaction(action);

  @override
  Future<void> updateEvent(LearningEvent event) => _inner.updateEvent(event);

  @override
  Future<List<Profile>> getProfiles() => _inner.getProfiles();

  @override
  Future<void> addProfile(Profile profile) => _inner.addProfile(profile);

  @override
  Future<void> renameProfile(String profileId, String name) =>
      _inner.renameProfile(profileId, name);

  @override
  Future<void> deleteProfile(String profileId) => _inner.deleteProfile(profileId);

  @override
  Stream<List<CatalogNode>> watchCustomNodes(String profileId) =>
      _inner.watchCustomNodes(profileId);

  @override
  Future<List<CatalogNode>> getCustomNodes(String profileId) =>
      _inner.getCustomNodes(profileId);

  @override
  Future<void> addCustomNode(String profileId, CatalogNode node) =>
      _inner.addCustomNode(profileId, node);

  @override
  Future<void> removeCustomNode(String profileId, String nodeId) =>
      _inner.removeCustomNode(profileId, nodeId);

  @override
  Stream<List<Layer>> watchCustomLayers(String profileId) =>
      _inner.watchCustomLayers(profileId);

  @override
  Future<List<Layer>> getCustomLayers(String profileId) =>
      _inner.getCustomLayers(profileId);

  @override
  Future<void> addCustomLayer(String profileId, Layer layer) =>
      _inner.addCustomLayer(profileId, layer);

  @override
  Future<void> removeCustomLayer(String profileId, String layerId) =>
      _inner.removeCustomLayer(profileId, layerId);

  @override
  Stream<List<LayerConfigEntry>> watchLayerConfigs(String profileId) =>
      _inner.watchLayerConfigs(profileId);

  @override
  Future<List<LayerConfigEntry>> getLayerConfigs(String profileId) =>
      _inner.getLayerConfigs(profileId);

  @override
  Future<void> setLayerConfig(String profileId, LayerConfigEntry entry) =>
      _inner.setLayerConfig(profileId, entry);

  @override
  Future<void> clearLayerConfig(String profileId, String nodeId, int unitIndex) =>
      _inner.clearLayerConfig(profileId, nodeId, unitIndex);
}
