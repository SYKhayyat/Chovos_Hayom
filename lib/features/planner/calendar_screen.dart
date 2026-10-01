import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/plans.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../core/breakpoints.dart';
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
import '../../domain/usecases/day_ledger.dart';
import '../../domain/usecases/recurrence.dart';
import '../../domain/usecases/siyum_schedule.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';
import '../common/text_prompt.dart';

class PlannerCalendarScreen extends ConsumerStatefulWidget {
  const PlannerCalendarScreen({super.key});

  @override
  ConsumerState<PlannerCalendarScreen> createState() => _PlannerCalendarScreenState();
}

class _PlannerCalendarScreenState extends ConsumerState<PlannerCalendarScreen> {
  /// The day the view is anchored on. Each range derives its page from this one
  /// day — a day range is that day, a week range the week containing it, a
  /// month range the month containing it. One anchor rather than a month,
  /// because a "week" is not a month and deriving it from one was why this view
  /// used to open on the 1st and show days 1-7 no matter what today was.
  late Day _anchor;
  PlannerCalendarRange _range = PlannerCalendarRange.month;

  /// The pager, held so the arrows can put it back on the current page.
  ///
  /// Three pages exist at a time — the one before, this one, the one after —
  /// and a swipe past either end is answered by moving [_anchor] and jumping
  /// back to the middle. Which is what keeps the promise that paging costs one
  /// page: a pager over every day of the year would be a year of grids built to
  /// answer a question about this week.
  late final PageController _pages;

