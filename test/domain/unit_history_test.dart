import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/unit_history.dart';
import 'package:flutter_test/flutter_test.dart';

LearningEvent ev(
  EventAction action, {
  int seq = 0,
  int unit = 2,
  String node = 'a',
  int? durationMin,
  String? note,
}) {
  final t = DateTime(2026, 1, 1).add(Duration(seconds: seq));
  return LearningEvent(
    id: '$node-$unit-${action.name}-$seq',
    profileId: 'p',
    nodeId: node,
    unitIndex: unit,
    action: action,
    occurredAt: t,
    loggedAt: t,
    durationMin: durationMin,
    note: note,
  );
}

void main() {
  group('UnitHistoryFinder', () {
    test('returns the done event with its recorded annotations', () {
      final h = UnitHistoryFinder.forUnit(
        [ev(EventAction.done, seq: 0, durationMin: 25, note: 'good seder')],
        'a',
        2,
      );
      expect(h.isDone, isTrue);
      expect(h.done!.durationMin, 25);
      expect(h.done!.note, 'good seder');
      expect(h.reviewCount, 0);
    });

    test('a later done supersedes an earlier one\'s annotations', () {
      final h = UnitHistoryFinder.forUnit([
        ev(EventAction.done, seq: 0, note: 'first'),
        ev(EventAction.done, seq: 1, note: 'second'),
      ], 'a', 2);
      expect(h.done!.note, 'second');
    });

    test('collects reviews logged while done, oldest first', () {
      final h = UnitHistoryFinder.forUnit([
        ev(EventAction.done, seq: 0),
        ev(EventAction.reviewed, seq: 1),
        ev(EventAction.reviewed, seq: 2),
      ], 'a', 2);
      expect(h.reviewCount, 2);
      expect(h.reviews.first.loggedAt.isBefore(h.reviews.last.loggedAt), isTrue);
    });

    test('un-marking clears the done event and its reviews', () {
      final h = UnitHistoryFinder.forUnit([
        ev(EventAction.done, seq: 0),
        ev(EventAction.reviewed, seq: 1),
        ev(EventAction.undone, seq: 2),
      ], 'a', 2);
      expect(h.isDone, isFalse);
      expect(h.reviewCount, 0);
    });

    test('reviews before a done event do not count', () {
      final h = UnitHistoryFinder.forUnit([
        ev(EventAction.reviewed, seq: 0),
        ev(EventAction.done, seq: 1),
      ], 'a', 2);
      expect(h.reviewCount, 0);
      expect(h.isDone, isTrue);
    });

    test('totalMinutes sums the done event and reviews with a duration', () {
      final h = UnitHistoryFinder.forUnit([
        ev(EventAction.done, seq: 0, durationMin: 30),
        ev(EventAction.reviewed, seq: 1, durationMin: 10),
        ev(EventAction.reviewed, seq: 2),
      ], 'a', 2);
      expect(h.totalMinutes, 40);
    });

    test('ignores other units and nodes', () {
      final h = UnitHistoryFinder.forUnit([
        ev(EventAction.done, seq: 0, unit: 2),
        ev(EventAction.done, seq: 1, unit: 3),
        ev(EventAction.done, seq: 2, node: 'b', unit: 2),
      ], 'a', 2);
      expect(h.isDone, isTrue);
      expect(h.done!.unitIndex, 2);
      expect(h.done!.nodeId, 'a');
    });
  });
}
