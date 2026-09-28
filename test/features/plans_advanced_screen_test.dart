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

/// The depth of a plan: the days that differ from the base amount, and the
/// seferim it works through in order (#35).
///
/// The test that matters most here is the one about `0`. A day off is an amount
/// rather than a flag precisely so that "nothing on this day" and "not set" stay
/// different facts, and the UI is the only place that can blur them.
void main() {
  const sonim = Size(240, 324);

  late InMemoryPreferences prefs;

  setUp(() => prefs = InMemoryPreferences());

  LearningPlan seed({int unitsPerDay = 10}) => LearningPlan(
        id: 'p',
        name: 'Yoma',
        unitsPerDay: unitsPerDay,
        assignments: const [PlanAssignment(id: 'a', rule: DailyRule())],
      );

  Future<void> put(LearningPlan plan) => prefs.setString(
      PrefKeys.scoped('default', PrefKeys.plans),
      jsonEncode(PlansConfig(plans: [plan]).toJson()));

  PlansConfig config() {
    final raw =
        prefs.getString(PrefKeys.scoped('default', PrefKeys.plans)) ?? '{}';
    return PlansConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

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

  /// Picks a weekday in the picker sheet, then types an amount and saves.
  Future<void> addWeekday(
    WidgetTester tester,
    String weekdayName,
    String amount,
  ) async {
    await scrollAndTap(tester, find.text('Add a weekday'));
    // A weekday that already has an override shows twice - as its row and in
    // the sheet - and the sheet is on top, so the last match is the right one.
    await scrollAndTap(tester, find.text(weekdayName).last);
    await tester.enterText(find.byType(TextField).last, amount);
    await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Save'));
  }


  group('weekday overrides', () {
    testWidgets('says so when every day is the same', (tester) async {
      await put(seed());
      await pump(tester);
      expect(find.text('Every day asks the same amount.'), findsOneWidget);
    });

    testWidgets('an added weekday shows its own amount, not the base',
        (tester) async {
      await put(seed());
      await pump(tester);
      await addWeekday(tester, 'Tuesday', '5');
      // Asserted before saving: saving pops the screen, so afterwards there is
      // nothing left to read the row off.
      expect(find.text('5'), findsOneWidget,
          reason: 'the base is 10, so a row reading "10" would prove nothing');
      await scrollAndTap(tester, find.text('Save'));
      expect(config().plans.single.weekdayAmounts, {DateTime.tuesday: 5});
    });

    testWidgets('two weekdays can differ from each other', (tester) async {
      await put(seed());
      await pump(tester);
      await addWeekday(tester, 'Tuesday', '5');
      await addWeekday(tester, 'Thursday', '15');
      await scrollAndTap(tester, find.text('Save'));

      expect(config().plans.single.weekdayAmounts,
          {DateTime.tuesday: 5, DateTime.thursday: 15});
    });

    testWidgets('a weekday can be removed again', (tester) async {
      await put(const LearningPlan(
        id: 'p',
        name: 'Yoma',
        unitsPerDay: 10,
        weekdayAmounts: {DateTime.friday: 3},
        assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
      ));
      await pump(tester);
      expect(find.text('3'), findsOneWidget);

      // Keyed, because a ListView only builds what is on screen: locating the
      // row by its text, or by "the last tile", silently depends on scroll
      // position and breaks the moment a row is added or removed.
      await scrollAndTap(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('weekday-${DateTime.friday}')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await scrollAndTap(tester, find.text('Save'));
      expect(config().plans.single.weekdayAmounts, isEmpty);
    });

    testWidgets('a bad amount is refused, not saved', (tester) async {
      await put(seed());
      await pump(tester);
      await scrollAndTap(tester, find.text('Add a weekday'));
      await scrollAndTap(tester, find.text('Wednesday'));
      await tester.enterText(find.byType(TextField).last, '-3');
      await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Save'));
      expect(find.text('Enter a whole number, zero or more.'), findsOneWidget);

      // And the sheet is still open, so nothing was silently stored.
      expect(config().plans.single.weekdayAmounts, isEmpty);
    });
  });

  group('zero is a deliberate amount, not an empty field', () {
    testWidgets('a weekday set to 0 says so', (tester) async {
      await put(seed());
      await pump(tester);
      await addWeekday(tester, 'Friday', '0');

      // "0" alone is a number the eye slides past; "0 · day off" is a fact.
      expect(find.text('0 · day off'), findsOneWidget);
      expect(find.text('Every day asks the same amount.'), findsNothing,
          reason: 'a rest day is not the same as no override');

      await scrollAndTap(tester, find.text('Save'));
      expect(config().plans.single.weekdayAmounts, {DateTime.friday: 0});
    });

    testWidgets('a date set to 0 says so and survives the round trip',
        (tester) async {
      await put(seed());
      await pump(tester);
      await scrollAndTap(tester, find.text('Add a date'));
      // The picker opens on the clock's day; take it as-is.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '0');
      await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Save'));

      expect(find.text('0 · day off'), findsOneWidget);
      await scrollAndTap(tester, find.text('Save'));

      final dates = config().plans.single.dateAmounts;
      expect(dates, hasLength(1));
      expect(dates.values.single, 0);
    });
  });

  group('date overrides', () {
    testWidgets('says so when no date differs', (tester) async {
      await put(seed());
      await pump(tester);
      expect(find.text('Every date asks the same amount.'), findsOneWidget);
    });

    testWidgets('an added date is stored under its own day', (tester) async {
      await put(seed());
      await pump(tester);
      await scrollAndTap(tester, find.text('Add a date'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '4');
      await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Save'));
      await scrollAndTap(tester, find.text('Save'));

      // The clock's day, derived rather than hard-coded: a guessed ordinal is
      // how this test came to expect 11 April.
      expect(config().plans.single.dateAmounts, {Day.of(DateTime(2026, 1, 10)): 4});
    });

    testWidgets('a date can be removed', (tester) async {
      await put(seed(
        unitsPerDay: 10,
      ));
      await pump(tester);
      await scrollAndTap(tester, find.text('Add a date'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '4');
      await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Save'));
      await scrollAndTap(
        tester,
        find.descendant(
          of: find.byKey(ValueKey('date-${Day.of(DateTime(2026, 1, 10))}')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await scrollAndTap(tester, find.text('Save'));
      expect(config().plans.single.dateAmounts, isEmpty);
    });
  });



  group('robustness and the D-pad device', () {
    testWidgets('a plan that no longer exists does not throw', (tester) async {
      await put(seed());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(prefs),
            catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
            progressRepositoryProvider.overrideWithValue(memoryRepository()),
            clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
          ],
          child: localizedApp(
              home: const EditPlanAdvancedScreen(planId: 'gone')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the whole form lays out on a 240dp screen', (tester) async {
      await put(seed());
      await pump(tester, size: sonim);
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull,
          reason: 'the reorder row of three icon buttons is the tight spot here');
    });
  });
}
