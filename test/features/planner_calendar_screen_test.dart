import 'dart:convert';

import 'package:chovos_hayom/application/plans.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
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
          // would be "never"). At 30/day the 156 daf under every node project to
          // ceil(156/30) = 6 days out — 6 Jan, inside both the month grid and the
          // week view (which is anchored to the 1st).
          paceProvider.overrideWithValue(30),
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
}
