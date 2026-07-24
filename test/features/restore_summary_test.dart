import 'package:chovos_hayom/features/settings/settings_screen.dart';
import 'package:chovos_hayom/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A restore is reported in **units**, not events.
///
/// Putting a unit back is done by *deleting* the later `undone` that out-voted
/// its `done` — the `done` was never removed, so nothing has to be added. An
/// event-level tally therefore reads "removed 2, added 0" at the exact moment
/// the user watches a completion reappear, which is what made the first version
/// of this message so confusing.
///
/// The summary takes its localizations rather than holding English: the strings
/// live in the ARB now. `lookupAppLocalizations` resolves a table synchronously
/// and without a widget tree, so these stay plain unit tests.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final he = lookupAppLocalizations(const Locale('he'));

  test('a unit coming back is described as marked again, never as "added 0"',
      () {
    final msg = SettingsScreen.restoreSummary(
        en, const RestoreDiff(restored: 1, removed: 0, staleEvents: 2));

    expect(msg, contains('1 unit is marked again'));
    expect(msg, isNot(contains('added')));
    expect(msg, isNot(contains('event')));
  });

  test('both directions are reported', () {
    final msg = SettingsScreen.restoreSummary(
        en, const RestoreDiff(restored: 1, removed: 1, staleEvents: 2));

    expect(msg, contains('1 unit is marked again'));
    expect(msg, contains('1 unit is no longer marked'));
  });

  test('plurals agree', () {
    final msg = SettingsScreen.restoreSummary(
        en, const RestoreDiff(restored: 3, removed: 2, staleEvents: 5));

    expect(msg, contains('3 units are marked again'));
    expect(msg, contains('2 units are no longer marked'));
  });

  test('an identical profile says so rather than reporting zeroes', () {
    final msg = SettingsScreen.restoreSummary(
        en, const RestoreDiff(restored: 0, removed: 0, staleEvents: 0));

    expect(msg, contains('already matched'));
    expect(msg, isNot(contains('0')));
  });

  test('events undone that change no unit are not reported as a unit change',
      () {
    // e.g. only a re-log of the same unit with a different date was rolled back:
    // the log changed, what the user sees did not. Saying "0 units" would be
    // noise, and claiming a change would be a lie.
    final msg = SettingsScreen.restoreSummary(
        en, const RestoreDiff(restored: 0, removed: 0, staleEvents: 3));

    expect(msg, contains('no change to which units are marked'));
  });

  group('Hebrew', () {
    // The same behaviours in the other shipped locale. Without this the Hebrew
    // table could lose a plural case, or an ICU placeholder could be mistyped,
    // and nothing would notice until a Hebrew-reading user hit it.
    test('reports in units, and singular differs from plural', () {
      final one = SettingsScreen.restoreSummary(
          he, const RestoreDiff(restored: 1, removed: 0, staleEvents: 2));
      final many = SettingsScreen.restoreSummary(
          he, const RestoreDiff(restored: 3, removed: 2, staleEvents: 5));

      expect(one, contains('יחידה אחת מסומנת מחדש'));
      expect(many, contains('3 יחידות מסומנות מחדש'));
      expect(many, contains('2 יחידות אינן מסומנות עוד'));
      // Nothing fell back to the English template for a missing key.
      expect(one, isNot(contains('unit')));
      expect(many, isNot(contains('unit')));
    });

    test('an identical profile and a no-visible-change restore each say so', () {
      expect(
        SettingsScreen.restoreSummary(
            he, const RestoreDiff(restored: 0, removed: 0, staleEvents: 0)),
        contains('כבר תאם'),
      );
      expect(
        SettingsScreen.restoreSummary(
            he, const RestoreDiff(restored: 0, removed: 0, staleEvents: 3)),
        contains('אין שינוי'),
      );
    });
  });
}
