import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/plans.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../core/calendar.dart';
import '../../core/day.dart';
import '../../core/parse.dart';
import '../../core/planner_dates.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/usecases/fold_log.dart';
import '../../domain/usecases/layer_roles.dart';
import '../../domain/usecases/learning_plan.dart';
import '../../domain/usecases/plan_chain.dart';
import '../../domain/usecases/plan_completion.dart';
import '../../domain/usecases/planner_calendar.dart';
import '../../domain/usecases/day_amount.dart';
import '../../domain/usecases/siyum_schedule.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/text_prompt.dart';

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
                ? _MonthGrid(
                    byDay: byDay,
                    start: start,
                    siyumByDay: siyumByDay,
                    l10n: l10n,
                    dueOn: (day) => _dueOn(config, day),
                    onDay: (day) => _openDay(context, ref, day, config),
                  )
                : _WeekList(
                    byDay: byDay,
                    start: start,
                    siyumByDay: siyumByDay,
                    l10n: l10n,
                    mode: mode,
                    dueOn: (day) => _dueOn(config, day),
                    onDay: (day) => _openDay(context, ref, day, config),
                  ),
          ),
        ],
      ),
    );
  }


  /// Units due on [day], summed over every plan that fires on it.
  ///
  /// The **total**, not one plan's amount, because a day can have several plans
  /// firing and the cell has room for one number. "How much is due today" is
  /// the question a calendar answers; the per-plan breakdown is one tap away.
  static int _dueOn(PlansConfig config, Day day) {
    var total = 0;
    for (final plan in config.plans) {
      if (PlannerSchedule.assignmentsOn(plan, dayInfoFor(day)).isNotEmpty) {
        total += DayAmount.of(plan, dayInfoFor(day));
      }
    }
    return total;
  }

  /// Opens a day: what each plan asks for it, and a way to change that.
  ///
  /// Setting an amount writes a **date override on the plan** and never touches
  /// the event log, so "I am taking Thursday off" is a change to the schedule
  /// rather than a claim about what was learned.
  Future<void> _openDay(
    BuildContext context,
    WidgetRef ref,
    Day day,
    PlansConfig config,
  ) async {
    final l10n = AppLocalizations.of(context);
    final mode = ref.read(settingsProvider).calendar;
    final firing = [
      for (final plan in config.plans)
        if (PlannerSchedule.assignmentsOn(plan, dayInfoFor(day)).isNotEmpty)
          plan,
    ];

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(DateDisplay.format(day.midnight, mode),
                style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            if (firing.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.plansDaySheetNothing),
              ),
            for (final plan in firing)
              ListTile(
                title: Text(plan.name),
                subtitle: Text(
                  // `0` is a day off and says so; it must not read as an
                  // absent amount, which would be the one thing this design
                  // exists to prevent.
                  DayAmount.of(plan, dayInfoFor(day)) == 0
                      ? '0 · ${l10n.plansDayOff}'
                      : '${DayAmount.of(plan, dayInfoFor(day))}'
                          ' · ${l10n.plansUnitsPerDay}',
                ),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final navigator = Navigator.of(sheetContext);
                  // Guarded before the await: the sheet may be gone by the time
                  // the prompt returns, and `sheetContext` is not safe then.
                  if (!navigator.mounted) return;
                  final amount = await promptForText(
                    sheetContext,
                    title: l10n.plansDaySheetSetFor(plan.name),
                    body: l10n.plansDateAmountHelp,
                    label: l10n.plansUnitsPerDay,
                    initialValue: '${DayAmount.of(plan, dayInfoFor(day))}',
                    keyboardType: TextInputType.number,
                    confirmLabel: l10n.plansSave,
                    cancelLabel: l10n.plansCancel,
                    validate: (v) => nonNegativeInt(v) == null
                        ? l10n.plansAmountInvalid
                        : null,
                  );
                  if (amount == null || !navigator.mounted) return;
                  final next = nonNegativeInt(amount)!;
                  final dates = {...plan.dateAmounts, day: next};
                  // The sheet's context, not a context read after the await:
                  // `ref` and `plan` are all this needs.
                  await guarded(
                    navigator.context,
                    ref,
                    () => ref
                        .read(plansConfigProvider.notifier)
                        .save(plan.copyWithDateAmounts(dates)),
                    what: l10n.plansSaved,
                  );
                  navigator.pop();
                },
              ),
            if (firing.any((p) => p.dateAmounts.containsKey(day)))
              TextButton.icon(
                icon: const Icon(Icons.undo),
                label: Text(l10n.plansDaySheetClear),
                onPressed: () async {
                  final navigator = Navigator.of(sheetContext);
                  // Clear every plan's override for this date, so the day goes
                  // back to asking whatever its weekday and base amount say.
                  // Inside the write guard like every other write, and guarded
                  // before the await: the sheet may be gone by then.
                  if (!navigator.mounted) return;
                  await guarded(
                    navigator.context,
                    ref,
                    () async {
                      final controller = ref.read(plansConfigProvider.notifier);
                      for (final plan in firing) {
                        final dates = {...plan.dateAmounts}..remove(day);
                        await controller.save(plan.copyWithDateAmounts(dates));
                      }
                    },
                    what: l10n.plansSaved,
                  );
                  navigator.pop();
                },
              ),
          ],
        ),
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
    required this.dueOn,
    required this.onDay,
  });

  final Map<Day, PlannedDay> byDay;
  final Day start;
  final Map<Day, List<ScheduledSiyum>> siyumByDay;
  final AppLocalizations l10n;
  final int Function(Day day) dueOn;
  final void Function(Day day) onDay;

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
          key: ValueKey('day-${day.ordinal}'),
          label: siyumim == null
              ? '${day.midnight.day}'
              : '${day.midnight.day} · ${l10n.plannerCalendarSiyum}',
          child: Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              color: color.withValues(alpha: planned == null ? 0 : 0.18),
            ),
            child: InkWell(
              onTap: () => onDay(day),
              child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${day.midnight.day}'),
                      // The total due, not one plan's amount: a day can have
                      // several plans firing and the cell holds one number.
                      if (dueOn(day) > 0)
                        Text('${dueOn(day)}',
                            style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
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
    required this.dueOn,
    required this.onDay,
  });

  final Map<Day, PlannedDay> byDay;
  final Day start;
  final Map<Day, List<ScheduledSiyum>> siyumByDay;
  final AppLocalizations l10n;
  final CalendarMode mode;
  final int Function(Day day) dueOn;
  final void Function(Day day) onDay;

  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: 7,
        itemBuilder: (context, index) {
          final day = start + index;
          final planned = byDay[day];
          final siyumim = siyumByDay[day];
          return ListTile(
            onTap: () => onDay(day),
            leading: Icon(Icons.circle, size: 12, color: _color(planned?.status)),
            // Through `DateDisplay`, not `day.toString()`. `Day`'s own doc says its
            // ISO form is "diagnostics and test failure output only", and this
            // screen's heading right above already localises — so the raw string
            // put an ISO column under a Hebrew month and ignored the setting.
            title: Text(DateDisplay.format(day.midnight, mode)),
            subtitle: _subtitle(day, planned, siyumim),
            trailing: siyumim == null
                ? null
                : Icon(Icons.star, color: Colors.amber.shade700),
          );
        },
      );

  Widget? _subtitle(Day day, PlannedDay? planned, List<ScheduledSiyum>? siyumim) {
    // The units due come first: that is what the row is for.
    final due = dueOn(day);
    final parts = <String>[
      if (due > 0) l10n.plansUnitsDue(due),
      if (siyumim != null)
        '${l10n.plannerCalendarSiyum}: '
            '${[for (final s in siyumim) s.node.name].join(', ')}',
    ];
    if (parts.isNotEmpty) return Text(parts.join(' · '));
    return planned == null ? null : Text('${planned.plans.length}');
  }

  Color _color(PlannedDayStatus? status) => switch (status) {
        PlannedDayStatus.done => Colors.green,
        PlannedDayStatus.partlyDone => Colors.orange,
        PlannedDayStatus.missed => Colors.red,
        PlannedDayStatus.planned => Colors.blue,
        null => Colors.grey,
      };
}
