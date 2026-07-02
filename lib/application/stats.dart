import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/usecases/pace_engine.dart';
import '../domain/usecases/predictor.dart';
import '../domain/usecases/progress_series.dart';
import 'providers.dart';

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
  });

  final int learned;
  final int total;
  final int streak;
  final double avgPerDay;
  final DateTime? projectedFinish;
  final List<SeriesPoint> series;
  final Map<DateTime, int> dailyActivity;

  double get percent => total <= 0 ? 0 : 100 * learned / total;
  int get remaining => total - learned;
}

/// Injectable clock so stats are testable; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Overall stats for the active profile, derived from the log. Null while the
/// catalog or event log is still loading.
final statsProvider = Provider<StatsSummary?>((ref) {
  final forest = ref.watch(progressForestProvider).asData?.value;
  final events = ref.watch(eventsProvider).asData?.value;
  if (forest == null || events == null) return null;

  final root = forest.firstOrNull;
  final learned = root?.learned ?? 0;
  final total = root?.total ?? 0;
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
    series: ProgressSeries.cumulative(events),
    dailyActivity: ProgressSeries.dailyDone(events),
  );
});
