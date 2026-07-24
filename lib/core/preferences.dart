/// Simple synchronous key-value store for app-level preferences (active profile,
/// calendar mode, theme). Abstracted so tests use an in-memory implementation.
abstract interface class AppPreferences {
  String? getString(String key);
  Future<void> setString(String key, String value);

  /// Delete a key outright. Distinct from writing an empty string: profile
  /// deletion must leave nothing behind, not an empty orphan.
  Future<void> remove(String key);
}

class InMemoryPreferences implements AppPreferences {
  InMemoryPreferences([Map<String, String>? seed]) : _m = {...?seed};
  final Map<String, String> _m;

  @override
  String? getString(String key) => _m[key];

  @override
  Future<void> setString(String key, String value) async => _m[key] = value;

  @override
  Future<void> remove(String key) async => _m.remove(key);
}

/// Well-known preference keys.
///
/// Most settings are **per-profile**: two people sharing a device get their own
/// calendar, theme, sort, chazara intervals and meforish bars, the same way they
/// already get their own learning. [scoped] builds those keys; only
/// [activeProfileId] and [settingsScopedMigrated] are genuinely app-wide.
class PrefKeys {
  static const activeProfileId = 'activeProfileId';
  static const calendarMode = 'calendarMode';
  static const themeMode = 'themeMode';
  static const reminderEnabled = 'reminderEnabled';
  static const hebrewLayout = 'hebrewLayout';
  static const sortMetric = 'sortMetric';
  static const sortDescending = 'sortDescending';
  static const sortLevel = 'sortLevel';
  static const chazaraIntervals = 'chazaraIntervals';

  /// Comma-separated layer ids whose per-meforish coverage line is hidden in the
  /// tree. Absent/empty means every enabled meforish shows its bar.
  static const hiddenMeforishBars = 'hiddenMeforishBars';

  /// Whether to say anything when there is learning the last export doesn't
  /// contain. On by default: the app's export is the only copy of a user's
  /// history that survives a lost device, so silence is the dangerous default.
  static const backupReminderEnabled = 'backupReminderEnabled';

  /// How many days of unsaved learning to tolerate before saying so.
  static const backupIntervalDays = 'backupIntervalDays';

  /// The in-flight learning session (JSON). Persisted so a timer survives the
  /// sheet being dismissed, the app being backgrounded, and the process dying.
  static const sessionTimer = 'sessionTimer';

  /// The profile's learning cycles: which built-ins are hidden, their own
  /// cycles, and any sefer-name mappings (JSON).
  static const cycles = 'cycles';

  /// Set once the one-time move of the old device-wide settings into the active
  /// profile has run. See `SettingsNotifier`.
  static const settingsScopedMigrated = 'settingsScopedMigrated';

  /// When this profile was last exported (ISO-8601), or absent if it never has
  /// been.
  ///
  /// Deliberately *not* in [perProfile]: it is per-profile **state**, like the
  /// session timer, not a setting. It does not ride in a backup — "when you last
  /// backed up" is a fact about this device, and restoring a year-old file onto
  /// a new phone must not tell you that phone is safe — and *Clear settings*
  /// leaves it alone, because forgetting it would silence the reminder for a
  /// whole interval at the exact moment a user has just reset things.
  static const lastBackupAt = 'lastBackupAt';

  /// Every setting that belongs to a profile rather than the device.
  static const perProfile = [
    calendarMode,
    themeMode,
    reminderEnabled,
    hebrewLayout,
    sortMetric,
    sortDescending,
    sortLevel,
    chazaraIntervals,
    hiddenMeforishBars,
    cycles,
    backupReminderEnabled,
    backupIntervalDays,
  ];

  /// The profile-scoped form of [key].
  static String scoped(String profileId, String key) => '$profileId/$key';

  /// Where one profile's target finish dates live. Profile-scoped rather than a
  /// fixed key, so goals follow the profile they belong to — and so deleting a
  /// profile has a single key to remove.
  static String goalsFor(String profileId) => 'goals:$profileId';
}
