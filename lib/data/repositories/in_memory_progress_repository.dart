import 'dart:async';

import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/learning_event.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/progress_repository.dart';

/// In-memory [ProgressRepository] with no native dependencies. Used by tests and
/// as a reference implementation; the app uses the Drift-backed repository.
class InMemoryProgressRepository implements ProgressRepository {
  final Map<String, List<LearningEvent>> _events = {};
  final List<Profile> _profiles = [];
  final Map<String, StreamController<List<LearningEvent>>> _controllers = {};
  final Map<String, List<CatalogNode>> _customNodes = {};
  final Map<String, StreamController<List<CatalogNode>>> _customControllers = {};

  StreamController<List<LearningEvent>> _controllerFor(String profileId) =>
      _controllers.putIfAbsent(
        profileId,
        () => StreamController<List<LearningEvent>>.broadcast(),
      );

  void _emit(String profileId) {
    final controller = _controllers[profileId];
    if (controller != null && controller.hasListener) {
      controller.add(_snapshot(profileId));
    }
  }

  List<LearningEvent> _snapshot(String profileId) =>
      List.unmodifiable(_events[profileId] ?? const []);

  @override
  Stream<List<LearningEvent>> watchEvents(String profileId) async* {
    final controller = _controllerFor(profileId);
    yield _snapshot(profileId);
    yield* controller.stream;
  }

  @override
  Future<List<LearningEvent>> getEvents(String profileId) async =>
      _snapshot(profileId);

  @override
  Future<void> addEvent(LearningEvent event) async {
    (_events[event.profileId] ??= []).add(event);
    _emit(event.profileId);
  }

  @override
  Future<void> updateEvent(LearningEvent event) async {
    final list = _events[event.profileId];
    if (list == null) return;
    final i = list.indexWhere((e) => e.id == event.id);
    if (i == -1) return;
    list[i] = event;
    _emit(event.profileId);
  }

  @override
  Future<void> removeEvent(String eventId) async {
    for (final entry in _events.entries) {
      final before = entry.value.length;
      entry.value.removeWhere((e) => e.id == eventId);
      if (entry.value.length != before) _emit(entry.key);
    }
  }

  @override
  Future<List<Profile>> getProfiles() async => List.unmodifiable(_profiles);

  @override
  Future<void> addProfile(Profile profile) async => _profiles.add(profile);

  @override
  Future<void> renameProfile(String profileId, String name) async {
    final i = _profiles.indexWhere((p) => p.id == profileId);
    if (i == -1) return;
    final p = _profiles[i];
    _profiles[i] =
        Profile(id: p.id, name: name, createdAt: p.createdAt, settings: p.settings);
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    _profiles.removeWhere((p) => p.id == profileId);
    _events.remove(profileId);
    _customNodes.remove(profileId);
    _emit(profileId);
    _emitCustom(profileId);
  }

  StreamController<List<CatalogNode>> _customControllerFor(String profileId) =>
      _customControllers.putIfAbsent(
        profileId,
        () => StreamController<List<CatalogNode>>.broadcast(),
      );

  List<CatalogNode> _customSnapshot(String profileId) =>
      List.unmodifiable(_customNodes[profileId] ?? const []);

  void _emitCustom(String profileId) {
    final c = _customControllers[profileId];
    if (c != null && c.hasListener) c.add(_customSnapshot(profileId));
  }

  @override
  Stream<List<CatalogNode>> watchCustomNodes(String profileId) async* {
    final controller = _customControllerFor(profileId);
    yield _customSnapshot(profileId);
    yield* controller.stream;
  }

  @override
  Future<void> addCustomNode(String profileId, CatalogNode node) async {
    final list = _customNodes[profileId] ??= [];
    // Idempotent by (profileId, id): replace in place if it already exists.
    final i = list.indexWhere((n) => n.id == node.id);
    if (i == -1) {
      list.add(node);
    } else {
      list[i] = node;
    }
    _emitCustom(profileId);
  }

  @override
  Future<void> removeCustomNode(String profileId, String nodeId) async {
    final list = _customNodes[profileId];
    if (list == null) return;
    final before = list.length;
    list.removeWhere((n) => n.id == nodeId);
    if (list.length != before) _emitCustom(profileId);
  }
}
