import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/usecases/layer_requirements.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_progress_repository.dart';

/// The cleanup a meforish deletion performs, exercised at the repository level
/// (the sheet is the UI over exactly these writes).
///
/// Deleting used to remove only the `CustomLayers` row, leaving its id behind in
/// every required- and offered-layer setting. Anything that *required* it then
/// became uncompletable: the unit checklist could only offer a checkbox labelled
/// with a raw UUID.
Future<void> deleteMeforish(
  InMemoryProgressRepository repo,
  String profileId,
  String layerId,
) async {
  final requirements = await repo.watchLayerRequirements(profileId).first;
  final offered = await repo.watchOfferedLayers(profileId).first;

  await repo.transaction(() async {
    for (final e in requirements) {
      if (!e.layers.contains(layerId)) continue;
      final remaining = {...e.layers}..remove(layerId);
      if (remaining.isEmpty) {
        await repo.clearLayerRequirement(profileId, e.nodeId, e.unitIndex);
      } else {
        await repo.setLayerRequirement(
            profileId,
            LayerConfigEntry(
                nodeId: e.nodeId, unitIndex: e.unitIndex, layers: remaining));
      }
    }
    for (final e in offered) {
      if (!e.layers.contains(layerId)) continue;
      final remaining = {...e.layers}..remove(layerId);
      if (remaining.isEmpty) {
        await repo.clearOfferedLayers(profileId, e.nodeId, e.unitIndex);
      } else {
        await repo.setOfferedLayers(
            profileId,
            LayerConfigEntry(
                nodeId: e.nodeId, unitIndex: e.unitIndex, layers: remaining));
      }
    }
    await repo.removeCustomLayer(profileId, layerId);
  });
}

void main() {
  late InMemoryProgressRepository repo;

  setUp(() async {
    repo = InMemoryProgressRepository();
    await repo.addCustomLayer('p', const Layer(id: 'mine', name: 'My Meforish'));
  });

  test('deleting a meforish drops it from every required setting', () async {
    await repo.setLayerRequirement(
        'p',
        const LayerConfigEntry(
            nodeId: 'shas', unitIndex: -1, layers: {'main', 'mine'}));

    await deleteMeforish(repo, 'p', 'mine');

    final reqs = await repo.watchLayerRequirements('p').first;
    expect(reqs.single.layers, {'main'},
        reason: 'units gated on it must not become uncompletable');
    expect(await repo.watchCustomLayers('p').first, isEmpty);
  });

  test('a setting that held only that meforish is cleared, not left empty',
      () async {
    // An empty pinned set would mean "requires nothing" rather than "inherits",
    // which is a different answer.
    await repo.setLayerRequirement('p',
        const LayerConfigEntry(nodeId: 'shas', unitIndex: -1, layers: {'mine'}));

    await deleteMeforish(repo, 'p', 'mine');

    expect(await repo.watchLayerRequirements('p').first, isEmpty);
  });

  test('offered settings are cleaned up the same way', () async {
    await repo.setOfferedLayers(
        'p',
        const LayerConfigEntry(
            nodeId: 'shas', unitIndex: -1, layers: {'main', 'rashi', 'mine'}));

    await deleteMeforish(repo, 'p', 'mine');

    final offered = await repo.watchOfferedLayers('p').first;
    expect(offered.single.layers, {'main', 'rashi'});
  });

  test('per-unit overrides are cleaned up too, not just node-level ones',
      () async {
    await repo.setLayerRequirement(
        'p',
        const LayerConfigEntry(
            nodeId: 'shas.moed.shabbos', unitIndex: 7, layers: {'main', 'mine'}));

    await deleteMeforish(repo, 'p', 'mine');

    final reqs = await repo.watchLayerRequirements('p').first;
    expect(reqs.single.unitIndex, 7);
    expect(reqs.single.layers, {'main'});
  });

  test('settings naming other mefarshim are untouched', () async {
    await repo.setLayerRequirement('p',
        const LayerConfigEntry(nodeId: 'nach', unitIndex: -1, layers: {'main'}));
    await repo.setLayerRequirement(
        'p',
        const LayerConfigEntry(
            nodeId: 'shas', unitIndex: -1, layers: {'main', 'mine'}));

    await deleteMeforish(repo, 'p', 'mine');

    final reqs = await repo.watchLayerRequirements('p').first;
    expect(reqs.length, 2);
    expect(reqs.firstWhere((e) => e.nodeId == 'nach').layers, {'main'});
  });
}
