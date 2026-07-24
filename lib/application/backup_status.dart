import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/preferences.dart';
import '../domain/usecases/backup_reminder.dart';
import 'providers.dart';
import 'settings.dart';
import 'stats.dart';

/// When the active profile was last exported.
///
/// Written only after an export has actually succeeded — it goes through the
/// same rule as everything else the app records: a backup that failed, or a save
/// dialog the user cancelled, must not mark the profile safe. That is the whole
/// value of this timestamp; a "last backed up: today" that isn't true is worse
/// than no timestamp at all, because it silences the one warning that would have
/// told them.
class LastBackupController extends Notifier<DateTime?> {
  late String _profileId;

  String get _key => PrefKeys.scoped(_profileId, PrefKeys.lastBackupAt);

  @override
  DateTime? build() {
    _profileId = ref.watch(activeProfileProvider);
    final raw = ref.watch(appPreferencesProvider).getString(_key);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Record that an export of this profile succeeded at [at].
  Future<void> record(DateTime at) async {
    await ref
        .read(appPreferencesProvider)
        .setString(_key, at.toIso8601String());
    state = at;
  }
}

final lastBackupProvider =
    NotifierProvider<LastBackupController, DateTime?>(LastBackupController.new);

/// What the active profile stands to lose right now.
///
/// Derived, like everything else: the log says what has been recorded, the
/// timestamp says what the last export covered, and the difference is the
/// answer. Nothing about "how much is unsaved" is stored, so it cannot drift.
final backupStatusProvider = Provider<BackupStatus>((ref) {
  final settings = ref.watch(settingsProvider);
  return BackupReminder.evaluate(
    enabled: settings.backupReminderEnabled,
    lastBackupAt: ref.watch(lastBackupProvider),
    intervalDays: settings.backupIntervalDays,
    events: ref.watch(eventsProvider).asData?.value ?? const [],
    now: ref.watch(clockProvider)(),
  );
});
