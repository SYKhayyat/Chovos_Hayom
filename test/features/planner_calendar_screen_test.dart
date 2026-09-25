import 'dart:convert';

import 'package:chovos_hayom/application/plans.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:chovos_hayom/features/planner/calendar_screen.dart';
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
}
