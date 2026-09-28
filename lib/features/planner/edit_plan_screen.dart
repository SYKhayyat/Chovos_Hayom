import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/plans.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../core/parse.dart';
import '../../domain/usecases/learning_plan.dart';
import '../../domain/usecases/recurrence.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/confirm.dart';
import '../common/guarded.dart';

/// How a plan's firing rule is chosen here. The domain has [OrRule] and
/// [AndRule] too, and they are deliberately not offered: combining rules is
/// expressible as an `OrRule` of the ones below, and a first-class UI for
/// arbitrary boolean trees of recurrence rules is not something this needs to
/// guess at.
enum _RuleKind { daily, weekdays, dayOfMonth, hebrewDay }

/// Creates or edits one plan. One screen for both, so the back button and the
/// field order are identical whether the plan exists or not.
class EditPlanScreen extends ConsumerWidget {
  const EditPlanScreen({super.key, this.planId});

  /// Empty means a new plan.
  final String? planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(plansConfigProvider);
    final existing = planId == null
        ? null
        : config.plans.where((p) => p.id == planId).firstOrNull;

    return _PlanForm(
      key: ValueKey(planId ?? 'new'),
      existing: existing,
    );
  }
}

class _PlanForm extends ConsumerStatefulWidget {
  const _PlanForm({super.key, required this.existing});

  final LearningPlan? existing;

