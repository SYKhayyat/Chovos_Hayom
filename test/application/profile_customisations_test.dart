import 'dart:convert';
import 'dart:io';

import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/application/profile_customisations.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/usecases/layer_roles.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_database.dart';
import '../support/source_scan.dart';

/// The three collections a profile *makes* are read as one thing, from the
/// repository, in one place.
///
/// The duplication is the finding; where the copies read *from* is why it
/// mattered. All three used to come off providers as
/// `.asData?.value ?? const []`, and a provider still in flight reads as an
/// empty list — which is invisible in a list and a silent lie in a decision. A
/// backup that leaves out your custom sefarim and says "Saved backup"; a clear
/// that removes nothing and reports success.
void main() {
  const profile = 'p1';

  const sefer = CatalogNode(
    id: 'custom.mine',
    parentId: null,
    name: 'My Sefer',
    kind: NodeKind.leaf,
    unitLabel: UnitLabel.perek,
    unitCount: 5,
    unitOffset: 1,
  );
  const meforish = Layer(id: 'my-meforish', name: 'My Meforish');
  const config = LayerConfigEntry(
    nodeId: 'custom.mine',
    unitIndex: -1,
    roles: {mainLayerId: LayerRole.required, 'my-meforish': LayerRole.optional},
  );

  test('reads all three, and counts them together', () async {
    final repo = memoryRepository();
    await repo.addCustomNode(profile, sefer);
    await repo.addCustomLayer(profile, meforish);
    await repo.setLayerConfig(profile, config);

    final made = await ProfileCustomisations.of(repo, profile);

    expect(made.nodes.single.id, 'custom.mine');
    expect(made.layers.single.id, 'my-meforish');
    expect(made.configs.single.nodeId, 'custom.mine');
    expect(made.count, 3);
    expect(made.isEmpty, isFalse);
  });

  test('a profile that has made nothing is empty rather than absent', () async {
    final made = await ProfileCustomisations.of(memoryRepository(), profile);
    expect(made.count, 0);
    expect(made.isEmpty, isTrue);
  });

  test('it reads one profile, not the device', () async {
    final repo = memoryRepository();
    await repo.addCustomNode(profile, sefer);
    await repo.addCustomLayer('someone-else', meforish);

    final made = await ProfileCustomisations.of(repo, profile);
    expect(made.nodes, hasLength(1));
    expect(made.layers, isEmpty);
  });

  test('the export carries what the profile has, with nothing to pass in',
      () async {
    // The whole point of the parameters going away. There is no list to hand
    // over, so there is no empty one to hand over by accident.
    final repo = memoryRepository();
    await repo.addCustomNode(profile, sefer);
    await repo.addCustomLayer(profile, meforish);
    await repo.setLayerConfig(profile, config);

    final json =
        jsonDecode(await BackupService(repo).export(profile)) as Map;

    List<Map<String, dynamic>> rows(String field) =>
        (json[field] as List).cast<Map<String, dynamic>>();

    expect(rows('customNodes').single['id'], 'custom.mine');
    expect(rows('customLayers').single['id'], 'my-meforish');
    expect(rows('layerConfigs').single['nodeId'], 'custom.mine');
  });

  /// And the rule, rather than the three sites that currently obey it.
  test('nothing reads the three collections as a hand-written triple', () {
    const escapeHatch = 'customisations: ok';
    const home = 'lib/application/profile_customisations.dart';
    // The repository defines them, so it is not reading them.
    const definitions = {
      'lib/domain/repositories/progress_repository.dart',
      'lib/data/repositories/drift_progress_repository.dart',
    };
    const getters = [
      r'getCustomNodes\(',
      r'getCustomLayers\(',
      r'getLayerConfigs\(',
    ];

    for (final g in getters) {
      expect(RegExp(g).hasMatch('await repo.${g.replaceAll(r'\(', '(')}p)'),
          isTrue,
          reason: 'the pattern for $g no longer matches its own sample');
    }

    final violations = <String>[];
    for (final path in dartSourcesUnder()) {
      if (path == home || definitions.contains(path)) continue;
      final lines =
          codeLines(File(path).readAsStringSync(), escapeHatch: escapeHatch);
      final source = lines.map((l) => l.text).join('\n');
      final used = getters.where((g) => RegExp(g).hasMatch(source)).toList();
      // One or two of them is a different question — the meforish delete asks
      // which configs name a layer, the restore preview asks what the roles are
      // now. All three together is "everything this profile has made", and that
      // has a reader.
      if (used.length == getters.length) violations.add(path);
    }

    expect(violations, isEmpty,
        reason: 'read them through ProfileCustomisations.of, which goes to the '
            'repository rather than to whatever happens to be cached:\n'
            '${violations.join('\n')}');
  });
}
