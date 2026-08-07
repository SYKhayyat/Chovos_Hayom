import '../entities/catalog_node.dart';
import '../entities/layer.dart';
import '../entities/learning_event.dart';
import '../entities/profile.dart';
import '../usecases/layer_roles.dart';

/// Persists the append-only event log, profiles, and user-defined custom nodes.
/// The log is the single source of truth; nothing derived is stored here.
///
/// **Why this interface exists, having been revisited and kept.**
///
/// Twenty-four members over 109 lines, one production implementation, and one
/// test double — and the double *delegates*, so it is not a second answer to
/// anything. Those numbers are the case for deleting it, and the case is real:
/// a ~20-line wrapper that forwarded to `DriftProgressRepository` would need
/// every one of the twenty-four members anyway, so nothing is bought by the
/// swap either.
///
/// What it does buy is the **dependency rule**, and not the one its address
/// suggests. Nothing in `domain/` consumes this interface — the readers are
/// `application/` (the backup service, the logging service, the customisations
/// reader, the providers) and one screen. Without it, every one of them would
/// import `data/drift/`, and `drift` would be a compile-time dependency of the
/// layer that holds the app's rules. `test/data/dependency_rule_test.dart` is
/// what actually holds that line: only the two composition roots — `providers`
/// and `main` — may reach into `data/`, and this interface is what lets
/// everything else keep away from it.
///
/// The other thing it buys is `FailingProgressRepository`: a write cannot be
/// made to fail on demand through Drift, and the write guard's whole reason for
/// existing is what happens when one does.
///
/// The co-change signal is real and is not an argument against it. This file
/// moved with its implementation five times in eleven changes, because it is a
/// *faithful mirror* of a persistence surface rather than an abstraction over
/// several — which is the correct shape here and the reason the shape is
/// stated rather than left to be re-litigated.
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

  /// The profile's custom nodes, once.
  ///
  /// This and its two siblings below exist because eleven call sites wanted a
  /// one-shot read and only had a stream, so they all wrote
  /// `await watchCustomNodes(id).first`: open a live query, register it in the
  /// update store, fetch, emit, cancel, unregister — to answer a question a
  /// `SELECT` answers. The log has had both halves from the start
  /// ([watchEvents] and [getEvents]); these three collections were given only
  /// the reactive one, and every reader had to improvise the other.
  Future<List<CatalogNode>> getCustomNodes(String profileId);

  /// Add or replace a custom node. Idempotent by (profileId, id) so re-importing
  /// a backup does not duplicate or throw.
  Future<void> addCustomNode(String profileId, CatalogNode node);
  Future<void> removeCustomNode(String profileId, String nodeId);

  // --- Mefarshim (learning layers) -----------------------------------------

  /// Reactive stream of the profile's user-defined mefarshim.
  Stream<List<Layer>> watchCustomLayers(String profileId);

  /// The profile's user-defined mefarshim, once. See [getCustomNodes].
  Future<List<Layer>> getCustomLayers(String profileId);

  /// Add or replace a custom meforish (idempotent by (profileId, id)).
  Future<void> addCustomLayer(String profileId, Layer layer);
  Future<void> removeCustomLayer(String profileId, String layerId);

  /// Reactive stream of the profile's layer settings (node + unit level).
  ///
  /// One stream, because one entry carries a node's whole answer. This was two
  /// streams over two tables, which meant every consumer had to watch both and
  /// re-unite them — and any consumer that watched one and not the other was
  /// simply wrong about what the user had configured.
  Stream<List<LayerConfigEntry>> watchLayerConfigs(String profileId);

  /// The profile's layer settings, once. See [getCustomNodes].
  Future<List<LayerConfigEntry>> getLayerConfigs(String profileId);

  /// Pin a layer role map at a node (unitIndex -1) or a single unit.
  Future<void> setLayerConfig(String profileId, LayerConfigEntry entry);

  /// Remove a layer setting, reverting to inheritance/default.
  Future<void> clearLayerConfig(String profileId, String nodeId, int unitIndex);
}
