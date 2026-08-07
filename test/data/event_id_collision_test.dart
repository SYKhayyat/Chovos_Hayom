import 'package:flutter_test/flutter_test.dart';

import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/data/repositories/drift_progress_repository.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/entities/profile.dart';

import '../support/memory_database.dart';

/// GRADER PROBE — the real Drift repository, not the in-memory double.
///
/// `LearningEvents.primaryKey` is `{id}` alone, while `CustomNodes` is
/// `{profileId, id}` with a comment stating that a profile-blind key throws
/// "a uniqueness violation" when the same backup is imported into a second
/// profile. Events never got that fix, and no test exercises
/// `DriftProgressRepository` at all — every backup test runs against
/// `InMemoryProgressRepository`, which keys events by profile and so has no
/// global id constraint to violate.
void main() {
  late DriftProgressRepository repo;

  setUp(() {
    repo = memoryRepository();
  });

  LearningEvent event(String id, String profileId) => LearningEvent(
        id: id,
        profileId: profileId,
        nodeId: 'shas.berachos',
        unitIndex: 2,
        action: EventAction.done,
        occurredAt: DateTime(2026, 7, 1),
        loggedAt: DateTime(2026, 7, 1),
        layers: const [mainLayerId],
      );

  test('the same backup imports into a second profile', () async {
    await repo.addProfile(
        Profile(id: 'p1', name: 'Reuven', createdAt: DateTime(2026)));
    await repo.addProfile(
        Profile(id: 'p2', name: 'Shimon', createdAt: DateTime(2026)));

    // p1 learns a daf, and exports.
    await repo.addEvent(event('evt-1', 'p1'));
    final service = BackupService(repo);
    final json = await service.export('p1');

    // The same file is imported into the second profile — a documented
    // feature (profiles + import/restore), and the obvious way to move
    // progress to a family member's profile on the same device.
    await service.importInto('p2', BackupService.parse(json));

    expect((await repo.getEvents('p2')).length, 1,
        reason: 'p2 should now hold the backed-up event');
    expect((await repo.getEvents('p1')).length, 1,
        reason: "p1's own log must be untouched");
  });
}
