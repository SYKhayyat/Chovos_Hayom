import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/in_memory_progress_repository.dart';

ProviderContainer makeContainer(InMemoryProgressRepository repo) =>
    ProviderContainer(overrides: [
      catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
      progressRepositoryProvider.overrideWithValue(repo),
    ]);

void main() {
  test('a same-id custom row overrides a built-in node in place', () async {
    final repo = InMemoryProgressRepository();
    final c = makeContainer(repo);
    addTearDown(c.dispose);
    final sub = c.listen(mergedCatalogProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(catalogProvider.future);
    await pumpEventQueue();

    await repo.addCustomNode(
      'default',
      const CatalogNode(
        id: 'shas.moed.shabbos',
        parentId: 'shas.moed',
        name: 'Shabbos (renamed)',
        kind: NodeKind.leaf,
        unitLabel: UnitLabel.daf,
        unitCount: 200,
        unitOffset: 2,
      ),
    );
    await pumpEventQueue();

    final node = c.read(mergedCatalogProvider).value!.byId('shas.moed.shabbos')!;
    expect(node.name, 'Shabbos (renamed)');
    expect(node.unitCount, 200);
    // Not duplicated.
    expect(
      c.read(mergedCatalogProvider).value!.all.where((n) => n.id == 'shas.moed.shabbos'),
      hasLength(1),
    );
  });

  test('a hidden override removes the node and its subtree', () async {
    final repo = InMemoryProgressRepository();
    final c = makeContainer(repo);
    addTearDown(c.dispose);
    final sub = c.listen(mergedCatalogProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(catalogProvider.future);
    await pumpEventQueue();

    // Hide the whole 'shas' subtree.
    await repo.addCustomNode(
      'default',
      const CatalogNode(
        id: 'shas',
        parentId: 'root',
        name: 'Shas',
        kind: NodeKind.category,
        hidden: true,
      ),
    );
    await pumpEventQueue();

    final ids = c.read(mergedCatalogProvider).value!.all.map((n) => n.id).toSet();
    expect(ids.contains('shas'), isFalse);
    expect(ids.contains('shas.moed'), isFalse); // cascaded
    expect(ids.contains('shas.moed.shabbos'), isFalse); // cascaded
    expect(ids.contains('root'), isTrue);
  });
}
