import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/plans.dart';
import '../../application/providers.dart';
import '../../application/stats.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../core/day.dart';
import '../../core/parse.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/usecases/learning_plan.dart';
import '../../domain/usecases/plan_position.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/date_field.dart';
import '../common/guarded.dart';
import '../common/naming.dart';
import '../common/text_prompt.dart';
import '../common/node_picker.dart';

/// The depth of a plan: the days that differ from the base amount, and the
/// seferim it works through in order.
///
/// Split out of [EditPlanScreen] rather than appended to it. The basic shape —
/// name, amounts, when it fires, what a missed day does — is what a user edits
/// most, and burying it under three more sections to reach it would make the
/// common case the expensive one. This is the same decision the calendar makes
/// in the other direction: a per-day amount is easiest to see *there*, so the
/// editor's job is to hold the rules, and the calendar's to show the result.
class EditPlanAdvancedScreen extends ConsumerWidget {
  const EditPlanAdvancedScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(plansConfigProvider);
    final plan = config.plans.where((p) => p.id == planId).firstOrNull;

    // A plan deleted from under this screen (or an id that never existed) shows
    // an empty state rather than throwing: a route can be restored or deep
    // linked after the thing it named is gone.
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).plansAdvancedTitle)),
        body: const Center(child: Text('-')),
      );
    }
    return _AdvancedForm(key: ValueKey(planId), plan: plan);
  }
}

class _AdvancedForm extends ConsumerStatefulWidget {
  const _AdvancedForm({super.key, required this.plan});

  final LearningPlan plan;

  @override
  ConsumerState<_AdvancedForm> createState() => _AdvancedFormState();
}

class _AdvancedFormState extends ConsumerState<_AdvancedForm> {
  late Map<int, int> _weekdays;
  late Map<Day, int> _dates;
  late List<PlanItem> _items;
  late bool _flows;

  @override
  void initState() {
    super.initState();
    _weekdays = {...widget.plan.weekdayAmounts};
    _dates = {...widget.plan.dateAmounts};
    _items = [...widget.plan.items];
    _flows = widget.plan.flowsToNextItem;
  }

