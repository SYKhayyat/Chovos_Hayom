import 'dart:convert';

import '../domain/entities/catalog_node.dart';
import '../domain/entities/layer.dart';
import '../domain/entities/learning_event.dart';
import '../domain/repositories/progress_repository.dart';
import '../domain/usecases/layer_requirements.dart';

/// Raised when a backup is unusable. Carries a message meant to be shown to the
/// user verbatim — "what is wrong with this file" is more useful than "failed".
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Parsed backup payload. Newer fields ([customLayers], [requirements],
/// [offered], [settings], [goals]) are absent in older backups and default to
/// empty.
class BackupData {
  const BackupData({
    required this.version,
    required this.events,
    required this.customNodes,
    this.customLayers = const [],
    this.requirements = const [],
    this.offered = const [],
    this.settings = const {},
    this.goals = const {},
  });

  final int version;
  final List<LearningEvent> events;
  final List<CatalogNode> customNodes;
  final List<Layer> customLayers;
  final List<LayerConfigEntry> requirements;
  final List<LayerConfigEntry> offered;
  final Map<String, dynamic> settings;

  /// Target finish dates by node id. Lives outside the repository (in
  /// preferences), so the caller applies it — but it is a backup field in its
  /// own right, not a preference, because goals are profile data.
  final Map<String, DateTime> goals;
}

/// Serialises and restores everything a profile owns: the event log (the source
/// of truth) plus all customization — custom sefarim, custom mefarshim,
/// required/offered layer settings, goals, and app preferences. A backup fully
/// round-trips the app.
class BackupService {
  const BackupService(this._repo);

  final ProgressRepository _repo;

  /// v2 added customLayers, requirements, and settings. v3 added offered
  /// (checkable) layer configs. v4 added goals. Older backups still import
  /// (missing fields default to empty).
  static const currentVersion = 4;

  /// Build a portable JSON string for [profileId].
  Future<String> export(
    String profileId, {
    required List<CatalogNode> customNodes,
    List<Layer> customLayers = const [],
    List<LayerConfigEntry> requirements = const [],
    List<LayerConfigEntry> offered = const [],
    Map<String, dynamic> settings = const {},
    Map<String, DateTime> goals = const {},
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
      'goals': goals.map((k, v) => MapEntry(k, v.toIso8601String())),
    });
  }

  /// Parse [jsonStr] into a [BackupData]. Throws [BackupFormatException] with a
  /// readable reason for anything malformed — this is a trust boundary, and a
  /// hand-edited or truncated file must fail here rather than persist damage.
  static BackupData parse(String jsonStr) {
    final Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        throw const BackupFormatException(
            'That is not a backup — the file must contain a JSON object.');
      }
      map = decoded;
    } on FormatException {
      throw const BackupFormatException(
          'That is not valid JSON. The file may be truncated or partly copied.');
    }

    return BackupData(
      version: (map['version'] as num?)?.toInt() ?? 1,
      events: _parseList(map['events'], 'events', LearningEvent.fromJson),
      customNodes:
          _parseList(map['customNodes'], 'customNodes', CatalogNode.fromJson),
      customLayers:
          _parseList(map['customLayers'], 'customLayers', Layer.fromJson),
      requirements: _parseList(
          map['requirements'], 'requirements', LayerConfigEntry.fromJson),
      offered:
          _parseList(map['offered'], 'offered', LayerConfigEntry.fromJson),
      settings: (map['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
      goals: _parseGoals(map['goals']),
    );
  }

  static List<T> _parseList<T>(
      Object? raw, String field, T Function(Map<String, dynamic>) fromJson) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw BackupFormatException('“$field” must be a list.');
    }
    final out = <T>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map) {
        throw BackupFormatException('“$field” entry ${i + 1} is not an object.');
      }
      try {
        out.add(fromJson(item.cast<String, dynamic>()));
      } catch (e) {
        throw BackupFormatException(
            '“$field” entry ${i + 1} is malformed ($e).');
      }
    }
    return out;
  }

  static Map<String, DateTime> _parseGoals(Object? raw) {
    if (raw == null) return const {};
    if (raw is! Map) throw const BackupFormatException('“goals” must be an object.');
    final out = <String, DateTime>{};
    raw.forEach((key, value) {
      final parsed = DateTime.tryParse('$value');
      if (parsed == null) {
        throw BackupFormatException('Goal for “$key” is not a valid date.');
      }
      out['$key'] = parsed;
    });
    return out;
  }

  /// Import [jsonStr] into [targetProfileId] as one atomic write: events are
  /// re-scoped and de-duplicated by id; custom sefarim, mefarshim, and layer
  /// settings are merged in.
  ///
  /// The payload is fully validated *before* anything is written (see
  /// [BackupValidator]), and the whole write runs in a transaction — so a
  /// malformed backup can neither persist a node that crashes the dashboard nor
  /// leave half of itself behind. [knownNodeIds] are the ids the app already
  /// knows (the bundled catalog), so a custom node parented onto a built-in one
  /// validates.
  ///
  /// Returns the parsed data (so the caller can apply settings and goals, which
  /// live outside the repository) with [BackupData.events] holding only the
  /// newly-added events.
  Future<BackupData> importInto(
    String targetProfileId,
    String jsonStr, {
    Set<String> knownNodeIds = const {},
  }) async {
    final data = parse(jsonStr);
    BackupValidator.validate(data, knownNodeIds: knownNodeIds);

    final existing =
        (await _repo.getEvents(targetProfileId)).map((e) => e.id).toSet();
    final added = [
      for (final e in data.events)
        if (!existing.contains(e.id)) _rescope(e, targetProfileId),
    ];

    await _repo.transaction(() async {
      await _repo.addEvents(added);
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
    });

    return BackupData(
      version: data.version,
      events: added,
      customNodes: data.customNodes,
      customLayers: data.customLayers,
      requirements: data.requirements,
      offered: data.offered,
      settings: data.settings,
      goals: data.goals,
    );
  }

  static LearningEvent _rescope(LearningEvent e, String profileId) =>
      LearningEvent(
        id: e.id,
        profileId: profileId,
        nodeId: e.nodeId,
        unitIndex: e.unitIndex,
        action: e.action,
        occurredAt: e.occurredAt,
        loggedAt: e.loggedAt,
        durationMin: e.durationMin,
        note: e.note,
        layers: e.layers,
        batchId: e.batchId,
      );
}

