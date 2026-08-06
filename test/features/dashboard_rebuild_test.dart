import 'package:chovos_hayom/app/routes.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/features/dashboard/dashboard_screen.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/memory_database.dart';
import '../support/localized_app.dart';

/// Changing the sort must not provoke a build-phase `setState`.
///
/// A `setState() or markNeedsBuild() called during build` was sitting in the
/// crash log from a hand-run of the app, thrown from Riverpod's provider scope
/// while an overlay was being built. The dashboard was subscribing to
/// `nodeLastActivityProvider` *conditionally* — `sort.active ? ref.watch(…) : {}`
/// — so the set of providers it listened to changed shape mid-frame, exactly
/// when the sort sheet's overlay was animating over it.
///
/// This drives that path: open the sort sheet, change the metric (which flips
/// `sort.active`), and fail on any framework error.
void main() {
  final errors = <FlutterErrorDetails>[];
  late FlutterExceptionHandler? previous;

  setUp(() {
    errors.clear();
    previous = FlutterError.onError;
    FlutterError.onError = errors.add;
  });
  tearDown(() => FlutterError.onError = previous);

  LearningEvent done(int unit) => LearningEvent(
        id: 'e$unit',
        profileId: 'default',
        nodeId: 'shas.moed.shabbos',
        unitIndex: unit,
        action: EventAction.done,
        occurredAt: DateTime(2026, 1, 1),
        loggedAt: DateTime(2026, 1, 1),
      );

  testWidgets('changing the sort from its sheet raises no framework error',
      (tester) async {
    final repo = memoryRepository();
    await repo.addEvent(done(2));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(repo),
        appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
        clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
      ],
      child: localizedApp(home: const DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    // Open the sort sheet — this is the overlay in the recorded stack.
    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();

    // Flip the sort on. Before the fix this changed the dashboard's *set* of
    // watched providers while the sheet was mounted over it.
    await tester.tap(find.text('Last learned'));
    await tester.pumpAndSettle();

    // ...and off again, removing the subscription the same way.
    await tester.tap(find.text('Catalog order'));
    await tester.pumpAndSettle();

    expect(
      errors.map((e) => e.exceptionAsString()).toList(),
      isEmpty,
      reason: 'changing the sort must not schedule a build during a build',
    );
  });

  testWidgets('opening the drawer over the tree raises no framework error',
      (tester) async {
    // The other overlay on this screen, and the other thing that flips
    // TickerMode on a ConsumerStatefulWidget.
    final repo = memoryRepository();
    await repo.addEvent(done(2));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(repo),
        appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
        clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
      ],
      child: localizedApp(home: const DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    final state = tester.state<ScaffoldState>(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle();
    // Mutate the log while the drawer overlay is up: the chazara badge in it
    // watches derived state, so this is a provider change under an overlay.
    await repo.addEvent(done(3));
    await tester.pumpAndSettle();

    expect(errors.map((e) => e.exceptionAsString()).toList(), isEmpty);
  });

  testWidgets('providers changing mid route-transition raise no framework error',
      (tester) async {
    // The closest reconstruction of the recorded stack: `TickerMode` flips when
    // a route animates over another, which is what made Riverpod resume and
    // flush the dashboard's subscriptions mid-frame. So mutate *during* the
    // transition rather than after it settles.
    final repo = memoryRepository();
    await repo.addEvent(done(2));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(repo),
        appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
        clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
      ],
      child: localizedApp(
        home: const DashboardScreen(),
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    ));
    await tester.pumpAndSettle();

    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    for (var i = 0; i < 4; i++) {
      // Deliberately not awaited: the point is to act *during* the push.
      unawaited(navigator.pushNamed(Routes.stats));
      // Part-way into the push, while TickerMode is changing under the tree.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await repo.addEvent(done(10 + i));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await repo.addEvent(done(20 + i));
      await tester.pumpAndSettle();
    }

    expect(errors.map((e) => e.exceptionAsString()).toList(), isEmpty);
  });
}
