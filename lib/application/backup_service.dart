import 'dart:convert';

import '../domain/entities/catalog_node.dart';
import '../domain/entities/layer.dart';
import '../domain/entities/learning_event.dart';
import '../domain/repositories/progress_repository.dart';
import '../domain/usecases/layer_roles.dart';

/// Raised when a backup is unusable. Carries a message meant to be shown to the
/// user verbatim — "what is wrong with this file" is more useful than "failed".
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// How much of the profile an import is allowed to change.
///
/// There used to be a `bool replace`, and the two things it could mean were not
/// the same size. "Make this profile exactly match a backup" was what the UI
/// promised; reconciling the event log was what the code did. Custom sefarim,
/// custom mefarshim and every layer setting made since the backup survived a
/// restore that said it would undo them.
///
/// Rather than pick one, both exist and each says which it is. The narrow one is
/// what most people want after an accidental bulk action; the wide one is what
/// "exactly match" means, and it deletes things, so it is a separate button with
/// its own confirmation.
enum ImportMode {
  /// Add what the profile does not have. Remove nothing. Re-importing a backup
  /// into the profile it came from is a no-op.
  merge,

  /// Make the **log** match the backup: events the backup does not contain are
  /// deleted, so un-marks and re-logs recorded since it are undone. Custom
  /// sefarim, mefarshim and layer settings are merged in, never removed.
  restoreLog,

  /// Make the **whole profile** match the backup: [restoreLog], and in addition
  /// delete the custom sefarim, custom mefarshim and layer settings the backup
  /// does not contain.
  restoreEverything;

  /// Whether the log is reconciled rather than merged.
  bool get replacesLog => this != ImportMode.merge;

  /// Whether everything outside the log is reconciled too.
  bool get replacesCustomisation => this == ImportMode.restoreEverything;
}

/// Parsed backup payload. Newer fields ([customLayers], [layerConfigs],
/// [settings], [goals]) are absent in older backups and default to empty.
class BackupData {
  const BackupData({
    required this.version,
    required this.events,
    required this.customNodes,
    this.customLayers = const [],
    this.layerConfigs = const [],
    this.settings = const {},
    this.goals = const {},
    this.removedEvents = 0,
    this.removedCustomisations = 0,
  });

  /// How many events a *restore* deleted because the backup doesn't contain
  /// them. Always 0 for a merge. Set on the value [BackupService.importInto]
  /// returns, so the caller can report what it actually did.
  final int removedEvents;

  /// How many custom sefarim, custom mefarshim and layer settings a
  /// [ImportMode.restoreEverything] deleted for the same reason. Always 0 for
  /// the other two modes — which is the whole difference between them.
  final int removedCustomisations;

  final int version;
  final List<LearningEvent> events;
  final List<CatalogNode> customNodes;
  final List<Layer> customLayers;

  /// The profile's mefarshim settings — one entry per configured scope, each
  /// carrying every layer's role. Read from `layerConfigs` in a v5 backup, and
  /// reassembled from the old `requirements` + `offered` arrays in anything
  /// older (see [BackupService.parse]).
  final List<LayerConfigEntry> layerConfigs;
  final Map<String, dynamic> settings;

  /// Target finish dates by node id. Lives outside the repository (in
  /// preferences), so the caller applies it — but it is a backup field in its
  /// own right, not a preference, because goals are profile data.
  final Map<String, DateTime> goals;
}

/// Serialises and restores everything a profile owns: the event log (the source
/// of truth) plus all customization — custom sefarim, custom mefarshim, layer
/// settings, goals, and app preferences. A backup fully round-trips the app.
class BackupService {
  const BackupService(this._repo);

  final ProgressRepository _repo;

  /// v2 added customLayers, requirements, and settings. v3 added offered
  /// (checkable) layer configs. v4 added goals. v5 merged requirements+offered
  /// into one `layerConfigs` array carrying a role per layer. Older backups
  /// still import (missing fields default to empty; see [parse] for how v1–v4
  /// layer settings are read back).
  static const currentVersion = 5;

