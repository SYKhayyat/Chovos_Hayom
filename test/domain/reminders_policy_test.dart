import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/log_activity.dart';
import 'package:chovos_hayom/domain/usecases/reminders_policy.dart';
import 'package:flutter_test/flutter_test.dart';

LearningEvent done(DateTime day, {DateTime? logged}) => LearningEvent(
      id: 'e-${day.toIso8601String()}-${logged?.toIso8601String() ?? ''}',
      profileId: 'p',
      nodeId: 'a',
      unitIndex: 2,
      action: EventAction.done,
      occurredAt: day,
      loggedAt: logged ?? day,
    );

void main() {
  final today = Day.of(DateTime(2026, 1, 10, 15));

  test('no reminder when disabled', () {
    expect(
        RemindersPolicy.shouldRemind(
            enabled: false, activity: LogActivity.empty, today: today),
        isFalse);
  });

  test('reminder when enabled and nothing recorded today', () {
    final activity = LogActivity.of([done(DateTime(2026, 1, 9))]);
    expect(
        RemindersPolicy.shouldRemind(
            enabled: true, activity: activity, today: today),
        isTrue);
  });

  test('no reminder when something was recorded today', () {
    final activity = LogActivity.of([done(DateTime(2026, 1, 10, 8))]);
    expect(
        RemindersPolicy.shouldRemind(
            enabled: true, activity: activity, today: today),
        isFalse);
  });

  test('a session backdated to yesterday still counts as activity today', () {
    // The axis this reads is `loggedAt`, not `occurredAt` — writing up last
    // night's seder this morning is a thing you did today, and nudging someone
    // who just recorded something is the failure this distinction prevents.
    final activity = LogActivity.of([
      done(DateTime(2026, 1, 9, 21), logged: DateTime(2026, 1, 10, 7)),
    ]);
    expect(
        RemindersPolicy.shouldRemind(
            enabled: true, activity: activity, today: today),
        isFalse);
  });
}