  @override
  void initState() {
    super.initState();
    _anchor = Day.of(ref.read(clockProvider)());
    _pages = PageController(initialPage: _middlePage);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// The page the view is actually showing.
  ///
  /// One of three, with the current page in the middle so that a swipe in
  /// either direction has somewhere to go.
  static const _middlePage = 1;

  /// Move the anchor a whole step in the current range: a month in month range,
  /// a week in week range, a day in day range. Tapping "next" seven times in the
  /// week view moves one week, not seven.
  void _step(int delta) {
    setState(() => _anchor = _range.step(_anchor, delta));
  }

  /// A swipe landed on a page. Move the anchor to match and recentre.
  ///
  /// The `jumpToPage` matters: without it the view would animate from page 2
  /// back to page 1 after every swipe, which on a day range is a visible
  /// backward lurch on each single flick.
  void _onPage(int page) {
    if (page == _middlePage) return;
    _step(page > _middlePage ? 1 : -1);
    _pages.jumpToPage(_middlePage);
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
    final range = _range;
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
            // Named for the range, not for a month. "Next month" on a day view
            // is a tooltip that contradicts the button's own effect, and a
            // screen reader is the only place some of these readers will ever
            // hear it.
            tooltip: _stepLabel(l10n, back: true),
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _step(-1),
          ),
          IconButton(
            tooltip: _stepLabel(l10n, back: false),
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _step(1),
          ),
        ],
      ),
      body: Column(
        children: [
          SegmentedButton<PlannerCalendarRange>(
            // **Tighter on a 240dp screen, and the selected icon goes.**
            //
            // Three segments with three labels, each padded 12dp either side,
            // is 232dp of chrome on a screen 208dp wide — so the longest label
            // wrapped mid-word and the control showed "Mo / nth". It was only
            // visible in *month* range, because the selected segment also
            // carries a checkmark, and Month is the longest of the three words;
            // so the default view of the default screen had a clipped label on
            // the device the app is built for, and no assertion caught it
            // because a wrapped `Text` is not an overflow.
            //
            // `showSelectedIcon: false` and half the padding together buy back
            // the 24dp it needs. Both are compact-only, so an ordinary phone is
            // untouched — and `pinned_text_field_test`-style geometry is not
            // what holds this: `keypad_test.dart` measures the rendered label.
            showSelectedIcon: !isCompact(context),
            style: isCompact(context)
                ? const ButtonStyle(
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 6),
                    ),
                  )
                : null,
            segments: [
              ButtonSegment(
                  value: PlannerCalendarRange.day,
                  label: Text(l10n.plannerCalendarDay)),
              ButtonSegment(
                  value: PlannerCalendarRange.week,
                  label: Text(l10n.plannerCalendarWeek)),
              ButtonSegment(
                  value: PlannerCalendarRange.month,
                  label: Text(l10n.plannerCalendarMonth)),
            ],
            selected: {range},
            onSelectionChanged: (value) => setState(() => _range = value.first),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            // Keyed because the heading is the screen's answer to "which range
            // am I looking at, and when" — so it is the one thing every paging
            // test asserts against, and it is a bare `Text` among several
            // identical ones. Locating it by content means a test that only
            // wants "the range moved" has to hard-code every date it might see.
            key: const ValueKey('calendar-heading'),
            child: Text(
              _heading(range, anchor, mode),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            // **Left and right page, for a device with no swipe.**
            //
            // A `PageView` answers a drag and nothing else, and the phone this
            // app is built for has a D-pad and no touchscreen — so paging, the
            // thing #31 was filed for, was reachable by finger only. The arrows
            // in the bar still work, which is what the keypad test covers, but a
            // reader who has focus *on the calendar* had no way to move through
            // it except going back up to the bar.
            //
            // This is a `Focus` **above** the pages on purpose. Key events
            // travel from the focused node outward, so a descendant that wants
            // the key gets it first: the range selector's segments use left and
            // right to move between themselves, and this must not steal that.
            // Anything the page ignored falls through to here and pages.
            child: Focus(
              onKeyEvent: _onKey,
              child: PageView.builder(
              controller: _pages,
              onPageChanged: _onPage,
              // Three pages, and not one per day of a browsable span. Each page
              // derives its own window from the same step the arrows call, so a
              // swipe costs one window and only three windows are ever built.
              itemCount: 3,
              itemBuilder: (context, page) => _page(
                range: range,
                // Page 0 is the window before, 2 the one after, derived rather
                // than tracked: an offset kept in step with the anchor is
                // exactly the state that drifts.
                anchor: range.step(anchor, page - _middlePage),
                catalog: catalog,
                fold: fold,
                config: config,
                layers: layers,
                today: Day.of(now),
                siyumByDay: siyumByDay,
                l10n: l10n,
                mode: mode,
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  /// Left and right page, by one step, when nothing on the page wanted the key.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight => 1,
      LogicalKeyboardKey.arrowLeft => -1,
      _ => null,
    };
    if (step == null) return KeyEventResult.ignored;
    _step(step);
    // Focus is moved onto the pager itself, because the day cell that had it is
    // gone: paging replaces the page, and a cell for 15 January does not exist
    // on the page for February. Without this the first press pages and every
    // press after it is delivered to nothing — which is worse than not paging
    // at all, because it looks like a key that worked once and then broke.
    node.requestFocus();
    return KeyEventResult.handled;
  }

  /// One page: its own days, its own plan data, in whichever range is showing.
  ///
  /// The window is derived per page rather than computed once for the whole
  /// view, because the three pages are three *different* windows — deriving
  /// them all from the anchor's would leave the page a swipe away from blank,
  /// which is the one thing a pager must never do.
  Widget _page({
    required PlannerCalendarRange range,
    required Day anchor,
    required Catalog? catalog,
    required LogFold? fold,
    required PlansConfig config,
    required LayerRoles layers,
    required Day today,
    required Map<Day, List<ScheduledSiyum>> siyumByDay,
    required AppLocalizations l10n,
    required CalendarMode mode,
  }) {
    final window = calendarWindow(anchor, range);
    final planned = catalog == null || fold == null
        ? <PlannedDay>[]
        : PlannerCalendar.between(
            plans: config.plans,
            catalog: catalog,
            fold: fold,
            from: window.first,
            to: window.last,
            today: today,
            layers: layers,
            isActive: (plan, day) =>
                _isActive(config, plan, day, catalog, fold, layers),
          );
    final byDay = {for (final day in planned) day.day: day};
    void onDay(Day day) => _openDay(context, ref, day, config);

    return switch (range) {
      PlannerCalendarRange.month => _MonthGrid(
          days: window,
          byDay: byDay,
          siyumByDay: siyumByDay,
          l10n: l10n,
          dueOn: (day) => _dueOn(config, day),
          onDay: onDay,
        ),
      PlannerCalendarRange.week => _WeekList(
          days: window,
          byDay: byDay,
          siyumByDay: siyumByDay,
          l10n: l10n,
          mode: mode,
          dueOn: (day) => _dueOn(config, day),
          onDay: onDay,
        ),
      PlannerCalendarRange.day => _DayList(
          day: window.first,
          config: config,
          l10n: l10n,
          mode: mode,
          siyumim: siyumByDay[window.first],
          onDay: onDay,
        ),
    };
  }

  /// What the heading says: the range's own span, not always a month.
  ///
  /// It said "the 1st of the anchor's month" in every range, which put a 1 Jan
  /// heading above a week running 5-11 January and above a day in the middle of
  /// it — the same class of defect as the raw ISO dates in #30, one layer up: a
  /// heading that is not about what is under it. All three forms go through
  /// [DateDisplay], so a Hebrew reader gets Hebrew dates in all of them.
  ///
  /// The day's *name* rather than the page's first cell, which is what
  /// [PlannerCalendarRange.namedDay] is for: a month page opens on the preceding
  /// Monday, and printing that would put December's date over January.
  static String _heading(
    PlannerCalendarRange range,
    Day anchor,
    CalendarMode mode,
  ) {
    final named = range.namedDay(anchor);
    return switch (range) {
      PlannerCalendarRange.day ||
      PlannerCalendarRange.month =>
        DateDisplay.format(named.midnight, mode),
      PlannerCalendarRange.week =>
        // Both ends, because a week is not a point: the Monday alone reads as
        // a day rather than as the week that starts on it.
        '${DateDisplay.format(named.midnight, mode)} – '
            '${DateDisplay.format((named + 6).midnight, mode)}',
    };
  }

  /// What the arrows are called, in the range's own terms.
  ///
  /// "Next month" on a day view is a label that contradicts the button's
  /// effect, and a screen reader is the only place some of these readers will
  /// ever hear it.
  String _stepLabel(AppLocalizations l10n, {required bool back}) =>
      switch (_range) {
        PlannerCalendarRange.day => back
            ? l10n.plannerCalendarPreviousDay
            : l10n.plannerCalendarNextDay,
        PlannerCalendarRange.week => back
            ? l10n.plannerCalendarPreviousWeek
            : l10n.plannerCalendarNextWeek,
        PlannerCalendarRange.month =>
          back ? l10n.plannerCalendarPrevious : l10n.plannerCalendarNext,
      };

  /// The day's ledger, or an empty list when the catalog or log has not loaded.
  ///
  /// **Empty rather than a throw**, because this is a modal opened from a
  /// calendar cell and neither the catalog nor the fold is guaranteed to be there
  /// by then — a cold start is a legitimate state, not a failure.
  List<({LearningPlan plan, List<LedgerUnit> units})> _ledgerFor(
    WidgetRef ref,
    List<LearningPlan> firing,
    Day day,
  ) {
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final fold = ref.watch(foldProvider).asData?.value;
    if (catalog == null || fold == null) return const [];
    return DayLedger.forDay(
      firing,
      catalog,
      fold,
      day,
      layers: ref.watch(layerRolesProvider),
    );
  }

  /// Whether every unit every firing plan owes on [day] is already done.
  bool _ledgerAllDone(WidgetRef ref, List<LearningPlan> firing, Day day) {
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final fold = ref.watch(foldProvider).asData?.value;
    if (catalog == null || fold == null) return false;
    final ledgers = DayLedger.forDay(
      firing,
      catalog,
      fold,
      day,
      layers: ref.watch(layerRolesProvider),
    );
    if (ledgers.isEmpty) return false;
    return ledgers.every((e) => DayLedger.owed(e.units) == 0);
  }

  /// One plan's ledger: its units, each with a checkbox.
  ///
  /// **A tick is not an edit of the plan.** It writes to the event log with this
  /// plan's id and the day being looked at, so the unit grid, the progress bars
  /// and every count update immediately — and the plan still asks for the unit,
  /// which is the whole point of the ledger. Setting an amount, above, is the
  /// opposite act and goes to the plan instead.
  List<Widget> _ledgerSection(
    BuildContext sheetContext,
    WidgetRef ref,
    Day day,
    LearningPlan plan,
    List<LedgerUnit> units,
    CalendarMode mode,
  ) {
    if (units.isEmpty) return const [];
    final l10n = AppLocalizations.of(sheetContext);
    final catalog = ref.read(mergedCatalogProvider).asData?.value;
    final logger = ref.read(loggingServiceProvider);
    final doneHere = DayLedger.doneOnDay(units);

    Widget rowFor(LedgerUnit u) {
      final node = catalog?.byId(u.nodeId);
      final label = node == null ? '${u.nodeId} ${u.unitIndex}' : nodeAndUnit(l10n, node, u.unitIndex);
      final dayText = DateDisplay.format(day.midnight, mode);

      String? subtitle;
      if (u.doneHere) {
        subtitle = l10n.plansLedgerDone;
      } else if (u.doneElsewhere) {
        // Shown rather than hidden: a backlog is the reader's business, and the
        // plan's pacing is what acts on it — not this sheet.
        subtitle = l10n.plansLedgerDoneElsewhere(
          DateDisplay.format(u.doneOn!.midnight, mode),
        );
      } else {
        subtitle = l10n.plansLedgerOwed;
      }

      return CheckboxListTile(
        // Keyed by node and unit, never by position: a day's ledger can hold the
        // same unit twice when two plans each contribute it, and a finder that
        // counted rows would then be pointing at whichever happens to be first.
        key: ValueKey('ledger-${plan.id}-${u.nodeId}-${u.unitIndex}'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: u.doneHere,
        // A checkbox that is ticked by being looked at is a lie; it is written
        // to the log, and every other view reads it from there.
        onChanged: (v) async {
          final navigator = Navigator.of(sheetContext);
          if (!navigator.mounted) return;
          // The day is the *plan's* day, not today: a tick made on Friday for
          // last Thursday belongs to Thursday, which is the day whose ledger it
          // is.
          await guarded(
            navigator.context,
            ref,
            () => v == true
                ? logger.markDone(
                    u.nodeId,
                    u.unitIndex,
                    occurredAt: day.midnight,
                    planId: plan.id,
                  )
                : logger.markUndone(
                    u.nodeId,
                    u.unitIndex,
                    // Named day, so the un-tick takes back *this* day's tick
                    // rather than the most recent one — a tick made in the past
                    // is the ordinary case, not the exotic one.
                    occurredAt: day.midnight,
                    planId: plan.id,
                  ),
            what: v == true
                ? l10n.unitDoneSnackbar(label, dayText)
                : l10n.unitUndoneSnackbar(label, dayText),
          );
        },
        title: Text(label),
        subtitle: Text(subtitle),
      );
    }

    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          // A day where nothing is owed is not a day of zero progress — it is a
          // rest day, or one whose work is already done. The count line says so
          // rather than printing "0 of 0", which reads as a failure.
          DayLedger.owed(units) == 0
              ? l10n.plansLedgerEmpty
              : l10n.plansLedgerCount(doneHere, units.length),
          style: Theme.of(sheetContext).textTheme.bodySmall,
        ),
      ),
      for (final u in units) rowFor(u),
      const Divider(height: 24),
    ];
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
      // **A `Consumer`, not a plain builder.** The ledger has to rebuild when the
      // log changes, and a `ref.watch` called in a bare builder is read exactly
      // once — when the sheet is built — so ticking a unit would write to the log
      // and leave the row unticked, with no error anywhere. `ConsumerWidget`
      // re-runs the subtree on every change, which is what makes "tick it and
      // watch it tick" true.
      builder: (sheetContext) => Consumer(builder: (sheetContext, sheetRef, _) {
        return SafeArea(
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
            // **The ledger: what this day asks for, with the log applied.**
            //
            // Deliberately below the per-plan rows rather than instead of them.
            // Ticking here writes to the **event log**, which is a different act
            // from editing the amount above it — the rows change *the plan*, and
            // a tick is a claim about *what was learned*. Every other view
            // updates at once because they all read the log.
            //
            // And the reverse does not happen: a unit ticked in the **unit
            // grid** still appears here, because the plan still asks for it.
            // Nothing leaves a plan by being learned; only a deliberate planning
            // act changes what a day asks. The gap between the two is the thing
            // the calendar exists to show.
            for (final entry in _ledgerFor(sheetRef, firing, day))
              ..._ledgerSection(
                  sheetContext, sheetRef, day, entry.plan, entry.units, mode),
            // A day that asks for units and has every one of them done is a
            // finished day, and saying so is the point of the ledger. Written
            // here rather than per plan, because it is a statement about the day.
            if (_ledgerFor(sheetRef, firing, day).isNotEmpty &&
                _ledgerAllDone(sheetRef, firing, day))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.plansLedgerDoneAll,
                    style: Theme.of(sheetContext).textTheme.bodySmall),
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
      );
      }),
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
    required this.days,
    required this.byDay,
    required this.siyumByDay,
    required this.l10n,
    required this.dueOn,
    required this.onDay,
  });

  /// The page's days, in order — 42 of them, so the grid is six rows of seven
  /// whichever month it is. Taken as a list rather than as a start day and a
  /// count so the widget cannot disagree with the range about how long a month
  /// is.
  final List<Day> days;
  final Map<Day, PlannedDay> byDay;
  final Map<Day, List<ScheduledSiyum>> siyumByDay;
  final AppLocalizations l10n;
  final int Function(Day day) dueOn;
  final void Function(Day day) onDay;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
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
                  // **Smaller type, not a smaller everything.**
                  //
                  // A cell is a seventh of the screen, and on the 240dp keypad
                  // phone this app is built for that is 28 logical pixels — a
                  // day number and an amount stacked need about 36 of them, so
                  // every cell with something due on it overflowed and drew a
                  // yellow stripe across the month.
                  //
                  // `FittedBox(scaleDown)` fixes the overflow, and it was the
                  // whole fix until it was measured: it scales the *day number*
                  // along with the amount, landing every cell at 0.78, so the
                  // number that has to be readable comes out near 11sp and the
                  // amount near 8.6. Trading a legibility problem for a smaller
                  // legibility problem is not a fix.
                  //
                  // So on a compact screen the type is chosen small enough to
                  // fit, which is the difference between *smaller* and
                  // *distorted*, and the `FittedBox` stays as the backstop that
                  // makes an overflow impossible on any screen — including one
                  // narrower than the one this was measured on. On an ordinary
                  // phone the scale is 1.0 and nothing is smaller than it was.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${day.midnight.day}',
                            style: isCompact(context)
                                ? Theme.of(context).textTheme.labelMedium
                                : null),
                        // The total due, not one plan's amount: a day can have
                        // several plans firing and the cell holds one number.
                        if (dueOn(day) > 0)
                          Text(
                            '${dueOn(day)}',
                            style: isCompact(context)
                                ? Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(fontSize: 9)
                                : Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
                    ),
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
    required this.days,
    required this.byDay,
    required this.siyumByDay,
    required this.l10n,
    required this.mode,
    required this.dueOn,
    required this.onDay,
  });

  final List<Day> days;
  final Map<Day, PlannedDay> byDay;
  final Map<Day, List<ScheduledSiyum>> siyumByDay;
  final AppLocalizations l10n;
  final CalendarMode mode;
  final int Function(Day day) dueOn;
  final void Function(Day day) onDay;

  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
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

