import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/backup_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one gap that could cost a user everything.
///
/// Android's automatic cloud backup is deliberately off — leaving it on would
/// copy every daf and every haara to a Google account unasked — which makes the
/// app's own export the only copy that survives a lost phone. Nothing ever
/// mentioned that. This is the policy that does.
LearningEvent event(
  String node,
  int unit, {
  required DateTime loggedAt,
  EventAction action = EventAction.done,
}) =>
    LearningEvent(
      id: '$node-$unit-${loggedAt.microsecondsSinceEpoch}-${action.name}',
      profileId: 'p',
      nodeId: node,
      unitIndex: unit,
      action: action,
      occurredAt: loggedAt,
      loggedAt: loggedAt,
    );

void main() {
  final now = DateTime(2026, 3, 1, 10);

  BackupStatus evaluate({
    DateTime? lastBackupAt,
    List<LearningEvent> events = const [],
    int intervalDays = 14,
    bool enabled = true,
  }) =>
      BackupReminder.evaluate(
        enabled: enabled,
        lastBackupAt: lastBackupAt,
        intervalDays: intervalDays,
        events: events,
        now: now,
      );

  test('a profile that has never been exported, with learning in it, is due', () {
    final status = evaluate(
      events: [event('shabbos', 2, loggedAt: DateTime(2026, 2, 20))],
    );

    expect(status.neverBackedUp, isTrue);
    expect(status.unsavedUnits, 1);
    expect(status.daysSinceBackup, isNull);
    expect(status.due, isTrue);
  });

  test('an empty profile is never due — there is nothing to lose', () {
    // A fresh install must not open on a warning about data that doesn't exist.
    expect(evaluate().due, isFalse);
    expect(evaluate().unsavedUnits, 0);
  });

  test('nothing recorded since the backup is never due, however old it is', () {
    // The "finished" case: someone who exported and then stopped must not be
    // nagged forever about a backup that is still complete.
    final status = evaluate(
      lastBackupAt: DateTime(2020, 1, 1),
      events: [event('shabbos', 2, loggedAt: DateTime(2019, 12, 31))],
    );

    expect(status.unsavedUnits, 0);
    expect(status.daysSinceBackup, greaterThan(2000));
    expect(status.due, isFalse,
        reason: 'the backup still contains everything there is');
  });

  test('unsaved learning inside the interval is counted but not yet due', () {
    final status = evaluate(
      lastBackupAt: DateTime(2026, 2, 25),
      events: [event('shabbos', 2, loggedAt: DateTime(2026, 2, 26))],
      intervalDays: 14,
    );

    expect(status.unsavedUnits, 1);
    expect(status.daysSinceBackup, 4);
    expect(status.due, isFalse);
  });

  test('unsaved learning past the interval is due', () {
    final status = evaluate(
      lastBackupAt: DateTime(2026, 2, 1),
      events: [event('shabbos', 2, loggedAt: DateTime(2026, 2, 20))],
      intervalDays: 14,
    );

    expect(status.daysSinceBackup, 28);
    expect(status.due, isTrue);
  });

  test('the count is units, not events', () {
    // The log is internal. One daf marked, un-marked and marked again is one
    // thing at risk — reporting "3" would be true of the log and wrong to a
    // reader, the same mistake the restore summary was fixed for.
    final status = evaluate(
      lastBackupAt: DateTime(2026, 2, 1),
      events: [
        event('shabbos', 2, loggedAt: DateTime(2026, 2, 10)),
        event('shabbos', 2,
            loggedAt: DateTime(2026, 2, 11), action: EventAction.undone),
        event('shabbos', 2, loggedAt: DateTime(2026, 2, 12)),
        event('shabbos', 3, loggedAt: DateTime(2026, 2, 13)),
      ],
    );

    expect(status.unsavedUnits, 2);
  });

  test('only what the backup does not already contain counts', () {
    final status = evaluate(
      lastBackupAt: DateTime(2026, 2, 10),
      events: [
        event('shabbos', 2, loggedAt: DateTime(2026, 2, 1)), // in the backup
        event('shabbos', 3, loggedAt: DateTime(2026, 2, 11)), // not
      ],
    );

    expect(status.unsavedUnits, 1);
  });

  test('it is keyed on when a thing was recorded, not when it was learned', () {
    // Backdating this morning's session to last week is still a change made
    // today that the last export does not have.
    final backdated = LearningEvent(
      id: 'backdated',
      profileId: 'p',
      nodeId: 'shabbos',
      unitIndex: 4,
      action: EventAction.done,
      occurredAt: DateTime(2026, 1, 1), // long before the backup
      loggedAt: DateTime(2026, 2, 28), // recorded after it
    );

    final status =
        evaluate(lastBackupAt: DateTime(2026, 2, 1), events: [backdated]);

    expect(status.unsavedUnits, 1);
    expect(status.due, isTrue);
  });

  test('turning the reminder off silences it without hiding the facts', () {
    final status = evaluate(
      enabled: false,
      lastBackupAt: DateTime(2026, 1, 1),
      events: [event('shabbos', 2, loggedAt: DateTime(2026, 2, 20))],
    );

    expect(status.due, isFalse);
    // The Settings screen still shows where you stand — the toggle governs
    // whether the app volunteers it, not whether it is true.
    expect(status.unsavedUnits, 1);
    expect(status.daysSinceBackup, 59);
  });

  test('a backup taken earlier today is zero days old, not one', () {
    // Compared by calendar date, so the age does not round up overnight.
    final status = evaluate(
      lastBackupAt: DateTime(2026, 3, 1, 2),
      events: [event('shabbos', 2, loggedAt: DateTime(2026, 3, 1, 9))],
      intervalDays: 1,
    );

    expect(status.daysSinceBackup, 0);
    expect(status.due, isFalse);
  });
}
