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
import '../../domain/usecases/day_amount.dart';
import '../../domain/usecases/day_ledger.dart';
import '../../domain/usecases/learning_plan.dart';
import '../../domain/usecases/plan_edit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';
import '../common/node_picker.dart';
import '../common/text_prompt.dart';
import 'reflow_sheet.dart';

/// A day: what each plan asks of it, every unit it owes, and a way to change
/// either.
///
/// **Three layouts, and which one is a *setting*** ([DaySheetLayout]). What
/// changes between them is only how the day's **work** is listed. The per-plan
/// amounts, the `+`/`−` commands and the reflow are the same in all three,
/// because they are facts about a plan and about the day rather than about how
/// the units happen to read. That is the whole design: a layout switch that also
/// moved the buttons would be three settings to learn rather than one.
///
/// **This was inline in the calendar screen until #48.** It became a widget
/// because three copies of a sheet that edits plans, writes to the log and offers
/// a reflow are three chances for them to disagree about what a day is.
class DaySheet extends ConsumerWidget {
  const DaySheet({super.key, required this.day, required this.config});

  final Day day;
  final PlansConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(settingsProvider.select((s) => s.calendar));
    // **Watched, not read.** The layout is a setting, so changing it in Settings
    // and coming back must show the other one; a `read` would pin the sheet to
    // whichever layout was in force when it was opened.
    final layout = ref.watch(settingsProvider.select((s) => s.daySheetLayout));
    final firing = [
      for (final plan in config.plans)
        if (PlannerSchedule.assignmentsOn(plan, dayInfoFor(day)).isNotEmpty)
          plan,
    ];
    final ledgers = _ledgerFor(ref, firing);

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              DateDisplay.format(day.midnight, mode),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (firing.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.plansDaySheetNothing),
            ),
          ...switch (layout) {
            DaySheetLayout.byPlan => _grouped(
              context,
              ref,
              firing,
              ledgers,
              mode,
            ),
            DaySheetLayout.flat => _flat(context, ref, firing, ledgers, mode),
            DaySheetLayout.collapsed => _collapsed(
              context,
              ref,
              firing,
              ledgers,
              mode,
            ),
          },
          _planCommands(context, ref, firing),
          // A day that asks for units and has every one of them done is a
          // finished day, and saying so is the point of the ledger. Written here
          // rather than per plan, because it is a statement about the day.
          if (ledgers.isNotEmpty && _allDone(ledgers))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.plansLedgerDoneAll,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (firing.any((p) => p.dateAmounts.containsKey(day)))
            TextButton.icon(
              icon: const Icon(Icons.undo),
              label: Text(l10n.plansDaySheetClear),
              onPressed: () => _clearOverrides(context, ref, firing),
            ),
        ],
      ),
    );
  }

  /// **Layout 1 — grouped by plan.** The default, and the only one of the three
  /// that stays readable when several plans fall on the same day: each plan's
  /// amount, its reflow and its own units sit together, so the answer to "what
  /// does *this* plan want here" is in one place.
  List<Widget> _grouped(
    BuildContext context,
    WidgetRef ref,
    List<LearningPlan> firing,
    List<({LearningPlan plan, List<LedgerUnit> units})> ledgers,
    CalendarMode mode,
  ) {
    final byPlan = {for (final entry in ledgers) entry.plan.id: entry.units};
    return [
      for (final plan in firing) ...[
        _amountRow(context, ref, plan),
        _recomputeButton(context, ref, plan, mode),
        ..._unitRows(context, ref, byPlan[plan.id] ?? const [], plan, mode),
      ],
    ];
  }

  /// **Layout 2 — one flat list.** Every unit the day owes, in the order the
  /// plans come, each **naming its own plan**: no group header, and so no
  /// heading to scroll back to in order to find a unit. Fewest taps on a small
  /// day, which is the reason to choose it.
  List<Widget> _flat(
    BuildContext context,
    WidgetRef ref,
    List<LearningPlan> firing,
    List<({LearningPlan plan, List<LedgerUnit> units})> ledgers,
    CalendarMode mode,
  ) => [
    for (final plan in firing) _amountRow(context, ref, plan),
    if (ledgers.isNotEmpty) ...[
      for (final plan in firing) _recomputeButton(context, ref, plan, mode),
      for (final entry in ledgers)
        ..._unitRows(
          context,
          ref,
          entry.units,
          entry.plan,
          mode,
          // The only thing that differs from the grouped rows: the plan is named
          // on the row itself, because nothing above it says which plan a unit
          // belongs to.
          namePlanOnRow: true,
        ),
    ],
  ];

  /// **Layout 3 — collapsed summaries that expand.** One line per plan saying
  /// how much of it is done, and the units behind a tap.
  ///
  /// **Collapsed by default**, because the layout exists for a day with many
  /// plans firing and little interest in most of them; starting expanded would
  /// be the grouped layout with extra steps.
  List<Widget> _collapsed(
    BuildContext context,
    WidgetRef ref,
    List<LearningPlan> firing,
    List<({LearningPlan plan, List<LedgerUnit> units})> ledgers,
    CalendarMode mode,
  ) => [
    for (final plan in firing) _amountRow(context, ref, plan),
    for (final entry in ledgers)
      _CollapsedPlan(
        key: ValueKey('collapsed-${entry.plan.id}'),
        plan: entry.plan,
        units: entry.units,
        expanded: () => [
          _recomputeButton(context, ref, entry.plan, mode),
          ..._unitRows(context, ref, entry.units, entry.plan, mode),
        ],
      ),
  ];

  /// A plan's row: its name, what it asks of this day, and a way to change that.
  ///
  /// Setting an amount writes a **date override on the plan** and never touches
  /// the event log, so "I am taking Thursday off" is a change to the schedule
  /// rather than a claim about what was learned.
  Widget _amountRow(BuildContext context, WidgetRef ref, LearningPlan plan) {
    final l10n = AppLocalizations.of(context);
    final amount = DayAmount.of(plan, dayInfoFor(day));
    return ListTile(
      key: ValueKey('amount-${plan.id}'),
      title: Text(plan.name),
      subtitle: Text(
        // `0` is a day off and says so; it must not read as an absent amount,
        // which would be the one thing this design exists to prevent.
        amount == 0
            ? '0 · ${l10n.plansDayOff}'
            : '$amount · ${l10n.plansUnitsPerDay}',
      ),
      trailing: const Icon(Icons.edit),
      onTap: () => _editAmount(context, ref, plan),
    );
  }

  Future<void> _editAmount(
    BuildContext context,
    WidgetRef ref,
    LearningPlan plan,
  ) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    // Guarded before the await: the sheet may be gone by the time the prompt
    // returns, and `context` is not safe then.
    if (!navigator.mounted) return;
    final amount = await promptForText(
      context,
      title: l10n.plansDaySheetSetFor(plan.name),
      body: l10n.plansDateAmountHelp,
      label: l10n.plansUnitsPerDay,
      initialValue: '${DayAmount.of(plan, dayInfoFor(day))}',
      keyboardType: TextInputType.number,
      confirmLabel: l10n.plansSave,
      cancelLabel: l10n.plansCancel,
      validate: (v) =>
          nonNegativeInt(v) == null ? l10n.plansAmountInvalid : null,
    );
    if (amount == null || !navigator.mounted) return;
    final next = nonNegativeInt(amount)!;
    final dates = {...plan.dateAmounts, day: next};
    // The sheet's context, not a context read after the await: `ref` and `plan`
    // are all this needs.
    await guarded(
      navigator.context,
      ref,
      () => ref
          .read(plansConfigProvider.notifier)
          .save(plan.copyWithDateAmounts(dates)),
      what: l10n.plansSaved,
    );
    navigator.pop();
  }

  Widget _recomputeButton(
    BuildContext context,
    WidgetRef ref,
    LearningPlan plan,
    CalendarMode mode,
  ) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: ValueKey('recompute-open-${plan.id}'),
        icon: const Icon(Icons.auto_fix_high, size: 18),
        label: Text(l10n.plansRecompute),
        onPressed: () => Reflow.from(context, ref, plan, day, mode),
      ),
    );
  }

  /// The day's ledger, or an empty list when the catalog or log has not loaded.
  ///
  /// **Empty rather than a throw**, because this is a modal opened from a
  /// calendar cell and neither the catalog nor the fold is guaranteed to be there
  /// by then — a cold start is a legitimate state, not a failure.
  List<({LearningPlan plan, List<LedgerUnit> units})> _ledgerFor(
    WidgetRef ref,
    List<LearningPlan> firing,
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

  /// Whether every unit every firing plan owes on this day is already done.
  bool _allDone(List<({LearningPlan plan, List<LedgerUnit> units})> ledgers) =>
      ledgers.isNotEmpty && ledgers.every((e) => DayLedger.owed(e.units) == 0);

  /// Every unit row for [units], each with a checkbox.
  ///
  /// **The plan is the list; the log is what has been ticked against it.** A unit
  /// ticked in the unit grid still appears here, because the plan still asks for
  /// it, and the only way anything leaves is a deliberate planning act.
  ///
  /// **A tick is not an edit of the plan.** It writes to the event log with this
  /// plan's id and the day being looked at, so the unit grid, the progress bars
  /// and every count update immediately — and the plan still asks for the unit,
  /// which is the whole point of the ledger. Setting an amount is the opposite
  /// act and goes to the plan instead.
  ///
  /// [namePlanOnRow] prints the plan's name on the row, which the flat layout
  /// needs and the other two do not — there, a group above already says it.
  List<Widget> _unitRows(
    BuildContext context,
    WidgetRef ref,
    List<LedgerUnit> units,
    LearningPlan plan,
    CalendarMode mode, {
    bool namePlanOnRow = false,
  }) {
    if (units.isEmpty) return const [];
    final l10n = AppLocalizations.of(context);
    final catalog = ref.read(mergedCatalogProvider).asData?.value;
    final logger = ref.read(loggingServiceProvider);
    final doneHere = DayLedger.doneOnDay(units);

    Widget rowFor(LedgerUnit u) {
      final node = catalog?.byId(u.nodeId);
      final label = node == null
          ? '${u.nodeId} ${u.unitIndex}'
          : nodeAndUnit(l10n, node, u.unitIndex);
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
      if (namePlanOnRow) subtitle = '${plan.name} · $subtitle';

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
          final navigator = Navigator.of(context);
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
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      for (final u in units) rowFor(u),
      const Divider(height: 24),
    ];
  }

  /// Clear every firing plan's override for this date, so the day goes back to
  /// asking whatever its weekday and base amount say.
  Future<void> _clearOverrides(
    BuildContext context,
    WidgetRef ref,
    List<LearningPlan> firing,
  ) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    // Inside the write guard like every other write, and guarded before the
    // await: the sheet may be gone by then.
    if (!navigator.mounted) return;
    await guarded(navigator.context, ref, () async {
      final controller = ref.read(plansConfigProvider.notifier);
      for (final plan in firing) {
        final dates = {...plan.dateAmounts}..remove(day);
        await controller.save(plan.copyWithDateAmounts(dates));
      }
    }, what: l10n.plansSaved);
    navigator.pop();
  }

  /// The `+` and `−` row for the day.
  ///
  /// **Two removes, and they are not the same edit.** "Ask for one fewer" and
  /// "this plan had nothing to do that day" are different statements: a `0` says
  /// the plan was scheduled and asked for nothing, while skipping says it was
  /// not on the day at all. The day sheet already prints `0 · day off` for the
  /// first, and this keeps the distinction rather than collapsing it.
  ///
  /// `−` is offered only for plans the day has an opinion about — one that fires
  /// today or carries a lift — because removing from a day with nothing to
  /// remove would be a button that does nothing.
  Widget _planCommands(
    BuildContext sheetContext,
    WidgetRef ref,
    List<LearningPlan> firing,
  ) {
    final l10n = AppLocalizations.of(sheetContext);
    final controller = ref.read(plansConfigProvider.notifier);

    Future<void> save(LearningPlan next, String message) =>
        guarded(sheetContext, ref, () => controller.save(next), what: message);

    // Every plan, not just the firing ones: adding to a day a plan's rule skips
    // is exactly what makes it "also how you force a plan onto a day its rule
    // would not have chosen".
    final all = [
      ...firing,
      for (final p in config.plans)
        if (!firing.any((f) => f.id == p.id)) p,
    ];
    final removable = [
      ...firing,
      for (final p in config.plans)
        if (!firing.any((f) => f.id == p.id) && p.dateAmounts.containsKey(day))
          p,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              key: const ValueKey('day-add'),
              icon: const Icon(Icons.add),
              label: Text(l10n.plansDayAddWork),
              onPressed: () => _addToDay(sheetContext, ref, all, save),
            ),
            if (removable.isNotEmpty)
              TextButton.icon(
                key: const ValueKey('day-remove'),
                icon: const Icon(Icons.remove),
                label: Text(l10n.plansRemove),
                onPressed: () =>
                    _removeFromDay(sheetContext, ref, removable, save),
              ),
          ],
        ),
      ],
    );
  }

  /// Asks which plan the extra work belongs to, then raises that day.
  Future<void> _addToDay(
    BuildContext sheetContext,
    WidgetRef ref,
    List<LearningPlan> plans,
    Future<void> Function(LearningPlan, String) save,
  ) async {
    final l10n = AppLocalizations.of(sheetContext);
    final navigator = Navigator.of(sheetContext);
    if (!navigator.mounted) return;

    final chosen = await _pickPlanForDay(sheetContext, ref, plans, l10n);
    if (chosen == null || !navigator.mounted) return;

    final next = PlanEdit.addUnits(chosen, day, 1);
    final amount = DayAmount.of(next, dayInfoFor(day));
    await save(next, l10n.plansAddedUnits(chosen.name, amount));
  }

  /// The plan chooser for the day, with a way to start a new plan.
  Future<LearningPlan?> _pickPlanForDay(
    BuildContext sheetContext,
    WidgetRef ref,
    List<LearningPlan> plans,
    AppLocalizations l10n,
  ) {
    final catalog = ref.read(mergedCatalogProvider).asData?.value;

    return showModalBottomSheet<LearningPlan>(
      context: sheetContext,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.plansAddExisting,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
            for (final plan in plans)
              ListTile(
                key: ValueKey('add-to-${plan.id}'),
                title: Text(plan.name),
                onTap: () => Navigator.of(sheet).pop(plan),
              ),
            ListTile(
              key: const ValueKey('add-new-plan'),
              leading: const Icon(Icons.add),
              title: Text(l10n.plansAddNew),
              // Disabled rather than inert: a button that does nothing on tap
              // is a defect, and a cold start genuinely has no catalog to pick
              // a sefer from.
              onTap: catalog == null
                  ? null
                  : () async {
                      final navigator = Navigator.of(sheet);
                      // Read before the first await: reaching for `ref` after a
                      // gap is the async-misuse the analyzer is right to refuse,
                      // and a clock read does not need to be current.
                      final today = Day.of(ref.read(clockProvider)());
                      final chosen = await showNodePicker(
                        sheet,
                        title: l10n.plansAddNew,
                        showKindIcon: true,
                        choices: nodeChoices(
                          l10n,
                          catalog,
                          order: NodeOrder.name,
                        ),
                      );
                      if (chosen == null || !navigator.mounted) return;
                      // **The navigator's context, not `sheet`.** The sheet is
                      // the thing this callback is closing, so it is the one
                      // context that is *not* guaranteed still to be mounted
                      // after the picker closed; `navigator.mounted` is the
                      // check that actually covers what is used here. This is the
                      // same reasoning the day sheet's own prompts use.
                      final name = await promptForText(
                        navigator.context,
                        title: l10n.plansAddNew,
                        label: l10n.plansName,
                        initialValue: nodeName(l10n, chosen),
                        confirmLabel: l10n.plansSave,
                        cancelLabel: l10n.plansCancel,
                      );
                      if (name == null || !navigator.mounted) return;
                      final node = catalog.byId(chosen.id);
                      if (node == null) return;
                      // A real, tiny plan — see `PlanEdit.standalonePlan` for
                      // why it cannot be a note: #42's ledger reads the plan, so
                      // work added to a day with no plan has no row to tick.
                      // **One unit**, because this is the `+` command and every
                      // press of it is one more unit.
                      final created = PlanEdit.standalonePlan(
                        nodeId: node.id,
                        name: name.trim().isEmpty
                            ? nodeName(l10n, node)
                            : name.trim(),
                        day: today,
                        units: 1,
                      );
                      navigator.pop(created);
                    },
            ),
          ],
        ),
      ),
    );
  }

  /// The two removes, as a choice rather than two buttons side by side.
  ///
  /// A sheet rather than a second row, because the two are the same gesture with
  /// different meanings and a reader should be told which they are choosing.
  Future<void> _removeFromDay(
    BuildContext sheetContext,
    WidgetRef ref,
    List<LearningPlan> plans,
    Future<void> Function(LearningPlan, String) save,
  ) async {
    final l10n = AppLocalizations.of(sheetContext);
    final navigator = Navigator.of(sheetContext);
    if (!navigator.mounted) return;

    final choice =
        await showModalBottomSheet<({LearningPlan plan, bool whole})>(
          context: sheetContext,
          builder: (sheet) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    l10n.plansRemove,
                    style: Theme.of(sheet).textTheme.titleMedium,
                  ),
                ),
                for (final plan in plans)
                  ListTile(
                    key: ValueKey('remove-one-${plan.id}'),
                    title: Text(l10n.plansRemoveUnit),
                    subtitle: Text(plan.name),
                    onTap: () =>
                        Navigator.of(sheet).pop((plan: plan, whole: false)),
                  ),
                for (final plan in plans)
                  ListTile(
                    key: ValueKey('remove-all-${plan.id}'),
                    title: Text(l10n.plansRemovePlan),
                    subtitle: Text(
                      '${l10n.plansRemovePlanHelp} — ${plan.name}',
                    ),
                    onTap: () =>
                        Navigator.of(sheet).pop((plan: plan, whole: true)),
                  ),
              ],
            ),
          ),
        );
    if (choice == null || !navigator.mounted) return;

    final next = choice.whole
        ? PlanEdit.removePlanFromDay(choice.plan, day)
        : PlanEdit.removeUnit(choice.plan, day);
    await save(
      next,
      choice.whole
          ? l10n.plansPlanSkipped(choice.plan.name)
          : l10n.plansRemovedUnit(
              choice.plan.name,
              DayAmount.of(next, dayInfoFor(day)),
            ),
    );
  }
}

