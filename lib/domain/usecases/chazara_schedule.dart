import '../entities/layer.dart';
import 'fold_log.dart';
import 'layer_requirements.dart';

/// A unit that is due (or overdue) for a chazara (review) pass.
class ChazaraItem {
  const ChazaraItem({
    required this.nodeId,
    required this.unitIndex,
    required this.reviewCount,
    required this.lastLearned,
    required this.daysOverdue,
  });

  final String nodeId;
  final int unitIndex;

  /// How many review passes have already happened.
  final int reviewCount;

  /// When the unit was last touched (learned or reviewed).
  final DateTime lastLearned;

  /// Days past the point it became due (0 = due today).
  final int daysOverdue;
}

/// Spaced-repetition schedule for chazara. A learned unit becomes due for review
/// after an interval that grows with each pass, so freshly-learned material comes
/// back sooner and well-reviewed material comes back later. Pure.
class ChazaraSchedule {
  const ChazaraSchedule._();

  /// Default days after the last pass before the next review is due, indexed by
  /// how many reviews have already happened. Past the end, the last interval
  /// repeats. Fully overridable per profile — this is only the starting point.
  static const defaultIntervals = <int>[1, 3, 7, 16, 35, 70];

  static int intervalFor(int reviewCount, [List<int> intervals = defaultIntervals]) {
    if (intervals.isEmpty) return defaultIntervals.last;
    return intervals[reviewCount < intervals.length
        ? reviewCount
        : intervals.length - 1];
  }

  /// Units currently due for review, most overdue first. A unit is included only
  /// if it is currently marked done and enough time has elapsed since its last
  /// pass. Un-marking a unit drops it from the schedule. [intervals] overrides
  /// the spacing.
  ///
  /// Reads the shared [LogFold] instead of re-sorting and re-folding the log:
  /// last-touch date and review count are exactly what the fold already tracks,
  /// and this recomputes on the same invalidation the fold does. It also means
  /// the schedule never has to pack (nodeId, unit) into a string and pick it
  /// apart again — the nested maps carry both directly.
  ///
  /// [required] gates completeness: `touchedAtByNode` carries an entry for any
  /// unit with a `done` event, *including* one where only an optional meforish
  /// was ticked and the required set is unmet. Passing the resolver keeps the
  /// promise the doc above makes — "only if it is currently marked done" — by
  /// dropping units whose required layers aren't all present. With it null the
  /// requirement is the text alone (`{main}`), the pre-layers behaviour.
  static List<ChazaraItem> due(LogFold fold, DateTime now,
      {List<int> intervals = defaultIntervals, LayerRequirements? required}) {
    final today = _dayNumber(now);
    final out = <ChazaraItem>[];
    fold.touchedAtByNode.forEach((nodeId, byUnit) {
      byUnit.forEach((unitIndex, last) {
        final req = required?.forUnit(nodeId, unitIndex) ?? const {mainLayerId};
        final have = fold.completedLayers(nodeId, unitIndex);
        if (!req.every(have.contains)) return;
        final rc = fold.reviewCount(nodeId, unitIndex);
        final overdue = today - (_dayNumber(last) + intervalFor(rc, intervals));
        if (overdue < 0) return;
        out.add(ChazaraItem(
          nodeId: nodeId,
          unitIndex: unitIndex,
          reviewCount: rc,
          lastLearned: last,
          daysOverdue: overdue,
        ));
      });
    });
    out.sort((a, b) => b.daysOverdue.compareTo(a.daysOverdue));
    return out;
  }

  /// DST-safe whole-day ordinal in UTC.
  static int _dayNumber(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
}
