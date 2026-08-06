import '../../core/day.dart';
import 'fold_log.dart';
import 'log_activity.dart';

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

/// The cumulative-progress line. Pure.
///
/// Groups on [Day], whose identity is an `int` ordinal, so a `Map<Day, …>` costs
/// what a `Map<int, …>` costs. That matters: this file once keyed its maps on a
/// local-midnight `DateTime` built per *event*, and a local `DateTime` costs a
/// timezone conversion (~230× the UTC form), so a multi-year user paid about a
/// second of it opening the Statistics screen.
///
/// It once held two more helpers. `dailyDone` — distinct units learned per day,
/// for the heatmap — asked the raw log a question about *days*, which is
/// [LogActivity]'s axis, and moved there with the other four passes
/// `statsProvider` was making. `dailyDeltas` had no caller outside its own test.
class ProgressSeries {
  const ProgressSeries._();

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
