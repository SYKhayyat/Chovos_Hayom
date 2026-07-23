import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/bulk_marker.dart';
import '../../application/providers.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/layer.dart';

/// Bulk finish/clear for a whole node — one leaf, or a category cascading to
/// every descendant leaf. Offers:
///
/// - **Finish all** — each unit's required mefarshim.
/// - **Mark all — `<meforish>`** — one specific layer across every unit (only
///   the layers offered/required at this node are listed).
/// - **Finish a range…** — a user-chosen `[start, end]` of units (leaf only).
/// - **Clear all** — un-mark everything (confirmed; destructive).
///
/// Every action is one batched transaction and returns undo-able event ids, so a
/// snackbar can revert it. Works with mouse + keyboard; no touchscreen assumed.
Future<void> showBulkActionsSheet(
  BuildContext context,
  WidgetRef ref, {
  required CatalogNode node,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _BulkActionsSheet(node: node, host: context),
  );
}

class _BulkActionsSheet extends ConsumerWidget {
  const _BulkActionsSheet({required this.node, required this.host});

  final CatalogNode node;

  /// The context that opened the sheet — used for snackbars/dialogs that must
  /// outlive the sheet itself.
  final BuildContext host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allLayers = ref.watch(allLayersProvider);
    final offered = ref.watch(offeredLayersProvider);
    final required = ref.watch(layerRequirementsProvider);

    // The layers worth offering as a per-meforish bulk action at this node.
    final nodeCheckable = {
      ...offered.forNode(node.id),
      ...required.forNode(node.id),
    };
    final perLayer = [
      for (final l in allLayers)
        if (nodeCheckable.contains(l.id)) l,
    ];

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bulk actions', style: theme.textTheme.titleLarge),
                  Text(
                    node.isLeaf
                        ? node.name
                        : '${node.name} · all units underneath',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.done_all),
              title: const Text('Finish all'),
              subtitle: const Text('Mark every unit’s required mefarshim done'),
              onTap: () => _run(
                verb: 'Finished',
                action: (m) => m.finish(
                    nodeId: node.id, selection: const RequiredLayerSelection()),
              ),
            ),
            for (final layer in perLayer)
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: Text('Mark all — ${layer.name}'),
                subtitle: layer.id == mainLayerId
                    ? const Text('The primary text on every unit')
                    : null,
                onTap: () => _run(
                  verb: 'Marked ${layer.name} on',
                  action: (m) => m.finish(
                      nodeId: node.id,
                      selection: SingleLayerSelection(layer.id)),
                ),
              ),
            if (node.isLeaf)
              ListTile(
                leading: const Icon(Icons.linear_scale),
                title: const Text('Finish a range…'),
                subtitle: const Text('Choose a start and end unit'),
                onTap: _finishRange,
              ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete_sweep_outlined,
                  color: theme.colorScheme.error),
              title: Text('Clear all',
                  style: TextStyle(color: theme.colorScheme.error)),
              subtitle: const Text('Un-mark every unit (and its mefarshim)'),
              onTap: _clearAll,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // All async work reads the provider *container* (captured from the host, which
  // outlives the sheet), never the sheet's own ref — the sheet is popped first.
  ProviderContainer get _container => ProviderScope.containerOf(host);

  /// Runs a bulk [action]: closes the sheet, then applies + reports with undo.
  Future<void> _run({
    required String verb,
    required Future<BulkResult> Function(BulkMarker) action,
  }) async {
    final container = _container;
    final messenger = ScaffoldMessenger.of(host);
    if (Navigator.canPop(host)) Navigator.pop(host);
    final marker = container.read(bulkMarkerProvider);
    if (marker == null) return;
    _report(container, messenger, verb, await action(marker));
  }

  Future<void> _finishRange() async {
    final first = node.unitOffset;
    final last = node.unitOffset + node.unitCount - 1;
    final range = await showDialog<UnitRange>(
      context: host,
      builder: (_) => _RangeDialog(first: first, last: last),
    );
    if (range == null) return;
    await _run(
      verb: 'Finished units ${range.start}–${range.end} of',
      action: (m) => m.finish(
        nodeId: node.id,
        selection: const RequiredLayerSelection(),
        range: range,
      ),
    );
  }

  Future<void> _clearAll() async {
    final container = _container;
    final messenger = ScaffoldMessenger.of(host);
    if (Navigator.canPop(host)) Navigator.pop(host); // close the sheet first
    final confirmed = await showDialog<bool>(
      context: host,
      builder: (dialogContext) => AlertDialog(
        title: Text('Clear all of “${node.name}”?'),
        content: Text(node.isLeaf
            ? 'Un-marks every unit here, including any mefarshim you checked off.'
            : 'Un-marks every unit under this — including all its mefarshim. '
                'This can be a lot.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final marker = container.read(bulkMarkerProvider);
    if (marker == null) return;
    _report(container, messenger, 'Cleared',
        await marker.clear(nodeId: node.id, selection: const AllLayersSelection()));
  }

  void _report(ProviderContainer container, ScaffoldMessengerState messenger,
      String verb, BulkResult result) {
    if (result.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Nothing to change')));
      return;
    }
    messenger.showSnackBar(SnackBar(
      content: Text('$verb ${result.unitsAffected} '
          '${result.unitsAffected == 1 ? 'unit' : 'units'}'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => container
            .read(progressRepositoryProvider)
            .removeEvents(result.addedEventIds),
      ),
    ));
  }
}

/// Two-field start/end picker for a unit range, defaulting to the full leaf.
class _RangeDialog extends StatefulWidget {
  const _RangeDialog({required this.first, required this.last});
  final int first;
  final int last;

  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  late final TextEditingController _startCtrl =
      TextEditingController(text: '${widget.first}');
  late final TextEditingController _endCtrl =
      TextEditingController(text: '${widget.last}');
  String? _error;

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final start = int.tryParse(_startCtrl.text.trim());
    final end = int.tryParse(_endCtrl.text.trim());
    if (start == null || end == null) {
      setState(() => _error = 'Enter two numbers.');
      return;
    }
    final lo = start <= end ? start : end;
    final hi = start <= end ? end : start;
    if (lo < widget.first || hi > widget.last) {
      setState(() =>
          _error = 'Units run from ${widget.first} to ${widget.last}.');
      return;
    }
    Navigator.pop(context, UnitRange(lo, hi));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Finish a range'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Units ${widget.first}–${widget.last}. Both ends included.'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'From'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'To'),
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Finish')),
      ],
    );
  }
}
