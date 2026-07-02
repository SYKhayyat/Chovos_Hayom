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
    final node = ref.watch(progressNodeProvider(nodeId));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: node == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(children: [ProgressTile(node: node)]),
    );
  }
}
