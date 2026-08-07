import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/providers.dart';
import '../../core/keypad.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/layer.dart';
import '../../domain/usecases/layer_roles.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';
import '../common/text_prompt.dart';

/// Editor for a node's mefarshim. Each one is in exactly one of three states:
///
/// - **Off** — not on the unit at all.
/// - **Available** — you can check it off on any unit here (it appears in the
///   per-unit checklist), without it affecting completion.
/// - **Required** — it must be learned for a unit to count as done.
///
/// This was two independent chips, Available and Required, which is four states
/// for a three-state answer. "Required but not available" means nothing, so
/// ticking Required silently ticked Available and un-ticking Available silently
/// un-ticked Required — an invariant repaired by hand here, again at save, and a
/// third time by every reader taking `offered ∪ required`. One control that can
/// only be in one position has nothing to repair.
///
/// The setting pins at [node] and inherits down unless a nearer node or a single
/// unit overrides it. Fully user-driven: add your own mefarshim, set any of them
/// to anything, and reset to inherited.
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
  /// layer id -> role. Null until seeded from the effective answer; a layer that
  /// is absent is *off*, which is the third state and needs no storage.
  Map<String, LayerRole>? _roles;

  /// True once the user has actually changed something. The sheet seeds from the
  /// *inherited* answer, so saving an untouched sheet would pin that answer here
  /// as a node-level override — silently detaching this node from its ancestor.
  /// We only write when there is a real edit to write.
  bool _dirty = false;

  @override
  Widget build(BuildContext context) {
    final layers = ref.watch(allLayersProvider);
    final roles = ref.watch(layerRolesProvider);
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Seed once from the currently-effective answer.
    final current = _roles ??= {...roles.forNode(widget.node.id)};

    // Where the effective answer comes from, so the sheet can say so rather than
    // presenting an inherited answer as if it were set here. One source now,
    // where there were two that could name different nodes and the sheet just
    // took whichever was non-null first.
    final source = roles.pinnedSource(widget.node.id);
    final pinnedHere = source == widget.node.id;
    final inheritedNode =
        pinnedHere || source == null ? null : catalog?.byId(source);
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
                  role: current[layer.id],
                  onRole: (v) => setState(() {
                    _dirty = true;
                    if (v == null) {
                      current.remove(layer.id);
                    } else {
                      current[layer.id] = v;
                    }
                  }),
                  onEdit: layer.builtIn
                      ? null
                      : () => _editCustomLayer(existing: layer),
                  onDelete: layer.builtIn ? null : () => _deleteLayer(layer),
                ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.mefarshimAddMeforish),
                onPressed: _editCustomLayer,
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
    // Everything off falls back to the text, required — the same floor the two
    // writes each used to apply separately. One write, so it applies once, and
    // there is no longer a transaction here because there is nothing to pair it
    // with: a half-written config was only possible when it took two rows.
    final current = _roles!;
    final saved = await guard.run(
      () => repo.setLayerConfig(
        profileId,
        LayerConfigEntry(
          nodeId: widget.node.id,
          unitIndex: -1,
          roles: current.isEmpty ? defaultLayerRoles : current,
        ),
      ),
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
      () => repo.clearLayerConfig(profileId, widget.node.id, -1),
      what: l10n.whatResettingMefarshim(nodeName(l10n, widget.node)),
    );
    if (reset) navigator.pop();
  }

  /// Delete a custom meforish, taking every reference to it with it.
  ///
  /// Deleting used to remove only the row, leaving the id behind in layer
  /// settings all over the tree. Anything that *required* it then became
  /// uncompletable — the unit checklist could only offer a checkbox labelled
  /// with a raw UUID. So the settings are rewritten in the same transaction, and
  /// the user is told how many will change before it happens.
  ///
  /// This used to walk two lists over two tables, and clearing one while
  /// rewriting the other is exactly how a node ended up pinned in one and
  /// inheriting in the other. One list now, so a scope is either rewritten or
  /// cleared, never half of each.
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
    final configs = await repo.getLayerConfigs(profileId);
    if (!mounted) return;

    final affected = [
      for (final e in configs)
        if (e.roles.containsKey(layer.id)) e,
    ];
    // The warning is about completion breaking, so it counts the scopes that
    // *require* it — an optional one disappearing costs the user nothing.
    final requiredCount = affected.where((e) => e.required.contains(layer.id)).length;

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
        for (final e in affected) {
          final remaining = e.without(layer.id);
          if (remaining == null) {
            // Nothing would be left, so clear the setting entirely and let the
            // node fall back to inheritance rather than pinning an empty map.
            await repo.clearLayerConfig(profileId, e.nodeId, e.unitIndex);
          } else {
            await repo.setLayerConfig(profileId, remaining);
          }
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
      setState(() => _roles?.remove(layer.id));
    }
    // A delete happened, but it wrote its own settings changes already and does
    // not, by itself, make the seeded (inherited) set worth pinning here — so it
    // deliberately does not set `_dirty`. Toggling a chip does.
  }

  /// Add a meforish, or edit one you added.
  ///
  /// Editing used to be impossible: a custom meforish could be created and
  /// deleted and nothing else, so a Hebrew name you didn't think to type at
  /// creation could never be added — the only route was to delete it (losing
  /// every required/offered set that named it) and start again. Saving reuses
  /// the same id, and `addCustomLayer` is an upsert, so a rename leaves every
  /// event and every layer setting still pointing at it.
  Future<void> _editCustomLayer({Layer? existing}) async {
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    // Through the shared prompt, which owns the controllers. This was a
    // hand-rolled `StatefulWidget` with its own pair of them and its own copy
    // of the paragraph explaining why they cannot be disposed beside the
    // `showDialog` call — the third copy of that knowledge in a codebase that
    // has a file for it.
    final result = await promptForFields(
      context,
      title: existing == null
          ? l10n.mefarshimNewTitle
          : l10n.mefarshimEditTitle(layerName(l10n, existing)),
      confirmLabel: existing == null ? l10n.actionAdd : l10n.actionSave,
      cancelLabel: l10n.actionCancel,
      footer: l10n.namePairHelp,
      fields: [
        PromptField(
          key: 'name',
          label: l10n.labelNameEnglish,
          initialValue: existing?.name ?? '',
        ),
        PromptField(
          key: 'hebrew',
          label: l10n.labelNameHebrew,
          initialValue: existing?.nameHebrew ?? '',
          textDirection: TextDirection.rtl,
        ),
      ],
    );
    if (result == null) return;
    final typed = result['name']!;
    final hebrew = result['hebrew']!;
    // Either field alone is enough. Someone working entirely in Hebrew should
    // not have to invent a transliteration to get past the form, so the Hebrew
    // stands in as the primary name — which is also the fallback every
    // English-locale screen will then show.
    final name = typed.isNotEmpty ? typed : hebrew;
    if (name.isEmpty) {
      guard.report(l10n.mefarshimNeedName);
      return;
    }
    final id = existing?.id ?? const Uuid().v4();
    final repo = ref.read(progressRepositoryProvider);
    final profileId = ref.read(activeProfileProvider);
    final saved = await guard.run(
      () => repo.addCustomLayer(
        profileId,
        Layer(id: id, name: name, nameHebrew: hebrew.isEmpty ? null : hebrew),
      ),
      what: existing == null
          ? l10n.whatAddingMeforish(name)
          : l10n.whatSavingMeforish(name),
    );
    if (!saved || existing != null) return;
    // A freshly-added meforish starts Available (checkable) but not Required —
    // exactly the "offer without mandating" case. An *edit* changes no set, so
    // it deliberately leaves `_dirty` alone.
    if (mounted) {
      setState(() {
        _dirty = true;
        _roles![id] = LayerRole.optional;
      });
    }
  }
}

