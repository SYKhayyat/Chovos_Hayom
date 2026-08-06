import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/learning_event.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/usecases/layer_roles.dart';
import '../drift/database.dart';

/// Drift-backed [ProgressRepository]. The app's real persistence layer.
class DriftProgressRepository implements ProgressRepository {
  DriftProgressRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<LearningEvent>> watchEvents(String profileId) {
    final query = _db.select(_db.learningEvents)
      ..where((t) => t.profileId.equals(profileId));
    return query.watch().map((rows) => rows.map(_toEvent).toList());
  }

  @override
  Future<List<LearningEvent>> getEvents(String profileId) async {
    final query = _db.select(_db.learningEvents)
      ..where((t) => t.profileId.equals(profileId));
    final rows = await query.get();
    return rows.map(_toEvent).toList();
  }

  @override
  Future<void> addEvent(LearningEvent e) async {
    await _db.into(_db.learningEvents).insert(_eventCompanion(e));
  }

  @override
  Future<void> addEvents(List<LearningEvent> events) async {
    if (events.isEmpty) return;
    await _db.batch((b) {
      b.insertAll(_db.learningEvents, events.map(_eventCompanion).toList());
    });
  }

  @override
  Future<void> removeEvents(String profileId, List<String> eventIds) async {
    if (eventIds.isEmpty) return;
    await (_db.delete(_db.learningEvents)
          ..where((t) => t.profileId.equals(profileId) & t.id.isIn(eventIds)))
        .go();
  }

  @override
  Future<int> removeBatch(String profileId, String batchId) =>
      (_db.delete(_db.learningEvents)
            ..where((t) =>
                t.profileId.equals(profileId) & t.batchId.equals(batchId)))
          .go();

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _db.transaction(action);

  LearningEventsCompanion _eventCompanion(LearningEvent e) =>
      LearningEventsCompanion.insert(
        id: e.id,
        profileId: e.profileId,
        nodeId: e.nodeId,
        unitIndex: e.unitIndex,
        action: e.action,
        occurredAt: e.occurredAt,
        loggedAt: e.loggedAt,
        durationMin: Value(e.durationMin),
        note: Value(e.note),
        layersJson: Value(_encodeLayers(e.layers)),
        batchId: Value(e.batchId),
      );

  @override
  Future<void> updateEvent(LearningEvent e) async {
    // Only the annotation columns are mutable; identity/action are immutable.
    // Both halves of the key, or this edits whichever profile's row matched.
    await (_db.update(_db.learningEvents)
          ..where((t) => t.profileId.equals(e.profileId) & t.id.equals(e.id)))
        .write(
      LearningEventsCompanion(
        occurredAt: Value(e.occurredAt),
        durationMin: Value(e.durationMin),
        note: Value(e.note),
      ),
    );
  }

  @override
  Future<List<Profile>> getProfiles() async {
    final rows = await _db.select(_db.profiles).get();
    return rows.map(_toProfile).toList();
  }

  @override
  Future<void> addProfile(Profile p) async {
    await _db.into(_db.profiles).insert(
          ProfilesCompanion.insert(
            id: p.id,
            name: p.name,
            createdAt: p.createdAt,
          ),
        );
  }

