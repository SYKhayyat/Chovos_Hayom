import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/progress_node.dart';
import '../unit_grid/unit_grid_screen.dart';

/// Recursive expandable tree row with a progress bar. Leaves navigate to their
/// per-unit grid; categories expand to reveal children.
class ProgressTile extends ConsumerWidget {
  const ProgressTile({super.key, required this.node, this.depth = 0});

  final ProgressNode node;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indent = 16.0 + depth * 16;

    if (node.node.isLeaf) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: indent, right: 16),
        title: Text(node.name),
        subtitle: _ProgressBar(node: node),
        trailing: node.isComplete
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => UnitGridScreen(node: node.node)),
        ),
      );
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.only(left: indent, right: 16),
      title: Text(node.name),
      subtitle: _ProgressBar(node: node),
      childrenPadding: EdgeInsets.zero,
      children: [
        for (final child in node.children)
          ProgressTile(node: child, depth: depth + 1),
      ],
    );
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
