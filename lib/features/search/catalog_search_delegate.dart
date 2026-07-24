import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../domain/entities/catalog_node.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/naming.dart';

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
    final l10n = AppLocalizations.of(context);
    final matches = _matches();
    if (query.trim().isEmpty) {
      return Center(child: Text(l10n.searchPrompt));
    }
    if (matches.isEmpty) {
      return Center(child: Text(l10n.searchNoMatches));
    }
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, i) {
        final node = matches[i];
        return ListTile(
          leading: Icon(node.isLeaf ? Icons.menu_book : Icons.folder_outlined),
          title: Text(nodeName(l10n, node)),
          subtitle: node.isLeaf
              ? Text(unitCount(l10n, node.unitCount, node.unitLabel))
              : null,
          onTap: () => Navigator.pushNamed(
            context,
            node.isLeaf ? Routes.sefer(node.id) : Routes.category(node.id),
          ),
        );
      },
    );
  }
}
