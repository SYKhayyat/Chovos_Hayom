import '../entities/enums.dart';
import '../entities/learning_event.dart';
import 'fold_log.dart';

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
  /// Reads the shared [LogFold], which already resolved membership in **append
  /// order** (`loggedAt`, then `id`) — exactly how `RollUp` computes `learned` —
  /// so the line's final value always equals the headline `learned` count, even
  /// after a unit is un-marked or a `done` is re-logged with a backdated date.
  /// Each currently-done unit is bucketed by its representative (latest) `done`
  /// date; un-marked units drop out entirely rather than leaving a dip in an
  /// otherwise-cumulative line. Folding once and reading it here replaces a
  /// second sort of the whole log.
  static List<SeriesPoint> cumulative(LogFold fold) {
    final perDay = <DateTime, int>{};
    for (final byUnit in fold.doneAtByNode.values) {
      for (final occurred in byUnit.values) {
        final key = _dayKey(occurred);
        perDay[key] = (perDay[key] ?? 0) + 1;
      }
    }
    if (perDay.isEmpty) return const [];

    final days = perDay.keys.toList()..sort();
    var running = 0;
    return [for (final day in days) SeriesPoint(day, running += perDay[day]!)];
  }
}
