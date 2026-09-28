import 'dart:convert';

import 'package:chovos_hayom/application/plans.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:chovos_hayom/features/planner/edit_plan_screen.dart';
import 'package:chovos_hayom/features/planner/plans_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// A plan is an entity you can change. Until this screen existed the only way to
/// make one was to hand-write JSON into preferences, so these cover the whole
/// round trip a user actually performs: create, list, open, edit, delete.
void main() {
  const sonim = Size(240, 324);

  late InMemoryPreferences prefs;

  setUp(() => prefs = InMemoryPreferences());

  /// Read the stored plans back the way a restart would.
  PlansConfig config() {
    final raw =
        prefs.getString(PrefKeys.scoped('default', PrefKeys.plans)) ?? '{}';
    return PlansConfig.fromJson(
        (jsonDecode(raw) as Map<String, dynamic>));
  }

  Future<void> pump(WidgetTester tester, Widget home, {Size? size}) async {
    if (size != null) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
    } else {
      // Tall enough that the whole editor form is laid out, so a test can tap a
      // control without scrolling to it. The D-pad test below is the one that
      // deliberately does not get this.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 2600);
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(prefs),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(memoryRepository()),
          clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
        ],
        child: localizedApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls [finder] into view and taps it.
  ///
  /// The editor is one long form, so on a 600px test surface the save button and
  /// everything below it are simply not built. Every tap on a lower control needs
  /// this; a bare `tap` fails with a finder error that looks like a missing
  /// widget rather than a widget below the fold.
  Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enterText(WidgetTester tester, int index, String text) async {
    final field = find.byType(TextField).at(index);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  group('the list screen', () {
    testWidgets('says so when there are no plans', (tester) async {
      await pump(tester, const PlansScreen());
      expect(find.text('No plans yet. Add one to start scheduling.'),
          findsOneWidget);
      expect(find.text('Add plan'), findsOneWidget);
    });

    testWidgets('lists a plan and says what it is', (tester) async {
      await prefs.setString(
        PrefKeys.scoped('default', PrefKeys.plans),
        jsonEncode(const PlansConfig(plans: [
          LearningPlan(
            id: 'p',
            name: 'Daf Yomi',
            unitsPerDay: 7,
            assignments: [
              PlanAssignment(id: 'a', rule: DailyRule()),
            ],
          ),
        ]).toJson()),
      );
      await pump(tester, const PlansScreen());

      expect(find.text('Daf Yomi'), findsOneWidget);
      // The summary says how much and how often, so the list is readable
      // without opening every plan.
      expect(find.textContaining('Units per day: 7'), findsOneWidget);
      expect(find.textContaining('Every day'), findsOneWidget);
    });
  });

  group('creating', () {
    testWidgets('a new plan gets a rule, an amount and appears in the list',
        (tester) async {
      await pump(tester, const EditPlanScreen());

      expect(find.text('New plan'), findsOneWidget);
      await enterText(tester, 0, 'Chulljuna');
      await enterText(tester, 1, '1');
      await scrollAndTap(tester, find.text('Create'));
      await tester.pumpAndSettle();

      // Saved with a *rule*, not just a name: a plan with no assignment never
      // fires, so a plan you can create but that never happens is the failure
      // this screen exists to prevent.
      final saved = config().plans;
      expect(saved, hasLength(1));
      expect(saved.first.name, 'Chulljuna');
      expect(saved.first.unitsPerDay, 1);
      expect(saved.first.assignments, hasLength(1));
      expect(saved.first.assignments.first.rule, isA<DailyRule>());
    });

    testWidgets('the spillover mode is saved, not just displayed',
        (tester) async {
      await pump(tester, const EditPlanScreen());
      await scrollAndTap(tester, find.text('Slide the whole schedule'));
      await scrollAndTap(tester, find.text('Create'));
      await tester.pumpAndSettle();

      expect(config().plans.single.spillover, SpilloverMode.slide);
    });

    testWidgets('the flow toggle is saved', (tester) async {
      await pump(tester, const EditPlanScreen());
      await scrollAndTap(tester, find.byType(SwitchListTile));
      await scrollAndTap(tester, find.text('Create'));
      await tester.pumpAndSettle();

      expect(config().plans.single.flowsToNextItem, isTrue);
    });

    testWidgets('a weekday rule saves the chosen weekdays', (tester) async {
      await pump(tester, const EditPlanScreen());
      await scrollAndTap(tester, find.text('Certain weekdays'));

      // Default starts on Monday; add Thursday so the set is a genuine subset.
      await scrollAndTap(tester, find.widgetWithText(OutlinedButton, '4'));
      await scrollAndTap(tester, find.text('Create'));
      await tester.pumpAndSettle();

      final rule = config().plans.single.assignments.single.rule;
      expect(rule, isA<WeekdayRule>());
      expect((rule as WeekdayRule).weekdays, {DateTime.monday, DateTime.thursday});
    });

    testWidgets('a Hebrew day rule saves the day and month', (tester) async {
      await pump(tester, const EditPlanScreen());
      await scrollAndTap(tester, find.text('A Hebrew day of the month'));
      await scrollAndTap(tester, find.text('Create'));
      await tester.pumpAndSettle();

      final rule = config().plans.single.assignments.single.rule;
      expect(rule, isA<HebrewDayRule>());
      expect((rule as HebrewDayRule).day, 1);
      expect(rule.month, isNull, reason: 'every Hebrew month by default');
    });
  });

  group('validation is visible, not thrown', () {
    testWidgets('a negative amount is refused with a message', (tester) async {
      await pump(tester, const EditPlanScreen());
      await enterText(tester, 1, '-3');
      await scrollAndTap(tester, find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a whole number, zero or more.'), findsOneWidget);
      expect(config().plans, isEmpty, reason: 'nothing was saved');
    });

    testWidgets('text that is not a number is refused with a message',
        (tester) async {
      await pump(tester, const EditPlanScreen());
      await enterText(tester, 1, 'ten');
      await scrollAndTap(tester, find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a whole number, zero or more.'), findsOneWidget);
      expect(config().plans, isEmpty);
    });

    testWidgets('a rule with nothing selected is refused', (tester) async {
      // "Certain weekdays" with every day deselected would save a plan that
      // never fires — the same failure as having no rule at all.
      await pump(tester, const EditPlanScreen());
      await scrollAndTap(tester, find.text('Certain weekdays'));
      await scrollAndTap(tester, find.widgetWithText(OutlinedButton, '1')); // clear Monday
      await scrollAndTap(tester, find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a whole number, zero or more.'), findsOneWidget);
      expect(config().plans, isEmpty);
    });
  });

  group('editing', () {
    Future<void> seed(LearningPlan plan) => prefs.setString(
        PrefKeys.scoped('default', PrefKeys.plans),
        jsonEncode(PlansConfig(plans: [plan]).toJson()));

    testWidgets('an existing plan opens with its values', (tester) async {
      await seed(const LearningPlan(
        id: 'p',
        name: 'Yoma',
        unitsPerDay: 7,
        spillover: SpilloverMode.catchUp,
        assignments: [PlanAssignment(id: 'a', rule: DailyRule(), unitsPerFiring: 3)],
      ));
      await pump(tester, const EditPlanScreen(planId: 'p'));

      expect(find.text('Edit plan'), findsOneWidget);
      // Not the field's own hint, which is also "Daf Yomi" - hence "Yoma".
      expect(find.text('Yoma'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('3'), findsOneWidget, reason: 'unitsPerFiring');
    });

    testWidgets('editing changes the amount and keeps the id', (tester) async {
      await seed(const LearningPlan(
        id: 'p',
        name: 'Yoma',
        unitsPerDay: 7,
        assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
      ));
      await pump(tester, const EditPlanScreen(planId: 'p'));

      await enterText(tester, 1, '9');
      await scrollAndTap(tester, find.text('Save'));
      await tester.pumpAndSettle();

      final saved = config().plans.single;
      expect(saved.id, 'p', reason: 'editing must not mint a new plan');
      expect(saved.unitsPerDay, 9);
    });

    testWidgets('a save does not silently drop what this screen cannot edit',
        (tester) async {
      // The weekday overrides, date overrides and item sequence are #35's job.
      // They are not on this form, so a save here must carry them across rather
      // than rebuild the plan from the visible fields.
      await seed(const LearningPlan(
        id: 'p',
        name: 'Daf Yomi',
        unitsPerDay: 7,
        weekdayAmounts: {DateTime.friday: 3},
        dateAmounts: {},
        items: [PlanItem(id: 'i1', nodeId: 'shas.moed.shabbos')],
        flowsToNextItem: true,
        assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
      ));
      await pump(tester, const EditPlanScreen(planId: 'p'));
      await enterText(tester, 1, '8');
      await scrollAndTap(tester, find.text('Save'));
      await tester.pumpAndSettle();

      final saved = config().plans.single;
      expect(saved.weekdayAmounts, {DateTime.friday: 3});
      expect(saved.items, hasLength(1));
      expect(saved.flowsToNextItem, isTrue);
    });
  });

  group('deleting', () {
    testWidgets('asks first, and deleting removes the plan', (tester) async {
      await prefs.setString(
        PrefKeys.scoped('default', PrefKeys.plans),
        jsonEncode(const PlansConfig(plans: [
          LearningPlan(id: 'p', name: 'Daf Yomi'),
        ]).toJson()),
      );
      await pump(tester, const EditPlanScreen(planId: 'p'));

      await scrollAndTap(tester, find.byTooltip('Delete plan'));
      expect(find.text('Delete "Daf Yomi"?'), findsOneWidget);

      await scrollAndTap(tester, find.text('Cancel'));
      expect(config().plans, hasLength(1), reason: 'cancelling keeps the plan');

      await scrollAndTap(tester, find.byTooltip('Delete plan'));
      await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(config().plans, isEmpty);
    });
  });

  group('the D-pad device', () {
    testWidgets('the editor lays out and is reachable on a 240dp screen',
        (tester) async {
      await pump(tester, const EditPlanScreen(), size: sonim);

      // The form is a scrollable ListView with focusable controls, so it both
      // fits and can be walked.
      // Scroll the whole form: every control must lay out, and none may
      // overflow a 240dp screen.
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();
      }
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the list screen lays out on a 240dp screen', (tester) async {
      await pump(tester, const PlansScreen(), size: sonim);
      expect(tester.takeException(), isNull);
    });
  });

  group('round trip', () {
    testWidgets('a plan survives save, reload and backup export',
        (tester) async {
      await pump(tester, const EditPlanScreen());
      await enterText(tester, 0, 'Chulljuna');
      await enterText(tester, 1, '1');
      await scrollAndTap(tester, find.text('Add it to the next day'));
      await scrollAndTap(tester, find.text('Create'));
      await tester.pumpAndSettle();

      // Read it back through a fresh container, the way a restart would.
      final reloaded = await tester.runAsync(() async {
        final container = ProviderContainer(
          overrides: [appPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);
        return PlansConfig.fromJson(
          (jsonDecode(prefs.getString(
                      PrefKeys.scoped('default', PrefKeys.plans)) ??
                  '{}') as Map)
              .cast<String, dynamic>(),
        );
      });

      expect(reloaded!.plans.single.name, 'Chulljuna');
      expect(reloaded.plans.single.unitsPerDay, 1);
      expect(reloaded.plans.single.spillover, SpilloverMode.catchUp);
      expect(reloaded.plans.single.assignments.single.unitsPerFiring, 1);
    });
  });
}
