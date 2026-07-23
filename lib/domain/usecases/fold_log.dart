import '../entities/enums.dart';
import '../entities/layer.dart';
import '../entities/learning_event.dart';
import 'layer_requirements.dart';

/// The state derived by folding the event log: for each unit of each node, which
/// *layers* are done, how many review passes it has had, when it was learned,
/// when it was last touched, and whether it carries a haara or a duration.
///
/// This is deliberately everything-per-unit rather than a minimal set. Chazara
/// scheduling, the cumulative progress line, siyumim, and the grid's detail dots
/// each used to re-sort and re-fold the whole log to recover one of these — five
/// ordered passes where one will do. Folding once and answering all of them from
/// the result is what keeps a tap on a daf cheap for a user with years of history.
class LogFold {
  const LogFold({
    required this.completedByNode,
    required this.reviewsByNode,
    required this.doneAtByNode,
    required this.touchedAtByNode,
    required this.annotatedByNode,
  });

  /// nodeId -> (unit index -> set of layer ids completed).
  final Map<String, Map<int, Set<String>>> completedByNode;

  /// nodeId -> (unit index -> review count).
  final Map<String, Map<int, int>> reviewsByNode;

  /// nodeId -> (unit index -> when it was *learned*), from the `done` event
  /// currently in force. Un-marking removes it; a later `done` replaces it. This
  /// is the representative date for the cumulative line and for dating a siyum.
  final Map<String, Map<int, DateTime>> doneAtByNode;

  /// nodeId -> (unit index -> when it was last learned *or reviewed*). The
  /// anchor the chazara schedule counts its interval from.
  final Map<String, Map<int, DateTime>> touchedAtByNode;

  /// nodeId -> units whose in-force `done` event carries a haara or a duration.
  /// The grid's "there are details here" dot reads this instead of re-scanning
  /// the log on every rebuild.
  final Map<String, Set<int>> annotatedByNode;

  /// The layers completed for one unit (empty if none).
  Set<String> completedLayers(String nodeId, int unitIndex) =>
      completedByNode[nodeId]?[unitIndex] ?? const {};

  int reviewCount(String nodeId, int unitIndex) =>
      reviewsByNode[nodeId]?[unitIndex] ?? 0;

  /// When [unitIndex] was learned, or null if it is not currently done.
  DateTime? doneAt(String nodeId, int unitIndex) =>
      doneAtByNode[nodeId]?[unitIndex];

  /// When [unitIndex] was last learned or reviewed, or null if not done.
  DateTime? touchedAt(String nodeId, int unitIndex) =>
      touchedAtByNode[nodeId]?[unitIndex];

  bool isAnnotated(String nodeId, int unitIndex) =>
      annotatedByNode[nodeId]?.contains(unitIndex) ?? false;

  /// Units currently *complete* — every required layer is done. With no
  /// [required] resolver the requirement is just the text (`{main}`), which
  /// reproduces the pre-layers behaviour exactly.
  Set<int> doneUnits(String nodeId, [LayerRequirements? required]) {
    final byUnit = completedByNode[nodeId];
    if (byUnit == null) return const {};
    final out = <int>{};
    byUnit.forEach((unit, completed) {
      if (completed.isEmpty) return;
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
    final doneAt = <String, Map<int, DateTime>>{};
    final touchedAt = <String, Map<int, DateTime>>{};
    final annotated = <String, Set<int>>{};

    for (final e in sorted) {
      switch (e.action) {
        case EventAction.done:
          final byUnit = completed[e.nodeId] ??= <int, Set<String>>{};
          (byUnit[e.unitIndex] ??= <String>{}).addAll(e.layers);
          // A later `done` supersedes the earlier one's date and annotations —
          // the same rule UnitHistoryFinder shows the user.
          (doneAt[e.nodeId] ??= <int, DateTime>{})[e.unitIndex] = e.occurredAt;
          (touchedAt[e.nodeId] ??= <int, DateTime>{})[e.unitIndex] = e.occurredAt;
          final hasDetails =
              (e.note != null && e.note!.isNotEmpty) || e.durationMin != null;
          if (hasDetails) {
            (annotated[e.nodeId] ??= <int>{}).add(e.unitIndex);
          } else {
            annotated[e.nodeId]?.remove(e.unitIndex);
          }
        case EventAction.undone:
          final set = completed[e.nodeId]?[e.unitIndex];
          if (set != null) {
            set.removeAll(e.layers);
            if (set.isEmpty) completed[e.nodeId]!.remove(e.unitIndex);
          }
          // Un-marking clears the unit's review history too, so a later re-mark
          // starts fresh (matches ChazaraSchedule and the grid's ↻ badge), and
          // with it every other trace of the unit having been learned.
          reviews[e.nodeId]?.remove(e.unitIndex);
          doneAt[e.nodeId]?.remove(e.unitIndex);
          touchedAt[e.nodeId]?.remove(e.unitIndex);
          annotated[e.nodeId]?.remove(e.unitIndex);
        case EventAction.reviewed:
          // A pass over something not currently learned isn't a chazara of it,
          // so it moves nothing. (UnitHistoryFinder shows the same to the user.)
          if (touchedAt[e.nodeId]?[e.unitIndex] == null) continue;
          final byUnit = reviews[e.nodeId] ??= <int, int>{};
          byUnit[e.unitIndex] = (byUnit[e.unitIndex] ?? 0) + 1;
          touchedAt[e.nodeId]![e.unitIndex] = e.occurredAt;
      }
    }

    return LogFold(
      completedByNode: completed,
      reviewsByNode: reviews,
      doneAtByNode: doneAt,
      touchedAtByNode: touchedAt,
      annotatedByNode: annotated,
    );
  }
}
