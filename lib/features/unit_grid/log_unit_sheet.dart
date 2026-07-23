import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/session_timer.dart';
import '../../application/stats.dart';
import '../../domain/entities/layer.dart';

/// Result of the logging sheet. [occurredAt] is null when the user did not set a
/// date/time manually, so the caller auto-fills "now" (ARCHITECTURE.md §2.2).
class LogUnitResult {
  const LogUnitResult({
    this.occurredAt,
    this.durationMin,
    this.note,
    this.layers = const [mainLayerId],
  });

  final DateTime? occurredAt;
  final int? durationMin;

  /// The haara — one free-text field, whatever the user wanted to record.
  /// Surfaced in the Notes Journal.
  final String? note;

  /// Which layers this log marks. Defaults to the primary text; on a layered
  /// unit the sheet offers the checkable set so one action records "I learned
  /// Rashi on this daf for 40 minutes, and here's my chiddush".
  final List<String> layers;
}

/// A modal sheet for logging a unit — or editing an already-logged one — with an
/// optional manual date **and time**, the shared session timer, a duration, a
/// free-text haara, and (on a layered unit) which mefarshim it covers. Returns
/// null if cancelled.
///
/// Pass [initialOccurredAt]/[initialDurationMin]/[initialNote] to pre-fill the
/// fields (edit mode); [saveLabel] labels the confirm button. Pass
/// [layerOptions] to offer a meforish checklist, with [initialLayers] selected.
/// [nodeId]/[unitIndex] tie the session timer to what is being learned.
Future<LogUnitResult?> showLogUnitSheet(
  BuildContext context, {
  required String title,
  DateTime? initialOccurredAt,
  int? initialDurationMin,
  String? initialNote,
  String saveLabel = 'Mark learned',
  List<Layer> layerOptions = const [],
  Set<String> initialLayers = const {mainLayerId},
  String? nodeId,
  int? unitIndex,
}) {
  return showModalBottomSheet<LogUnitResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LogUnitSheet(
      title: title,
      initialOccurredAt: initialOccurredAt,
      initialDurationMin: initialDurationMin,
      initialNote: initialNote,
      saveLabel: saveLabel,
      layerOptions: layerOptions,
      initialLayers: initialLayers,
      nodeId: nodeId,
      unitIndex: unitIndex,
    ),
  );
}

class _LogUnitSheet extends ConsumerStatefulWidget {
  const _LogUnitSheet({
    required this.title,
    required this.saveLabel,
    required this.layerOptions,
    required this.initialLayers,
    this.initialOccurredAt,
    this.initialDurationMin,
    this.initialNote,
    this.nodeId,
    this.unitIndex,
  });

  final String title;
  final String saveLabel;
  final DateTime? initialOccurredAt;
  final int? initialDurationMin;
  final String? initialNote;
  final List<Layer> layerOptions;
  final Set<String> initialLayers;
  final String? nodeId;
  final int? unitIndex;

  @override
  ConsumerState<_LogUnitSheet> createState() => _LogUnitSheetState();
}

class _LogUnitSheetState extends ConsumerState<_LogUnitSheet> {
  late bool _manualDate;
  late DateTime _date; // date + time of "finished learning"
  late final TextEditingController _durationCtrl;
  late final TextEditingController _noteCtrl;
  late final Set<String> _selectedLayers;

  /// Redraws the elapsed readout once a second. Display only — the elapsed time
  /// itself lives in [sessionTimerProvider] and is derived from wall-clock
  /// instants, so nothing is lost if this widget goes away.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Editing an existing event (has an occurredAt) starts in manual mode with
    // its stored date/time; a fresh log defaults to "now" and manual off.
    _manualDate = widget.initialOccurredAt != null;
    _date = widget.initialOccurredAt ?? DateTime.now();
    _durationCtrl = TextEditingController(
        text: widget.initialDurationMin?.toString() ?? '');
    _noteCtrl = TextEditingController(text: widget.initialNote ?? '');
    _selectedLayers = {...widget.initialLayers};
    if (_selectedLayers.isEmpty) _selectedLayers.add(mainLayerId);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _durationCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  DateTime get _now => ref.read(clockProvider)();

  Future<void> _toggleTimer() async {
    final timer = ref.read(sessionTimerProvider.notifier);
    await timer.toggle(_now,
        label: widget.title, nodeId: widget.nodeId, unitIndex: widget.unitIndex);
    // Pausing offers the time it measured as the duration, without overwriting
    // a number the user typed themselves.
    final session = ref.read(sessionTimerProvider);
    if (!session.isRunning) {
      final minutes = session.minutesAt(_now);
      if (minutes > 0) _durationCtrl.text = '$minutes';
    }
  }

  static String _clock(Duration d) {
    final s = d.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  String get _dateTimeLabel {
    final d = _date;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$date · $time';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date =
          DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
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

  Future<void> _save() async {
    final duration = int.tryParse(_durationCtrl.text.trim());
    final note = _noteCtrl.text.trim();
    // The session ends when it is recorded; leaving it running would let it
    // bleed into whatever is logged next.
    if (ref.read(sessionTimerProvider).isActive) {
      await ref.read(sessionTimerProvider.notifier).reset();
    }
    if (!mounted) return;
    Navigator.of(context).pop(LogUnitResult(
      occurredAt: _manualDate ? _date : null,
      durationMin: duration,
      note: note.isEmpty ? null : note,
      layers: _selectedLayers.toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final session = ref.watch(sessionTimerProvider);
    final elapsed = session.elapsedAt(_now);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (widget.layerOptions.isNotEmpty) ...[
              Text('What you learned:',
                  style: Theme.of(context).textTheme.labelLarge),
              for (final layer in widget.layerOptions)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _selectedLayers.contains(layer.id),
                  title: Text(layer.name),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selectedLayers.add(layer.id);
                    } else {
                      _selectedLayers.remove(layer.id);
                    }
                  }),
                ),
              const Divider(),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set date & time manually'),
              subtitle: Text(_manualDate ? _dateTimeLabel : 'Defaults to now'),
              value: _manualDate,
              onChanged: (v) => setState(() => _manualDate = v),
            ),
            if (_manualDate)
              Wrap(
                spacing: 8,
                children: [
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
                ],
              ),
            Row(
              children: [
                Text('Timer  ${_clock(elapsed)}',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (session.isActive && !session.isRunning)
                  TextButton(
                    onPressed: () =>
                        ref.read(sessionTimerProvider.notifier).reset(),
                    child: const Text('Reset'),
                  ),
                FilledButton.tonalIcon(
                  icon: Icon(session.isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(session.isRunning ? 'Stop' : 'Start'),
                  onPressed: _toggleTimer,
                ),
              ],
            ),
            if (session.isRunning)
              Text(
                'Keeps running if you close this — go learn.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            TextField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'How long it took (minutes, optional)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Haara (optional)',
                hintText: 'A chiddush, a question, a maareh makom, how it went…',
                helperText: 'Collected in your Notes Journal.',
              ),
              maxLines: 5,
              minLines: 1,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _selectedLayers.isEmpty ? null : _save,
                  child: Text(widget.saveLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
