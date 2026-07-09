import '../entities/enums.dart';
import '../entities/learning_event.dart';

/// The state derived by folding the event log: which units are done, and how
/// many review passes each has had, per node.
class LogFold {
  const LogFold(this.doneByNode, this.reviewsByNode);

  /// nodeId -> set of unit indices currently marked done.
  final Map<String, Set<int>> doneByNode;

  /// nodeId -> (unit index -> review count).
  final Map<String, Map<int, int>> reviewsByNode;

  Set<int> doneUnits(String nodeId) => doneByNode[nodeId] ?? const {};
  int reviewCount(String nodeId, int unitIndex) =>
      reviewsByNode[nodeId]?[unitIndex] ?? 0;
}

/// Folds an event log into current [LogFold] state.
///
/// This is the single source of truth for "what is learned". `learned` is never
/// stored — it is computed here, which makes `learned > total` impossible by
/// construction (see ARCHITECTURE.md §1).
class FoldLog {
  const FoldLog._();

  /// Fold [events] into current state. Events are processed in **append order**
  /// ([LearningEvent.loggedAt], then [LearningEvent.id] as a stable tiebreak) so
  /// the result is deterministic regardless of input ordering.
  static LogFold fold(Iterable<LearningEvent> events) {
    final sorted = events.toList()
      ..sort((a, b) {
        final c = a.loggedAt.compareTo(b.loggedAt);
        return c != 0 ? c : a.id.compareTo(b.id);
      });

    final done = <String, Set<int>>{};
    final reviews = <String, Map<int, int>>{};

    for (final e in sorted) {
      switch (e.action) {
        case EventAction.done:
          (done[e.nodeId] ??= <int>{}).add(e.unitIndex);
          break;
        case EventAction.undone:
          done[e.nodeId]?.remove(e.unitIndex);
          // Un-marking clears the unit's review history too, so a later re-mark
          // starts fresh (matches ChazaraSchedule and the grid's ↻ badge).
          reviews[e.nodeId]?.remove(e.unitIndex);
          break;
        case EventAction.reviewed:
          final byUnit = reviews[e.nodeId] ??= <int, int>{};
          byUnit[e.unitIndex] = (byUnit[e.unitIndex] ?? 0) + 1;
          break;
      }
    }

    return LogFold(done, reviews);
  }
}
