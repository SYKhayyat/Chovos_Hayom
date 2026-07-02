import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/reminders_policy.dart';
import 'package:flutter_test/flutter_test.dart';

LearningEvent done(DateTime day) => LearningEvent(
      id: 'e-${day.toIso8601String()}',
      profileId: 'p',
      nodeId: 'a',
      unitIndex: 2,
      action: EventAction.done,
      occurredAt: day,
      loggedAt: day,
    );

void main() {
  final now = DateTime(2026, 1, 10, 15);

  test('no reminder when disabled', () {
    expect(
        RemindersPolicy.shouldRemind(enabled: false, events: const [], now: now),
        isFalse);
  });

  test('reminder when enabled and nothing learned today', () {
    final events = [done(DateTime(2026, 1, 9))];
    expect(RemindersPolicy.shouldRemind(enabled: true, events: events, now: now),
        isTrue);
  });

  test('no reminder when something was learned today', () {
    final events = [done(DateTime(2026, 1, 10, 8))];
    expect(RemindersPolicy.shouldRemind(enabled: true, events: events, now: now),
        isFalse);
  });
}
