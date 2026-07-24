import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/cycles.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/usecases/learning_cycle.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/missing_item.dart';
import '../common/naming.dart';

/// Build a learning cycle: pick the sefarim, in order, set the pace and the day
/// it started.
///
/// This is what makes "learning cycles" plural. Mishna Yomi, Rambam Yomi, Amud
/// Yomi, a yeshiva's seder, a personal chazara programme — all of them are this
/// screen, rather than something the app either ships or doesn't.
///
/// [cycleId] rather than the cycle itself, so `/cycles/<id>` is a route and the
/// screen reads the cycle as it is now, not as it was when it was opened.
class EditCycleScreen extends ConsumerWidget {
  const EditCycleScreen({super.key, this.cycleId});

  final String? cycleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cycleId == null) return const _CycleForm();

    final matches =
        ref.watch(cyclesConfigProvider).custom.where((c) => c.id == cycleId);
    if (matches.isEmpty) {
      return MissingItemScreen(
        loading: false,
        message: AppLocalizations.of(context).cycleMissing,
      );
    }
    return _CycleForm(key: ValueKey(cycleId), existing: matches.first);
  }
}

class _CycleForm extends ConsumerStatefulWidget {
  const _CycleForm({super.key, this.existing});

  final SequentialCycle? existing;

  @override
  ConsumerState<_CycleForm> createState() => _CycleFormState();
}

class _CycleFormState extends ConsumerState<_CycleForm> {
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
    final l10n = AppLocalizations.of(context);
    var total = 0;
    for (final s in _segments) {
      total += s.unitCount;
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? l10n.editCycleTitle : l10n.newCycleTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.labelName,
              hintText: l10n.editCycleNameHint,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _perDay,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.editCycleUnitsPerDay,
              helperText: l10n.editCycleUnitsPerDayHelper,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(l10n.editCycleStartedOn),
            subtitle: Text(DateDisplay.format(_startDate, mode)),
            trailing: const Icon(Icons.edit),
            onTap: _pickStart,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.editCycleRepeats),
            subtitle: Text(l10n.editCycleRepeatsSubtitle),
            value: _repeats,
            onChanged: (v) => setState(() => _repeats = v),
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(l10n.editCycleSefarimInOrder,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text(l10n.editCycleTotalUnits(total),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          if (_segments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l10n.editCycleEmpty),
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
              for (var i = 0; i < _segments.length; i++) _segmentTile(i),
            ],
          ),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l10n.editCycleAddSefer),
            onPressed: catalog == null ? null : () => _addSegment(catalog.all),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text(_isEdit
                ? l10n.editCycleSaveExisting
                : l10n.editCycleCreate),
          ),
        ],
      ),
    );
  }

  Widget _segmentTile(int i) {
    final l10n = AppLocalizations.of(context);
    final segment = _segments[i];
    final node = ref.read(catalogNodeProvider(segment.nodeId));
    return ListTile(
      key: ValueKey('${segment.nodeId}#$i'),
      contentPadding: EdgeInsets.zero,
      leading: ReorderableDragStartListener(
          index: i, child: const Icon(Icons.drag_handle)),
      title: Text(node == null ? segment.nodeId : nodeName(l10n, node)),
      subtitle: Text(l10n.editCycleSegmentSubtitle(
          segment.unitCount, segment.unitOffset)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            tooltip: l10n.tooltipMoveUp,
            onPressed: i == 0
                ? null
                : () => setState(() =>
                    _segments.insert(i - 1, _segments.removeAt(i))),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 18),
            tooltip: l10n.tooltipMoveDown,
            onPressed: i == _segments.length - 1
                ? null
                : () => setState(() =>
                    _segments.insert(i + 1, _segments.removeAt(i))),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: l10n.tooltipRemove,
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
    final l10n = AppLocalizations.of(context);
    final choices = all.toList()
      ..sort((a, b) => nodeName(l10n, a).compareTo(nodeName(l10n, b)));

    final chosen = await showDialog<CatalogNode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.editCycleAddDialogTitle),
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
                  title: Text(nodeName(l10n, n)),
                  subtitle: Text(n.isLeaf
                      ? unitCount(l10n, n.unitCount, n.unitLabel)
                      : l10n.editCycleEverythingUnderneath),
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
    final navigator = Navigator.of(context);
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      guard.report(l10n.editCycleNeedName);
      return;
    }
    final perDay = int.tryParse(_perDay.text.trim()) ?? 0;
    if (perDay <= 0) {
      guard.report(l10n.editCycleNeedPerDay);
      return;
    }
    if (_segments.isEmpty) {
      guard.report(l10n.editCycleNeedSegment);
      return;
    }

    final cycles = ref.read(cyclesConfigProvider.notifier);
    final saved = await guard.run(
      () => cycles.save(SequentialCycle(
        id: widget.existing?.id ?? const Uuid().v4(),
        name: name,
        startDate: _startDate,
        unitsPerDay: perDay,
        repeats: _repeats,
        segments: _segments,
      )),
      what: l10n.whatSavingCycle(name),
    );
    if (saved) navigator.pop();
  }
}
