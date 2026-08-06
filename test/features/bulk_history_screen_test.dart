import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/features/history/bulk_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// The durable undo list, built by a test for the first time.
///
/// A "finish all" on a category can write twelve thousand events, and a
/// snackbar that lives four seconds is not a real undo for that. This screen is
/// the one that has to still work next month — which makes it the one where
/// "the domain function is tested, so the screen is fine" is least true: what
/// the user is undoing here is described entirely by widget code
/// (`_where`, `_commonAncestor`) that `batch_history_test.dart` never runs.
void main() {
  const profile = 'default';

  LearningEvent event(
    String id, {
    required String node,
    required int unit,
    required String batch,
    EventAction action = EventAction.done,
  }) =>
      LearningEvent(
        id: id,
        profileId: profile,
        nodeId: node,
        unitIndex: unit,
        action: action,
        occurredAt: DateTime(2026, 1, 5, 14, 30),
        loggedAt: DateTime(2026, 1, 5, 14, 30),
        batchId: batch,
      );

  Widget screen(ProgressRepository repo) => ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
          appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
          clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
        ],
        child: localizedApp(home: const BulkHistoryScreen()),
      );

  testWidgets('says so when nothing has been done in bulk', (tester) async {
    await tester.pumpWidget(screen(memoryRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('No bulk actions yet'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('a finish batch says how many units and which sefer',
      (tester) async {
    final repo = memoryRepository();
    await repo.addEvents([
      event('a', node: 'shas.moed.shabbos', unit: 2, batch: 'b1'),
      event('b', node: 'shas.moed.shabbos', unit: 3, batch: 'b1'),
      event('c', node: 'shas.moed.shabbos', unit: 4, batch: 'b1'),
    ]);

    await tester.pumpWidget(screen(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Finished 3 units'), findsOneWidget);
    expect(find.textContaining('Shabbos'), findsOneWidget,
        reason: 'a single-node batch is named by that node, not by a count');
    // Time as well as date: two bulk actions on one day are otherwise two rows
    // the user cannot tell apart, and the whole screen is about picking one.
    expect(find.textContaining('14:30'), findsOneWidget);
  });

  testWidgets('a clear batch is distinguished from a finish', (tester) async {
    final repo = memoryRepository();
    await repo.addEvents([
      event('a',
          node: 'shas.moed.shabbos',
          unit: 2,
          batch: 'b1',
          action: EventAction.undone),
    ]);

    await tester.pumpWidget(screen(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cleared 1 unit'), findsOneWidget);
    expect(find.textContaining('Finished'), findsNothing);
  });

  testWidgets('undoing asks first, and removes exactly that batch',
      (tester) async {
    final repo = memoryRepository();
    await repo.addEvents([
      event('a', node: 'shas.moed.shabbos', unit: 2, batch: 'b1'),
      event('b', node: 'shas.moed.shabbos', unit: 3, batch: 'b1'),
      event('c', node: 'shas.moed.shabbos', unit: 4, batch: 'b2'),
    ]);

    await tester.pumpWidget(screen(repo));
    await tester.pumpAndSettle();

    // Two batches, two rows — the point of the screen is choosing between them.
    expect(find.text('Undo'), findsNWidgets(2));

    await tester.tap(find.text('Undo').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Undo this bulk action?'), findsOneWidget);

    // Cancelling really cancels. A confirm dialog whose Cancel writes anyway is
    // worse than no dialog.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(await repo.getEvents(profile), hasLength(3));

    await tester.tap(find.text('Undo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Undo'));
    await tester.pumpAndSettle();

    final left = await repo.getEvents(profile);
    expect(left.map((e) => e.id), ['c'],
        reason: 'the other batch is untouched — undoing one bulk action must '
            'not take a second one with it');
    expect(find.textContaining('2 events removed'), findsOneWidget);
  });

  testWidgets('a batch spanning several sefarim is named by what contains them',
      (tester) async {
    // `_commonAncestor` lives in the widget file and nothing else calls it.
    // A "finish all" is pressed on a *category*, so the row has to name the
    // category — the ids in the batch are its leaves.
    final repo = memoryRepository();
    await repo.addEvents([
      event('a', node: 'shas.moed.shabbos', unit: 2, batch: 'b1'),
      event('b', node: 'shas.moed', unit: 0, batch: 'b1'),
    ]);

    await tester.pumpWidget(screen(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Moed'), findsOneWidget);
    expect(find.textContaining('2 sefarim'), findsOneWidget);
  });
}
