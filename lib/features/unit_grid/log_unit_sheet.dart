import 'package:flutter/material.dart';

/// Result of the logging sheet. [occurredAt] is null when the user did not set a
/// date manually, so the caller auto-fills "now" (ARCHITECTURE.md §2.2).
class LogUnitResult {
  const LogUnitResult({this.occurredAt, this.durationMin, this.note});
  final DateTime? occurredAt;
  final int? durationMin;
  final String? note;
}

/// A modal sheet for logging a unit with an optional manual date, duration, and
/// note. Returns null if cancelled.
Future<LogUnitResult?> showLogUnitSheet(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<LogUnitResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LogUnitSheet(title: title),
  );
}

class _LogUnitSheet extends StatefulWidget {
  const _LogUnitSheet({required this.title});
  final String title;

  @override
  State<_LogUnitSheet> createState() => _LogUnitSheetState();
}

class _LogUnitSheetState extends State<_LogUnitSheet> {
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Set date manually'),
            subtitle: Text(_manualDate
                ? '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'
                : 'Defaults to now'),
            value: _manualDate,
            onChanged: (v) => setState(() => _manualDate = v),
          ),
          if (_manualDate)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text('Pick date'),
                onPressed: _pickDate,
              ),
            ),
          TextField(
            controller: _durationCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Duration (minutes, optional)',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
            maxLines: 2,
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
              FilledButton(onPressed: _save, child: const Text('Mark learned')),
            ],
          ),
        ],
      ),
    );
  }
}
