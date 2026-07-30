import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chovos_hayom/data/drift/database.dart';
import 'package:chovos_hayom/data/repositories/drift_progress_repository.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/entities/profile.dart';

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
void main() {
  late AppDatabase db;
  late DriftProgressRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftProgressRepository(db);
    await repo.addProfile(
        Profile(id: 'p1', name: 'Reuven', createdAt: DateTime(2026)));
    await repo.addProfile(
        Profile(id: 'p2', name: 'Shimon', createdAt: DateTime(2026)));
  });

  tearDown(() => db.close());

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
}
