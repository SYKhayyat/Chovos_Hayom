import 'package:chovos_hayom/app/routes.dart';
import 'package:chovos_hayom/features/custom_node/add_custom_node_screen.dart';
import 'package:chovos_hayom/features/cycles/edit_cycle_screen.dart';
import 'package:chovos_hayom/features/dashboard/dashboard_screen.dart';
import 'package:chovos_hayom/features/node/node_screen.dart';
import 'package:chovos_hayom/features/settings/crash_log_screen.dart';
import 'package:chovos_hayom/features/unit_grid/unit_grid_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Routes', () {
    test('a route name carries the id, and survives the round trip', () {
      // Built-in ids are dotted slugs, custom ones are UUIDs — but the encoding
      // must hold for anything, because a node id is not ours to assume.
      for (final id in [
        'shas.moed.shabbos',
        '6f1c2e9a-0b7d-4a51-9d3e-2f4c5b6a7d8e',
        'a b/c?d#e',
      ]) {
        final screen = AppRouter.screenFor(Routes.sefer(id));
        expect(screen, isA<UnitGridScreen>());
        expect((screen! as UnitGridScreen).nodeId, id);
      }
    });

    test('a category route resolves to the subtree screen', () {
      final screen = AppRouter.screenFor(Routes.category('shas'));
      expect((screen! as NodeScreen).nodeId, 'shas');
    });

    test('add-item carries an optional parent; edit-item carries the node', () {
      expect((AppRouter.screenFor(Routes.addItem)! as AddCustomNodeScreen).parentId,
          isNull);
      expect(
        (AppRouter.screenFor(Routes.addItemUnder('shas.moed'))!
                as AddCustomNodeScreen)
            .parentId,
        'shas.moed',
      );
      final edit =
          AppRouter.screenFor(Routes.editItem('shas.moed'))! as AddCustomNodeScreen;
      expect(edit.nodeId, 'shas.moed');
      expect(edit.parentId, isNull);
    });

    test('a new cycle and an existing one are different routes', () {
      expect((AppRouter.screenFor(Routes.newCycle)! as EditCycleScreen).cycleId,
          isNull);
      expect((AppRouter.screenFor(Routes.editCycle('abc'))! as EditCycleScreen)
          .cycleId, 'abc');
      // The id "new" must not be swallowed by the create route.
      expect((AppRouter.screenFor(Routes.editCycle('new'))! as EditCycleScreen)
          .cycleId, 'new');
    });

    test('the fixed screens all resolve', () {
      expect(AppRouter.screenFor(Routes.dashboard), isA<DashboardScreen>());
      expect(AppRouter.screenFor(Routes.crashLog), isA<CrashLogScreen>());
      for (final route in [
        Routes.stats,
        Routes.calculator,
        Routes.cycles,
        Routes.goals,
        Routes.chazara,
        Routes.siyumim,
        Routes.journal,
        Routes.mefarshim,
        Routes.profiles,
        Routes.settings,
        Routes.bulkHistory,
      ]) {
        expect(AppRouter.screenFor(route), isNotNull, reason: route);
      }
    });

    test('a name we do not serve resolves to nothing, not to a blank screen',
        () {
      expect(AppRouter.screenFor('/nope'), isNull);
      expect(AppRouter.screenFor('/sefer'), isNull);
      expect(AppRouter.onGenerateRoute(const RouteSettings(name: '/nope')),
          isNull);
      expect(AppRouter.onUnknownRoute(const RouteSettings(name: '/nope')),
          isA<Route<void>>());
    });

    test('a generated route keeps its name, so it can be restored', () {
      final route =
          AppRouter.onGenerateRoute(RouteSettings(name: Routes.sefer('x')))!;
      expect(route.settings.name, Routes.sefer('x'));
      expect(route.settings.arguments, isNull,
          reason: 'everything a screen needs must live in the name');
    });

    test('a deep link opens with the dashboard underneath it', () {
      final direct = AppRouter.onGenerateInitialRoutes(Routes.dashboard);
      expect(direct, hasLength(1));

      final deep = AppRouter.onGenerateInitialRoutes(Routes.sefer('shas'));
      expect(deep, hasLength(2));
      expect(deep.first.settings.name, Routes.dashboard);
      expect(deep.last.settings.name, Routes.sefer('shas'));
    });

    test('a deep-link URI resolves to the same screen as the in-app path', () {
      // `chovoshayom://sefer/<id>` puts "sefer" in the URI's authority, not its
      // path — one table has to serve both shapes.
      final deep = AppRouter.screenFor('chovoshayom://sefer/shas.moed.shabbos');
      expect((deep! as UnitGridScreen).nodeId, 'shas.moed.shabbos');

      expect(AppRouter.screenFor('chovoshayom://settings/crash-log'),
          isA<CrashLogScreen>());
      expect(
        (AppRouter.screenFor('chovoshayom://add-item?parent=shas')!
                as AddCustomNodeScreen)
            .parentId,
        'shas',
      );
      expect(AppRouter.screenFor('chovoshayom://'), isA<DashboardScreen>());
      expect(AppRouter.screenFor('chovoshayom://nope'), isNull);
    });

    test('a deep link to a name we do not serve still lands somewhere', () {
      final routes = AppRouter.onGenerateInitialRoutes('/gone');
      expect(routes, hasLength(2));
      expect(routes.first.settings.name, Routes.dashboard);
    });
  });
}
