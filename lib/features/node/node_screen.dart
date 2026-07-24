import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/missing_item.dart';
import '../common/naming.dart';
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
    final l10n = AppLocalizations.of(context);

    if (node == null) {
      return MissingItemScreen(
        loading: !catalogReady || !eventsReady,
        message: l10n.itemMissingRenamed,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(nodeName(l10n, node.node))),
      body: ListView(children: [ProgressTile(node: node)]),
    );
  }
}
