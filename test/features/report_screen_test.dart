import 'dart:convert';

import 'package:chovos_hayom/app/routes.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/features/reports/calculator_section.dart';
import 'package:chovos_hayom/features/reports/goals_section.dart';
import 'package:chovos_hayom/features/reports/mefarshim_section.dart';
import 'package:chovos_hayom/features/reports/overview_section.dart';
import 'package:chovos_hayom/features/reports/report_screen.dart';
import 'package:chovos_hayom/features/reports/siyumim_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// The report — five tabs that used to be five routes.
///
/// Each section is checked for the two things it can get wrong below whatever
/// its domain function says: that the empty state renders (it is what a new user
/// sees, and three of the five are empty for months) and that a populated one
/// puts the domain's numbers on the screen. On top of that the *shell* is
/// checked for the guarantee the merge had to keep — every old route name still
/// opens the report, on its own tab — and for the thing the merge made possible:
/// the Calculator's "By date" answer can now be kept as a goal, so the Goals
/// section is no longer a screen whose only verb is delete.
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

  Widget app(
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

  /// One section on its own, under the Scaffold and tab controller the shell
  /// would have supplied.
  Widget section(
    Widget body,
    ProgressRepository repo, {
    AppPreferences? prefs,
    DateTime? now,
  }) =>
      app(reportSection(body), repo, prefs: prefs, now: now);

  int selectedTab(WidgetTester tester) =>
      DefaultTabController.of(tester.element(find.byType(TabBarView))).index;

  group('the shell', () {
    testWidgets('every old route name opens the report on its own tab',
        (tester) async {
      // The merge is a design change; the names are a contract with anything
      // outside the app that holds one — a deep link, a shortcut, a route the
      // OS restores. Retiring them would have been a broken link for nothing.
      const expected = {
        Routes.stats: ReportSection.overview,
        Routes.calculator: ReportSection.calculator,
        Routes.goals: ReportSection.goals,
        Routes.siyumim: ReportSection.siyumim,
        Routes.mefarshim: ReportSection.mefarshim,
      };
      for (final entry in expected.entries) {
        final screen = AppRouter.screenFor(entry.key);
        expect(screen, isA<ReportScreen>(), reason: entry.key);
        expect((screen! as ReportScreen).section, entry.value,
            reason: entry.key);
      }
    });

    testWidgets('opens on the section its route named, not always the first',
        (tester) async {
      await tester.pumpWidget(app(
          const ReportScreen(section: ReportSection.siyumim),
          memoryRepository()));
      await tester.pumpAndSettle();

      expect(selectedTab(tester), ReportSection.siyumim.index);
      expect(find.byType(SiyumimSection), findsOneWidget);
      expect(find.byType(OverviewSection), findsNothing);
    });

    testWidgets('and the tabs move between them', (tester) async {
      await tester.pumpWidget(app(const ReportScreen(), memoryRepository()));
      await tester.pumpAndSettle();

      expect(find.byType(OverviewSection), findsOneWidget);

      await tester.tap(find.text('Mefarshim'));
      await tester.pumpAndSettle();

      expect(find.byType(MefarshimSection), findsOneWidget);
      expect(selectedTab(tester), ReportSection.mefarshim.index);
    });
  });

  group('Overview', () {
    testWidgets('shows a 2-day streak and the progress chart', (tester) async {
      final repo = memoryRepository();
      await repo.addEvent(done(2, id: 'a', at: DateTime(2026, 1, 10)));
      await repo.addEvent(done(3, id: 'b', at: DateTime(2026, 1, 9)));

      await tester.pumpWidget(section(const OverviewSection(), repo,
          now: DateTime(2026, 1, 10, 12)));
      await tester.pumpAndSettle();

      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('2 days'), findsOneWidget);

      // The chart sits below the (lazily-built) summary grid; scroll to it.
      await tester.scrollUntilVisible(
        find.text('Progress over time'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Progress over time'), findsOneWidget);
    });
  });

  group('Calculator', () {
    testWidgets('projects a finish date at 1/day, and again on a cycle',
        (tester) async {
      await tester.pumpWidget(section(const CalculatorSection(),
          memoryRepository(),
          now: DateTime(2026, 1, 1, 12)));
      await tester.pumpAndSettle();

      // Default node = root (156 units in the fake catalog), default rate = 1/day.
      expect(find.textContaining('156 of 156 left'), findsOneWidget);
      expect(find.textContaining('You will finish on'), findsOneWidget);

      await tester.tap(find.text('Cycle'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cycle length: 7 days'), findsOneWidget);
      expect(find.textContaining('You will finish on'), findsOneWidget);
    });

    testWidgets('"By date" keeps its answer as a goal, and says it already has',
        (tester) async {
      // The finding this whole merge came from called the By-date mode "a goal
      // you can't save". This is the assertion that it is one you can.
      final prefs = InMemoryPreferences();
      await tester.pumpWidget(section(const CalculatorSection(),
          memoryRepository(),
          prefs: prefs, now: DateTime(2026, 1, 1, 12)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('By date'));
      await tester.pumpAndSettle();
      expect(find.textContaining('per day to finish by'), findsOneWidget);

      await tester.tap(find.text('Save as goal'));
      await tester.pumpAndSettle();

      final saved =
          jsonDecode(prefs.getString(PrefKeys.goalsFor(profile))!) as Map;
      expect(saved.keys, hasLength(1),
          reason: 'the node the calculator was pointed at, and only that one');
      expect(saved.values.single, startsWith('2027-01-01'),
          reason: 'a year out, which is what the picker opened on');

      // Disabled rather than gone: a control that vanishes once it has worked
      // reads as broken.
      expect(find.text('Save as goal'), findsNothing);
      final button =
          tester.widget<FilledButton>(find.byType(FilledButton).first);
      expect(button.onPressed, isNull);
      expect(find.text('Saved as a goal'), findsOneWidget);
    });
  });

  group('Goals', () {
    testWidgets('says so when there are none, and offers to make one',
        (tester) async {
      await tester
          .pumpWidget(section(const GoalsSection(), memoryRepository()));
      await tester.pumpAndSettle();

      expect(find.textContaining('No goals yet'), findsOneWidget);
      // The affordance is a control now, not a sentence naming another route.
      expect(find.text('Set a goal'), findsOneWidget);
    });

    testWidgets('and that offer moves to the Calculator tab', (tester) async {
      await tester.pumpWidget(app(
          const ReportScreen(section: ReportSection.goals),
          memoryRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set a goal'));
      await tester.pumpAndSettle();

      expect(selectedTab(tester), ReportSection.calculator.index);
      expect(find.byType(CalculatorSection), findsOneWidget);
    });

    testWidgets('a goal shows its date, its required pace and whether it holds',
        (tester) async {
      final prefs = InMemoryPreferences({
        PrefKeys.goalsFor(profile):
            jsonEncode({'shas.moed.shabbos': '2026-04-11T00:00:00.000'}),
      });
      final repo = memoryRepository();
      await repo.addEvent(done(2, id: 'a'));

      await tester.pumpWidget(section(const GoalsSection(), repo,
          prefs: prefs, now: DateTime(2026, 1, 10)));
      await tester.pumpAndSettle();

      expect(find.text('Shabbos'), findsOneWidget);
      // 155 units left over 91 days is 1.70/day, and nothing else on the screen
      // computes that number — `goalStatusProvider` does, and this row and the
      // unit grid's banner now say it through the same function.
      expect(find.textContaining('need 1.70/day'), findsOneWidget);
    });

    testWidgets('removing a goal is undoable', (tester) async {
      final prefs = InMemoryPreferences({
        PrefKeys.goalsFor(profile):
            jsonEncode({'shas.moed.shabbos': '2026-04-11T00:00:00.000'}),
      });

      await tester.pumpWidget(
          section(const GoalsSection(), memoryRepository(), prefs: prefs));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove goal'));
      await tester.pumpAndSettle();

      expect(find.text('Shabbos'), findsNothing);
      // Named, which the banner's copy of this flow never was: it said only
      // "Goal removed", so undoing from there did not say what came back.
      expect(find.textContaining('Goal for'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.text('Shabbos'), findsOneWidget,
          reason: 'the undo restores the same target date, not a blank goal');
      expect(find.textContaining('By '), findsOneWidget);
    });
  });

  group('Siyumim', () {
    testWidgets('says so when there are none', (tester) async {
      await tester
          .pumpWidget(section(const SiyumimSection(), memoryRepository()));
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

      await tester.pumpWidget(section(const SiyumimSection(), repo));
      await tester.pumpAndSettle();

      expect(find.text('Shabbos'), findsOneWidget);
      expect(find.text('Moed'), findsOneWidget);
      // The count line is the section's own arithmetic, not the provider's.
      expect(find.textContaining('siyumim'), findsWidgets);
      // A siyum on a whole seder is marked as such rather than sitting in the
      // list looking like any other line — the section's whole reason to exist.
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

  group('Mefarshim', () {
    testWidgets('says so when nothing is learned', (tester) async {
      await tester
          .pumpWidget(section(const MefarshimSection(), memoryRepository()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing learned yet'), findsOneWidget);
    });

    testWidgets(
        'counts each layer separately, and the bar is relative to the biggest',
        (tester) async {
      final repo = memoryRepository();
      await repo.addEvents([
        done(2, id: 'a', layers: const [mainLayerId, 'rashi']),
        done(3, id: 'b', layers: const [mainLayerId, 'rashi']),
        done(4, id: 'c', layers: const [mainLayerId]),
      ]);

      await tester.pumpWidget(section(const MefarshimSection(), repo));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget, reason: 'the text, on all three');
      expect(find.text('2'), findsOneWidget, reason: 'Rashi, on two of them');
      // `max` is computed in the section, from the same list it renders. A bar
      // over 1.0 throws in LinearProgressIndicator; one computed against a
      // constant would make every screen look full.
      final bars = tester
          .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator))
          .map((b) => b.value)
          .toList();
      expect(bars, containsAll(<double>[1.0, 2 / 3]));
    });

    testWidgets('a stat row for a meforish since deleted is named, not a UUID',
        (tester) async {
      // The fallback that three files had each written for themselves, and that
      // only two of them got right. This section was one of the wrong ones: its
      // orElse produced `Layer(id: id, name: id)`.
      final repo = memoryRepository();
      await repo.addEvent(done(2,
          id: 'a',
          layers: const [mainLayerId, '4f3c1d9e-0000-4000-8000-000000000001']));

      await tester.pumpWidget(section(const MefarshimSection(), repo));
      await tester.pumpAndSettle();

      expect(find.text('Deleted meforish'), findsOneWidget);
      expect(find.textContaining('4f3c1d9e'), findsNothing);
    });
  });
}
