import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/layer_roles.dart';

import '../support/layer_roles_dsl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_progress_repository.dart';

LearningEvent ev(String id, {String profile = 'a'}) => LearningEvent(
      id: id,
      profileId: profile,
      nodeId: 'shas.moed.shabbos',
      unitIndex: 2,
      action: EventAction.done,
      occurredAt: DateTime(2026, 1, 1),
      loggedAt: DateTime(2026, 1, 1),
      durationMin: 30,
      note: 'with Rashi',
    );

void main() {
  test('export then import reproduces the log in a fresh profile', () async {
    final source = InMemoryProgressRepository();
    await source.addEvent(ev('e1'));
    await source.addEvent(ev('e2'));
    await source.addCustomNode(
      'a',
      const CatalogNode(
        id: 'custom1',
        parentId: null,
        name: 'My Sefer',
        kind: NodeKind.leaf,
        unitLabel: UnitLabel.perek,
        unitCount: 5,
        unitOffset: 1,
      ),
    );

    final json = await BackupService(source).export('a', customNodes: const [
      CatalogNode(
        id: 'custom1',
        parentId: null,
        name: 'My Sefer',
        kind: NodeKind.leaf,
        unitLabel: UnitLabel.perek,
        unitCount: 5,
        unitOffset: 1,
      ),
    ]);

    final target = InMemoryProgressRepository();
    final result = await BackupService(target).importInto('b', json);

    expect(result.events.length, 2);
    final events = await target.getEvents('b');
    expect(events.map((e) => e.id).toSet(), {'e1', 'e2'});
    expect(events.every((e) => e.profileId == 'b'), isTrue, reason: 're-scoped');
    expect(events.first.note, 'with Rashi');
    // Custom sefer travels with the backup.
    final nodes = await target.watchCustomNodes('b').first;
    expect(nodes.map((n) => n.id), contains('custom1'));
  });

  test('re-import is idempotent (dedup by id)', () async {
    final source = InMemoryProgressRepository();
    await source.addEvent(ev('e1'));
    final json = await BackupService(source).export('a', customNodes: const []);

    final target = InMemoryProgressRepository();
    await BackupService(target).importInto('b', json);
    final addedAgain = await BackupService(target).importInto('b', json);

    expect(addedAgain.events, isEmpty);
    expect(await target.getEvents('b'), hasLength(1));
  });

  test('backup round-trips mefarshim, required sets, settings, and layers',
      () async {
    final source = InMemoryProgressRepository();
    await source.addEvent(LearningEvent(
      id: 'e1',
      profileId: 'a',
      nodeId: 'shas.moed.shabbos',
      unitIndex: 2,
      action: EventAction.done,
      occurredAt: DateTime(2026, 1, 1),
      loggedAt: DateTime(2026, 1, 1),
      note: 'nice chiddush',
      layers: const ['main', 'rashi'],
    ));
    await source.addCustomLayer(
        'a', const Layer(id: 'my-meforish', name: 'My Meforish'));

    final json = await BackupService(source).export(
      'a',
      customNodes: const [],
      customLayers: const [Layer(id: 'my-meforish', name: 'My Meforish')],
      layerConfigs: [
        LayerConfigEntry(
            nodeId: 'shas',
            unitIndex: -1,
            roles: roles(required: ['main', 'rashi'], optional: ['maharsha'])),
      ],
      settings: const {'chazaraIntervals': '2,4,8'},
    );

    final target = InMemoryProgressRepository();
    final result = await BackupService(target).importInto('b', json);

    // Event keeps its haara + layers.
    final events = await target.getEvents('b');
    expect(events.single.note, 'nice chiddush');
    expect(events.single.layers, ['main', 'rashi']);
    // Custom meforish, layer settings, and settings all came across.
    expect((await target.watchCustomLayers('b').first).map((l) => l.id),
        contains('my-meforish'));
    final configs = await target.watchLayerConfigs('b').first;
    // One entry, and each layer keeps the role it was exported with — an
    // optional meforish must not come back required, or units the user had
    // finished go incomplete on restore.
    expect(configs.single.required, {'main', 'rashi'});
    expect(configs.single.checkable, {'main', 'rashi', 'maharsha'});
    expect(result.settings['chazaraIntervals'], '2,4,8');
  });
}
