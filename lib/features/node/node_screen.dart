import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../common/missing_item.dart';
import '../dashboard/progress_tile.dart';

/// Shows the progress subtree rooted at a single node (used by search results
/// for categories).
///
/// The title comes from the catalog rather than from whoever pushed this screen,
/// so renaming the category while it is open renames the screen too.
class NodeScreen extends ConsumerWidget {
  const NodeScreen({super.key, required this.nodeId});

  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While the catalog/log load these are still loading; once loaded, a null
    // node means the id genuinely doesn't exist — don't spin forever on it.
    final catalogReady = ref.watch(mergedCatalogProvider).hasValue;
    final eventsReady = ref.watch(eventsProvider).hasValue;
    final node = ref.watch(progressNodeProvider(nodeId));

    if (node == null) {
      return MissingItemScreen(
        loading: !catalogReady || !eventsReady,
        message: 'This item no longer exists.\n'
            'It may have been removed or renamed.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(node.name)),
      body: ListView(children: [ProgressTile(node: node)]),
    );
  }
}
