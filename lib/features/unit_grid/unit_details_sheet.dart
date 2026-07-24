import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/learning_event.dart';
import '../../domain/usecases/unit_history.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';
import 'add_chazara_sheet.dart';
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
    final done = history.done;
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nodeAndUnit(l10n, node, unit),
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              if (done == null)
                Text(l10n.detailsNotLearnedYet,
                    style: theme.textTheme.bodyLarge)
              else ...[
                _DetailRow(
                  icon: Icons.event_available,
                  label: l10n.detailsFinished,
                  value: DateDisplay.formatWithTime(done.occurredAt, mode),
                ),
                _DetailRow(
                  icon: Icons.timer_outlined,
                  label: l10n.detailsTimeToLearn,
                  value: done.durationMin != null
                      ? formatMinutes(l10n, done.durationMin!)
                      : l10n.detailsNotRecorded,
                ),
                _DetailRow(
                  icon: Icons.refresh,
                  label: l10n.detailsChazaraPasses,
                  value: history.reviewCount == 0
                      ? l10n.detailsNoneYet
                      : '${history.reviewCount}',
                ),
                if (history.reviews.isNotEmpty)
                  Padding(
                    // Directional: these chazara lines indent *under* the row
                    // above them, which is the start edge, not the left one.
                    padding: const EdgeInsetsDirectional.only(
                        start: 32, top: 2, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < history.reviews.length; i++)
                          _chazaraLine(context, ref, i + 1, history.reviews[i], mode),
                      ],
                    ),
                  ),
                _DetailRow(
                  icon: Icons.lightbulb_outline,
                  label: l10n.detailsHaara,
                  value: (done.note == null || done.note!.isEmpty)
                      ? l10n.detailsNoHaara
                      : done.note!,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text(l10n.detailsEdit),
                      onPressed: () => _edit(context, ref, history),
                    ),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(l10n.detailsAddChazara),
                      onPressed: () =>
                          showAddChazaraSheet(context, ref, node: node, unit: unit),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.undo, size: 18),
                      label: Text(l10n.detailsUnmark),
                      onPressed: () => _unmark(context, ref),
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

  /// The sheet closes first — the write is guarded, so its outcome is reported
  /// on the messenger regardless of this sheet still being there.
  Future<void> _unmark(BuildContext context, WidgetRef ref) async {
    final logger = ref.read(loggingServiceProvider);
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    Navigator.of(context).pop();
    await guard.run(() => logger.markUndone(node.id, unit),
        what: l10n.whatUnmarking(nodeAndUnit(l10n, node, unit)));
  }

  Widget _chazaraLine(BuildContext context, WidgetRef ref, int n,
      LearningEvent review, CalendarMode mode) {
    final l10n = AppLocalizations.of(context);
    final allLayers = ref.read(allLayersProvider);
    String nameOf(String id) => layerName(
        l10n,
        allLayers.firstWhere((l) => l.id == id,
            orElse: () => Layer(id: id, name: id)));
    final mefarshim =
        review.layers.where((l) => l != mainLayerId).map(nameOf).toList();
    final head = <String>[
      l10n.chazaraPass(n),
      DateDisplay.format(review.occurredAt, mode),
      if (review.durationMin != null) l10n.minutesShort(review.durationMin!),
      if (mefarshim.isNotEmpty) mefarshim.join(', '),
    ].join(' · ');
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(head, style: theme.textTheme.bodySmall),
          if (review.note != null && review.note!.isNotEmpty)
            Text('“${review.note}”',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, UnitHistory history) async {
    final done = history.done;
    if (done == null) return;
    final logger = ref.read(loggingServiceProvider);
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final heading = nodeAndUnit(l10n, node, unit);
    final result = await showLogUnitSheet(
      context,
      title: l10n.detailsEditTitle(heading),
      initialOccurredAt: done.occurredAt,
      initialDurationMin: done.durationMin,
      initialNote: done.note,
      saveLabel: l10n.logSheetSaveChanges,
    );
    if (result == null) return;
    await guard.run(
      () => logger.editDetails(
        done,
        // Null occurredAt means the user turned manual off; keep the stored date.
        occurredAt: result.occurredAt ?? done.occurredAt,
        durationMin: result.durationMin,
        note: result.note,
      ),
      what: l10n.whatSavingDetails(heading),
    );
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
