import 'package:chovos_hayom/application/logging_service.dart';
import 'package:chovos_hayom/data/repositories/in_memory_progress_repository.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/unit_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('editDetails', () {
    late InMemoryProgressRepository repo;
    late LoggingService logger;

    setUp(() {
      repo = InMemoryProgressRepository();
      logger = LoggingService(
        repository: repo,
        profileId: 'p',
        now: () => DateTime(2026, 1, 1, 8),
        idGen: () => 'fixed-id',
      );
    });

    test('updates occurredAt, duration, and note in place without changing done',
        () async {
      final original = await logger.markDone('a', 2, note: 'first', haara: 'idea');
      await logger.editDetails(
        original,
        occurredAt: DateTime(2026, 1, 3, 14, 30),
        durationMin: 45,
        note: 'revised',
        haara: 'sharper idea',
      );

      final events = await repo.getEvents('p');
      expect(events, hasLength(1)); // edited in place, not appended
      final h = UnitHistoryFinder.forUnit(events, 'a', 2);
      expect(h.done!.occurredAt, DateTime(2026, 1, 3, 14, 30));
      expect(h.done!.durationMin, 45);
      expect(h.done!.note, 'revised');
      expect(h.done!.haara, 'sharper idea');

      // Still marked done.
      expect(FoldLog.fold(events).doneUnits('a'), {2});
    });

    test('can clear the note and duration by passing null', () async {
      final original = await logger.markDone('a', 2,
          durationMin: 20, note: 'x', haara: 'y');
      await logger.editDetails(
        original,
        occurredAt: original.occurredAt,
        durationMin: null,
        note: null,
        haara: null,
      );

      final h = UnitHistoryFinder.forUnit(await repo.getEvents('p'), 'a', 2);
      expect(h.done!.durationMin, isNull);
      expect(h.done!.note, isNull);
      expect(h.done!.haara, isNull);
    });

    test('editing is scoped to the target profile', () async {
      final original = await logger.markDone('a', 2, note: 'p-note');
      // A different profile with the same event id should be untouched.
      final other = LoggingService(
        repository: repo,
        profileId: 'q',
        now: () => DateTime(2026, 1, 1, 8),
        idGen: () => 'fixed-id',
      );
      await other.markDone('a', 2, note: 'q-note');

      await logger.editDetails(original,
          occurredAt: original.occurredAt,
          durationMin: null,
          note: 'edited',
          haara: null);

      expect(UnitHistoryFinder.forUnit(await repo.getEvents('p'), 'a', 2).done!.note,
          'edited');
      expect(UnitHistoryFinder.forUnit(await repo.getEvents('q'), 'a', 2).done!.note,
          'q-note');
    });
  });
}
