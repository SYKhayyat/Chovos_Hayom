import 'dart:convert';

import '../domain/entities/catalog_node.dart';
import '../domain/entities/layer.dart';
import '../domain/entities/learning_event.dart';
import '../domain/repositories/progress_repository.dart';
import '../domain/usecases/layer_requirements.dart';

/// Parsed backup payload. Newer fields ([customLayers], [requirements],
/// [offered], [settings]) are absent in older backups and default to empty.
class BackupData {
  const BackupData({
    required this.version,
    required this.events,
    required this.customNodes,
    this.customLayers = const [],
    this.requirements = const [],
    this.offered = const [],
    this.settings = const {},
  });

  final int version;
  final List<LearningEvent> events;
  final List<CatalogNode> customNodes;
  final List<Layer> customLayers;
  final List<LayerConfigEntry> requirements;
  final List<LayerConfigEntry> offered;
  final Map<String, dynamic> settings;
}

/// Serialises and restores everything a profile owns: the event log (the source
/// of truth) plus all customization — custom sefarim, custom mefarshim, required
/// -layer settings, and app preferences. A backup fully round-trips the app.
class BackupService {
  const BackupService(this._repo);

  final ProgressRepository _repo;

  /// v2 added customLayers, requirements, and settings. v3 added offered
  /// (checkable) layer configs. Older backups still import (missing fields
  /// default to empty).
  static const currentVersion = 3;

  /// Build a portable JSON string for [profileId].
  Future<String> export(
    String profileId, {
    required List<CatalogNode> customNodes,
    List<Layer> customLayers = const [],
    List<LayerConfigEntry> requirements = const [],
    List<LayerConfigEntry> offered = const [],
    Map<String, dynamic> settings = const {},
  }) async {
    final events = await _repo.getEvents(profileId);
    return jsonEncode({
      'version': currentVersion,
      'exportedFrom': profileId,
      'events': events.map((e) => e.toJson()).toList(),
      'customNodes': customNodes.map((n) => n.toJson()).toList(),
      'customLayers': customLayers.map((l) => l.toJson()).toList(),
      'requirements': requirements.map((r) => r.toJson()).toList(),
      'offered': offered.map((r) => r.toJson()).toList(),
      'settings': settings,
    });
  }

  static BackupData parse(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return BackupData(
      version: (map['version'] as num?)?.toInt() ?? 1,
      events: [
        for (final e in (map['events'] as List? ?? []))
          LearningEvent.fromJson((e as Map).cast<String, dynamic>()),
      ],
      customNodes: [
        for (final n in (map['customNodes'] as List? ?? []))
          CatalogNode.fromJson((n as Map).cast<String, dynamic>()),
      ],
      customLayers: [
        for (final l in (map['customLayers'] as List? ?? []))
          Layer.fromJson((l as Map).cast<String, dynamic>()),
      ],
      requirements: [
        for (final r in (map['requirements'] as List? ?? []))
          LayerConfigEntry.fromJson((r as Map).cast<String, dynamic>()),
      ],
      offered: [
        for (final r in (map['offered'] as List? ?? []))
          LayerConfigEntry.fromJson((r as Map).cast<String, dynamic>()),
      ],
      settings: (map['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// Import [jsonStr] into [targetProfileId]: events are re-scoped and
  /// de-duplicated by id; custom sefarim, mefarshim, and required-layer settings
  /// are merged in. Returns the parsed data (so the caller can apply settings,
  /// which live outside the repository) with [BackupData.events] holding only the
  /// newly-added events.
  Future<BackupData> importInto(String targetProfileId, String jsonStr) async {
    final data = parse(jsonStr);
    final existing =
        (await _repo.getEvents(targetProfileId)).map((e) => e.id).toSet();

    final added = <LearningEvent>[];
    for (final e in data.events) {
      if (existing.contains(e.id)) continue;
      final scoped = LearningEvent(
        id: e.id,
        profileId: targetProfileId,
        nodeId: e.nodeId,
        unitIndex: e.unitIndex,
        action: e.action,
        occurredAt: e.occurredAt,
        loggedAt: e.loggedAt,
        durationMin: e.durationMin,
        note: e.note,
        layers: e.layers,
      );
      await _repo.addEvent(scoped);
      added.add(scoped);
    }
    for (final n in data.customNodes) {
      await _repo.addCustomNode(targetProfileId, n);
    }
    for (final l in data.customLayers) {
      await _repo.addCustomLayer(targetProfileId, l);
    }
    for (final r in data.requirements) {
      await _repo.setLayerRequirement(targetProfileId, r);
    }
    for (final o in data.offered) {
      await _repo.setOfferedLayers(targetProfileId, o);
    }

    return BackupData(
      version: data.version,
      events: added,
      customNodes: data.customNodes,
      customLayers: data.customLayers,
      requirements: data.requirements,
      offered: data.offered,
      settings: data.settings,
    );
  }
}
