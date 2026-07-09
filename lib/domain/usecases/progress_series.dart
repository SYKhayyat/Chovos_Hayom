import '../entities/enums.dart';
import '../entities/learning_event.dart';

/// A point on the cumulative-progress line: [day] and the running total of net
/// units learned up to and including that day.
class SeriesPoint {
  const SeriesPoint(this.day, this.cumulative);
  final DateTime day;
  final int cumulative;
}

/// Derives time-series views of the log for charts and heatmaps. Pure.
class ProgressSeries {
  const ProgressSeries._();

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Net units learned per calendar day (done = +1, undone = -1). Days with no
  /// activity are omitted. Keyed by midnight-local.
  static Map<DateTime, int> dailyDeltas(Iterable<LearningEvent> events) {
    final map = <DateTime, int>{};
    for (final e in events) {
      final delta = switch (e.action) {
        EventAction.done => 1,
        EventAction.undone => -1,
        EventAction.reviewed => 0,
      };
      if (delta == 0) continue;
      final key = _dayKey(e.occurredAt);
      map[key] = (map[key] ?? 0) + delta;
    }
    return map;
  }

  /// Distinct units marked done per calendar day (for an activity heatmap). A
  /// unit re-marked the same day counts once, matching the set-based `learned`.
  static Map<DateTime, int> dailyDone(Iterable<LearningEvent> events) {
    final byDay = <DateTime, Set<String>>{};
    for (final e in events) {
      if (e.action != EventAction.done) continue;
      (byDay[_dayKey(e.occurredAt)] ??= <String>{})
          .add('${e.nodeId} ${e.unitIndex}');
    }
    return {for (final entry in byDay.entries) entry.key: entry.value.length};
  }

  /// Cumulative distinct-units-learned line: a monotonic running total of the
  /// units *currently* learned, each placed on the day it was learned. Empty if
  /// nothing is currently done.
  ///
  /// Membership is resolved in **append order** (`loggedAt`, then `id`) — exactly
  /// how `FoldLog`/`RollUp` compute `learned` — so the line's final value always
  /// equals the headline `learned` count, even after a unit is un-marked or a
  /// `done` is re-logged with a backdated date. Each currently-done unit is
  /// bucketed by its representative (latest) `done` date; un-marked units drop
  /// out entirely rather than leaving a dip in an otherwise-cumulative line.
  static List<SeriesPoint> cumulative(Iterable<LearningEvent> events) {
    final ordered = events
        .where((e) => e.action != EventAction.reviewed)
        .toList()
      ..sort((a, b) {
        final byLogged = a.loggedAt.compareTo(b.loggedAt);
        return byLogged != 0 ? byLogged : a.id.compareTo(b.id);
      });
    if (ordered.isEmpty) return const [];

    // Representative learned-date per unit still done (later done wins; undone
    // drops it) — the same fold as the authoritative `learned` count.
    final doneAt = <String, DateTime>{};
    for (final e in ordered) {
      final unitKey = '${e.nodeId} ${e.unitIndex}';
      if (e.action == EventAction.done) {
        doneAt[unitKey] = e.occurredAt;
      } else if (e.action == EventAction.undone) {
        doneAt.remove(unitKey);
      }
    }
    if (doneAt.isEmpty) return const [];

    final perDay = <DateTime, int>{};
    for (final occurred in doneAt.values) {
      final key = _dayKey(occurred);
      perDay[key] = (perDay[key] ?? 0) + 1;
    }
    final days = perDay.keys.toList()..sort();
    var running = 0;
    return [for (final day in days) SeriesPoint(day, running += perDay[day]!)];
  }
}
