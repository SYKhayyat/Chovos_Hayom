import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/usecases/unit_history.dart';
import 'log_unit_sheet.dart';

/// A bottom sheet showing everything recorded for one learned unit — when it was
/// finished, how long it took, the note, and its chazara (review) history — with
/// the ability to edit those details, add a review, or un-mark it.
///
/// Reactive: it re-reads the log, so edits/reviews made from here refresh live.
Future<void> showUnitDetailsSheet(
  BuildContext context,
  WidgetRef ref, {
  required CatalogNode node,
  required int unit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _UnitDetailsSheet(node: node, unit: unit),
  );
}

class _UnitDetailsSheet extends ConsumerWidget {
  const _UnitDetailsSheet({required this.node, required this.unit});

  final CatalogNode node;
  final int unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider).asData?.value ?? const [];
    final history = UnitHistoryFinder.forUnit(events, node.id, unit);
    final mode = ref.watch(settingsProvider).calendar;
    final theme = Theme.of(context);
    final label = node.unitLabel?.name ?? 'unit';
    final done = history.done;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${node.name} · $label $unit',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              if (done == null)
                Text('Not learned yet.', style: theme.textTheme.bodyLarge)
              else ...[
                _DetailRow(
                  icon: Icons.event_available,
                  label: 'Finished',
                  value: DateDisplay.formatWithTime(done.occurredAt, mode),
                ),
                _DetailRow(
                  icon: Icons.timer_outlined,
                  label: 'Time to learn',
                  value: done.durationMin != null
                      ? _fmtMinutes(done.durationMin!)
                      : 'Not recorded',
                ),
                _DetailRow(
                  icon: Icons.refresh,
                  label: 'Chazara passes',
                  value:
                      history.reviewCount == 0 ? 'None yet' : '${history.reviewCount}',
                ),
                if (history.reviews.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 2, bottom: 4),
                    child: Text(
                      history.reviews
                          .map((r) => DateDisplay.format(r.occurredAt, mode))
                          .join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                _DetailRow(
                  icon: Icons.notes,
                  label: 'Note',
                  value: (done.note == null || done.note!.isEmpty)
                      ? 'No note'
                      : done.note!,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit details'),
                      onPressed: () => _edit(context, ref, history),
                    ),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Add chazara'),
                      onPressed: () => ref
                          .read(loggingServiceProvider)
                          .markReview(node.id, unit),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Un-mark'),
                      onPressed: () {
                        ref.read(loggingServiceProvider).markUndone(node.id, unit);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, UnitHistory history) async {
    final done = history.done;
    if (done == null) return;
    final logger = ref.read(loggingServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final label = node.unitLabel?.name ?? 'unit';
    final result = await showLogUnitSheet(
      context,
      title: 'Edit · ${node.name} · $label $unit',
      initialOccurredAt: done.occurredAt,
      initialDurationMin: done.durationMin,
      initialNote: done.note,
      saveLabel: 'Save changes',
    );
    if (result == null) return;
    try {
      await logger.editDetails(
        done,
        // Null occurredAt means the user turned manual off; keep the stored date.
        occurredAt: result.occurredAt ?? done.occurredAt,
        durationMin: result.durationMin,
        note: result.note,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  static String _fmtMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
