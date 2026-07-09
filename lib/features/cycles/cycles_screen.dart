import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../core/calendar.dart';
import '../../core/daf_yomi.dart';
import '../../domain/entities/catalog_node.dart';

/// Built-in learning cycles. Shows today's Daf Yomi (Bavli) and, when the daf
/// maps to a mesechta in the catalog, lets you log it in one tap.
class CyclesScreen extends ConsumerWidget {
  const CyclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final info = DafYomi.forDate(now);
    final mode = ref.watch(settingsProvider).calendar;

    return Scaffold(
      appBar: AppBar(title: const Text('Learning cycles')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Today · ${DateDisplay.format(now, mode)}',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          if (info == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text("Daf Yomi isn't available for this date."),
              ),
            )
          else
            _DafYomiCard(info: info),
        ],
      ),
    );
  }
}

class _DafYomiCard extends ConsumerWidget {
  const _DafYomiCard({required this.info});
  final DafYomiInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final fold = ref.watch(foldProvider).asData?.value;
    final match = catalog == null ? null : _matchMesechta(catalog.all, info);
    final required = ref.watch(layerRequirementsProvider);
    final alreadyDone = match != null &&
        (fold?.doneUnits(match.id, required).contains(info.daf) ?? false);
    final inRange = match != null && match.containsUnit(info.daf);

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daf Yomi', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text('${info.masechtaEnglish} ${info.daf}',
                style: Theme.of(context).textTheme.headlineSmall),
            Text('${info.masechtaHebrew} · דף ${info.daf}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (match == null || !inRange)
              const Text(
                  'This mesechta isn\'t in your catalog, so it can\'t be logged '
                  'automatically. You can still track it from the main list.')
            else if (alreadyDone)
              const Row(children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Logged for today ✓'),
              ])
            else
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: Text('Log ${info.masechtaEnglish} ${info.daf}'),
                onPressed: () {
                  final messenger = ScaffoldMessenger.of(context);
                  ref.read(loggingServiceProvider).markDone(match.id, info.daf);
                  messenger.showSnackBar(SnackBar(
                      content: Text(
                          'Logged ${info.masechtaEnglish} ${info.daf}')));
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Finds the Bavli mesechta leaf whose name matches today's daf. Bavli leaves
  /// use `shas.*` ids in the bundled catalog; match on English or Hebrew name.
  static CatalogNode? _matchMesechta(
      Iterable<CatalogNode> nodes, DafYomiInfo info) {
    final wantEn = _norm(info.masechtaEnglish);
    final wantHe = _norm(info.masechtaHebrew);
    for (final n in nodes) {
      if (!n.isLeaf || !n.id.startsWith('shas')) continue;
      if (_norm(n.name) == wantEn ||
          (n.nameHebrew != null && _norm(n.nameHebrew!) == wantHe)) {
        return n;
      }
    }
    return null;
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-zא-ת]'), '');
}
