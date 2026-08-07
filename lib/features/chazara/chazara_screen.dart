import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/stats.dart';
import '../../domain/usecases/chazara_schedule.dart';
import '../../domain/usecases/unit_mefarshim.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';
import '../unit_grid/log_unit_sheet.dart';

/// Units due for a chazara (review) pass, on a spaced-repetition schedule.
/// Reviewing an item logs a review and pushes its next due date out.
class ChazaraScreen extends ConsumerWidget {
  const ChazaraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(chazaraDueProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chazaraTitle)),
      body: due.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.chazaraEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: due.length,
              itemBuilder: (context, i) {
                final item = due[i];
                return _ChazaraRow(item: item);
              },
            ),
    );
  }
}

class _ChazaraRow extends ConsumerWidget {
  const _ChazaraRow({required this.item});
  final ChazaraItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final node = ref.watch(catalogNodeProvider(item.nodeId));
    // Named units (parshiyos, simanim) read as their names here too, not as
    // bare numbers — the same heading the grid and the journal show.
    final heading = node == null
        ? l10n.nodeAndUnit(
            item.nodeId,
            l10n.unitHeading(l10n.unitLabelUnknown, item.unitIndex),
          )
        : nodeAndUnit(l10n, node, item.unitIndex);
    final overdue = item.daysOverdue == 0
        ? l10n.chazaraDueToday
        : l10n.chazaraOverdue(item.daysOverdue);

    return ListTile(
      leading: const Icon(Icons.refresh),
      title: Text(heading),
      subtitle: Text(l10n.chazaraRowSubtitle(overdue, item.reviewCount)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The full sheet: pick which mefarshim, when, how long, and a haara.
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: l10n.chazaraLogWithDetails,
            onPressed: node == null
                ? null
                : () => logChazaraWithDetails(context, ref,
                    node: node, unit: item.unitIndex),
          ),
          FilledButton.tonal(
            onPressed: () => _quickReview(context, ref, l10n, heading),
            child: Text(l10n.actionReview),
          ),
        ],
      ),
    );
  }

  /// One tap = a pass over **everything currently learned on this unit**, which
  /// is what the Add-chazara sheet defaults to. The two paths used to disagree —
  /// this button recorded only the text, so a daf reviewed from here silently
  /// lost its mefarshim, and the same action meant two different things
  /// depending on where you tapped it.
  Future<void> _quickReview(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, String heading) async {
    // The same question the Add-chazara sheet asks, asked the same way — this
    // was a fourth hand-written answer to it, and "which is what the sheet
    // defaults to" was a promise nothing kept.
    final learned = UnitMefarshim.of(
      roles: ref.read(layerRolesProvider),
      fold: ref.read(foldProvider).asData?.value,
      layerOrder: [for (final l in ref.read(allLayersProvider)) l.id],
      nodeId: item.nodeId,
      unitIndex: item.unitIndex,
    ).done;
    final logger = ref.read(loggingServiceProvider);
    await guarded(
      context,
      ref,
      () => logger.markReview(
        item.nodeId,
        item.unitIndex,
        layers: learned.isEmpty
            ? UnitMefarshim.justTheText.toList()
            : learned.toList(),
      ),
      what: l10n.whatLoggingChazara(heading),
      success: l10n.chazaraReviewed(heading),
    );
  }
}
