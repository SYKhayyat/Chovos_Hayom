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

  /// Count of `done` events per calendar day (for an activity heatmap).
  static Map<DateTime, int> dailyDone(Iterable<LearningEvent> events) {
    final map = <DateTime, int>{};
    for (final e in events) {
      if (e.action != EventAction.done) continue;
      final key = _dayKey(e.occurredAt);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  /// Cumulative net-progress line, one point per active day in chronological
  /// order. Empty if there is no activity.
  static List<SeriesPoint> cumulative(Iterable<LearningEvent> events) {
    final deltas = dailyDeltas(events);
    if (deltas.isEmpty) return const [];
    final days = deltas.keys.toList()..sort();
    var running = 0;
    return [
      for (final day in days) SeriesPoint(day, running += deltas[day]!),
    ];
  }
}
