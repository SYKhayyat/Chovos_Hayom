import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/roll_up.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/memory_database.dart';
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
  String? name,
  int unitCount = 5,
  int unitOffset = 1,
  List<String> unitNames = const [],
}) =>
    {
      'id': id,
      'parentId': parentId,
      'name': name ?? 'Sefer $id',
      'kind': 'leaf',
      'unitLabel': 'perek',
      'unitCount': unitCount,
      'unitOffset': unitOffset,
      'unitNames': unitNames,
    };

Map<String, dynamic> event(
  String id, {
  int unitIndex = 2,
  int? durationMin,
  List<String>? layers,
}) =>
    {
      'id': id,
      'profileId': 'a',
      'nodeId': 'shas.moed.shabbos',
      'unitIndex': unitIndex,
      'action': 'done',
      'occurredAt': '2026-01-01T00:00:00.000',
      'loggedAt': '2026-01-01T00:00:00.000',
      'durationMin': ?durationMin,
      'layers': ?layers,
    };

Future<void> expectRejected(String json, Matcher messageMatcher) async {
  final repo = memoryRepository();
  await expectLater(
    BackupService(repo).importInto('b', json),
    throwsA(isA<BackupFormatException>()
        .having((e) => e.message, 'message', messageMatcher)),
  );
  // Nothing may be left behind by a rejected import.
  expect(await repo.getEvents('b'), isEmpty);
  expect(await repo.getCustomNodes('b'), isEmpty);
}

/// Imports [json] and returns what landed, for the cases that are *not*
/// rejected — the deletions in this file are only defensible if the data they
/// used to refuse is genuinely harmless, and asserting that is more work than
/// deleting a test, which is the point.
Future<List<CatalogNode>> expectAccepted(String json) async {
  final repo = memoryRepository();
  await BackupService(repo).importInto('b', json);
  return repo.getCustomNodes('b');
}

