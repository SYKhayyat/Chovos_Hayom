import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/settings.dart';
import 'package:chovos_hayom/core/calendar.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// #48 — the day sheet's layout, as a *setting*.
///
/// **The point of the issue is that it is a setting and not a per-day choice**,
/// so that is what most of this asserts: one key, written once, read back on a
/// fresh container, and cleared by *Clear settings* because it is a thing the
/// learner chose.
void main() {
  late InMemoryPreferences prefs;

  setUp(() => prefs = InMemoryPreferences());

  /// Read the layout back the way a restart would, through a fresh container.
  DaySheetLayout readBack() {
    final container = ProviderContainer(
      overrides: [appPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container.read(settingsProvider).daySheetLayout;
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(prefs),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(memoryRepository()),
        ],
        child: localizedApp(home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The radio for one layout, scrolled into view.
  Future<void> choose(WidgetTester tester, DaySheetLayout layout) async {
    final radio = find.byKey(ValueKey('settings-day-sheet-${layout.name}'));
    await tester.ensureVisible(radio);
    await tester.pumpAndSettle();
    await tester.tap(radio);
    await tester.pumpAndSettle();
  }

  group('the default', () {
    test('is grouped by plan', () {
      expect(
        readBack(),
        DaySheetLayout.byPlan,
        reason:
            'the default is named explicitly rather than taken from '
            'DaySheetLayout.values.first, so a layout added above it cannot '
            'silently become what every existing install sees',
      );
    });

    testWidgets('and it is the first radio on the screen', (tester) async {
      await pump(tester);
      final grouped = find.byKey(const ValueKey('settings-day-sheet-byPlan'));
      final flat = find.byKey(const ValueKey('settings-day-sheet-flat'));
      await tester.ensureVisible(grouped);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(grouped).dy,
        lessThan(tester.getTopLeft(flat).dy),
      );
    });
  });

  group('changing it', () {
    testWidgets('writes the key and it survives a restart', (tester) async {
      await pump(tester);
      await choose(tester, DaySheetLayout.collapsed);

      expect(
        prefs.getString(PrefKeys.scoped('default', PrefKeys.daySheetLayout)),
        'collapsed',
        reason: 'asserted on the stored value, not on the notifier',
      );
      expect(readBack(), DaySheetLayout.collapsed);
    });

    testWidgets('each of the three round-trips', (tester) async {
      for (final layout in DaySheetLayout.values) {
        await pump(tester);
        await choose(tester, layout);
        expect(readBack(), layout, reason: layout.name);
      }
    });

    testWidgets('an unknown stored name falls back rather than throwing', (
      tester,
    ) async {
      // A plan written by a newer build, or a hand-edited file. Falling back is
      // the safe answer, and it must be the *default* one: a layout this build
      // cannot render is not something to guess at.
      await prefs.setString(
        PrefKeys.scoped('default', PrefKeys.daySheetLayout),
        'sideways',
      );
      await pump(tester);
      expect(readBack(), DaySheetLayout.byPlan);
    });
  });

  group('it is a per-profile setting', () {
    test('and belongs to the profile, not the device', () {
      // Asserted through the lists themselves rather than by deleting a profile:
      // `profile_delete_test.dart` already holds every key in `PrefKeys` to one
      // of them, and this says which list it is in.
      expect(PrefKeys.perProfile, contains(PrefKeys.daySheetLayout));
      expect(
        PrefKeys.deviceWide,
        isNot(contains(PrefKeys.daySheetLayout)),
        reason:
            'how a day is laid out describes this learner, not this phone — a '
            'backup carried to someone else\'s device must not rearrange their '
            'days',
      );
    });

    test("and is exported with the rest of the profile's settings", () async {
      final container = ProviderContainer(
        overrides: [appPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      await container
          .read(settingsProvider.notifier)
          .setDaySheetLayout(DaySheetLayout.flat);

      final backup = container.read(settingsProvider.notifier).toBackup();
      expect(backup[PrefKeys.daySheetLayout], 'flat');
    });
  });

  group('the setting takes part in value equality', () {
    test('so a change to it rebuilds, and an untouched load does not', () {
      const a = SettingsState();
      final b = a.copyWith(daySheetLayout: DaySheetLayout.flat);
      expect(a, isNot(b), reason: 'a changed layout must notify');
      expect(a.copyWith(), a, reason: 'and an unchanged reload must not');
    });
  });
}
