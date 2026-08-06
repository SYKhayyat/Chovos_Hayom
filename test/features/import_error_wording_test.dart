import 'package:flutter_test/flutter_test.dart';

import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/entities/profile.dart';
import 'package:chovos_hayom/features/settings/settings_screen.dart';
import 'package:chovos_hayom/l10n/generated/app_localizations_en.dart';

import '../support/failing_progress_repository.dart';

/// GRADER PROBE — when an import fails, the app tells the user their backup file
/// is unreadable.
///
/// This was the user-visible half of the event-id collision in
/// `event_id_collision_test.dart`. That probe proved the insert threw; this one
/// is about what the person holding the only copy of their learning is then
/// told.
///
/// Reproduced on hardware. Export from "Default", switch to a second profile,
/// Settings -> "Import from file", choose the file just written: a snackbar
/// reading
///
///   Import failed: the file could not be read.        [Details]
///
/// and the same line in the in-app crash log, above the real cause:
///
///   SqliteException(1555): while executing statement, UNIQUE constraint
///   failed: learning_events.id, constraint failed (code 1555)
///
/// The file was read perfectly — parsed, validated, and its events on their way
/// into a transaction. The failure was the app's own schema. Blaming the file is
/// worse than a bare error: `settingsRestoreFileSubtitle` and the reminder copy
/// both tell the user this export is "the only copy that survives losing it",
/// and this message tells them that copy is corrupt. The reasonable response is
/// to delete it and make another — which failed in exactly the same way.
///
/// Mechanism — `settings_screen.dart`:
///
///   static String importError(AppLocalizations l10n, Object e) =>
///       e is BackupFormatException
///           ? l10n.backupImportFailed(e.message)
///           : l10n.backupImportUnreadable;
///
/// A `SqliteException` is not a `BackupFormatException`, so every failure that is
/// *ours* fell through to the branch that describes the file. Three unrelated
/// causes — a malformed file, a bug in the app, and a genuinely unreadable file —
/// collapsed into one sentence, and it named the only one that is the user's
/// fault.
///
/// **BUILDER NOTE (W1).** The collision itself is fixed — the primary key is now
/// `{profileId, id}` — so this probe can no longer get its failure by importing
/// across profiles. It was written to be deleted at that point. It is kept and
/// re-pointed instead, because the wording defect is not the collision: *any*
/// failure inside the write is still reported by the same function, and the next
/// one to appear there would be laundered identically. The failure is now
/// injected, which is the only way to hold the invariant without a live bug.
void main() {
  final l10n = AppLocalizationsEn();

  LearningEvent event(String id, String profileId) => LearningEvent(
        id: id,
        profileId: profileId,
        nodeId: 'shabbosShas',
        unitIndex: 2,
        action: EventAction.done,
        occurredAt: DateTime(2026, 7, 30),
        loggedAt: DateTime(2026, 7, 30),
        layers: const [mainLayerId],
      );

  test('a failure that is the app\'s own is not reported as an unreadable file',
      () async {
    // Disarmed while the fixture is built, then armed for the import — the
    // write has to succeed once so there is something to export.
    final repo = FailingProgressRepository(failWrites: false);
    await repo.addProfile(
        Profile(id: 'p1', name: 'Reuven', createdAt: DateTime(2026)));
    await repo.addProfile(
        Profile(id: 'p2', name: 'Shimon', createdAt: DateTime(2026)));
    await repo.addEvent(event('evt-1', 'p1'));

    final service = BackupService(repo);
    final json = await service.export('p1', customNodes: const []);
    repo.failWrites = true;

    Object? thrown;
    try {
      await service.importInto('p2', json);
    } catch (e) {
      thrown = e;
    }

    expect(thrown, isNotNull, reason: 'the injected write failure must surface');
    expect(
      SettingsScreen.importError(l10n, thrown!),
      isNot(l10n.backupImportUnreadable),
      reason: 'the file was read, parsed and validated; what failed was inside '
          'the app. Telling the user their only backup "could not be read" '
          'invites them to throw it away',
    );
    expect(SettingsScreen.importError(l10n, thrown), l10n.backupImportAppFailure,
        reason: 'and it should say whose fault it was');
  });

  test('a file that really cannot be read still says so', () async {
    // The other half of the same rule: narrowing the catch-all must not cost the
    // one case the old sentence was true for. `FormatException` is what the utf8
    // decode raises on a binary or half-copied file.
    expect(
      SettingsScreen.importError(l10n, const FormatException('bad utf8')),
      l10n.backupImportUnreadable,
    );
  });

  test('a malformed backup still names the field that is wrong', () async {
    expect(
      SettingsScreen.importError(
          l10n, const BackupFormatException('“events” must be a list.')),
      contains('“events” must be a list.'),
    );
  });
}
