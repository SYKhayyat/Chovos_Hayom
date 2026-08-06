import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/profile.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_database.dart';

/// Deleting a profile used to leave every one of its preference keys behind —
/// only goals were removed, and the ten scoped settings keys (calendar, theme,
/// cycles, …) plus the session timer were orphaned in shared_preferences
/// forever. Looping PrefKeys.perProfile fixes it by construction.
void main() {
  late ProgressRepository repo;
  late InMemoryPreferences prefs;
  late ProviderContainer container;

  setUp(() {
    repo = memoryRepository();
    prefs = InMemoryPreferences();
    container = ProviderContainer(overrides: [
      progressRepositoryProvider.overrideWithValue(repo),
      appPreferencesProvider.overrideWithValue(prefs),
    ]);
  });

  tearDown(() => container.dispose());

  test('deleting a profile takes all of its preference keys with it', () async {
    await repo.addProfile(
        Profile(id: 'keep', name: 'Keep', createdAt: DateTime(2026)));
    await repo.addProfile(
        Profile(id: 'victim', name: 'Victim', createdAt: DateTime(2026)));
    await container.read(profilesProvider.future);

    // A full spread of the victim's scoped preferences, plus its timer + goals.
    for (final key in PrefKeys.perProfile) {
      await prefs.setString(PrefKeys.scoped('victim', key), 'x');
    }
    await prefs.setString(PrefKeys.scoped('victim', PrefKeys.sessionTimer), 'x');
    await prefs.setString(PrefKeys.goalsFor('victim'), '{}');
    // A bystander's keys must survive untouched.
    await prefs.setString(PrefKeys.scoped('keep', PrefKeys.cycles), 'keepme');

    await container.read(profilesProvider.notifier).delete('victim');

    for (final key in PrefKeys.perProfile) {
      expect(prefs.getString(PrefKeys.scoped('victim', key)), isNull,
          reason: 'orphaned: $key');
    }
    expect(prefs.getString(PrefKeys.scoped('victim', PrefKeys.sessionTimer)),
        isNull);
    expect(prefs.getString(PrefKeys.goalsFor('victim')), isNull);
    expect(prefs.getString(PrefKeys.scoped('keep', PrefKeys.cycles)), 'keepme',
        reason: 'another profile’s settings must not be touched');
  });
}
