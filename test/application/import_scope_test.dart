import 'dart:io';

import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/application/goals.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/settings.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// **An import mode is a promise about scope, and it has to be kept by every
/// store the profile is spread across — not just the ones inside `importInto`.**
///
/// The defect this file exists for: [ImportMode] reached the event log, custom
/// sefarim, custom mefarshim and the layer configs, and stopped there. Settings
/// and goals live in preferences rather than in the repository, so they are
/// applied by the settings screen *after* `importInto` returns — and for a long
/// time they were applied the same way in all three modes. Two consequences,
/// pointing in opposite directions:
///
/// - **A merge removed things.** `merge` documents itself as "add what the
///   profile does not have, remove nothing", and `toBackup` emits every key in
///   [PrefKeys.perProfile] on every export, filling in the effective value —
///   which for an untouched profile is simply the default. So the file always
///   names every key, applying every key it names always overwrote, and a merge
///   silently replaced the learner's sort order, chazara intervals, hidden bars
///   and backup interval with whatever the file happened to hold. `cycles` made
///   it destructive rather than merely rude: the entire list is one key, so
///   merging a backup taken before a cycle was added *deleted* that cycle.
/// - **A restore-everything kept things.** The mode that promises the profile
///   will match the file left behind every goal set since the backup.
///
/// Three earlier reviews each caught one layer of this (`F4` in both grades,
/// `W5` in the builder's report) and each fixed the layer it could see. The
/// point of enumerating the contract here is that the next store added to a
/// profile does not get to be the fourth.
void main() {
  late InMemoryPreferences prefs;
  late ProviderContainer container;

  setUp(() {
    prefs = InMemoryPreferences();
    container = ProviderContainer(
      overrides: [appPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() => container.dispose());

  SettingsNotifier settings() => container.read(settingsProvider.notifier);
  GoalsController goals() => container.read(goalsProvider.notifier);

  String? stored(String key) =>
      prefs.getString(PrefKeys.scoped('default', key));

  /// A backup that names every per-profile key, which is what a real one is —
  /// see `SettingsNotifier.toBackup`.
  Map<String, dynamic> backupNaming(String value) => {
        for (final key in PrefKeys.perProfile) key: value,
      };

  group('the settings contract, over every key that exists', () {
    // Enumerated rather than spelled out per key, so a preference added to
    // PrefKeys.perProfile is covered by these four the day it is added. The
    // assertions read the *stored string*, not the parsed SettingsState, so
    // they need to know nothing about what any particular key means — which is
    // the only way a test can outlive the list it iterates.

    test('a merge does not overwrite a value the learner has set', () async {
      for (final key in PrefKeys.perProfile) {
        await prefs.setString(PrefKeys.scoped('default', key), 'mine');
      }

      await settings().applyBackup(backupNaming('theirs'), ImportMode.merge);

      for (final key in PrefKeys.perProfile) {
        expect(stored(key), 'mine',
            reason: '$key was set on this profile, and a merge removes nothing');
      }
    });

    test('a merge does fill in a value the learner has never set', () async {
      await settings().applyBackup(backupNaming('theirs'), ImportMode.merge);

      for (final key in PrefKeys.perProfile) {
        expect(stored(key), 'theirs',
            reason: '$key is unset here, so there is nothing to protect — a '
                'fresh profile on a new phone must still get the file’s '
                'settings, which is the whole reason import applies them');
      }
    });

    test('the narrow restore is a merge outside the log', () async {
      // "Custom sefarim, mefarshim and settings are kept" is what its subtitle
      // promises, and the log is the only thing it reconciles.
      for (final key in PrefKeys.perProfile) {
        await prefs.setString(PrefKeys.scoped('default', key), 'mine');
      }

      await settings()
          .applyBackup(backupNaming('theirs'), ImportMode.restoreLog);

      for (final key in PrefKeys.perProfile) {
        expect(stored(key), 'mine', reason: '$key survives a restoreLog');
      }
    });

    test('restore everything takes the file’s answer for every key', () async {
      for (final key in PrefKeys.perProfile) {
        await prefs.setString(PrefKeys.scoped('default', key), 'mine');
      }

      await settings()
          .applyBackup(backupNaming('theirs'), ImportMode.restoreEverything);

      for (final key in PrefKeys.perProfile) {
        expect(stored(key), 'theirs', reason: '$key now matches the backup');
      }
    });

    test('restore everything clears a key the backup does not carry', () async {
      // The case a merge cannot express at all, and the reason the clear runs
      // even when the settings map is empty: a v1 backup predates the settings
      // array entirely, and "make this profile match the file" means the file's
      // silence is an answer too.
      for (final key in PrefKeys.perProfile) {
        await prefs.setString(PrefKeys.scoped('default', key), 'mine');
      }

      await settings().applyBackup(const {}, ImportMode.restoreEverything);

      for (final key in PrefKeys.perProfile) {
        expect(stored(key), isNull,
            reason: '$key is back to its default, which is stored as *absent* '
                'rather than as the default value — see clearAll');
      }
    });

    test('no mode touches what belongs to the device', () async {
      // The existing rule, re-asserted here because restore-everything is a new
      // way to break it: this mode clears PrefKeys.perProfile, and the day
      // someone "tidies" that into "every key" is the day a restore starts
      // changing the language of a phone it was carried to.
      await settings().setHebrewLayout(true);

      await settings().applyBackup(
          {for (final key in PrefKeys.deviceWide) key: 'theirs'},
          ImportMode.restoreEverything);

      expect(container.read(settingsProvider).hebrewLayout, isTrue);
      for (final key in PrefKeys.deviceWide) {
        expect(prefs.getString(key), isNot('theirs'));
      }
    });
  });

  group('the goals contract', () {
    final march = DateTime(2027, 3, 1);
    final june = DateTime(2027, 6, 1);

    test('a merge honours the file and keeps what it does not name', () async {
      await goals().setGoal('mine', june);
      await goals().setGoal('shared', june);

      final deleted = await goals()
          .applyBackup({'shared': march, 'theirs': march}, ImportMode.merge);

      expect(container.read(goalsProvider), {
        'mine': june,
        'shared': march,
        'theirs': march,
      },
          reason: 'unlike the settings map, a node is only named here because '
              'somebody picked a date for it — so naming it is the intent, and '
              'honouring it is the right merge');
      expect(deleted, 0);
    });

    test('the narrow restore leaves goals alone', () async {
      await goals().setGoal('mine', june);

      final deleted =
          await goals().applyBackup(const {}, ImportMode.restoreLog);

      expect(container.read(goalsProvider), {'mine': june});
      expect(deleted, 0);
    });

    test('restore everything drops a goal the backup does not name', () async {
      await goals().setGoal('mine', june);
      await goals().setGoal('shared', june);

      final deleted = await goals()
          .applyBackup({'shared': march}, ImportMode.restoreEverything);

      expect(container.read(goalsProvider), {'shared': march},
          reason: 'a target date set since the backup is exactly the kind of '
              'thing "make this profile match the file" is for undoing');
      expect(deleted, 1, reason: 'reported, so the summary can say what it did');
    });

    test('what the confirmation counts is what the import deletes', () async {
      // The two numbers come from one function for the reason
      // BackupService._customisationsToRemove is one function: a preview
      // computed separately from the outcome is one that will eventually
      // disagree with it, and this one is telling the user what they will lose.
      await goals().setGoal('a', june);
      await goals().setGoal('b', june);
      await goals().setGoal('c', june);
      final backup = {'a': march};

      final predicted = GoalsController.goalsRemovedBy(
              container.read(goalsProvider), backup,
              ImportMode.restoreEverything)
          .length;
      final actual =
          await goals().applyBackup(backup, ImportMode.restoreEverything);

      expect(predicted, 2);
      expect(actual, predicted);
    });
  });

  group('the rule, rather than a description of it', () {
    // The compiler already enforces that every *existing* applyBackup call
    // passes a mode — it is a required positional parameter, and that is the
    // right kind of guard because it cannot be forgotten. What the compiler
    // cannot catch is the next store: a fourth thing a profile owns, added to
    // preferences, applied after `importInto` by a method that never took a
    // mode in the first place. That is precisely how settings and goals came to
    // be wrong, and it is silent — the mode is not ignored so much as never
    // asked for.
    test('every applyBackup in lib/ takes an ImportMode', () {
      final declaration = RegExp(r'\bapplyBackup\s*\(([^)]*)\)');
      final violations = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (path.contains('/l10n/generated/') || path.endsWith('.g.dart')) {
          continue;
        }
        final source = entity.readAsStringSync();
        for (final match in declaration.allMatches(source)) {
          final params = match.group(1)!;
          // Call sites pass `mode`; declarations name the type. Either spelling
          // proves the scope reached this store.
          if (params.contains('ImportMode') || params.contains('mode')) continue;
          violations.add('$path: ${match.group(0)}');
        }
      }

      expect(violations, isEmpty,
          reason: 'a store that a backup writes into has to know how much of '
              'itself the chosen mode is allowed to replace. Add the ImportMode '
              'parameter and give it a branch — and if the answer is genuinely '
              '"this one is the same in all three modes", say so in the '
              'signature by taking the mode and ignoring it, so the next reader '
              'can tell that was decided rather than missed');
    });
  });
}
