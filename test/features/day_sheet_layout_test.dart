import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/calendar.dart';
import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/features/planner/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// #48 — the day sheet's layout is a setting, with three of them.
///
/// **What is asserted here is which *shape* each layout puts on the screen**,
/// because that is the whole of the feature: the same units, the same tick, the
/// same three commands, arranged differently. So every test asks "is this row
/// where this layout says it should be", not "does the sheet still work" — the
/// latter is already held by `day_ledger_screen_test.dart` and
/// `day_commands_test.dart`, which run against all of this unchanged.
void main() {
  const shabbos = 'shas.moed.shabbos';
  final theDay = DateTime(2026, 1, 5);
  final dayKey = ValueKey('day-${Day.of(theDay).ordinal}');

  /// Two plans, both firing on the 5th, over overlapping ranges of the same
  /// sefer. Two is the case the issue names — "Daf Yomi *and* seven blatt of a
  /// different mesechta" — and the reason **grouped** is the default: a layout
  /// that stays readable with several plans firing is the one that has to be the
  /// one you get without choosing.
  const plansJson =
      '{"plans":['
      '{"id":"daf","name":"Daf Yomi","displayCalendar":"gregorian",'
      '"assignments":[{"id":"a","rule":{"type":"daily"}}],"overrides":[],'
      '"unitsPerDay":2,"spillover":"ignore","flowsToNextItem":false,'
      '"items":[{"id":"i1","nodeId":"$shabbos","startUnit":2,"endUnit":6}]},'
      '{"id":"other","name":"Other","displayCalendar":"gregorian",'
      '"assignments":[{"id":"a","rule":{"type":"daily"}}],"overrides":[],'
      '"unitsPerDay":2,"spillover":"ignore","flowsToNextItem":false,'
      '"items":[{"id":"i1","nodeId":"$shabbos","startUnit":7,"endUnit":11}]}'
      ']}';

  /// The day sheet, open on [theDay], with [layout] as the stored setting.
  ///
  /// The setting is **seeded into preferences** rather than set through the
  /// Settings screen: this file is about what each layout renders, and driving
  /// the control would test the control. `settings_day_sheet_test.dart` covers
  /// the control.
  Future<void> openSheet(
    WidgetTester tester, {
    DaySheetLayout? layout,
    Size size = const Size(900, 1600),
  }) async {
    final prefs = InMemoryPreferences({
      PrefKeys.scoped('default', PrefKeys.plans): plansJson,
      if (layout != null)
        PrefKeys.scoped('default', PrefKeys.daySheetLayout): layout.name,
    });
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(prefs),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(memoryRepository()),
          clockProvider.overrideWithValue(() => theDay),
        ],
        child: localizedApp(home: const PlannerCalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(dayKey));
    await tester.pumpAndSettle();
  }

  /// A ledger row, which every layout renders with the same key.
  Finder box(String planId, int unit) =>
      find.byKey(ValueKey('ledger-$planId-$shabbos-$unit'));

  group('the default', () {
    testWidgets('is grouped by plan, with no setting stored', (tester) async {
      // **Absent, not "the first value".** The fallback is named `byPlan`
      // explicitly so that a layout added above it in the enum cannot silently
      // become what every existing install sees.
      await openSheet(tester);

      expect(find.byKey(const ValueKey('amount-daf')), findsOneWidget);
      expect(find.byKey(const ValueKey('amount-other')), findsOneWidget);
      expect(box('daf', 2), findsOneWidget);
      expect(box('other', 7), findsOneWidget);
      expect(
        find.byKey(const ValueKey('collapsed-tile-daf')),
        findsNothing,
        reason: 'grouped has no collapsed summary to expand',
      );
    });

    testWidgets("groups each plan's units under its own amount row", (
      tester,
    ) async {
      await openSheet(tester);

      // The point of the default: each plan's amount, its reflow and its own
      // units sit together, so "what does *this* plan want here" is one place.
      final amountY = tester.getTopLeft(
        find.byKey(const ValueKey('amount-daf')),
      );
      final unitY = tester.getTopLeft(box('daf', 2));
      final amountOther = tester.getTopLeft(
        find.byKey(const ValueKey('amount-other')),
      );
      final unitOther = tester.getTopLeft(box('other', 7));

      expect(unitY.dy, greaterThan(amountY.dy));
      expect(unitOther.dy, greaterThan(amountOther.dy));
      expect(
        unitOther.dy,
        greaterThan(unitY.dy),
        reason: "the second plan's units come after the first plan's block",
      );
    });
  });

  group('flat', () {
    testWidgets('lists every unit, naming the plan on each row', (
      tester,
    ) async {
      await openSheet(tester, layout: DaySheetLayout.flat);

      expect(box('daf', 2), findsOneWidget);
      expect(box('other', 7), findsOneWidget);
      // **The plan on the row**, because there is no group above it saying which
      // plan a unit belongs to. Without it the two plans' units are one
      // unattributable list.
      expect(
        find.textContaining('Daf Yomi · Owed'),
        findsNWidgets(2),
        reason: 'two units under Daf Yomi, each naming its plan',
      );
      expect(find.textContaining('Other · Owed'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('collapsed-tile-daf')),
        findsNothing,
        reason: 'nothing to expand in a flat list',
      );
    });

    testWidgets('puts all the amount rows above every unit', (tester) async {
      await openSheet(tester, layout: DaySheetLayout.flat);

      final secondAmount = tester.getTopLeft(
        find.byKey(const ValueKey('amount-other')),
      );
      final firstUnit = tester.getTopLeft(box('daf', 2));
      expect(
        firstUnit.dy,
        greaterThan(secondAmount.dy),
        reason: 'amounts are grouped at the top, then one list of units',
      );
    });
  });

  group('collapsed', () {
    testWidgets('shows one line per plan and hides the units', (tester) async {
      await openSheet(tester, layout: DaySheetLayout.collapsed);

      expect(find.byKey(const ValueKey('collapsed-tile-daf')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('collapsed-tile-other')),
        findsOneWidget,
      );
      // **Collapsed by default** — the layout exists for a day with many plans
      // and little interest in most of them; starting expanded would be the
      // grouped layout with extra steps.
      expect(box('daf', 2), findsNothing);
      expect(box('other', 7), findsNothing);
    });

    testWidgets('and the count is on the line even while collapsed', (
      tester,
    ) async {
      // The whole reason to pick this layout rather than to scroll: a glance
      // still says whether anything is outstanding.
      await openSheet(tester, layout: DaySheetLayout.collapsed);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('collapsed-tile-daf')),
          matching: find.textContaining('0 of 2'),
        ),
        findsOneWidget,
      );
    });

    testWidgets("expanding shows that plan's units", (tester) async {
      await openSheet(tester, layout: DaySheetLayout.collapsed);

      await tester.tap(find.byKey(const ValueKey('collapsed-tile-daf')));
      await tester.pumpAndSettle();
      expect(box('daf', 2), findsOneWidget);
      // And only that plan's: the other line is still shut.
      expect(box('other', 7), findsNothing);

      await tester.tap(find.byKey(const ValueKey('collapsed-tile-other')));
      await tester.pumpAndSettle();
      expect(box('other', 7), findsOneWidget);
      expect(box('daf', 2), findsOneWidget, reason: 'the first stays open');
    });
  });

  group('what is the same in all three', () {
    // A layout switch that also moved these would be three settings to learn
    // rather than one, so they are asserted to be invariant.
    for (final layout in DaySheetLayout.values) {
      testWidgets('${layout.name}: the commands and the per-plan rows', (
        tester,
      ) async {
        await openSheet(tester, layout: layout);

        expect(
          find.byKey(const ValueKey('day-add')),
          findsOneWidget,
          reason: 'doing extra work on a quiet day is how `+` is reached',
        );
        expect(find.byKey(const ValueKey('day-remove')), findsOneWidget);
        expect(find.byKey(const ValueKey('amount-daf')), findsOneWidget);
      });

      testWidgets('${layout.name}: a plan\'s own actions are reachable', (
        tester,
      ) async {
        await openSheet(tester, layout: layout);

        // **Behind the plan's own expansion in the collapsed layout**, and that
        // is the design rather than an omission: the reflow is something you do
        // *to one plan*, and the layout exists for a day with many plans and
        // little interest in most of them. Opening the plan you mean is the
        // price of the compact view, and it is paid only on the plan it applies
        // to.
        if (layout == DaySheetLayout.collapsed) {
          await tester.tap(find.byKey(const ValueKey('collapsed-tile-daf')));
          await tester.pumpAndSettle();
        }
        expect(
          find.byKey(const ValueKey('recompute-open-daf')),
          findsOneWidget,
        );
        if (layout == DaySheetLayout.collapsed) {
          expect(
            find.byKey(const ValueKey('recompute-open-other')),
            findsNothing,
            reason: 'and only for the plan that was opened',
          );
        }
      });
    }
  });

  group('the D-pad device', () {
    testWidgets('every layout lays out on a 240dp screen', (tester) async {
      for (final layout in DaySheetLayout.values) {
        await openSheet(tester, layout: layout, size: const Size(240, 900));
        expect(
          tester.takeException(),
          isNull,
          reason: 'the ${layout.name} layout must fit 240dp',
        );
      }
    });
  });
}
