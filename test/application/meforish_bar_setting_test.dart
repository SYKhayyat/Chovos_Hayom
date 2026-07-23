import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/settings.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('meforish bars show by default and can be toggled off per meforish',
      () async {
    final prefs = InMemoryPreferences();
    final c = ProviderContainer(
        overrides: [appPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);

    expect(c.read(settingsProvider).showsMeforishBar('rashi'), isTrue);

    await c.read(settingsProvider.notifier).setMeforishBarVisible('rashi', false);
    expect(c.read(settingsProvider).showsMeforishBar('rashi'), isFalse);
    expect(c.read(settingsProvider).showsMeforishBar('tosafos'), isTrue);

    // Turning it back on removes it from the hidden set.
    await c.read(settingsProvider.notifier).setMeforishBarVisible('rashi', true);
    expect(c.read(settingsProvider).hiddenMeforishBars, isEmpty);
  });

  test('the hidden set persists across a reload', () async {
    final prefs = InMemoryPreferences();
    final c1 = ProviderContainer(
        overrides: [appPreferencesProvider.overrideWithValue(prefs)]);
    await c1.read(settingsProvider.notifier).setMeforishBarVisible('tosafos', false);
    c1.dispose();

    // A fresh container over the same prefs reloads the stored preference.
    final c2 = ProviderContainer(
        overrides: [appPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c2.dispose);
    expect(c2.read(settingsProvider).hiddenMeforishBars, {'tosafos'});
    expect(c2.read(settingsProvider).showsMeforishBar('tosafos'), isFalse);
  });
}
