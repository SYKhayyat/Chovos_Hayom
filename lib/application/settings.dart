import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calendar.dart';

/// App-wide, user-configurable settings. Currently in-memory; Phase 3 will
/// persist these per profile via the settings registry.
class SettingsState {
  const SettingsState({
    this.calendar = CalendarMode.gregorian,
    this.themeMode = ThemeMode.system,
  });

  final CalendarMode calendar;
  final ThemeMode themeMode;

  SettingsState copyWith({CalendarMode? calendar, ThemeMode? themeMode}) =>
      SettingsState(
        calendar: calendar ?? this.calendar,
        themeMode: themeMode ?? this.themeMode,
      );
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  void setCalendar(CalendarMode mode) =>
      state = state.copyWith(calendar: mode);

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
