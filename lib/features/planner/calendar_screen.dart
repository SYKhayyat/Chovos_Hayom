import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/plans.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../core/calendar.dart';
import '../../core/day.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/usecases/fold_log.dart';
import '../../domain/usecases/layer_roles.dart';
import '../../domain/usecases/learning_plan.dart';
import '../../domain/usecases/plan_chain.dart';
import '../../domain/usecases/plan_completion.dart';
import '../../domain/usecases/planner_calendar.dart';
import '../../domain/usecases/siyum_schedule.dart';
import '../../l10n/generated/app_localizations.dart';

enum PlannerCalendarRange { month, week }

class PlannerCalendarScreen extends ConsumerStatefulWidget {
  const PlannerCalendarScreen({super.key});

  @override
  ConsumerState<PlannerCalendarScreen> createState() => _PlannerCalendarScreenState();
}

class _PlannerCalendarScreenState extends ConsumerState<PlannerCalendarScreen> {
  /// The day the view is anchored on. Month range shows the month containing it;
  /// week range shows the week containing it. One anchor rather than a month,
  /// because a "week" is not a month and deriving it from one was why this view
  /// used to open on the 1st and show days 1-7 no matter what today was.
  late Day _anchor;
  PlannerCalendarRange _range = PlannerCalendarRange.month;

  @override
  void initState() {
    super.initState();
    _anchor = Day.of(ref.read(clockProvider)());
  }

  /// Move the anchor a whole step in the current range: a month in month range,
  /// a week in week range. Tapping "next" seven times in the week view moves one
  /// week, not seven.
  void _step(int delta) {
    setState(() {
      _anchor = _range == PlannerCalendarRange.month
          ? _addMonths(_anchor, delta)
          : _anchor + (delta * 7);
    });
  }

