import '../../core/day.dart';
import '../entities/enums.dart';
import '../entities/learning_event.dart';
import 'fold_log.dart';

/// A point on the cumulative-progress line: [day] and the running total of net
/// units learned up to and including that day.
class SeriesPoint {
  const SeriesPoint(this.day, this.cumulative);
  final Day day;
  final int cumulative;

  /// So that a `List<SeriesPoint>` can be compared element-wise — [StatsSummary]
  /// holds one, and its `==` is what stops the Statistics screen rebuilding on
  /// a midnight tick that changed nothing.
  @override
  bool operator ==(Object other) =>
      other is SeriesPoint &&
      other.cumulative == cumulative &&
      other.day == day;

  @override
  int get hashCode => Object.hash(day, cumulative);
}

/// Derives time-series views of the log for charts and heatmaps. Pure.
///
/// Everything here groups on [Day], whose identity is an `int` ordinal, so a
/// `Map<Day, …>` costs what a `Map<int, …>` costs. That matters: these helpers
/// once keyed on a local-midnight `DateTime` built per *event*, and a local
/// `DateTime` costs a timezone conversion (~230× the UTC form), so a multi-year
/// user paid about a second of it opening the Statistics screen. Grouping on
/// `Day` keeps that fix and drops the parallel `ordinal -> DateTime` side-maps
/// the previous version needed to carry alongside every result — the day is the
/// key now, so it no longer has to be remembered separately from it.
class ProgressSeries {
  const ProgressSeries._();

  /// Net units learned per calendar day (done = +1, undone = -1). Days with no
  /// activity are omitted.
  static Map<Day, int> dailyDeltas(Iterable<LearningEvent> events) {
    final byDay = <Day, int>{};
    for (final e in events) {
      final delta = switch (e.action) {
        EventAction.done => 1,
        EventAction.undone => -1,
        EventAction.reviewed => 0,
      };
      if (delta == 0) continue;
      final day = Day.of(e.occurredAt);
      byDay[day] = (byDay[day] ?? 0) + delta;
    }
    return byDay;
  }

  /// Distinct units marked done per calendar day (for an activity heatmap). A
  /// unit re-marked the same day counts once, matching the set-based `learned`.
  static Map<Day, int> dailyDone(Iterable<LearningEvent> events) {
    final byDay = <Day, Set<String>>{};
    for (final e in events) {
      if (e.action != EventAction.done) continue;
      (byDay[Day.of(e.occurredAt)] ??= <String>{})
          .add('${e.nodeId} ${e.unitIndex}');
    }
    return {for (final e in byDay.entries) e.key: e.value.length};
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
    final perDay = <Day, int>{};
    for (final byUnit in fold.doneAtByNode.values) {
      for (final occurred in byUnit.values) {
        final day = Day.of(occurred);
        perDay[day] = (perDay[day] ?? 0) + 1;
      }
    }
    if (perDay.isEmpty) return const [];

    final days = perDay.keys.toList()..sort();
    var running = 0;
    return [
      for (final day in days) SeriesPoint(day, running += perDay[day]!),
    ];
  }
}
