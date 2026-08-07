import 'package:flutter/material.dart';

import '../../domain/entities/catalog.dart';
import '../../domain/entities/catalog_node.dart';
import '../../l10n/generated/app_localizations.dart';
import 'naming.dart';

/// Choosing a node out of the catalog — built once, in four shapes' worth of
/// places.
///
/// There were four of these and no two agreed. Linking a cycle's sefer name
/// opened a `SimpleDialog` of leaves, sorted by localized name, clamped to
/// 320x400. Adding a segment to a cycle opened a `SimpleDialog` of everything,
/// sorted the same way, clamped to **340x420** — with a comment pointing at the
/// first one saying "see the same clamp", beside a different number. The
/// Calculator used an indented dropdown. And the node editor's *parent* dropdown
/// sorted by `a.name` — the **raw English** field, not the name the reader is
/// looking at — and did not qualify anything, so a Hebrew reader got a list
/// ordered by strings that were not on their screen, containing four rows all
/// reading "שבת" with nothing to choose between them.
///
/// That last one is the whole argument for this file. Every picker had a comment
/// explaining why its list is qualified; the one written last had neither the
/// comment nor the qualifier, because a rule stated four times is a rule nobody
/// owns.
///
/// Two presentations, deliberately. A dialog is right when a button opens it; a
/// dropdown is right inside a form. What they share is the part that was
/// actually going wrong — *which* nodes, in *what* order, under *what* label.
///
/// The one node list this does not serve is the search delegate's, and that is
/// on purpose: search navigates rather than returns, and its row splits the
/// qualifier into a subtitle beside the unit count instead of folding it into
/// the title. `node_picker_guard_test.dart` names it as the one exception, so a
/// fifth picker has to argue rather than be typed.

/// A node as a picker offers it: what it is, what it is called here, and what
/// distinguishes it from the one below it.
class NodeChoice {
  const NodeChoice({
    required this.node,
    required this.label,
    this.secondary,
    this.depth = 0,
  });

  final CatalogNode node;

  /// [qualifiedNodeName] — the node's own name plus where it sits. A flat list
  /// has no tree around it to supply that, and "Shabbos" is four different
  /// sefarim.
  final String label;

  /// The second line: how many units a leaf has, what a category will pull in,
  /// or the node's name in the *other* language.
  final String? secondary;

  /// How deep in the tree, for the dropdowns that indent rather than qualify by
  /// sorting. Always 0 in a name-ordered list, where depth would be a lie.
  final int depth;

  String get id => node.id;
}

/// How a picker's list is ordered.
enum NodeOrder {
  /// Catalog order, parents before their children, depth carried so a dropdown
  /// can indent. Right where the list is a *tree you are navigating* — picking
  /// a parent, picking what to finish.
  tree,

  /// Alphabetical by the label the reader is actually seeing. Right where the
  /// list is a *name you are matching* — linking a cycle's sefer to the catalog
  /// entry that spells it differently.
  ///
  /// By the label, not by `node.name`: sorting a Hebrew reader's list by the
  /// English field puts it in an order that has no visible explanation.
  name,
}

/// The nodes to offer, in the order to offer them.
///
/// [where] keeps a node; [exclude] drops a node **and its subtree**, which is
/// the node editor's "you may not file this under its own descendant". The two
/// are separate because they are different questions: `where` is about what
/// kind of node is pickable, `exclude` is about a region of the tree that is
/// not.
List<NodeChoice> nodeChoices(
  AppLocalizations l10n,
  Catalog catalog, {
  bool Function(CatalogNode node)? where,
  Set<String> exclude = const {},
  int maxDepth = 1 << 30,
  String? Function(AppLocalizations l10n, CatalogNode node)? secondary,
  NodeOrder order = NodeOrder.tree,
}) {
  final out = <NodeChoice>[];

  void walk(CatalogNode node, int depth) {
    if (exclude.contains(node.id)) return;
    if (where == null || where(node)) {
      out.add(NodeChoice(
        node: node,
        label: qualifiedNodeName(l10n, catalog, node),
        secondary: secondary?.call(l10n, node),
        depth: order == NodeOrder.tree ? depth : 0,
      ));
    }
    if (depth >= maxDepth) return;
    for (final child in catalog.childrenOf(node.id)) {
      walk(child, depth + 1);
    }
  }

  // From the roots down, not over `catalog.all`: [Catalog] guarantees a forest,
  // so this reaches every node exactly once *and* knows how deep each one is,
  // which a flat iteration cannot tell you.
  for (final root in catalog.roots) {
    walk(root, 0);
  }
  if (order == NodeOrder.name) {
    out.sort((a, b) => a.label.compareTo(b.label));
  }
  return out;
}

