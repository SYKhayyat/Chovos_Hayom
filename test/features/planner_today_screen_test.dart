import 'dart:convert';

import 'package:chovos_hayom/application/plans.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:chovos_hayom/features/planner/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

void main() {
  const profile = 'default';

  LearningPlan plan() => const LearningPlan(
        id: 'p1',
        name: 'Daily plan',
        assignments: [
          PlanAssignment(
            id: 'a1',
            rule: DailyRule(),
            targetNodeId: 'shas.moed.shabbos',
            label: 'Text',
          ),
        ],
      );

  Widget screen({
    required ProgressRepository repo,
    Locale locale = const Locale('en'),
  }) {
    final prefs = InMemoryPreferences({
      PrefKeys.scoped(profile, PrefKeys.plans): jsonEncode(
        PlansConfig(plans: [plan()]).toJson(),
      ),
    });
    return ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(prefs),
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => DateTime(2026, 1, 10, 14)),
      ],
      child: localizedApp(home: const PlannerTodayScreen(), locale: locale),
    );
  }

  testWidgets('lists a daily assignment and logs its next unit', (tester) async {
    final repo = memoryRepository();
    await tester.pumpWidget(screen(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text("Today's goals"), findsOneWidget);
    expect(find.text('Daily plan'), findsOneWidget);
    expect(find.textContaining('Log 2'), findsOneWidget);

    await tester.tap(find.text('Mark'));
    await tester.pumpAndSettle();

    final events = await repo.getEvents(profile);
    expect(events, hasLength(1));
    expect(events.single.nodeId, 'shas.moed.shabbos');
    expect(events.single.unitIndex, 2);
  });

  testWidgets('the empty state is localized', (tester) async {
    final repo = memoryRepository();
    final prefs = InMemoryPreferences();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(prefs),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
        ],
        child: localizedApp(
          home: const PlannerTodayScreen(),
          locale: const Locale('he'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('יעדים להיום'), findsOneWidget);
    expect(find.text('אין דבר מתוכנן להיום.'), findsOneWidget);
  });
}