  /// Applies the edits to the plan they came from, rather than rebuilding it.
  ///
  /// The rule, name, amounts and spillover are not on this screen, so writing a
  /// fresh plan from what is visible would blank every one of them. Same reason
  /// the main editor carries its fields forward.
  LearningPlan _applyTo() {
    final p = widget.plan;
    return LearningPlan(
      id: p.id,
      name: p.name,
      assignments: p.assignments,
      overrides: p.overrides,
      displayCalendar: p.displayCalendar,
      unitsPerDay: p.unitsPerDay,
      weekdayAmounts: _weekdays,
      dateAmounts: _dates,
      spillover: p.spillover,
      items: _items,
      flowsToNextItem: _flows,
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    await guarded(
      context,
      ref,
      () => ref.read(plansConfigProvider.notifier).save(_applyTo()),
      what: l10n.plansSaved,
    );
    navigator.pop();
  }

  /// The amount a row shows. **`0` is a value, not a blank.**
  ///
  /// This is the whole reason a day off is an amount rather than a flag: an
  /// empty field means "not set, fall back to the base", and `0` means "nothing
  /// on this day". Rendering them the same way — or letting `0` read as empty —
  /// would put back exactly the ambiguity the design removed, and the user could
  /// not tell a day off from a day they had not configured.
  static String _amountText(AppLocalizations l10n, int amount) =>
      amount == 0 ? '0 · ${l10n.plansDayOff}' : '$amount';

  Future<void> _addWeekday() async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            // A bare list of seven days with no heading is a list the user has
            // to interpret, so it says what it is asking.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.plansWeekdayPick,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (var d = DateTime.monday; d <= DateTime.sunday; d++)
              ListTile(
                title: Text(weekdayName(l10n, d)),
                trailing: _weekdays.containsKey(d) ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(sheetContext).pop(d),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    final amount = await _askAmount(
      title: l10n.plansWeekdayOverrides,
      initial: _weekdays[chosen] ?? widget.plan.unitsPerDay,
    );
    if (amount == null) return;
    setState(() => _weekdays[chosen] = amount);
  }

  Future<void> _addDate() async {
    final l10n = AppLocalizations.of(context);
    final today = Day.of(ref.read(clockProvider)());
    // The shared date control rather than `showDatePicker`, which is a
    // Gregorian grid: a reader who thinks in Hebrew dates could set an override
    // for one only by navigating that grid, and could not type `ד׳ טבת תשפ״ו`
    // or `4 Tevat 5786` at all. It offers the grid *and* the field, so choosing
    // a date by eye still works.
    //
    // The year a yearless date takes comes from the clock's day, so `Jan 4` in
    // a plan opened in 2027 is 4 January 2027 and not 4 January of whatever year
    // the device thinks it is.
    final picked = await promptForDate(
      context,
      initial: today,
      reference: today,
      mode: ref.read(settingsProvider).calendar,
      title: l10n.plansDateAmount,
      confirmLabel: l10n.plansSave,
      cancelLabel: l10n.plansCancel,
    );
    if (picked == null || !mounted) return;
    final amount = await _askAmount(
      title: l10n.plansDateAmount,
      help: l10n.plansDateAmountHelp,
      initial: _dates[picked] ?? widget.plan.unitsPerDay,
    );
    if (amount == null) return;
    setState(() => _dates[picked] = amount);
  }

  /// One prompt for an amount, so there is a single place that can refuse one.
  ///
  /// Through the repository's shared prompt, which owns the controller. The
  /// obvious hand-rolled version — make a controller, show a dialog, dispose it
  /// when the await returns — is the exact bug `text_prompt_guard_test.dart`
  /// exists to prevent: the future completes when the route is *popped*, not
  /// when it is gone, so the exit animation renders one more frame against a
  /// disposed controller and throws. It threw, in this file, before the shared
  /// prompt was used.
  ///
  /// Its `validate` also means a refused amount keeps the dialog open with what
  /// was typed. Closing and then complaining would throw away the input, which
  /// on a keypad phone is a dozen key presses to retype.
  Future<int?> _askAmount({
    required String title,
    String? help,
    required int initial,
  }) async {
    final l10n = AppLocalizations.of(context);
    final typed = await promptForText(
      context,
      title: title,
      body: help,
      label: l10n.plansUnitsPerDay,
      initialValue: '$initial',
      keyboardType: TextInputType.number,
      confirmLabel: l10n.plansSave,
      cancelLabel: l10n.plansCancel,
      validate: (v) {
        // One parser for the whole app, so 'ten', '-3' and '' all fail the same
        // way here as they do everywhere else.
        if (nonNegativeInt(v) == null) return l10n.plansAmountInvalid;
        return null;
      },
    );
    if (typed == null) return null;
    return nonNegativeInt(typed);
  }

  /// Adds a sefer to the sequence. [catalog] is passed in rather than read here.
  ///
  /// It used to open with `ref.read(mergedCatalogProvider).asData?.value` and
  /// `if (catalog == null) return;`, and on a cold start that is a button which
  /// does nothing at all: the catalog has not finished loading, the read is
  /// never re-taken, and no error is shown. The user taps *Add a sefer* and the
  /// screen does not move, which reads as a broken app rather than a slow one.
  ///
  /// [build] watches the catalog and the button is disabled until it arrives, so
  /// the one state where there is nothing to offer is a state the user can see.
  Future<void> _addItem(Catalog catalog) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showNodePicker(
      context,
      title: l10n.plansSequenceAdd,
      showKindIcon: true,
      choices: nodeChoices(l10n, catalog, order: NodeOrder.name),
    );
    if (chosen == null) return;
    setState(() {
      // A category becomes **one** item, not one item per leaf. "Yoma, Sukkah,
      // Chagigah, then Moed" means Moed is a single step, and a plan's totals
      // already roll a category up to every unit under it — expanding it here
      // would make the sequence unreadable and the count wrong to read.
      //
      // A minted id, and not `'item-${_items.length}-$nodeId'`, which is what
      // this read before. A length is a *position*, not an identity, and the
      // same sefer added again once the list has shrunk back to that length
      // re-mints the id of the copy already sitting there: add Moed twice, take
      // the first out, add Moed again, and both items are `item-1-shas.moed`.
      //
      // The collision is silent and it is the sequence that pays, twice over.
      // The rows are keyed by this id, so two items sharing one are two tiles
      // Flutter collapses into one — the list stops being reorderable — and
      // [PlanPosition] reports `itemId`, so the position can no longer say
      // which sefer you are on. Same answer the cycle editor, the node editor
      // and the meforish sheet all already give.
      _items = [
        ..._items,
        PlanItem(id: const Uuid().v4(), nodeId: chosen.id),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(settingsProvider.select((s) => s.calendar));
    // **Watched**, not read. The sequence section asks the catalog three
    // questions — what a sefer is called, what is under it, how many units the
    // whole thing is — and every one of them was answered by a `ref.read` that
    // took "not loaded yet" as the final answer. So a plan opened on a cold
    // start showed raw node ids in place of names, "0 units in total" under a
    // real sequence, and an *Add a sefer* button that opened nothing.
    //
    // One watch, here, and the three are answered from it. The screen next door
    // (`EditCycleScreen`) and the calendar both already did this, which is what
    // makes the miss here a rule broken rather than a rule never stated.
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plansAdvancedTitle),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(l10n.plansSave),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(l10n.plansWeekdayOverrides),
          if (_weekdays.isEmpty)
            _empty(l10n.plansWeekdayOverridesEmpty)
          else
            for (final entry in _weekdays.entries)
              ListTile(
                key: ValueKey('weekday-${entry.key}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(weekdayName(l10n, entry.key)),
                subtitle: Text(_amountText(l10n, entry.value)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: l10n.tooltipRemove,
                  onPressed: () => setState(() => _weekdays.remove(entry.key)),
                ),
                onTap: () async {
                  final amount = await _askAmount(
                    title: l10n.plansWeekdayOverrides,
                    initial: entry.value,
                  );
                  if (amount != null) {
                    setState(() => _weekdays[entry.key] = amount);
                  }
                },
              ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.plansWeekdayAdd),
              onPressed: _addWeekday,
            ),
          ),
          const Divider(height: 32),
          _header(l10n.plansDateOverrides),
          if (_dates.isEmpty)
            _empty(l10n.plansDateOverridesEmpty)
          else
            for (final entry in _dates.entries)
              ListTile(
                key: ValueKey('date-${entry.key}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(DateDisplay.format(entry.key.midnight, mode)),
                subtitle: Text(_amountText(l10n, entry.value)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: l10n.tooltipRemove,
                  onPressed: () => setState(() => _dates.remove(entry.key)),
                ),
                onTap: () async {
                  final amount = await _askAmount(
                    title: l10n.plansDateAmount,
                    help: l10n.plansDateAmountHelp,
                    initial: entry.value,
                  );
                  if (amount != null) {
                    setState(() => _dates[entry.key] = amount);
                  }
                },
              ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.plansDateAdd),
              onPressed: _addDate,
            ),
          ),
          const Divider(height: 32),
          _header(l10n.plansSequence),
          if (_items.isEmpty)
            _empty(l10n.plansSequenceEmpty)
          else ...[
            // Reorderable *and* up/down, because drag is unusable on a D-pad.
            // The same pairing `EditCycleScreen` uses, for the same reason.
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              // onReorderItem, not onReorder: it already accounts for the removed
              // item, so no index fix-up is needed. Same reason as the cycle
              // editor's, which this pairs with.
              onReorderItem: (from, to) => setState(
                  () => _items.insert(to, _items.removeAt(from))),
              children: [
                for (var i = 0; i < _items.length; i++)
                  _itemTile(l10n, i, catalog),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.plansSequenceTotal(_totalUnits(catalog)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.plansSequenceAdd),
              // Disabled rather than silently inert: a button that does nothing
              // on tap is the defect this replaced.
              onPressed: catalog == null ? null : () => _addItem(catalog),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _flows,
            onChanged: (v) => setState(() => _flows = v),
            title: Text(l10n.plansFlowToNext),
            subtitle: Text(l10n.plansFlowToNextHelp),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  int _totalUnits(Catalog? catalog) {
    if (catalog == null) return 0;
    return PlanProgress.totalUnits(_applyTo(), catalog);
  }

  /// One row of the sequence, keyed by the item's own id.
  ///
  /// The key is the id, not the index and not the row's text, and both of the
  /// alternatives are the reason this section had no widget coverage at all.
  /// `find.text('Shabbos')` is ambiguous the moment the same sefer is in the
  /// list twice — which is a legitimate thing for a sequence to be — and "the
  /// tile at index N" is a claim about scroll position, which a finder cannot
  /// rely on in a `ListView` that builds lazily. Untestable is how a screen
  /// whose *Add a sefer* button opened nothing kept shipping.
  ///
  /// The id rather than `'${item.id}#$i'`, the shape `EditCycleScreen` uses:
  /// the index there cannot collide, because a cycle's segments are the node
  /// itself, whereas here the id has to be an identity for its own sake and
  /// carrying the index only hid that.
  Widget _itemTile(AppLocalizations l10n, int i, Catalog? catalog) {
    final item = _items[i];
    final node = catalog?.byId(item.nodeId);
    return ListTile(
      key: ValueKey('item-${item.id}'),
      contentPadding: EdgeInsets.zero,
      leading: ReorderableDragStartListener(
          index: i, child: const Icon(Icons.drag_handle)),
      title: Text(node == null ? item.nodeId : nodeName(l10n, node)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            tooltip: l10n.tooltipMoveUp,
            onPressed: i == 0
                ? null
                : () => setState(() => _items.insert(i - 1, _items.removeAt(i))),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 18),
            tooltip: l10n.tooltipMoveDown,
            onPressed: i == _items.length - 1
                ? null
                : () => setState(() => _items.insert(i + 1, _items.removeAt(i))),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: l10n.tooltipRemove,
            onPressed: () => setState(() => _items.removeAt(i)),
          ),
        ],
      ),
    );
  }

  Widget _header(String text) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );
}
