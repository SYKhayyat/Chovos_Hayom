import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/stats.dart';
import '../../domain/usecases/chazara_schedule.dart';

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
    final label = node?.unitLabel?.name ?? 'unit';
    final name = node?.name ?? item.nodeId;
    final overdue = item.daysOverdue == 0
        ? 'due today'
        : '${item.daysOverdue} day${item.daysOverdue == 1 ? '' : 's'} overdue';

    return ListTile(
      leading: const Icon(Icons.refresh),
      title: Text('$name · $label ${item.unitIndex}'),
      subtitle: Text('$overdue · ${item.reviewCount} review'
          '${item.reviewCount == 1 ? '' : 's'} so far'),
      trailing: FilledButton.tonal(
        onPressed: () {
          final messenger = ScaffoldMessenger.of(context);
          ref
              .read(loggingServiceProvider)
              .markReview(item.nodeId, item.unitIndex);
          messenger.showSnackBar(
              SnackBar(content: Text('Reviewed $name $label ${item.unitIndex}')));
        },
        child: const Text('Review'),
      ),
    );
  }
}
