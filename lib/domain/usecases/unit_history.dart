import '../entities/enums.dart';
import '../entities/learning_event.dart';

/// The recorded details of a single unit: the [done] event that currently marks
/// it learned (with its date/duration/note), and every chazara (review) pass
/// logged against it. Pure; derived from the log, never stored.
class UnitHistory {
  const UnitHistory({required this.done, required this.reviews});

  /// The representative `done` event — the most recent one still in effect — or
  /// null if the unit is not currently marked learned.
  final LearningEvent? done;

  /// Review passes logged while the unit was learned, oldest first.
  final List<LearningEvent> reviews;

  bool get isDone => done != null;
  int get reviewCount => reviews.length;

  /// Total minutes across the done event and all reviews that carry a duration.
  int get totalMinutes {
    var sum = done?.durationMin ?? 0;
    for (final r in reviews) {
      sum += r.durationMin ?? 0;
    }
    return sum;
  }
}

/// Extracts the [UnitHistory] for one (node, unit) from the event log.
class UnitHistoryFinder {
  const UnitHistoryFinder._();

  static UnitHistory forUnit(
    Iterable<LearningEvent> events,
    String nodeId,
    int unitIndex,
  ) {
    // Only this unit's events, in canonical append order.
    final own = events
        .where((e) => e.nodeId == nodeId && e.unitIndex == unitIndex)
        .toList()
      ..sort((a, b) {
        final c = a.loggedAt.compareTo(b.loggedAt);
        return c != 0 ? c : a.id.compareTo(b.id);
      });

    LearningEvent? done;
    final reviews = <LearningEvent>[];
    for (final e in own) {
      switch (e.action) {
        case EventAction.done:
          // A later `done` supersedes an earlier one's annotations.
          done = e;
          break;
        case EventAction.undone:
          // Un-marking clears the unit and any reviews accrued against it.
          done = null;
          reviews.clear();
          break;
        case EventAction.reviewed:
          if (done != null) reviews.add(e);
          break;
      }
    }

    return UnitHistory(done: done, reviews: reviews);
  }
}
