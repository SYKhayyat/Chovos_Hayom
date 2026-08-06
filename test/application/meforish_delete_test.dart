import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/usecases/layer_roles.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_database.dart';
import '../support/layer_roles_dsl.dart';

/// The cleanup a meforish deletion performs, exercised at the repository level
/// (the sheet is the UI over exactly these writes).
///
/// Deleting used to remove only the `CustomLayers` row, leaving its id behind in
/// every layer setting. Anything that *required* it then became uncompletable:
/// the unit checklist could only offer a checkbox labelled with a raw UUID.
///
/// This walked two lists and re-derived "rewrite or clear?" itself, which is the
/// decision the sheet also made and could drift from. Both now go through
/// [LayerConfigEntry.without], so this loop tests the branch the app takes
/// rather than a copy of it.
Future<void> deleteMeforish(
  ProgressRepository repo,
  String profileId,
  String layerId,
) async {
  final configs = await repo.getLayerConfigs(profileId);
  await repo.transaction(() async {
    for (final e in configs) {
      if (!e.roles.containsKey(layerId)) continue;
      final remaining = e.without(layerId);
      if (remaining == null) {
        await repo.clearLayerConfig(profileId, e.nodeId, e.unitIndex);
      } else {
        await repo.setLayerConfig(profileId, remaining);
      }
    }
    await repo.removeCustomLayer(profileId, layerId);
  });
}

void main() {
  late ProgressRepository repo;

  setUp(() async {
    repo = memoryRepository();
    await repo.addCustomLayer('p', const Layer(id: 'mine', name: 'My Meforish'));
  });

  test('deleting a meforish drops it from every required setting', () async {
    await repo.setLayerConfig(
        'p',
        LayerConfigEntry(
            nodeId: 'shas',
            unitIndex: -1,
            roles: roles(required: ['main', 'mine'])));

    await deleteMeforish(repo, 'p', 'mine');

    final configs = await repo.getLayerConfigs('p');
    expect(configs.single.required, {'main'},
        reason: 'units gated on it must not become uncompletable');
    expect(await repo.getCustomLayers('p'), isEmpty);
  });

  test('a setting that held only that meforish is cleared, not left empty',
      () async {
    // An empty pinned map would mean "requires nothing" rather than "inherits",
    // which is a different answer.
    await repo.setLayerConfig(
        'p',
        LayerConfigEntry(
            nodeId: 'shas', unitIndex: -1, roles: roles(required: ['mine'])));

    await deleteMeforish(repo, 'p', 'mine');

    expect(await repo.getLayerConfigs('p'), isEmpty);
  });

  test('an optional role is cleaned up the same way as a required one', () async {
    await repo.setLayerConfig(
        'p',
        LayerConfigEntry(
            nodeId: 'shas',
            unitIndex: -1,
            roles: roles(required: ['main'], optional: ['rashi', 'mine'])));

    await deleteMeforish(repo, 'p', 'mine');

    final configs = await repo.getLayerConfigs('p');
    expect(configs.single.checkable, {'main', 'rashi'});
    expect(configs.single.roles['rashi'], LayerRole.optional,
        reason: 'the surviving roles keep their meaning, not just their ids');
  });

  test('one scope is rewritten or cleared, never half of each', () async {
    // The two-table model could clear the required row (its last id was this
    // meforish) while rewriting the offered one, leaving the node inheriting its
    // requirements from an ancestor and pinning its offers here. One entry has
    // one outcome.
    await repo.setLayerConfig(
        'p',
        LayerConfigEntry(
            nodeId: 'shas',
            unitIndex: -1,
            roles: roles(required: ['mine'], optional: ['main'])));

    await deleteMeforish(repo, 'p', 'mine');

    final configs = await repo.getLayerConfigs('p');
    expect(configs.single.roles, {'main': LayerRole.optional});
    expect(configs.single.required, isEmpty);
  });

  test('per-unit overrides are cleaned up too, not just node-level ones',
      () async {
    await repo.setLayerConfig(
        'p',
        LayerConfigEntry(
            nodeId: 'shas.moed.shabbos',
            unitIndex: 7,
            roles: roles(required: ['main', 'mine'])));

    await deleteMeforish(repo, 'p', 'mine');

    final configs = await repo.getLayerConfigs('p');
    expect(configs.single.unitIndex, 7);
    expect(configs.single.required, {'main'});
  });

  test('settings naming other mefarshim are untouched', () async {
    await repo.setLayerConfig(
        'p',
        LayerConfigEntry(
            nodeId: 'nach', unitIndex: -1, roles: roles(required: ['main'])));
    await repo.setLayerConfig(
        'p',
        LayerConfigEntry(
            nodeId: 'shas',
            unitIndex: -1,
            roles: roles(required: ['main', 'mine'])));

    await deleteMeforish(repo, 'p', 'mine');

    final configs = await repo.getLayerConfigs('p');
    expect(configs.length, 2);
    expect(configs.firstWhere((e) => e.nodeId == 'nach').required, {'main'});
  });
}
