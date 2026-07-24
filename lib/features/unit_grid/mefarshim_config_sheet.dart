import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/providers.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/layer.dart';
import '../../domain/usecases/layer_requirements.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';

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

  /// True once the user has actually changed something. The sheet seeds from the
  /// *inherited* answer, so saving an untouched sheet would pin that answer here
  /// as a node-level override — silently detaching this node from its ancestor.
  /// We only write when there is a real edit to write.
  bool _dirty = false;

  @override
  Widget build(BuildContext context) {
    final layers = ref.watch(allLayersProvider);
    final required = ref.watch(layerRequirementsProvider);
    final offered = ref.watch(offeredLayersProvider);
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Seed once from the currently-effective sets. Available always includes
    // required (required ⇒ available), matching how they resolve at a unit.
    if (_required == null) {
      _required = {...required.forNode(widget.node.id)};
      _available = {...offered.forNode(widget.node.id), ..._required!};
    }
    final requiredSet = _required!;
    final availableSet = _available!;

    // Where the effective sets come from, so the sheet can say so rather than
    // presenting an inherited answer as if it were set here.
    final reqSource = required.pinnedSource(widget.node.id);
    final offSource = offered.pinnedSource(widget.node.id);
    final pinnedHere =
        reqSource == widget.node.id || offSource == widget.node.id;
    final inheritedNode = pinnedHere || (reqSource ?? offSource) == null
        ? null
        : catalog?.byId((reqSource ?? offSource)!);
    final String provenance;
    if (pinnedHere) {
      provenance = l10n.mefarshimSetHere;
    } else if (inheritedNode != null) {
      provenance = l10n.mefarshimInheritedFrom(nodeName(l10n, inheritedNode));
    } else {
      provenance = l10n.mefarshimDefault;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.mefarshimTitle, style: theme.textTheme.titleLarge),
              Text(nodeName(l10n, widget.node),
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                l10n.mefarshimExplainer,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                provenance,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              for (final layer in layers)
                _MeforishRow(
                  layer: layer,
                  available: availableSet.contains(layer.id),
                  required: requiredSet.contains(layer.id),
                  onAvailable: (v) => setState(() {
                    _dirty = true;
                    if (v) {
                      availableSet.add(layer.id);
                    } else {
                      availableSet.remove(layer.id);
                      requiredSet.remove(layer.id); // required ⇒ available
                    }
                  }),
                  onRequired: (v) => setState(() {
                    _dirty = true;
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
                label: Text(l10n.mefarshimAddMeforish),
                onPressed: _addCustomLayer,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: _resetToInherited,
                    child: Text(l10n.mefarshimResetToInherited),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _save,
                    child: Text(l10n.actionSave),
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
    // Nothing was touched, so there is nothing to pin. Writing here anyway would
    // freeze the inherited answer as a node-level override — the exact silent
    // detachment this guard exists to prevent. Just close.
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final repo = ref.read(progressRepositoryProvider);
    final profileId = ref.read(activeProfileProvider);
    final navigator = Navigator.of(context);
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final requiredSet = _required!;
    // Available always subsumes required; an empty required falls back to text.
    final availableSet = {..._available!, ...requiredSet};
    // Required and offered are two halves of one answer; writing one without the
    // other leaves a node requiring a meforish it does not offer.
    final saved = await guard.run(
      () => repo.transaction(() async {
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
      }),
      what: l10n.whatSavingMefarshim(nodeName(l10n, widget.node)),
    );
    if (saved) navigator.pop();
  }

  Future<void> _resetToInherited() async {
    final repo = ref.read(progressRepositoryProvider);
    final profileId = ref.read(activeProfileProvider);
    final navigator = Navigator.of(context);
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final reset = await guard.run(
      () => repo.transaction(() async {
        await repo.clearLayerRequirement(profileId, widget.node.id, -1);
        await repo.clearOfferedLayers(profileId, widget.node.id, -1);
      }),
      what: l10n.whatResettingMefarshim(nodeName(l10n, widget.node)),
    );
    if (reset) navigator.pop();
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
    final repo = ref.read(progressRepositoryProvider);
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final name = layerName(l10n, layer);
    // From the repository, not from the providers that cache it. A config that
    // read as an empty list would tell the user "required in 0 places" and then
    // leave every one of those references dangling — the exact failure deleting
    // a meforish was fixed for.
    final requirements = await repo.watchLayerRequirements(profileId).first;
    final offered = await repo.watchOfferedLayers(profileId).first;
    if (!mounted) return;

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
        title: Text(l10n.mefarshimDeleteTitle(name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (requiredCount > 0)
              Text(l10n.mefarshimDeleteRequiredWarning(requiredCount)),
            if (requiredCount > 0) const SizedBox(height: 8),
            Text(l10n.mefarshimDeleteLogNote),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.actionCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final deleted = await guard.run(
      () => repo.transaction(() async {
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
      }),
      what: l10n.whatDeletingMeforish(name),
    );
    // Nothing was written, so nothing may leave the in-progress edit either —
    // dropping it here on a failure would hide a meforish that still exists.
    if (!deleted) return;

    // Drop it from the in-progress edit too, so the sheet doesn't re-save it.
    if (mounted) {
      setState(() {
        _available?.remove(layer.id);
        _required?.remove(layer.id);
      });
    }
    // A delete happened, but it wrote its own settings changes already and does
    // not, by itself, make the seeded (inherited) set worth pinning here — so it
    // deliberately does not set `_dirty`. Toggling a chip does.
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
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final hebrewCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.mefarshimNewTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.labelName),
            ),
            TextField(
              controller: hebrewCtrl,
              decoration:
                  InputDecoration(labelText: l10n.mefarshimHebrewOptional),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.actionCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.actionAdd)),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final hebrew = hebrewCtrl.text.trim();
    nameCtrl.dispose();
    hebrewCtrl.dispose();
    if (ok != true || name.isEmpty) return;
    final id = const Uuid().v4();
    final repo = ref.read(progressRepositoryProvider);
    final profileId = ref.read(activeProfileProvider);
    final added = await guard.run(
      () => repo.addCustomLayer(
        profileId,
        Layer(id: id, name: name, nameHebrew: hebrew.isEmpty ? null : hebrew),
      ),
      what: l10n.whatAddingMeforish(name),
    );
    if (!added) return;
    // A freshly-added meforish starts Available (checkable) but not Required —
    // exactly the "offer without mandating" case.
    if (mounted) {
      setState(() {
        _dirty = true;
        _available!.add(id);
      });
    }
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
    final l10n = AppLocalizations.of(context);
    // Both names are shown together where there are two, so the row reads the
    // same in either language rather than hiding the one you didn't pick.
    final primary = layerName(l10n, layer);
    final secondary = primary == layer.name ? layer.nameHebrew : layer.name;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(primary),
                if (secondary != null && secondary != primary)
                  Text(secondary,
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          FilterChip(
            label: Text(l10n.mefarshimAvailable),
            selected: available,
            onSelected: onAvailable,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: Text(l10n.labelRequired),
            selected: required,
            onSelected: onRequired,
            visualDensity: VisualDensity.compact,
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: l10n.tooltipDeleteMeforish,
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
