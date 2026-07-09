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
    String? haara,
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
      haara: haara,
      layers: layers,
    );
    await _repo.addEvent(event);
    return event;
  }

  Future<LearningEvent> markDone(String nodeId, int unitIndex,
          {DateTime? occurredAt,
          int? durationMin,
          String? note,
          String? haara,
          List<String> layers = const [mainLayerId]}) =>
      log(
        nodeId: nodeId,
        unitIndex: unitIndex,
        action: EventAction.done,
        occurredAt: occurredAt,
        durationMin: durationMin,
        note: note,
        haara: haara,
        layers: layers,
      );

  Future<LearningEvent> markUndone(String nodeId, int unitIndex,
          {List<String> layers = const [mainLayerId]}) =>
      log(
          nodeId: nodeId,
          unitIndex: unitIndex,
          action: EventAction.undone,
          layers: layers);

  /// Edit the annotations (learned-at date/time, duration, note, haara) of an
  /// existing event. Null [durationMin]/[note]/[haara] clear the field. The
  /// done-set is unchanged.
  Future<LearningEvent> editDetails(
    LearningEvent event, {
    required DateTime occurredAt,
    required int? durationMin,
    required String? note,
    required String? haara,
  }) async {
    final updated = event.withDetails(
      occurredAt: occurredAt,
      durationMin: durationMin,
      note: note,
      haara: haara,
    );
    await _repo.updateEvent(updated);
    return updated;
  }

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
