import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/cycles.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/usecases/learning_cycle.dart';

/// Build a learning cycle: pick the sefarim, in order, set the pace and the day
/// it started.
///
/// This is what makes "learning cycles" plural. Mishna Yomi, Rambam Yomi, Amud
/// Yomi, a yeshiva's seder, a personal chazara programme — all of them are this
/// screen, rather than something the app either ships or doesn't.
class EditCycleScreen extends ConsumerStatefulWidget {
  const EditCycleScreen({super.key, this.existing});

  final SequentialCycle? existing;

  @override
  ConsumerState<EditCycleScreen> createState() => _EditCycleScreenState();
}

class _EditCycleScreenState extends ConsumerState<EditCycleScreen> {
  late final TextEditingController _name;
  late final TextEditingController _perDay;
  late DateTime _startDate;
  late bool _repeats;
  late List<CycleSegment> _segments;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _perDay = TextEditingController(text: (e?.unitsPerDay ?? 1).toString());
    _startDate = e?.startDate ?? DateTime.now();
    _repeats = e?.repeats ?? true;
    _segments = [...?e?.segments];
  }

  @override
  void dispose() {
    _name.dispose();
    _perDay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final mode = ref.watch(settingsProvider).calendar;
    var total = 0;
    for (final s in _segments) {
      total += s.unitCount;
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit cycle' : 'New cycle')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Mishna Yomi, Rambam Yomi, my chazara seder',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _perDay,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Units per day',
              helperText: 'Mishna Yomi is 2; a daf a day is 1.',
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Started on'),
            subtitle: Text(DateDisplay.format(_startDate, mode)),
            trailing: const Icon(Icons.edit),
            onTap: _pickStart,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Starts over when it finishes'),
            subtitle: const Text('Off = a one-time programme'),
            value: _repeats,
            onChanged: (v) => setState(() => _repeats = v),
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text('Sefarim, in order',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text('$total units', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          if (_segments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Add the sefarim this cycle walks through.'),
            ),
          // Reorderable so the order — which *is* the cycle — can be corrected
          // by dragging, and with mouse-friendly up/down as well.
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // onReorderItem, not onReorder: it already accounts for the removed
            // item, so no index fix-up is needed.
            onReorderItem: (from, to) => setState(
                () => _segments.insert(to, _segments.removeAt(from))),
            children: [
              for (var i = 0; i < _segments.length; i++)
                _segmentTile(catalog, i),
            ],
          ),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add a sefer'),
            onPressed: catalog == null ? null : () => _addSegment(catalog.all),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text(_isEdit ? 'Save cycle' : 'Create cycle'),
          ),
        ],
      ),
    );
  }

  Widget _segmentTile(dynamic catalog, int i) {
    final segment = _segments[i];
    final node = ref.read(catalogNodeProvider(segment.nodeId));
    return ListTile(
      key: ValueKey('${segment.nodeId}#$i'),
      contentPadding: EdgeInsets.zero,
      leading: ReorderableDragStartListener(
          index: i, child: const Icon(Icons.drag_handle)),
      title: Text(node?.name ?? segment.nodeId),
      subtitle: Text('${segment.unitCount} units from ${segment.unitOffset}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            tooltip: 'Move up',
            onPressed: i == 0
                ? null
                : () => setState(() =>
                    _segments.insert(i - 1, _segments.removeAt(i))),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 18),
            tooltip: 'Move down',
            onPressed: i == _segments.length - 1
                ? null
                : () => setState(() =>
                    _segments.insert(i + 1, _segments.removeAt(i))),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove',
            onPressed: () => setState(() => _segments.removeAt(i)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  /// Adds a leaf, or every leaf under a category — so "all of Shas, in order"
  /// is one action rather than thirty-seven.
  Future<void> _addSegment(Iterable<CatalogNode> all) async {
    final catalog = ref.read(mergedCatalogProvider).asData?.value;
    if (catalog == null) return;
    final choices = all.toList()..sort((a, b) => a.name.compareTo(b.name));

    final chosen = await showDialog<CatalogNode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Add a sefer or category'),
        children: [
          SizedBox(
            width: 340,
            height: 420,
            child: ListView.builder(
              itemCount: choices.length,
              itemBuilder: (_, i) {
                final n = choices[i];
                return ListTile(
                  leading: Icon(n.isLeaf ? Icons.menu_book : Icons.folder),
                  title: Text(n.name),
                  subtitle: Text(n.isLeaf
                      ? '${n.unitCount} ${n.unitLabel?.name ?? 'unit'}s'
                      : 'everything underneath'),
                  onTap: () => Navigator.pop(dialogContext, n),
                );
              },
            ),
          ),
        ],
      ),
    );
    if (chosen == null) return;

    setState(() {
      for (final leaf in catalog.leavesUnder(chosen.id)) {
        if (leaf.unitCount <= 0) continue;
        _segments.add(CycleSegment(
          nodeId: leaf.id,
          unitCount: leaf.unitCount,
          unitOffset: leaf.unitOffset,
        ));
      }
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Give the cycle a name.')));
      return;
    }
    final perDay = int.tryParse(_perDay.text.trim()) ?? 0;
    if (perDay <= 0) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Units per day must be at least 1.')));
      return;
    }
    if (_segments.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Add at least one sefer for the cycle to walk.')));
      return;
    }

    await ref.read(cyclesConfigProvider.notifier).save(SequentialCycle(
          id: widget.existing?.id ?? const Uuid().v4(),
          name: name,
          startDate: _startDate,
          unitsPerDay: perDay,
          repeats: _repeats,
          segments: _segments,
        ));
    if (mounted) Navigator.of(context).pop();
  }
}
