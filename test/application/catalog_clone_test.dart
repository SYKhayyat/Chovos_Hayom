import 'package:chovos_hayom/data/repositories/in_memory_progress_repository.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

/// The clone itself, lifted out of `CatalogEditor` (which needs a `WidgetRef`)
/// so the structural rules can be asserted directly.
Future<void> cloneStructure(
  InMemoryProgressRepository repo,
  String profileId,
  Catalog catalog,
  CatalogNode root,
) async {
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
  await repo.transaction(() async {
    for (final n in all) {
      final isRoot = n.id == root.id;
      await repo.addCustomNode(
        profileId,
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
          unitNames: n.unitNames,
        ),
      );
    }
  });
}

final _catalog = Catalog(const [
  CatalogNode(
      id: 'chumash', parentId: null, name: 'Chumash', kind: NodeKind.category),
  CatalogNode(
    id: 'bereishis',
    parentId: 'chumash',
    name: 'Bereishis',
    kind: NodeKind.leaf,
    unitLabel: UnitLabel.perek,
    unitCount: 3,
    unitOffset: 1,
    unitNames: ['Bereishis', 'Noach', 'Lech Lecha'],
  ),
]);

void main() {
  test('cloning a subtree keeps its named units', () async {
    // Named units are structure, not progress. Dropping them turned a clone of
    // Chumash into a list of numbers.
    final repo = InMemoryProgressRepository();
    await cloneStructure(repo, 'p', _catalog, _catalog.byId('chumash')!);

    final nodes = await repo.watchCustomNodes('p').first;
    final leaf = nodes.firstWhere((n) => n.name == 'Bereishis');
    expect(leaf.unitNames, ['Bereishis', 'Noach', 'Lech Lecha']);
    expect(leaf.unitDisplay(2), 'Noach');
  });

  test('the clone is a fresh subtree, re-parented onto the new root', () async {
    final repo = InMemoryProgressRepository();
    await cloneStructure(repo, 'p', _catalog, _catalog.byId('chumash')!);

    final nodes = await repo.watchCustomNodes('p').first;
    final root = nodes.firstWhere((n) => n.name == 'Chumash (copy)');
    final leaf = nodes.firstWhere((n) => n.name == 'Bereishis');

    expect(nodes.map((n) => n.id), isNot(contains('chumash')));
    expect(leaf.parentId, root.id, reason: 'children point at the new root');
    expect(root.parentId, isNull, reason: 'cloned in as a sibling');
    expect(leaf.unitCount, 3);
    expect(leaf.unitOffset, 1);
  });
}
