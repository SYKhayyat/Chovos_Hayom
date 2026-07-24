import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/bulk_marker.dart';
import '../../application/providers.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/layer.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';

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
    final l10n = AppLocalizations.of(context);
    final name = nodeName(l10n, node);
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
                  Text(l10n.bulkTitle, style: theme.textTheme.titleLarge),
                  Text(
                    node.isLeaf
                        ? name
                        : l10n.bulkAllUnitsUnderneath(name),
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.done_all),
              title: Text(l10n.bulkFinishAll),
              subtitle: Text(l10n.bulkFinishAllSubtitle),
              onTap: () => _run(
                l10n,
                title: l10n.bulkFinishAllTitle(name),
                what: l10n.bulkWhatFinishingAll(name),
                report: l10n.bulkReportFinished,
                confirmLabel: l10n.actionFinish,
                plan: (m) => m.planFinish(
                    nodeId: node.id, selection: const RequiredLayerSelection()),
              ),
            ),
            for (final layer in perLayer)
              _layerTile(context, l10n, layer, name),
            if (node.isLeaf)
              ListTile(
                leading: const Icon(Icons.linear_scale),
                title: Text(l10n.bulkFinishRange),
                subtitle: Text(l10n.bulkFinishRangeSubtitle),
                onTap: () => _finishRange(l10n, name),
              ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete_sweep_outlined,
                  color: theme.colorScheme.error),
              title: Text(l10n.bulkClearAll,
                  style: TextStyle(color: theme.colorScheme.error)),
              subtitle: Text(l10n.bulkClearAllSubtitle),
              onTap: () => _clearAll(l10n, name),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// One `Mark all — <meforish>` row. Extracted so the layer's localized name is
  /// resolved once and shared by the row, its confirmation and its report.
  Widget _layerTile(BuildContext context, AppLocalizations l10n, Layer layer,
      String nodeDisplayName) {
    final label = layerName(l10n, layer);
    return ListTile(
      leading: const Icon(Icons.layers_outlined),
      title: Text(l10n.bulkMarkAllLayer(label)),
      subtitle: layer.id == mainLayerId
          ? Text(l10n.bulkMainTextSubtitle)
          : null,
      onTap: () => _run(
        l10n,
        title: l10n.bulkMarkLayerTitle(label, nodeDisplayName),
        what: l10n.bulkWhatMarkingLayer(label, nodeDisplayName),
        report: (units) => l10n.bulkReportMarkedLayer(units, label),
        confirmLabel: l10n.actionMark,
        plan: (m) => m.planFinish(
            nodeId: node.id, selection: SingleLayerSelection(layer.id)),
      ),
    );
  }

  // All async work reads the provider *container* (captured from the host, which
  // outlives the sheet), never the sheet's own ref — the sheet is popped first.
  ProviderContainer get _container => ProviderScope.containerOf(host);

  /// The same guard every other write in the app uses, built from the host
  /// rather than from a `WidgetRef` — this sheet is gone by the time it writes.
  WriteGuard _guard(ProviderContainer container) => WriteGuard(
        ScaffoldMessenger.of(host),
        Navigator.of(host, rootNavigator: true),
        container.read(crashLogProvider),
        AppLocalizations.of(host),
      );

  /// Closes the sheet, plans the action, confirms it with the real unit count,
  /// then commits and reports with undo. [destructive] colours the confirm
  /// button as a warning (clearing) rather than a normal action (marking).
  Future<void> _run(
    AppLocalizations l10n, {
    required String title,
    required String what,

    /// Builds the "Finished 64 units" sentence from the real count.
    ///
    /// This used to be a `verb` string that the reporter glued a count and the
    /// word "unit(s)" onto. That shape only produces a sentence in a language
    /// whose verb comes first and whose plural is an "s", so each action now
    /// supplies its whole message and the plural rules live in the ARB.
    required String Function(int units) report,
    required String confirmLabel,
    required BulkPlan Function(BulkMarker) plan,
    String? extraWarning,
    bool destructive = false,
  }) async {
    final container = _container;
    final guard = _guard(container);
    if (Navigator.canPop(host)) Navigator.pop(host);
    final marker = container.read(bulkMarkerProvider);
    if (marker == null) return;

    final planned = plan(marker);
    if (planned.isEmpty) {
      guard.report(l10n.bulkNothingToChange);
      return;
    }
    final ok = await _confirm(
      l10n,
      title: title,
      units: planned.unitsAffected,
      confirmLabel: confirmLabel,
      extraWarning: extraWarning,
      destructive: destructive,
    );
    if (ok != true) return;
    // A bulk write is the largest thing the app does; it is also the one whose
    // failure a user would most easily miss, because the sheet is already gone
    // and the tree redraws either way.
    BulkResult? result;
    final committed = await guard.run(
      () async => result = await marker.commit(planned),
      what: what,
    );
    final done = result;
    if (committed && done != null) _report(l10n, container, guard, report, done);
  }

  /// The one gate every bulk write goes through. Always states the exact number
  /// of units, because that number is the whole point — "finish all" on Shas and
  /// on one mesechta look identical until you see 12,092 versus 64.
  Future<bool?> _confirm(
    AppLocalizations l10n, {
    required String title,
    required int units,
    required String confirmLabel,
    String? extraWarning,
    bool destructive = false,
  }) {
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
              Text(l10n.bulkConfirmUnits(units),
                  style: Theme.of(dialogContext).textTheme.titleMedium),
              if (extraWarning != null) ...[
                const SizedBox(height: 8),
                Text(extraWarning),
              ],
              const SizedBox(height: 8),
              Text(l10n.bulkUndoNote),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.actionCancel)),
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

  Future<void> _finishRange(AppLocalizations l10n, String name) async {
    final first = node.unitOffset;
    final last = node.unitOffset + node.unitCount - 1;
    final range = await showDialog<UnitRange>(
      context: host,
      builder: (_) => _RangeDialog(first: first, last: last),
    );
    if (range == null) return;
    await _run(
      l10n,
      title: l10n.bulkRangeTitle(range.start, range.end, name),
      what: l10n.bulkWhatFinishingRange(range.start, range.end, name),
      report: (units) =>
          l10n.bulkReportFinishedRange(units, range.start, range.end),
      confirmLabel: l10n.actionFinish,
      plan: (m) => m.planFinish(
        nodeId: node.id,
        selection: const RequiredLayerSelection(),
        range: range,
      ),
    );
  }

  Future<void> _clearAll(AppLocalizations l10n, String name) => _run(
        l10n,
        title: l10n.bulkClearAllTitle(name),
        what: l10n.bulkWhatClearingAll(name),
        report: l10n.bulkReportCleared,
        confirmLabel: l10n.actionClear,
        destructive: true,
        extraWarning: node.isLeaf
            ? l10n.bulkClearWarningLeaf
            : l10n.bulkClearWarningCategory,
        plan: (m) =>
            m.planClear(nodeId: node.id, selection: const AllLayersSelection()),
      );

  void _report(AppLocalizations l10n, ProviderContainer container,
      WriteGuard guard, String Function(int) report, BulkResult result) {
    if (result.isEmpty) {
      guard.report(l10n.bulkNothingToChange);
      return;
    }
    final batchId = result.batchId;
    guard.report(
      report(result.unitsAffected),
      action: batchId == null
          ? null
          // Undo by batch, not by the ids held in this closure — the same call
          // the history screen makes, so the two paths can't disagree.
          : SnackBarAction(
              label: l10n.actionUndo,
              onPressed: () => guard.run(
                () => container
                    .read(progressRepositoryProvider)
                    .removeBatch(container.read(activeProfileProvider), batchId),
                what: l10n.whatUndoingBulk,
              ),
            ),
    );
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
    final l10n = AppLocalizations.of(context);
    final start = int.tryParse(_startCtrl.text.trim());
    final end = int.tryParse(_endCtrl.text.trim());
    if (start == null || end == null) {
      setState(() => _error = l10n.rangeErrorTwoNumbers);
      return;
    }
    final lo = start <= end ? start : end;
    final hi = start <= end ? end : start;
    if (lo < widget.first || hi > widget.last) {
      setState(
          () => _error = l10n.rangeErrorBounds(widget.first, widget.last));
      return;
    }
    Navigator.pop(context, UnitRange(lo, hi));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.rangeDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.rangeDialogBody(widget.first, widget.last)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.rangeFrom),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.rangeTo),
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
            child: Text(l10n.actionCancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.actionFinish)),
      ],
    );
  }
}
