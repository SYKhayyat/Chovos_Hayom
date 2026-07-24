import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/settings.dart';
import 'package:chovos_hayom/application/sorting.dart';
import 'package:chovos_hayom/core/calendar.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Settings used to be device-wide while the data they described was
/// per-profile: switching profiles kept the previous user's calendar, theme,
/// RTL, sort, chazara intervals and meforish bars.
void main() {
  late InMemoryPreferences prefs;
  late ProviderContainer container;

  ProviderContainer build() => ProviderContainer(
        overrides: [appPreferencesProvider.overrideWithValue(prefs)],
      );

  setUp(() {
    prefs = InMemoryPreferences();
    container = build();
  });

  tearDown(() => container.dispose());

  Future<void> switchTo(String profileId) =>
      container.read(activeProfileProvider.notifier).setProfile(profileId);

  SettingsNotifier notifier() => container.read(settingsProvider.notifier);
  SettingsState settings() => container.read(settingsProvider);

  test('one profile’s settings do not follow you to another', () async {
    await notifier().setThemeMode(ThemeMode.dark);
    await notifier().setCalendar(CalendarMode.hebrew);
    await notifier().setChazaraIntervals([2, 4, 8]);

    await switchTo('other');

    expect(settings().themeMode, ThemeMode.system);
    expect(settings().calendar, CalendarMode.gregorian);
    expect(settings().chazaraIntervals, isNot([2, 4, 8]));
  });

  test('switching back restores the first profile’s settings', () async {
    await notifier().setHebrewLayout(true);
    await notifier().setSort(const SortConfig(metric: SortMetric.percent));

    await switchTo('other');
    await notifier().setHebrewLayout(false);
    await switchTo('default');

    expect(settings().hebrewLayout, isTrue);
    expect(settings().sort.metric, SortMetric.percent);
  });

  test('clearing settings only clears the active profile', () async {
    await notifier().setThemeMode(ThemeMode.dark);
    await switchTo('other');
    await notifier().setThemeMode(ThemeMode.light);

    await notifier().clearAll();
    expect(settings().themeMode, ThemeMode.system);

    await switchTo('default');
    expect(settings().themeMode, ThemeMode.dark, reason: 'untouched');
  });

  test('meforish bar visibility is per-profile', () async {
    await notifier().setMeforishBarVisible('rashi', false);
    expect(settings().showsMeforishBar('rashi'), isFalse);

    await switchTo('other');
    expect(settings().showsMeforishBar('rashi'), isTrue);
  });

  group('upgrading from device-wide settings', () {
    test('the active profile inherits the old settings, once', () async {
      // An install from before the change: bare, unscoped keys.
      prefs = InMemoryPreferences({
        PrefKeys.activeProfileId: 'yaakov',
        PrefKeys.themeMode: 'dark',
        PrefKeys.calendarMode: 'hebrew',
        PrefKeys.chazaraIntervals: '2,4,8',
      });
      container.dispose();
      container = build();

      // The person those settings belong to keeps them...
      expect(settings().themeMode, ThemeMode.dark);
      expect(settings().calendar, CalendarMode.hebrew);
      expect(settings().chazaraIntervals, [2, 4, 8]);

      // ...and nobody else inherits them.
      await switchTo('someone-else');
      expect(settings().themeMode, ThemeMode.system);
      expect(settings().calendar, CalendarMode.gregorian);
    });

    test('the legacy keys are removed so it cannot run twice', () async {
      prefs = InMemoryPreferences({PrefKeys.themeMode: 'dark'});
      container.dispose();
      container = build();
      container.read(settingsProvider); // force the notifier to build

      expect(prefs.getString(PrefKeys.themeMode), isNull);
      expect(prefs.getString(PrefKeys.settingsScopedMigrated), 'true');

      // A later profile switch must not re-import anything.
      await switchTo('other');
      expect(settings().themeMode, ThemeMode.system);
    });
  });

  test('an imported backup applies to the active profile only', () async {
    await switchTo('other');
    await notifier().applyBackup({PrefKeys.chazaraIntervals: '5,10'});
    expect(settings().chazaraIntervals, [5, 10]);

    await switchTo('default');
    expect(settings().chazaraIntervals, isNot([5, 10]));
  });

  group('the backup covers every per-profile key', () {
    // The enumeration guard: a per-profile key that toBackup omits is one that
    // silently doesn't survive export → clear → import. Cycles were that key.
    test('toBackup emits all of PrefKeys.perProfile', () {
      final keys = notifier().toBackup().keys.toSet();
      expect(keys.containsAll(PrefKeys.perProfile), isTrue,
          reason: 'missing: '
              '${PrefKeys.perProfile.toSet().difference(keys)}');
    });

    test('cycles are exported and cleared with the rest of the settings', () async {
      // Cycles live under their own scoped pref (a separate controller owns them).
      const raw = '{"custom":[],"hiddenBuiltIns":[],"mappings":{}}';
      await prefs.setString(
          PrefKeys.scoped('default', PrefKeys.cycles), raw);

      expect(notifier().toBackup()[PrefKeys.cycles], raw,
          reason: 'cycles must ride in the backup');

      await notifier().clearAll();
      expect(prefs.getString(PrefKeys.scoped('default', PrefKeys.cycles)), isNull,
          reason: 'clear settings must take the cycles with it');
    });
  });
}
