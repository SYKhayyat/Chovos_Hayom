import 'package:chovos_hayom/app/routes.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/in_memory_progress_repository.dart';

/// What the route table buys, end to end: the app can be *told* where to open.
///
/// None of this was possible while every destination was a builder closure — a
/// deep link, a notification tap and a restored stack all arrive as a string.
void main() {
  Future<void> pumpApp(WidgetTester tester, {String? initialRoute}) async {
    // How the engine hands a launch URL to the framework: as the initial route
    // name, before the first frame.
    if (initialRoute != null) {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = initialRoute;
      addTearDown(
          tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider
              .overrideWithValue(InMemoryProgressRepository()),
        ],
        child: const ChovosHayomApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('launching with no route opens the dashboard', (tester) async {
    await pumpApp(tester);
    expect(find.text('Chovos Hayom'), findsOneWidget);
  });

  testWidgets('a link to a sefer opens it, with the dashboard behind it',
      (tester) async {
    await pumpApp(tester, initialRoute: Routes.sefer('shas.moed.shabbos'));
    expect(find.text('Shabbos'), findsOneWidget);

    // The whole point of back-filling the stack: Back goes home rather than out
    // of the app.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Chovos Hayom'), findsOneWidget);
  });

  testWidgets('the same link as a chovoshayom:// URI opens the same screen',
      (tester) async {
    // The shape Android actually delivers from the manifest's intent filter.
    await pumpApp(tester, initialRoute: 'chovoshayom://sefer/shas.moed.shabbos');
    expect(find.text('Shabbos'), findsOneWidget);
  });

  testWidgets('a link we do not serve lands on a page that says so',
      (tester) async {
    await pumpApp(tester, initialRoute: '/sefer-of-the-month');
    expect(find.text('Not found'), findsOneWidget);
    expect(find.textContaining('/sefer-of-the-month'), findsOneWidget);
  });

  testWidgets('navigating by name from the drawer still works', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siyumim'));
    await tester.pumpAndSettle();

    expect(find.text('Siyumim'), findsOneWidget);
    expect(ModalRoute.of(tester.element(find.text('Siyumim')))?.settings.name,
        Routes.siyumim);
  });

  testWidgets('every route the app is asked for by name resolves',
      (tester) async {
    // A cheap guard against a route constant losing its table entry: the
    // constants and the switch live in the same file, and nothing else would
    // notice them drifting apart until a user tapped the dead one.
    for (final route in [
      Routes.dashboard,
      Routes.stats,
      Routes.calculator,
      Routes.cycles,
      Routes.newCycle,
      Routes.goals,
      Routes.chazara,
      Routes.siyumim,
      Routes.journal,
      Routes.mefarshim,
      Routes.profiles,
      Routes.settings,
      Routes.bulkHistory,
      Routes.crashLog,
      Routes.addItem,
    ]) {
      expect(AppRouter.screenFor(route), isNotNull, reason: route);
    }
  });
}