  /// Build a portable JSON string for [profileId].
  Future<String> export(
    String profileId, {
    required List<CatalogNode> customNodes,
    List<Layer> customLayers = const [],
    List<LayerConfigEntry> layerConfigs = const [],
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
      'layerConfigs': layerConfigs.map((r) => r.toJson()).toList(),
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
      layerConfigs: _parseLayerConfigs(map),
      settings: (map['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
      goals: _parseGoals(map['goals']),
    );
  }

  /// Reads the layer settings out of a backup of any version.
  ///
  /// A v5 backup has one `layerConfigs` array and this is a straight parse.
  /// Anything older has two arrays — `requirements` and `offered` — where
  /// membership *was* the meaning, and the same (node, unit) scope routinely
  /// appears in both, because the config sheet always wrote both. So they are
  /// merged the way the app used to reconcile them at read time: everything
  /// offered is checkable, everything required gates completion, and required
  /// wins where they overlap.
  ///
  /// Getting this wrong is not a cosmetic import bug — reading an old backup's
  /// `requirements` as merely optional would quietly un-complete every layered
  /// unit in the tree, and reading `offered` as required would make units the
  /// user had finished go incomplete. Hence the explicit role per array.
  static List<LayerConfigEntry> _parseLayerConfigs(Map<String, dynamic> map) {
    if (map.containsKey('layerConfigs')) {
      return _parseList(
          map['layerConfigs'], 'layerConfigs', LayerConfigEntry.fromJson);
    }
    final merged = <(String, int), Map<String, LayerRole>>{};
    void take(String field, LayerRole role) {
      for (final e in _parseList(map[field], field,
          (j) => LayerConfigEntry.fromJson(j, legacyRole: role))) {
        (merged[(e.nodeId, e.unitIndex)] ??= {}).addAll(e.roles);
      }
    }

    // Offered first, so the required pass overwrites the overlap rather than
    // the other way round.
    take('offered', LayerRole.optional);
    take('requirements', LayerRole.required);
    return [
      for (final e in merged.entries)
        LayerConfigEntry(
            nodeId: e.key.$1, unitIndex: e.key.$2, roles: e.value),
    ];
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
  /// leave half of itself behind. [knownParents] maps each id the app already
  /// knows (the bundled catalog) to its parent, so a custom node parented onto a
  /// built-in one validates — and so the cycle check can see a loop an *override*
  /// row creates by re-parenting a built-in beneath its own descendant, which
  /// knowing only the ids cannot.
  ///
  /// Returns the parsed data (so the caller can apply settings and goals, which
  /// live outside the repository) with [BackupData.events] holding only the
  /// newly-added events.
  /// [mode] decides how much is reconciled rather than merged — see [ImportMode].
  ///
  /// Deleting the events the backup does not contain is the whole point of a
  /// restore, and merging cannot substitute for it. The log is append-only, so
  /// un-marking a unit *adds* an `undone` event rather than removing the `done`.
  /// Re-importing a backup taken before the un-mark adds nothing (every id in it
  /// is already present) while the later `undone` still wins — so the unit stays
  /// un-marked and the "restore" restores nothing. Only removing the events
  /// recorded since the backup puts it back.
  Future<BackupData> importInto(
    String targetProfileId,
    String jsonStr, {
    Map<String, String?> knownParents = const {},
    ImportMode mode = ImportMode.merge,
  }) async {
    final data = parse(jsonStr);
    BackupValidator.validate(data, knownParents: knownParents);

    final existingEvents = await _repo.getEvents(targetProfileId);
    final existing = existingEvents.map((e) => e.id).toSet();
    final added = [
      for (final e in data.events)
        if (!existing.contains(e.id)) _rescope(e, targetProfileId),
    ];
    final backupIds = data.events.map((e) => e.id).toSet();
    final stale = mode.replacesLog
        ? [
            for (final e in existingEvents)
              if (!backupIds.contains(e.id)) e.id,
          ]
        : const <String>[];

    // Everything outside the log that the backup does not contain, read *before*
    // the transaction — the same order `_clearSettings` uses, because these are
    // streams and a stream read from inside a transaction is a read of a
    // different world.
    final teardown = mode.replacesCustomisation
        ? await _customisationsToRemove(targetProfileId, data)
        : const _Teardown.empty();

    await _repo.transaction(() async {
      if (stale.isNotEmpty) await _repo.removeEvents(targetProfileId, stale);
      await _repo.addEvents(added);
      for (final n in data.customNodes) {
        await _repo.addCustomNode(targetProfileId, n);
      }
      for (final l in data.customLayers) {
        await _repo.addCustomLayer(targetProfileId, l);
      }
      for (final c in data.layerConfigs) {
        await _repo.setLayerConfig(targetProfileId, c);
      }
      // Deletions last: a node the backup also contains has just been written in
      // its backup shape, and removing first then re-adding would make the same
      // row briefly absent for no reason.
      for (final id in teardown.nodeIds) {
        await _repo.removeCustomNode(targetProfileId, id);
      }
      for (final id in teardown.layerIds) {
        await _repo.removeCustomLayer(targetProfileId, id);
      }
      for (final (nodeId, unitIndex) in teardown.layerConfigs) {
        await _repo.clearLayerConfig(targetProfileId, nodeId, unitIndex);
      }
    });

    return BackupData(
      version: data.version,
      events: added,
      customNodes: data.customNodes,
      customLayers: data.customLayers,
      layerConfigs: data.layerConfigs,
      settings: data.settings,
      goals: data.goals,
      removedEvents: stale.length,
      removedCustomisations: teardown.count,
    );
  }

  /// What a [ImportMode.restoreEverything] into [profileId] would delete.
  ///
  /// Public in spirit and used twice: once by the import itself, and once by the
  /// confirmation dialog, which must be able to say *how much* it is about to
  /// destroy without performing it. Two computations of one answer is how a
  /// preview comes to disagree with the outcome.
  Future<_Teardown> _customisationsToRemove(
      String profileId, BackupData data) async {
    final nodes = await _repo.getCustomNodes(profileId);
    final layers = await _repo.getCustomLayers(profileId);
    final configs = await _repo.getLayerConfigs(profileId);

    final keepNodes = {for (final n in data.customNodes) n.id};
    final keepLayers = {for (final l in data.customLayers) l.id};
    final keepConfigs = {
      for (final c in data.layerConfigs) (c.nodeId, c.unitIndex)
    };

    return _Teardown(
      nodeIds: [
        for (final n in nodes)
          if (!keepNodes.contains(n.id)) n.id,
      ],
      layerIds: [
        for (final l in layers)
          if (!keepLayers.contains(l.id)) l.id,
      ],
      layerConfigs: [
        for (final c in configs)
          if (!keepConfigs.contains((c.nodeId, c.unitIndex)))
            (c.nodeId, c.unitIndex),
      ],
    );
  }

  /// How many customisations a [ImportMode.restoreEverything] of [jsonStr] would
  /// delete from [profileId] — the number the confirmation has to show, computed
  /// by the same code that will do the deleting.
  Future<int> customisationsAtRisk(String profileId, String jsonStr) async =>
      (await _customisationsToRemove(profileId, parse(jsonStr))).count;

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

/// The rows a [ImportMode.restoreEverything] has to delete, by kind.
///
/// Kept as one value rather than loose lists threaded through two methods, so
/// the count the user is shown and the deletions performed cannot come apart.
class _Teardown {
  const _Teardown({
    required this.nodeIds,
    required this.layerIds,
    required this.layerConfigs,
  });

  const _Teardown.empty()
      : nodeIds = const [],
        layerIds = const [],
        layerConfigs = const [];

  final List<String> nodeIds;
  final List<String> layerIds;
  final List<(String, int)> layerConfigs;

  int get count => nodeIds.length + layerIds.length + layerConfigs.length;
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
  /// ambitious — Shas entire is ~2,711 dapim, and even a daily habit tracked for
  /// a lifetime is tens of thousands, so 100,000 is well beyond anything real
  /// while still bounding what *Finish all* can plan in a single batch. Shared
  /// with the add-node form, so the importer and the UI agree on the ceiling.
  static const maxUnitCount = 100000;

  /// Throws [BackupFormatException] on the first problem found.
  static void validate(BackupData data,
      {Map<String, String?> knownParents = const {}}) {
    _validateNodes(data.customNodes, knownParents);
    _validateEvents(data.events);
    _validateLayers(data.customLayers);
    _validateConfigs(data.layerConfigs, 'mefarshim');
  }

  static void _validateNodes(
      List<CatalogNode> nodes, Map<String, String?> knownParents) {
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
      if (!byId.containsKey(parent) && !knownParents.containsKey(parent)) {
        throw BackupFormatException(
            '“${n.name}” is filed under a sefer that does not exist '
            '(parent $parent).');
      }
    }

    // Cycle check, over the *merged* parent map — the backup's rows overlaid on
    // the catalog the app already knows. A backup node whose id matches a
    // built-in is an override that *replaces* that node's parent, so a single
    // row can re-parent a built-in beneath its own descendant (`{shas ->
    // shas.berachos}` when the catalog has `shas.berachos -> shas`). Every id in
    // that loop is "known", so walking only the backup's own rows — as this once
    // did — cannot see it, and the loop lands in SQLite and empties the tree.
    //
    // Any cycle the backup introduces must contain at least one backup node
    // (the known catalog alone is a valid tree), so starting from each backup
    // node and following merged parents reaches it.
    final parentOf = <String, String?>{...knownParents};
    for (final n in nodes) {
      parentOf[n.id] = n.parentId;
    }
    for (final start in nodes) {
      var current = parentOf[start.id];
      var steps = 0;
      while (current != null && parentOf.containsKey(current)) {
        if (current == start.id) {
          throw BackupFormatException(
              '“${start.name}” is its own ancestor — the file has a loop in its '
              'sefer hierarchy.');
        }
        if (++steps > parentOf.length) {
          throw const BackupFormatException(
              'The custom sefer hierarchy contains a loop.');
        }
        current = parentOf[current];
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
