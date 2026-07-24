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

  /// Whole-day ordinal in UTC — a DST-safe integer key for a local calendar day,
  /// the same key `PaceEngine` and `ChazaraSchedule` use. Grouping by this int
  /// rather than by a local `DateTime(y, m, d)` is the whole performance story
  /// here: constructing a *local* DateTime forces a timezone conversion (~230×
  /// slower than the UTC form), and these helpers built one per event, so a
  /// multi-year user paid a second of it opening the Statistics screen. We group
  /// on the cheap ordinal and materialise a DateTime once per *distinct day*.
  static int _dayNumber(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  /// Local midnight for [d]'s calendar day — the representation the chart and
  /// heatmap expect. The expensive call, made once per distinct day, not once
  /// per event.
  static DateTime _localMidnight(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Net units learned per calendar day (done = +1, undone = -1). Days with no
  /// activity are omitted. Keyed by midnight-local.
  static Map<DateTime, int> dailyDeltas(Iterable<LearningEvent> events) {
    final byDay = <int, int>{};
    final dayOf = <int, DateTime>{};
    for (final e in events) {
      final delta = switch (e.action) {
        EventAction.done => 1,
        EventAction.undone => -1,
        EventAction.reviewed => 0,
      };
      if (delta == 0) continue;
      final ord = _dayNumber(e.occurredAt);
      dayOf.putIfAbsent(ord, () => _localMidnight(e.occurredAt));
      byDay[ord] = (byDay[ord] ?? 0) + delta;
    }
    return {for (final e in byDay.entries) dayOf[e.key]!: e.value};
  }

  /// Distinct units marked done per calendar day (for an activity heatmap). A
  /// unit re-marked the same day counts once, matching the set-based `learned`.
  static Map<DateTime, int> dailyDone(Iterable<LearningEvent> events) {
    final byDay = <int, Set<String>>{};
    final dayOf = <int, DateTime>{};
    for (final e in events) {
      if (e.action != EventAction.done) continue;
      final ord = _dayNumber(e.occurredAt);
      dayOf.putIfAbsent(ord, () => _localMidnight(e.occurredAt));
      (byDay[ord] ??= <String>{}).add('${e.nodeId} ${e.unitIndex}');
    }
    return {for (final e in byDay.entries) dayOf[e.key]!: e.value.length};
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
    final perDay = <int, int>{};
    final dayOf = <int, DateTime>{};
    for (final byUnit in fold.doneAtByNode.values) {
      for (final occurred in byUnit.values) {
        final ord = _dayNumber(occurred);
        dayOf.putIfAbsent(ord, () => _localMidnight(occurred));
        perDay[ord] = (perDay[ord] ?? 0) + 1;
      }
    }
    if (perDay.isEmpty) return const [];

    final days = perDay.keys.toList()..sort();
    var running = 0;
    return [
      for (final ord in days) SeriesPoint(dayOf[ord]!, running += perDay[ord]!),
    ];
  }
}
