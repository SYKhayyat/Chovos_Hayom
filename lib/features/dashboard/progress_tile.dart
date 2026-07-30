import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../application/catalog_editor.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/progress_node.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';
import '../unit_grid/bulk_actions_sheet.dart';
import '../unit_grid/mefarshim_config_sheet.dart';

/// One row of the dashboard tree: a progress bar plus the per-node menu. Leaves
/// navigate to their per-unit grid; categories toggle their children.
///
/// Deliberately **not** recursive, and deliberately not an `ExpansionTile`. The
/// screen flattens the currently-visible tree and feeds the rows to a
/// `ListView.builder`, so only the rows actually on screen are ever built —
/// *Expand all* used to mount all ~312 tiles, each with a `LinearProgressIndicator`
/// and a per-meforish bar row, in a single frame. Expansion state lives on the
/// screen ([expanded] / [onToggle]) rather than inside each tile, which is what
/// makes that flattening possible — and it now survives a rebuild, which the
/// old epoch-bump trick could not.
class ProgressTile extends ConsumerWidget {
  const ProgressTile({
    super.key,
    required this.node,
    this.depth = 0,
    this.hasChildren = false,
    this.expanded = false,
    this.onToggle,
  });

  final ProgressNode node;
  final int depth;

  /// Whether there is anything to reveal. False for a leaf and for an empty
  /// category, neither of which gets a chevron.
  final bool hasChildren;
  final bool expanded;

  /// Toggles this node's expansion; null when there is nothing to expand.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Indent from the **start** edge, not from the left. The tree's whole job is
    // to show nesting, and under a Hebrew (right-to-left) layout a physical
    // `left` padding indents away from the side the text begins on — so a child
    // appeared to sit *outdented* from its parent, which reads as the opposite
    // of what it means.
    final indent = 16.0 + depth * 16;
    final l10n = AppLocalizations.of(context);

    if (node.node.isLeaf) {
      return ListTile(
        contentPadding: EdgeInsetsDirectional.only(start: indent, end: 8),
        title: Text(nodeName(l10n, node.node)),
        subtitle: _ProgressBar(node: node),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _nodeMenu(context, ref),
            node.isComplete
                ? const Icon(Icons.check_circle, color: Colors.green)
                // "Drill in" points the way the text runs, so it points left
                // under Hebrew. A chevron that always points right is telling a
                // right-to-left reader to go back.
                : Icon(Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left
                    : Icons.chevron_right),
          ],
        ),
        onTap: () => Navigator.pushNamed(context, Routes.sefer(node.node.id)),
      );
    }

    return ListTile(
      contentPadding: EdgeInsetsDirectional.only(start: indent, end: 8),
      title: Text(nodeName(l10n, node.node)),
      subtitle: _ProgressBar(node: node),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _nodeMenu(context, ref),
          if (hasChildren)
            IconButton(
              icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              tooltip: expanded ? l10n.tooltipCollapse : l10n.tooltipExpand,
              onPressed: onToggle,
            ),
        ],
      ),
      // The whole row toggles, so expanding is a mouse target the size of the
      // row rather than just the chevron.
      onTap: onToggle,
    );
  }

  /// Per-node actions menu — click-based so it works with a mouse (no long-press
  /// or touchscreen needed). Every node, built-in or custom, can be edited,
  /// extended, cloned, hidden, reset, or given its own mefarshim.
  Widget _nodeMenu(BuildContext context, WidgetRef ref) {
    final editor = CatalogEditor(ref);
    final l10n = AppLocalizations.of(context);
    // Watch, not read: hiding or editing another node adds an override row, and
    // this node's "Reset to default" / "Remove permanently" entry must follow
    // without waiting for some unrelated rebuild. Reading the loaded list here
    // (rather than `CatalogEditor.isOverridden`, which is `.asData?.value ??
    // const []` — "not loaded" read as "no overrides", the silent-lie shape in a
    // decision path) makes the tile depend on it and stay current.
    final customNodes = ref.watch(customNodesProvider).asData?.value ?? const [];
    final overridden = customNodes.any((n) => n.id == node.node.id);
    final builtIn = editor.isBuiltIn(node.node.id);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      tooltip: l10n.nodeMenuTooltip,
      onSelected: (value) => _onMenu(context, ref, editor, value),
      itemBuilder: (_) => [
        // The whole InheritedLayerSet engine is built around pinning a set at a
        // *high* node and letting it inherit down. Until this entry existed the
        // only way in was a leaf's app bar, so "require Rashi across all of
        // Shas" meant opening thirty-seven mesechtos one at a time.
        PopupMenuItem(value: 'mefarshim', child: Text(l10n.menuMefarshim)),
        PopupMenuItem(value: 'bulk', child: Text(l10n.menuBulkActions)),
        PopupMenuItem(value: 'edit', child: Text(l10n.actionEdit)),
        PopupMenuItem(value: 'add', child: Text(l10n.menuAddSubItem)),
        PopupMenuItem(value: 'clone', child: Text(l10n.menuCloneStructure)),
        PopupMenuItem(value: 'hide', child: Text(l10n.menuHideDelete)),
        if (overridden)
          PopupMenuItem(
              value: 'reset',
              child: Text(builtIn
                  ? l10n.menuResetToDefault
                  : l10n.menuRemovePermanently)),
      ],
    );
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, CatalogEditor editor,
      String action) async {
    final navigator = Navigator.of(context);
    // Captured up front: 'hide' confirms first, so by the time it writes there
    // has already been an async gap.
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final name = nodeName(l10n, node.node);
    switch (action) {
      case 'mefarshim':
        await showMefarshimConfigSheet(context, ref, node: node.node);
      case 'bulk':
        await showBulkActionsSheet(context, ref, node: node.node);
      case 'edit':
        await navigator.pushNamed(Routes.editItem(node.node.id));
      case 'add':
        await navigator.pushNamed(Routes.addItemUnder(node.node.id));
      case 'clone':
        await guard.run(() => editor.cloneStructure(node.node),
            what: l10n.whatCloning(name), success: l10n.clonedNode(name));
      case 'hide':
        final ok = await _confirm(
            context, l10n.hideNodeTitle(name), l10n.hideNodeBody);
        if (ok) {
          await guard.run(() => editor.hide(node.node),
              what: l10n.whatHiding(name));
        }
      case 'reset':
        await guard.run(() => editor.reset(node.node.id),
            what: l10n.whatResetting(name));
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.actionCancel)),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.hideNodeConfirm)),
        ],
      ),
    );
    return ok ?? false;
  }
}

