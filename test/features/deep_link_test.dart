import 'package:chovos_hayom/app/routes.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/memory_database.dart';

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
              .overrideWithValue(memoryRepository()),
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

  /// A link delivered to an app that is *already running*.
  ///
  /// Android sends the second one through `onNewIntent` (the activity is
  /// `singleTop`), which reaches the framework as a `pushRouteInformation` on
  /// the navigation channel rather than as an initial route name. Every test
  /// above drives the cold path only, and so did the hardware check that signed
  /// deep links off — which is how this survived: the *same link* opens the grid
  /// from cold and lands on "Not found" when the app is already open.
  Future<void> deliverWhileRunning(WidgetTester tester, String uri) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', <String, dynamic>{'location': uri}),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a link that arrives while the app is running opens the same '
      'screen as a cold one', (tester) async {
    await pumpApp(tester);
    expect(find.text('Chovos Hayom'), findsOneWidget);

    await deliverWhileRunning(tester, 'chovoshayom://sefer/shas.moed.shabbos');

    expect(find.text('Shabbos'), findsOneWidget,
        reason: 'the screen type lives in the URI authority, and the '
            'framework default rebuilds the route from path + query alone — so '
            'this arrived as "/shas.moed.shabbos" and missed the table');
  });

  testWidgets('a running app still says so for a link it does not serve',
      (tester) async {
    await pumpApp(tester);
    await deliverWhileRunning(tester, 'chovoshayom://nonsense/xyz');

    expect(find.text('Not found'), findsOneWidget);
    expect(find.textContaining('chovoshayom://nonsense/xyz'), findsOneWidget,
        reason: 'and it quotes back what it was actually asked for');
  });

  testWidgets('a bare path delivered while running still works', (tester) async {
    // The in-app shape, and what the platform sends for a link with no
    // authority. Both have to keep working through the same handler.
    await pumpApp(tester);
    await deliverWhileRunning(tester, Routes.sefer('shas.moed.shabbos'));

    expect(find.text('Shabbos'), findsOneWidget);
  });

  testWidgets('a link we do not serve lands on a page that says so',
      (tester) async {
    await pumpApp(tester, initialRoute: '/sefer-of-the-month');
    expect(find.text('Not found'), findsOneWidget);
    expect(find.textContaining('/sefer-of-the-month'), findsOneWidget);
  });

  testWidgets('navigating by name from the drawer still works', (tester) async {
    // The drawer lost five rows to the report and gained one, so the row this
    // walks is "Reports" and the destination is /stats. Siyumim is still a
    // route — the test below proves it resolves — it is just no longer a door
    // of its own on a drawer that was twelve rows long on a 324dp screen.
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();

    expect(find.text('Siyumim'), findsOneWidget, reason: 'as a tab');
    expect(ModalRoute.of(tester.element(find.text('Siyumim')))?.settings.name,
        Routes.stats);
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
