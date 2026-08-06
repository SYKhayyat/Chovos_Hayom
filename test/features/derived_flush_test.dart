import 'package:chovos_hayom/application/goals.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/memory_database.dart';

/// **Marking a daf must not blow up the screen you come back to.**
///
/// A `Consumer` that stays mounted under a pushed route or an open sheet has its
/// provider subscriptions paused by `TickerMode` and resumed when the overlay
/// goes away. Resuming one flushes it — and flushing it flushes its ancestors,
/// so if a *derived* ancestor went dirty while the subscription was asleep, that
/// ancestor rebuilds and notifies mid-build, and the descendant's
/// re-invalidation is a `setState` inside the build phase. Flutter asserts on
/// that; the screen comes back with a red box instead of a daf.
///
/// It is not hypothetical and it is not subtle once you have seen it: adding one
/// derived provider between the dashboard's nudge banner and the event log was
/// enough to make *drill in, mark a daf, come back* throw, every time.
///
/// The two paths below are the two places a mark is made from — the grid, with a
/// goal banner on it whose status is three providers away from the log, and the
/// dashboard behind it. Both pump a real app over a real database, because the
/// pause/resume this is about only exists when there is a route transition.
void main() {
  Future<void> pumpApp(WidgetTester tester) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(memoryRepository()),
        ],
        child: const ChovosHayomApp(),
      ),
    );
  }

  /// Drills to the Shabbos grid. Expansion survives a pop, so each step is
  /// skipped when its children are already on screen — tapping an open category
  /// would close it.
  Future<void> openShabbosGrid(WidgetTester tester) async {
    for (final step in ['Shas', 'Moed', 'Shabbos']) {
      if (step != 'Shabbos' && find.text('Shabbos').evaluate().isNotEmpty) {
        continue;
      }
      await tester.tap(find.text(step));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('a mark with a goal set survives the trip back to the dashboard',
      (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    // A goal makes `goalStatusProvider` live on the grid *and* the goal row —
    // and its chain to the log is the longest in the app: goal status, pace,
    // the day index, the log. Without one, the whole chain is never built and
    // the scenario proves nothing.
    final scope = tester.element(find.byType(ChovosHayomApp));
    await ProviderScope.containerOf(scope, listen: false)
        .read(goalsProvider.notifier)
        .setGoal('shas.moed.shabbos', DateTime(2027, 1, 1));
    await tester.pumpAndSettle();

    await openShabbosGrid(tester);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 'the grid re-derives its goal banner while the mark lands');

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'the dashboard resumes every subscription it had paused, and '
            'one of them is a nudge banner three providers from the log');
    expect(find.textContaining('1 / 156'), findsWidgets);
  });

  testWidgets('a second mark, with the dashboard already warm, is also clean',
      (tester) async {
    // The first trip warms every provider; the second is the one where a
    // *dirty* ancestor meets a *resuming* subscription, which is the actual
    // failing combination rather than a cold-start artefact.
    await pumpApp(tester);
    await tester.pumpAndSettle();

    for (final daf in ['2', '3']) {
      await openShabbosGrid(tester);
      await tester.tap(find.text(daf));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'marking daf $daf');
    }

    expect(find.textContaining('2 / 156'), findsWidgets);
  });
}
