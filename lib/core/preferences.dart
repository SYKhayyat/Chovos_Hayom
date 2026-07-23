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

  /// The in-flight learning session (JSON). Persisted so a timer survives the
  /// sheet being dismissed, the app being backgrounded, and the process dying.
  static const sessionTimer = 'sessionTimer';

  /// The profile's learning cycles: which built-ins are hidden, their own
  /// cycles, and any sefer-name mappings (JSON).
  static const cycles = 'cycles';

  /// Set once the one-time move of the old device-wide settings into the active
  /// profile has run. See `SettingsNotifier`.
  static const settingsScopedMigrated = 'settingsScopedMigrated';

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
  ];

  /// The profile-scoped form of [key].
  static String scoped(String profileId, String key) => '$profileId/$key';

  /// Where one profile's target finish dates live. Profile-scoped rather than a
  /// fixed key, so goals follow the profile they belong to — and so deleting a
  /// profile has a single key to remove.
  static String goalsFor(String profileId) => 'goals:$profileId';
}
