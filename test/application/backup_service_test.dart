import 'dart:convert';

import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/layer_roles.dart';

import '../support/layer_roles_dsl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_database.dart';

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
    final source = memoryRepository();
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

    // The export reads the profile's own rows rather than being handed a list
    // — which is the point: a caller that could pass a *different* list is a
    // caller that could pass an empty one.
    final json = await BackupService(source).export('a');

    final target = memoryRepository();
    final result = await BackupService(target).importInto('b', BackupService.parse(json));

    expect(result.events.length, 2);
    final events = await target.getEvents('b');
    expect(events.map((e) => e.id).toSet(), {'e1', 'e2'});
    expect(events.every((e) => e.profileId == 'b'), isTrue, reason: 're-scoped');
    expect(events.first.note, 'with Rashi');
    // Custom sefer travels with the backup.
    final nodes = await target.getCustomNodes('b');
    expect(nodes.map((n) => n.id), contains('custom1'));
  });

  test('re-import is idempotent (dedup by id)', () async {
    final source = memoryRepository();
    await source.addEvent(ev('e1'));
    final json = await BackupService(source).export('a');

    final target = memoryRepository();
    await BackupService(target).importInto('b', BackupService.parse(json));
    final addedAgain = await BackupService(target).importInto('b', BackupService.parse(json));

    expect(addedAgain.events, isEmpty);
    expect(await target.getEvents('b'), hasLength(1));
  });

  test('backup round-trips mefarshim, required sets, settings, and layers',
      () async {
    final source = memoryRepository();
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

    await source.setLayerConfig(
      'a',
      LayerConfigEntry(
          nodeId: 'shas',
          roles: roles(required: ['main', 'rashi'], optional: ['maharsha'])),
    );

    final json = await BackupService(source).export(
      'a',
      settings: const {'chazaraIntervals': '2,4,8'},
    );

    final target = memoryRepository();
    final result = await BackupService(target).importInto('b', BackupService.parse(json));

    // Event keeps its haara + layers.
    final events = await target.getEvents('b');
    expect(events.single.note, 'nice chiddush');
    expect(events.single.layers, ['main', 'rashi']);
    // Custom meforish, layer settings, and settings all came across.
    expect((await target.getCustomLayers('b')).map((l) => l.id),
        contains('my-meforish'));
    final configs = await target.getLayerConfigs('b');
    // One entry, and each layer keeps the role it was exported with — an
    // optional meforish must not come back required, or units the user had
    // finished go incomplete on restore.
    expect(configs.single.required, {'main', 'rashi'});
    expect(configs.single.checkable, {'main', 'rashi', 'maharsha'});
    expect(result.settings['chazaraIntervals'], '2,4,8');
  });

  group('a layer setting pinned to one unit', () {
    // The import half of schema v2. No backup this app has ever written holds
    // one — the config sheet opens from a node and always wrote -1 — so this is
    // about a hand-edited file, where the choice is between dropping the entry
    // and promoting one unit's answer to cover its whole node. Dropping it
    // changes less.
    String fileWith(String layerConfigs) => jsonEncode({
          'version': 5,
          'events': const [],
          'customNodes': const [],
          'layerConfigs': jsonDecode(layerConfigs),
        });

    test('is dropped, and its node-level neighbour is not', () {
      final data = BackupService.parse(fileWith('''
        [
          {"nodeId": "shas", "unitIndex": -1, "roles": {"main": "required"}},
          {"nodeId": "shas", "unitIndex": 7, "roles": {"rashi": "required"}}
        ]'''));

      expect(data.layerConfigs.single.nodeId, 'shas');
      expect(data.layerConfigs.single.roles, {'main': LayerRole.required});
    });

    test('does not take its node with it when it stands alone', () {
      final data = BackupService.parse(fileWith(
          '[{"nodeId": "shas", "unitIndex": 7, "roles": {"rashi": "required"}}]'));

      expect(data.layerConfigs, isEmpty,
          reason: 'the node keeps whatever it inherits, rather than being '
              'pinned to what one of its units said');
    });

    test('the same in a pre-v5 file, where membership was the meaning', () {
      final data = BackupService.parse(jsonEncode({
        'version': 4,
        'events': const [],
        'customNodes': const [],
        'requirements': [
          {'nodeId': 'shas', 'unitIndex': -1, 'layers': ['main']},
          {'nodeId': 'shas', 'unitIndex': 7, 'layers': ['rashi']},
        ],
      }));

      expect(data.layerConfigs.single.roles, {'main': LayerRole.required});
    });
  });
}
