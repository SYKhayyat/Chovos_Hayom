import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calendar.dart';
import '../core/preferences.dart';
import '../domain/usecases/backup_reminder.dart';
import '../domain/usecases/chazara_schedule.dart';
import 'providers.dart';
import 'sorting.dart';

/// App-wide, user-configurable settings, persisted via [AppPreferences].
class SettingsState {
  const SettingsState({
    this.calendar = CalendarMode.gregorian,
    this.themeMode = ThemeMode.system,
    this.reminderEnabled = false,
    this.hebrewLayout = false,
    this.sort = const SortConfig(),
    this.chazaraIntervals = ChazaraSchedule.defaultIntervals,
    this.hiddenMeforishBars = const {},
    this.backupReminderEnabled = true,
    this.backupIntervalDays = BackupReminder.defaultIntervalDays,
  });

  final CalendarMode calendar;
  final ThemeMode themeMode;
  final bool reminderEnabled;

  /// Whether to point out that there is learning no export contains. Defaults
  /// **on**: the export is the only copy that survives a lost device, so the
  /// safe default is the one that speaks up.
  final bool backupReminderEnabled;

  /// Days of unsaved learning tolerated before the reminder appears.
  final int backupIntervalDays;

  /// When true, the whole app renders in Hebrew (right-to-left) layout. Optional.
  final bool hebrewLayout;

  /// How the catalog tree's children are ordered.
  final SortConfig sort;

  /// Spaced-repetition intervals (days) for the chazara schedule, user-editable.
  final List<int> chazaraIntervals;

  /// Layer ids whose per-meforish coverage line is hidden in the tree. Empty
  /// means every enabled meforish shows its bar.
  final Set<String> hiddenMeforishBars;

  /// Whether [layerId]'s tree coverage line should render.
  bool showsMeforishBar(String layerId) => !hiddenMeforishBars.contains(layerId);

  SettingsState copyWith({
    CalendarMode? calendar,
    ThemeMode? themeMode,
    bool? reminderEnabled,
    bool? hebrewLayout,
    SortConfig? sort,
    List<int>? chazaraIntervals,
    Set<String>? hiddenMeforishBars,
    bool? backupReminderEnabled,
    int? backupIntervalDays,
  }) =>
      SettingsState(
        calendar: calendar ?? this.calendar,
        themeMode: themeMode ?? this.themeMode,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        hebrewLayout: hebrewLayout ?? this.hebrewLayout,
        sort: sort ?? this.sort,
        chazaraIntervals: chazaraIntervals ?? this.chazaraIntervals,
        hiddenMeforishBars: hiddenMeforishBars ?? this.hiddenMeforishBars,
        backupReminderEnabled:
            backupReminderEnabled ?? this.backupReminderEnabled,
        backupIntervalDays: backupIntervalDays ?? this.backupIntervalDays,
      );
}

class SettingsNotifier extends Notifier<SettingsState> {
  /// The profile whose settings these are. Watched, so switching profiles
  /// re-reads that profile's settings instead of carrying the previous user's
  /// calendar, theme and RTL over to them.
  late String _profileId;

  @override
  SettingsState build() {
    _profileId = ref.watch(activeProfileProvider);
    _migrateDeviceWideSettings();
    _migrateChromeBackToTheDevice();
    return _load();
  }

  /// Where [key] lives: bare for the three device-wide settings, prefixed with
  /// the profile for everything else. One place decides, so a reader and a
  /// writer cannot disagree about which store a setting is in.
  String _keyFor(String key) =>
      PrefKeys.deviceWide.contains(key) ? key : PrefKeys.scoped(_profileId, key);

  String? _get(String key) =>
      ref.read(appPreferencesProvider).getString(_keyFor(key));

  Future<void> _set(String key, String value) =>
      ref.read(appPreferencesProvider).setString(_keyFor(key), value);

  /// One-time move of the old device-wide settings onto whichever profile was
  /// active when the app upgraded.
  ///
  /// Settings used to be global while the data they described was per-profile.
  /// The person those settings belong to keeps them; every other profile starts
  /// from the defaults rather than inheriting a stranger's. The legacy keys are
  /// removed so this can only happen once.
  void _migrateDeviceWideSettings() {
    final prefs = ref.read(appPreferencesProvider);
    if (prefs.getString(PrefKeys.settingsScopedMigrated) == 'true') return;
    for (final key in PrefKeys.perProfile) {
      final legacy = prefs.getString(key);
      if (legacy == null) continue;
      prefs.setString(PrefKeys.scoped(_profileId, key), legacy);
      prefs.remove(key);
    }
    prefs.setString(PrefKeys.settingsScopedMigrated, 'true');
  }

