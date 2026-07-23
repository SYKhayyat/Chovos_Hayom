import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:flutter_test/flutter_test.dart';

LearningEvent ev(
  String node,
  int unit,
  EventAction action, {
  int seq = 0,
  String? id,
  DateTime? occurredAt,
  String? note,
  int? durationMin,
}) {
  final t = DateTime(2026, 1, 1).add(Duration(seconds: seq));
  return LearningEvent(
    id: id ?? '$node-$unit-${action.name}-$seq',
    profileId: 'p',
    nodeId: node,
    unitIndex: unit,
    action: action,
    occurredAt: occurredAt ?? t,
    loggedAt: t,
    note: note,
    durationMin: durationMin,
  );
}

void main() {
  group('FoldLog', () {
    test('done marks a unit', () {
      final fold = FoldLog.fold([ev('a', 2, EventAction.done)]);
      expect(fold.doneUnits('a'), {2});
    });

    test('undone removes a previously done unit', () {
      final fold = FoldLog.fold([
        ev('a', 2, EventAction.done, seq: 0),
        ev('a', 2, EventAction.undone, seq: 1),
      ]);
      expect(fold.doneUnits('a'), isEmpty);
    });

    test('later done after undone re-marks it', () {
      final fold = FoldLog.fold([
        ev('a', 2, EventAction.done, seq: 0),
        ev('a', 2, EventAction.undone, seq: 1),
        ev('a', 2, EventAction.done, seq: 2),
      ]);
      expect(fold.doneUnits('a'), {2});
    });

    test('fold is order-independent (sorted by loggedAt then id)', () {
      final ordered = [
        ev('a', 2, EventAction.done, seq: 0),
        ev('a', 2, EventAction.undone, seq: 1),
      ];
      final shuffled = [ordered[1], ordered[0]];
      expect(FoldLog.fold(shuffled).doneUnits('a'), isEmpty);
    });

    test('reviewed increments review count without affecting done', () {
      final fold = FoldLog.fold([
        ev('a', 5, EventAction.done, seq: 0),
        ev('a', 5, EventAction.reviewed, seq: 1),
        ev('a', 5, EventAction.reviewed, seq: 2),
      ]);
      expect(fold.doneUnits('a'), {5});
      expect(fold.reviewCount('a', 5), 2);
    });

    test('a review of something never learned moves nothing', () {
      final fold = FoldLog.fold([ev('a', 5, EventAction.reviewed)]);
      expect(fold.reviewCount('a', 5), 0);
      expect(fold.touchedAt('a', 5), isNull);
    });
  });

  // The fold carries everything per-unit that used to be recovered by a second
  // ordered pass over the log — chazara timing, the cumulative line's dates, and
  // the grid's detail dot.
  group('FoldLog per-unit detail', () {
    test('doneAt is the learned-date of the done event in force', () {
      final fold = FoldLog.fold([
        ev('a', 2, EventAction.done, seq: 0, occurredAt: DateTime(2026, 3, 1)),
        ev('a', 2, EventAction.done, seq: 1, occurredAt: DateTime(2026, 1, 15)),
      ]);
      // A later done supersedes the earlier one, even backdated.
      expect(fold.doneAt('a', 2), DateTime(2026, 1, 15));
    });

    test('un-marking clears the dates and the annotation', () {
      final fold = FoldLog.fold([
        ev('a', 2, EventAction.done, seq: 0, note: 'chiddush'),
        ev('a', 2, EventAction.undone, seq: 1),
      ]);
      expect(fold.doneAt('a', 2), isNull);
      expect(fold.touchedAt('a', 2), isNull);
      expect(fold.isAnnotated('a', 2), isFalse);
    });

    test('touchedAt follows reviews; doneAt does not', () {
      final fold = FoldLog.fold([
        ev('a', 2, EventAction.done, seq: 0, occurredAt: DateTime(2026, 1, 1)),
        ev('a', 2, EventAction.reviewed,
            seq: 1, occurredAt: DateTime(2026, 2, 1)),
      ]);
      expect(fold.doneAt('a', 2), DateTime(2026, 1, 1));
      expect(fold.touchedAt('a', 2), DateTime(2026, 2, 1));
    });

    test('a haara or a duration marks the unit as annotated', () {
      final fold = FoldLog.fold([
        ev('a', 2, EventAction.done, seq: 0, note: 'a question on Rashi'),
        ev('a', 3, EventAction.done, seq: 1, durationMin: 40),
        ev('a', 4, EventAction.done, seq: 2),
      ]);
      expect(fold.isAnnotated('a', 2), isTrue);
      expect(fold.isAnnotated('a', 3), isTrue);
      expect(fold.isAnnotated('a', 4), isFalse);
    });

    test('re-logging without details clears the annotation', () {
      final fold = FoldLog.fold([
        ev('a', 2, EventAction.done, seq: 0, note: 'first thought'),
        ev('a', 2, EventAction.done, seq: 1),
      ]);
      expect(fold.isAnnotated('a', 2), isFalse,
          reason: 'the later done is the one in force');
    });
  });
}
