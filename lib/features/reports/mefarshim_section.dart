import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/naming.dart';
import 'report_screen.dart';

/// A breakdown of how much of each meforish (and the primary text) you've
/// learned across everything — e.g. "Rashi: 240 units". Becomes meaningful once
/// optional mefarshim are tracked, since progress bars only count required ones.
class MefarshimSection extends ConsumerWidget {
  const MefarshimSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(mefarshimStatsProvider);
    final layers = ref.watch(allLayersProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (stats.isEmpty) {
      return ReportEmpty(message: l10n.mefarshimProgressEmpty);
    }

    final max = stats.map((s) => s.learnedUnits).reduce((a, b) => a > b ? a : b);

    // Rows of bars and figures, none of them focusable, so a D-pad had
    // nothing to move focus to and this list never scrolled a pixel on a
    // keypad phone. See [ReportBody], and the Overview tab, which had the same.
    return ReportBody(
      builder: (context, controller) => ListView.separated(
        controller: controller,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: stats.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final stat = stats[i];
          // A stat row is keyed by layer id, and an id with no meforish behind
          // it means one was deleted after those units were marked. Named
          // rather than printed raw — see [layerById].
          final layer = layerById(l10n, layers, stat.layerId);
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
            trailing:
                Text('${stat.learnedUnits}', style: theme.textTheme.titleMedium),
          );
        },
      ),
    );
  }
}