/// Checks a parsed backup for anything that would corrupt the app if persisted.
///
/// This is the app's trust boundary. Everything it rejects is something that,
/// once in SQLite, has no in-app cure: a negative `unitCount` makes
/// `RollUp` throw on every dashboard build, and a `parentId` cycle makes the
/// inheritance walk recurse forever. Both would be permanent, because the bad
/// row is in the database before the crash is visible.
///
/// Pure, framework-free, and separately testable.
class BackupValidator {
  const BackupValidator._();

  /// A unit count past which a "leaf" is certainly corrupt rather than
  /// ambitious — Shas entire is ~2,711 dapim, so a million-unit sefer is a
  /// damaged number, and building its grid would hang the app.
  static const maxUnitCount = 1000000;

  /// Throws [BackupFormatException] on the first problem found.
  static void validate(BackupData data, {Set<String> knownNodeIds = const {}}) {
    _validateNodes(data.customNodes, knownNodeIds);
    _validateEvents(data.events);
    _validateLayers(data.customLayers);
    _validateConfigs(data.requirements, 'required-mefarshim');
    _validateConfigs(data.offered, 'offered-mefarshim');
  }

  static void _validateNodes(List<CatalogNode> nodes, Set<String> known) {
    final byId = <String, CatalogNode>{};
    for (final n in nodes) {
      if (n.id.trim().isEmpty) {
        throw const BackupFormatException('A custom sefer has an empty id.');
      }
      if (byId.containsKey(n.id)) {
        throw BackupFormatException(
            'Custom sefer “${n.name}” appears twice (id ${n.id}).');
      }
      if (n.name.trim().isEmpty) {
        throw BackupFormatException('Custom sefer ${n.id} has no name.');
      }
      if (n.unitCount < 0) {
        throw BackupFormatException(
            '“${n.name}” has a negative unit count (${n.unitCount}).');
      }
      if (n.unitCount > maxUnitCount) {
        throw BackupFormatException(
            '“${n.name}” claims ${n.unitCount} units, which is not a real '
            'sefer — the file is corrupt.');
      }
      if (n.unitOffset < 0) {
        throw BackupFormatException(
            '“${n.name}” starts at unit ${n.unitOffset}; units cannot be '
            'negative.');
      }
      if (n.unitNames.length > n.unitCount) {
        throw BackupFormatException(
            '“${n.name}” lists ${n.unitNames.length} unit names but only has '
            '${n.unitCount} units.');
      }
      byId[n.id] = n;
    }

    // A parent must resolve — to another node in this backup or to one the app
    // already knows. Anything else would import a node the tree can never show.
    for (final n in nodes) {
      final parent = n.parentId;
      if (parent == null) continue;
      if (!byId.containsKey(parent) && !known.contains(parent)) {
        throw BackupFormatException(
            '“${n.name}” is filed under a sefer that does not exist '
            '(parent $parent).');
      }
    }

    // Cycle check: walk each chain, bounded by the node count. A cycle is only
    // possible among the backup's own nodes — known ids are already a valid tree.
    for (final start in nodes) {
      var current = start.parentId;
      var steps = 0;
      while (current != null && byId.containsKey(current)) {
        if (current == start.id) {
          throw BackupFormatException(
              '“${start.name}” is its own ancestor — the file has a loop in its '
              'sefer hierarchy.');
        }
        if (++steps > byId.length) {
          throw const BackupFormatException(
              'The custom sefer hierarchy contains a loop.');
        }
        current = byId[current]!.parentId;
      }
    }
  }

