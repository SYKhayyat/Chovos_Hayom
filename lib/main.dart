import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/providers.dart';
import 'domain/entities/progress_node.dart';

void main() {
  runApp(const ProviderScope(child: ChovosHayomApp()));
}

class ChovosHayomApp extends StatelessWidget {
  const ChovosHayomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chovos Hayom',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3B5BA5),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forest = ref.watch(progressForestProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chovos Hayom')),
      body: forest.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (nodes) => ListView(
          children: [for (final n in nodes) ProgressTile(node: n)],
        ),
      ),
    );
  }
}

/// Recursive expandable tree row with a progress bar. Leaves get a "mark next
/// daf" button (a placeholder for Phase 1's per-unit grid).
class ProgressTile extends ConsumerWidget {
  const ProgressTile({super.key, required this.node, this.depth = 0});

  final ProgressNode node;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = _ProgressBar(node: node);

    if (node.node.isLeaf) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: 16.0 + depth * 16, right: 16),
        title: Text(node.name),
        subtitle: subtitle,
        trailing: node.isComplete
            ? const Icon(Icons.check_circle, color: Colors.green)
            : IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Mark next ${node.node.unitLabel?.name ?? 'unit'}',
                onPressed: () => ref.read(loggingServiceProvider).markDone(
                      node.id,
                      node.node.unitOffset + node.learned,
                    ),
              ),
      );
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.only(left: 16.0 + depth * 16, right: 16),
      title: Text(node.name),
      subtitle: subtitle,
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
          LinearProgressIndicator(
              value: node.total == 0 ? 0 : node.learned / node.total),
          const SizedBox(height: 2),
          Text(
              '${node.learned} / ${node.total}  (${node.percent.toStringAsFixed(1)}%)',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
