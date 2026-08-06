import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
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

    test('cumulative is a monotonic total of currently-held units by learn-date', () {
      // unit 2 (Jan 1) was later un-marked, so it drops out entirely; the line
      // reflects only units 3 (Jan 1) and 4 (Jan 3) that are still done.
      final series = ProgressSeries.cumulative(FoldLog.fold(events));
      expect(series.map((p) => p.cumulative).toList(), [1, 2]);
      expect(series.first.day, Day.of(DateTime(2026, 1, 1)));
      expect(series.last.day, Day.of(DateTime(2026, 1, 3)));
    });

    test('final cumulative equals the current learned count after a backdated re-log', () {
      // done (Jan 10) -> undone (Jan 11) -> re-logged done backdated to Jan 1.
      // The unit is currently done, so the line must end at 1 (not 0).
      final e = [
        ev(DateTime(2026, 1, 10), EventAction.done, unit: 7),
        LearningEvent(
          id: 'z-undone',
          profileId: 'p',
          nodeId: 'a',
          unitIndex: 7,
          action: EventAction.undone,
          occurredAt: DateTime(2026, 1, 11),
          loggedAt: DateTime(2026, 1, 11),
        ),
        LearningEvent(
          id: 'z-redone',
          profileId: 'p',
          nodeId: 'a',
          unitIndex: 7,
          action: EventAction.done,
          occurredAt: DateTime(2026, 1, 1),
          loggedAt: DateTime(2026, 1, 12),
        ),
      ];
      final series = ProgressSeries.cumulative(FoldLog.fold(e));
      expect(series.last.cumulative, 1);
    });

    test('empty log yields empty series', () {
      expect(ProgressSeries.cumulative(FoldLog.fold(const [])), isEmpty);
    });

    // Grouping happens on `Day`, whose identity is a cheap int ordinal
    // (constructing a *local* DateTime per event was ~230× slower and made the
    // Statistics screen take a second to open). This pins the behaviour that
    // both that refactor and the later move to `Day` had to preserve: events at
    // different times of the same calendar day still collapse to one key. The
    // same property for the day-indexed helpers that used to live here is in
    // `log_activity_test.dart`, which is where they went.
    test('cumulative keys each distinct learned-day exactly once', () {
      final events = [
        ev(DateTime(2026, 3, 9, 8), EventAction.done, unit: 2),
        ev(DateTime(2026, 3, 9, 20), EventAction.done, unit: 3),
        ev(DateTime(2026, 3, 11, 6), EventAction.done, unit: 4),
      ];
      final series = ProgressSeries.cumulative(FoldLog.fold(events));
      expect(series.map((p) => p.day).toList(),
          [Day.of(DateTime(2026, 3, 9)), Day.of(DateTime(2026, 3, 11))]);
      expect(series.map((p) => p.cumulative).toList(), [2, 3]);
    });
  });
}