  static void _validateEvents(List<LearningEvent> events) {
    final seen = <String>{};
    for (final e in events) {
      if (e.id.trim().isEmpty) {
        throw const BackupFormatException('An event has an empty id.');
      }
      if (!seen.add(e.id)) {
        throw BackupFormatException('Event ${e.id} appears twice.');
      }
      if (e.nodeId.trim().isEmpty) {
        throw BackupFormatException('Event ${e.id} has no sefer.');
      }
      if (e.unitIndex < 0) {
        throw BackupFormatException(
            'Event ${e.id} points at unit ${e.unitIndex}; units cannot be '
            'negative.');
      }
      if (e.layers.isEmpty) {
        throw BackupFormatException(
            'Event ${e.id} marks nothing — it has an empty layer list.');
      }
      if (e.durationMin != null && e.durationMin! < 0) {
        throw BackupFormatException(
            'Event ${e.id} has a negative duration (${e.durationMin} min).');
      }
    }
  }

  static void _validateLayers(List<Layer> layers) {
    final seen = <String>{};
    for (final l in layers) {
      if (l.id.trim().isEmpty) {
        throw const BackupFormatException('A meforish has an empty id.');
      }
      if (!seen.add(l.id)) {
        throw BackupFormatException('Meforish “${l.name}” appears twice.');
      }
      if (l.name.trim().isEmpty) {
        throw BackupFormatException('Meforish ${l.id} has no name.');
      }
    }
  }

  static void _validateConfigs(List<LayerConfigEntry> entries, String what) {
    for (final e in entries) {
      if (e.nodeId.trim().isEmpty) {
        throw BackupFormatException('A $what setting has no sefer.');
      }
      // -1 is the node-level default; anything below that is meaningless.
      if (e.unitIndex < -1) {
        throw BackupFormatException(
            'A $what setting on ${e.nodeId} points at unit ${e.unitIndex}.');
      }
    }
  }
}
