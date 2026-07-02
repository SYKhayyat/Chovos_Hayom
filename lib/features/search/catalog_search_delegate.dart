import 'package:flutter/material.dart';

import '../../domain/entities/catalog_node.dart';
import '../node/node_screen.dart';
import '../unit_grid/unit_grid_screen.dart';

/// Global search across every catalog + custom node by name.
class CatalogSearchDelegate extends SearchDelegate<void> {
  CatalogSearchDelegate(this.nodes);

  final List<CatalogNode> nodes;

  List<CatalogNode> _matches() {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return nodes
        .where((n) =>
            n.name.toLowerCase().contains(q) ||
            (n.nameHebrew?.contains(query.trim()) ?? false))
        .take(50)
        .toList();
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) => _list(context);

  Widget _list(BuildContext context) {
    final matches = _matches();
    if (query.trim().isEmpty) {
      return const Center(child: Text('Search sefarim, mesechtos, dafim…'));
    }
    if (matches.isEmpty) {
      return const Center(child: Text('No matches.'));
    }
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, i) {
        final node = matches[i];
        return ListTile(
          leading: Icon(node.isLeaf ? Icons.menu_book : Icons.folder_outlined),
          title: Text(node.name),
          subtitle: node.isLeaf
              ? Text('${node.unitCount} ${node.unitLabel?.name ?? 'units'}')
              : null,
          onTap: () {
            final route = MaterialPageRoute<void>(
              builder: (_) => node.isLeaf
                  ? UnitGridScreen(node: node)
                  : NodeScreen(nodeId: node.id, title: node.name),
            );
            Navigator.of(context).push(route);
          },
        );
      },
    );
  }
}
