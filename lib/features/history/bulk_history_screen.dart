import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/usecases/batch_history.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';

/// The durable undo list for bulk actions.
///
/// A "finish all" on a category can write twelve thousand events; a snackbar
/// that lives four seconds is not a real undo for that. This screen derives
/// every batch still present in the log and lets the user revert any of them,
/// today or next month. Nothing here is stored — the list is a fold over the
/// same event log everything else derives from.
class BulkHistoryScreen extends ConsumerWidget {
  const BulkHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(batchHistoryProvider);
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final mode = ref.watch(settingsProvider).calendar;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bulkHistoryTitle)),
      body: batches.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.bulkHistoryEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              itemCount: batches.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _BatchTile(
                batch: batches[i],
                catalog: catalog,
                calendar: mode,
              ),
            ),
    );
  }
}

class _BatchTile extends ConsumerWidget {
  const _BatchTile({
    required this.batch,
    required this.catalog,
    required this.calendar,
  });

  final BulkBatch batch;
  final Catalog? catalog;
  final CalendarMode calendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final units = batch.unitsAffected;
    final where = _where(l10n);
    return ListTile(
      leading: Icon(
        batch.isFinish ? Icons.done_all : Icons.delete_sweep_outlined,
        color: batch.isFinish ? scheme.primary : scheme.error,
      ),
      title: Text(batch.isFinish
          ? l10n.bulkHistoryFinishedEntry(units, where)
          : l10n.bulkHistoryClearedEntry(units, where)),
      subtitle: Text(DateDisplay.formatWithTime(batch.appliedAt, calendar)),
      trailing: TextButton.icon(
        icon: const Icon(Icons.undo, size: 18),
        label: Text(l10n.actionUndo),
        onPressed: () => _undo(context, ref),
      ),
    );
  }

  /// A human name for what the batch touched: the leaf itself when it was one,
  /// otherwise the deepest node that contains all of them ("Seder Moed") — which
  /// is what the user actually pressed the button on.
  String _where(AppLocalizations l10n) {
    final c = catalog;
    if (c == null) return l10n.bulkHistorySefarimCount(batch.nodeIds.length);
    if (batch.nodeIds.length == 1) {
      final node = c.byId(batch.nodeIds.first);
      return node == null ? batch.nodeIds.first : nodeName(l10n, node);
    }
    final common = _commonAncestor(c, batch.nodeIds);
    if (common == null) {
      return l10n.bulkHistorySefarimCount(batch.nodeIds.length);
    }
    final node = c.byId(common);
    return l10n.bulkHistoryWhereWithCount(
        node == null ? common : nodeName(l10n, node), batch.nodeIds.length);
  }

  /// Deepest id that is an ancestor-or-self of every node in [ids]. Walks each
  /// node's ancestor chain once and keeps the longest shared prefix.
  static String? _commonAncestor(Catalog catalog, List<String> ids) {
    List<String> chainOf(String id) {
      final chain = <String>[];
      var current = catalog.byId(id);
      while (current != null) {
        chain.insert(0, current.id);
        final parent = current.parentId;
        current = parent == null ? null : catalog.byId(parent);
      }
      return chain;
    }

    var shared = chainOf(ids.first);
    for (final id in ids.skip(1)) {
      final chain = chainOf(id);
      var i = 0;
      while (i < shared.length && i < chain.length && shared[i] == chain[i]) {
        i++;
      }
      shared = shared.sublist(0, i);
      if (shared.isEmpty) return null;
    }
    return shared.isEmpty ? null : shared.last;
  }

  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    final guard = WriteGuard.of(context, ref);
    final repo = ref.read(progressRepositoryProvider);
    final profileId = ref.read(activeProfileProvider);
    final l10n = AppLocalizations.of(context);
    final units = batch.unitsAffected;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.bulkHistoryUndoTitle),
        content: Text(
          batch.isFinish
              ? l10n.bulkHistoryUndoFinishBody(units)
              : l10n.bulkHistoryUndoClearBody(units),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.actionCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.actionUndo)),
        ],
      ),
    );
    if (confirmed != true) return;
    var removed = 0;
    final ok = await guard.run(
      () async => removed = await repo.removeBatch(profileId, batch.id),
      what: l10n.whatUndoingThisBulk,
    );
    if (!ok) return;
    guard.report(l10n.bulkHistoryUndone(removed));
  }
}
