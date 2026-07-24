import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/chazara_schedule.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/layer_requirements.dart';
import 'package:flutter_test/flutter_test.dart';

LearningEvent doneWith(DateTime day, List<String> layers, {int unit = 2}) =>
    LearningEvent(
      id: 'd${_seq++}',
      profileId: 'p',
      nodeId: 'a',
      unitIndex: unit,
      action: EventAction.done,
      occurredAt: day,
      loggedAt: day,
      layers: layers,
    );

var _seq = 0;
LearningEvent evt(EventAction action, DateTime day, {int unit = 2}) =>
    LearningEvent(
      id: 'e${_seq++}',
      profileId: 'p',
      nodeId: 'a',
      unitIndex: unit,
      action: action,
      occurredAt: day,
      loggedAt: day,
    );

void main() {
  setUp(() => _seq = 0);

  group('ChazaraSchedule', () {
    test('intervalFor grows then plateaus at the last interval', () {
      expect(ChazaraSchedule.intervalFor(0), 1);
      expect(ChazaraSchedule.intervalFor(2), 7);
      expect(
          ChazaraSchedule.intervalFor(99), ChazaraSchedule.defaultIntervals.last);
    });

    test('intervalFor honours a custom interval list', () {
      expect(ChazaraSchedule.intervalFor(0, [2, 4, 8]), 2);
      expect(ChazaraSchedule.intervalFor(1, [2, 4, 8]), 4);
      expect(ChazaraSchedule.intervalFor(9, [2, 4, 8]), 8); // plateaus at last
    });

    test('a freshly-learned unit is due after 1 day', () {
      final events = [evt(EventAction.done, DateTime(2026, 1, 1))];
      // Same day: not yet due.
      expect(ChazaraSchedule.due(FoldLog.fold(events), DateTime(2026, 1, 1)), isEmpty);
      // Next day: due.
      final due = ChazaraSchedule.due(FoldLog.fold(events), DateTime(2026, 1, 2));
      expect(due, hasLength(1));
      expect(due.first.reviewCount, 0);
      expect(due.first.daysOverdue, 0);
    });

    test('a review pushes the next due date out by the next interval', () {
      final events = [
        evt(EventAction.done, DateTime(2026, 1, 1)),
        evt(EventAction.reviewed, DateTime(2026, 1, 2)),
      ];
      // After 1 review, interval is 3 days from the review (Jan 2) -> due Jan 5.
      expect(ChazaraSchedule.due(FoldLog.fold(events), DateTime(2026, 1, 4)), isEmpty);
      final due = ChazaraSchedule.due(FoldLog.fold(events), DateTime(2026, 1, 5));
      expect(due, hasLength(1));
      expect(due.first.reviewCount, 1);
    });

    test('un-marking removes a unit from the schedule', () {
      final events = [
        evt(EventAction.done, DateTime(2026, 1, 1)),
        evt(EventAction.undone, DateTime(2026, 1, 1)),
      ];
      expect(ChazaraSchedule.due(FoldLog.fold(events), DateTime(2026, 2, 1)), isEmpty);
    });

    test('most overdue comes first', () {
      final events = [
        evt(EventAction.done, DateTime(2026, 1, 1), unit: 2),
        evt(EventAction.done, DateTime(2026, 1, 10), unit: 3),
      ];
      final due = ChazaraSchedule.due(FoldLog.fold(events), DateTime(2026, 1, 20));
      expect(due.map((d) => d.unitIndex).toList(), [2, 3]);
    });

    test('a unit with only an optional meforish ticked is not due', () {
      // Ticking Rashi (not the text) leaves a touch date but the unit isn't done
      // under the text-only default, so it must not appear on the schedule.
      final fold = FoldLog.fold([doneWith(DateTime(2026, 1, 1), ['rashi'])]);
      expect(ChazaraSchedule.due(fold, DateTime(2026, 1, 10)), isEmpty);
    });

    test('required layers gate the schedule', () {
      final req = LayerRequirements(nodeConfig: {
        'a': {'main', 'rashi'}
      });
      // Only the text learned: due date has passed, but Rashi is required.
      final textOnly = FoldLog.fold([doneWith(DateTime(2026, 1, 1), ['main'])]);
      expect(
          ChazaraSchedule.due(textOnly, DateTime(2026, 1, 10), required: req),
          isEmpty);

      // Add Rashi and it becomes a real, complete unit — now it's due.
      final both = FoldLog.fold([
        doneWith(DateTime(2026, 1, 1), ['main']),
        doneWith(DateTime(2026, 1, 1), ['rashi']),
      ]);
      expect(ChazaraSchedule.due(both, DateTime(2026, 1, 10), required: req),
          hasLength(1));
    });
  });
}
