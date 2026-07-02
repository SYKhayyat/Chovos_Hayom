import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/progress_series.dart';
import 'package:flutter_test/flutter_test.dart';

LearningEvent ev(DateTime day, EventAction action, {int unit = 2}) => LearningEvent(
      id: '$unit-${action.name}-${day.toIso8601String()}',
      profileId: 'p',
      nodeId: 'a',
      unitIndex: unit,
      action: action,
      occurredAt: day,
      loggedAt: day,
    );

void main() {
  group('ProgressSeries', () {
    final events = [
      ev(DateTime(2026, 1, 1), EventAction.done, unit: 2),
      ev(DateTime(2026, 1, 1), EventAction.done, unit: 3),
      ev(DateTime(2026, 1, 3), EventAction.done, unit: 4),
      ev(DateTime(2026, 1, 3), EventAction.undone, unit: 2),
      ev(DateTime(2026, 1, 3), EventAction.reviewed, unit: 3),
    ];

    test('dailyDeltas nets done and undone, ignores reviewed', () {
      final d = ProgressSeries.dailyDeltas(events);
      expect(d[DateTime(2026, 1, 1)], 2);
      expect(d[DateTime(2026, 1, 3)], 0); // +1 done, -1 undone
      expect(d.containsKey(DateTime(2026, 1, 2)), isFalse);
    });

    test('dailyDone counts only done events', () {
      final d = ProgressSeries.dailyDone(events);
      expect(d[DateTime(2026, 1, 1)], 2);
      expect(d[DateTime(2026, 1, 3)], 1);
    });

    test('cumulative runs a chronological running total', () {
      final series = ProgressSeries.cumulative(events);
      expect(series.map((p) => p.cumulative).toList(), [2, 2]);
      expect(series.first.day, DateTime(2026, 1, 1));
      expect(series.last.day, DateTime(2026, 1, 3));
    });

    test('empty log yields empty series', () {
      expect(ProgressSeries.cumulative(const []), isEmpty);
    });
  });
}
