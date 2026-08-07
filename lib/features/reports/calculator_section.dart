import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/goals.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../core/calendar.dart';
import '../../core/day.dart';
import '../../core/keypad.dart';
import '../../domain/entities/progress_node.dart';
import '../../domain/usecases/predictor.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';
import '../common/node_picker.dart';

enum _CalcMode { rate, cycle, target }

/// Flexible siyum planning.
///  * Rate   — at X/day (and Y on Shabbos), when do I finish?
///  * Cycle  — a custom repeating cycle of any length (you set each day's amount
///             and which cycle-day is today).
///  * Target — to finish by a date, what flat daily rate do I need?
///
/// The third mode is a goal in every respect except that it could not be kept:
/// it names a node, a target date and the pace that reaches it, which is exactly
/// what `goalStatusProvider` evaluates, and the answer used to evaporate the
/// moment you navigated away. **Save it** is the whole of what was missing, and
/// it only became possible to offer once Goals stopped being a different route.
class CalculatorSection extends ConsumerStatefulWidget {
  const CalculatorSection({super.key});

  @override
  ConsumerState<CalculatorSection> createState() => _CalculatorSectionState();
}

class _CalculatorSectionState extends ConsumerState<CalculatorSection>
    with AutomaticKeepAliveClientMixin {
  String? _nodeId;
  _CalcMode _mode = _CalcMode.rate;

  final _dailyCtrl = TextEditingController(text: '1');
  final _shabbosCtrl = TextEditingController();
  final _cycleCtrl = TextEditingController(text: '5, 5, 5, 5, 5, 0, 10');
  final _cycleStartCtrl = TextEditingController(text: '1');

  /// A year out, as the opening guess for "finish by". Counted in calendar
  /// days, not 8,760 hours — the `Duration` form drifts an hour across a DST
  /// boundary and, started late enough in the evening, names the day before.
  late DateTime _target;

  /// A `TabBarView` disposes the page you tabbed away from, and four
  /// controllers' worth of typing is not something to lose because you glanced
  /// at Siyumim. This is the one section here that holds state a user entered.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Through the clock, like everything else that asks what day it is: the
    // tests override it, and a screen that reads the wall clock directly is a
    // screen no test can place in time.
    _target = (Day.of(ref.read(clockProvider)()) + 365).midnight;
  }

  @override
  void dispose() {
    _dailyCtrl.dispose();
    _shabbosCtrl.dispose();
    _cycleCtrl.dispose();
    _cycleStartCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final mode = ref.watch(settingsProvider.select((s) => s.calendar));
    final now = ref.watch(clockProvider)();
    final l10n = AppLocalizations.of(context);

    if (catalog == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Every node worth targeting: roots, their categories, and individual
    // leaves (a single mesechta/sefer) so a siyum can be computed for one
    // thing, not only for whole categories. Four levels is where a tree of
    // sefarim stops being a list of destinations and starts being a list of
    // dapim.
    final choices = nodeChoices(l10n, catalog, maxDepth: 3);
    if (choices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // The *subtree*, not the whole forest. This used to watch
    // `progressForestProvider` and walk all 312 nodes into a parallel list on
    // every build, to read `remaining` and `total` off one of them — so a mark
    // anywhere in the catalog rebuilt this tab. `progressNodeProvider` is a map
    // lookup with value equality on the other side of it, so it notifies only
    // when the thing being counted down actually moved.
    final selectedId = choices.any((c) => c.id == _nodeId)
        ? _nodeId!
        : choices.first.id;
    final selected = ref.watch(progressNodeProvider(selectedId));
    if (selected == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _body(context, l10n, choices, selectedId, selected, mode, now);
  }

  Widget _body(
      BuildContext context,
      AppLocalizations l10n,
      List<NodeChoice> choices,
      String selectedId,
      ProgressNode selected,
      CalendarMode mode,
      DateTime now) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NodeDropdown(
          label: l10n.calculatorWhatFinishing,
          choices: choices,
          value: selectedId,
          onChanged: (v) => setState(() => _nodeId = v),
        ),
        const SizedBox(height: 8),
        Text(l10n.calculatorRemaining(selected.remaining, selected.total),
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        SegmentedButton<_CalcMode>(
          segments: [
            ButtonSegment(
                value: _CalcMode.rate, label: Text(l10n.calculatorModeRate)),
            ButtonSegment(
                value: _CalcMode.cycle, label: Text(l10n.calculatorModeCycle)),
            ButtonSegment(
                value: _CalcMode.target, label: Text(l10n.calculatorModeByDate)),
          ],
          selected: {_mode},
          // The tick beside the selected segment costs about 24dp, and on a
          // 240dp screen that is the difference between "Rate" and a column of
          // letters reading R-a-t-e. The segment is already filled to show
          // which one is chosen, so the tick was saying it twice.
          showSelectedIcon: !isCompact(context),
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 16),
        ..._inputs(context, l10n, mode, now),
        const SizedBox(height: 24),
        _Result(text: _compute(l10n, selected, mode, now)),
        if (_mode == _CalcMode.target) ...[
          const SizedBox(height: 12),
          _SaveAsGoal(node: selected, target: _target),
        ],
      ],
    );
  }

  List<Widget> _inputs(BuildContext context, AppLocalizations l10n,
      CalendarMode mode, DateTime now) {
    switch (_mode) {
      case _CalcMode.rate:
        return [
          TextField(
            controller: _dailyCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.calculatorAmountPerDay),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _shabbosCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.calculatorAmountShabbos),
            onChanged: (_) => setState(() {}),
          ),
        ];
      case _CalcMode.cycle:
        return [
          TextField(
            controller: _cycleCtrl,
            decoration: InputDecoration(
              labelText: l10n.calculatorCycleAmounts,
              helperText: l10n.calculatorCycleAmountsHelper,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cycleStartCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.calculatorCycleDay,
              helperText: l10n.calculatorCycleDayHelper,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ];
      case _CalcMode.target:
        return [
          Row(
            children: [
              Expanded(
                  child: Text(
                      l10n.calculatorTarget(DateDisplay.format(_target, mode)))),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _target,
                    firstDate: now,
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _target = picked);
                },
                child: Text(l10n.calculatorPickDate),
              ),
            ],
          ),
        ];
    }
  }

  String _compute(AppLocalizations l10n, ProgressNode selected,
      CalendarMode mode, DateTime now) {
    final remaining = selected.remaining;
    if (remaining <= 0) return l10n.calculatorAlreadyFinished;
    final today = Day.of(now);

    switch (_mode) {
      case _CalcMode.rate:
        final daily = double.tryParse(_dailyCtrl.text.trim()) ?? 0;
        if (daily <= 0) return l10n.calculatorEnterDailyAmount;
        final shabbos = double.tryParse(_shabbosCtrl.text.trim());
        final date = shabbos == null
            ? Predictor.finishDateWithCycle(
                remaining: remaining,
                amounts: [daily],
                startIndex: 0,
                from: today)
            : Predictor.finishDateWithShabbos(
                remaining: remaining,
                weekdayAmount: daily,
                shabbosAmount: shabbos,
                from: today);
        return _finishText(l10n, date, mode, today);

      case _CalcMode.cycle:
        final amounts = _cycleCtrl.text
            .split(',')
            .map((s) => double.tryParse(s.trim()) ?? 0)
            .toList();
        if (amounts.isEmpty) return l10n.calculatorEnterAmounts;
        final startDay = int.tryParse(_cycleStartCtrl.text.trim()) ?? 1;
        final date = Predictor.finishDateWithCycle(
          remaining: remaining,
          amounts: amounts,
          startIndex: startDay - 1,
          from: today,
        );
        if (date == null) return l10n.calculatorCycleNeverFinishes;
        return _finishText(l10n, date, mode, today) +
            l10n.calculatorCycleLength(amounts.length);

      case _CalcMode.target:
        final rate = Predictor.requiredPerDay(
            remaining: remaining, from: today, target: Day.of(_target));
        if (rate == double.infinity) return l10n.calculatorPickFutureDate;
        // The same rendering the goal line uses — which matters here more than
        // anywhere, because *Save as goal* is right underneath: the number this
        // sentence shows and the number that goal then reports are the same
        // arithmetic, and were two spellings of it.
        return l10n.calculatorRequiredRate(
            requiredPerDayText(rate), DateDisplay.format(_target, mode));
    }
  }

  String _finishText(
      AppLocalizations l10n, Day? date, CalendarMode mode, Day today) {
    if (date == null) return l10n.calculatorNeverFinish;
    return l10n.calculatorFinishOn(
        DateDisplay.format(date.midnight, mode), date.difference(today));
  }
}

/// Keeps what the "By date" mode just worked out, as a goal on the node it was
/// worked out for.
///
/// Disabled rather than hidden when a goal for this node already exists: the
/// button is the answer to "can I keep this", and a control that vanishes when
/// the answer is *you already did* is a control that reads as broken.
class _SaveAsGoal extends ConsumerWidget {
  const _SaveAsGoal({required this.node, required this.target});

  final ProgressNode node;
  final DateTime target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final existing = ref.watch(goalsProvider)[node.id];
    final already = existing != null && Day.of(existing) == Day.of(target);
    return Align(
      child: FilledButton.icon(
        icon: const Icon(Icons.flag_outlined, size: 18),
        label: Text(already ? l10n.calculatorGoalSaved : l10n.calculatorSaveGoal),
        onPressed: already ? null : () => _save(context, ref),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final goals = ref.read(goalsProvider.notifier);
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final name = nodeName(l10n, node.node);
    await guard.run(
      () => goals.setGoal(node.id, target),
      what: l10n.whatSettingGoal(name),
      success: l10n.calculatorGoalSetFor(name),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
