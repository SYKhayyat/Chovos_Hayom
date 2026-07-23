import 'dart:async';

import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/learning_event.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/usecases/layer_requirements.dart';

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
  Future<void> addEvents(List<LearningEvent> events) async {
    if (events.isEmpty) return;
    final touched = <String>{};
    for (final event in events) {
      (_events[event.profileId] ??= []).add(event);
      touched.add(event.profileId);
    }
    for (final p in touched) {
      _emit(p);
    }
  }

  @override
  Future<void> removeEvents(List<String> eventIds) async {
    if (eventIds.isEmpty) return;
    final ids = eventIds.toSet();
    for (final entry in _events.entries) {
      final before = entry.value.length;
      entry.value.removeWhere((e) => ids.contains(e.id));
      if (entry.value.length != before) _emit(entry.key);
    }
  }

  @override
  Future<int> removeBatch(String profileId, String batchId) async {
    final list = _events[profileId];
    if (list == null) return 0;
    final before = list.length;
    list.removeWhere((e) => e.batchId == batchId);
    final removed = before - list.length;
    if (removed > 0) _emit(profileId);
    return removed;
  }

  /// Snapshot-and-restore, so a failed [action] leaves nothing behind — the same
  /// all-or-nothing guarantee the SQLite repository gets from a real transaction.
  /// Nested calls join the outermost one, matching SQLite's behaviour.
  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    if (_inTransaction) return action();
    _inTransaction = true;
    final undo = _snapshotAll();
    try {
      return await action();
    } catch (_) {
      undo();
      _emitAll();
      rethrow;
    } finally {
      _inTransaction = false;
    }
  }

  bool _inTransaction = false;

  /// Captures every mutable collection; the returned closure puts them all back.
  void Function() _snapshotAll() {
    final events = {for (final e in _events.entries) e.key: [...e.value]};
    final profiles = [..._profiles];
    final nodes = {for (final e in _customNodes.entries) e.key: [...e.value]};
    final layers = {for (final e in _customLayers.entries) e.key: [...e.value]};
    final reqs = {for (final e in _requirements.entries) e.key: [...e.value]};
    final offered = {for (final e in _offered.entries) e.key: [...e.value]};
    return () {
      _events
        ..clear()
        ..addAll(events);
      _profiles
        ..clear()
        ..addAll(profiles);
      _customNodes
        ..clear()
        ..addAll(nodes);
      _customLayers
        ..clear()
        ..addAll(layers);
      _requirements
        ..clear()
        ..addAll(reqs);
      _offered
        ..clear()
        ..addAll(offered);
    };
  }

  void _emitAll() {
    for (final p in {
      ..._events.keys,
      ..._customNodes.keys,
      ..._customLayers.keys,
      ..._requirements.keys,
      ..._offered.keys,
    }) {
      _emit(p);
      _emitCustom(p);
      _emitLayers(p);
      _emitReqs(p);
      _emitOffered(p);
    }
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
        Profile(id: p.id, name: name, createdAt: p.createdAt);
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    _profiles.removeWhere((p) => p.id == profileId);
    _events.remove(profileId);
    _customNodes.remove(profileId);
    _customLayers.remove(profileId);
    _requirements.remove(profileId);
    _offered.remove(profileId);
    _emit(profileId);
    _emitCustom(profileId);
    _emitLayers(profileId);
    _emitReqs(profileId);
    _emitOffered(profileId);
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

  // --- Mefarshim + required layers -----------------------------------------

  final Map<String, List<Layer>> _customLayers = {};
  final Map<String, StreamController<List<Layer>>> _layerControllers = {};
  final Map<String, List<LayerRequirementEntry>> _requirements = {};
  final Map<String, StreamController<List<LayerRequirementEntry>>> _reqControllers =
      {};

  StreamController<List<Layer>> _layerControllerFor(String profileId) =>
      _layerControllers.putIfAbsent(
          profileId, () => StreamController<List<Layer>>.broadcast());

  void _emitLayers(String profileId) {
    final c = _layerControllers[profileId];
    if (c != null && c.hasListener) {
      c.add(List.unmodifiable(_customLayers[profileId] ?? const []));
    }
  }

  @override
  Stream<List<Layer>> watchCustomLayers(String profileId) async* {
    final controller = _layerControllerFor(profileId);
    yield List.unmodifiable(_customLayers[profileId] ?? const []);
    yield* controller.stream;
  }

  @override
  Future<void> addCustomLayer(String profileId, Layer layer) async {
    final list = _customLayers[profileId] ??= [];
    final i = list.indexWhere((l) => l.id == layer.id);
    if (i == -1) {
      list.add(layer);
    } else {
      list[i] = layer;
    }
    _emitLayers(profileId);
  }

  @override
  Future<void> removeCustomLayer(String profileId, String layerId) async {
    final list = _customLayers[profileId];
    if (list == null) return;
    final before = list.length;
    list.removeWhere((l) => l.id == layerId);
    if (list.length != before) _emitLayers(profileId);
  }

  StreamController<List<LayerRequirementEntry>> _reqControllerFor(
          String profileId) =>
      _reqControllers.putIfAbsent(profileId,
          () => StreamController<List<LayerRequirementEntry>>.broadcast());

  void _emitReqs(String profileId) {
    final c = _reqControllers[profileId];
    if (c != null && c.hasListener) {
      c.add(List.unmodifiable(_requirements[profileId] ?? const []));
    }
  }

  @override
  Stream<List<LayerRequirementEntry>> watchLayerRequirements(
      String profileId) async* {
    final controller = _reqControllerFor(profileId);
    yield List.unmodifiable(_requirements[profileId] ?? const []);
    yield* controller.stream;
  }

  @override
  Future<void> setLayerRequirement(
      String profileId, LayerRequirementEntry entry) async {
    final list = _requirements[profileId] ??= [];
    list.removeWhere(
        (e) => e.nodeId == entry.nodeId && e.unitIndex == entry.unitIndex);
    list.add(entry);
    _emitReqs(profileId);
  }

  @override
  Future<void> clearLayerRequirement(
      String profileId, String nodeId, int unitIndex) async {
    final list = _requirements[profileId];
    if (list == null) return;
    final before = list.length;
    list.removeWhere((e) => e.nodeId == nodeId && e.unitIndex == unitIndex);
    if (list.length != before) _emitReqs(profileId);
  }

  // --- Offered (checkable) layers ------------------------------------------

  final Map<String, List<LayerConfigEntry>> _offered = {};
  final Map<String, StreamController<List<LayerConfigEntry>>> _offeredControllers =
      {};

  StreamController<List<LayerConfigEntry>> _offeredControllerFor(
          String profileId) =>
      _offeredControllers.putIfAbsent(
          profileId, () => StreamController<List<LayerConfigEntry>>.broadcast());

  void _emitOffered(String profileId) {
    final c = _offeredControllers[profileId];
    if (c != null && c.hasListener) {
      c.add(List.unmodifiable(_offered[profileId] ?? const []));
    }
  }

  @override
  Stream<List<LayerConfigEntry>> watchOfferedLayers(String profileId) async* {
    final controller = _offeredControllerFor(profileId);
    yield List.unmodifiable(_offered[profileId] ?? const []);
    yield* controller.stream;
  }

  @override
  Future<void> setOfferedLayers(String profileId, LayerConfigEntry entry) async {
    final list = _offered[profileId] ??= [];
    list.removeWhere(
        (e) => e.nodeId == entry.nodeId && e.unitIndex == entry.unitIndex);
    list.add(entry);
    _emitOffered(profileId);
  }

  @override
  Future<void> clearOfferedLayers(
      String profileId, String nodeId, int unitIndex) async {
    final list = _offered[profileId];
    if (list == null) return;
    final before = list.length;
    list.removeWhere((e) => e.nodeId == nodeId && e.unitIndex == unitIndex);
    if (list.length != before) _emitOffered(profileId);
  }
}
