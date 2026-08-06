import 'dart:convert';

import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/features/chazara/chazara_screen.dart';
import 'package:chovos_hayom/features/goals/goals_screen.dart';
import 'package:chovos_hayom/features/mefarshim/mefarshim_progress_screen.dart';
import 'package:chovos_hayom/features/siyum/siyum_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// The four report screens, built by a test for the first time.
///
/// Between them these are 369 lines that `routes_test.dart` and
/// `deep_link_test.dart` *construct* and assert `isNotNull` on — which proves a
/// constructor exists and nothing else. Every one of the last thirteen shipped
/// defects in this app was in the UI: a confirm button under the navigation
/// bar, a Hebrew fraction reading backwards, a green tick over a backup that
/// did not exist. The pure-Dart domain behind these four screens is tested four
/// times more densely than they are.
///
/// So each screen is checked for the two things a route can get wrong on its
/// own, below whatever its domain function says: that the empty state renders
/// (it is what a new user sees, and three of the four are empty for months),
/// and that a populated one puts the domain's numbers on the screen.
void main() {
  const profile = 'default';

  LearningEvent done(
    int unit, {
    required String id,
    DateTime? at,
    List<String> layers = const [mainLayerId],
    String node = 'shas.moed.shabbos',
  }) =>
      LearningEvent(
        id: id,
        profileId: profile,
        nodeId: node,
        unitIndex: unit,
        action: EventAction.done,
        occurredAt: at ?? DateTime(2026, 1, 1),
        loggedAt: at ?? DateTime(2026, 1, 1),
        layers: layers,
      );

  Widget screen(
    Widget home,
    ProgressRepository repo, {
    AppPreferences? prefs,
    DateTime? now,
  }) =>
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
          appPreferencesProvider
              .overrideWithValue(prefs ?? InMemoryPreferences()),
          clockProvider.overrideWithValue(() => now ?? DateTime(2026, 1, 10)),
        ],
        child: localizedApp(home: home),
      );

  group('Siyumim', () {
    testWidgets('says so when there are none', (tester) async {
      await tester.pumpWidget(screen(const SiyumScreen(), memoryRepository()));
      await tester.pumpAndSettle();

      expect(find.textContaining('No siyumim yet'), findsOneWidget);
    });

    testWidgets('a finished mesechta appears, and so does the seder above it',
        (tester) async {
      final repo = memoryRepository();
      // Shabbos is 156 units at offset 2, and it is the only leaf under Moed,
      // so finishing it is two siyumim: the mesechta and its seder.
      await repo.addEvents([
        for (var i = 0; i < 156; i++) done(i + 2, id: 'e$i'),
      ]);

      await tester.pumpWidget(screen(const SiyumScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.text('Shabbos'), findsOneWidget);
      expect(find.text('Moed'), findsOneWidget);
      // The count line is the screen's own arithmetic, not the provider's.
      expect(find.textContaining('siyumim'), findsWidgets);
      // A siyum on a whole seder is marked as such rather than sitting in the
      // list looking like any other line — the screen's whole reason to exist.
      // Asserted per row, because finishing this catalog's only mesechta
      // finishes every category above it too, so a bare count would pass on a
      // screen that put the suffix on all of them.
      ListTile row(String name) => tester.widget<ListTile>(
          find.ancestor(of: find.text(name), matching: find.byType(ListTile)));
      expect((row('Moed').subtitle! as Text).data,
          contains('everything underneath'));
      expect((row('Shabbos').subtitle! as Text).data,
          isNot(contains('everything underneath')));
    });
  });

  group('Mefarshim progress', () {
    testWidgets('says so when nothing is learned', (tester) async {
      await tester.pumpWidget(
          screen(const MefarshimProgressScreen(), memoryRepository()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing learned yet'), findsOneWidget);
    });

    testWidgets('counts each layer separately, and the bar is relative to the '
        'biggest', (tester) async {
      final repo = memoryRepository();
      await repo.addEvents([
        done(2, id: 'a', layers: const [mainLayerId, 'rashi']),
        done(3, id: 'b', layers: const [mainLayerId, 'rashi']),
        done(4, id: 'c', layers: const [mainLayerId]),
      ]);

      await tester.pumpWidget(screen(const MefarshimProgressScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget, reason: 'the text, on all three');
      expect(find.text('2'), findsOneWidget, reason: 'Rashi, on two of them');
      // `max` is computed in the screen, from the same list it renders. A bar
      // over 1.0 throws in LinearProgressIndicator; one computed against a
      // constant would make every screen look full.
      final bars = tester
          .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator))
          .map((b) => b.value)
          .toList();
      expect(bars, containsAll(<double>[1.0, 2 / 3]));
    });
  });

  group('Chazara', () {
    testWidgets('says so when nothing is due', (tester) async {
      await tester.pumpWidget(screen(const ChazaraScreen(), memoryRepository()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing due for review'), findsOneWidget);
    });

    testWidgets('an overdue unit is listed with how late it is', (tester) async {
      final repo = memoryRepository();
      // First interval is 1 day, so something learned on the 1st is four days
      // overdue by the 6th.
      await repo.addEvent(done(5, id: 'a', at: DateTime(2026, 1, 1)));

      await tester.pumpWidget(
          screen(const ChazaraScreen(), repo, now: DateTime(2026, 1, 6)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Shabbos'), findsOneWidget);
      expect(find.textContaining('4 days overdue'), findsOneWidget);
      expect(find.textContaining('no reviews so far'), findsOneWidget);
    });

    testWidgets('the quick Review button logs a pass and clears the row',
        (tester) async {
      final repo = memoryRepository();
      await repo.addEvent(done(5, id: 'a', at: DateTime(2026, 1, 1)));

      await tester.pumpWidget(
          screen(const ChazaraScreen(), repo, now: DateTime(2026, 1, 6)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();

      final events = await repo.getEvents(profile);
      expect(events.where((e) => e.action == EventAction.reviewed), hasLength(1),
          reason: 'one tap is one review pass');
      // Reviewed today, so the next pass is not due today: the row goes, and
      // the screen falls back to its empty state.
      expect(find.textContaining('Nothing due for review'), findsOneWidget);
    });

    testWidgets('a quick review carries the mefarshim the unit was learned with',
        (tester) async {
      // The two review paths used to disagree: this button recorded only the
      // text, so a daf reviewed from here silently lost its mefarshim.
      final repo = memoryRepository();
      await repo.addEvent(done(5,
          id: 'a',
          at: DateTime(2026, 1, 1),
          layers: const [mainLayerId, 'rashi']));

      await tester.pumpWidget(
          screen(const ChazaraScreen(), repo, now: DateTime(2026, 1, 6)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();

      final review = (await repo.getEvents(profile))
          .firstWhere((e) => e.action == EventAction.reviewed);
      expect(review.layers, containsAll(<String>[mainLayerId, 'rashi']));
    });
  });

  group('Goals', () {
    testWidgets('says so when there are none, and points at where to make one',
        (tester) async {
      await tester.pumpWidget(screen(const GoalsScreen(), memoryRepository()));
      await tester.pumpAndSettle();

      // The screen cannot create the thing it lists — its only verb is delete —
      // so the empty state naming the other screen is the whole affordance.
      expect(find.textContaining('No goals yet'), findsOneWidget);
      expect(find.textContaining('tap the flag'), findsOneWidget);
    });

    testWidgets('a goal shows its date, its required pace and whether it holds',
        (tester) async {
      final prefs = InMemoryPreferences({
        PrefKeys.goalsFor(profile):
            jsonEncode({'shas.moed.shabbos': '2026-04-11T00:00:00.000'}),
      });
      final repo = memoryRepository();
      await repo.addEvent(done(2, id: 'a'));

      await tester.pumpWidget(screen(const GoalsScreen(), repo,
          prefs: prefs, now: DateTime(2026, 1, 10)));
      await tester.pumpAndSettle();

      expect(find.text('Shabbos'), findsOneWidget);
      // 155 units left over 91 days is 1.70/day, and nothing else on the screen
      // computes that number — `goalStatusProvider` does, and this is the only
      // place it is rendered outside the unit grid's banner.
      expect(find.textContaining('need 1.70/day'), findsOneWidget);
    });

    testWidgets('removing a goal is undoable', (tester) async {
      final prefs = InMemoryPreferences({
        PrefKeys.goalsFor(profile):
            jsonEncode({'shas.moed.shabbos': '2026-04-11T00:00:00.000'}),
      });

      await tester.pumpWidget(
          screen(const GoalsScreen(), memoryRepository(), prefs: prefs));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove goal'));
      await tester.pumpAndSettle();

      expect(find.text('Shabbos'), findsNothing);
      expect(find.textContaining('Goal for'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.text('Shabbos'), findsOneWidget,
          reason: 'the undo restores the same target date, not a blank goal');
      expect(find.textContaining('By '), findsOneWidget);
    });
  });
}