  /// The other half of that move, undone for three of the keys.
  ///
  /// Language, theme and calendar went per-profile with everything else, and
  /// that was wrong for them: switching profiles switched the app's language, so
  /// a Hebrew-only user creating a profile for their son landed in an English,
  /// left-to-right settings screen and had to find the toggle back without being
  /// able to read it.
  ///
  /// Whoever was active when the app upgraded keeps their three settings, and
  /// they become the device's. Their scoped copies are removed so the bare key is
  /// the only answer; the *other* profiles' scoped copies are simply never read
  /// again — [AppPreferences] cannot enumerate keys, so they cannot be found to
  /// delete, and a stale key nothing reads is inert.
  void _migrateChromeBackToTheDevice() {
    final prefs = ref.read(appPreferencesProvider);
    if (prefs.getString(PrefKeys.deviceWideMigrated) == 'true') return;
    for (final key in PrefKeys.deviceWide) {
      final scoped = prefs.getString(PrefKeys.scoped(_profileId, key));
      if (scoped != null) {
        prefs.setString(key, scoped);
        prefs.remove(PrefKeys.scoped(_profileId, key));
      }
    }
    prefs.setString(PrefKeys.deviceWideMigrated, 'true');
  }

  SettingsState _load() {
    return SettingsState(
      calendar: _enumByName(CalendarMode.values, _get(PrefKeys.calendarMode),
          fallback: CalendarMode.gregorian),
      themeMode: _enumByName(ThemeMode.values, _get(PrefKeys.themeMode),
          fallback: ThemeMode.system),
      reminderEnabled: _get(PrefKeys.reminderEnabled) == 'true',
      hebrewLayout: _get(PrefKeys.hebrewLayout) == 'true',
      sort: SortConfig(
        metric: _enumByName(SortMetric.values, _get(PrefKeys.sortMetric),
            fallback: SortMetric.catalog),
        descending: _get(PrefKeys.sortDescending) == 'true',
        level: int.tryParse(_get(PrefKeys.sortLevel) ?? ''),
      ),
      chazaraIntervals: _parseIntervals(_get(PrefKeys.chazaraIntervals)),
      hiddenMeforishBars: _parseIdSet(_get(PrefKeys.hiddenMeforishBars)),
      // Absent reads as ON — an install that predates this setting is exactly
      // the one whose learning has never been exported.
      backupReminderEnabled: _get(PrefKeys.backupReminderEnabled) != 'false',
      backupIntervalDays: _parsePositive(_get(PrefKeys.backupIntervalDays),
          fallback: BackupReminder.defaultIntervalDays),
    );
  }

  static int _parsePositive(String? raw, {required int fallback}) {
    final n = int.tryParse(raw?.trim() ?? '');
    return (n == null || n <= 0) ? fallback : n;
  }

