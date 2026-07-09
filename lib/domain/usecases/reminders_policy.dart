import '../entities/learning_event.dart';
import 'pace_engine.dart';

/// Decides whether to nudge the user to learn. Pure; the UI shows an in-app
/// banner when [shouldRemind] is true (OS push notifications are a future,
/// device-only addition).
class RemindersPolicy {
  const RemindersPolicy._();

  /// Keyed on `loggedAt` (when it was recorded), not `occurredAt`: the nudge
  /// asks "did I *record* anything today?", so backdating a session to yesterday
  /// still counts as activity today and won't trigger a false reminder.
  static bool learnedToday(Iterable<LearningEvent> events, DateTime now) =>
      PaceEngine.recordedOn(events, now) > 0;

  static bool shouldRemind({
    required bool enabled,
    required Iterable<LearningEvent> events,
    required DateTime now,
  }) =>
      enabled && !learnedToday(events, now);
}
