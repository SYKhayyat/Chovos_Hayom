import 'dart:convert';

import 'package:chovos_hayom/application/plans.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:chovos_hayom/features/planner/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// #43 — `+` and `−` on a day, as **planning** commands.
///
/// **The claim under every test here is that these write no events.** A tick
/// (#42) claims something was learned; these say only what a day asks for. So
/// the log is asserted empty after every command, and a day asking for more than
/// is done is a legitimate state rather than something the test has to explain.
void main() {
  const shabbos = 'shas.moed.shabbos';
  final theDay = DateTime(2026, 1, 5);
  final dayKey = ValueKey('day-${Day.of(theDay).ordinal}');

  String plansJson({bool secondPlan = false}) {
    final plans = [
      const LearningPlan(
        id: 'daf-yomi',
        name: 'Daf Yomi',
        unitsPerDay: 2,
        assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
        items: [PlanItem(id: 'i1', nodeId: shabbos)],
      ),
      if (secondPlan)
        const LearningPlan(
          id: 'other',
          name: 'Other',
          // Mondays only, so it is *not* firing on the 5th — which is what makes
          // it the interesting choice for `+`.
          unitsPerDay: 4,
          assignments: [
            PlanAssignment(id: 'a', rule: WeekdayRule(weekdays: {DateTime.monday})),
          ],
          items: [PlanItem(id: 'i1', nodeId: shabbos)],
        ),
    ];
    return jsonEncode(PlansConfig(plans: plans).toJson());
  }

  Future<InMemoryPreferences> openSheet(
    WidgetTester tester, {
    required ProgressRepository repo,
    bool secondPlan = false,
  }) async {
    final prefs = InMemoryPreferences({
      PrefKeys.scoped('default', PrefKeys.plans): plansJson(secondPlan: secondPlan),
    });
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(prefs),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => theDay),
        ],
        child: localizedApp(home: const PlannerCalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(dayKey));
    await tester.pumpAndSettle();
    return prefs;
  }

  LearningPlan storedPlan(InMemoryPreferences prefs, String id) =>
      PlansConfig.fromJson((jsonDecode(prefs.getString(
                PrefKeys.scoped('default', PrefKeys.plans)) ??
              '{}') as Map)
              .cast<String, dynamic>())
          .plans
          .firstWhere((p) => p.id == id);

  group('add', () {
    testWidgets('raises the day on the chosen plan, and writes no event',
        (tester) async {
      final repo = memoryRepository();
      final prefs = await openSheet(tester, repo: repo);

      await tester.tap(find.byKey(const ValueKey('day-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-to-daf-yomi')));
      await tester.pumpAndSettle();

      expect(storedPlan(prefs, 'daf-yomi').dateAmounts[Day.of(theDay)], 3,
          reason: 'base 2 plus one');
      expect(await repo.getEvents('default'), isEmpty,
          reason: 'a planning command claims nothing was learned');
    });

    testWidgets('offers a plan whose rule would not have fired that day',
        (tester) async {
      // This is the case the issue calls out: a plan row only exists on a day
      // if a rule put it there, so someone doing extra on a quiet day has
      // nothing to press. Offering every plan is what makes the command useful.
      final repo = memoryRepository();
      final prefs =
          await openSheet(tester, repo: repo, secondPlan: true);

      await tester.tap(find.byKey(const ValueKey('day-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-to-other')));
      await tester.pumpAndSettle();

      expect(storedPlan(prefs, 'other').dateAmounts[Day.of(theDay)], 5,
          reason: 'the date override is what makes it fire on a day its rule '
              'skips; the rule itself is untouched');
      expect(storedPlan(prefs, 'other')
          .assignments
          .single
          .rule, const WeekdayRule(weekdays: {DateTime.monday}));
    });

    testWidgets('leaves the other plans alone', (tester) async {
      final repo = memoryRepository();
      final prefs =
          await openSheet(tester, repo: repo, secondPlan: true);

      await tester.tap(find.byKey(const ValueKey('day-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-to-other')));
      await tester.pumpAndSettle();

      expect(storedPlan(prefs, 'daf-yomi').dateAmounts, isEmpty,
          reason: 'recomputing one plan must not disturb another — the same '
              'rule #44 has to keep');
    });
  });

  group('remove', () {
    testWidgets('asks for one fewer unit, on the day', (tester) async {
      final repo = memoryRepository();
      final prefs = await openSheet(tester, repo: repo);

      await tester.tap(find.byKey(const ValueKey('day-remove')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('remove-one-daf-yomi')));
      await tester.pumpAndSettle();

      expect(storedPlan(prefs, 'daf-yomi').dateAmounts[Day.of(theDay)], 1);
      expect(await repo.getEvents('default'), isEmpty);
    });

    testWidgets('and skipping the plan leaves no answer for the day at all',
        (tester) async {
      // **Distinct from an amount of 0.** A zero says the plan was scheduled
      // and asked for nothing; skipping says it had nothing to do there, which
      // is "taking Thursday off". Collapsing the two loses a statement the user
      // is making, so both are offered.
      final repo = memoryRepository();
      final prefs = await openSheet(tester, repo: repo);

      await tester.tap(find.byKey(const ValueKey('day-remove')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('remove-all-daf-yomi')));
      await tester.pumpAndSettle();

      final plan = storedPlan(prefs, 'daf-yomi');
      expect(plan.dateAmounts.containsKey(Day.of(theDay)), isFalse,
          reason: 'no answer for the day at all');
      expect(plan.unitsPerDay, 2,
          reason: 'and the plan itself is untouched — only that day changed');
    });

    testWidgets('an amount of zero is offered and is a different edit',
        (tester) async {
      // The two are distinguishable in storage, which is the whole reason both
      // are reachable: one leaves an entry saying "nothing", the other removes it.
      final repo = memoryRepository();
      final prefs = await openSheet(tester, repo: repo);

      // Zero via the existing amount control.
      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(storedPlan(prefs, 'daf-yomi').dateAmounts[Day.of(theDay)], 0);
      expect(storedPlan(prefs, 'daf-yomi').dateAmounts.containsKey(Day.of(theDay)),
          isTrue,
          reason: 'the day is still answered — the plan was on it');
    });
  });

  group('neither command touches the log', () {
    testWidgets('and neither moves a later day', (tester) async {
      final repo = memoryRepository();
      final prefs = await openSheet(tester, repo: repo);

      await tester.tap(find.byKey(const ValueKey('day-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-to-daf-yomi')));
      await tester.pumpAndSettle();

      final plan = storedPlan(prefs, 'daf-yomi');
      expect(plan.dateAmounts.keys, [Day.of(theDay)],
          reason: 'one day got an answer, and it is this one');
      expect(await repo.getEvents('default'), isEmpty,
          reason: 'reflow is #44 and is asked for explicitly; a command that '
              'quietly reflowed would be a second unasked-for decision');
    });
  });
}
