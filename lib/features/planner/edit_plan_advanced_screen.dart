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
import '../../domain/usecases/plan_review.dart';
import '../../domain/usecases/plan_run.dart';
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
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).plansAdvancedTitle),
        ),
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
  late bool _startToday;
  late Day? _startDay;
  late PlanPacing _pacing;

  /// The plan's review request, or null for "this plan asks for no review"
  /// (#50). Null is a real setting here rather than "not configured": the
  /// default for a plan nobody has touched is to ask for no review.
  late PlanReview? _review;

  /// Why the start date is a toggle and not a field showing today.
  ///
  /// The plan's own rule is that an unset start date *means* today
  /// (`LearningPlan.startDay` is null), and it is stored that way so "starts
  /// today" stays true as the days pass. A field pre-filled with today's date
  /// would therefore freeze a day the user never chose, and the plan would stop
  /// following the device — a change the user did not make and cannot see.
  bool get _startsToday => _startToday;

  @override
  void initState() {
    super.initState();
    _weekdays = {...widget.plan.weekdayAmounts};
    _dates = {...widget.plan.dateAmounts};
    _items = [...widget.plan.items];
    _flows = widget.plan.flowsToNextItem;
    _startToday = widget.plan.startDay == null;
    _startDay = widget.plan.startDay;
    _pacing = widget.plan.pacing;
    _review = widget.plan.review;
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
      startDay: _startsToday ? null : _startDay,
      pacing: _pacing,
      review: _review,
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
                trailing: _weekdays.containsKey(d)
                    ? const Icon(Icons.check)
                    : null,
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
      _items = [..._items, PlanItem(id: const Uuid().v4(), nodeId: chosen.id)];
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
        actions: [TextButton(onPressed: _save, child: Text(l10n.plansSave))],
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
              onReorderItem: (from, to) =>
                  setState(() => _items.insert(to, _items.removeAt(from))),
              children: [
                for (var i = 0; i < _items.length; i++)
                  _itemTile(l10n, i, catalog),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _totalLabel(l10n, catalog),
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
            key: const ValueKey('flow-to-next'),
            contentPadding: EdgeInsets.zero,
            value: _flows,
            onChanged: (v) => setState(() => _flows = v),
            title: Text(l10n.plansFlowToNext),
            subtitle: Text(l10n.plansFlowToNextHelp),
          ),
          _rangeEditor(l10n, catalog),
          const Divider(height: 32),
          _header(l10n.plansStartDay),
          SwitchListTile(
            key: const ValueKey('start-today'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _startsToday,
            onChanged: (v) => setState(() {
              _startToday = v;
              // Switching away from "today" needs a day to switch to, and the
              // clock is the only honest source for the default. Taken at the
              // moment the toggle is flipped rather than at build, so the field
              // does not silently re-anchor on a rebuild.
              if (!v) _startDay ??= Day.of(ref.read(clockProvider)());
            }),
            title: Text(l10n.plansStartDayToday),
          ),
          if (!_startsToday) ...[
            ListTile(
              key: const ValueKey('start-day'),
              contentPadding: EdgeInsets.zero,
              title: Text(DateDisplay.format(_startDay!.midnight, mode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickStartDay,
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.plansStartDayHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(height: 32),
          _header(l10n.plansPacing),
          // **Two radios, not a dropdown, and not two independent fields.**
          // Pacing is one of two answers to one question, so the UI offers them
          // as one choice; letting both be filled in is what the sealed
          // `PlanPacing` exists to make unrepresentable in the first place.
          RadioGroup<_PacingKind>(
            groupValue: _pacingKind,
            onChanged: (v) => setState(() => _setPacingKind(v!)),
            child: Column(
              children: [
                for (final kind in _PacingKind.values)
                  RadioListTile<_PacingKind>(
                    key: ValueKey('pacing-${kind.name}'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: kind,
                    title: Text(
                      kind == _PacingKind.perDay
                          ? l10n.plansPacingPerDay
                          : l10n.plansPacingFinishBy,
                    ),
                    subtitle: kind == _PacingKind.finishBy
                        ? Text(l10n.plansPacingFinishByHelp)
                        : null,
                  ),
              ],
            ),
          ),
          if (_pacingKind == _PacingKind.finishBy)
            ListTile(
              key: const ValueKey('pacing-finish-date'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                DateDisplay.format(
                  (_pacing.finishDay ?? Day.of(ref.read(clockProvider)()))
                      .midnight,
                  mode,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickFinishDay,
            ),
          const Divider(height: 32),
          _header(l10n.plansReview),
          _reviewControls(l10n, mode),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.plansReviewHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// The review schedule's own controls: a kind, and whatever that kind needs.
  ///
  /// **Off is the first option, and it is a real setting.** A plan nobody has
  /// touched does not ask for a review, and the control says so rather than
  /// showing a schedule the plan does not have.
  Widget _reviewControls(AppLocalizations l10n, CalendarMode mode) {
    final review = _review;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RadioGroup<_ReviewKind>(
          groupValue: _reviewKind,
          onChanged: (v) => setState(() => _setReviewKind(v!)),
          child: Column(
            children: [
              for (final kind in _ReviewKind.values)
                RadioListTile<_ReviewKind>(
                  key: ValueKey('review-${kind.name}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: kind,
                  title: Text(_reviewKindLabel(l10n, kind)),
                  subtitle: Text(_reviewKindHelp(l10n, kind)),
                ),
            ],
          ),
        ),
        if (review != null) ...[
          // **The window is asked in days and only in days.** A plan whose rule
          // is written in the Hebrew calendar still reaches back in calendar
          // days; a Hebrew month is 29 or 30 of them, and making the window
          // Hebrew for some plans and not others would be a difference nobody
          // would notice until a unit sat due for a fortnight.
          TextField(
            key: const ValueKey('review-window'),
            controller: _windowController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.plansReviewWindow,
              helperText: l10n.plansReviewWindowHelp,
            ),
          ),
          const SizedBox(height: 8),
          if (review.when is ReviewOnWeekday) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.plansReviewOnWeekdayHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (var i = 0; i < 7; i++)
                  Padding(
                    padding: const EdgeInsets.all(1),
                    child: OutlinedButton(
                      key: ValueKey('review-weekday-${i + 1}'),
                      onPressed: () => setState(() {
                        _review = PlanReview(
                          windowDays: _review!.windowDays,
                          when: ReviewOnWeekday(i + 1),
                        );
                      }),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                        backgroundColor:
                            (review.when as ReviewOnWeekday).weekday == i + 1
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                      ),
                      child: Text('${i + 1}'),
                    ),
                  ),
              ],
            ),
          ],
          if (review.when is ReviewOnDate)
            ListTile(
              key: const ValueKey('review-on-date'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                DateDisplay.format(
                  (review.when as ReviewOnDate).day.midnight,
                  mode,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickReviewDate,
            ),
          if (review.when is ReviewEveryDays) ...[
            ListTile(
              key: const ValueKey('review-every-days'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.plansReviewEvery((review.when as ReviewEveryDays).days),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickReviewEvery,
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _pickReviewDate() async {
    final l10n = AppLocalizations.of(context);
    final review = _review;
    if (review == null) return;
    final today = Day.of(ref.read(clockProvider)());
    final picked = await promptForDate(
      context,
      initial: (review.when as ReviewOnDate).day,
      reference: today,
      mode: ref.read(settingsProvider).calendar,
      title: l10n.plansReviewOnDate,
      confirmLabel: l10n.plansSave,
      cancelLabel: l10n.plansCancel,
    );
    if (picked == null || !mounted) return;
    setState(
      () => _review = PlanReview(
        windowDays: review.windowDays,
        when: ReviewOnDate(picked),
      ),
    );
  }

  Future<void> _pickReviewEvery() async {
    final l10n = AppLocalizations.of(context);
    final review = _review;
    if (review == null) return;
    final navigator = Navigator.of(context);
    if (!navigator.mounted) return;
    final days = await promptForText(
      context,
      title: l10n.plansReviewEveryDays,
      body: l10n.plansReviewEveryDaysHelp,
      label: l10n.plansReviewEvery(_defaultEveryDays()),
      initialValue: '${(review.when as ReviewEveryDays).days}',
      keyboardType: TextInputType.number,
      confirmLabel: l10n.plansSave,
      cancelLabel: l10n.plansCancel,
      validate: (v) => nonNegativeInt(v) == null || nonNegativeInt(v)! < 1
          ? l10n.plansAmountInvalid
          : null,
    );
    if (days == null || !navigator.mounted) return;
    final every = nonNegativeInt(days)!;
    if (every < 1) return;
    setState(() {
      _review = PlanReview(
        windowDays: _review!.windowDays,
        // **The start day is kept**, because changing the period is not
        // changing when the count began. The two are separate settings, and
        // moving one silently is how a schedule drifts from what was chosen.
        when: ReviewEveryDays(
          every,
          from: (review.when as ReviewEveryDays).from,
        ),
      );
    });
  }

  /// The period a new "every few days" review starts at — a week, which is the
  /// shortest period anybody asks a chazara for.
  static int _defaultEveryDays() => 7;

  /// The window the field shows, and what the field edits.
  ///
  /// **One number, read once.** A screen that shows a window and saves a
  /// different one is the bug this pair exists to prevent, so the controller is
  /// only ever written from the plan and read on save.
  late final TextEditingController _windowController = TextEditingController(
    text: '${_review?.windowDays ?? 7}',
  )..addListener(_onWindowChanged);

  void _onWindowChanged() {
    final days = nonNegativeInt(_windowController.text);
    final review = _review;
    if (days == null || days < 1 || review == null) return;
    if (days == review.windowDays) return;
    setState(() => _review = PlanReview(windowDays: days, when: review.when));
  }

  @override
  void dispose() {
    _windowController.dispose();
    super.dispose();
  }

  _ReviewKind get _reviewKind {
    final when = _review?.when;
    if (when is ReviewOnWeekday) return _ReviewKind.weekday;
    if (when is ReviewEveryDays) return _ReviewKind.everyDays;
    if (when is ReviewOnDate) return _ReviewKind.onDate;
    return _ReviewKind.off;
  }

  /// Switching the kind keeps the window, so flipping between the three
  /// schedules and back does not lose how far the review reaches.
  void _setReviewKind(_ReviewKind kind) {
    setState(() {
      final window = _review?.windowDays ?? _windowInt();
      final every = _review?.when is ReviewEveryDays
          ? (_review!.when as ReviewEveryDays).days
          : _defaultEveryDays();
      final from = _review?.when is ReviewEveryDays
          ? (_review!.when as ReviewEveryDays).from
          : null;
      _review = switch (kind) {
        _ReviewKind.off => null,
        _ReviewKind.weekday => PlanReview(
          windowDays: window,
          when: ReviewOnWeekday(
            _review?.when is ReviewOnWeekday
                ? (_review!.when as ReviewOnWeekday).weekday
                : DateTime.saturday,
          ),
        ),
        _ReviewKind.everyDays => PlanReview(
          windowDays: window,
          when: ReviewEveryDays(every, from: from),
        ),
        _ReviewKind.onDate => PlanReview(
          windowDays: window,
          when: ReviewOnDate(
            _review?.when is ReviewOnDate
                ? (_review!.when as ReviewOnDate).day
                : Day.of(ref.read(clockProvider)()),
          ),
        ),
      };
      _windowController.text = '$window';
    });
  }

  int _windowInt() => nonNegativeInt(_windowController.text) ?? 7;

  static String _reviewKindLabel(AppLocalizations l10n, _ReviewKind kind) =>
      switch (kind) {
        _ReviewKind.off => l10n.plansReviewOff,
        _ReviewKind.weekday => l10n.plansReviewOnWeekday,
        _ReviewKind.everyDays => l10n.plansReviewEveryDays,
        _ReviewKind.onDate => l10n.plansReviewOnDate,
      };

  static String _reviewKindHelp(AppLocalizations l10n, _ReviewKind kind) =>
      switch (kind) {
        _ReviewKind.off => l10n.plansReviewOffHelp,
        _ReviewKind.weekday => l10n.plansReviewOnWeekdayHelp,
        _ReviewKind.everyDays => l10n.plansReviewEveryDaysHelp,
        _ReviewKind.onDate => l10n.plansReviewOnDateHelp,
      };

  _PacingKind get _pacingKind =>
      _pacing.finishDay != null ? _PacingKind.finishBy : _PacingKind.perDay;

  /// Switching pacing mode keeps whichever answer is already filled in, so
  /// flipping to finish-by and back does not lose the daily amount.
  void _setPacingKind(_PacingKind kind) {
    setState(() {
      _pacing = switch (kind) {
        _PacingKind.perDay => AmountPerDay(
          _pacing.unitsPerDay ?? widget.plan.unitsPerDay,
        ),
        _PacingKind.finishBy => FinishBy(
          _pacing.finishDay ?? Day.of(ref.read(clockProvider)()),
        ),
      };
    });
  }

  Future<void> _pickStartDay() async {
    final l10n = AppLocalizations.of(context);
    final today = Day.of(ref.read(clockProvider)());
    final picked = await promptForDate(
      context,
      initial: _startDay ?? today,
      reference: today,
      mode: ref.read(settingsProvider).calendar,
      title: l10n.plansStartDay,
      confirmLabel: l10n.plansSave,
      cancelLabel: l10n.plansCancel,
    );
    if (picked == null || !mounted) return;
    setState(() => _startDay = picked);
  }

  Future<void> _pickFinishDay() async {
    final l10n = AppLocalizations.of(context);
    final today = Day.of(ref.read(clockProvider)());
    final picked = await promptForDate(
      context,
      initial: _pacing.finishDay ?? today,
      reference: today,
      mode: ref.read(settingsProvider).calendar,
      title: l10n.plansPacingFinishDate,
      confirmLabel: l10n.plansSave,
      cancelLabel: l10n.plansCancel,
    );
    if (picked == null || !mounted) return;
    setState(() => _pacing = FinishBy(picked));
  }

  /// The chain's total, or the honest statement that it has none.
  ///
  /// **A wrapping or open-ended range has no total, so it does not get a
  /// fraction.** The owner's ruling: progress there is how many units have been
  /// done, and the *plan* screen is where that count belongs — this is the
  /// editor, and it has no fold to read, so it says only that there is no end
  /// set. Inventing a denominator for an endless plan is the kind of number this
  /// repository's rules exist to stop.
  ///
  /// Empty rather than a misleading zero when the catalog has not loaded: this
  /// screen watches for it and re-renders, so the line appears once it can be
  /// answered.
  String _totalLabel(AppLocalizations l10n, Catalog? catalog) {
    if (catalog == null || _items.isEmpty) return '';
    final total = PlanRunProgress.totalUnits(_applyTo(), catalog);
    if (total != null) return l10n.plansSequenceTotal(total);
    final open = _items.any((i) => i.wrapsRange || i.endUnit == null);
    return open ? l10n.plansSequenceTotalOpen(totalUnitsWhenOpen(catalog)) : '';
  }

  /// Units in the chain, used only as the "so far" figure on the endless line.
  ///
  /// Zero here is a real answer, not a placeholder: with no log in scope the
  /// count of *learned* units is genuinely zero, and the figure that matters to
  /// a user reading their own plan is how big it is, not how far along they are.
  int totalUnitsWhenOpen(Catalog catalog) {
    var total = 0;
    for (var i = 0; i < _items.length; i++) {
      final range = PlanRange.resolve(_applyTo(), catalog, i);
      if (range == null) continue;
      total += range.wraps
          ? (range.node.isLeaf ? range.length : 0)
          : (range.node.isLeaf ? range.length : range.walk(catalog).length);
    }
    return total;
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
  /// One row of the sequence.
  ///
  /// **A flat `ListTile`, and deliberately not a `Column` wrapping one.** The row
  /// sits directly inside [ReorderableListView], which lays its children out
  /// itself and needs each of them to be the row — a wrapper changed the height
  /// the reorder maths uses and the list stopped building. So the range editor
  /// is a sibling section below the list rather than something folded into a row,
  /// which also keeps a four-sefer chain from opening as eight sets of fields.
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
        index: i,
        child: const Icon(Icons.drag_handle),
      ),
      title: Text(node == null ? item.nodeId : nodeName(l10n, node)),
      subtitle: _rangeSubtitle(l10n, item),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            tooltip: l10n.tooltipMoveUp,
            onPressed: i == 0
                ? null
                : () =>
                      setState(() => _items.insert(i - 1, _items.removeAt(i))),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 18),
            tooltip: l10n.tooltipMoveDown,
            onPressed: i == _items.length - 1
                ? null
                : () =>
                      setState(() => _items.insert(i + 1, _items.removeAt(i))),
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

  /// One line saying what the range currently is, so it is visible without
  /// opening the section below. Absent bounds are described, not shown blank.
  Widget? _rangeSubtitle(AppLocalizations l10n, PlanItem item) {
    final parts = <String>[];
    if (item.startUnit != null) {
      parts.add('${l10n.plansRangeFrom} ${item.startUnit}');
    }
    parts.add(
      item.endUnit == null
          ? l10n.plansRangeNoEnd
          : '${l10n.plansRangeTo} ${item.endUnit}',
    );
    if (item.wrapsRange) parts.add(l10n.plansRangeWrap);
    return Text(
      parts.join(' · '),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  /// The range controls, one block per sefer in the chain.
  ///
  /// Keys carry the item's id because two entries may legitimately be the same
  /// sefer, and a finder keyed on position would then be pointing at whichever
  /// one happens to be laid out first.
  Widget _rangeEditor(AppLocalizations l10n, Catalog? catalog) {
    if (catalog == null || _items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        _header(l10n.plansRange),
        Text(l10n.plansRangeHelp, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        for (final item in _items) _rangeRow(l10n, item),
      ],
    );
  }

  Widget _rangeRow(AppLocalizations l10n, PlanItem item) {
    void replace(PlanItem next) => setState(() {
      final at = _items.indexWhere((i) => i.id == item.id);
      if (at >= 0) _items[at] = next;
    });

    return Padding(
      key: ValueKey('range-${item.id}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _UnitField(
                  key: ValueKey('range-from-${item.id}'),
                  label: l10n.plansRangeFrom,
                  value: item.startUnit,
                  onChanged: (v) => replace(
                    _copyItem(item, startUnit: v, clearStart: v == null),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _UnitField(
                  key: ValueKey('range-to-${item.id}'),
                  label: l10n.plansRangeTo,
                  value: item.endUnit,
                  onChanged: (v) =>
                      replace(_copyItem(item, endUnit: v, clearEnd: v == null)),
                ),
              ),
            ],
          ),
          SwitchListTile(
            key: ValueKey('wrap-${item.id}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: item.wrapsRange,
            onChanged: (v) => replace(_copyItem(item, wrapsRange: v)),
            title: Text(l10n.plansRangeWrap),
            subtitle: Text(l10n.plansRangeWrapHelp),
          ),
        ],
      ),
    );
  }

  /// A copy of [item] with the named bounds changed.
  ///
  /// **Null is a value here, not "leave it alone."** Clearing the last unit is
  /// how a user says "no end", which is a different plan from one that ends at
  /// the sefer's last unit — so the field has to be able to produce null, and
  /// this is where that happens. `clearStart`/`clearEnd` are separate from the
  /// values because a `?? item.startUnit` fallback would turn an explicit null
  /// back into the old one, and the field could then never clear anything.
  static PlanItem _copyItem(
    PlanItem item, {
    int? startUnit,
    int? endUnit,
    bool clearStart = false,
    bool clearEnd = false,
    bool? wrapsRange,
  }) => PlanItem(
    id: item.id,
    nodeId: item.nodeId,
    label: item.label,
    startUnit: clearStart ? null : (startUnit ?? item.startUnit),
    endUnit: clearEnd ? null : (endUnit ?? item.endUnit),
    wrapsRange: wrapsRange ?? item.wrapsRange,
  );

  Widget _header(String text) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

/// Which of pacing's two mutually exclusive answers is in force.
///
/// A UI-side enum rather than `switch`ing on the sealed type, so the radio group
/// has a value type to compare and the choice is made in exactly one place
/// ([_AdvancedFormState._setPacingKind]).
enum _PacingKind { perDay, finishBy }

/// Which review schedule a plan asks for, **or none at all** (#50).
///
/// Off is a value rather than an absence, because "this plan does not ask for a
/// review" is the answer for every plan nobody has touched, and a control that
/// could not express it would show a schedule the plan does not have.
enum _ReviewKind { off, weekday, everyDays, onDate }

/// One optional unit bound.
///
/// **Empty means "not set", and that is a real setting** — the whole sefer, or
/// no end — so the field reports null rather than 0 for a blank, and the parser
/// it uses refuses anything that is not a positive number rather than accepting
/// a zero that would mean "no units at all".
class _UnitField extends StatefulWidget {
  const _UnitField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<_UnitField> createState() => _UnitFieldState();
}

class _UnitFieldState extends State<_UnitField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void didUpdateWidget(covariant _UnitField old) {
    super.didUpdateWidget(old);
    // Rebuilt from the item when the list reorders or another field changes it,
    // so the text has to follow — otherwise the field keeps showing a number
    // the plan no longer holds.
    final next = widget.value?.toString() ?? '';
    if (_controller.text != next) _controller.text = next;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: widget.label,
      isDense: true,
      border: const OutlineInputBorder(),
    ),
    onChanged: (raw) => widget.onChanged(nonNegativeInt(raw)),
  );
}
