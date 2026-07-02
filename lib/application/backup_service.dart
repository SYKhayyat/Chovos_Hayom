import 'dart:convert';

import '../domain/entities/catalog_node.dart';
import '../domain/entities/learning_event.dart';
import '../domain/repositories/progress_repository.dart';

/// Parsed backup payload.
class BackupData {
  const BackupData({
    required this.version,
    required this.events,
    required this.customNodes,
  });

  final int version;
  final List<LearningEvent> events;
  final List<CatalogNode> customNodes;
}

/// Serialises and restores a profile's data (event log + custom nodes). The log
/// is the source of truth, so a backup is simply the log plus any custom nodes.
class BackupService {
  const BackupService(this._repo);

  final ProgressRepository _repo;

  static const currentVersion = 1;

  /// Build a portable JSON string for [profileId].
  Future<String> export(String profileId, List<CatalogNode> customNodes) async {
    final events = await _repo.getEvents(profileId);
    return jsonEncode({
      'version': currentVersion,
      'exportedFrom': profileId,
      'events': events.map((e) => e.toJson()).toList(),
      'customNodes': customNodes.map((n) => n.toJson()).toList(),
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
    );
  }

  /// Import [jsonStr] into [targetProfileId]. Events are re-scoped to the target
  /// profile and de-duplicated by id. Returns the number of new events added.
  Future<int> importInto(String targetProfileId, String jsonStr) async {
    final data = parse(jsonStr);
    final existing =
        (await _repo.getEvents(targetProfileId)).map((e) => e.id).toSet();

    var added = 0;
    for (final e in data.events) {
      if (existing.contains(e.id)) continue;
      await _repo.addEvent(LearningEvent(
        id: e.id,
        profileId: targetProfileId,
        nodeId: e.nodeId,
        unitIndex: e.unitIndex,
        action: e.action,
        occurredAt: e.occurredAt,
        loggedAt: e.loggedAt,
        durationMin: e.durationMin,
        note: e.note,
      ));
      added++;
    }
    for (final n in data.customNodes) {
      await _repo.addCustomNode(targetProfileId, n);
    }
    return added;
  }
}
