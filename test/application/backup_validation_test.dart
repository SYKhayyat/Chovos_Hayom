import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
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

  test('an override row that re-parents a built-in beneath its own child', () async {
    // The catalog has shas.berachos -> shas. This override makes shas ->
    // shas.berachos, closing a loop in which *every* id is already "known" —
    // invisible to a cycle check that walks only the backup's own rows, and it
    // empties the whole tree once in SQLite.
    final repo = InMemoryProgressRepository();
    final json =
        jsonEncode(backup(nodes: [node('shas', parentId: 'shas.berachos')]));
    await expectLater(
      BackupService(repo).importInto('b', json,
          knownParents: {'shas': null, 'shas.berachos': 'shas'}),
      throwsA(isA<BackupFormatException>()
          .having((e) => e.message, 'message', contains('loop'))),
    );
    expect(await repo.watchCustomNodes('b').first, isEmpty);
  });

  test('a parent in the bundled catalog is accepted', () async {
    final repo = InMemoryProgressRepository();
    final json =
        jsonEncode(backup(nodes: [node('mine', parentId: 'shas.moed')]));
    await BackupService(repo)
        .importInto('b', json, knownParents: {'shas.moed': null});
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

  group('restore (replace) undoes what a merge cannot', () {
    /// The log is append-only, so un-marking a unit *adds* an `undone` rather
    /// than removing the `done`. A merge re-adds nothing (every id is already
    /// present) and the later `undone` still wins — so the unit stays un-marked.
    /// Only a restore, which drops events the backup doesn't contain, puts it
    /// back. This is the exact round-trip a user hit: mark → export → un-mark →
    /// import, and nothing came back.
    LearningEvent ev(String id, EventAction action, DateTime at) => LearningEvent(
          id: id,
          profileId: 'a',
          nodeId: 'bereishis',
          unitIndex: 1,
          action: action,
          occurredAt: at,
          loggedAt: at,
        );

    late InMemoryProgressRepository repo;
    late String json;

    setUp(() async {
      repo = InMemoryProgressRepository();
      await repo.addEvent(ev('done-1', EventAction.done, DateTime(2026, 7, 24, 10)));
      // The backup is taken while the unit is marked.
      json = await BackupService(repo).export('a', customNodes: const []);
      // ...and then the user un-marks it, which appends rather than deletes.
      await repo
          .addEvent(ev('undone-1', EventAction.undone, DateTime(2026, 7, 24, 11)));
    });

    test('a merge cannot bring the un-marked unit back', () async {
      final data = await BackupService(repo).importInto('a', json);

      expect(data.events, isEmpty, reason: 'every id is already present');
      expect(data.removedEvents, 0);
      final ids = (await repo.getEvents('a')).map((e) => e.id).toSet();
      expect(ids, containsAll(<String>['done-1', 'undone-1']),
          reason: 'the later undone survives, so the unit is still un-marked');
    });

    test('a restore removes the later undone, so the unit is marked again',
        () async {
      final data =
          await BackupService(repo).importInto('a', json, replace: true);

      expect(data.removedEvents, 1);
      final events = await repo.getEvents('a');
      expect(events.map((e) => e.id), ['done-1']);
      expect(FoldLog.fold(events).doneUnits('bereishis'), {1},
          reason: 'the mark is genuinely back');
    });

    test('restoring twice is a no-op the second time', () async {
      await BackupService(repo).importInto('a', json, replace: true);
      final again =
          await BackupService(repo).importInto('a', json, replace: true);

      expect(again.removedEvents, 0);
      expect(again.events, isEmpty);
    });

    test('a restore leaves another profile alone', () async {
      await repo.addEvent(LearningEvent(
        id: 'other-1',
        profileId: 'b',
        nodeId: 'bereishis',
        unitIndex: 1,
        action: EventAction.done,
        occurredAt: DateTime(2026, 7, 24, 10),
        loggedAt: DateTime(2026, 7, 24, 10),
      ));

      await BackupService(repo).importInto('a', json, replace: true);

      expect((await repo.getEvents('b')).map((e) => e.id), ['other-1']);
    });
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
