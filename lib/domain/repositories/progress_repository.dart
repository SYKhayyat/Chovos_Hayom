import '../entities/catalog_node.dart';
import '../entities/learning_event.dart';
import '../entities/profile.dart';

/// Persists the append-only event log, profiles, and user-defined custom nodes.
/// The log is the single source of truth; nothing derived is stored here.
abstract interface class ProgressRepository {
  /// Reactive stream of all events for [profileId], emitting on every change.
  Stream<List<LearningEvent>> watchEvents(String profileId);

  Future<List<LearningEvent>> getEvents(String profileId);

  /// Append an event. The done/undone/reviewed *actions* are never rewritten in
  /// place — they are only ever appended (see [updateEvent] for the one exception).
  Future<void> addEvent(LearningEvent event);

  /// Edit the *annotations* of an existing event in place — its [occurredAt]
  /// (when it was learned), [durationMin], and [note]. The event's identity and
  /// action are unchanged, so the folded done-set is unaffected; this lets the
  /// user correct or fill in details of an item after the fact. No-op if the id
  /// doesn't exist.
  Future<void> updateEvent(LearningEvent event);

  /// Remove a single event by id (used by undo).
  Future<void> removeEvent(String eventId);

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
}
