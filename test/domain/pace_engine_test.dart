import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/pace_engine.dart';
import 'package:flutter_test/flutter_test.dart';

LearningEvent doneOn(DateTime day, {int unit = 2, String node = 'a'}) =>
    LearningEvent(
      id: '$node-$unit-${day.toIso8601String()}',
      profileId: 'p',
      nodeId: node,
      unitIndex: unit,
      action: EventAction.done,
      occurredAt: day,
      loggedAt: day,
    );

void main() {
  group('PaceEngine', () {
    final events = [
      doneOn(DateTime(2026, 1, 10, 9), unit: 2),
      doneOn(DateTime(2026, 1, 10, 21), unit: 3),
      doneOn(DateTime(2026, 1, 9, 12), unit: 4),
      doneOn(DateTime(2026, 1, 8, 12), unit: 5),
    ];

    test('unitsOn counts done events on a calendar day', () {
      expect(PaceEngine.unitsOn(events, DateTime(2026, 1, 10)), 2);
      expect(PaceEngine.unitsOn(events, DateTime(2026, 1, 9)), 1);
      expect(PaceEngine.unitsOn(events, DateTime(2026, 1, 7)), 0);
    });

    test('averagePerDay divides by days active, not the full window, for new users', () {
      // 4 done spanning Jan 8-10 (3 active days) — a 3-day-old profile learning
      // ~1.3/day should not read as 0.13/day.
      expect(
        PaceEngine.averagePerDay(events, now: DateTime(2026, 1, 10), windowDays: 30),
        closeTo(4 / 3, 1e-9),
      );
    });

    test('averagePerDay divides by the full window once the profile is older than it', () {
      // First event is >30 days before `now`, so the divisor is the full window.
      final older = [
        doneOn(DateTime(2025, 11, 1)),
        ...events,
      ];
      expect(
        PaceEngine.averagePerDay(older, now: DateTime(2026, 1, 10), windowDays: 30),
        // Only the 4 in-window events count; divided by 30.
        closeTo(4 / 30, 1e-9),
      );
    });

    test('currentStreak counts consecutive days back from today', () {
      expect(PaceEngine.currentStreak(events, now: DateTime(2026, 1, 10)), 3);
    });

    test('streak stays alive when today is empty but yesterday learned', () {
      expect(PaceEngine.currentStreak(events, now: DateTime(2026, 1, 11)), 3);
    });

    test('streak is zero after a two-day gap', () {
      expect(PaceEngine.currentStreak(events, now: DateTime(2026, 1, 12)), 0);
    });
  });
}
