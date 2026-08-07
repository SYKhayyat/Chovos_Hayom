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

  /// The three settings that belong to the **device**, not to a learner.
  ///
  /// Language, theme and calendar were per-profile like everything else, which
  /// meant creating a second profile flipped the whole app to English and
  /// left-to-right: a Hebrew-only user setting up a profile for their son landed
  /// in an English settings screen to find the toggle back, unable to read the
  /// way out. They are chrome — how this device presents itself — rather than
  /// facts about someone's learning, and they are shared.
  ///
  /// Consequences, all deliberate: they do not ride in a backup (a file from
  /// someone else's phone must not change your language), and *Clear settings*,
  /// which resets one profile, leaves them alone.
  static const deviceWide = [calendarMode, themeMode, hebrewLayout];

  /// Set once the one-time move of language/theme/calendar out of the active
  /// profile has run. See `SettingsNotifier`.
  static const deviceWideMigrated = 'deviceWideSettingsMigrated';

  /// Every setting that belongs to a profile rather than the device.
  ///
  /// This is the list a *backup* and *Clear settings* walk: things the learner
  /// chose. It is deliberately not the same list as [ownedBy] — see there.
  static const perProfile = [
    reminderEnabled,
    sortMetric,
    sortDescending,
    sortLevel,
    chazaraIntervals,
    hiddenMeforishBars,
    cycles,
    backupReminderEnabled,
    backupIntervalDays,
  ];

  /// Per-profile **state**, as opposed to per-profile settings.
  ///
  /// Neither of these is something the learner chose, so neither rides in a
  /// backup and neither is reset by *Clear settings* — but both belong to the
  /// profile and both go when it does. They were named one at a time at the
  /// delete site, in a comment explaining that they are not in [perProfile];
  /// naming them here is what makes the next one of them impossible to forget.
  static const perProfileState = [sessionTimer, lastBackupAt];

  /// The profile-scoped form of [key].
  static String scoped(String profileId, String key) => '$profileId/$key';

  /// Where one profile's target finish dates live. Profile-scoped rather than a
  /// fixed key, so goals follow the profile they belong to — and so deleting a
  /// profile has a single key to remove.
  static String goalsFor(String profileId) => 'goals:$profileId';

  /// **Every preference key [profileId] owns.** The one list a profile deletion
  /// walks.
  ///
  /// Deleting a profile touches two stores. The repository cascades its five
  /// tables; nothing cascades preferences, because [AppPreferences] cannot
  /// enumerate keys — so a key left behind here outlives the profile forever,
  /// and a new profile that happened to reuse the id would inherit a stranger's
  /// calendar, cycles, sort order and target dates.
  ///
  /// That has already happened once: goals were the only removal here for a
  /// long time, then `cycles` and nine other keys were added *next to* them and
  /// orphaned on every delete. Looping [perProfile] fixed those nine and left
  /// three keys still named by hand at the call site — two because they are
  /// state rather than settings, one because it has its own key shape. Three
  /// hand-written exceptions is where the next one goes missing.
  ///
  /// `profile_delete_test.dart` holds every key `PrefKeys` declares to this
  /// list, so a key that is neither app-wide nor device-wide nor here fails the
  /// build rather than the user.
  static List<String> ownedBy(String profileId) => [
        for (final key in perProfile) scoped(profileId, key),
        for (final key in perProfileState) scoped(profileId, key),
        goalsFor(profileId),
      ];
}
