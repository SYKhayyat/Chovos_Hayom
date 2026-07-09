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

  SettingsState copyWith({
    CalendarMode? calendar,
    ThemeMode? themeMode,
    bool? reminderEnabled,
    bool? hebrewLayout,
    SortConfig? sort,
    List<int>? chazaraIntervals,
  }) =>
      SettingsState(
        calendar: calendar ?? this.calendar,
        themeMode: themeMode ?? this.themeMode,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        hebrewLayout: hebrewLayout ?? this.hebrewLayout,
        sort: sort ?? this.sort,
        chazaraIntervals: chazaraIntervals ?? this.chazaraIntervals,
      );
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final prefs = ref.watch(appPreferencesProvider);
    return SettingsState(
      calendar: _enumByName(
          CalendarMode.values, prefs.getString(PrefKeys.calendarMode),
          fallback: CalendarMode.gregorian),
      themeMode: _enumByName(
          ThemeMode.values, prefs.getString(PrefKeys.themeMode),
          fallback: ThemeMode.system),
      reminderEnabled: prefs.getString(PrefKeys.reminderEnabled) == 'true',
      hebrewLayout: prefs.getString(PrefKeys.hebrewLayout) == 'true',
      sort: SortConfig(
        metric: _enumByName(SortMetric.values, prefs.getString(PrefKeys.sortMetric),
            fallback: SortMetric.catalog),
        descending: prefs.getString(PrefKeys.sortDescending) == 'true',
        level: int.tryParse(prefs.getString(PrefKeys.sortLevel) ?? ''),
      ),
      chazaraIntervals: _parseIntervals(prefs.getString(PrefKeys.chazaraIntervals)),
    );
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
    await ref
        .read(appPreferencesProvider)
        .setString(PrefKeys.chazaraIntervals, effective.join(','));
    state = state.copyWith(chazaraIntervals: effective);
  }

  Future<void> setSort(SortConfig config) async {
    final prefs = ref.read(appPreferencesProvider);
    await prefs.setString(PrefKeys.sortMetric, config.metric.name);
    await prefs.setString(PrefKeys.sortDescending, config.descending.toString());
    await prefs.setString(PrefKeys.sortLevel, config.level?.toString() ?? '');
    state = state.copyWith(sort: config);
  }

  Future<void> setHebrewLayout(bool enabled) async {
    await ref
        .read(appPreferencesProvider)
        .setString(PrefKeys.hebrewLayout, enabled.toString());
    state = state.copyWith(hebrewLayout: enabled);
  }

  Future<void> setReminderEnabled(bool enabled) async {
    await ref
        .read(appPreferencesProvider)
        .setString(PrefKeys.reminderEnabled, enabled.toString());
    state = state.copyWith(reminderEnabled: enabled);
  }

  Future<void> setCalendar(CalendarMode mode) async {
    await ref
        .read(appPreferencesProvider)
        .setString(PrefKeys.calendarMode, mode.name);
    state = state.copyWith(calendar: mode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await ref
        .read(appPreferencesProvider)
        .setString(PrefKeys.themeMode, mode.name);
    state = state.copyWith(themeMode: mode);
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
