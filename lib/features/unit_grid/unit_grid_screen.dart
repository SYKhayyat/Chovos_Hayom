import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/usecases/fold_log.dart';
import 'log_unit_sheet.dart';

/// A grid of every unit (daf/perek/siman) in a leaf. Tap toggles done with an
/// auto-date; long-press opens the sheet to log a date/duration/note.
class UnitGridScreen extends ConsumerWidget {
  const UnitGridScreen({super.key, required this.node});

  final CatalogNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldAsync = ref.watch(foldProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(node.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${node.unitCount} ${node.unitLabel?.name ?? 'units'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: foldAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (fold) => _grid(context, ref, fold),
      ),
    );
  }

  Widget _grid(BuildContext context, WidgetRef ref, LogFold fold) {
    final done = fold.doneUnits(node.id);
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 64,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: node.unitCount,
      itemBuilder: (context, i) {
        final unit = node.unitOffset + i;
        final isDone = done.contains(unit);
        final reviews = fold.reviewCount(node.id, unit);
        return _UnitCell(
          label: '$unit',
          isDone: isDone,
          reviewCount: reviews,
          onTap: () {
            final logger = ref.read(loggingServiceProvider);
            if (isDone) {
              logger.markUndone(node.id, unit);
            } else {
              logger.markDone(node.id, unit);
            }
          },
          onLongPress: () async {
            final result = await showLogUnitSheet(
              context,
              title: '${node.name} · ${node.unitLabel?.name ?? 'unit'} $unit',
            );
            if (result == null) return;
            await ref.read(loggingServiceProvider).markDone(
                  node.id,
                  unit,
                  occurredAt: result.occurredAt,
                  durationMin: result.durationMin,
                  note: result.note,
                );
          },
        );
      },
    );
  }
}

class _UnitCell extends StatelessWidget {
  const _UnitCell({
    required this.label,
    required this.isDone,
    required this.reviewCount,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final bool isDone;
  final int reviewCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isDone ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isDone ? scheme.onPrimary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (reviewCount > 0)
              Positioned(
                right: 4,
                top: 2,
                child: Text('↻$reviewCount',
                    style: TextStyle(
                        fontSize: 10,
                        color: isDone ? scheme.onPrimary : scheme.primary)),
              ),
          ],
        ),
      ),
    );
  }
}
