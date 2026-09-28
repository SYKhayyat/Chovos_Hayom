import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/plans.dart';
import '../../application/providers.dart';
import '../../application/stats.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../core/day.dart';
import '../../core/parse.dart';
import '../../domain/usecases/learning_plan.dart';
import '../../domain/usecases/plan_position.dart';
import '../../l10n/generated/app_localizations.dart';
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
    final now = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final amount = await _askAmount(
      title: l10n.plansDateAmount,
      help: l10n.plansDateAmountHelp,
      initial: _dates[Day.of(picked)] ?? widget.plan.unitsPerDay,
    );
    if (amount == null) return;
    setState(() => _dates[Day.of(picked)] = amount);
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

  Future<void> _addItem() async {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.read(mergedCatalogProvider).asData?.value;
    if (catalog == null) return;
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
      _items = [
        ..._items,
        PlanItem(id: 'item-${_items.length}-${chosen.id}', nodeId: chosen.id),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(settingsProvider.select((s) => s.calendar));

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
              onReorderItem: (from, to) => setState(
                  () => _items.insert(to, _items.removeAt(from))),
              children: [
                for (var i = 0; i < _items.length; i++) _itemTile(l10n, i),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.plansSequenceTotal(_totalUnits()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.plansSequenceAdd),
              onPressed: _addItem,
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

  int _totalUnits() {
    final catalog = ref.read(mergedCatalogProvider).asData?.value;
    if (catalog == null) return 0;
    return PlanProgress.totalUnits(_applyTo(), catalog);
  }

  Widget _itemTile(AppLocalizations l10n, int i) {
    final item = _items[i];
    final node = ref.read(catalogNodeProvider(item.nodeId));
    return ListTile(
      key: ValueKey('${item.id}#$i'),
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
