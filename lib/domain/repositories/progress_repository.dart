import '../entities/catalog_node.dart';
import '../entities/learning_event.dart';
import '../entities/profile.dart';

/// Persists the append-only event log, profiles, and user-defined custom nodes.
/// The log is the single source of truth; nothing derived is stored here.
abstract interface class ProgressRepository {
  /// Reactive stream of all events for [profileId], emitting on every change.
  Stream<List<LearningEvent>> watchEvents(String profileId);

  Future<List<LearningEvent>> getEvents(String profileId);

  /// Append an event. Events are never updated in place.
  Future<void> addEvent(LearningEvent event);

  /// Remove a single event by id (used by undo).
  Future<void> removeEvent(String eventId);

  Future<List<Profile>> getProfiles();
  Future<void> addProfile(Profile profile);

  /// Reactive stream of the profile's custom nodes (as catalog nodes).
  Stream<List<CatalogNode>> watchCustomNodes(String profileId);

  Future<void> addCustomNode(String profileId, CatalogNode node);
  Future<void> removeCustomNode(String nodeId);
}
