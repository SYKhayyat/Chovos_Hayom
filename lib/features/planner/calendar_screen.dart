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
  late DateTime _month;
  PlannerCalendarRange _range = PlannerCalendarRange.month;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider)();
    _month = DateTime(now.year, now.month);
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
    final first = Day.of(_month);
    final start = _range == PlannerCalendarRange.month
        ? first - (first.weekday - 1)
        : first;
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
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
          ),
          IconButton(
            tooltip: l10n.plannerCalendarNext,
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
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
              DateDisplay.format(_month, mode),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: _range == PlannerCalendarRange.month
                ? _MonthGrid(byDay: byDay, start: start, siyumByDay: siyumByDay, l10n: l10n)
                : _WeekList(byDay: byDay, start: start, siyumByDay: siyumByDay, l10n: l10n),
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
  });

  final Map<Day, PlannedDay> byDay;
  final Day start;
  final Map<Day, List<ScheduledSiyum>> siyumByDay;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: 7,
        itemBuilder: (context, index) {
          final day = start + index;
          final planned = byDay[day];
          final siyumim = siyumByDay[day];
          return ListTile(
            leading: Icon(Icons.circle, size: 12, color: _color(planned?.status)),
            title: Text(day.toString()),
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
