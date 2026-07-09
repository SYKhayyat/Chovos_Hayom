import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/catalog_editor.dart';
import '../../application/settings.dart';
import '../../application/sorting.dart';
import '../../domain/entities/progress_node.dart';
import '../custom_node/add_custom_node_screen.dart';
import '../unit_grid/unit_grid_screen.dart';

/// Recursive expandable tree row with a progress bar. Leaves navigate to their
/// per-unit grid; categories expand to reveal children.
///
/// [initiallyExpanded] + [epoch] drive expand-all / collapse-all: bumping the
/// epoch changes every tile's key, forcing a rebuild that honours the new
/// initial-expansion state. [customIds] marks user-created nodes, which get a
/// delete action.
class ProgressTile extends ConsumerWidget {
  const ProgressTile({
    super.key,
    required this.node,
    this.depth = 0,
    this.initiallyExpanded = false,
    this.epoch = 0,
    this.customIds = const {},
  });

  final ProgressNode node;
  final int depth;
  final bool initiallyExpanded;
  final int epoch;
  final Set<String> customIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indent = 16.0 + depth * 16;

    if (node.node.isLeaf) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: indent, right: 8),
        title: Text(node.name),
        subtitle: _ProgressBar(node: node),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _nodeMenu(context, ref),
            node.isComplete
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => UnitGridScreen(node: node.node)),
        ),
      );
    }

    return ExpansionTile(
      key: ValueKey('${node.node.id}#$epoch'),
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.only(left: indent, right: 8),
      title: Text(node.name),
      subtitle: _ProgressBar(node: node),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [_nodeMenu(context, ref), const Icon(Icons.expand_more)],
      ),
      childrenPadding: EdgeInsets.zero,
      children: [
        for (final child in _orderedChildren(ref))
          ProgressTile(
            node: child,
            depth: depth + 1,
            initiallyExpanded: initiallyExpanded,
            epoch: epoch,
            customIds: customIds,
          ),
      ],
    );
  }

  /// This node's children in display order. The sort applies only when the
  /// configured [SortConfig.level] targets this generation (null = all levels).
  List<ProgressNode> _orderedChildren(WidgetRef ref) {
    final config = ref.watch(settingsProvider.select((s) => s.sort));
    final childDepth = depth + 1;
    if (!config.active || (config.level != null && config.level != childDepth)) {
      return node.children;
    }
    return sortChildren(node.children, config, ref.watch(nodeLastActivityProvider));
  }

  /// Per-node actions menu — click-based so it works with a mouse (no long-press
  /// or touchscreen needed). Every node, built-in or custom, can be edited,
  /// extended, cloned, hidden, or reset.
  Widget _nodeMenu(BuildContext context, WidgetRef ref) {
    final editor = CatalogEditor(ref);
    final overridden = editor.isOverridden(node.node.id);
    final builtIn = editor.isBuiltIn(node.node.id);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      tooltip: 'Edit / add / hide',
      onSelected: (value) => _onMenu(context, ref, editor, value),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        const PopupMenuItem(value: 'add', child: Text('Add sub-item')),
        const PopupMenuItem(value: 'clone', child: Text('Clone structure')),
        const PopupMenuItem(value: 'hide', child: Text('Hide / delete')),
        if (overridden)
          PopupMenuItem(
              value: 'reset',
              child: Text(builtIn ? 'Reset to default' : 'Remove permanently')),
      ],
    );
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, CatalogEditor editor,
      String action) async {
    final navigator = Navigator.of(context);
    switch (action) {
      case 'edit':
        navigator.push(MaterialPageRoute(
            builder: (_) => AddCustomNodeScreen(existing: node.node)));
      case 'add':
        navigator.push(MaterialPageRoute(
            builder: (_) => AddCustomNodeScreen(initialParentId: node.node.id)));
      case 'clone':
        await editor.cloneStructure(node.node);
      case 'hide':
        final ok = await _confirm(context,
            'Hide "${node.name}"?',
            'It is removed from the tree. Your logged progress stays intact, '
                'and you can restore it with "Reset to default".');
        if (ok) await editor.hide(node.node);
      case 'reset':
        await editor.reset(node.node.id);
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('OK')),
        ],
      ),
    );
    return ok ?? false;
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.node});
  final ProgressNode node;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: node.total == 0 ? 0 : node.learned / node.total,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${node.learned} / ${node.total}  (${node.percent.toStringAsFixed(1)}%)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
