import '../../core/day.dart';
import '../entities/learning_event.dart';

/// What is at stake if this device is lost right now.
class BackupStatus {
  const BackupStatus({
    required this.lastBackupAt,
    required this.unsavedUnits,
    required this.daysSinceBackup,
    required this.due,
  });

  /// When the profile was last exported, or null if it never has been.
  final DateTime? lastBackupAt;

  /// How many distinct units have been touched since then — the thing that
  /// would actually be lost.
  final int unsavedUnits;

  /// Days since the last backup, or null if there has never been one.
  final int? daysSinceBackup;

  /// Whether to say something about it.
  final bool due;

  bool get neverBackedUp => lastBackupAt == null;
}

/// Whether to remind the user to back up, and what is riding on it.
///
/// The app deliberately keeps everything on the device: Android's automatic
/// cloud backup is switched off, because leaving it on would copy the database —
/// every daf, every haara — to a Google account unasked. That is the right call
/// and it has a consequence: the app's own export is the *only* way a user's
/// learning survives a lost phone, and nothing ever asked them to run it. Years
/// of daf yomi could end with a dropped handset and no warning that they were
/// one step from safe.
///
/// So this is the other half of that decision rather than a walk-back of it.
/// Nothing leaves the device; the user is simply told when something is worth
/// saving and how long it has been.
class BackupReminder {
  const BackupReminder._();

  /// The default cadence. Long enough not to nag, short enough that what you
  /// lose is a fortnight rather than a year.
  static const defaultIntervalDays = 14;

  /// Evaluate the profile's backup standing.
  ///
  /// Keyed on `loggedAt` — when a thing was *recorded* — not `occurredAt`.
  /// Backdating a session you learned last week is still a change made today
  /// that the last backup does not contain, and it is the recording that the
  /// export would have captured.
  static BackupStatus evaluate({
    required bool enabled,
    required DateTime? lastBackupAt,
    required int intervalDays,
    required Iterable<LearningEvent> events,
    required DateTime now,
  }) {
    final since = lastBackupAt;
    // Units, not events: the log is internal, and "47 events" means nothing to
    // someone deciding whether this matters. One unit marked, un-marked and
    // marked again is one thing at risk, not three.
    final touched = <String>{};
    for (final e in events) {
      if (since == null || e.loggedAt.isAfter(since)) {
        touched.add('${e.nodeId} ${e.unitIndex}');
      }
    }

    final days = since == null ? null : _wholeDaysBetween(since, now);
    // Nothing recorded since the last export means nothing to lose, however long
    // ago it was — a finished profile must not be nagged forever.
    final overdue = since == null || (days ?? 0) >= intervalDays;

    return BackupStatus(
      lastBackupAt: since,
      unsavedUnits: touched.length,
      daysSinceBackup: days,
      due: enabled && touched.isNotEmpty && overdue,
    );
  }

  /// Whole days between two instants, floored at zero.
  ///
  /// Compared by calendar date rather than by elapsed hours, so "yesterday" is
  /// one day regardless of the clock time, and a backup taken this morning is
  /// zero days old rather than rounding up overnight.
  ///
  /// That promise used to be false one day a year: this took the difference of
  /// two local midnights and read `.inDays`, and the spring-forward day is 23
  /// hours long, which truncates to zero. A backup exactly at the interval read
  /// as a day younger and the reminder went quiet for a day. [Day] subtraction
  /// is integer arithmetic on a day count, so there is no hour to lose.
  static int _wholeDaysBetween(DateTime from, DateTime to) {
    final days = Day.of(to).difference(Day.of(from));
    return days < 0 ? 0 : days;
  }
}