void main() {
  group('import rejects data that would corrupt the app', () {
    test('a negative unit count', () async {
      // Kept, and its reason is now the honest one: nothing throws — `RollUp`
      // renders `0 / -5` — but the sefer is permanently uncountable, because
      // `containsUnit` is false for every index, so no mark on it can ever
      // register. That is worth a sentence.
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

    test('a duplicate node id', () async {
      // The rows go in with `insertOnConflictUpdate`, so without this the
      // second silently replaces the first and a sefer is gone with no error.
      await expectRejected(
        jsonEncode(backup(nodes: [node('a'), node('a')])),
        contains('appears twice'),
      );
    });

    test('a duplicate event id', () async {
      // Without this, `addEvents` hands the user
      // `SqliteException(1555): UNIQUE constraint failed` — a driver error in
      // front of somebody who asked to restore a backup.
      await expectRejected(
        jsonEncode(backup(events: [event('e1'), event('e1')])),
        contains('appears twice'),
      );
    });

    test('a negative duration', () async {
      // Minutes are summed into the time statistics, so this subtracts from a
      // total the user reads.
      await expectRejected(
        jsonEncode(backup(events: [event('e1', durationMin: -90)])),
        contains('negative duration'),
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

  group('import no longer refuses what it cannot be hurt by', () {
    // Every one of these was a rejection. Each is now asserted to be inert
    // instead — because "the file is refused" and "the app is safe" are
    // different claims, and this class was making the first while stating the
    // second.

    test('a negative unit offset only moves the labels', () async {
      final nodes = await expectAccepted(
          jsonEncode(backup(nodes: [node('bad', unitOffset: -1)])));
      expect(nodes.single.unitOffset, -1);
      // The units are still enumerable and still count; they are labelled from
      // -1, which is wrong and is fixable in the node editor.
      expect(nodes.single.unitIndices, [-1, 0, 1, 2, 3]);
    });

    test('more unit names than units leaves the extras unread', () async {
      final nodes = await expectAccepted(jsonEncode(backup(nodes: [
        node('a', unitCount: 2, unitNames: ['x', 'y', 'z'])
      ])));
      final n = nodes.single;
      // `unitDisplay` is bounded by the range, so the third name is simply
      // never asked for — there is no index that reaches it.
      expect(n.unitIndices.map(n.unitDisplay), ['x', 'y']);
    });

    test('a negative unit index on an event is ignored by the fold', () async {
      final repo = memoryRepository();
      await BackupService(repo)
          .importInto('b', jsonEncode(backup(events: [event('e1', unitIndex: -4)])));
      final fold = FoldLog.fold(await repo.getEvents('b'));
      // It is in the log and out of every node's range, which is the same
      // handling a mark on a sefer that later shrank gets.
      expect(fold.doneUnits('shas.moed.shabbos'), {-4});
      expect(
        RollUp.buildNode(fakeCatalog(), 'shas.moed.shabbos', fold)!.learned,
        0,
        reason: 'out-of-range marks never reach a progress number',
      );
    });

    test('an event with an empty layer list marks nothing', () async {
      final repo = memoryRepository();
      await BackupService(repo).importInto(
          'b', jsonEncode(backup(events: [event('e1', layers: const [])])));
      final fold = FoldLog.fold(await repo.getEvents('b'));
      expect(fold.doneUnits('shas.moed.shabbos'), isEmpty,
          reason: 'the text layer is not among the completed ones, so the '
              'unit is simply not done');
    });

    test('an empty name and an empty id are carried, not refused', () async {
      final nodes = await expectAccepted(
          jsonEncode(backup(nodes: [node('', name: '')])));
      expect(nodes.single.name, '');
      // A blank row in the tree, and the node editor can rename it. That is a
      // worse backup than it should be; it is not a broken app.
    });
  });

  group('a shape the tree cannot hold is repaired rather than refused', () {
    // These used to be the validator's two headline rejections. They are now
    // `Catalog`'s promise, which is a wider one — it also covers the loops the
    // node editor and the clone can make with no file involved.
    // `catalog_forest_test.dart` holds the invariant; these hold the seam.

    test('a parent that does not exist becomes a root', () async {
      final nodes = await expectAccepted(
          jsonEncode(backup(nodes: [node('orphan', parentId: 'nowhere')])));
      expect(nodes.single.id, 'orphan');
      final catalog = Catalog([...fakeCatalog().all, ...nodes]);
      expect(catalog.roots.map((n) => n.id), contains('orphan'),
          reason: 'visible and re-fileable, where it used to be in `byId` and '
              'under no root at all');
    });

    test('a parent cycle imports and is cut once', () async {
      final nodes = await expectAccepted(jsonEncode(backup(nodes: [
        node('a', parentId: 'b'),
        node('b', parentId: 'a'),
      ])));
      expect(nodes.map((n) => n.id).toSet(), {'a', 'b'});
      final catalog = Catalog(nodes);
      expect(catalog.roots.map((n) => n.id), ['a']);
      expect(catalog.childrenOf('a').map((n) => n.id), ['b']);
    });

    test('a node that is its own parent imports and is detached', () async {
      final nodes =
          await expectAccepted(jsonEncode(backup(nodes: [node('a', parentId: 'a')])));
      expect(Catalog(nodes).byId('a')!.parentId, isNull);
    });

    test('an override row that re-parents a built-in beneath its own child',
        () async {
      // The loop in which *every* id belongs to the bundled catalog — the case
      // that needed the whole `knownParents` map threaded through the settings
      // screen for the old check to be able to see it at all. It needs nothing
      // now: the catalog that gets built cannot hold the shape.
      final nodes = await expectAccepted(jsonEncode(backup(nodes: [
        {
          'id': 'shas',
          'parentId': 'shas.moed',
          'name': 'Shas',
          'kind': 'category',
        }
      ])));
      final catalog = Catalog([
        ...fakeCatalog().all.where((n) => n.id != 'shas'),
        ...nodes,
      ]);
      // Shas is lifted to the top rather than left dangling under its own
      // grandchild, and everything beneath it keeps its place. The user's tree
      // is rearranged by one link, which is the whole cost of the repair.
      expect(catalog.byId('shas')!.parentId, isNull);
      expect(catalog.leavesUnder('shas').map((n) => n.id),
          ['shas.moed.shabbos']);
    });
  });

  test('a parent in the bundled catalog is accepted', () async {
    final repo = memoryRepository();
    final json =
        jsonEncode(backup(nodes: [node('mine', parentId: 'shas.moed')]));
    await BackupService(repo).importInto('b', json);
    expect((await repo.getCustomNodes('b')).single.id, 'mine');
  });

  test('a rejected import leaves no partial data behind', () async {
    final repo = memoryRepository();
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

    late ProgressRepository repo;
    late String json;

    setUp(() async {
      repo = memoryRepository();
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
      final data = await BackupService(repo)
          .importInto('a', json, mode: ImportMode.restoreLog);

      expect(data.removedEvents, 1);
      final events = await repo.getEvents('a');
      expect(events.map((e) => e.id), ['done-1']);
      expect(FoldLog.fold(events).doneUnits('bereishis'), {1},
          reason: 'the mark is genuinely back');
    });

    test('restoring twice is a no-op the second time', () async {
      await BackupService(repo).importInto('a', json, mode: ImportMode.restoreLog);
      final again = await BackupService(repo)
          .importInto('a', json, mode: ImportMode.restoreLog);

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

      await BackupService(repo).importInto('a', json, mode: ImportMode.restoreLog);

      expect((await repo.getEvents('b')).map((e) => e.id), ['other-1']);
    });
  });

  test('goals round-trip through a backup', () async {
    final source = memoryRepository();
    final json = await BackupService(source).export(
      'a',
      customNodes: const [],
      goals: {'shas': DateTime(2030, 6, 1)},
    );
    final target = memoryRepository();
    final data = await BackupService(target).importInto('b', json);
    expect(data.goals, {'shas': DateTime(2030, 6, 1)});
  });

  test('the batch id of a bulk event survives a backup round-trip', () async {
    final source = memoryRepository();
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
    final target = memoryRepository();
    await BackupService(target).importInto('b', json);
    expect((await target.getEvents('b')).single.batchId, 'batch-7');
  });

  test('a valid CatalogNode with no units is still fine', () async {
    final repo = memoryRepository();
    const category = CatalogNode(
        id: 'cat', parentId: null, name: 'Category', kind: NodeKind.category);
    final json = await BackupService(memoryRepository())
        .export('a', customNodes: const [category]);
    await BackupService(repo).importInto('b', json);
    expect((await repo.getCustomNodes('b')).single.id, 'cat');
  });
}
