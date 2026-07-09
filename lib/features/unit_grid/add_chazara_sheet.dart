import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/layer.dart';

/// Logs one chazara (review) pass: which mefarshim were reviewed, when, how long,
/// and any notes. Each pass is independent of the main learning and of other
/// passes, so you can review just Tosafos one time and the whole daf the next.
Future<void> showAddChazaraSheet(
  BuildContext context,
  WidgetRef ref, {
  required CatalogNode node,
  required int unit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _AddChazaraSheet(node: node, unit: unit),
  );
}

class _AddChazaraSheet extends ConsumerStatefulWidget {
  const _AddChazaraSheet({required this.node, required this.unit});
  final CatalogNode node;
  final int unit;

  @override
  ConsumerState<_AddChazaraSheet> createState() => _AddChazaraSheetState();
}

class _AddChazaraSheetState extends ConsumerState<_AddChazaraSheet> {
  final _selected = <String>{};
  bool _seeded = false;
  bool _manualDate = false;
  DateTime _date = DateTime.now();
  final _durationCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _haaraCtrl = TextEditingController();

  @override
  void dispose() {
    _durationCtrl.dispose();
    _noteCtrl.dispose();
    _haaraCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fold = ref.watch(foldProvider).asData?.value;
    final required = ref.watch(layerRequirementsProvider);
    final allLayers = ref.watch(allLayersProvider);
    final theme = Theme.of(context);

    final completed = fold?.completedLayers(widget.node.id, widget.unit) ?? const {};
    final requiredSet = required.forUnit(widget.node.id, widget.unit);
    final candidates = <String>[
      for (final l in allLayers)
        if (requiredSet.contains(l.id) || completed.contains(l.id)) l.id,
    ];
    if (candidates.isEmpty) candidates.add(mainLayerId);

    // Default a fresh pass to reviewing everything currently learned.
    if (!_seeded) {
      _selected.addAll(completed.isEmpty ? candidates : completed);
      _seeded = true;
    }

    Layer layerOf(String id) =>
        allLayers.firstWhere((l) => l.id == id, orElse: () => Layer(id: id, name: id));

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add chazara', style: theme.textTheme.titleLarge),
            Text('${widget.node.name} · ${widget.node.unitHeading(widget.unit)}',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text('Reviewed:', style: theme.textTheme.labelLarge),
            for (final id in candidates)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _selected.contains(id),
                title: Text(layerOf(id).name),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(id);
                  } else {
                    _selected.remove(id);
                  }
                }),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set date & time manually'),
              subtitle: Text(_manualDate ? _dateTimeLabel : 'Defaults to now'),
              value: _manualDate,
              onChanged: (v) => setState(() => _manualDate = v),
            ),
            if (_manualDate)
              Wrap(spacing: 8, children: [
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Pick date'),
                  onPressed: _pickDate,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.schedule, size: 18),
                  label: const Text('Pick time'),
                  onPressed: _pickTime,
                ),
              ]),
            TextField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'How long (minutes, optional)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _haaraCtrl,
              decoration: const InputDecoration(
                labelText: 'Haara — insight (optional)',
                helperText: 'Collected in your Notes Journal.',
              ),
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              decoration:
                  const InputDecoration(labelText: 'Learning note (optional)'),
              maxLines: 2,
              minLines: 1,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _selected.isEmpty ? null : _save,
                  child: const Text('Log chazara'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _dateTimeLabel {
    final d = _date;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} · ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = DateTime(
          picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _date.hour, minute: _date.minute),
    );
    if (picked != null) {
      setState(() => _date = DateTime(
          _date.year, _date.month, _date.day, picked.hour, picked.minute));
    }
  }

  void _save() {
    final duration = int.tryParse(_durationCtrl.text.trim());
    final note = _noteCtrl.text.trim();
    final haara = _haaraCtrl.text.trim();
    ref.read(loggingServiceProvider).markReview(
          widget.node.id,
          widget.unit,
          occurredAt: _manualDate ? _date : null,
          durationMin: duration,
          note: note.isEmpty ? null : note,
          haara: haara.isEmpty ? null : haara,
          layers: _selected.toList(),
        );
    Navigator.pop(context);
  }
}
