import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/layer.dart';

/// A breakdown of how much of each meforish (and the primary text) you've
/// learned across everything — e.g. "Rashi: 240 units". Becomes meaningful once
/// optional mefarshim are tracked, since progress bars only count required ones.
class MefarshimProgressScreen extends ConsumerWidget {
  const MefarshimProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(mefarshimStatsProvider);
    final layers = ref.watch(allLayersProvider);
    final theme = Theme.of(context);

    Layer layerOf(String id) =>
        layers.firstWhere((l) => l.id == id, orElse: () => Layer(id: id, name: id));

    final max = stats.isEmpty
        ? 1
        : stats.map((s) => s.learnedUnits).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Mefarshim progress')),
      body: stats.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nothing learned yet.\nAs you check off mefarshim, their totals '
                  'appear here.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: stats.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final stat = stats[i];
                final layer = layerOf(stat.layerId);
                return ListTile(
                  title: Text(layer.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (layer.nameHebrew != null)
                        Text(layer.nameHebrew!, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: stat.learnedUnits / max,
                        ),
                      ),
                    ],
                  ),
                  trailing: Text('${stat.learnedUnits}',
                      style: theme.textTheme.titleMedium),
                );
              },
            ),
    );
  }
}
