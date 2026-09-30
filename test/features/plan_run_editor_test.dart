import 'dart:convert';

import 'package:chovos_hayom/application/plans.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:chovos_hayom/features/planner/edit_plan_advanced_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// #41's editor half: the unit range per sefer, the range wrap, the start date
/// and the two pacing modes.
///
/// **The two tests that matter most are the wrap and the pacing exclusivity**,
/// because both are the shape of #41 rather than a field on it. A range that
/// wraps has to survive a round trip as *wrapping* and not come back as a plain
/// finite range that silently reports a percentage; and pacing has to come back
/// as one answer, never as both.
void main() {
  const sonim = Size(240, 324);

  late InMemoryPreferences prefs;
  setUp(() => prefs = InMemoryPreferences());

  /// Yoma is the fake catalog's leaf: units 2..157, so a range has room at both
  /// ends and "the whole sefer" is not the same as any range a test states.
  const yoma = 'shas.moed.shabbos';

  LearningPlan seed({
    List<PlanItem> items = const [],
    Day? startDay,
    PlanPacing? pacing,
    int unitsPerDay = 10,
  }) =>
      LearningPlan(
        id: 'p',
        name: 'Yoma',
        unitsPerDay: unitsPerDay,
        assignments: const [PlanAssignment(id: 'a', rule: DailyRule())],
        items: items,
        startDay: startDay,
        pacing: pacing ?? AmountPerDay(unitsPerDay),
      );

  Future<void> put(LearningPlan plan) => prefs.setString(
      PrefKeys.scoped('default', PrefKeys.plans),
      jsonEncode(PlansConfig(plans: [plan]).toJson()));

  PlansConfig config() {
    final raw =
        prefs.getString(PrefKeys.scoped('default', PrefKeys.plans)) ?? '{}';
    return PlansConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  LearningPlan saved() => config().plans.single;

  Future<void> pump(WidgetTester tester, {Size? size}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size ?? const Size(800, 3000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(prefs),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(memoryRepository()),
          // A fixed clock, because the start date is *today* by default and a
          // test that reads today's date without pinning it passes on the day it
          // was written and fails tomorrow.
          clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
        ],
        child: localizedApp(home: const EditPlanAdvancedScreen(planId: 'p')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) =>
      scrollAndTap(tester, find.text('Save'));

  group('the range', () {
    testWidgets('an unset range says so rather than showing a blank',
        (tester) async {
      await put(seed(items: const [PlanItem(id: 'i1', nodeId: yoma)]));
      await pump(tester);
      // Read off the row, before saving: saving pops the screen.
      expect(find.textContaining('No last unit'), findsOneWidget);
      await save(tester);
      expect(saved().items.single.startUnit, isNull);
      expect(saved().items.single.endUnit, isNull);
    });

    testWidgets('a first and last unit are saved onto the item',
        (tester) async {
      await put(seed(items: const [PlanItem(id: 'i1', nodeId: yoma)]));
      await pump(tester);
      await tester.enterText(find.byKey(const ValueKey('range-from-i1')), '10');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('range-to-i1')), '40');
      await tester.pumpAndSettle();
      await save(tester);

      expect(saved().items.single.startUnit, 10);
      expect(saved().items.single.endUnit, 40);
    });

    testWidgets('clearing the last unit is saved as no end, not as the old one',
        (tester) async {
      await put(seed(
        items: const [
          PlanItem(id: 'i1', nodeId: yoma, startUnit: 10, endUnit: 40),
        ],
      ));
      await pump(tester);
      await tester.enterText(find.byKey(const ValueKey('range-to-i1')), '');
      await tester.pumpAndSettle();
      await save(tester);

      expect(saved().items.single.startUnit, 10, reason: 'untouched field holds');
      expect(saved().items.single.endUnit, isNull,
          reason: 'an emptied bound means "no end", and a copyWith-style fallback '
              'would put 40 back and make the field impossible to clear');
    });

    testWidgets('a range is shown on the row without being opened',
        (tester) async {
      await put(seed(
        items: const [
          PlanItem(id: 'i1', nodeId: yoma, startUnit: 10, endUnit: 40),
        ],
      ));
      await pump(tester);
      expect(find.textContaining('First unit 10'), findsOneWidget);
      expect(find.textContaining('Last unit 40'), findsOneWidget);
    });

    testWidgets('two seferim in a chain get their own ranges',
        (tester) async {
      await put(seed(items: const [
        PlanItem(id: 'i1', nodeId: yoma),
        PlanItem(id: 'i2', nodeId: 'shas.moed'),
      ]));
      await pump(tester);
      await tester.enterText(find.byKey(const ValueKey('range-to-i1')), '20');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('range-to-i2')), '50');
      await tester.pumpAndSettle();
      await save(tester);

      expect(saved().items[0].endUnit, 20);
      expect(saved().items[1].endUnit, 50,
          reason: 'keyed by item id, so the second sefer keeps its own');
    });
  });

  group('the range wrap', () {
    testWidgets('switching it on is saved, and survives as wrapping',
        (tester) async {
      await put(seed(items: const [
        PlanItem(id: 'i1', nodeId: yoma, startUnit: 10, endUnit: 40),
      ]));
      await pump(tester);
      await scrollAndTap(tester, find.byKey(const ValueKey('wrap-i1')));
      await save(tester);

      final item = saved().items.single;
      expect(item.wrapsRange, isTrue);
      expect(item.startUnit, 10);
      expect(item.endUnit, 40);
    });

    testWidgets('a wrapping range shows no total rather than a percentage',
        (tester) async {
      await put(seed(items: const [
        PlanItem(id: 'i1', nodeId: yoma, startUnit: 10, endUnit: 40, wrapsRange: true),
      ]));
      await pump(tester);
      // The owner's ruling: an endless plan has no denominator, so the line says
      // what it can say instead of printing "31 units in total" as though the
      // run were heading somewhere. The row still names the range's own bounds —
      // 10..40 is still what was asked for, it just is not the end of anything.
      expect(find.textContaining('First unit 10'), findsOneWidget);
      expect(find.textContaining('Last unit 40'), findsOneWidget);
      expect(find.textContaining('no end set'), findsOneWidget);
      expect(find.textContaining('units in total'), findsNothing,
          reason: 'a wrapping range has no total, and "31 units in total" is '
              'the fraction this is meant not to print');
    });

    testWidgets('a finite range still gets its total', (tester) async {
      await put(seed(items: const [
        PlanItem(id: 'i1', nodeId: yoma, startUnit: 10, endUnit: 40),
      ]));
      await pump(tester);
      expect(find.textContaining('31 units in total'), findsOneWidget);
    });

    testWidgets('the wrap switch is off by default for a single-sefer plan',
        (tester) async {
      // The two wraps are separate settings, and a single-sefer plan has no
      // chain to continue — so its only possible wrap is its own range, and it
      // is not on until asked for.
      await put(seed(items: const [PlanItem(id: 'i1', nodeId: yoma)]));
      await pump(tester);
      final tile = tester.widget<SwitchListTile>(
          find.byKey(const ValueKey('wrap-i1')));
      expect(tile.value, isFalse);
    });
  });

  group('the start date', () {
    testWidgets('a new plan starts today, and today is not stored',
        (tester) async {
      await put(seed());
      await pump(tester);
      final tile =
          tester.widget<SwitchListTile>(find.byKey(const ValueKey('start-today')));
      expect(tile.value, isTrue);
      await save(tester);
      expect(saved().startDay, isNull,
          reason: 'null means today and is deliberately not frozen to a date the '
              'user never chose');
    });

    testWidgets('switching it off reveals the date to choose', (tester) async {
      await put(seed());
      await pump(tester);
      expect(find.byKey(const ValueKey('start-day')), findsNothing);
      await scrollAndTap(tester, find.byKey(const ValueKey('start-today')));
      expect(find.byKey(const ValueKey('start-day')), findsOneWidget);
    });

    testWidgets('a plan with a start date shows it and keeps it',
        (tester) async {
      await put(seed(startDay: Day.of(DateTime(2026, 2, 1))));
      await pump(tester);
      final tile =
          tester.widget<SwitchListTile>(find.byKey(const ValueKey('start-today')));
      expect(tile.value, isFalse,
          reason: 'a stored date is a choice, and it must not read as "today"');
      await save(tester);
      expect(saved().startDay, Day.of(DateTime(2026, 2, 1)));
    });

    testWidgets('switching back to today clears the stored date',
        (tester) async {
      await put(seed(startDay: Day.of(DateTime(2026, 2, 1))));
      await pump(tester);
      await scrollAndTap(tester, find.byKey(const ValueKey('start-today')));
      await save(tester);
      expect(saved().startDay, isNull);
    });
  });

  group('pacing — one answer, never two', () {
    testWidgets('an amount-per-day plan asks for no date', (tester) async {
      await put(seed());
      await pump(tester);
      // The consequence, not the mechanism: the date field is absent because the
      // mode that needs it is not in force. Asserting on a radio's `value` would
      // only restate that a radio has a value.
      expect(find.byKey(const ValueKey('pacing-perDay')), findsOneWidget);
      expect(find.byKey(const ValueKey('pacing-finish-date')), findsNothing);
      await save(tester);
      expect(saved().pacing.unitsPerDay, 10);
      expect(saved().pacing.finishDay, isNull);
    });

    testWidgets('switching to finish-by asks for a date and saves only that',
        (tester) async {
      await put(seed(unitsPerDay: 12));
      await pump(tester);
      await scrollAndTap(
          tester, find.byKey(const ValueKey('pacing-finishBy')));
      expect(find.byKey(const ValueKey('pacing-finish-date')), findsOneWidget);
      await save(tester);

      final pacing = saved().pacing;
      expect(pacing.finishDay, isNotNull);
      expect(pacing.unitsPerDay, isNull,
          reason: 'the two answer the same question; saving both is the '
              'self-contradicting plan PlanPacing exists to make impossible');
    });

    testWidgets('a finish-by plan keeps its date and gains no amount',
        (tester) async {
      await put(seed(pacing: FinishBy(Day.of(DateTime(2026, 6, 1)))));
      await pump(tester);
      await save(tester);
      final pacing = saved().pacing;
      expect(pacing.finishDay, Day.of(DateTime(2026, 6, 1)));
      expect(pacing.unitsPerDay, isNull);
    });

    testWidgets('switching back to per-day keeps the amount already there',
        (tester) async {
      await put(seed(unitsPerDay: 7));
      await pump(tester);
      await scrollAndTap(tester, find.byKey(const ValueKey('pacing-finishBy')));
      await scrollAndTap(tester, find.byKey(const ValueKey('pacing-perDay')));
      await save(tester);
      expect(saved().pacing.unitsPerDay, 7,
          reason: 'flipping modes and back must not lose the answer already given');
    });
  });

  group('nothing not on this screen is lost', () {
    testWidgets('the new fields do not clobber name, rule or spillover',
        (tester) async {
      // The no-clobber guarantee, for the sections #41 added. A save here
      // rebuilds the plan, and everything this screen cannot see is what a
      // rebuild is most likely to drop.
      await put(LearningPlan(
        id: 'p',
        name: 'Yoma',
        unitsPerDay: 12,
        spillover: SpilloverMode.catchUp,
        displayCalendar: RuleCalendar.hebrew,
        assignments: const [
          PlanAssignment(id: 'a', rule: HebrewDayRule(day: 1), unitsPerFiring: 3),
        ],
        weekdayAmounts: const {DateTime.tuesday: 5},
        items: const [
          PlanItem(id: 'i1', nodeId: yoma, startUnit: 10, endUnit: 40),
        ],
        startDay: Day.of(DateTime(2026, 2, 1)),
        pacing: const AmountPerDay(12),
      ));
      await pump(tester);
      await scrollAndTap(tester, find.byKey(const ValueKey('wrap-i1')));
      await save(tester);

      final plan = saved();
      expect(plan.name, 'Yoma');
      expect(plan.unitsPerDay, 12);
      expect(plan.spillover, SpilloverMode.catchUp);
      expect(plan.displayCalendar, RuleCalendar.hebrew);
      expect(plan.assignments.single.rule, const HebrewDayRule(day: 1));
      expect(plan.assignments.single.unitsPerFiring, 3);
      expect(plan.weekdayAmounts[DateTime.tuesday], 5);
      expect(plan.startDay, Day.of(DateTime(2026, 2, 1)));
      expect(plan.items.single.wrapsRange, isTrue,
          reason: 'the one thing this save did change');
    });
  });

  group('the Sonim', () {
    /// Scrolls until [key] has been built, or gives up.
    ///
    /// The form builds lazily, so at 240x324 anything below the fold is simply
    /// not in the tree — and "No element" from `ensureVisible` says nothing
    /// about layout, which is all this group is testing.
    Future<void> scrollUntil(WidgetTester tester, Key key) async {
      for (var i = 0; i < 40 && find.byKey(key).evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -160));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('the range section lays out on a 240dp screen', (tester) async {
      await put(seed(items: const [
        PlanItem(id: 'i1', nodeId: yoma, startUnit: 10, endUnit: 40),
      ]));
      await pump(tester, size: sonim);
      await scrollUntil(tester, const ValueKey('wrap-i1'));
      // Two bound fields side by side is the tight spot here, and 240dp is the
      // device this ships to.
      expect(find.byKey(const ValueKey('range-from-i1')), findsOneWidget);
      expect(find.byKey(const ValueKey('range-to-i1')), findsOneWidget);
      expect(find.byKey(const ValueKey('wrap-i1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the pacing section lays out on a 240dp screen',
        (tester) async {
      await put(seed());
      await pump(tester, size: sonim);
      await scrollUntil(tester, const ValueKey('pacing-perDay'));
      expect(find.byKey(const ValueKey('pacing-perDay')), findsOneWidget);
      expect(find.byKey(const ValueKey('pacing-finishBy')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the start-date section lays out on a 240dp screen',
        (tester) async {
      await put(seed());
      await pump(tester, size: sonim);
      await scrollUntil(tester, const ValueKey('start-today'));
      expect(find.byKey(const ValueKey('start-today')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the wrap switch is reachable and works at 240dp',
        (tester) async {
      await put(seed(items: const [
        PlanItem(id: 'i1', nodeId: yoma, startUnit: 10, endUnit: 40),
      ]));
      await pump(tester, size: sonim);
      await scrollUntil(tester, const ValueKey('wrap-i1'));
      // `scrollUntil` stops as soon as the key exists, which means it can still
      // be built just off-screen — and a tap there hits nothing. `ensureVisible`
      // brings it onto the viewport before the tap.
      await tester.ensureVisible(find.byKey(const ValueKey('wrap-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wrap-i1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await save(tester);
      expect(saved().items.single.wrapsRange, isTrue,
          reason: 'reachable and working, not merely present');
    });
  });
}
