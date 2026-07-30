import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../core/calendar.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/naming.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final mode = ref.watch(settingsProvider).calendar;
    final now = ref.watch(clockProvider)();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
      body: stats == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SummaryGrid(stats: stats, mode: mode),
                const SizedBox(height: 24),
                Text(l10n.statsProgressOverTime,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(height: 200, child: _ProgressChart(stats: stats)),
                const SizedBox(height: 24),
                Text(l10n.statsActivity,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _Heatmap(activity: stats.dailyActivity, now: now),
              ],
            ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.stats, required this.mode});
  final StatsSummary stats;
  final CalendarMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final finish = stats.projectedFinish == null
        ? l10n.statsNone
        : DateDisplay.format(stats.projectedFinish!, mode);
    String time(int minutes) =>
        minutes <= 0 ? l10n.statsNone : formatMinutes(l10n, minutes);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _StatTile(
            label: l10n.statsOverall,
            value: l10n.statsPercentValue(stats.percent.toStringAsFixed(1))),
        _StatTile(
            label: l10n.statsLearned,
            // The space-padded fraction reverses under Hebrew — see
            // [ltrNumerals].
            value: ltrNumerals(
                l10n.statsLearnedValue(stats.learned, stats.total))),
        _StatTile(
            label: l10n.statsStreak,
            value: l10n.statsStreakValue(stats.streak)),
        _StatTile(
            label: l10n.statsAvgPerDay,
            value: stats.avgPerDay.toStringAsFixed(2)),
        _StatTile(
            label: l10n.statsTimeLearned, value: time(stats.totalMinutes)),
        _StatTile(
            label: l10n.statsTimeThisMonth,
            value: time(stats.minutesThisMonth)),
        _StatTile(
            label: l10n.statsProjectedSiyum, value: finish, wide: true),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.wide = false});
  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _ProgressChart extends StatelessWidget {
  const _ProgressChart({required this.stats});
  final StatsSummary stats;

  @override
  Widget build(BuildContext context) {
    if (stats.series.length < 2) {
      return Center(
          child: Text(AppLocalizations.of(context).statsNeedMoreData));
    }
    final first = stats.series.first.day;
    final spots = [
      for (final p in stats.series)
        FlSpot(p.day.difference(first).inDays.toDouble(), p.cumulative.toDouble()),
    ];
    final scheme = Theme.of(context).colorScheme;
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: scheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.activity, required this.now});
  final Map<DateTime, int> activity;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime(now.year, now.month, now.day);
    const weeks = 12;
    const days = weeks * 7;
    final maxCount =
        activity.values.isEmpty ? 1 : activity.values.reduce((a, b) => a > b ? a : b);

    // Columns = weeks, rows = day-of-week.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var w = 0; w < weeks; w++)
            Column(
              children: [
                for (var d = 0; d < 7; d++)
                  Builder(builder: (_) {
                    // Step by calendar day through the DateTime constructor,
                    // which normalises an out-of-range day to the right local
                    // midnight. Adding a `Duration(days:)` to a local DateTime
                    // instead shifts by an hour across a DST boundary, and the
                    // midnight normalisation afterwards then skips or repeats a
                    // column twice a year.
                    final day = DateTime(
                        today.year, today.month, today.day - (days - 1) + w * 7 + d);
                    if (day.isAfter(today)) {
                      return const SizedBox(width: 16, height: 16);
                    }
                    final count = activity[day] ?? 0;
                    final intensity = count == 0 ? 0.0 : (count / maxCount).clamp(0.2, 1.0);
                    return Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: count == 0
                            ? scheme.surfaceContainerHighest
                            : scheme.primary.withValues(alpha: intensity),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
              ],
            ),
        ],
      ),
    );
  }
}
