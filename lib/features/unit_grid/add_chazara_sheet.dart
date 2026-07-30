import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/layer.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';

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
    // The nav-bar inset — see [showLogUnitSheet], which had the identical defect
    // for the identical reason. Measured on a phone, "Log chazara" landed its
    // confirm button on exactly the same dead y-range.
    builder: (_) => SafeArea(
      child: _AddChazaraSheet(node: node, unit: unit),
    ),
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

  @override
  void dispose() {
    _durationCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fold = ref.watch(foldProvider).asData?.value;
    final required = ref.watch(layerRequirementsProvider);
    final allLayers = ref.watch(allLayersProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

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

    String nameOf(String id) => layerName(
        l10n,
        allLayers.firstWhere((l) => l.id == id,
            orElse: () => Layer(id: id, name: l10n.deletedMeforish)));

    // The keyboard only; the nav bar is the `SafeArea` in [showAddChazaraSheet].
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.addChazaraTitle, style: theme.textTheme.titleLarge),
            Text(nodeAndUnit(l10n, widget.node, widget.unit),
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(l10n.addChazaraReviewed, style: theme.textTheme.labelLarge),
            for (final id in candidates)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _selected.contains(id),
                title: Text(nameOf(id)),
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
              title: Text(l10n.logSheetManualDateTime),
              subtitle: Text(
                  _manualDate ? _dateTimeLabel : l10n.logSheetDefaultsToNow),
              value: _manualDate,
              onChanged: (v) => setState(() => _manualDate = v),
            ),
            if (_manualDate)
              Wrap(spacing: 8, children: [
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(l10n.logSheetPickDate),
                  onPressed: _pickDate,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(l10n.logSheetPickTime),
                  onPressed: _pickTime,
                ),
              ]),
            TextField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: l10n.addChazaraDuration),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: l10n.logSheetHaara,
                helperText: l10n.logSheetHaaraHelper,
              ),
              maxLines: 4,
              minLines: 1,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.actionCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _selected.isEmpty ? null : _save,
                  child: Text(l10n.addChazaraSubmit),
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

  /// Closes the sheet, then writes. The guard already holds the messenger, so a
  /// chazara that fails to save still says so — it used to be fired off unawaited
  /// as the sheet disappeared, which meant a failure left no trace anywhere.
  Future<void> _save() async {
    final duration = int.tryParse(_durationCtrl.text.trim());
    final note = _noteCtrl.text.trim();
    final logger = ref.read(loggingServiceProvider);
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final heading = nodeAndUnit(l10n, widget.node, widget.unit);
    Navigator.pop(context);
    await guard.run(
      () => logger.markReview(
        widget.node.id,
        widget.unit,
        occurredAt: _manualDate ? _date : null,
        durationMin: duration,
        note: note.isEmpty ? null : note,
        layers: _selected.toList(),
      ),
      what: l10n.whatLoggingChazara(heading),
    );
  }
}