/// One plan's line in the collapsed layout: a count, and the units behind a tap.
///
/// A widget rather than an `ExpansionTile` because the header has to carry the
/// **count** as well as the name, and because the rows inside are built by the
/// sheet — which is where the `guarded` write lives, and a header that grew its
/// own tick rows would be a second place to keep in step.
class _CollapsedPlan extends StatefulWidget {
  const _CollapsedPlan({
    super.key,
    required this.plan,
    required this.units,
    required this.expanded,
  });

  final LearningPlan plan;
  final List<LedgerUnit> units;

  /// The rows for the expanded state, built by the sheet.
  final List<Widget> Function() expanded;

  @override
  State<_CollapsedPlan> createState() => _CollapsedPlanState();
}

class _CollapsedPlanState extends State<_CollapsedPlan> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final done = DayLedger.doneOnDay(widget.units);
    final owed = DayLedger.owed(widget.units);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          // **Not the same key as the widget above it.** Two widgets keyed
          // identically means a finder matching `collapsed-<id>` gets two hits
          // and cannot say which it tapped — which is how a test that looks like
          // it covers the header ends up asserting on the container.
          key: ValueKey('collapsed-tile-${widget.plan.id}'),
          title: Text(widget.plan.name),
          subtitle: Text(
            // **The count on the line even when collapsed.** A glance still has
            // to say whether anything is outstanding, which is the whole reason
            // to pick this layout rather than to scroll.
            owed == 0
                ? l10n.plansLedgerEmpty
                : l10n.plansLedgerCount(done, widget.units.length),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open) ...widget.expanded(),
      ],
    );
  }
}
