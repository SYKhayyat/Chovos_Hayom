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
/// - **Clear all** — un-mark everything.
///
/// **Every** action is planned first and confirmed with the real number of units
/// it would change — a "finish all" on a category can be twelve thousand writes,
/// and a mis-tap that large must never be one tap away. Each action commits as
/// one batch and stays undoable from *Bulk action history* long after the
/// snackbar is gone. Works with mouse + keyboard; no touchscreen assumed.
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
                title: 'Finish all of “${node.name}”?',
                verb: 'Finished',
                confirmLabel: 'Finish',
                plan: (m) => m.planFinish(
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
                  title: 'Mark ${layer.name} on all of “${node.name}”?',
                  verb: 'Marked ${layer.name} on',
                  confirmLabel: 'Mark',
                  plan: (m) => m.planFinish(
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

  /// Closes the sheet, plans the action, confirms it with the real unit count,
  /// then commits and reports with undo. [destructive] colours the confirm
  /// button as a warning (clearing) rather than a normal action (marking).
  Future<void> _run({
    required String title,
    required String verb,
    required String confirmLabel,
    required BulkPlan Function(BulkMarker) plan,
    String? extraWarning,
    bool destructive = false,
  }) async {
    final container = _container;
    final messenger = ScaffoldMessenger.of(host);
    if (Navigator.canPop(host)) Navigator.pop(host);
    final marker = container.read(bulkMarkerProvider);
    if (marker == null) return;

    final planned = plan(marker);
    if (planned.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Nothing to change')));
      return;
    }
    final ok = await _confirm(
      title: title,
      units: planned.unitsAffected,
      confirmLabel: confirmLabel,
      extraWarning: extraWarning,
      destructive: destructive,
    );
    if (ok != true) return;
    _report(container, messenger, verb, await marker.commit(planned));
  }

  /// The one gate every bulk write goes through. Always states the exact number
  /// of units, because that number is the whole point — "finish all" on Shas and
  /// on one mesechta look identical until you see 12,092 versus 64.
  Future<bool?> _confirm({
    required String title,
    required int units,
    required String confirmLabel,
    String? extraWarning,
    bool destructive = false,
  }) {
    final noun = units == 1 ? 'unit' : 'units';
    return showDialog<bool>(
      context: host,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This changes ${_thousands(units)} $noun.',
                  style: Theme.of(dialogContext).textTheme.titleMedium),
              if (extraWarning != null) ...[
                const SizedBox(height: 8),
                Text(extraWarning),
              ],
              const SizedBox(height: 8),
              const Text('You can undo it from Settings → Bulk action history '
                  'for as long as you like.'),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError)
                  : null,
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
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
      title: 'Finish units ${range.start}–${range.end} of “${node.name}”?',
      verb: 'Finished units ${range.start}–${range.end} of',
      confirmLabel: 'Finish',
      plan: (m) => m.planFinish(
        nodeId: node.id,
        selection: const RequiredLayerSelection(),
        range: range,
      ),
    );
  }

  Future<void> _clearAll() => _run(
        title: 'Clear all of “${node.name}”?',
        verb: 'Cleared',
        confirmLabel: 'Clear',
        destructive: true,
        extraWarning: node.isLeaf
            ? 'Un-marks every unit here, including any mefarshim you checked off.'
            : 'Un-marks every unit under this — including all its mefarshim.',
        plan: (m) =>
            m.planClear(nodeId: node.id, selection: const AllLayersSelection()),
      );

  void _report(ProviderContainer container, ScaffoldMessengerState messenger,
      String verb, BulkResult result) {
    if (result.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Nothing to change')));
      return;
    }
    final batchId = result.batchId;
    messenger.showSnackBar(SnackBar(
      content: Text('$verb ${_thousands(result.unitsAffected)} '
          '${result.unitsAffected == 1 ? 'unit' : 'units'}'),
      action: batchId == null
          ? null
          // Undo by batch, not by the ids held in this closure — the same call
          // the history screen makes, so the two paths can't disagree.
          : SnackBarAction(
              label: 'Undo',
              onPressed: () => container
                  .read(progressRepositoryProvider)
                  .removeBatch(container.read(activeProfileProvider), batchId),
            ),
    ));
  }
}

/// Thousands separators — the difference between "12092" and "12,092" is the
/// difference between a number you skim and one you actually read.
String _thousands(int n) {
  final digits = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
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
