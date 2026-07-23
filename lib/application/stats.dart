import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/usecases/chazara_schedule.dart';
import '../domain/usecases/pace_engine.dart';
import '../domain/usecases/predictor.dart';
import '../domain/usecases/progress_series.dart';
import '../domain/usecases/siyum.dart';
import '../domain/usecases/time_stats.dart';
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
  final DateTime? projectedFinish;
  final List<SeriesPoint> series;
  final Map<DateTime, int> dailyActivity;

  /// Total minutes ever logged (from sessions that recorded a duration).
  final int totalMinutes;

  /// Minutes logged since the start of the current month.
  final int minutesThisMonth;

  double get percent => total <= 0 ? 0 : 100 * learned / total;
  int get remaining => total - learned;
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
    final next = DateTime(now.year, now.month, now.day + 1)
        .add(const Duration(seconds: 1));
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
final clockProvider = Provider<DateTime Function()>((ref) {
  ref.watch(_dayTickProvider);
  return DateTime.now;
});

/// Force everything date-dependent to re-derive. Called when the app returns to
/// the foreground: a suspended process gets no timers, so coming back after a
/// day (or after the device slept through midnight) must not show stale dates.
void invalidateClock(WidgetRef ref) => ref.invalidate(_dayTickProvider);

/// Overall stats for the active profile, derived from the log. Null while the
/// catalog or event log is still loading.
final statsProvider = Provider<StatsSummary?>((ref) {
  final forest = ref.watch(progressForestProvider).asData?.value;
  final events = ref.watch(eventsProvider).asData?.value;
  final fold = ref.watch(foldProvider).asData?.value;
  if (forest == null || events == null || fold == null) return null;

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
  final avg = PaceEngine.averagePerDay(events, now: now, windowDays: 30);

  return StatsSummary(
    learned: learned,
    total: total,
    streak: PaceEngine.currentStreak(events, now: now),
    avgPerDay: avg,
    projectedFinish: avg > 0
        ? Predictor.finishDate(remaining: remaining, perDay: avg, from: now)
        : null,
    series: ProgressSeries.cumulative(fold),
    dailyActivity: ProgressSeries.dailyDone(events),
    totalMinutes: TimeStats.totalMinutes(events),
    minutesThisMonth:
        TimeStats.minutesSince(events, DateTime(now.year, now.month, 1)),
  );
});

/// Units currently due for a chazara (review) pass, most overdue first.
final chazaraDueProvider = Provider<List<ChazaraItem>>((ref) {
  final fold = ref.watch(foldProvider).asData?.value;
  if (fold == null) return const [];
  final intervals = ref.watch(settingsProvider.select((s) => s.chazaraIntervals));
  return ChazaraSchedule.due(fold, ref.watch(clockProvider)(),
      intervals: intervals);
});

/// Completed nodes at every level (siyumim), most-recently-finished first.
final siyumimProvider = Provider<List<Siyum>>((ref) {
  final forest = ref.watch(progressForestProvider).asData?.value;
  final fold = ref.watch(foldProvider).asData?.value;
  if (forest == null || fold == null) return const [];
  return SiyumFinder.completed(forest, fold);
});