/// The second line a leaf-and-category list wants: how many units this sefer
/// has, or that picking a category takes everything underneath it.
String? nodeSizeLine(AppLocalizations l10n, CatalogNode node) => node.isLeaf
    ? unitCount(l10n, node.unitCount, node.unitLabel)
    : l10n.editCycleEverythingUnderneath;

/// The second line a leaves-only list wants: the node's name in the language the
/// title is *not* in, so a reader matching a transliteration can see both.
String? nodeOtherName(AppLocalizations l10n, CatalogNode node) {
  final primary = nodeName(l10n, node);
  final other = primary == node.name ? node.nameHebrew : node.name;
  return other == null || other == primary ? null : other;
}

/// Pick one node from [choices], in a dialog sized to the screen it is on.
///
/// The clamp is the whole reason this is not four `SimpleDialog`s. A fixed 320
/// is wider than the entire 240dp Sonim display, and a dialog wider than the
/// screen is one whose trailing edge — where a row's chevron and the end of a
/// long name live — cannot be seen at all. The 80/160 leave room for the
/// dialog's own insets and its title; the upper bounds are what the widest of
/// the two old copies used, since a picker that fits on a phone should not be
/// cramped on a desktop.
Future<CatalogNode?> showNodePicker(
  BuildContext context, {
  required String title,
  required List<NodeChoice> choices,
  bool showKindIcon = false,
}) {
  return showDialog<CatalogNode>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(title),
      children: [
        SizedBox(
          width: (MediaQuery.sizeOf(context).width - 80).clamp(200.0, 340.0),
          height: (MediaQuery.sizeOf(context).height - 160).clamp(200.0, 420.0),
          child: ListView.builder(
            itemCount: choices.length,
            itemBuilder: (_, i) {
              final choice = choices[i];
              return ListTile(
                leading: showKindIcon
                    ? Icon(choice.node.isLeaf ? Icons.menu_book : Icons.folder)
                    : null,
                title: Text(choice.label),
                subtitle:
                    choice.secondary == null ? null : Text(choice.secondary!),
                onTap: () => Navigator.pop(dialogContext, choice.node),
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// Pick one node from [choices] inside a form.
///
/// A closed dropdown shows one line with no indentation and no neighbours, so
/// the label has to carry the qualifier on its own; the indentation still
/// carries the tree while the list is open. [noneLabel], when given, adds a null
/// entry at the top — the node editor's "top level", which is a real answer and
/// not an absence.
class NodeDropdown extends StatelessWidget {
  const NodeDropdown({
    super.key,
    required this.label,
    required this.choices,
    required this.value,
    required this.onChanged,
    this.noneLabel,
  });

  final String label;
  final List<NodeChoice> choices;

  /// The selected node's id, or null for [noneLabel].
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? noneLabel;

  @override
  Widget build(BuildContext context) {
    final known = choices.any((c) => c.id == value);
    return DropdownButtonFormField<String?>(
      // A value the list does not contain throws; falling back to the none
      // entry (or the first row) is what makes a re-parent that excluded the
      // current parent survive being reopened.
      initialValue: known ? value : (noneLabel != null ? null : choices.first.id),
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        if (noneLabel != null)
          DropdownMenuItem(value: null, child: Text(noneLabel!)),
        for (final choice in choices)
          DropdownMenuItem(
            value: choice.id,
            child: Text('${'   ' * choice.depth}${choice.label}',
                overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
