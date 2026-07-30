import '../entities/catalog_node.dart';
import '../entities/layer.dart';
import '../entities/learning_event.dart';
import '../entities/profile.dart';
import '../usecases/layer_requirements.dart';

/// Persists the append-only event log, profiles, and user-defined custom nodes.
/// The log is the single source of truth; nothing derived is stored here.
///
/// **Event ids are unique within a profile, not across the store.** The same
/// backup imported into two profiles puts the same ids in both — that is the
/// feature — so every operation that names an event also names the profile it
/// belongs to. There is deliberately no find-by-id-alone anywhere in this
/// interface; one existed, and it deleted from whichever profile happened to
/// hold a matching row.
abstract interface class ProgressRepository {
  /// Reactive stream of all events for [profileId], emitting on every change.
  Stream<List<LearningEvent>> watchEvents(String profileId);

  Future<List<LearningEvent>> getEvents(String profileId);

  /// Append an event. The done/undone/reviewed *actions* are never rewritten in
  /// place — they are only ever appended (see [updateEvent] for the one exception).
  Future<void> addEvent(LearningEvent event);

  /// Append many events in one transaction — the backing store for bulk actions
  /// (finish-all / clear-all). No-op on an empty list.
  Future<void> addEvents(List<LearningEvent> events);

  /// Remove many of [profileId]'s events by id in one transaction — used to undo
  /// a bulk action, and to drop the events a restore does not contain. Ids
  /// belonging to another profile are not this profile's to remove and are
  /// ignored.
  Future<void> removeEvents(String profileId, List<String> eventIds);

  /// Remove every event of one bulk batch, returning how many rows went. Undo by
  /// batch id rather than by a list of ids the caller has to have kept, so a bulk
  /// action stays revertible in a later session (see [BatchHistory]).
  Future<int> removeBatch(String profileId, String batchId);

  /// Run [action] as one atomic unit: either every write inside it lands or none
  /// does. Import uses this so a malformed or truncated backup can never leave
  /// half of itself behind.
  Future<T> transaction<T>(Future<T> Function() action);

  /// Edit the *annotations* of an existing event in place — its [occurredAt]
  /// (when it was learned), [durationMin], and [note]. The event's identity and
  /// action are unchanged, so the folded done-set is unaffected; this lets the
  /// user correct or fill in details of an item after the fact. Scoped to
  /// [LearningEvent.profileId]; a no-op if that profile has no such id.
  Future<void> updateEvent(LearningEvent event);

  Future<List<Profile>> getProfiles();
  Future<void> addProfile(Profile profile);

  /// Rename a profile. No-op if the id doesn't exist.
  Future<void> renameProfile(String profileId, String name);

  /// Delete a profile and all of its events and custom nodes.
  Future<void> deleteProfile(String profileId);

  /// Reactive stream of the profile's custom nodes (as catalog nodes).
  Stream<List<CatalogNode>> watchCustomNodes(String profileId);

  /// Add or replace a custom node. Idempotent by (profileId, id) so re-importing
  /// a backup does not duplicate or throw.
  Future<void> addCustomNode(String profileId, CatalogNode node);
  Future<void> removeCustomNode(String profileId, String nodeId);

  // --- Mefarshim (learning layers) -----------------------------------------

  /// Reactive stream of the profile's user-defined mefarshim.
  Stream<List<Layer>> watchCustomLayers(String profileId);

  /// Add or replace a custom meforish (idempotent by (profileId, id)).
  Future<void> addCustomLayer(String profileId, Layer layer);
  Future<void> removeCustomLayer(String profileId, String layerId);

  /// Reactive stream of the profile's required-layer settings (node + unit).
  Stream<List<LayerConfigEntry>> watchLayerRequirements(String profileId);

  /// Pin a required-layer set at a node (unitIndex -1) or a single unit.
  Future<void> setLayerRequirement(String profileId, LayerConfigEntry entry);

  /// Remove a required-layer setting, reverting to inheritance/default.
  Future<void> clearLayerRequirement(
      String profileId, String nodeId, int unitIndex);

  /// Reactive stream of the profile's *offered* (checkable) layer settings.
  Stream<List<LayerConfigEntry>> watchOfferedLayers(String profileId);

  /// Pin an offered-layer set at a node (unitIndex -1) or a single unit.
  Future<void> setOfferedLayers(String profileId, LayerConfigEntry entry);

  /// Remove an offered-layer setting, reverting to inheritance/default.
  Future<void> clearOfferedLayers(String profileId, String nodeId, int unitIndex);
}