class _ProgressBar extends ConsumerWidget {
  const _ProgressBar({required this.node});
  final ProgressNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The bar itself carries no semantics — its value is announced by the
          // count underneath, which is the same information in words. Marking it
          // decorative stops a screen reader reading the node twice.
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: node.total == 0 ? 0 : node.learned / node.total,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            // Isolated, or Hebrew paints "0 / 929" as "929 / 0" — see
            // [ltrNumerals]. This is the most-read number in the app.
            ltrNumerals(l10n.progressCount(
                node.learned, node.total, node.percent.toStringAsFixed(1))),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ..._meforishBars(context, ref),
        ],
      ),
    );
  }

  /// A thin line per enabled meforish (Rashi, Tosafos, …) showing its coverage
  /// across this node — the mefarshim offered/required here, plus any that
  /// already carry progress underneath (so an aggregating parent reflects them).
  /// The primary text is excluded; it maps to the main bar above.
  List<Widget> _meforishBars(BuildContext context, WidgetRef ref) {
    if (node.total == 0) return const [];
    final l10n = AppLocalizations.of(context);
    final offered = ref.watch(offeredLayersProvider).forNode(node.id);
    final required = ref.watch(layerRequirementsProvider).forNode(node.id);
    final layers = ref.watch(allLayersProvider);
    final hidden = ref.watch(settingsProvider.select((s) => s.hiddenMeforishBars));

    final show = <String>{
      ...offered,
      ...required,
      ...node.learnedByLayer.keys,
    }
      ..remove(mainLayerId)
      ..removeWhere(hidden.contains); // per-meforish toggle in Settings
    if (show.isEmpty) return const [];

    // Stable order following the mefarshim list; unknown ids fall to the end.
    final ordered = [
      for (final l in layers)
        if (show.contains(l.id)) l.id,
      for (final id in show)
        if (layers.every((l) => l.id != id)) id,
    ];

    Layer layerOf(String id) =>
        layers.firstWhere((l) => l.id == id, orElse: () => Layer(id: id, name: id));

    return [
      const SizedBox(height: 4),
      for (final id in ordered)
        _MeforishBar(
          name: layerName(l10n, layerOf(id)),
          learned: node.learnedFor(id),
          total: node.total,
        ),
    ];
  }
}

/// One compact meforish coverage line: name · thin bar · count.
class _MeforishBar extends StatelessWidget {
  const _MeforishBar(
      {required this.name, required this.learned, required this.total});
  final String name;
  final int learned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    // Name, bar and count are one fact ("Rashi, 240 of 2711"), so they are read
    // as one node rather than as three fragments in a row.
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            SizedBox(
              width: 68,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: total == 0 ? 0 : learned / total,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: scheme.secondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Safe as spelled (an unspaced slash joins the numeric run) and
            // isolated anyway: see [ltrNumerals] on why "it happens to be safe"
            // is not a property to leave a string table depending on.
            Text(ltrNumerals(l10n.meforishCoverage(learned, total)),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
