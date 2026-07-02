import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calendar.dart';
import '../core/preferences.dart';
import 'providers.dart';

/// App-wide, user-configurable settings, persisted via [AppPreferences].
class SettingsState {
  const SettingsState({
    this.calendar = CalendarMode.gregorian,
    this.themeMode = ThemeMode.system,
    this.reminderEnabled = false,
  });

  final CalendarMode calendar;
  final ThemeMode themeMode;
  final bool reminderEnabled;

  SettingsState copyWith({
    CalendarMode? calendar,
    ThemeMode? themeMode,
    bool? reminderEnabled,
  }) =>
      SettingsState(
        calendar: calendar ?? this.calendar,
        themeMode: themeMode ?? this.themeMode,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
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
    );
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
