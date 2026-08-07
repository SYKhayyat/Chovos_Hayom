import '../../core/day.dart';
import 'log_activity.dart';

/// Decides whether to nudge the user to learn. Pure; the UI shows an in-app
/// banner when [shouldRemind] is true (OS push notifications are a future,
/// device-only addition).
///
/// **Twenty-five lines with one production caller, and it stays.** The case for
/// folding it into `dashboard_screen` is the line count, and the line count is
/// not what this file is worth. What it holds is the choice of *axis* — the
/// nudge asks "did I **record** anything today", keyed on `loggedAt` and not on
/// `occurredAt` — and that choice is one character away from its opposite,
/// invisible when it is wrong (a backdated session would trigger a reminder the
/// user has already earned their way out of), and stated here where a pure test
/// can hold it. Inside a widget's `build` it would be a condition nobody could
/// test without pumping a screen.
///
/// The other half of this file's original entry in the review — `time_stats.dart`,
/// which was folded away — was folded because half of it had no callers at all.
/// That is a different fact about a different file.
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
