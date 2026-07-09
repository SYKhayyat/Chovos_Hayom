import '../entities/enums.dart';
import '../entities/layer.dart';
import '../entities/learning_event.dart';
import 'layer_requirements.dart';

/// The state derived by folding the event log: which *layers* of each unit are
/// done, and how many review passes each unit has had, per node.
class LogFold {
  const LogFold(this.completedByNode, this.reviewsByNode);

  /// nodeId -> (unit index -> set of layer ids completed).
  final Map<String, Map<int, Set<String>>> completedByNode;

  /// nodeId -> (unit index -> review count).
  final Map<String, Map<int, int>> reviewsByNode;

  /// The layers completed for one unit (empty if none).
  Set<String> completedLayers(String nodeId, int unitIndex) =>
      completedByNode[nodeId]?[unitIndex] ?? const {};

  int reviewCount(String nodeId, int unitIndex) =>
      reviewsByNode[nodeId]?[unitIndex] ?? 0;

  /// Units currently *complete* — every required layer is done. With no
  /// [required] resolver the requirement is just the text (`{main}`), which
  /// reproduces the pre-layers behaviour exactly.
  Set<int> doneUnits(String nodeId, [LayerRequirements? required]) {
    final byUnit = completedByNode[nodeId];
    if (byUnit == null) return const {};
    final out = <int>{};
    byUnit.forEach((unit, completed) {
      final req = required?.forUnit(nodeId, unit) ?? const {mainLayerId};
      if (_subset(req, completed)) out.add(unit);
    });
    return out;
  }

  static bool _subset(Set<String> required, Set<String> have) {
    for (final r in required) {
      if (!have.contains(r)) return false;
    }
    return true;
  }
}

/// Folds an event log into current [LogFold] state.
///
/// This is the single source of truth for "what is learned". Nothing is stored —
/// it is computed here in one pass, which makes `learned > total` impossible by
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

    final completed = <String, Map<int, Set<String>>>{};
    final reviews = <String, Map<int, int>>{};

    for (final e in sorted) {
      switch (e.action) {
        case EventAction.done:
          final byUnit = completed[e.nodeId] ??= <int, Set<String>>{};
          (byUnit[e.unitIndex] ??= <String>{}).addAll(e.layers);
          break;
        case EventAction.undone:
          final set = completed[e.nodeId]?[e.unitIndex];
          if (set != null) {
            set.removeAll(e.layers);
            if (set.isEmpty) completed[e.nodeId]!.remove(e.unitIndex);
          }
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

    return LogFold(completed, reviews);
  }
}
