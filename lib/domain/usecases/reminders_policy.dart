import '../../core/day.dart';
import 'log_activity.dart';

/// Decides whether to nudge the user to learn. Pure; the UI shows an in-app
/// banner when [shouldRemind] is true (OS push notifications are a future,
/// device-only addition).
class RemindersPolicy {
  const RemindersPolicy._();

  /// Keyed on `loggedAt` (when it was recorded), not `occurredAt`: the nudge
  /// asks "did I *record* anything today?", so backdating a session to yesterday
  /// still counts as activity today and won't trigger a false reminder. That is
  /// the axis [LogActivity.recordedOn] indexes, which is why this takes the
  /// index and not the log — asking the log directly meant walking every event
  /// ever recorded, from a widget `build`, to produce one bool.
  static bool learnedToday(LogActivity activity, Day today) =>
      activity.recordedOn(today) > 0;

  static bool shouldRemind({
    required bool enabled,
    required LogActivity activity,
    required Day today,
  }) =>
      enabled && !learnedToday(activity, today);
}
