import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/layer.dart';

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
    final required = ref.watch(layerRequirementsProvider);
    final allLayers = ref.watch(allLayersProvider);
    final theme = Theme.of(context);
    final label = node.unitLabel?.name ?? 'unit';

    final completed = fold?.completedLayers(node.id, unit) ?? const {};
    final requiredSet = required.forUnit(node.id, unit);

    // Show required layers first, then any extra learned layers, in a stable
    // order that follows the mefarshim list.
    final shown = <String>[
      for (final l in allLayers)
        if (requiredSet.contains(l.id) || completed.contains(l.id)) l.id,
    ];
    // Include anything required/completed that isn't in the known list (safety).
    for (final id in {...requiredSet, ...completed}) {
      if (!shown.contains(id)) shown.add(id);
    }

    final missing = requiredSet.where((l) => !completed.contains(l)).length;
    final logger = ref.read(loggingServiceProvider);

    Layer layerOf(String id) => allLayers.firstWhere((l) => l.id == id,
        orElse: () => Layer(id: id, name: id));

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
              Text(
                missing == 0
                    ? 'Complete — all required mefarshim learned.'
                    : '$missing of ${requiredSet.length} required still to learn.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: missing == 0 ? Colors.green : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              for (final id in shown)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: completed.contains(id),
                  title: Text(layerOf(id).name),
                  subtitle: requiredSet.contains(id)
                      ? const Text('Required')
                      : const Text('Extra'),
                  onChanged: (v) {
                    if (v == true) {
                      logger.markDone(node.id, unit, layers: [id]);
                    } else {
                      logger.markUndone(node.id, unit, layers: [id]);
                    }
                  },
                ),
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Mark all required learned'),
                  onPressed: () {
                    final toAdd = requiredSet
                        .where((l) => !completed.contains(l))
                        .toList();
                    if (toAdd.isNotEmpty) {
                      logger.markDone(node.id, unit, layers: toAdd);
                    }
                  },
                ),
              ),
              if (completed.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Clear this unit'),
                    onPressed: () {
                      logger.markUndone(node.id, unit, layers: completed.toList());
                      Navigator.pop(context);
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
