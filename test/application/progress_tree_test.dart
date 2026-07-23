import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/domain/entities/progress_node.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/in_memory_progress_repository.dart';

ProgressNode _leaf(List<ProgressNode> forest) =>
    forest.single // root
        .children.single // shas
        .children.single // moed
        .children.single; // shabbos

void main() {
  test('appending an event reactively updates the derived progress tree', () async {
    final repo = InMemoryProgressRepository();
    final container = ProviderContainer(overrides: [
      catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
      progressRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    // Keep the derived provider (and its event-stream dependency) active.
    final sub = container.listen(progressForestProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(catalogProvider.future);
    await pumpEventQueue();

    var forest = container.read(progressForestProvider).value!;
    expect(forest.single.learned, 0, reason: 'starts empty');

    final logger = container.read(loggingServiceProvider);
    await logger.markDone('shas.moed.shabbos', 2);
    await pumpEventQueue();

    forest = container.read(progressForestProvider).value!;
    expect(_leaf(forest).learned, 1);
    expect(forest.single.learned, 1, reason: 'rolls up to the root');

    await logger.markUndone('shas.moed.shabbos', 2);
    await pumpEventQueue();

    forest = container.read(progressForestProvider).value!;
    expect(_leaf(forest).learned, 0, reason: 'undo removes it');
  });
}
