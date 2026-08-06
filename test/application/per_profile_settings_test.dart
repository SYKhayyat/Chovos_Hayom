import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/settings.dart';
import 'package:chovos_hayom/application/sorting.dart';
import 'package:chovos_hayom/core/calendar.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which settings belong to a *learner* and which belong to the *device*.
///
/// Both halves were wrong once, in opposite directions. Settings began
/// device-wide while the data they described was per-profile, so switching
/// profiles kept the previous user's sort, chazara intervals and meforish bars.
/// Making all of them per-profile then over-corrected: switching profiles also
/// flipped the app's *language*, so a Hebrew-only user creating a profile for
/// their son landed in an English, left-to-right settings screen and had to find
/// the toggle back without being able to read it.
///
/// The line now: language, theme and calendar describe the device; everything
/// else describes the learner.
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
    await notifier().setChazaraIntervals([2, 4, 8]);
    await notifier().setSort(const SortConfig(metric: SortMetric.percent));

    await switchTo('other');

    expect(settings().chazaraIntervals, isNot([2, 4, 8]));
    expect(settings().sort.metric, SortMetric.catalog);
  });

  test('but the language, theme and calendar do', () async {
    // The defect: these three followed the profile too, so creating a second
    // profile threw a Hebrew reader into an English app to look for the switch
    // back. They are chrome — how this device presents itself — not facts about
    // anyone's learning.
    await notifier().setHebrewLayout(true);
    await notifier().setThemeMode(ThemeMode.dark);
    await notifier().setCalendar(CalendarMode.hebrew);

    await switchTo('other');

    expect(settings().hebrewLayout, isTrue,
        reason: 'a new profile must not silently change the language');
    expect(settings().themeMode, ThemeMode.dark);
    expect(settings().calendar, CalendarMode.hebrew);
  });

  test('switching back restores the first profile’s settings', () async {
    await notifier().setSort(const SortConfig(metric: SortMetric.percent));

    await switchTo('other');
    await notifier().setSort(const SortConfig(metric: SortMetric.learned));
    await switchTo('default');

    expect(settings().sort.metric, SortMetric.percent);
  });

  test('clearing settings only clears the active profile', () async {
    await notifier().setChazaraIntervals([2, 4, 8]);
    await switchTo('other');
    await notifier().setChazaraIntervals([3, 6, 9]);

    await notifier().clearAll();
    expect(settings().chazaraIntervals, isNot([3, 6, 9]));

    await switchTo('default');
    expect(settings().chazaraIntervals, [2, 4, 8], reason: 'untouched');
  });

  test('clearing settings leaves the device’s language alone', () async {
    await notifier().setHebrewLayout(true);

    await notifier().clearAll();

    expect(settings().hebrewLayout, isTrue,
        reason: 'resetting one profile must not change what language the '
            'person is reading');
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

      // Everything survives the upgrade for the person it belonged to...
      expect(settings().themeMode, ThemeMode.dark);
      expect(settings().calendar, CalendarMode.hebrew);
      expect(settings().chazaraIntervals, [2, 4, 8]);

      // ...and only the learner's half is theirs alone. Theme and calendar
      // belong to the device, so the next profile keeps looking the same —
      // which is the whole point of the second migration.
      await switchTo('someone-else');
      expect(settings().chazaraIntervals, isNot([2, 4, 8]));
      expect(settings().themeMode, ThemeMode.dark);
      expect(settings().calendar, CalendarMode.hebrew);
    });

    test('the legacy keys are removed so it cannot run twice', () async {
      prefs = InMemoryPreferences({
        PrefKeys.themeMode: 'dark',
        PrefKeys.chazaraIntervals: '2,4,8',
      });
      container.dispose();
      container = build();
      container.read(settingsProvider); // force the notifier to build

      // The learner's key moved into the profile; the bare one is gone.
      expect(prefs.getString(PrefKeys.chazaraIntervals), isNull);
      expect(
          prefs.getString(PrefKeys.scoped('default', PrefKeys.chazaraIntervals)),
          '2,4,8');
      expect(prefs.getString(PrefKeys.settingsScopedMigrated), 'true');
      // The device's key went into the profile and straight back out, so the
      // bare key is where it lives and the scoped copy is gone.
      expect(prefs.getString(PrefKeys.themeMode), 'dark');
      expect(
          prefs.getString(PrefKeys.scoped('default', PrefKeys.themeMode)), isNull);
      expect(prefs.getString(PrefKeys.deviceWideMigrated), 'true');

      // A later profile switch must not re-import anything.
      await switchTo('other');
      expect(settings().chazaraIntervals, isNot([2, 4, 8]));
    });
  });

  test('an imported backup cannot change the device’s language', () async {
    // Old backups carry these three keys, and a file from someone else's phone
    // must not flip this one into a language its owner does not read.
    await notifier().setHebrewLayout(true);

    await notifier().applyBackup({
      PrefKeys.hebrewLayout: 'false',
      PrefKeys.themeMode: 'light',
      PrefKeys.chazaraIntervals: '5,10',
    }, ImportMode.merge);

    expect(settings().hebrewLayout, isTrue);
    expect(settings().themeMode, ThemeMode.system);
    expect(settings().chazaraIntervals, [5, 10],
        reason: 'the learner’s own settings still import');
  });

  test('an imported backup applies to the active profile only', () async {
    await switchTo('other');
    await notifier()
        .applyBackup({PrefKeys.chazaraIntervals: '5,10'}, ImportMode.merge);
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