  @override
  ConsumerState<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends ConsumerState<_PlanForm> {
  late final TextEditingController _name;
  late final TextEditingController _unitsPerDay;
  late final TextEditingController _perFiring;
  late _RuleKind _kind;
  late Set<int> _weekdays;
  late Set<int> _daysOfMonth;
  late int _hebrewDay;
  int? _hebrewMonth;
  late SpilloverMode _spillover;
  late bool _flows;

  /// The one place a bad number is reported. Not a per-field error because there
  /// is one rule: no amount is not a valid plan.
  String? _error;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _unitsPerDay = TextEditingController(text: '${p?.unitsPerDay ?? 1}');
    final rule = p?.assignments.isEmpty ?? true ? null : p!.assignments.first;
    _perFiring = TextEditingController(text: '${rule?.unitsPerFiring ?? 1}');
    _spillover = p?.spillover ?? SpilloverMode.ignore;
    _flows = p?.flowsToNextItem ?? false;

    final r = rule?.rule;
    if (r is WeekdayRule) {
      _kind = _RuleKind.weekdays;
      _weekdays = {...r.weekdays};
    } else if (r is DayOfMonthRule) {
      _kind = _RuleKind.dayOfMonth;
      _daysOfMonth = {...r.days};
    } else if (r is HebrewDayRule) {
      _kind = _RuleKind.hebrewDay;
      _hebrewDay = r.day;
      _hebrewMonth = r.month;
    } else {
      _kind = _RuleKind.daily;
      _weekdays = {DateTime.monday};
      _daysOfMonth = {1};
      _hebrewDay = 1;
      _hebrewMonth = null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _unitsPerDay.dispose();
    _perFiring.dispose();
    super.dispose();
  }

  /// Parses a whole-number field, refusing anything else.
  ///
  /// `int.tryParse` alone is not enough: it accepts `-3`, and a negative amount
  /// is refused by the domain (#24) — so catching it here turns a thrown
  /// FormatException on save into a message beside the field, which is the
  /// difference between "validation is visible" and "the app throws".
  int? _amount(TextEditingController c) => nonNegativeInt(c.text);

  RecurrenceRule? _buildRule() => switch (_kind) {
        _RuleKind.daily => const DailyRule(),
        _RuleKind.weekdays =>
          _weekdays.isEmpty ? null : WeekdayRule(weekdays: _weekdays),
        _RuleKind.dayOfMonth =>
          _daysOfMonth.isEmpty ? null : DayOfMonthRule(days: _daysOfMonth),
        _RuleKind.hebrewDay => HebrewDayRule(day: _hebrewDay, month: _hebrewMonth),
      };

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final perDay = _amount(_unitsPerDay);
    final perFiring = _amount(_perFiring);
    final rule = _buildRule();
    if (perDay == null || perFiring == null || rule == null) {
      setState(() => _error = l10n.plansAmountInvalid);
      return;
    }
    setState(() => _error = null);

    final name = _name.text.trim();
    final existing = widget.existing;
    final plan = LearningPlan(
      id: existing?.id ?? 'plan-${DateTime.now().microsecondsSinceEpoch}',
      // An unnamed plan is still a plan; showing the amount beats showing
      // nothing, and the name field is right there to fill in.
      name: name.isEmpty ? '${l10n.plansNewTitle} ${l10n.plansTitle}' : name,
      // Everything the plan already knows is carried across, not rebuilt from
      // this form: the overrides and the item sequence (#35) are not edited here
      // and a save must not silently drop them.
      assignments: [
        PlanAssignment(
          id: existing?.assignments.isEmpty ?? true
              ? 'a'
              : existing!.assignments.first.id,
          rule: rule,
          targetNodeId: existing?.assignments.isEmpty ?? true
              ? null
              : existing!.assignments.first.targetNodeId,
          unitsPerFiring: perFiring,
          label: existing?.assignments.isEmpty ?? true
              ? null
              : existing!.assignments.first.label,
        ),
      ],
      overrides: existing?.overrides ?? const [],
      displayCalendar: existing?.displayCalendar ?? RuleCalendar.gregorian,
      unitsPerDay: perDay,
      weekdayAmounts: existing?.weekdayAmounts ?? const {},
      dateAmounts: existing?.dateAmounts ?? const {},
      spillover: _spillover,
      items: existing?.items ?? const [],
      flowsToNextItem: _flows,
    );

    final navigator = Navigator.of(context);
    await guarded(
      context,
      ref,
      () => ref.read(plansConfigProvider.notifier).save(plan),
      what: l10n.plansSaved,
    );
    navigator.pop();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final existing = widget.existing;
    if (existing == null) return;
    final navigator = Navigator.of(context);
    final ok = await confirmYesNo(
      context,
      message: l10n.plansDeleteConfirm(existing.name),
      confirmLabel: l10n.plansDeleteConfirmAction,
      cancelLabel: l10n.plansCancel,
      destructive: true,
    );
    if (!ok) return;
    if (!mounted) return;
    await guarded(
      context,
      ref,
      () => ref.read(plansConfigProvider.notifier).remove(existing.id),
      what: l10n.plansDeleted,
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(settingsProvider.select((s) => s.calendar));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.plansNewTitle : l10n.plansEditTitle),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: l10n.plansDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.plansName,
              hintText: l10n.plansNameHint,
            ),
          ),
          const SizedBox(height: 12),
          _AmountField(
            controller: _unitsPerDay,
            label: l10n.plansUnitsPerDay,
            helper: l10n.plansUnitsPerDayHelp,
            onChanged: () => setState(() => _error = null),
          ),
          const SizedBox(height: 12),
          _AmountField(
            controller: _perFiring,
            label: l10n.plansPerFiring,
            onChanged: () => setState(() => _error = null),
          ),
          const Divider(height: 32),
          Text(l10n.plansWhen,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _ruleKindPicker(l10n),
          const SizedBox(height: 8),
          _ruleInputs(l10n, mode),
          const Divider(height: 32),
          Text(l10n.plansSpillover,
              style: Theme.of(context).textTheme.titleMedium),
          RadioGroup<SpilloverMode>(
            groupValue: _spillover,
            onChanged: (v) => setState(() => _spillover = v ?? _spillover),
            child: Column(
              children: [
                for (final mode in SpilloverMode.values)
                  RadioListTile<SpilloverMode>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: mode,
                    title: Text(_spilloverLabel(l10n, mode)),
                    subtitle: Text(_spilloverHelp(l10n, mode)),
                  ),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _flows,
            onChanged: (v) => setState(() => _flows = v),
            title: Text(l10n.plansFlowToNext),
            subtitle: Text(l10n.plansFlowToNextHelp),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: Text(_isNew ? l10n.plansCreate : l10n.plansSave),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _ruleKindPicker(AppLocalizations l10n) => RadioGroup<_RuleKind>(
        groupValue: _kind,
        onChanged: (v) => setState(() => _kind = v ?? _kind),
        child: Column(
          children: [
            for (final kind in _RuleKind.values)
              RadioListTile<_RuleKind>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: kind,
                title: Text(_ruleKindLabel(l10n, kind)),
              ),
          ],
        ),
      );

  Widget _ruleInputs(AppLocalizations l10n, CalendarMode mode) => switch (_kind) {
        _RuleKind.daily => const SizedBox.shrink(),
        _RuleKind.weekdays => _numberToggles(
            l10n, weekdays: _weekdays, onToggle: _toggleWeekday),
        _RuleKind.dayOfMonth => _numberToggles(
            l10n, days: _daysOfMonth, onToggle: _toggleDayOfMonth),
        _RuleKind.hebrewDay => _hebrewDayInputs(l10n),
      };

  void _toggleWeekday(int n) => setState(() {
        if (!_weekdays.remove(n)) _weekdays.add(n);
      });

  void _toggleDayOfMonth(int n) => setState(() {
        if (!_daysOfMonth.remove(n)) _daysOfMonth.add(n);
      });

  /// A row of tappable numbers. A `Wrap` rather than a fixed grid so a 240dp
  /// screen wraps instead of overflowing, and every number is a real `TextButton`
  /// so the D-pad can reach it.
  Widget _numberToggles(
    AppLocalizations l10n, {
    Set<int>? weekdays,
    Set<int>? days,
    required void Function(int) onToggle,
  }) {
    final selected = weekdays ?? days ?? <int>{};
    final values = weekdays != null
        ? List.generate(7, (i) => DateTime.monday + i)
        : List.generate(31, (i) => i + 1);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final v in values)
          Padding(
            padding: const EdgeInsets.all(1),
            child: OutlinedButton(
              onPressed: () => onToggle(v),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(40, 40),
                padding: EdgeInsets.zero,
                backgroundColor:
                    selected.contains(v) ? Theme.of(context).colorScheme.primaryContainer : null,
              ),
              child: Text('$v'),
            ),
          ),
      ],
    );
  }

  Widget _hebrewDayInputs(AppLocalizations l10n) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _hebrewDay,
            decoration: InputDecoration(labelText: l10n.plansHebrewDay),
            items: [
              for (var d = 1; d <= 30; d++)
                DropdownMenuItem(value: d, child: Text('$d')),
            ],
            onChanged: (v) => setState(() => _hebrewDay = v ?? _hebrewDay),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: _hebrewMonth,
            decoration: InputDecoration(labelText: l10n.plansHebrewMonth),
            items: [
              DropdownMenuItem(
                  value: null, child: Text(l10n.plansHebrewEveryMonth)),
              for (final m in _hebrewMonths)
                DropdownMenuItem(value: m.value, child: Text(m.label)),
            ],
            onChanged: (v) => setState(() => _hebrewMonth = v),
          ),
        ],
      );

  static String _ruleKindLabel(AppLocalizations l10n, _RuleKind kind) =>
      switch (kind) {
        _RuleKind.daily => l10n.plansRuleDaily,
        _RuleKind.weekdays => l10n.plansRuleWeekdays,
        _RuleKind.dayOfMonth => l10n.plansRuleDayOfMonth,
        _RuleKind.hebrewDay => l10n.plansRuleHebrewDay,
      };

  static String _spilloverLabel(AppLocalizations l10n, SpilloverMode mode) =>
      switch (mode) {
        SpilloverMode.ignore => l10n.plansSpilloverIgnore,
        SpilloverMode.catchUp => l10n.plansSpilloverCatchUp,
        SpilloverMode.slide => l10n.plansSpilloverSlide,
      };

  static String _spilloverHelp(AppLocalizations l10n, SpilloverMode mode) =>
      switch (mode) {
        SpilloverMode.ignore => l10n.plansSpilloverIgnoreHelp,
        SpilloverMode.catchUp => l10n.plansSpilloverCatchUpHelp,
        SpilloverMode.slide => l10n.plansSpilloverSlideHelp,
      };

  /// The Hebrew months in year order, with the app's own names.
  ///
  /// [HebrewMonth] is a set of integer constants, not an enum, so there is no
  /// `values` to iterate and no `name` to show. Listing them here keeps the
  /// numbering in one place rather than scattering `HebrewMonth.tishrei`-style
  /// literals through the UI.
  static const _hebrewMonths = <({int value, String label})>[
    (value: HebrewMonth.nissan, label: 'Nissan'),
    (value: HebrewMonth.iyar, label: 'Iyar'),
    (value: HebrewMonth.sivan, label: 'Sivan'),
    (value: HebrewMonth.tammuz, label: 'Tammuz'),
    (value: HebrewMonth.av, label: 'Av'),
    (value: HebrewMonth.elul, label: 'Elul'),
    (value: HebrewMonth.tishrei, label: 'Tishrei'),
    (value: HebrewMonth.cheshvan, label: 'Cheshvan'),
    (value: HebrewMonth.kislev, label: 'Kislev'),
    (value: HebrewMonth.teves, label: 'Teves'),
    (value: HebrewMonth.shevat, label: 'Shevat'),
    (value: HebrewMonth.adar, label: 'Adar'),
    (value: HebrewMonth.adarIi, label: 'Adar II'),
  ];
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.label,
    this.helper,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (_) => onChanged?.call(),
        decoration: InputDecoration(labelText: label, helperText: helper),
      );
}
