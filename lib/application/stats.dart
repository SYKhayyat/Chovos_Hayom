import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day.dart';
import '../core/equality.dart';
import '../domain/usecases/chazara_schedule.dart';
import '../domain/usecases/predictor.dart';
import '../domain/usecases/progress_series.dart';
import '../domain/usecases/siyum.dart';
import 'providers.dart';
import 'settings.dart';

/// A derived snapshot of overall learning stats for the active profile.
class StatsSummary {
  const StatsSummary({
    required this.learned,
    required this.total,
    required this.streak,
    required this.avgPerDay,
    required this.projectedFinish,
    required this.series,
    required this.dailyActivity,
    required this.totalMinutes,
    required this.minutesThisMonth,
  });

  final int learned;
  final int total;
  final int streak;
  final double avgPerDay;
  final Day? projectedFinish;
  final List<SeriesPoint> series;
  final Map<Day, int> dailyActivity;

  /// Total minutes ever logged (from sessions that recorded a duration).
  final int totalMinutes;

  /// Minutes logged since the start of the current month.
  final int minutesThisMonth;

  double get percent => total <= 0 ? 0 : 100 * learned / total;
  int get remaining => total - learned;

  /// Scalars first, collections last, and both collections are compared.
  ///
  /// [statsProvider] re-derives on every log change *and* on every clock tick,
  /// and the Statistics screen is one of the two places that watch it. The
  /// scalar prefix short-circuits the case that dominates — a marked daf moves
  /// `learned` on the first comparison — so the walk over [series] and
  /// [dailyActivity] only ever happens when everything else already matched,
  /// which is the midnight-tick and app-resume case this is here to absorb.
  @override
  bool operator ==(Object other) =>
      other is StatsSummary &&
      other.learned == learned &&
      other.total == total &&
      other.streak == streak &&
      other.avgPerDay == avgPerDay &&
      other.projectedFinish == projectedFinish &&
      other.totalMinutes == totalMinutes &&
      other.minutesThisMonth == minutesThisMonth &&
      listEquals(other.series, series) &&
      mapEquals(other.dailyActivity, dailyActivity);

  /// Shallow, like `ProgressNode.hashCode` and for the same reason: nothing
  /// keys a map on one of these, and hashing the series would walk it. Equal
  /// objects only have to *share* a hash; collisions are legal.
  @override
  int get hashCode => Object.hash(learned, total, streak, avgPerDay,
      projectedFinish, totalMinutes, minutesThisMonth, series.length);
}

/// Fires once at every local midnight, and whenever [invalidateClock] is called
/// (on app resume). Everything date-dependent hangs off this.
///
/// Without it nothing in the app is time-reactive: the streak, the "you haven't
/// learned today" nudge, the chazara due badge and today's Daf Yomi all stay on
/// yesterday's answer until some unrelated event happens to force a rebuild. On
/// desktop, where the app stays open for days, that is plainly visible.
///
/// The timer targets the next midnight rather than polling, so an idle app does
/// no work, and it is cancelled with the provider so it can't outlive a test.
final _dayTickProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  Timer? timer;

  void scheduleNextMidnight() {
    final now = DateTime.now();
    // A second past midnight, so the new day is unambiguously the current one.
    // Tomorrow's midnight comes from `Day`, which counts days rather than
    // adding 24 hours, so the tick lands on the actual local midnight even on
    // the two nights a year that are not 24 hours long.
    final next = (Day.of(now) + 1).midnight.add(const Duration(seconds: 1));
    timer = Timer(next.difference(now), () {
      if (!controller.isClosed) controller.add(DateTime.now());
      scheduleNextMidnight();
    });
  }

  scheduleNextMidnight();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Injectable clock. Overridden wholesale in tests, which is why it stays a
/// plain `DateTime Function()` — watching the tick here means every dependent
/// provider re-derives when the day rolls over, without any of them knowing
/// that time is what changed.
///
/// **The closure is the whole mechanism, not a style choice.** This read
/// `return DateTime.now;` — a static method tear-off, which Dart canonicalises
/// to one object. So the provider rebuilt on every tick and then handed back a
/// value `==` to the previous one, Riverpod propagated nothing, and the midnight
/// timer and [invalidateClock] both fired into a wall. Today's Daf Yomi stayed
/// frozen at whichever day the app was opened on for the life of the process;
/// the streak and the chazara badge were rescued only by accident, because they
/// also watch the log. A fresh closure per build is never `==` to the last one,
/// which is what makes the tick a change. No test caught it because all 19
/// overrides pass `() => fixedDate`, a fresh closure — the suite was
/// structurally incapable of observing it. `provider_notify_test.dart` now
/// watches the *real* provider through an invalidation, deliberately without an
/// override, which is the only way this class of defect is visible at all.
final clockProvider = Provider<DateTime Function()>((ref) {
  ref.watch(_dayTickProvider);
  return () => DateTime.now();
});

