import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_progress_repository.dart';
import 'dart:convert';

/// A valid backup body, so each test can corrupt exactly one thing.
Map<String, dynamic> backup({
  List<Map<String, dynamic>> nodes = const [],
  List<Map<String, dynamic>> events = const [],
  Map<String, dynamic> goals = const {},
}) =>
    {
      'version': BackupService.currentVersion,
      'events': events,
      'customNodes': nodes,
      'goals': goals,
    };

Map<String, dynamic> node(
  String id, {
  String? parentId,
  int unitCount = 5,
  int unitOffset = 1,
  List<String> unitNames = const [],
}) =>
    {
      'id': id,
      'parentId': parentId,
      'name': 'Sefer $id',
      'kind': 'leaf',
      'unitLabel': 'perek',
      'unitCount': unitCount,
      'unitOffset': unitOffset,
      'unitNames': unitNames,
    };

Map<String, dynamic> event(String id, {int unitIndex = 2}) => {
      'id': id,
      'profileId': 'a',
      'nodeId': 'shas.moed.shabbos',
      'unitIndex': unitIndex,
      'action': 'done',
      'occurredAt': '2026-01-01T00:00:00.000',
      'loggedAt': '2026-01-01T00:00:00.000',
    };

Future<void> expectRejected(String json, Matcher messageMatcher) async {
  final repo = InMemoryProgressRepository();
  await expectLater(
    BackupService(repo).importInto('b', json),
    throwsA(isA<BackupFormatException>()
        .having((e) => e.message, 'message', messageMatcher)),
  );
  // Nothing may be left behind by a rejected import.
  expect(await repo.getEvents('b'), isEmpty);
  expect(await repo.watchCustomNodes('b').first, isEmpty);
}

void main() {
  group('import rejects data that would corrupt the app', () {
    test('a negative unit count', () async {
      await expectRejected(
        jsonEncode(backup(nodes: [node('bad', unitCount: -3)])),
        contains('negative unit count'),
      );
    });

    test('an absurd unit count that would hang the grid', () async {
      await expectRejected(
        jsonEncode(backup(nodes: [node('bad', unitCount: 9999999)])),
        contains('not a real sefer'),
      );
    });

    test('a negative unit offset', () async {
      await expectRejected(
        jsonEncode(backup(nodes: [node('bad', unitOffset: -1)])),
        contains('cannot be negative'),
      );
    });

    test('a parent that does not exist', () async {
      await expectRejected(
        jsonEncode(backup(nodes: [node('orphan', parentId: 'nowhere')])),
        contains('does not exist'),
      );
    });

    test('a parent cycle', () async {
      await expectRejected(
        jsonEncode(backup(nodes: [
          node('a', parentId: 'b'),
          node('b', parentId: 'a'),
        ])),
        contains('loop'),
      );
    });

    test('a node that is its own parent', () async {
      await expectRejected(
        jsonEncode(backup(nodes: [node('a', parentId: 'a')])),
        contains('own ancestor'),
      );
    });

    test('more unit names than units', () async {
      await expectRejected(
        jsonEncode(backup(nodes: [
          node('a', unitCount: 2, unitNames: ['x', 'y', 'z'])
        ])),
        contains('unit names'),
      );
    });

    test('a duplicate node id', () async {
      await expectRejected(
        jsonEncode(backup(nodes: [node('a'), node('a')])),
        contains('appears twice'),
      );
    });

    test('a negative unit index on an event', () async {
      await expectRejected(
        jsonEncode(backup(events: [event('e1', unitIndex: -4)])),
        contains('cannot be negative'),
      );
    });

    test('truncated JSON', () async {
      await expectRejected('{"events": [', contains('not valid JSON'));
    });

    test('JSON that is not an object', () async {
      await expectRejected('[1, 2, 3]', contains('not a backup'));
    });

    test('a goal that is not a date', () async {
      await expectRejected(
        jsonEncode(backup(goals: {'shas': 'whenever'})),
        contains('not a valid date'),
      );
    });
  });

  test('a parent in the bundled catalog is accepted', () async {
    final repo = InMemoryProgressRepository();
    final json =
        jsonEncode(backup(nodes: [node('mine', parentId: 'shas.moed')]));
    await BackupService(repo)
        .importInto('b', json, knownNodeIds: {'shas.moed'});
    expect((await repo.watchCustomNodes('b').first).single.id, 'mine');
  });

  test('a rejected import leaves no partial data behind', () async {
    final repo = InMemoryProgressRepository();
    // Good events first, then a node that must be refused: without a
    // transaction the events would land and the node would not.
    final json = jsonEncode(backup(
      events: [event('e1'), event('e2')],
      nodes: [node('bad', unitCount: -1)],
    ));
    await expectLater(BackupService(repo).importInto('b', json),
        throwsA(isA<BackupFormatException>()));
    expect(await repo.getEvents('b'), isEmpty);
  });

  test('goals round-trip through a backup', () async {
    final source = InMemoryProgressRepository();
    final json = await BackupService(source).export(
      'a',
      customNodes: const [],
      goals: {'shas': DateTime(2030, 6, 1)},
    );
    final target = InMemoryProgressRepository();
    final data = await BackupService(target).importInto('b', json);
    expect(data.goals, {'shas': DateTime(2030, 6, 1)});
  });

  test('the batch id of a bulk event survives a backup round-trip', () async {
    final source = InMemoryProgressRepository();
    await source.addEvent(LearningEvent(
      id: 'e1',
      profileId: 'a',
      nodeId: 'shas.moed.shabbos',
      unitIndex: 2,
      action: EventAction.done,
      occurredAt: DateTime(2026, 1, 1),
      loggedAt: DateTime(2026, 1, 1),
      batchId: 'batch-7',
    ));
    final json = await BackupService(source).export('a', customNodes: const []);
    final target = InMemoryProgressRepository();
    await BackupService(target).importInto('b', json);
    expect((await target.getEvents('b')).single.batchId, 'batch-7');
  });

  test('a valid CatalogNode with no units is still fine', () async {
    final repo = InMemoryProgressRepository();
    const category = CatalogNode(
        id: 'cat', parentId: null, name: 'Category', kind: NodeKind.category);
    final json = await BackupService(InMemoryProgressRepository())
        .export('a', customNodes: const [category]);
    await BackupService(repo).importInto('b', json);
    expect((await repo.watchCustomNodes('b').first).single.id, 'cat');
  });
}
