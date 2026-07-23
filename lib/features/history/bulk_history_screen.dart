import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/usecases/batch_history.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Bulk action history')),
      body: batches.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No bulk actions yet.\n\n'
                  'Anything you finish or clear in bulk shows up here, and stays '
                  'undoable until you undo it.',
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
    final units = batch.unitsAffected;
    return ListTile(
      leading: Icon(
        batch.isFinish ? Icons.done_all : Icons.delete_sweep_outlined,
        color: batch.isFinish ? scheme.primary : scheme.error,
      ),
      title: Text('${batch.isFinish ? 'Finished' : 'Cleared'} $units '
          '${units == 1 ? 'unit' : 'units'} · ${_where()}'),
      subtitle: Text(DateDisplay.formatWithTime(batch.appliedAt, calendar)),
      trailing: TextButton.icon(
        icon: const Icon(Icons.undo, size: 18),
        label: const Text('Undo'),
        onPressed: () => _undo(context, ref),
      ),
    );
  }

  /// A human name for what the batch touched: the leaf itself when it was one,
  /// otherwise the deepest node that contains all of them ("Seder Moed") — which
  /// is what the user actually pressed the button on.
  String _where() {
    final c = catalog;
    if (c == null) return '${batch.nodeIds.length} sefarim';
    if (batch.nodeIds.length == 1) {
      return c.byId(batch.nodeIds.first)?.name ?? batch.nodeIds.first;
    }
    final common = _commonAncestor(c, batch.nodeIds);
    return common == null
        ? '${batch.nodeIds.length} sefarim'
        : '${c.byId(common)?.name ?? common} '
            '(${batch.nodeIds.length} sefarim)';
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
    final messenger = ScaffoldMessenger.of(context);
    final units = batch.unitsAffected;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Undo this bulk action?'),
        content: Text(
          batch.isFinish
              ? 'Removes the $units ${units == 1 ? 'mark' : 'marks'} this action '
                  'made. Anything you had learned before it is untouched.'
              : 'Restores the $units ${units == 1 ? 'unit' : 'units'} this action '
                  'cleared.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Undo')),
        ],
      ),
    );
    if (confirmed != true) return;
    final removed = await ref
        .read(progressRepositoryProvider)
        .removeBatch(ref.read(activeProfileProvider), batch.id);
    messenger.showSnackBar(
        SnackBar(content: Text('Undone — $removed ${removed == 1 ? 'event' : 'events'} removed')));
  }
}
