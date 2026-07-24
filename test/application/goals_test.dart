import 'package:chovos_hayom/application/goals.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// goalsProvider is watched by the dashboard tiles, the unit grid and the Goals
/// screen — so an unguarded parse of a corrupt stored value takes all three down
/// on launch. Its two neighbours (cycles, session timer) guard the same read;
/// this one didn't.
void main() {
  ProviderContainer containerFor(AppPreferences prefs) {
    final c = ProviderContainer(
        overrides: [appPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    return c;
  }

  test('a corrupt goals value yields no goals rather than crashing', () {
    final prefs = InMemoryPreferences(
        {PrefKeys.goalsFor('default'): 'not valid json'});
    final container = containerFor(prefs);
    expect(container.read(goalsProvider), isEmpty);
  });

  test('a goals value with a bad date does not throw either', () {
    final prefs = InMemoryPreferences(
        {PrefKeys.goalsFor('default'): '{"shas":"whenever"}'});
    final container = containerFor(prefs);
    expect(container.read(goalsProvider), isEmpty);
  });

  test('a well-formed goals value still loads', () {
    final prefs = InMemoryPreferences({
      PrefKeys.goalsFor('default'): '{"shas":"2030-06-01T00:00:00.000"}',
    });
    final container = containerFor(prefs);
    expect(container.read(goalsProvider), {'shas': DateTime(2030, 6, 1)});
  });
}
