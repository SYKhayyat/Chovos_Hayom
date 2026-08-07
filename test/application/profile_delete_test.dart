import 'dart:io';

import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/profile.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_database.dart';

/// Deleting a profile touches **two stores**, and only one of them cascades.
///
/// The repository drops its five tables in a transaction. Nothing drops the
/// preferences, because [AppPreferences] cannot enumerate keys — so a key left
/// behind outlives the profile forever, and a new profile that reused the id
/// would inherit a stranger's calendar, cycles, sort order and target dates.
///
/// It has gone wrong twice in the same direction. First goals were the *only*
/// removal, and the ten scoped settings keys were orphaned. Then a loop over
/// `perProfile` fixed those and left three keys still named by hand at the call
/// site — two because they are per-profile *state* rather than settings, one
/// because it has its own key shape. Three hand-written exceptions is where the
/// fourth goes missing, so there is one list now, and the last test in this file
/// holds every key `PrefKeys` declares to it.
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

    // Every key the victim can own, written — settings, state and goals alike,
    // off the same list the delete walks.
    for (final key in PrefKeys.ownedBy('victim')) {
      await prefs.setString(key, 'x');
    }
    // A bystander's keys must survive untouched.
    await prefs.setString(PrefKeys.scoped('keep', PrefKeys.cycles), 'keepme');

    await container.read(profilesProvider.notifier).delete('victim');

    for (final key in PrefKeys.ownedBy('victim')) {
      expect(prefs.getString(key), isNull, reason: 'orphaned: $key');
    }
    expect(prefs.getString(PrefKeys.scoped('keep', PrefKeys.cycles)), 'keepme',
        reason: 'another profile’s settings must not be touched');
  });

  test('the last-backup stamp goes, so a reused id is not told it is safe',
      () async {
    // Called out because it is the one whose survival is *reassuring* rather
    // than merely wrong: a new profile inheriting it would be told its learning
    // had been exported when it never was, and the whole point of that stamp is
    // that the export is the only copy which survives a lost device.
    expect(PrefKeys.ownedBy('p'),
        contains(PrefKeys.scoped('p', PrefKeys.lastBackupAt)));
  });

  test('every key PrefKeys declares is app-wide, device-wide, or owned', () {
    // Read out of the source rather than listed here, so adding a key to
    // `preferences.dart` and forgetting to file it fails the build. There is no
    // reflection to do this with under `flutter_test`.
    final source = File('lib/core/preferences.dart').readAsStringSync();
    final constants = <String, String>{
      for (final m in RegExp(r"static const (\w+) = '([^']*)';")
          .allMatches(source))
        m.group(1)!: m.group(2)!,
    };

    expect(constants, isNotEmpty,
        reason: 'the scan found no keys at all, so it is guarding nothing');

    /// Keys that belong to the device or the install rather than to a learner.
    /// Each one is named, so widening this set is a decision somebody makes.
    const appWide = {
      'activeProfileId': 'which profile is open — not owned by any of them',
      'settingsScopedMigrated': 'a one-time migration flag for the install',
      'deviceWideSettingsMigrated': 'likewise — and note the constant is called '
          'deviceWideMigrated, so this set keys on the stored value rather '
          'than the Dart name',
    };

    final owned = PrefKeys.ownedBy('p').toSet();
    final unfiled = <String>[];
    for (final entry in constants.entries) {
      final value = entry.value;
      if (appWide.containsKey(value)) continue;
      if (PrefKeys.deviceWide.contains(value)) continue;
      if (owned.contains(PrefKeys.scoped('p', value))) continue;
      unfiled.add('${entry.key} ("$value")');
    }

    expect(unfiled, isEmpty,
        reason: 'these keys are declared and belong to nothing. A per-profile '
            'key that PrefKeys.ownedBy does not name is one that outlives the '
            'profile it belongs to, in a store that cannot be enumerated to '
            'find it again:\n${unfiled.join('\n')}');
  });

  test('every profile-scoped key *shape* is named by ownedBy', () {
    // The other half: a key built by a function rather than declared as a
    // constant. `goalsFor` is one, and it is exactly the sort that gets left
    // out — it does not go through `scoped`, so no loop over the settings can
    // ever reach it.
    final source = File('lib/core/preferences.dart').readAsStringSync();
    final factories = [
      for (final m
          in RegExp(r'static String (\w+)\(String profileId\)').allMatches(source))
        m.group(1)!,
    ];
    expect(factories, contains('goalsFor'),
        reason: 'the scan must at least find the one that exists');

    final ownedBody = RegExp(r'static List<String> ownedBy\(String profileId\)'
            r' =>[\s\S]*?\n      \];')
        .firstMatch(source)
        ?.group(0);
    expect(ownedBody, isNotNull,
        reason: 'ownedBy has moved, so this guard is reading nothing');

    for (final name in factories) {
      // `scoped` takes a key as well, so it is the shape rather than a key.
      if (name == 'scoped') continue;
      expect(ownedBody, contains('$name(profileId)'),
          reason: '$name builds a profile-scoped key that ownedBy never '
              'removes');
    }
  });

  test('every table with a profileId is dropped when the profile is', () {
    // The database half, which cascades — but only over the tables somebody
    // remembered to name. A sixth table with a `profileId` column and no
    // `delete` beside the other five is a table whose rows survive their owner.
    final schema =
        File('lib/data/drift/database.dart').readAsStringSync();
    final tables = [
      for (final m in RegExp(r'class (\w+) extends Table \{([\s\S]*?)\n\}')
          .allMatches(schema))
        if (m.group(2)!.contains('get profileId')) m.group(1)!,
    ];
    expect(tables, hasLength(greaterThanOrEqualTo(4)),
        reason: 'the scan found almost no tables, so it is guarding nothing');

    final deleteBody = RegExp(
            r'Future<void> deleteProfile\(String profileId\) async \{[\s\S]*?\n  \}')
        .firstMatch(
            File('lib/data/repositories/drift_progress_repository.dart')
                .readAsStringSync())
        ?.group(0);
    expect(deleteBody, isNotNull, reason: 'deleteProfile has moved');

    for (final table in tables) {
      // Drift exposes `class CustomNodes` as `_db.customNodes`.
      final accessor = table[0].toLowerCase() + table.substring(1);
      expect(deleteBody, contains(accessor),
          reason: '$table is scoped to a profile and deleteProfile does not '
              'clear it');
    }
    expect(deleteBody, contains('_db.profiles'),
        reason: 'and the profile row itself');
  });
}
