import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/time_stats.dart';
import 'package:flutter_test/flutter_test.dart';

LearningEvent ev(DateTime day, {int? mins, EventAction action = EventAction.done}) =>
    LearningEvent(
      id: '$mins-${day.toIso8601String()}',
      profileId: 'p',
      nodeId: 'a',
      unitIndex: 2,
      action: action,
      occurredAt: day,
      loggedAt: day,
      durationMin: mins,
    );

void main() {
  group('TimeStats', () {
    final events = [
      ev(DateTime(2026, 1, 1), mins: 30),
      ev(DateTime(2026, 1, 15), mins: 45),
      ev(DateTime(2026, 2, 2), mins: 20),
      ev(DateTime(2026, 2, 3), mins: null), // no duration -> ignored
    ];

    test('totalMinutes sums recorded durations, ignoring null', () {
      expect(TimeStats.totalMinutes(events), 95);
    });

    test('minutesSince counts only on/after the given day', () {
      expect(TimeStats.minutesSince(events, DateTime(2026, 2, 1)), 20);
    });

    test('timedSessions counts events with a duration', () {
      expect(TimeStats.timedSessions(events), 3);
    });

    test('averageSessionMinutes divides total by timed sessions', () {
      expect(TimeStats.averageSessionMinutes(events), closeTo(95 / 3, 1e-9));
    });

    test('empty log yields zeros', () {
      expect(TimeStats.totalMinutes(const []), 0);
      expect(TimeStats.averageSessionMinutes(const []), 0);
    });
  });
}
