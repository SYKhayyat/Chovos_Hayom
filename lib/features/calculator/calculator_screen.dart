import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../core/calendar.dart';
import '../../domain/entities/progress_node.dart';
import '../../domain/usecases/predictor.dart';

/// The reborn "Calculate": bidirectional siyum planning.
///  * Forward  — at X/day (and Y on Shabbos), when do I finish?
///  * Backward — to finish by a date, what daily rate do I need?
class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  String? _nodeId;
  bool _forward = true;
  final _dailyCtrl = TextEditingController(text: '1');
  final _shabbosCtrl = TextEditingController();
  DateTime _target = DateTime.now().add(const Duration(days: 365));

  @override
  void dispose() {
    _dailyCtrl.dispose();
    _shabbosCtrl.dispose();
    super.dispose();
  }

  /// Flatten root + top categories + sedarim (depth <= 2) for the picker.
  List<ProgressNode> _selectable(List<ProgressNode> forest) {
    final out = <ProgressNode>[];
    void walk(ProgressNode n, int depth) {
      out.add(n);
      if (depth < 2) {
        for (final c in n.children) {
          if (!c.node.isLeaf) walk(c, depth + 1);
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
    final mode = ref.watch(settingsProvider).calendar;
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(title: const Text('Siyum Calculator')),
      body: forest == null
          ? const Center(child: CircularProgressIndicator())
          : _body(context, _selectable(forest), mode, now),
    );
  }

  Widget _body(BuildContext context, List<ProgressNode> nodes, CalendarMode mode,
      DateTime now) {
    final selected =
        nodes.firstWhere((n) => n.id == _nodeId, orElse: () => nodes.first);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: selected.id,
          decoration: const InputDecoration(labelText: 'What are you finishing?'),
          items: [
            for (final n in nodes)
              DropdownMenuItem(value: n.id, child: Text(n.name)),
          ],
          onChanged: (v) => setState(() => _nodeId = v),
        ),
        const SizedBox(height: 8),
        Text('${selected.remaining} of ${selected.total} left',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Rate → date')),
            ButtonSegment(value: false, label: Text('Date → rate')),
          ],
          selected: {_forward},
          onSelectionChanged: (s) => setState(() => _forward = s.first),
        ),
        const SizedBox(height: 16),
        if (_forward) ..._forwardInputs() else _backwardInputs(context, mode),
        const SizedBox(height: 24),
        _Result(text: _compute(selected, mode, now)),
      ],
    );
  }

  List<Widget> _forwardInputs() => [
        TextField(
          controller: _dailyCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount per day'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _shabbosCtrl,
          keyboardType: TextInputType.number,
          decoration:
              const InputDecoration(labelText: 'Amount on Shabbos (optional)'),
          onChanged: (_) => setState(() {}),
        ),
      ];

  Widget _backwardInputs(BuildContext context, CalendarMode mode) {
    return Row(
      children: [
        Expanded(child: Text('Target: ${DateDisplay.format(_target, mode)}')),
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
          child: const Text('Pick date'),
        ),
      ],
    );
  }

  String _compute(ProgressNode selected, CalendarMode mode, DateTime now) {
    final remaining = selected.remaining;
    if (remaining <= 0) return 'Already finished! 🎉';

    if (_forward) {
      final daily = double.tryParse(_dailyCtrl.text.trim()) ?? 0;
      if (daily <= 0) return 'Enter a daily amount above 0.';
      final shabbos = double.tryParse(_shabbosCtrl.text.trim());
      final date = shabbos == null
          ? Predictor.finishDate(remaining: remaining, perDay: daily, from: now)
          : Predictor.finishDateWithShabbos(
              remaining: remaining,
              weekdayAmount: daily,
              shabbosAmount: shabbos,
              from: now);
      if (date == null) return 'At that rate you never finish.';
      final days = date.difference(DateTime(now.year, now.month, now.day)).inDays;
      return 'You will finish on ${DateDisplay.format(date, mode)}\n'
          '(about $days days from today).';
    } else {
      final rate = Predictor.requiredPerDay(remaining: remaining, from: now, target: _target);
      if (rate == double.infinity) return 'Pick a date in the future.';
      return 'Learn ${rate.toStringAsFixed(2)} per day to finish by\n'
          '${DateDisplay.format(_target, mode)}.';
    }
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