  /// [anchor] shifted by [delta] months, clamping the day to the target month's
  /// length so 31 Jan + 1 month lands on 28/29 Feb rather than spilling into March.
  static Day _addMonths(Day anchor, int delta) {
    final d = anchor.midnight;
    final firstOfTarget = DateTime(d.year, d.month + delta, 1);
    // Day 0 of the following month is the last day of the target month.
    final lastDay = DateTime(firstOfTarget.year, firstOfTarget.month + 1, 0).day;
    return Day.of(DateTime(
      firstOfTarget.year,
      firstOfTarget.month,
      d.day <= lastDay ? d.day : lastDay,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(settingsProvider.select((s) => s.calendar));
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final fold = ref.watch(foldProvider).asData?.value;
    final config = ref.watch(plansConfigProvider);
    final layers = ref.watch(layerRolesProvider);
    final now = ref.read(clockProvider)();
    final anchor = _anchor;
    final anchorDate = anchor.midnight;
    // Month range is anchored on the 1st (so it cannot drift as days are
    // stepped); week range on the anchor itself, then both align to the Monday
    // of the containing week.
    final first = _range == PlannerCalendarRange.month
        ? Day.of(DateTime(anchorDate.year, anchorDate.month, 1))
        : anchor;
    final start = first - (first.weekday - 1);
    final days = catalog == null || fold == null
        ? <PlannedDay>[]
        : PlannerCalendar.between(
            plans: config.plans,
            catalog: catalog,
            fold: fold,
            from: start,
            to: start + (_range == PlannerCalendarRange.month ? 41 : 6),
            today: Day.of(now),
            layers: layers,
            isActive: (plan, day) => _isActive(config, plan, day, catalog, fold, layers),
          );
    final byDay = {for (final day in days) day.day: day};
    // A siyum gets a recurring/one-off slot in the calendar so the user knows
    // it is coming. The slot is a *projection* off the same rolled-up log the
    // confirmed siyumim come from (see `SiyumSchedule`), so this is a marker,
    // never a stored event — mark the day, don't write to the log.
    final scheduled = ref.watch(scheduledSiyumimProvider);
    final siyumByDay = <Day, List<ScheduledSiyum>>{};
    for (final siyum in scheduled) {
      siyumByDay.putIfAbsent(siyum.day, () => []).add(siyum);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plannerCalendarTitle),
        actions: [
          IconButton(
            tooltip: l10n.plannerCalendarPrevious,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _step(-1),
          ),
          IconButton(
            tooltip: l10n.plannerCalendarNext,
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _step(1),
          ),
        ],
      ),
      body: Column(
        children: [
          SegmentedButton<PlannerCalendarRange>(
            segments: [
              ButtonSegment(value: PlannerCalendarRange.month, label: Text(l10n.plannerCalendarMonth)),
              ButtonSegment(value: PlannerCalendarRange.week, label: Text(l10n.plannerCalendarWeek)),
            ],
            selected: {_range},
            onSelectionChanged: (value) => setState(() => _range = value.first),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              DateDisplay.format(
                DateTime(anchorDate.year, anchorDate.month, 1),
                mode,
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: _range == PlannerCalendarRange.month
                ? _MonthGrid(byDay: byDay, start: start, siyumByDay: siyumByDay, l10n: l10n)
                : _WeekList(byDay: byDay, start: start, siyumByDay: siyumByDay, l10n: l10n, mode: mode),
          ),
        ],
      ),
    );
  }

  bool _isActive(
    PlansConfig config,
    LearningPlan plan,
    Day day,
    Catalog catalog,
    LogFold fold,
    LayerRoles layers,
  ) {
    final chain = config.chains.where((c) => c.planIds.contains(plan.id));
    if (chain.isEmpty) return true;
    return chain.any(
      (c) => ChainSchedule.activePlanIds(c, day, (id, at) {
        final candidate = config.plans.where((p) => p.id == id).firstOrNull;
        return candidate != null &&
            PlanCompletion.completeBefore(candidate, catalog, fold, at, layers: layers);
      }).contains(plan.id),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.byDay,
    required this.start,
    required this.siyumByDay,
    required this.l10n,
  });

  final Map<Day, PlannedDay> byDay;
  final Day start;
  final Map<Day, List<ScheduledSiyum>> siyumByDay;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final cells = List.generate(42, (index) => start + index);
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: cells.length,
      itemBuilder: (context, index) {
        final day = cells[index];
        final planned = byDay[day];
        final siyumim = siyumByDay[day];
        final color = switch (planned?.status) {
          PlannedDayStatus.done => Colors.green,
          PlannedDayStatus.partlyDone => Colors.orange,
          PlannedDayStatus.missed => Colors.red,
          PlannedDayStatus.planned => Colors.blue,
          null => Colors.transparent,
        };
        return Semantics(
          label: siyumim == null
              ? '${day.midnight.day}'
              : '${day.midnight.day} · ${l10n.plannerCalendarSiyum}',
          child: Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              color: color.withValues(alpha: planned == null ? 0 : 0.18),
            ),
            child: Stack(
              children: [
                Center(child: Text('${day.midnight.day}')),
                if (siyumim != null)
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Icon(
                      Icons.star,
                      size: 10,
                      color: Colors.amber.shade700,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WeekList extends StatelessWidget {
  const _WeekList({
    required this.byDay,
    required this.start,
    required this.siyumByDay,
    required this.l10n,
    required this.mode,
  });

  final Map<Day, PlannedDay> byDay;
  final Day start;
  final Map<Day, List<ScheduledSiyum>> siyumByDay;
  final AppLocalizations l10n;
  final CalendarMode mode;

  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: 7,
        itemBuilder: (context, index) {
          final day = start + index;
          final planned = byDay[day];
          final siyumim = siyumByDay[day];
          return ListTile(
            leading: Icon(Icons.circle, size: 12, color: _color(planned?.status)),
            // Through `DateDisplay`, not `day.toString()`. `Day`'s own doc says its
            // ISO form is "diagnostics and test failure output only", and this
            // screen's heading right above already localises — so the raw string
            // put an ISO column under a Hebrew month and ignored the setting.
            title: Text(DateDisplay.format(day.midnight, mode)),
            subtitle: _subtitle(planned, siyumim),
            trailing: siyumim == null
                ? null
                : Icon(Icons.star, color: Colors.amber.shade700),
          );
        },
      );

  Widget? _subtitle(PlannedDay? planned, List<ScheduledSiyum>? siyumim) {
    if (siyumim == null) {
      return planned == null ? null : Text('${planned.plans.length}');
    }
    final names = [for (final s in siyumim) s.node.name].join(', ');
    return Text('${l10n.plannerCalendarSiyum}: $names');
  }

  Color _color(PlannedDayStatus? status) => switch (status) {
        PlannedDayStatus.done => Colors.green,
        PlannedDayStatus.partlyDone => Colors.orange,
        PlannedDayStatus.missed => Colors.red,
        PlannedDayStatus.planned => Colors.blue,
        null => Colors.grey,
      };
}
