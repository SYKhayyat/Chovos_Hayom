import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/stats.dart';
import '../../domain/entities/layer.dart';
import '../../domain/usecases/chazara_schedule.dart';
import '../unit_grid/add_chazara_sheet.dart';

/// Units due for a chazara (review) pass, on a spaced-repetition schedule.
/// Reviewing an item logs a review and pushes its next due date out.
class ChazaraScreen extends ConsumerWidget {
  const ChazaraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(chazaraDueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chazara due')),
      body: due.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nothing due for review right now.\n'
                  'Learned units come back here on a spaced schedule.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: due.length,
              itemBuilder: (context, i) {
                final item = due[i];
                return _ChazaraRow(item: item);
              },
            ),
    );
  }
}

class _ChazaraRow extends ConsumerWidget {
  const _ChazaraRow({required this.item});
  final ChazaraItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(catalogNodeProvider(item.nodeId));
    final name = node?.name ?? item.nodeId;
    // Named units (parshiyos, simanim) read as their names here too, not as
    // bare numbers — the same heading the grid and the journal show.
    final unit = node?.unitHeading(item.unitIndex) ?? 'unit ${item.unitIndex}';
    final overdue = item.daysOverdue == 0
        ? 'due today'
        : '${item.daysOverdue} day${item.daysOverdue == 1 ? '' : 's'} overdue';

    return ListTile(
      leading: const Icon(Icons.refresh),
      title: Text('$name · $unit'),
      subtitle: Text('$overdue · ${item.reviewCount} review'
          '${item.reviewCount == 1 ? '' : 's'} so far'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The full sheet: pick which mefarshim, when, how long, and a haara.
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Log with details',
            onPressed: node == null
                ? null
                : () => showAddChazaraSheet(context, ref,
                    node: node, unit: item.unitIndex),
          ),
          FilledButton.tonal(
            onPressed: () => _quickReview(context, ref, name, unit),
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }

  /// One tap = a pass over **everything currently learned on this unit**, which
  /// is what the Add-chazara sheet defaults to. The two paths used to disagree —
  /// this button recorded only the text, so a daf reviewed from here silently
  /// lost its mefarshim, and the same action meant two different things
  /// depending on where you tapped it.
  Future<void> _quickReview(
      BuildContext context, WidgetRef ref, String name, String unit) async {
    final messenger = ScaffoldMessenger.of(context);
    final fold = ref.read(foldProvider).asData?.value;
    final learned =
        fold?.completedLayers(item.nodeId, item.unitIndex) ?? const <String>{};
    await ref.read(loggingServiceProvider).markReview(
          item.nodeId,
          item.unitIndex,
          layers: learned.isEmpty ? const [mainLayerId] : learned.toList(),
        );
    messenger.showSnackBar(SnackBar(content: Text('Reviewed $name · $unit')));
  }
}