  static Set<String> _parseIdSet(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    return {
      for (final part in raw.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    };
  }

  static List<int> _parseIntervals(String? raw) {
    if (raw == null || raw.trim().isEmpty) return ChazaraSchedule.defaultIntervals;
    final parsed = [
      for (final part in raw.split(','))
        if (int.tryParse(part.trim()) case final n?) if (n > 0) n,
    ];
    return parsed.isEmpty ? ChazaraSchedule.defaultIntervals : parsed;
  }

  Future<void> setChazaraIntervals(List<int> intervals) async {
    final clean = intervals.where((n) => n > 0).toList();
    final effective = clean.isEmpty ? ChazaraSchedule.defaultIntervals : clean;
    await _set(PrefKeys.chazaraIntervals, effective.join(','));
    state = state.copyWith(chazaraIntervals: effective);
  }

  /// Show or hide a single meforish's coverage line in the tree.
  Future<void> setMeforishBarVisible(String layerId, bool visible) async {
    final next = {...state.hiddenMeforishBars};
    if (visible) {
      next.remove(layerId);
    } else {
      next.add(layerId);
    }
    await _set(PrefKeys.hiddenMeforishBars, next.join(','));
    state = state.copyWith(hiddenMeforishBars: next);
  }

  Future<void> setSort(SortConfig config) async {
    await _set(PrefKeys.sortMetric, config.metric.name);
    await _set(PrefKeys.sortDescending, config.descending.toString());
    await _set(PrefKeys.sortLevel, config.level?.toString() ?? '');
    state = state.copyWith(sort: config);
  }

  Future<void> setHebrewLayout(bool enabled) async {
    await _set(PrefKeys.hebrewLayout, enabled.toString());
    state = state.copyWith(hebrewLayout: enabled);
  }

  Future<void> setReminderEnabled(bool enabled) async {
    await _set(PrefKeys.reminderEnabled, enabled.toString());
    state = state.copyWith(reminderEnabled: enabled);
  }

  Future<void> setBackupReminderEnabled(bool enabled) async {
    await _set(PrefKeys.backupReminderEnabled, enabled.toString());
    state = state.copyWith(backupReminderEnabled: enabled);
  }

  Future<void> setBackupIntervalDays(int days) async {
    final effective = days > 0 ? days : BackupReminder.defaultIntervalDays;
    await _set(PrefKeys.backupIntervalDays, effective.toString());
    state = state.copyWith(backupIntervalDays: effective);
  }

  Future<void> setCalendar(CalendarMode mode) async {
    await _set(PrefKeys.calendarMode, mode.name);
    state = state.copyWith(calendar: mode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _set(PrefKeys.themeMode, mode.name);
    state = state.copyWith(themeMode: mode);
  }

  /// Serialise all preferences (for a backup), keyed by their pref keys.
  ///
  /// This must cover every key in [PrefKeys.perProfile]; a missing one is a
  /// per-profile setting that silently doesn't survive export → clear → import.
  /// `settings_test.dart` asserts the coverage so the next key added here can't
  /// be forgotten — cycles were, once.
  ///
  /// [PrefKeys.deviceWide] is deliberately absent: language, theme and calendar
  /// describe this device, not this learner's progress. A backup carried to
  /// someone else's phone must not flip their app into a language they do not
  /// read.
  Map<String, dynamic> toBackup() => {
        PrefKeys.reminderEnabled: state.reminderEnabled.toString(),
        PrefKeys.sortMetric: state.sort.metric.name,
        PrefKeys.sortDescending: state.sort.descending.toString(),
        PrefKeys.sortLevel: state.sort.level?.toString() ?? '',
        PrefKeys.chazaraIntervals: state.chazaraIntervals.join(','),
        PrefKeys.hiddenMeforishBars: state.hiddenMeforishBars.join(','),
        PrefKeys.backupReminderEnabled: state.backupReminderEnabled.toString(),
        PrefKeys.backupIntervalDays: state.backupIntervalDays.toString(),
        // Learning cycles aren't part of SettingsState — CyclesController owns
        // them — but they are a per-profile preference, so they travel with the
        // backup like the rest. Read straight from the pref; '' for a profile
        // with no cycles yet, which imports back as "no cycles".
        PrefKeys.cycles: ref
                .read(appPreferencesProvider)
                .getString(PrefKeys.scoped(_profileId, PrefKeys.cycles)) ??
            '',
      };

  /// Apply a serialised preferences map (from an imported backup) to the active
  /// profile. Backups store bare keys, so importing one into a different profile
  /// lands on that profile rather than on the device.
  /// Older backups (and this one, before language/theme/calendar became the
  /// device's) carry those three keys. They are skipped rather than applied:
  /// importing a file must not change how this device presents itself, and a
  /// backup from a Hebrew reader's phone must not leave an English reader
  /// looking for a toggle they can no longer read.
  Future<void> applyBackup(Map<String, dynamic> settings) async {
    if (settings.isEmpty) return;
    for (final entry in settings.entries) {
      if (PrefKeys.deviceWide.contains(entry.key)) continue;
      await _set(entry.key, entry.value.toString());
    }
    state = _load();
  }

  /// Reset this profile's preferences to their defaults, leaving other profiles
  /// alone. Removing the keys rather than writing default *values* means a later
  /// change to a default is actually picked up.
  ///
  /// Language, theme and calendar survive: they belong to the device, and this
  /// action resets one profile. Resetting them would also mean a Hebrew reader
  /// pressing "Clear settings" ends up in English — a reset that changes what
  /// language you are reading is not one anybody asked for.
  Future<void> clearAll() async {
    final prefs = ref.read(appPreferencesProvider);
    for (final key in PrefKeys.perProfile) {
      await prefs.remove(PrefKeys.scoped(_profileId, key));
    }
    state = _load();
  }
}

T _enumByName<T extends Enum>(List<T> values, String? name, {required T fallback}) {
  if (name == null) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
