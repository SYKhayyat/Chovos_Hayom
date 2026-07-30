import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/catalog_node.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/naming.dart';

/// Global search across every catalog + custom node by name.
class CatalogSearchDelegate extends SearchDelegate<void> {
  CatalogSearchDelegate(this.catalog);

  /// The whole merged tree, not a flat list of nodes: a result has to say *where*
  /// it is, and that answer lives in the node's ancestors. Four rows all reading
  /// "Shabbos" are four rows you cannot choose between.
  final Catalog catalog;

  List<CatalogNode> get nodes => catalog.all.toList();

  /// Every match, in catalog order.
  ///
  /// There was a `.take(50)` here with nothing to say it had happened, so a
  /// search for a common word showed fifty rows and silently dropped the rest —
  /// including, potentially, the one being looked for. A cap the user cannot see
  /// is indistinguishable from an incomplete catalog.
  ///
  /// Nothing replaces it: the whole catalog is ~312 nodes plus a profile's custom
  /// ones, the filter is one pass over a list already in memory, and the results
  /// go into a `ListView.builder`, which only ever builds the rows on screen. The
  /// cap was buying nothing and costing correctness.
  @visibleForTesting
  List<CatalogNode> matches() {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return nodes
        .where((n) =>
            n.name.toLowerCase().contains(q) ||
            (n.nameHebrew?.contains(query.trim()) ?? false))
        .toList();
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        // "Back" is whichever way the text came from.
        icon: Icon(Directionality.of(context) == TextDirection.rtl
            ? Icons.arrow_forward
            : Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) => _list(context);

  Widget _list(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final matches = this.matches();
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
        // Where it sits, then how big it is. The qualifier is derived from the
        // node's ancestors rather than read out of its name, so it is right for
        // every result — including the custom sefarim a user adds, which nobody
        // could have annotated in advance.
        final where = nodePath(l10n, catalog, node);
        final detail = [
          if (where.isNotEmpty) where,
          if (node.isLeaf) unitCount(l10n, node.unitCount, node.unitLabel),
        ].join(' · ');
        return ListTile(
          leading: Icon(node.isLeaf ? Icons.menu_book : Icons.folder_outlined),
          title: Text(nodeName(l10n, node)),
          subtitle: detail.isEmpty ? null : Text(detail),
          onTap: () => Navigator.pushNamed(
            context,
            node.isLeaf ? Routes.sefer(node.id) : Routes.category(node.id),
          ),
        );
      },
    );
  }
}
