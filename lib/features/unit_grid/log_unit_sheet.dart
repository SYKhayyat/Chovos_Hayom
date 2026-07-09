import 'dart:async';

import 'package:flutter/material.dart';

/// Result of the logging sheet. [occurredAt] is null when the user did not set a
/// date/time manually, so the caller auto-fills "now" (ARCHITECTURE.md §2.2).
class LogUnitResult {
  const LogUnitResult({this.occurredAt, this.durationMin, this.note});
  final DateTime? occurredAt;
  final int? durationMin;
  final String? note;
}

/// A modal sheet for logging a unit — or editing an already-logged one — with an
/// optional manual date **and time**, a built-in session stopwatch, a duration,
/// and a free-text note. Returns null if cancelled.
///
/// Pass [initialOccurredAt]/[initialDurationMin]/[initialNote] to pre-fill the
/// fields (edit mode); [saveLabel] labels the confirm button.
Future<LogUnitResult?> showLogUnitSheet(
  BuildContext context, {
  required String title,
  DateTime? initialOccurredAt,
  int? initialDurationMin,
  String? initialNote,
  String saveLabel = 'Mark learned',
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
    ),
  );
}

class _LogUnitSheet extends StatefulWidget {
  const _LogUnitSheet({
    required this.title,
    required this.saveLabel,
    this.initialOccurredAt,
    this.initialDurationMin,
    this.initialNote,
  });

  final String title;
  final String saveLabel;
  final DateTime? initialOccurredAt;
  final int? initialDurationMin;
  final String? initialNote;

  @override
  State<_LogUnitSheet> createState() => _LogUnitSheetState();
}

class _LogUnitSheetState extends State<_LogUnitSheet> {
  late bool _manualDate;
  late DateTime _date; // date + time of "finished learning"
  late final TextEditingController _durationCtrl;
  late final TextEditingController _noteCtrl;

  final _stopwatch = Stopwatch();
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
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _durationCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    setState(() {
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
        _ticker?.cancel();
        final minutes = (_stopwatch.elapsed.inSeconds / 60).ceil();
        if (minutes > 0) _durationCtrl.text = '$minutes';
      } else {
        _stopwatch.start();
        _ticker = Timer.periodic(
            const Duration(seconds: 1), (_) => setState(() {}));
      }
    });
  }

  String get _elapsed {
    final s = _stopwatch.elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
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

  void _save() {
    final duration = int.tryParse(_durationCtrl.text.trim());
    final note = _noteCtrl.text.trim();
    Navigator.of(context).pop(LogUnitResult(
      occurredAt: _manualDate ? _date : null,
      durationMin: duration,
      note: note.isEmpty ? null : note,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
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
                Text('Timer  $_elapsed',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                FilledButton.tonalIcon(
                  icon:
                      Icon(_stopwatch.isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(_stopwatch.isRunning ? 'Stop' : 'Start'),
                  onPressed: _toggleTimer,
                ),
              ],
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
                labelText: 'Note (optional)',
                hintText: 'A thought, a question, where you stopped…',
              ),
              maxLines: 3,
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
                FilledButton(onPressed: _save, child: Text(widget.saveLabel)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
