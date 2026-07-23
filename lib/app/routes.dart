import 'package:flutter/material.dart';

import '../features/calculator/calculator_screen.dart';
import '../features/chazara/chazara_screen.dart';
import '../features/custom_node/add_custom_node_screen.dart';
import '../features/cycles/cycles_screen.dart';
import '../features/cycles/edit_cycle_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/goals/goals_screen.dart';
import '../features/history/bulk_history_screen.dart';
import '../features/journal/notes_journal_screen.dart';
import '../features/mefarshim/mefarshim_progress_screen.dart';
import '../features/node/node_screen.dart';
import '../features/profiles/profiles_screen.dart';
import '../features/settings/crash_log_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/siyum/siyum_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/unit_grid/unit_grid_screen.dart';

/// Every screen the app can reach, named.
///
/// Screens used to be pushed as `MaterialPageRoute(builder: (_) => Screen(…))`
/// closures. A closure cannot be named, which means nothing outside the widget
/// tree can ask for a screen — a deep link, a notification tap, and the OS's
/// state restoration all hand you a *string*, not a builder. Naming them is the
/// difference between "we could support that" and "we cannot".
///
/// Two rules make the names sufficient on their own:
///
/// - **A route carries ids, never objects.** `/sefer/shas.moed.shabbos`, not a
///   `CatalogNode`. A serialisable name is what makes restoration possible at
///   all, and it removes a staleness bug on the way: a screen handed a *node*
///   kept rendering the node as it was when it was pushed, so renaming a sefer
///   while its grid was open left the old title on screen. Screens resolve their
///   id against the live catalog, so they follow every edit.
/// - **Everything a screen needs is in the path.** No `arguments`, so no route
///   is un-restorable because of what was passed to it.
abstract final class Routes {
  static const dashboard = '/';
  static const stats = '/stats';
  static const calculator = '/calculator';
  static const cycles = '/cycles';
  static const newCycle = '/cycles/new';
  static const goals = '/goals';
  static const chazara = '/chazara';
  static const siyumim = '/siyumim';
  static const journal = '/journal';
  static const mefarshim = '/mefarshim';
  static const profiles = '/profiles';
  static const settings = '/settings';
  static const bulkHistory = '/settings/history';
  static const crashLog = '/settings/crash-log';
  static const addItem = '/add-item';

  /// A leaf's per-unit grid.
  static String sefer(String nodeId) => '/sefer/${_seg(nodeId)}';

  /// The progress subtree rooted at a category.
  static String category(String nodeId) => '/category/${_seg(nodeId)}';

  /// The add/edit form for a node, either creating one under [parentId] or
  /// editing [nodeId]. Custom node ids are UUIDs and built-in ids are slugs, but
  /// both go through the same encoding — a user-facing id is not ours to assume.
  static String editItem(String nodeId) => '/edit-item/${_seg(nodeId)}';

  static String addItemUnder(String? parentId) => parentId == null
      ? addItem
      : '$addItem?parent=${Uri.encodeQueryComponent(parentId)}';

  /// `/cycles/edit/<id>` rather than `/cycles/<id>`: the latter would collide
  /// with [newCycle] for a cycle whose id happened to be "new". Ids are UUIDs
  /// today, but a route table that is only correct because of what ids look like
  /// is a trap set for whoever changes them.
  static String editCycle(String cycleId) => '/cycles/edit/${_seg(cycleId)}';

  static String _seg(String value) => Uri.encodeComponent(value);
}

/// Turns a route name into a screen, and back-fills the stack a deep link skips.
abstract final class AppRouter {
  /// The whole table. Returns null for a name it does not recognise, which is
  /// what makes [onUnknownRoute] fire rather than the app showing a blank page.
  static Widget? screenFor(String? name) {
    final uri = Uri.parse(name ?? Routes.dashboard);
    // `pathSegments` percent-decodes, so an id survives the round trip.
    final path = uri.pathSegments;
    return switch (path) {
      [] => const DashboardScreen(),
      ['stats'] => const StatsScreen(),
      ['calculator'] => const CalculatorScreen(),
      ['cycles'] => const CyclesScreen(),
      ['cycles', 'new'] => const EditCycleScreen(),
      ['cycles', 'edit', final id] => EditCycleScreen(cycleId: id),
      ['goals'] => const GoalsScreen(),
      ['chazara'] => const ChazaraScreen(),
      ['siyumim'] => const SiyumScreen(),
      ['journal'] => const NotesJournalScreen(),
      ['mefarshim'] => const MefarshimProgressScreen(),
      ['profiles'] => const ProfilesScreen(),
      ['settings'] => const SettingsScreen(),
      ['settings', 'history'] => const BulkHistoryScreen(),
      ['settings', 'crash-log'] => const CrashLogScreen(),
      ['add-item'] => AddCustomNodeScreen(parentId: uri.queryParameters['parent']),
      ['edit-item', final id] => AddCustomNodeScreen(nodeId: id),
      ['sefer', final id] => UnitGridScreen(nodeId: id),
      ['category', final id] => NodeScreen(nodeId: id),
      _ => null,
    };
  }

  static Route<void>? onGenerateRoute(RouteSettings settings) {
    final screen = screenFor(settings.name);
    if (screen == null) return null;
    return MaterialPageRoute<void>(builder: (_) => screen, settings: settings);
  }

  /// A name we don't serve — a link from an older version, a typo in a shortcut,
  /// a URL someone shared. Saying so beats a white screen, and it keeps the back
  /// button working because it is still a real route.
  static Route<void> onUnknownRoute(RouteSettings settings) =>
      MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => _UnknownRouteScreen(name: settings.name),
      );

  /// The stack a cold start builds.
  ///
  /// Launching straight into `/sefer/…` from a link would otherwise leave the
  /// user on a screen with nothing behind it, so Back exits the app instead of
  /// going to the dashboard. The dashboard always sits underneath.
  static List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) {
    final home = onGenerateRoute(const RouteSettings(name: Routes.dashboard))!;
    if (initialRoute == Routes.dashboard) return [home];
    return [
      home,
      onGenerateRoute(RouteSettings(name: initialRoute)) ??
          onUnknownRoute(RouteSettings(name: initialRoute)),
    ];
  }
}

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'There is nothing here.\n\n'
            '“${name ?? ''}” is not a screen this version of the app has.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
