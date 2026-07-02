import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import 'progress_tile.dart';

/// The main dashboard: an expandable tree of the whole catalog with per-node
/// progress bars. Tapping a leaf opens its per-unit grid.
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
          padding: const EdgeInsets.only(bottom: 24),
          children: [for (final n in nodes) ProgressTile(node: n)],
        ),
      ),
    );
  }
}
