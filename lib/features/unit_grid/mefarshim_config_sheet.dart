import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/providers.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/layer.dart';
import '../../domain/usecases/layer_requirements.dart';

/// Editor for a node's mefarshim, with two independent dimensions per meforish:
///
/// - **Available** — you can check it off on any unit here (it appears in the
///   per-unit checklist), without it affecting completion.
/// - **Required** — it must be learned for a unit to count as done.
///
/// Required implies Available. Both pin at [node] and inherit down unless a
/// nearer node or a single unit overrides them. Fully user-driven: add your own
/// mefarshim, offer any subset, require any subset, and reset to inherited.
Future<void> showMefarshimConfigSheet(
  BuildContext context,
  WidgetRef ref, {
  required CatalogNode node,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _MefarshimConfigSheet(node: node),
  );
}

class _MefarshimConfigSheet extends ConsumerStatefulWidget {
  const _MefarshimConfigSheet({required this.node});
  final CatalogNode node;

  @override
  ConsumerState<_MefarshimConfigSheet> createState() =>
      _MefarshimConfigSheetState();
}

class _MefarshimConfigSheetState extends ConsumerState<_MefarshimConfigSheet> {
  Set<String>? _available; // null until seeded from the effective sets
  Set<String>? _required;

  @override
  Widget build(BuildContext context) {
    final layers = ref.watch(allLayersProvider);
    final required = ref.watch(layerRequirementsProvider);
    final offered = ref.watch(offeredLayersProvider);
    final theme = Theme.of(context);

    // Seed once from the currently-effective sets. Available always includes
    // required (required ⇒ available), matching how they resolve at a unit.
    if (_required == null) {
      _required = {...required.forNode(widget.node.id)};
      _available = {...offered.forNode(widget.node.id), ..._required!};
    }
    final requiredSet = _required!;
    final availableSet = _available!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mefarshim', style: theme.textTheme.titleLarge),
              Text(widget.node.name, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '“Available” = you can check it off here. “Required” = a unit is '
                'done only once it’s learned. Applies to everything under this '
                'item unless overridden.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final layer in layers)
                _MeforishRow(
                  layer: layer,
                  available: availableSet.contains(layer.id),
                  required: requiredSet.contains(layer.id),
                  onAvailable: (v) => setState(() {
                    if (v) {
                      availableSet.add(layer.id);
                    } else {
                      availableSet.remove(layer.id);
                      requiredSet.remove(layer.id); // required ⇒ available
                    }
                  }),
                  onRequired: (v) => setState(() {
                    if (v) {
                      requiredSet.add(layer.id);
                      availableSet.add(layer.id); // required ⇒ available
                    } else {
                      requiredSet.remove(layer.id);
                    }
                  }),
                  onDelete: layer.builtIn ? null : () => _deleteLayer(layer),
                ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add a meforish'),
                onPressed: _addCustomLayer,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: _resetToInherited,
                    child: const Text('Reset to inherited'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final repo = ref.read(progressRepositoryProvider);
    final profileId = ref.read(activeProfileProvider);
    final requiredSet = _required!;
    // Available always subsumes required; an empty required falls back to text.
    final availableSet = {..._available!, ...requiredSet};
    await repo.setLayerRequirement(
      profileId,
      LayerConfigEntry(
        nodeId: widget.node.id,
        unitIndex: -1,
        layers: requiredSet.isEmpty ? {mainLayerId} : requiredSet,
      ),
    );
    await repo.setOfferedLayers(
      profileId,
      LayerConfigEntry(
        nodeId: widget.node.id,
        unitIndex: -1,
        layers: availableSet.isEmpty ? {mainLayerId} : availableSet,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _resetToInherited() async {
    final repo = ref.read(progressRepositoryProvider);
    final profileId = ref.read(activeProfileProvider);
    await repo.clearLayerRequirement(profileId, widget.node.id, -1);
    await repo.clearOfferedLayers(profileId, widget.node.id, -1);
    if (mounted) Navigator.pop(context);
  }

  /// Delete a custom meforish, taking every reference to it with it.
  ///
  /// Deleting used to remove only the row, leaving the id behind in required-
  /// and offered-layer settings all over the tree. Anything that *required* it
  /// then became uncompletable — the unit checklist could only offer a checkbox
  /// labelled with a raw UUID. So the settings are rewritten in the same
  /// transaction, and the user is told how many will change before it happens.
  ///
  /// Past events keep their record: the log is history, and a chazara you did on
  /// a meforish still happened. Nothing reads those ids once the settings are
  /// gone, so nothing is gated on or offers a meforish that no longer exists.
  Future<void> _deleteLayer(Layer layer) async {
    final profileId = ref.read(activeProfileProvider);
    final requirements = ref.read(layerConfigProvider).asData?.value ?? const [];
    final offered = ref.read(offeredConfigProvider).asData?.value ?? const [];

    final affectedRequired = [
      for (final e in requirements)
        if (e.layers.contains(layer.id)) e,
    ];
    final affectedOffered = [
      for (final e in offered)
        if (e.layers.contains(layer.id)) e,
    ];
    final requiredCount = affectedRequired.length;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete “${layer.name}”?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (requiredCount > 0)
              Text('It is currently *required* in $requiredCount '
                  '${requiredCount == 1 ? 'place' : 'places'}. Those units will '
                  'go back to not needing it, so anything they were waiting on '
                  'it for becomes complete.'),
            if (requiredCount > 0) const SizedBox(height: 8),
            const Text('Chazaras and learning you already recorded against it '
                'stay in your log.'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final repo = ref.read(progressRepositoryProvider);
    await repo.transaction(() async {
      for (final e in affectedRequired) {
        await _rewriteWithout(
            e, layer.id, (v) => repo.setLayerRequirement(profileId, v),
            clear: () =>
                repo.clearLayerRequirement(profileId, e.nodeId, e.unitIndex));
      }
      for (final e in affectedOffered) {
        await _rewriteWithout(
            e, layer.id, (v) => repo.setOfferedLayers(profileId, v),
            clear: () =>
                repo.clearOfferedLayers(profileId, e.nodeId, e.unitIndex));
      }
      await repo.removeCustomLayer(profileId, layer.id);
    });

    // Drop it from the in-progress edit too, so the sheet doesn't re-save it.
    if (mounted) {
      setState(() {
        _available?.remove(layer.id);
        _required?.remove(layer.id);
      });
    }
  }

  /// Writes [entry] back without [layerId] — or clears the setting entirely when
  /// nothing would be left, so the node falls back to inheritance rather than
  /// being pinned to an empty set.
  static Future<void> _rewriteWithout(
    LayerConfigEntry entry,
    String layerId,
    Future<void> Function(LayerConfigEntry) write, {
    required Future<void> Function() clear,
  }) async {
    final remaining = {...entry.layers}..remove(layerId);
    if (remaining.isEmpty) return clear();
    return write(LayerConfigEntry(
        nodeId: entry.nodeId, unitIndex: entry.unitIndex, layers: remaining));
  }

  Future<void> _addCustomLayer() async {
    final nameCtrl = TextEditingController();
    final hebrewCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New meforish'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: hebrewCtrl,
              decoration: const InputDecoration(labelText: 'Hebrew (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add')),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final hebrew = hebrewCtrl.text.trim();
    nameCtrl.dispose();
    hebrewCtrl.dispose();
    if (ok != true || name.isEmpty) return;
    final id = const Uuid().v4();
    await ref.read(progressRepositoryProvider).addCustomLayer(
          ref.read(activeProfileProvider),
          Layer(id: id, name: name, nameHebrew: hebrew.isEmpty ? null : hebrew),
        );
    // A freshly-added meforish starts Available (checkable) but not Required —
    // exactly the "offer without mandating" case.
    if (mounted) setState(() => _available!.add(id));
  }
}

/// One meforish row: its name plus two independent toggles (Available, Required)
/// and an optional delete for custom mefarshim. Chips are mouse-friendly and
/// read clearly on desktop — no touchscreen assumed.
class _MeforishRow extends StatelessWidget {
  const _MeforishRow({
    required this.layer,
    required this.available,
    required this.required,
    required this.onAvailable,
    required this.onRequired,
    this.onDelete,
  });

  final Layer layer;
  final bool available;
  final bool required;
  final ValueChanged<bool> onAvailable;
  final ValueChanged<bool> onRequired;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(layer.name),
                if (layer.nameHebrew != null)
                  Text(layer.nameHebrew!,
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          FilterChip(
            label: const Text('Available'),
            selected: available,
            onSelected: onAvailable,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: const Text('Required'),
            selected: required,
            onSelected: onRequired,
            visualDensity: VisualDensity.compact,
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Delete meforish',
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
