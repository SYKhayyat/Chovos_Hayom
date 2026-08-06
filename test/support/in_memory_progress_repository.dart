import 'dart:async';

import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/entities/profile.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/domain/usecases/layer_roles.dart';

/// In-memory [ProgressRepository] with no native dependencies — the double every
/// test overrides `progressRepositoryProvider` with.
///
/// It used to live in `lib/`, which meant it shipped inside the app: dead weight
/// in every release build, and an implementation of a core interface that looked
/// like production code while nothing in production could reach it. It is test
/// scaffolding, so it lives with the tests.
///
/// It is still a faithful implementation rather than a stub — [transaction] gives
/// the same all-or-nothing guarantee SQLite does, the streams emit on the same
/// writes, and an event insert enforces the real table's `{profileId, id}` key —
/// because a test double that is easier to satisfy than the real repository
/// proves nothing about the real repository.
///
/// It once claimed that while storing events in a `Map<profileId, List<…>>` with
/// no uniqueness check at all, which is exactly why the cross-profile import
/// collision could not fail in any test that used it. The claim is only worth
/// making about constraints the double actually enforces, so: the event key is
/// enforced, and the remaining primary keys are upserts here as they are there.
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

  /// The real table's primary key is `{profileId, id}`, so an insert that repeats
  /// one throws `SqliteException(1555)`. Enforcing it here is the difference
  /// between a double and a stub: while this map merely appended, a whole class
  /// of uniqueness bug — including the cross-profile import collision — could
  /// not fail in any test that used it.
  void _insert(LearningEvent event) {
    final list = _events[event.profileId] ??= [];
    if (list.any((e) => e.id == event.id)) {
      throw StateError('UNIQUE constraint failed: learning_events.profile_id, '
          'learning_events.id (${event.profileId}, ${event.id})');
    }
    list.add(event);
  }

  @override
  Future<void> addEvent(LearningEvent event) async {
    _insert(event);
    _emit(event.profileId);
  }

  @override
  Future<void> addEvents(List<LearningEvent> events) async {
    if (events.isEmpty) return;
    final touched = <String>{};
    for (final event in events) {
      _insert(event);
      touched.add(event.profileId);
    }
    for (final p in touched) {
      _emit(p);
    }
  }

  @override
  Future<void> removeEvents(String profileId, List<String> eventIds) async {
    if (eventIds.isEmpty) return;
    final list = _events[profileId];
    if (list == null) return;
    final ids = eventIds.toSet();
    final before = list.length;
    list.removeWhere((e) => ids.contains(e.id));
    if (list.length != before) _emit(profileId);
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
    final configs = {for (final e in _layerConfigs.entries) e.key: [...e.value]};
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
      _layerConfigs
        ..clear()
        ..addAll(configs);
    };
  }

  void _emitAll() {
    for (final p in {
      ..._events.keys,
      ..._customNodes.keys,
      ..._customLayers.keys,
      ..._layerConfigs.keys,
    }) {
      _emit(p);
      _emitCustom(p);
      _emitLayers(p);
      _emitConfigs(p);
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
    _layerConfigs.remove(profileId);
    _emit(profileId);
    _emitCustom(profileId);
    _emitLayers(profileId);
    _emitConfigs(profileId);
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

  // --- Mefarshim + layer settings ------------------------------------------

  final Map<String, List<Layer>> _customLayers = {};
  final Map<String, StreamController<List<Layer>>> _layerControllers = {};
  final Map<String, List<LayerConfigEntry>> _layerConfigs = {};
  final Map<String, StreamController<List<LayerConfigEntry>>>
      _configControllers = {};

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

  StreamController<List<LayerConfigEntry>> _configControllerFor(
          String profileId) =>
      _configControllers.putIfAbsent(profileId,
          () => StreamController<List<LayerConfigEntry>>.broadcast());

  void _emitConfigs(String profileId) {
    final c = _configControllers[profileId];
    if (c != null && c.hasListener) {
      c.add(List.unmodifiable(_layerConfigs[profileId] ?? const []));
    }
  }

  @override
  Stream<List<LayerConfigEntry>> watchLayerConfigs(String profileId) async* {
    final controller = _configControllerFor(profileId);
    yield List.unmodifiable(_layerConfigs[profileId] ?? const []);
    yield* controller.stream;
  }

  @override
  Future<void> setLayerConfig(String profileId, LayerConfigEntry entry) async {
    final list = _layerConfigs[profileId] ??= [];
    list.removeWhere(
        (e) => e.nodeId == entry.nodeId && e.unitIndex == entry.unitIndex);
    list.add(entry);
    _emitConfigs(profileId);
  }

  @override
  Future<void> clearLayerConfig(
      String profileId, String nodeId, int unitIndex) async {
    final list = _layerConfigs[profileId];
    if (list == null) return;
    final before = list.length;
    list.removeWhere((e) => e.nodeId == nodeId && e.unitIndex == unitIndex);
    if (list.length != before) _emitConfigs(profileId);
  }
}
