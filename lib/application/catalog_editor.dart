import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/catalog.dart';
import '../domain/entities/catalog_node.dart';
import 'providers.dart';

/// Editing operations over the merged catalog, implemented as per-profile
/// override rows so any node — built-in or custom — can be changed, hidden, or
/// restored without ever touching the bundled data.
class CatalogEditor {
  const CatalogEditor(this._ref);
  final WidgetRef _ref;

  String get _profileId => _ref.read(activeProfileProvider);

  /// True if [id] exists in the bundled catalog (so "reset" restores it rather
  /// than deleting it outright).
  bool isBuiltIn(String id) =>
      _ref.read(catalogProvider).asData?.value.byId(id) != null;

  /// True if a per-profile override/custom row exists for [id].
  bool isOverridden(String id) => (_ref.read(customNodesProvider).asData?.value ??
          const [])
      .any((n) => n.id == id);

  /// Hide a node (and its subtree) — a reversible soft-delete via an override.
  Future<void> hide(CatalogNode node) => _ref
      .read(progressRepositoryProvider)
      .addCustomNode(_profileId, node.copyWith(hidden: true));

  /// Drop the override for [id]: a built-in returns to its bundled definition; a
  /// purely-custom node is removed entirely.
  Future<void> reset(String id) =>
      _ref.read(progressRepositoryProvider).removeCustomNode(_profileId, id);

  /// Deep-copy [root]'s subtree as new custom nodes (fresh ids), placed as a
  /// sibling named "… (copy)". Progress is not copied — structure only. This is
  /// the "same structure as X" builder.
  Future<void> cloneStructure(CatalogNode root) async {
    final catalog = _ref.read(mergedCatalogProvider).asData?.value;
    if (catalog == null) return;
    final repo = _ref.read(progressRepositoryProvider);
    final nodes = cloneOf(catalog, root);

    // One transaction: a clone is either the whole subtree or nothing. Half a
    // cloned tree is worse than no clone — it leaves orphaned nodes behind.
    await repo.transaction(() async {
      for (final n in nodes) {
        await repo.addCustomNode(_profileId, n);
      }
    });
  }
}

/// The nodes a clone of [root]'s subtree consists of: fresh ids, re-parented
/// onto the new root, which is itself named "… (copy)" and keeps [root]'s
/// parent so the copy lands as a sibling.
///
/// Separate from [CatalogEditor.cloneStructure] because that method needs a
/// `WidgetRef` and this is the part with the rules in it. The test for those
/// rules used to hold its own transcription of this walk and assert against
/// *that* — which is why it could not have caught anything the real one got
/// wrong, and is finding 5's shape appearing in a test instead of in `lib/`.
///
/// [newId] is injectable so a test can read the mapping; production takes v4
/// UUIDs.
List<CatalogNode> cloneOf(
  Catalog catalog,
  CatalogNode root, {
  String Function()? newId,
}) {
  const uuid = Uuid();
  final mint = newId ?? uuid.v4;

  final all = <CatalogNode>[];
  void collect(CatalogNode n) {
    all.add(n);
    for (final c in catalog.childrenOf(n.id)) {
      collect(c);
    }
  }

  collect(root);

  final newIds = {for (final n in all) n.id: mint()};
  return [
    for (final n in all)
      CatalogNode(
        id: newIds[n.id]!,
        parentId: n.id == root.id ? root.parentId : newIds[n.parentId],
        name: n.id == root.id ? '${n.name} (copy)' : n.name,
        nameHebrew: n.nameHebrew,
        sortOrder: n.sortOrder,
        kind: n.kind,
        unitLabel: n.unitLabel,
        unitCount: n.unitCount,
        unitOffset: n.unitOffset,
        // Named units are part of the structure, not the progress. Dropping
        // them turned a clone of Chumash into a list of numbers.
        unitNames: n.unitNames,
      ),
  ];
}