/// One day, at full size: every plan that fires on it, by name, with what it
/// asks for.
///
/// The finest of the three ranges and the one that is not a list of dates —
/// which is the point of it. A month cell and a week row can only hold a number,
/// because there are forty of them and one of the screen; a day page has the
/// whole screen and therefore has room to say *which* plans are firing, which is
/// the question a person actually has when they are looking at a day ("what am
/// I meant to be doing on Tuesday?"). The amount is per plan here rather than
/// summed, for the same reason: the sum is what the cell was for.
///
/// Tapping a row opens the same day sheet the month grid opens, so an amount
/// can be set or a day off checked from here as well as from a cell.
class _DayList extends StatelessWidget {
  const _DayList({
    required this.day,
    required this.config,
    required this.l10n,
    required this.mode,
    required this.siyumim,
    required this.onDay,
  });

  final Day day;
  final PlansConfig config;
  final AppLocalizations l10n;
  final CalendarMode mode;
  final List<ScheduledSiyum>? siyumim;
  final void Function(Day day) onDay;

  @override
  Widget build(BuildContext context) {
    final info = dayInfoFor(day);
    // Which plans fire, in the user's own order of plans rather than in
    // whatever order a map happened to produce.
    final firing = [
      for (final plan in config.plans)
        if (PlannerSchedule.assignmentsOn(plan, info).isNotEmpty) plan,
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // The weekday, on its own line: the heading above says the date, and a
        // date without its weekday is half the answer to "what is this day".
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            weekdayName(l10n, day.weekday),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (siyumim != null)
          ListTile(
            leading: Icon(Icons.star, color: Colors.amber.shade700),
            title: Text('${l10n.plannerCalendarSiyum}: '
                '${[for (final s in siyumim!) s.node.name].join(', ')}'),
          ),
        if (firing.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.plansDaySheetNothing),
          ),
        for (final plan in firing)
          ListTile(
            title: Text(plan.name),
            subtitle: Text(_amount(plan, info)),
            trailing: const Icon(Icons.edit),
            onTap: () => onDay(day),
          ),
      ],
    );
  }

  /// What this plan asks of this day, with `0` saying so.
  ///
  /// The same distinction the month cell and the day sheet make, in the same
  /// words: a day off is a deliberate zero and must never read as a blank.
  String _amount(LearningPlan plan, DayInfo info) {
    final amount = DayAmount.of(plan, info);
    return amount == 0 ? '0 · ${l10n.plansDayOff}' : l10n.plansUnitsDue(amount);
  }
}
