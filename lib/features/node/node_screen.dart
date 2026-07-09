import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../dashboard/progress_tile.dart';

/// Shows the progress subtree rooted at a single node (used by search results
/// for categories).
class NodeScreen extends ConsumerWidget {
  const NodeScreen({super.key, required this.nodeId, required this.title});

  final String nodeId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While the catalog/log load these are still loading; once loaded, a null
    // node means the id genuinely doesn't exist — don't spin forever on it.
    final catalogReady = ref.watch(mergedCatalogProvider).hasValue;
    final eventsReady = ref.watch(eventsProvider).hasValue;
    final node = ref.watch(progressNodeProvider(nodeId));

    final Widget body;
    if (!catalogReady || !eventsReady) {
      body = const Center(child: CircularProgressIndicator());
    } else if (node == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'This item no longer exists.\nIt may have been removed or renamed.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    } else {
      body = ListView(children: [ProgressTile(node: node)]);
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}
