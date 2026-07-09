import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

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

    final all = <CatalogNode>[];
    void collect(CatalogNode n) {
      all.add(n);
      for (final c in catalog.childrenOf(n.id)) {
        collect(c);
      }
    }
    collect(root);

    const uuid = Uuid();
    final newIds = {for (final n in all) n.id: uuid.v4()};
    for (final n in all) {
      final isRoot = n.id == root.id;
      await repo.addCustomNode(
        _profileId,
        CatalogNode(
          id: newIds[n.id]!,
          parentId: isRoot ? root.parentId : newIds[n.parentId],
          name: isRoot ? '${n.name} (copy)' : n.name,
          nameHebrew: n.nameHebrew,
          sortOrder: n.sortOrder,
          kind: n.kind,
          unitLabel: n.unitLabel,
          unitCount: n.unitCount,
          unitOffset: n.unitOffset,
        ),
      );
    }
  }
}