/// One meforish row: its name, the one control that says what it is here, and an
/// optional edit/delete for custom mefarshim.
///
/// A [SegmentedButton] rather than two chips because the states are mutually
/// exclusive — a control that can only be in one position is the whole point of
/// the tri-state. It is also mouse- and D-pad-friendly, and takes one tab stop
/// where two chips took two.
class _MeforishRow extends StatelessWidget {
  const _MeforishRow({
    required this.layer,
    required this.role,
    required this.onRole,
    this.onEdit,
    this.onDelete,
  });

  final Layer layer;

  /// Null means *off* — the layer is simply not in the node's role map.
  final LayerRole? role;
  final ValueChanged<LayerRole?> onRole;

  /// Rename it, or give it the Hebrew name you didn't type at creation.
  /// Null for the built-ins, which are not the user's to rename.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Both names are shown together where there are two, so the row reads the
    // same in either language rather than hiding the one you didn't pick.
    final primary = layerName(l10n, layer);
    final secondary = primary == layer.name ? layer.nameHebrew : layer.name;
    final compact = isCompact(context);

    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(primary),
        if (secondary != null && secondary != primary)
          Text(secondary, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    final buttons = [
      if (onEdit != null)
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          tooltip: l10n.tooltipEditMeforish,
          onPressed: onEdit,
        ),
      if (onDelete != null)
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: l10n.tooltipDeleteMeforish,
          onPressed: onDelete,
        ),
    ];
    // `SegmentedButton` takes a set, but this one is single-select: `selected`
    // always holds exactly one value, and null is a real value (off) rather than
    // an empty selection, so there is no state where nothing is lit.
    final control = SegmentedButton<LayerRole?>(
      segments: [
        ButtonSegment(value: null, label: Text(l10n.mefarshimOff)),
        ButtonSegment(
            value: LayerRole.optional, label: Text(l10n.mefarshimAvailable)),
        ButtonSegment(
            value: LayerRole.required, label: Text(l10n.labelRequired)),
      ],
      selected: {role},
      // Same reasoning as the Calculator's mode switch: the tick costs ~24dp,
      // and on a 240dp screen that is the difference between "Required" and a
      // column of letters. The filled segment already says which one is chosen.
      showSelectedIcon: !compact,
      onSelectionChanged: (s) => onRole(s.first),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // The control gets its own line at every width rather than sitting beside
      // the name. Three segments, a name and two icons overflow a 240dp screen
      // by a mile and an 800dp one by 31px, and the fix for that is either a
      // second layout for narrow screens — two shapes of one row, which is the
      // thing this whole change is about — or one shape that always fits. It
      // also reads better: the meforish, then what it is here.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: name), ...buttons]),
          const SizedBox(height: 4),
          control,
        ],
      ),
    );
  }
}
