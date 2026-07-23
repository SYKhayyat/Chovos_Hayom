import 'package:uuid/uuid.dart';

import '../domain/entities/enums.dart';
import '../domain/entities/layer.dart';
import '../domain/entities/learning_event.dart';
import '../domain/repositories/progress_repository.dart';

/// Creates and appends [LearningEvent]s, applying the "auto date/time unless the
/// user supplies one" rule (ARCHITECTURE.md §2.2).
///
/// [now] and [idGen] are injectable so the service is deterministic under test.
class LoggingService {
  LoggingService({
    required ProgressRepository repository,
    required this.profileId,
    DateTime Function()? now,
    String Function()? idGen,
  })  : _repo = repository,
        _now = now ?? DateTime.now,
        _idGen = idGen ?? const Uuid().v4;

  final ProgressRepository _repo;
  final String profileId;
  final DateTime Function() _now;
  final String Function() _idGen;

  Future<LearningEvent> log({
    required String nodeId,
    required int unitIndex,
    required EventAction action,
    DateTime? occurredAt,
    int? durationMin,
    String? note,
    List<String> layers = const [mainLayerId],
  }) async {
    final now = _now();
    final event = LearningEvent(
      id: _idGen(),
      profileId: profileId,
      nodeId: nodeId,
      unitIndex: unitIndex,
      action: action,
      occurredAt: occurredAt ?? now, // auto-fill only when not supplied
      loggedAt: now,
      durationMin: durationMin,
      note: note,
      layers: layers,
    );
    await _repo.addEvent(event);
    return event;
  }

  Future<LearningEvent> markDone(String nodeId, int unitIndex,
          {DateTime? occurredAt,
          int? durationMin,
          String? note,
          List<String> layers = const [mainLayerId]}) =>
      log(
        nodeId: nodeId,
        unitIndex: unitIndex,
        action: EventAction.done,
        occurredAt: occurredAt,
        durationMin: durationMin,
        note: note,
        layers: layers,
      );

  Future<LearningEvent> markUndone(String nodeId, int unitIndex,
          {List<String> layers = const [mainLayerId]}) =>
      log(
          nodeId: nodeId,
          unitIndex: unitIndex,
          action: EventAction.undone,
          layers: layers);

  /// Append many marks in one transaction, all sharing a single timestamp — the
  /// backing operation for bulk finish/clear. Returns the created events (so the
  /// caller can offer an undo by removing them by id). Id/timestamp generation
  /// stays here so event creation has a single owner.
  Future<List<LearningEvent>> logBatch(List<BulkMark> marks,
      {DateTime? occurredAt}) async {
    if (marks.isEmpty) return const [];
    final now = _now();
    final events = [
      for (final m in marks)
        LearningEvent(
          id: _idGen(),
          profileId: profileId,
          nodeId: m.nodeId,
          unitIndex: m.unitIndex,
          action: m.action,
          occurredAt: occurredAt ?? now,
          loggedAt: now,
          layers: m.layers,
        ),
    ];
    await _repo.addEvents(events);
    return events;
  }

  /// Edit the annotations (learned-at date/time, duration, haara) of an existing
  /// event. Null [durationMin]/[note] clear the field. The done-set is unchanged.
  Future<LearningEvent> editDetails(
    LearningEvent event, {
    required DateTime occurredAt,
    required int? durationMin,
    required String? note,
  }) async {
    final updated = event.withDetails(
      occurredAt: occurredAt,
      durationMin: durationMin,
      note: note,
    );
    await _repo.updateEvent(updated);
    return updated;
  }

  /// Record a chazara (review) pass over an already-learned unit. A pass carries
  /// its own date/time, duration, haara, and the [layers] (mefarshim) it covered
  /// — each chazara is defined independently of the main learning and of other
  /// passes.
  Future<LearningEvent> markReview(String nodeId, int unitIndex,
          {DateTime? occurredAt,
          int? durationMin,
          String? note,
          List<String> layers = const [mainLayerId]}) =>
      log(
        nodeId: nodeId,
        unitIndex: unitIndex,
        action: EventAction.reviewed,
        occurredAt: occurredAt,
        durationMin: durationMin,
        note: note,
        layers: layers,
      );
}

/// One item in a [LoggingService.logBatch] call — a single unit's mark. Carries
/// only what a bulk finish/clear needs; timestamps and ids are filled in by the
/// service so every mark in a batch shares them.
class BulkMark {
  const BulkMark({
    required this.nodeId,
    required this.unitIndex,
    required this.action,
    this.layers = const [mainLayerId],
  });

  final String nodeId;
  final int unitIndex;
  final EventAction action;
  final List<String> layers;
}