  @override
  Future<void> renameProfile(String profileId, String name) async {
    await (_db.update(_db.profiles)..where((t) => t.id.equals(profileId)))
        .write(ProfilesCompanion(name: Value(name)));
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.learningEvents)
            ..where((t) => t.profileId.equals(profileId)))
          .go();
      await (_db.delete(_db.customNodes)
            ..where((t) => t.profileId.equals(profileId)))
          .go();
      await (_db.delete(_db.customLayers)
            ..where((t) => t.profileId.equals(profileId)))
          .go();
      await (_db.delete(_db.layerConfigs)
            ..where((t) => t.profileId.equals(profileId)))
          .go();
      await (_db.delete(_db.profiles)..where((t) => t.id.equals(profileId)))
          .go();
    });
  }

  LearningEvent _toEvent(LearningEventRow row) => LearningEvent(
        id: row.id,
        profileId: row.profileId,
        nodeId: row.nodeId,
        unitIndex: row.unitIndex,
        action: row.action,
        occurredAt: row.occurredAt,
        loggedAt: row.loggedAt,
        durationMin: row.durationMin,
        note: row.note,
        layers: _decodeLayers(row.layersJson),
        batchId: row.batchId,
      );

  /// Stores the default single-'main' list as null to keep old rows unchanged.
  static String? _encodeLayers(List<String> layers) =>
      (layers.length == 1 && layers.first == mainLayerId)
          ? null
          : jsonEncode(layers);

  static List<String> _decodeLayers(String? json) => json == null
      ? const [mainLayerId]
      : (jsonDecode(json) as List).cast<String>();

  Profile _toProfile(ProfileRow row) => Profile(
        id: row.id,
        name: row.name,
        createdAt: row.createdAt,
      );

  /// One query definition per collection, read two ways.
  ///
  /// `watch()` and `get()` differ only in whether the result keeps updating, so
  /// the selectable is built once and the two halves of the interface are two
  /// lines each. A hand-written second query is how the reactive and one-shot
  /// answers come to disagree about the same rows.
  SimpleSelectStatement<CustomNodes, CustomNodeRow> _customNodesOf(
          String profileId) =>
      _db.select(_db.customNodes)..where((t) => t.profileId.equals(profileId));

  @override
  Stream<List<CatalogNode>> watchCustomNodes(String profileId) =>
      _customNodesOf(profileId).watch().map((rows) => rows.map(_toNode).toList());

  @override
  Future<List<CatalogNode>> getCustomNodes(String profileId) async =>
      (await _customNodesOf(profileId).get()).map(_toNode).toList();

  @override
  Future<void> addCustomNode(String profileId, CatalogNode node) async {
    // Idempotent by (profileId, id): re-importing a backup updates in place
    // rather than throwing or duplicating.
    await _db.into(_db.customNodes).insertOnConflictUpdate(
          CustomNodesCompanion.insert(
            id: node.id,
            profileId: profileId,
            parentId: Value(node.parentId),
            name: node.name,
            nameHebrew: Value(node.nameHebrew),
            sortOrder: Value(node.sortOrder),
            kind: node.kind,
            unitLabel: Value(node.unitLabel),
            unitCount: Value(node.unitCount),
            unitOffset: Value(node.unitOffset),
            hidden: Value(node.hidden),
            unitNamesJson: Value(
                node.unitNames.isEmpty ? null : jsonEncode(node.unitNames)),
          ),
        );
  }

  @override
  Future<void> removeCustomNode(String profileId, String nodeId) async {
    await (_db.delete(_db.customNodes)
          ..where((t) => t.profileId.equals(profileId) & t.id.equals(nodeId)))
        .go();
  }

  CatalogNode _toNode(CustomNodeRow row) => CatalogNode(
        id: row.id,
        parentId: row.parentId,
        name: row.name,
        nameHebrew: row.nameHebrew,
        sortOrder: row.sortOrder,
        kind: row.kind,
        unitLabel: row.unitLabel,
        unitCount: row.unitCount,
        unitOffset: row.unitOffset,
        hidden: row.hidden,
        unitNames: row.unitNamesJson == null
            ? const []
            : (jsonDecode(row.unitNamesJson!) as List).cast<String>(),
      );

  // --- Mefarshim (custom layers) -------------------------------------------

  SimpleSelectStatement<CustomLayers, CustomLayerRow> _customLayersOf(
          String profileId) =>
      _db.select(_db.customLayers)
        ..where((t) => t.profileId.equals(profileId))
        ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);

  @override
  Stream<List<Layer>> watchCustomLayers(String profileId) =>
      _customLayersOf(profileId).watch().map((rows) => rows.map(_toLayer).toList());

  @override
  Future<List<Layer>> getCustomLayers(String profileId) async =>
      (await _customLayersOf(profileId).get()).map(_toLayer).toList();

  Layer _toLayer(CustomLayerRow r) =>
      Layer(id: r.id, name: r.name, nameHebrew: r.nameHebrew);

  @override
  Future<void> addCustomLayer(String profileId, Layer layer) async {
    await _db.into(_db.customLayers).insertOnConflictUpdate(
          CustomLayersCompanion.insert(
            id: layer.id,
            profileId: profileId,
            name: layer.name,
            nameHebrew: Value(layer.nameHebrew),
          ),
        );
  }

  @override
  Future<void> removeCustomLayer(String profileId, String layerId) async {
    await (_db.delete(_db.customLayers)
          ..where((t) => t.profileId.equals(profileId) & t.id.equals(layerId)))
        .go();
  }

  // --- Layer settings -------------------------------------------------------

  SimpleSelectStatement<LayerConfigs, LayerConfigRow> _layerConfigsOf(
          String profileId) =>
      _db.select(_db.layerConfigs)..where((t) => t.profileId.equals(profileId));

  @override
  Stream<List<LayerConfigEntry>> watchLayerConfigs(String profileId) =>
      _layerConfigsOf(profileId)
          .watch()
          .map((rows) => rows.map(_toLayerConfig).toList());

  @override
  Future<List<LayerConfigEntry>> getLayerConfigs(String profileId) async =>
      (await _layerConfigsOf(profileId).get()).map(_toLayerConfig).toList();

  LayerConfigEntry _toLayerConfig(LayerConfigRow r) => LayerConfigEntry(
        nodeId: r.nodeId,
        unitIndex: r.unitIndex,
        roles: _decodeRoles(r.rolesJson),
      );

  @override
  Future<void> setLayerConfig(String profileId, LayerConfigEntry entry) async {
    await _db.into(_db.layerConfigs).insertOnConflictUpdate(
          LayerConfigsCompanion.insert(
            profileId: profileId,
            nodeId: entry.nodeId,
            unitIndex: Value(entry.unitIndex),
            rolesJson: jsonEncode(
                {for (final e in entry.roles.entries) e.key: e.value.name}),
          ),
        );
  }

  @override
  Future<void> clearLayerConfig(
      String profileId, String nodeId, int unitIndex) async {
    await (_db.delete(_db.layerConfigs)
          ..where((t) =>
              t.profileId.equals(profileId) &
              t.nodeId.equals(nodeId) &
              t.unitIndex.equals(unitIndex)))
        .go();
  }

  /// Reads the stored role map. A stored list rather than an object is a row the
  /// v12 merge did not reach — it cannot happen through the app, but a row that
  /// arrives any other way should read as *required*, which is what a bare list
  /// in that column always meant.
  static Map<String, LayerRole> _decodeRoles(String json) {
    final decoded = jsonDecode(json);
    if (decoded is List) {
      return {for (final id in decoded) '$id': LayerRole.required};
    }
    return {
      for (final e in (decoded as Map).entries)
        '${e.key}': LayerRole.fromName(e.value as String?),
    };
  }
}