/// Force everything date-dependent to re-derive. Called when the app returns to
/// the foreground: a suspended process gets no timers, so coming back after a
/// day (or after the device slept through midnight) must not show stale dates.
void invalidateClock(WidgetRef ref) => ref.invalidate(_dayTickProvider);

/// The learning pace: distinct units per day over the last thirty.
///
/// **A provider because it has more than one consumer.** [statsProvider] needs
/// it for the projected finish date and the Statistics tile, and
/// `goalStatusProvider` needs the same number for every goal — and computed it
/// itself, per goal, per rebuild. N goals therefore cost N+1 identical scans of
/// the whole event log on every mark and every clock tick. Derived once here,
/// they all read one `double`, which has real `==`, so a re-derivation that
/// lands on the same pace notifies nobody at all.
final paceProvider = Provider<double>((ref) {
  final activity = ref.watch(logActivityProvider).asData?.value;
  if (activity == null) return 0;
  return activity.averagePerDay(Day.of(ref.watch(clockProvider)()),
      windowDays: 30);
});

/// Overall stats for the active profile, derived from the log. Null while the
/// catalog or event log is still loading.
///
/// **Watches the two indexes, never the log.** This used to hold a [LogFold] and
/// then make five more passes over the event list that produced it — the pace,
/// the streak, the heatmap, the total minutes and the month's minutes, each a
/// full walk, on every mark and every midnight tick. `fold_log.dart` opens by
/// explaining that the fold exists to replace exactly that; this was where the
/// passes had grown back. [LogActivity] answers all five off one pass, and the
/// answers below are map lookups.
final statsProvider = Provider<StatsSummary?>((ref) {
  final forest = ref.watch(progressForestProvider).asData?.value;
  final fold = ref.watch(foldProvider).asData?.value;
  final activity = ref.watch(logActivityProvider).asData?.value;
  if (forest == null || fold == null || activity == null) return null;

  // Aggregate every root, not just the first — a top-level custom sefer is a
  // second root and must be counted in the overall totals/projection.
  var learned = 0;
  var total = 0;
  for (final root in forest) {
    learned += root.learned;
    total += root.total;
  }
  final remaining = total - learned;
  final now = ref.watch(clockProvider)();
  final today = Day.of(now);
  final avg = ref.watch(paceProvider);

  return StatsSummary(
    learned: learned,
    total: total,
    streak: activity.streakEndingAt(today),
    avgPerDay: avg,
    projectedFinish: avg > 0
        ? Predictor.finishDate(remaining: remaining, perDay: avg, from: today)
        : null,
    series: ProgressSeries.cumulative(fold),
    // The index's own map, handed through unchanged — `StatsSummary.==` checks
    // identity before walking it, so a tick that changed nothing compares the
    // heatmap in one pointer read.
    dailyActivity: activity.dailyCounts,
    totalMinutes: activity.totalMinutes,
    minutesThisMonth: activity.minutesSince(Day.of(DateTime(now.year, now.month, 1))),
  );
});

/// Units currently due for a chazara (review) pass, most overdue first.
final chazaraDueProvider = Provider<List<ChazaraItem>>((ref) {
  final fold = ref.watch(foldProvider).asData?.value;
  if (fold == null) return const [];
  final intervals = ref.watch(settingsProvider.select((s) => s.chazaraIntervals));
  final layers = ref.watch(layerRolesProvider);
  final items = ChazaraSchedule.due(fold, ref.watch(clockProvider)(),
      intervals: intervals, layers: layers);
  final catalog = ref.watch(mergedCatalogProvider).asData?.value;
  if (catalog == null) return items;
  // Drop units whose node has since been hidden or removed, or that now sit
  // above a lowered unitCount — the schedule reads the log, which still
  // remembers them, but they can't be shown (the row would render a raw id) or
  // reviewed, so they must not sit in the list or the due-count badge.
  return [
    for (final item in items)
      if (catalog.byId(item.nodeId)?.containsUnit(item.unitIndex) ?? false)
        item,
  ];
});

/// Completed nodes at every level (siyumim), most-recently-finished first.
final siyumimProvider = Provider<List<Siyum>>((ref) {
  final forest = ref.watch(progressForestProvider).asData?.value;
  final fold = ref.watch(foldProvider).asData?.value;
  if (forest == null || fold == null) return const [];
  return SiyumFinder.completed(forest, fold);
});
