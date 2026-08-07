import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/usecases/unit_mefarshim.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';
import 'log_unit_sheet.dart';
import 'meforish_checklist.dart';

/// Per-unit meforish checklist: toggle each required (and any already-learned)
/// layer for one daf. The unit is complete only once every required layer is
/// checked; the grid shows a partial fill until then.
Future<void> showUnitLayersSheet(
  BuildContext context,
  WidgetRef ref, {
  required CatalogNode node,
  required int unit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _UnitLayersSheet(node: node, unit: unit),
  );
}

class _UnitLayersSheet extends ConsumerWidget {
  const _UnitLayersSheet({required this.node, required this.unit});
  final CatalogNode node;
  final int unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fold = ref.watch(foldProvider).asData?.value;
    final roles = ref.watch(layerRolesProvider);
    final allLayers = ref.watch(allLayersProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Which mefarshim this unit has and what state each is in — asked through
    // [UnitMefarshim], which is also what the two logging sheets ask. This used
    // to be four set operations and a safety loop written out here, and the two
    // sheets each had their own version of it that answered differently.
    final mefarshim = UnitMefarshim.of(
      roles: roles,
      fold: fold,
      layerOrder: [for (final l in allLayers) l.id],
      nodeId: node.id,
      unitIndex: unit,
    );
    final completed = mefarshim.done;
    final requiredSet = mefarshim.required;

    final missing = mefarshim.outstanding.length;
    final logger = ref.read(loggingServiceProvider);
    // Captured here rather than per-callback: "Clear this unit" pops the sheet
    // and then writes, so by then this context is gone.
    final guard = WriteGuard.of(context, ref);
    final heading = nodeAndUnit(l10n, node, unit);

    // An id with no matching meforish means one was deleted after this unit was
    // marked. Name it as such — a raw UUID in a checkbox is unreadable.
    String nameOf(String id) => layerNameById(l10n, allLayers, id);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(heading, style: theme.textTheme.titleLarge),
              Text(
                missing == 0
                    ? l10n.layersComplete
                    : l10n.layersRemaining(missing, requiredSet.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: missing == 0 ? Colors.green : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              MeforishChecklist(
                mefarshim: mefarshim.all,
                layers: allLayers,
                showRole: true,
                isChecked: completed.contains,
                onChanged: (id, checked) => guard.run(
                  () => checked
                      ? logger.markDone(node.id, unit, layers: [id])
                      : logger.markUndone(node.id, unit, layers: [id]),
                  what: checked
                      ? l10n.whatMarkingLayer(nameOf(id), heading)
                      : l10n.whatUnmarkingLayer(nameOf(id), heading),
                ),
              ),
              const Divider(),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  icon: const Icon(Icons.done_all, size: 18),
                  label: Text(l10n.markAllRequiredLearned),
                  onPressed: () {
                    final toAdd = mefarshim.outstanding.toList();
                    if (toAdd.isEmpty) return;
                    guard.run(
                      () => logger.markDone(node.id, unit, layers: toAdd),
                      what: l10n.whatMarkingEveryRequired(heading),
                    );
                  },
                ),
              ),
              // The checkboxes above record *that* you learned it. This records
              // when, for how long, and what you thought — for the mefarshim you
              // pick. Same sheet the grid's long-press opens, so the two ways in
              // write the same thing.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: Text(l10n.logWithDateDurationHaara),
                  onPressed: () {
                    Navigator.pop(context);
                    logWithDetails(context, ref, node: node, unit: unit);
                  },
                ),
              ),
              if (completed.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    icon: const Icon(Icons.undo, size: 18),
                    label: Text(l10n.clearThisUnit),
                    onPressed: () {
                      Navigator.pop(context);
                      guard.run(
                        () => logger.markUndone(node.id, unit,
                            layers: completed.toList()),
                        what: l10n.whatClearingUnit(heading),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
