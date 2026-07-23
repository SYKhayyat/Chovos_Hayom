import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calendar.dart';
import '../core/preferences.dart';
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
  });

  final CalendarMode calendar;
  final ThemeMode themeMode;
  final bool reminderEnabled;

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
  }) =>
      SettingsState(
        calendar: calendar ?? this.calendar,
        themeMode: themeMode ?? this.themeMode,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        hebrewLayout: hebrewLayout ?? this.hebrewLayout,
        sort: sort ?? this.sort,
        chazaraIntervals: chazaraIntervals ?? this.chazaraIntervals,
        hiddenMeforishBars: hiddenMeforishBars ?? this.hiddenMeforishBars,
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
    return _load();
  }

  /// Reads a per-profile setting.
  String? _get(String key) =>
      ref.read(appPreferencesProvider).getString(PrefKeys.scoped(_profileId, key));

  Future<void> _set(String key, String value) => ref
      .read(appPreferencesProvider)
      .setString(PrefKeys.scoped(_profileId, key), value);

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
    );
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

  Future<void> setCalendar(CalendarMode mode) async {
    await _set(PrefKeys.calendarMode, mode.name);
    state = state.copyWith(calendar: mode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _set(PrefKeys.themeMode, mode.name);
    state = state.copyWith(themeMode: mode);
  }

  /// Serialise all preferences (for a backup), keyed by their pref keys.
  Map<String, dynamic> toBackup() => {
        PrefKeys.calendarMode: state.calendar.name,
        PrefKeys.themeMode: state.themeMode.name,
        PrefKeys.reminderEnabled: state.reminderEnabled.toString(),
        PrefKeys.hebrewLayout: state.hebrewLayout.toString(),
        PrefKeys.sortMetric: state.sort.metric.name,
        PrefKeys.sortDescending: state.sort.descending.toString(),
        PrefKeys.sortLevel: state.sort.level?.toString() ?? '',
        PrefKeys.chazaraIntervals: state.chazaraIntervals.join(','),
        PrefKeys.hiddenMeforishBars: state.hiddenMeforishBars.join(','),
      };

  /// Apply a serialised preferences map (from an imported backup) to the active
  /// profile. Backups store bare keys, so importing one into a different profile
  /// lands on that profile rather than on the device.
  Future<void> applyBackup(Map<String, dynamic> settings) async {
    if (settings.isEmpty) return;
    for (final entry in settings.entries) {
      await _set(entry.key, entry.value.toString());
    }
    state = _load();
  }

  /// Reset this profile's preferences to their defaults, leaving other profiles
  /// alone. Removing the keys rather than writing default *values* means a later
  /// change to a default is actually picked up.
  Future<void> clearAll() async {
    final prefs = ref.read(appPreferencesProvider);
    for (final key in PrefKeys.perProfile) {
      await prefs.remove(PrefKeys.scoped(_profileId, key));
    }
    state = const SettingsState();
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
