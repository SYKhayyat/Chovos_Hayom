import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../core/calendar.dart';
import '../../core/keypad.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/progress_node.dart';
import '../../domain/usecases/predictor.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/naming.dart';

enum _CalcMode { rate, cycle, target }

/// The reborn "Calculate": flexible siyum planning.
///  * Rate   — at X/day (and Y on Shabbos), when do I finish?
///  * Cycle  — a custom repeating cycle of any length (you set each day's amount
///             and which cycle-day is today).
///  * Target — to finish by a date, what flat daily rate do I need?
class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  String? _nodeId;
  _CalcMode _mode = _CalcMode.rate;

  final _dailyCtrl = TextEditingController(text: '1');
  final _shabbosCtrl = TextEditingController();
  final _cycleCtrl = TextEditingController(text: '5, 5, 5, 5, 5, 0, 10');
  final _cycleStartCtrl = TextEditingController(text: '1');
  DateTime _target = DateTime.now().add(const Duration(days: 365));

  @override
  void dispose() {
    _dailyCtrl.dispose();
    _shabbosCtrl.dispose();
    _cycleCtrl.dispose();
    _cycleStartCtrl.dispose();
    super.dispose();
  }

  /// Every node worth targeting: roots, their categories, and individual leaves
  /// (a single mesechta/sefer) so you can compute a siyum for one thing, not
  /// only whole categories. Labels are indented by depth for readability.
  List<_Selectable> _selectable(List<ProgressNode> forest) {
    final out = <_Selectable>[];
    void walk(ProgressNode n, int depth) {
      out.add(_Selectable(n, depth));
      if (depth < 3) {
        for (final c in n.children) {
          walk(c, depth + 1);
        }
      }
    }

    for (final r in forest) {
      walk(r, 0);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final forest = ref.watch(progressForestProvider).asData?.value;
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final mode = ref.watch(settingsProvider).calendar;
    final now = ref.watch(clockProvider)();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calculatorTitle)),
      body: forest == null || catalog == null
          ? const Center(child: CircularProgressIndicator())
          : _body(context, l10n, catalog, _selectable(forest), mode, now),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n, Catalog catalog,
      List<_Selectable> nodes, CalendarMode mode, DateTime now) {
    final selectedEntry = nodes.firstWhere((s) => s.node.id == _nodeId,
        orElse: () => nodes.first);
    final selected = selectedEntry.node;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: selected.id,
          isExpanded: true,
          decoration:
              InputDecoration(labelText: l10n.calculatorWhatFinishing),
          items: [
            for (final s in nodes)
              DropdownMenuItem(
                value: s.node.id,
                // Qualified, because a closed dropdown shows one line with no
                // indentation and no neighbours: "Shabbos" alone could be the
                // Bavli, the Yerushalmi, the Mishnayos or the Rambam. The
                // indentation still carries the tree while the list is open.
                child: Text(
                    '${'   ' * s.depth}'
                    '${qualifiedNodeName(l10n, catalog, s.node.node)}',
                    overflow: TextOverflow.ellipsis),
              ),
          ],
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
                value: _CalcMode.target,
                label: Text(l10n.calculatorModeByDate)),
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
        ..._inputs(context, l10n, mode),
        const SizedBox(height: 24),
        _Result(text: _compute(l10n, selected, mode, now)),
      ],
    );
  }

  List<Widget> _inputs(
      BuildContext context, AppLocalizations l10n, CalendarMode mode) {
    switch (_mode) {
      case _CalcMode.rate:
        return [
          TextField(
            controller: _dailyCtrl,
            keyboardType: TextInputType.number,
            decoration:
                InputDecoration(labelText: l10n.calculatorAmountPerDay),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _shabbosCtrl,
            keyboardType: TextInputType.number,
            decoration:
                InputDecoration(labelText: l10n.calculatorAmountShabbos),
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
                  child: Text(l10n.calculatorTarget(
                      DateDisplay.format(_target, mode)))),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _target,
                    firstDate: DateTime.now(),
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
    final today = DateTime(now.year, now.month, now.day);

    switch (_mode) {
      case _CalcMode.rate:
        final daily = double.tryParse(_dailyCtrl.text.trim()) ?? 0;
        if (daily <= 0) return l10n.calculatorEnterDailyAmount;
        final shabbos = double.tryParse(_shabbosCtrl.text.trim());
        final date = shabbos == null
            ? Predictor.finishDateWithCycle(
                remaining: remaining, amounts: [daily], startIndex: 0, from: now)
            : Predictor.finishDateWithShabbos(
                remaining: remaining,
                weekdayAmount: daily,
                shabbosAmount: shabbos,
                from: now);
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
          from: now,
        );
        if (date == null) return l10n.calculatorCycleNeverFinishes;
        return _finishText(l10n, date, mode, today) +
            l10n.calculatorCycleLength(amounts.length);

      case _CalcMode.target:
        final rate = Predictor.requiredPerDay(
            remaining: remaining, from: now, target: _target);
        if (rate == double.infinity) return l10n.calculatorPickFutureDate;
        return l10n.calculatorRequiredRate(
            rate.toStringAsFixed(2), DateDisplay.format(_target, mode));
    }
  }

  String _finishText(AppLocalizations l10n, DateTime? date, CalendarMode mode,
      DateTime today) {
    if (date == null) return l10n.calculatorNeverFinish;
    final days = date.difference(today).inDays;
    return l10n.calculatorFinishOn(DateDisplay.format(date, mode), days);
  }
}

/// A catalog node plus its tree depth, for indented dropdown display.
class _Selectable {
  const _Selectable(this.node, this.depth);
  final ProgressNode node;
  final int depth;
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
