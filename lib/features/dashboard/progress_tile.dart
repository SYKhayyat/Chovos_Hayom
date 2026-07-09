import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/progress_node.dart';
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
    final isCustom = customIds.contains(node.node.id);

    if (node.node.isLeaf) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: indent, right: 8),
        title: Text(node.name),
        subtitle: _ProgressBar(node: node),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCustom) _deleteButton(context, ref),
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
      trailing: isCustom
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [_deleteButton(context, ref), const Icon(Icons.expand_more)],
            )
          : null,
      childrenPadding: EdgeInsets.zero,
      children: [
        for (final child in node.children)
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

  Widget _deleteButton(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.delete_outline, size: 20),
      tooltip: 'Delete custom sefer',
      onPressed: () => _confirmDelete(context, ref),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${node.name}"?'),
        content: const Text(
            'This removes the custom sefer. Your logged progress for it stays '
            'in the history but will no longer be shown.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final profileId = ref.read(activeProfileProvider);
    await ref
        .read(progressRepositoryProvider)
        .removeCustomNode(profileId, node.node.id);
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
