import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/data/repositories/in_memory_progress_repository.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/progress_node.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';

ProviderContainer makeContainer(InMemoryProgressRepository repo) {
  final c = ProviderContainer(overrides: [
    catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
    progressRepositoryProvider.overrideWithValue(repo),
  ]);
  return c;
}

ProgressNode? shabbos(List<ProgressNode> forest) => forest
    .firstWhere((n) => n.id == 'root')
    .children
    .single
    .children
    .single
    .children
    .single;

void main() {
  test('custom node is merged into the catalog and tracked', () async {
    final repo = InMemoryProgressRepository();
    final c = makeContainer(repo);
    addTearDown(c.dispose);
    final sub = c.listen(progressForestProvider, (_, _) {});
    addTearDown(sub.close);

    await c.read(catalogProvider.future);
    await pumpEventQueue();

    await repo.addCustomNode(
      'default',
      const CatalogNode(
        id: 'c1',
        parentId: null,
        name: 'Daily Mussar',
        kind: NodeKind.leaf,
        unitLabel: UnitLabel.custom,
        unitCount: 3,
        unitOffset: 1,
      ),
    );
    await pumpEventQueue();

    var forest = c.read(progressForestProvider).value!;
    final custom = forest.firstWhere((n) => n.id == 'c1');
    expect(custom.total, 3);
    expect(custom.learned, 0);

    await c.read(loggingServiceProvider).markDone('c1', 1);
    await pumpEventQueue();
    forest = c.read(progressForestProvider).value!;
    expect(forest.firstWhere((n) => n.id == 'c1').learned, 1);
  });

  test('switching profiles scopes the log independently', () async {
    final repo = InMemoryProgressRepository();
    final c = makeContainer(repo);
    addTearDown(c.dispose);
    final sub = c.listen(progressForestProvider, (_, _) {});
    addTearDown(sub.close);

    await c.read(catalogProvider.future);
    await c.read(profilesProvider.future); // ensures 'default' exists
    await pumpEventQueue();

    // Learn a daf in the default profile.
    await c.read(loggingServiceProvider).markDone('shas.moed.shabbos', 2);
    await pumpEventQueue();
    expect(shabbos(c.read(progressForestProvider).value!)!.learned, 1);

    // Create + switch to a new profile: its log is empty.
    await c.read(profilesProvider.notifier).create('Second');
    await pumpEventQueue();
    expect(c.read(activeProfileProvider), isNot('default'));
    expect(shabbos(c.read(progressForestProvider).value!)!.learned, 0);
  });
}
