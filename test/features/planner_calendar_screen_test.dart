import 'dart:convert';

import 'package:chovos_hayom/application/plans.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/calendar.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:chovos_hayom/features/planner/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

void main() {
  testWidgets('switches between the month and week views', (tester) async {
    final prefs = InMemoryPreferences({
      PrefKeys.scoped('default', PrefKeys.plans): jsonEncode(
        const PlansConfig(
          plans: [
            LearningPlan(
              id: 'p',
              name: 'Daily',
              assignments: [
                PlanAssignment(
                  id: 'a',
                  rule: DailyRule(),
                  targetNodeId: 'shas.moed.shabbos',
                ),
              ],
            ),
          ],
        ).toJson(),
      ),
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(prefs),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(memoryRepository()),
          clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
        ],
        child: localizedApp(home: const PlannerCalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Planner calendar'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('Week'), findsOneWidget);
  });

  // A siyum gets a slot in the calendar so the user knows it is coming. The slot
  // is a projection off the same rolled-up log the confirmed siyumim come from,
  // so these tests drive the *real* forest and the *real* `SiyumSchedule` and
  // stub only the upstream pace signal.
  Future<void> pumpCalendar(WidgetTester tester) async {
    final prefs = InMemoryPreferences({
      PrefKeys.scoped('default', PrefKeys.plans): jsonEncode(
        const PlansConfig().toJson(),
      ),
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(prefs),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(memoryRepository()),
          clockProvider.overrideWithValue(() => DateTime(2026, 1, 1)),
          // Nothing logged, so the real pace would be 0 (and the honest answer
          // would be "never"). At 40/day the 156 daf under every node project to
          // ceil(156/40) = 4 days out — 4 Jan, which is inside the week
          // containing 1 Jan (Mon 29 Dec - Sun 4 Jan) as well as the month grid.
          paceProvider.overrideWithValue(40),
        ],
        child: localizedApp(home: const PlannerCalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a scheduled siyum is starred in the month grid',
      (tester) async {
    await pumpCalendar(tester);

    // Root, Shas, Moed and Shabbos all owe the same 156 units, so they share one
    // projected day and therefore one star — grouped, not five overlapping ones.
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Siyum')), findsOneWidget);
  });

  testWidgets('the week view names the siyum due that day', (tester) async {
    await pumpCalendar(tester);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    // The week list shows the sefer's name under the day, not a bare count.
    expect(find.textContaining('Kol HaTorah Kula'), findsWidgets);
  });

  // #29: the week view used to be `start = first` — the 1st of the displayed
  // month — so it always listed days 1-7 regardless of today, and its arrows
  // moved a whole month. The old test only checked the 'Week' label survived the
  // tap, which passes on the broken anchoring; these assert *which* days.
  group('the week view shows a real week', () {
    Future<void> pumpAt(WidgetTester tester, DateTime now) async {
      // Tall enough that all seven rows are built: a ListView only lays out
      // what fits, and this test is about *which* seven days those are.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider
                .overrideWithValue(InMemoryPreferences()),
            catalogRepositoryProvider
                .overrideWithValue(FakeCatalogRepository()),
            progressRepositoryProvider
                .overrideWithValue(memoryRepository()),
            clockProvider.overrideWithValue(() => now),
          ],
          child: localizedApp(home: const PlannerCalendarScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
    }

    /// The seven rows, in order, as the dates they render.
    List<String> rows(WidgetTester tester) => [
          for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
            (tile.title! as Text).data!,
        ];

    testWidgets('the week containing today, Monday to Sunday', (tester) async {
      // 10 Jan 2026 is a Saturday, so its week is Mon 5 Jan - Sun 11 Jan.
      // Under the old anchoring this showed 1-7 Jan and never included today.
      await pumpAt(tester, DateTime(2026, 1, 10));
      expect(rows(tester), [
        '2026-01-05',
        '2026-01-06',
        '2026-01-07',
        '2026-01-08',
        '2026-01-09',
        '2026-01-10',
        '2026-01-11',
      ]);
    });

    testWidgets('a Monday anchors its own week', (tester) async {
      // 5 Jan 2026 is a Monday: the containing week is 5-11 Jan, not 1-7.
      await pumpAt(tester, DateTime(2026, 1, 5));
      expect(rows(tester).first, '2026-01-05');
      expect(rows(tester).last, '2026-01-11');
    });

    testWidgets('a Sunday belongs to the week that started six days earlier',
        (tester) async {
      // 11 Jan 2026 is a Sunday; its week still starts Mon 5 Jan.
      await pumpAt(tester, DateTime(2026, 1, 11));
      expect(rows(tester).first, '2026-01-05');
      expect(rows(tester).last, '2026-01-11');
    });

    testWidgets('next moves one week, not one month', (tester) async {
      await pumpAt(tester, DateTime(2026, 1, 10));
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(rows(tester).first, '2026-01-12');
      expect(rows(tester).last, '2026-01-18');
    });

    testWidgets('previous moves one week back', (tester) async {
      await pumpAt(tester, DateTime(2026, 1, 10));
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(rows(tester).first, '2025-12-29');
      expect(rows(tester).last, '2026-01-04');
    });

    testWidgets('month range still steps a month at a time', (tester) async {
      // The week fix must not have broken month navigation.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider
                .overrideWithValue(InMemoryPreferences()),
            catalogRepositoryProvider
                .overrideWithValue(FakeCatalogRepository()),
            progressRepositoryProvider
                .overrideWithValue(memoryRepository()),
            clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
          ],
          child: localizedApp(home: const PlannerCalendarScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2026-01-01'), findsOneWidget, reason: 'January');

      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('2026-02-01'), findsOneWidget, reason: 'February');
    });

    testWidgets('a month step from the 31st clamps instead of spilling over',
        (tester) async {
      // 31 Jan + 1 month is 28 Feb, not 3 Mar. Overflow here would silently
      // land the view in the wrong month.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider
                .overrideWithValue(InMemoryPreferences()),
            catalogRepositoryProvider
                .overrideWithValue(FakeCatalogRepository()),
            progressRepositoryProvider
                .overrideWithValue(memoryRepository()),
            clockProvider.overrideWithValue(() => DateTime(2026, 1, 31)),
          ],
          child: localizedApp(home: const PlannerCalendarScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('2026-02-01'), findsOneWidget);
    });
  });

  // #30: the week rows used `day.toString()`, which `Day` documents as
  // "diagnostics and test failure output only" - so a Hebrew user got a Hebrew
  // month heading directly above an ISO date column. Note Gregorian mode *is*
  // ISO too (see `DateDisplay.format`), so only Hebrew mode can tell the two
  // apart; the Gregorian half is pinned so the fix cannot quietly change it.
  group('the week list renders dates through DateDisplay', () {
    Future<void> pumpWeek(
      WidgetTester tester, {
      required DateTime now,
      required String calendarMode,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(
              InMemoryPreferences({PrefKeys.calendarMode: calendarMode}),
            ),
            catalogRepositoryProvider
                .overrideWithValue(FakeCatalogRepository()),
            progressRepositoryProvider
                .overrideWithValue(memoryRepository()),
            clockProvider.overrideWithValue(() => now),
          ],
          child: localizedApp(home: const PlannerCalendarScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
    }

    List<String> weekRowTitles(WidgetTester tester) => [
          for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
            (tile.title! as Text).data!,
        ];

    testWidgets('Hebrew mode shows Hebrew dates, not ISO', (tester) async {
      await pumpWeek(tester,
          now: DateTime(2026, 1, 5), calendarMode: 'hebrew');
      final titles = weekRowTitles(tester);
      expect(titles, hasLength(7));
      // 5 Jan 2026 is a Monday, so the week is 5-11 Jan.
      for (var i = 0; i < 7; i++) {
        expect(
          titles[i],
          DateDisplay.format(DateTime(2026, 1, 5 + i), CalendarMode.hebrew),
          reason: 'row $i must go through the display layer',
        );
      }
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(w.data ?? ''),
        ),
        findsNothing,
        reason: 'no raw ISO date may reach the user',
      );
    });

    testWidgets('Gregorian mode is unchanged, since DateDisplay is ISO there',
        (tester) async {
      await pumpWeek(tester,
          now: DateTime(2026, 1, 5), calendarMode: 'gregorian');
      expect(weekRowTitles(tester).first, '2026-01-05');
    });
  });
}
