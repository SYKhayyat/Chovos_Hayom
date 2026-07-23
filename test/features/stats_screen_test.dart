import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/features/stats/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/in_memory_progress_repository.dart';

LearningEvent done(int unit, DateTime day) => LearningEvent(
      id: 'e$unit-${day.toIso8601String()}',
      profileId: 'default',
      nodeId: 'shas.moed.shabbos',
      unitIndex: unit,
      action: EventAction.done,
      occurredAt: day,
      loggedAt: day,
    );

void main() {
  testWidgets('stats screen shows a 2-day streak and progress chart',
      (tester) async {
    final clock = DateTime(2026, 1, 10, 12);
    final repo = InMemoryProgressRepository();
    await repo.addEvent(done(2, DateTime(2026, 1, 10)));
    await repo.addEvent(done(3, DateTime(2026, 1, 9)));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => clock),
        ],
        child: const MaterialApp(home: StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Streak'), findsOneWidget);
    expect(find.text('2 days'), findsOneWidget);

    // The chart sits below the (lazily-built) summary grid; scroll to it.
    await tester.scrollUntilVisible(
      find.text('Progress over time'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Progress over time'), findsOneWidget);
  });
}
