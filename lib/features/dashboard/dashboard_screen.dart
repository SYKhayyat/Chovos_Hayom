import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../calculator/calculator_screen.dart';
import '../custom_node/add_custom_node_screen.dart';
import '../profiles/profiles_screen.dart';
import '../search/catalog_search_delegate.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import 'progress_tile.dart';

/// The main dashboard: an expandable tree of the whole catalog with per-node
/// progress bars. Tapping a leaf opens its per-unit grid.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forest = ref.watch(progressForestProvider);
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;

    return Scaffold(
      drawer: const _AppDrawer(),
      appBar: AppBar(
        title: const Text('Chovos Hayom'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: catalog == null
                ? null
                : () => showSearch(
                      context: context,
                      delegate: CatalogSearchDelegate(catalog.all.toList()),
                    ),
          ),
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: 'Statistics',
            onPressed: () => _push(context, const StatsScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.calculate),
            tooltip: 'Siyum calculator',
            onPressed: () => _push(context, const CalculatorScreen()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add custom sefer',
        onPressed: () => _push(context, const AddCustomNodeScreen()),
        child: const Icon(Icons.add),
      ),
      body: forest.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (nodes) => ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [for (final n in nodes) ProgressTile(node: n)],
        ),
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider).asData?.value ?? const [];
    final active = ref.watch(activeProfileProvider);
    final activeName =
        profiles.where((p) => p.id == active).map((p) => p.name).firstOrNull ??
            'Default';

    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration:
                BoxDecoration(color: Theme.of(context).colorScheme.primary),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Chovos Hayom',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
                  Text('Profile: $activeName',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary)),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Profiles'),
            onTap: () => _go(context, const ProfilesScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.add_box_outlined),
            title: const Text('Add custom sefer'),
            onTap: () => _go(context, const AddCustomNodeScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => _go(context, const SettingsScreen()),
          ),
        ],
      ),
    );
  }

  void _go(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
  }
}
