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

  /// `backupStatusProvider` watches the clock, so this is re-evaluated on every
  /// midnight tick and every return to the foreground. All four fields are
  /// scalars; comparing them is cheaper than rebuilding the banner, the drawer
  /// and the Settings tile to arrive at the same pixels.
  ///
  /// Note what this does *not* buy, because it reads as though it does: an
  /// equal result still costs whatever the derivation cost. That is why
  /// [BackupReminder.unsavedUnitsSince] sits behind its own provider rather
  /// than being recomputed here and then compared away.
  @override
  bool operator ==(Object other) =>
      other is BackupStatus &&
      other.due == due &&
      other.unsavedUnits == unsavedUnits &&
      other.daysSinceBackup == daysSinceBackup &&
      other.lastBackupAt == lastBackupAt;

  @override
  int get hashCode =>
      Object.hash(lastBackupAt, unsavedUnits, daysSinceBackup, due);
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

  /// How many distinct units have been recorded since [since] — the whole of
  /// this file's claim on the raw log, and the only part of the answer that
  /// costs a walk of it.
  ///
  /// Keyed on `loggedAt` — when a thing was *recorded* — not `occurredAt`.
  /// Backdating a session you learned last week is still a change made today
  /// that the last backup does not contain, and it is the recording that the
  /// export would have captured. That is a boundary at an *instant*, which is
  /// why neither day index can answer it and why this is its own axis; see
  /// `log_pass_guard_test.dart`.
  ///
  /// **Separate from [evaluate] because it depends on so much less.** The
  /// standing below is a function of this count, the clock and two settings; the
  /// count is a function of the log and the last export alone. Kept together,
  /// every midnight tick, every return to the foreground and every theme toggle
  /// re-derived the whole thing and therefore walked the entire log to arrive at
  /// a number that none of those can move. Split, the pass runs when a pass is
  /// warranted — the log changed, or a backup was taken.
  static int unsavedUnitsSince(
    Iterable<LearningEvent> events,
    DateTime? since,
  ) {
    // Units, not events: the log is internal, and "47 events" means nothing to
    // someone deciding whether this matters. One unit marked, un-marked and
    // marked again is one thing at risk, not three.
    final touched = <String>{};
    for (final e in events) {
      if (since == null || e.loggedAt.isAfter(since)) {
        touched.add('${e.nodeId} ${e.unitIndex}');
      }
    }
    return touched.length;
  }

  /// Evaluate the profile's backup standing from [unsavedUnits] (see
  /// [unsavedUnitsSince]) and the calendar. Scalars in, scalars out — no log.
  static BackupStatus evaluate({
    required bool enabled,
    required DateTime? lastBackupAt,
    required int intervalDays,
    required int unsavedUnits,
    required DateTime now,
  }) {
    final since = lastBackupAt;
    final days = since == null ? null : _wholeDaysBetween(since, now);
    // Nothing recorded since the last export means nothing to lose, however long
    // ago it was — a finished profile must not be nagged forever.
    final overdue = since == null || (days ?? 0) >= intervalDays;

    return BackupStatus(
      lastBackupAt: since,
      unsavedUnits: unsavedUnits,
      daysSinceBackup: days,
      due: enabled && unsavedUnits > 0 && overdue,
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
