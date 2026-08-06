import 'package:flutter_test/flutter_test.dart';

import 'package:chovos_hayom/data/repositories/drift_progress_repository.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/entities/profile.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';

import '../support/memory_database.dart';

/// The real persistence layer, under test.
///
/// Until this file existed, `DriftProgressRepository` had no test at all — and
/// the two defects that lived there were both about profile scope: an event id
/// that had to be globally unique (so the same backup could not be imported
/// twice), and, once that key became `{profileId, id}`, every query that finds
/// an event *by id alone* becoming able to reach into another profile.
///
/// Those are the same defect from two sides, which is why they are tested
/// together: fixing the first is what makes the second reachable.
///
/// It is now also where the *rest* of the suite's fidelity is pinned. Deleting
/// `InMemoryProgressRepository` meant every other test runs against this class,
/// so the four axes that double had silently drifted on — `updateEvent`
/// rewriting the whole row, `addProfile` accepting a duplicate key, layers
/// bypassing the column that encodes them, and a nested transaction that did
/// not roll back to a savepoint — are asserted here rather than assumed.
void main() {
  late DriftProgressRepository repo;

  setUp(() async {
    repo = memoryRepository();
    await repo.addProfile(
        Profile(id: 'p1', name: 'Reuven', createdAt: DateTime(2026)));
    await repo.addProfile(
        Profile(id: 'p2', name: 'Shimon', createdAt: DateTime(2026)));
  });

  LearningEvent event(
    String id,
    String profileId, {
    String? note,
    String? batchId,
    int unitIndex = 2,
  }) =>
      LearningEvent(
        id: id,
        profileId: profileId,
        nodeId: 'shas.berachos',
        unitIndex: unitIndex,
        action: EventAction.done,
        occurredAt: DateTime(2026, 7, 1),
        loggedAt: DateTime(2026, 7, 1),
        note: note,
        batchId: batchId,
        layers: const [mainLayerId],
      );

  /// Both profiles holding one id is the *point* of the composite key — it is
  /// what a backup imported into two profiles looks like — so it is also the
  /// state every id-based query has to survive.
  Future<void> sameIdInBothProfiles() async {
    await repo.addEvent(event('shared', 'p1', note: "Reuven's"));
    await repo.addEvent(event('shared', 'p2', note: "Shimon's"));
  }

  test('the same event id lives in two profiles at once', () async {
    await sameIdInBothProfiles();

    expect((await repo.getEvents('p1')).single.note, "Reuven's");
    expect((await repo.getEvents('p2')).single.note, "Shimon's");
  });

  test('removing events does not reach into another profile', () async {
    await sameIdInBothProfiles();

    await repo.removeEvents('p2', const ['shared']);

    expect(await repo.getEvents('p2'), isEmpty);
    expect((await repo.getEvents('p1')).single.note, "Reuven's",
        reason: "undoing Shimon's bulk action must not delete Reuven's log");
  });

  test('editing an event does not edit the other profile\'s', () async {
    await sameIdInBothProfiles();

    await repo.updateEvent(event('shared', 'p2', note: 'corrected'));

    expect((await repo.getEvents('p2')).single.note, 'corrected');
    expect((await repo.getEvents('p1')).single.note, "Reuven's",
        reason: 'an edit is scoped to the profile the event belongs to');
  });

  test('undoing a batch only undoes it in its own profile', () async {
    await repo.addEvents([
      event('a', 'p1', batchId: 'batch-1'),
      event('b', 'p1', batchId: 'batch-1', unitIndex: 3),
      event('a', 'p2', batchId: 'batch-1'),
    ]);

    expect(await repo.removeBatch('p1', 'batch-1'), 2);

    expect(await repo.getEvents('p1'), isEmpty);
    expect((await repo.getEvents('p2')).length, 1,
        reason: 'two profiles can run the same bulk action; the batch id is '
            'only unique within a profile, exactly like the event id');
  });

  test('deleting a profile leaves the other profile\'s identical rows',
      () async {
    await sameIdInBothProfiles();

    await repo.deleteProfile('p2');

    expect((await repo.getEvents('p1')).single.note, "Reuven's");
    expect((await repo.getProfiles()).map((p) => p.id), ['p1']);
  });

  group('what the in-memory double got wrong', () {
    // Four behaviours the deleted `InMemoryProgressRepository` implemented
    // differently from this class. Each one was reachable by a test that used
    // the double and passed — which is what a double drifting looks like from
    // the inside, and why these are pinned here rather than trusted.

    test('updateEvent rewrites the annotations and nothing else', () async {
      // The double did `list[i] = event`, so a test could "edit" an event's
      // node, unit or action and watch it work. This writes three columns; the
      // identity and the action are what the fold reads, and rewriting them in
      // place would make the log something other than append-only.
      await repo.addEvent(event('e1', 'p1', note: 'first'));

      await repo.updateEvent(LearningEvent(
        id: 'e1',
        profileId: 'p1',
        nodeId: 'shas.shabbos',
        unitIndex: 99,
        action: EventAction.undone,
        occurredAt: DateTime(2026, 8, 2),
        loggedAt: DateTime(2026, 8, 2),
        durationMin: 45,
        note: 'corrected',
      ));

      final back = (await repo.getEvents('p1')).single;
      expect((back.note, back.durationMin, back.occurredAt),
          ('corrected', 45, DateTime(2026, 8, 2)));
      expect((back.nodeId, back.unitIndex, back.action),
          ('shas.berachos', 2, EventAction.done),
          reason: 'identity and action are immutable — the interface says so, '
              'and only the real table enforces it');
    });

    test('addProfile refuses a duplicate id', () async {
      // The double was `_profiles.add`. Here the id is a primary key, so this
      // is SqliteException(1555) — the same failure the cross-profile import
      // collision produced, from the other table.
      expect(
        () => repo
            .addProfile(Profile(id: 'p1', name: 'again', createdAt: DateTime(2026))),
        throwsA(anything),
      );
    });

    test('layers go through the column that stores them', () async {
      // The double had no `_encodeLayers`, so `backup_service_test`'s
      // "round-trips layers" proved nothing about the encoding: the default
      // single-'main' list is stored as NULL to leave pre-layers rows alone,
      // and a NULL reads back as ['main'].
      await repo.addEvents([
        event('plain', 'p1'),
        LearningEvent(
          id: 'many',
          profileId: 'p1',
          nodeId: 'shas.berachos',
          unitIndex: 3,
          action: EventAction.done,
          occurredAt: DateTime(2026, 7, 1),
          loggedAt: DateTime(2026, 7, 1),
          layers: const [mainLayerId, 'rashi', 'tosfos'],
        ),
      ]);

      final back = {for (final e in await repo.getEvents('p1')) e.id: e.layers};
      expect(back['plain'], [mainLayerId]);
      expect(back['many'], [mainLayerId, 'rashi', 'tosfos']);
    });

    test('a nested transaction rolls back to its savepoint, not past it',
        () async {
      // The double ran a nested call inline and kept its writes. Drift nests
      // with SAVEPOINT: an inner failure the outer catches undoes only the
      // inner writes. Import relies on the outer half — a truncated backup
      // must not leave half of itself behind.
      await repo.transaction(() async {
        await repo.addEvent(event('outer', 'p1'));
        try {
          await repo.transaction(() async {
            await repo.addEvent(event('inner', 'p1', unitIndex: 4));
            throw StateError('inner fails');
          });
        } on StateError {
          // deliberately swallowed: the outer transaction goes on
        }
        await repo.addCustomNode(
            'p1',
            const CatalogNode(
                id: 'n', parentId: null, name: 'N', kind: NodeKind.leaf));
      });

      expect((await repo.getEvents('p1')).map((e) => e.id), ['outer']);
      expect((await repo.getCustomNodes('p1')).single.id, 'n',
          reason: 'the outer transaction survived its inner one failing');
    });

    test('a failed outer transaction leaves nothing behind', () async {
      await expectLater(
        repo.transaction(() async {
          await repo.addEvent(event('e1', 'p1'));
          throw StateError('outer fails');
        }),
        throwsStateError,
      );

      expect(await repo.getEvents('p1'), isEmpty);
    });
  });

  group('the log keeps its own order', () {
    /// `FoldLog` sorts by `loggedAt` and breaks ties on the event id, which is
    /// a v4 UUID. So any two events the store cannot tell apart in time are
    /// ordered by random text — and for a `done` and an `undone` on the same
    /// unit, that decides whether the daf is learned. Permanently: the fold is
    /// re-derived from the log on every read, so the coin lands the same way
    /// every time.
    ///
    /// Drift's `DateTimeColumn` writes `millisecondsSinceEpoch ~/ 1000`, so
    /// *everything inside one second* was such a pair. Mark a daf and un-mark
    /// it in the same second — a double tap — and roughly half the time it
    /// stayed marked. `LearningEvents.loggedAt` therefore stores microseconds.
    ///
    /// No test could see this while the suite ran against an in-memory double
    /// that held `DateTime` objects in a Dart list at full precision.
    test('two events a microsecond apart come back a microsecond apart',
        () async {
      final t1 = DateTime(2026, 7, 1, 9, 30, 15, 123, 456);
      final t2 = t1.add(const Duration(microseconds: 1));
      await repo.addEvents([
        LearningEvent(
          id: 'zzz',
          profileId: 'p1',
          nodeId: 'shas.berachos',
          unitIndex: 2,
          action: EventAction.done,
          occurredAt: t1,
          loggedAt: t1,
        ),
        LearningEvent(
          id: 'aaa',
          profileId: 'p1',
          nodeId: 'shas.berachos',
          unitIndex: 2,
          action: EventAction.undone,
          occurredAt: t2,
          loggedAt: t2,
        ),
      ]);

      final back = {
        for (final e in await repo.getEvents('p1')) e.id: e.loggedAt,
      };
      expect(back['zzz'], t1);
      expect(back['aaa'], t2);
      expect(back['aaa']!.isAfter(back['zzz']!), isTrue,
          reason: 'the ids sort the other way round, so if the store cannot '
              'separate these two instants the fold reads the undo first and '
              'the unit stays learned');
    });

    test('an un-mark in the same second as the mark still wins', () async {
      // The user-facing shape of the same defect, through the fold that reads
      // it: two taps inside one second, second tap undoes the first.
      final t = DateTime(2026, 7, 1, 9, 30, 15, 500);
      await repo.addEvent(LearningEvent(
        id: 'zzz-done',
        profileId: 'p1',
        nodeId: 'shas.berachos',
        unitIndex: 2,
        action: EventAction.done,
        occurredAt: t,
        loggedAt: t,
      ));
      await repo.addEvent(LearningEvent(
        // Sorts *before* the done by id — the losing side of the coin flip.
        id: 'aaa-undone',
        profileId: 'p1',
        nodeId: 'shas.berachos',
        unitIndex: 2,
        action: EventAction.undone,
        occurredAt: t,
        loggedAt: t.add(const Duration(milliseconds: 40)),
      ));

      final fold = FoldLog.fold(await repo.getEvents('p1'));

      expect(fold.completedByNode['shas.berachos']?[2] ?? const <String>{},
          isEmpty,
          reason: 'the later event is the undo, and 40ms is later');
    });
  });
}
