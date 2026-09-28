import 'dart:convert';

import 'package:chovos_hayom/application/plans.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/calendar.dart';
import 'package:chovos_hayom/core/day.dart';
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
      // "Next week", not "Next month": the arrow's label follows the range it
      // is in, so it cannot contradict what the button does. A tooltip that
      // says month on a week view is a lie a screen reader would read out.
      expect(find.byTooltip('Next month'), findsNothing);
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      expect(rows(tester).first, '2026-01-12');
      expect(rows(tester).last, '2026-01-18');
    });

    testWidgets('previous moves one week back', (tester) async {
      await pumpAt(tester, DateTime(2026, 1, 10));
      await tester.tap(find.byTooltip('Previous week'));
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

  // #31: the calendar had day and week *stepping* but no day range at all, and
  // no way to browse by anything but the two arrow buttons — which is a poor fit
  // for a D-pad phone and useless for "get me to roughly next month".
  group('day, week and month, browsable by scroll', () {
    /// A plan asking six units a day, so a day page has something to name.
    String dailyPlanJson() => jsonEncode(const PlansConfig(plans: [
          LearningPlan(
            id: 'p',
            name: 'Yoma',
            unitsPerDay: 6,
            assignments: [
              PlanAssignment(
                id: 'a',
                rule: DailyRule(),
                targetNodeId: 'shas.moed.shabbos',
              ),
            ],
          ),
        ]).toJson());

    Future<void> pumpAt(
      WidgetTester tester, {
      required DateTime now,
      String? plansJson,
      Size size = const Size(800, 1400),
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final prefs = InMemoryPreferences(plansJson == null
          ? null
          : {PrefKeys.scoped('default', PrefKeys.plans): plansJson});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(prefs),
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
    }

    /// The heading above the pages: what the current range is called, and when.
    ///
    /// By key rather than by content, because this is the one thing every
    /// paging assertion is about and a bare `Text` among several identical ones
    /// is not something a finder can point at.
    String heading(WidgetTester tester) => (tester
            .widget<Text>(find.descendant(
                of: find.byKey(const ValueKey('calendar-heading')),
                matching: find.byType(Text))))
        .data!;

    testWidgets('all three ranges are offered', (tester) async {
      await pumpAt(tester, now: DateTime(2026, 1, 10));
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
    });

    testWidgets('the day view names each plan firing that day', (tester) async {
      await pumpAt(tester, now: DateTime(2026, 1, 10), plansJson: dailyPlanJson());
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();

      // The day page says which plan, not just how much: forty-two month cells
      // have room for a number, one day page has the whole screen.
      expect(find.text('Yoma'), findsOneWidget);
      expect(find.textContaining('6'), findsWidgets);
      // And the weekday, since a date alone is half the answer.
      expect(find.text('Saturday'), findsOneWidget);
    });

    testWidgets('a day with nothing on it says so rather than showing nothing',
        (tester) async {
      await pumpAt(tester, now: DateTime(2026, 1, 10));
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
      // An empty screen is not an answer: "nothing is scheduled" is a fact and
      // this is the only place that can say it.
      expect(find.text('Nothing is scheduled on this day.'), findsOneWidget);
    });

    testWidgets('a day range steps one day at a time', (tester) async {
      await pumpAt(tester, now: DateTime(2026, 1, 10));
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
      expect(heading(tester), '2026-01-10');

      await tester.tap(find.byTooltip('Next day'));
      await tester.pumpAndSettle();
      expect(heading(tester), '2026-01-11');

      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();
      expect(heading(tester), '2026-01-10');
    });

    testWidgets('the arrows are named for the range they are in', (tester) async {
      await pumpAt(tester, now: DateTime(2026, 1, 10));
      expect(find.byTooltip('Next month'), findsOneWidget);
      expect(find.byTooltip('Next week'), findsNothing);

      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Next week'), findsOneWidget);
      expect(find.byTooltip('Next month'), findsNothing);

      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Next day'), findsOneWidget);
      expect(find.byTooltip('Next week'), findsNothing);
    });

    testWidgets('the heading names the span actually shown', (tester) async {
      // 10 Jan 2026 is a Saturday, so its week is Mon 5 - Sun 11 Jan. A heading
      // of "2026-01-01" over that week is a heading about the wrong month, and
      // it is what every range used to print.
      await pumpAt(tester, now: DateTime(2026, 1, 10));
      expect(heading(tester), '2026-01-01', reason: 'January, by its own name');

      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(heading(tester), '2026-01-05 – 2026-01-11');

      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
      expect(heading(tester), '2026-01-10');
    });

    testWidgets('a month page is named by its month, not by its first cell',
        (tester) async {
      // 1 Jan 2026 is a Thursday, so the grid opens on Mon 29 Dec 2025 to fill
      // six rows. Printing that would put December over January.
      await pumpAt(tester, now: DateTime(2026, 1, 10));
      expect(heading(tester), '2026-01-01');
      // And the first cell really is the padding day, so the two are different
      // things rather than one being a bug.
      expect(
        find.byKey(ValueKey('day-${Day.of(DateTime(2025, 12, 29)).ordinal}')),
        findsOneWidget,
      );
    });

    /// A left swipe on the pager: what a thumb or a D-pad user does to page.
    Future<void> swipeForward(WidgetTester tester) async {
      await tester.fling(
        find.byType(PageView),
        const Offset(-400, 0),
        1000,
      );
      await tester.pumpAndSettle();
    }

    Future<void> swipeBack(WidgetTester tester) async {
      await tester.fling(
        find.byType(PageView),
        const Offset(400, 0),
        1000,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a swipe pages forward by one unit, and back again',
        (tester) async {
      await pumpAt(tester, now: DateTime(2026, 1, 10));
      // Month, because a month is the unit a swipe is really for.
      expect(heading(tester), '2026-01-01');

      await swipeForward(tester);
      expect(heading(tester), '2026-02-01', reason: 'one month on');

      await swipeForward(tester);
      expect(heading(tester), '2026-03-01');

      await swipeBack(tester);
      expect(heading(tester), '2026-02-01', reason: 'and back again');
    });

    testWidgets('a swipe pages in the range it is in', (tester) async {
      await pumpAt(tester, now: DateTime(2026, 1, 10));
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
      expect(heading(tester), '2026-01-10');

      await swipeForward(tester);
      expect(heading(tester), '2026-01-11', reason: 'a day swipe is a day');

      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      // The anchor is still the day the swipes left it on, and the week range
      // shows the week containing it — the same anchor, a different window.
      expect(heading(tester), '2026-01-05 – 2026-01-11');
    });

    testWidgets('a page shows its own days, not the anchor page behind it',
        (tester) async {
      // The failure this guards: a pager that computes one window and draws it
      // three times, so the page a swipe arrives at is a copy of the one behind
      // it. Asserted on the rows of the page that is actually showing.
      await pumpAt(tester,
          now: DateTime(2026, 1, 10), plansJson: dailyPlanJson());
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(find.text('2026-01-05'), findsOneWidget, reason: 'this week');
      expect(find.text('2026-01-10'), findsOneWidget, reason: 'and today in it');
      expect(find.text('2026-01-11'), findsOneWidget, reason: 'its Sunday');

      await swipeForward(tester);
      // A different week, ending on its own Sunday: the one after 5-11 Jan is
      // 12-18, not 12-19, and a window that had re-used the old one would still
      // be showing the 5th.
      expect(find.text('2026-01-12'), findsOneWidget);
      expect(find.text('2026-01-18'), findsOneWidget);
      expect(find.text('2026-01-05'), findsNothing);
    });

    testWidgets('paging never materialises more than three windows',
        (tester) async {
      // The cost promise: on-demand generation means a swipe moves a window, it
      // does not build a calendar. Counted in *day cells*, which is what is
      // actually built, and bounded by three pages' worth — 42 each.
      int dayCells() => find
          .byWidgetPredicate((w) =>
              w.key is ValueKey && '${(w.key! as ValueKey).value}'.startsWith('day-'))
          .evaluate()
          .length;

      await pumpAt(tester, now: DateTime(2026, 1, 10));
      for (var i = 0; i < 6; i++) {
        await swipeForward(tester);
        expect(dayCells(), lessThanOrEqualTo(3 * 42),
            reason: 'after $i swipes only three pages may exist');
      }
      // Six month-swipes from January is July, and the cost did not grow: this
      // is what a pager over every day of a year would have cost instead.
      expect(heading(tester), '2026-07-01');
      expect(dayCells(), lessThanOrEqualTo(3 * 42));
    });

    testWidgets('the whole calendar lays out on a 240dp screen', (tester) async {
      for (final range in ['Day', 'Week', 'Month']) {
        await pumpAt(tester,
            now: DateTime(2026, 1, 10),
            plansJson: dailyPlanJson(),
            size: const Size(240, 324));
        await tester.tap(find.text(range));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: range);
      }
    });
  });

  // #28: the calendar is where a schedule is actually *used*, so the amount
  // belongs here. Two facts must never be blurred: "0 units" is a deliberate day
  // off, and "nothing scheduled" is a different thing entirely.
  group('the calendar shows what each day asks for', () {
    Future<void> pumpWith(WidgetTester tester, String plansJson) async {
      final prefs = InMemoryPreferences({
        PrefKeys.scoped('default', PrefKeys.plans): plansJson,
      });
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(900, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(prefs),
            catalogRepositoryProvider
                .overrideWithValue(FakeCatalogRepository()),
            progressRepositoryProvider
                .overrideWithValue(memoryRepository()),
            clockProvider.overrideWithValue(() => DateTime(2026, 1, 1)),
          ],
          child: localizedApp(home: const PlannerCalendarScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// A daily plan asking six units, targeting the fake catalog's Shabbos.
    String sixADayJson({int unitsPerDay = 6, Map<String, int>? dates}) =>
        jsonEncode(PlansConfig(plans: [
          LearningPlan(
            id: 'p',
            name: 'Yoma',
            unitsPerDay: unitsPerDay,
            dateAmounts: {
              for (final e in (dates ?? const <String, int>{}).entries)
                Day.of(DateTime.parse(e.key)): e.value,
            },
            assignments: [
              const PlanAssignment(
                id: 'a',
                rule: DailyRule(),
                targetNodeId: 'shas.moed.shabbos',
              ),
            ],
          ),
        ]).toJson());

    testWidgets('a month cell states the units due that day',
        (tester) async {
      await pumpWith(tester, sixADayJson());
      // The cell states the total for its day, so the number is on the calendar
      // and not only in the editor.
      expect(
        find.descendant(
          of: find.byKey(
              ValueKey('day-${Day.of(DateTime(2026, 1, 5)).ordinal}')),
          matching: find.text('6'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping a day opens what each plan asks of it', (tester) async {
      await pumpWith(tester, sixADayJson());
      await tester.tap(find.byKey(ValueKey('day-${Day.of(DateTime(2026, 1, 5)).ordinal}')));
      await tester.pumpAndSettle();
      expect(find.text('Yoma'), findsOneWidget, reason: 'the plan, by name');
      expect(find.textContaining('6'), findsWidgets);
    });

    testWidgets('a day off reads as a day off, not as an empty day',
        (tester) async {
      await pumpWith(
        tester,
        sixADayJson(dates: {'2026-01-05': 0}),
      );
      await tester.tap(find.byKey(ValueKey('day-${Day.of(DateTime(2026, 1, 5)).ordinal}')));
      await tester.pumpAndSettle();
      // The distinction the whole design turns on: 0 is a fact, and saying so is
      // the UI's job because nothing else will.
      expect(find.textContaining('day off'), findsOneWidget);
    });

    testWidgets('setting a day to 0 from the calendar writes a date override',
        (tester) async {
      final prefs = InMemoryPreferences({
        PrefKeys.scoped('default', PrefKeys.plans): sixADayJson(),
      });
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(900, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(prefs),
            catalogRepositoryProvider
                .overrideWithValue(FakeCatalogRepository()),
            progressRepositoryProvider
                .overrideWithValue(memoryRepository()),
            clockProvider.overrideWithValue(() => DateTime(2026, 1, 1)),
          ],
          child: localizedApp(home: const PlannerCalendarScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('day-${Day.of(DateTime(2026, 1, 5)).ordinal}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '0');
      // One confirmation, not two: accepting the prompt writes the override and
      // closes the sheet. There is no separate save step to press.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // Edits the *plan*, never the log: a date override on 5 Jan at 0.
      final stored = PlansConfig.fromJson(
          (jsonDecode(prefs.getString(
                      PrefKeys.scoped('default', PrefKeys.plans)) ??
                  '{}') as Map)
              .cast<String, dynamic>());
      expect(stored.plans.single.dateAmounts,
          {Day.of(DateTime(2026, 1, 5)): 0});
    });

    testWidgets('a bad amount is refused and the plan is left alone',
        (tester) async {
      final prefs = InMemoryPreferences({
        PrefKeys.scoped('default', PrefKeys.plans): sixADayJson(),
      });
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(900, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(prefs),
            catalogRepositoryProvider
                .overrideWithValue(FakeCatalogRepository()),
            progressRepositoryProvider
                .overrideWithValue(memoryRepository()),
            clockProvider.overrideWithValue(() => DateTime(2026, 1, 1)),
          ],
          child: localizedApp(home: const PlannerCalendarScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('day-${Day.of(DateTime(2026, 1, 5)).ordinal}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '-1');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a whole number, zero or more.'), findsOneWidget);
      final stored = PlansConfig.fromJson(
          (jsonDecode(prefs.getString(
                      PrefKeys.scoped('default', PrefKeys.plans)) ??
                  '{}') as Map)
              .cast<String, dynamic>());
      expect(stored.plans.single.dateAmounts, isEmpty,
          reason: 'a refused amount must not be half-saved');
    });
  });
}
