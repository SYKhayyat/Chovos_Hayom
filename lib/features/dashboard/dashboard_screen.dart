import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../calculator/calculator_screen.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chovos Hayom'),
        actions: [
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
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => _push(context, const SettingsScreen()),
          ),
        ],
      ),
      body: forest.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (nodes) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [for (final n in nodes) ProgressTile(node: n)],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}
