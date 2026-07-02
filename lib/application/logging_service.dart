import 'package:uuid/uuid.dart';

import '../domain/entities/enums.dart';
import '../domain/entities/learning_event.dart';
import '../domain/repositories/progress_repository.dart';

/// Creates and appends [LearningEvent]s, applying the "auto date/time unless the
/// user supplies one" rule (ARCHITECTURE.md §2.2).
///
/// [now] and [idGen] are injectable so the service is deterministic under test.
class LoggingService {
  LoggingService({
    required ProgressRepository repository,
    required String profileId,
    DateTime Function()? now,
    String Function()? idGen,
  })  : _repo = repository,
        _profileId = profileId,
        _now = now ?? DateTime.now,
        _idGen = idGen ?? const Uuid().v4;

  final ProgressRepository _repo;
  final String _profileId;
  final DateTime Function() _now;
  final String Function() _idGen;

  Future<LearningEvent> log({
    required String nodeId,
    required int unitIndex,
    required EventAction action,
    DateTime? occurredAt,
    int? durationMin,
    String? note,
  }) async {
    final now = _now();
    final event = LearningEvent(
      id: _idGen(),
      profileId: _profileId,
      nodeId: nodeId,
      unitIndex: unitIndex,
      action: action,
      occurredAt: occurredAt ?? now, // auto-fill only when not supplied
      loggedAt: now,
      durationMin: durationMin,
      note: note,
    );
    await _repo.addEvent(event);
    return event;
  }

  Future<LearningEvent> markDone(String nodeId, int unitIndex,
          {DateTime? occurredAt, int? durationMin, String? note}) =>
      log(
        nodeId: nodeId,
        unitIndex: unitIndex,
        action: EventAction.done,
        occurredAt: occurredAt,
        durationMin: durationMin,
        note: note,
      );

  Future<LearningEvent> markUndone(String nodeId, int unitIndex) =>
      log(nodeId: nodeId, unitIndex: unitIndex, action: EventAction.undone);

  /// Record a chazara (review) pass over an already-learned unit.
  Future<LearningEvent> markReview(String nodeId, int unitIndex,
          {DateTime? occurredAt}) =>
      log(
        nodeId: nodeId,
        unitIndex: unitIndex,
        action: EventAction.reviewed,
        occurredAt: occurredAt,
      );
}
