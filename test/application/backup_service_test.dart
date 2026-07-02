import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/data/repositories/in_memory_progress_repository.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:flutter_test/flutter_test.dart';

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

    final json = await BackupService(source).export('a', [
      const CatalogNode(
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
    final added = await BackupService(target).importInto('b', json);

    expect(added, 2);
    final events = await target.getEvents('b');
    expect(events.map((e) => e.id).toSet(), {'e1', 'e2'});
    expect(events.every((e) => e.profileId == 'b'), isTrue, reason: 're-scoped');
    expect(events.first.note, 'with Rashi');
  });

  test('re-import is idempotent (dedup by id)', () async {
    final source = InMemoryProgressRepository();
    await source.addEvent(ev('e1'));
    final json = await BackupService(source).export('a', const []);

    final target = InMemoryProgressRepository();
    await BackupService(target).importInto('b', json);
    final addedAgain = await BackupService(target).importInto('b', json);

    expect(addedAgain, 0);
    expect(await target.getEvents('b'), hasLength(1));
  });
}
