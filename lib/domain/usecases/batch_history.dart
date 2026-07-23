import '../entities/enums.dart';
import '../entities/learning_event.dart';

/// One bulk action, reconstructed from the events it wrote.
class BulkBatch {
  const BulkBatch({
    required this.id,
    required this.appliedAt,
    required this.action,
    required this.unitsAffected,
    required this.nodeIds,
  });

  /// The shared [LearningEvent.batchId] of every event in this batch.
  final String id;

  /// When the batch was written ([LearningEvent.loggedAt] — every event of a
  /// batch shares one).
  final DateTime appliedAt;

  /// What the batch did. A batch is homogeneous: finish writes only `done`,
  /// clear only `undone`.
  final EventAction action;

  /// How many units the batch touched (one event per unit).
  final int unitsAffected;

  /// Every leaf the batch wrote to, in the order first seen. A leaf-level action
  /// has one; a category cascade has one per descendant leaf.
  final List<String> nodeIds;

  bool get isFinish => action == EventAction.done;
}

/// Derives the list of undoable bulk actions by grouping the log on
/// [LearningEvent.batchId].
///
/// Nothing about the undo list is stored: it is a fold over the same event log
/// that everything else derives from, so it can never drift from what actually
/// happened. Undoing a batch deletes exactly its events, which is why the batch
/// stays revertible days later rather than only while a snackbar is on screen.
class BatchHistory {
  const BatchHistory._();

  /// All bulk batches in [events], most recent first. Events with no `batchId`
  /// (ordinary single marks) are ignored — they are undone in place.
  static List<BulkBatch> of(Iterable<LearningEvent> events, {int? limit}) {
    final byId = <String, _Accumulator>{};
    for (final e in events) {
      final batchId = e.batchId;
      if (batchId == null) continue;
      (byId[batchId] ??= _Accumulator(batchId, e)).add(e);
    }
    final out = [for (final a in byId.values) a.build()]
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    if (limit != null && out.length > limit) out.removeRange(limit, out.length);
    return out;
  }
}

class _Accumulator {
  _Accumulator(this.id, LearningEvent first)
      : appliedAt = first.loggedAt,
        action = first.action;

  final String id;
  final DateTime appliedAt;
  final EventAction action;
  final List<String> nodeIds = [];
  final Set<String> _seenNodes = {};
  int units = 0;

  void add(LearningEvent e) {
    units++;
    if (_seenNodes.add(e.nodeId)) nodeIds.add(e.nodeId);
  }

  BulkBatch build() => BulkBatch(
        id: id,
        appliedAt: appliedAt,
        action: action,
        unitsAffected: units,
        nodeIds: nodeIds,
      );
}
