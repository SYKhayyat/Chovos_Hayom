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
    this.maxBatchSize = defaultMaxBatchSize,
  }) : _repo = repository,
       _now = now ?? DateTime.now,
       _idGen = idGen ?? const Uuid().v4 {
    if (maxBatchSize <= 0) {
      throw ArgumentError.value(maxBatchSize, 'maxBatchSize');
    }
  }

  static const defaultMaxBatchSize = 500;

  final ProgressRepository _repo;
  final String profileId;
  final DateTime Function() _now;
  final String Function() _idGen;
  final int maxBatchSize;

  Future<LearningEvent> log({
    required String nodeId,
    required int unitIndex,
    required EventAction action,
    DateTime? occurredAt,
    int? durationMin,
    String? note,
    String? planId,
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
      planId: planId,
    );
    await _repo.addEvent(event);
    return event;
  }

  /// Mark [unitIndex] of [nodeId] done.
  ///
  /// [occurredAt] is the day the work is *for*, which is not always today — a
  /// tick made on Friday for last Thursday belongs to Thursday. [planId] names
  /// the plan that asked for it, and is null for a tick made in the unit grid:
  /// that one is a claim about the learner and belongs to no plan, which is what
  /// keeps a grid tick from adding to a plan and a grid un-tick from removing
  /// from one.
  Future<LearningEvent> markDone(
    String nodeId,
    int unitIndex, {
    DateTime? occurredAt,
    int? durationMin,
    String? note,
    String? planId,
    List<String> layers = const [mainLayerId],
  }) => log(
    nodeId: nodeId,
    unitIndex: unitIndex,
    action: EventAction.done,
    occurredAt: occurredAt,
    durationMin: durationMin,
    note: note,
    planId: planId,
    layers: layers,
  );

  /// Take a tick back.
  ///
  /// **[occurredAt] names the day being taken back**, and this is the same
  /// parameter [markDone] has rather than a separate concept: a tick carries the
  /// day it is for, so an un-tick carries the day it is undoing. Not "the latest
  /// one" — you can tick things in the past, and an un-tick that reached for the
  /// most recent would take back work you did not mean to touch.
  Future<LearningEvent> markUndone(
    String nodeId,
    int unitIndex, {
    DateTime? occurredAt,
    String? planId,
    List<String> layers = const [mainLayerId],
  }) => log(
    nodeId: nodeId,
    unitIndex: unitIndex,
    action: EventAction.undone,
    occurredAt: occurredAt,
    planId: planId,
    layers: layers,
  );

  /// Append many marks in bounded transactions, all sharing a single timestamp
  /// and a single `batchId` — the backing operation for bulk finish/clear. The
  /// shared id is what makes the action undoable later from the log alone.
  Future<List<LearningEvent>> logBatch(
    List<BulkMark> marks, {
    DateTime? occurredAt,
  }) async {
    if (marks.isEmpty) return const [];
    final now = _now();
    final batchId = _idGen();
    final events = <LearningEvent>[];
    for (var start = 0; start < marks.length; start += maxBatchSize) {
      final end = start + maxBatchSize < marks.length
          ? start + maxBatchSize
          : marks.length;
      final chunk = <LearningEvent>[
        for (final m in marks.sublist(start, end))
          LearningEvent(
            id: _idGen(),
            profileId: profileId,
            nodeId: m.nodeId,
            unitIndex: m.unitIndex,
            action: m.action,
            occurredAt: occurredAt ?? now,
            loggedAt: now,
            layers: m.layers,
            batchId: batchId,
          ),
      ];
      await _repo.addEvents(chunk);
      events.addAll(chunk);
    }
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
  Future<LearningEvent> markReview(
    String nodeId,
    int unitIndex, {
    DateTime? occurredAt,
    int? durationMin,
    String? note,
    List<String> layers = const [mainLayerId],
  }) => log(
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
