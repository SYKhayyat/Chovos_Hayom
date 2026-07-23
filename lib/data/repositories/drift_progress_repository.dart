import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/learning_event.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/usecases/layer_requirements.dart';
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
  Future<void> removeEvents(List<String> eventIds) async {
    if (eventIds.isEmpty) return;
    await (_db.delete(_db.learningEvents)..where((t) => t.id.isIn(eventIds))).go();
  }

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
      );

  @override
  Future<void> updateEvent(LearningEvent e) async {
    // Only the annotation columns are mutable; identity/action are immutable.
    await (_db.update(_db.learningEvents)..where((t) => t.id.equals(e.id))).write(
      LearningEventsCompanion(
        occurredAt: Value(e.occurredAt),
        durationMin: Value(e.durationMin),
        note: Value(e.note),
      ),
    );
  }

  @override
  Future<void> removeEvent(String eventId) async {
    await (_db.delete(_db.learningEvents)..where((t) => t.id.equals(eventId)))
        .go();
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
            settingsJson: Value(jsonEncode(p.settings)),
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
      await (_db.delete(_db.requiredLayerConfigs)
            ..where((t) => t.profileId.equals(profileId)))
          .go();
      await (_db.delete(_db.offeredLayerConfigs)
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
        settings: (jsonDecode(row.settingsJson) as Map).cast<String, dynamic>(),
      );

  @override
  Stream<List<CatalogNode>> watchCustomNodes(String profileId) {
    final query = _db.select(_db.customNodes)
      ..where((t) => t.profileId.equals(profileId));
    return query.watch().map((rows) => rows.map(_toNode).toList());
  }

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

  @override
  Stream<List<Layer>> watchCustomLayers(String profileId) {
    final query = _db.select(_db.customLayers)
      ..where((t) => t.profileId.equals(profileId))
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    return query.watch().map((rows) => rows
        .map((r) =>
            Layer(id: r.id, name: r.name, nameHebrew: r.nameHebrew))
        .toList());
  }

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

  // --- Required-layer settings ---------------------------------------------

  @override
  Stream<List<LayerRequirementEntry>> watchLayerRequirements(String profileId) {
    final query = _db.select(_db.requiredLayerConfigs)
      ..where((t) => t.profileId.equals(profileId));
    return query.watch().map((rows) => rows
        .map((r) => LayerRequirementEntry(
              nodeId: r.nodeId,
              unitIndex: r.unitIndex,
              layers: (jsonDecode(r.layersJson) as List).cast<String>().toSet(),
            ))
        .toList());
  }

  @override
  Future<void> setLayerRequirement(
      String profileId, LayerRequirementEntry entry) async {
    await _db.into(_db.requiredLayerConfigs).insertOnConflictUpdate(
          RequiredLayerConfigsCompanion.insert(
            profileId: profileId,
            nodeId: entry.nodeId,
            unitIndex: Value(entry.unitIndex),
            layersJson: jsonEncode(entry.layers.toList()),
          ),
        );
  }

  @override
  Future<void> clearLayerRequirement(
      String profileId, String nodeId, int unitIndex) async {
    await (_db.delete(_db.requiredLayerConfigs)
          ..where((t) =>
              t.profileId.equals(profileId) &
              t.nodeId.equals(nodeId) &
              t.unitIndex.equals(unitIndex)))
        .go();
  }

  // --- Offered (checkable) layer settings ----------------------------------

  @override
  Stream<List<LayerConfigEntry>> watchOfferedLayers(String profileId) {
    final query = _db.select(_db.offeredLayerConfigs)
      ..where((t) => t.profileId.equals(profileId));
    return query.watch().map((rows) => rows
        .map((r) => LayerConfigEntry(
              nodeId: r.nodeId,
              unitIndex: r.unitIndex,
              layers: (jsonDecode(r.layersJson) as List).cast<String>().toSet(),
            ))
        .toList());
  }

  @override
  Future<void> setOfferedLayers(String profileId, LayerConfigEntry entry) async {
    await _db.into(_db.offeredLayerConfigs).insertOnConflictUpdate(
          OfferedLayerConfigsCompanion.insert(
            profileId: profileId,
            nodeId: entry.nodeId,
            unitIndex: Value(entry.unitIndex),
            layersJson: jsonEncode(entry.layers.toList()),
          ),
        );
  }

  @override
  Future<void> clearOfferedLayers(
      String profileId, String nodeId, int unitIndex) async {
    await (_db.delete(_db.offeredLayerConfigs)
          ..where((t) =>
              t.profileId.equals(profileId) &
              t.nodeId.equals(nodeId) &
              t.unitIndex.equals(unitIndex)))
        .go();
  }
}
