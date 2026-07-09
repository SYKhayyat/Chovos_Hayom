import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/goals.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/learning_event.dart';
import '../../domain/usecases/fold_log.dart';
import '../../domain/usecases/goal_evaluator.dart';
import 'log_unit_sheet.dart';
import 'unit_details_sheet.dart';

/// A grid of every unit (daf/perek/siman) in a leaf. Tap toggles done; long-press
/// opens a menu to log details, add a chazara (review), or un-mark.
class UnitGridScreen extends ConsumerWidget {
  const UnitGridScreen({super.key, required this.node});

  final CatalogNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldAsync = ref.watch(foldProvider);
    final goal = ref.watch(goalStatusProvider(node.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(node.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Set goal date',
            onPressed: () => _setGoal(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          if (goal != null) _GoalBanner(goal: goal, nodeId: node.id),
          Expanded(
            child: foldAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (fold) => _grid(context, ref, fold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setGoal(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 180)),
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      await ref.read(goalsProvider.notifier).setGoal(node.id, picked);
    }
  }

  Widget _grid(BuildContext context, WidgetRef ref, LogFold fold) {
    final done = fold.doneUnits(node.id);
    // Units carrying a recorded note or duration on a `done` event — surfaced as
    // a small dot so details are discoverable at a glance.
    final events = ref.watch(eventsProvider).asData?.value ?? const <LearningEvent>[];
    final annotated = <int>{
      for (final e in events)
        if (e.nodeId == node.id &&
            e.action == EventAction.done &&
            ((e.note != null && e.note!.isNotEmpty) ||
                (e.haara != null && e.haara!.isNotEmpty) ||
                e.durationMin != null))
          e.unitIndex,
    };
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
        return _UnitCell(
          label: '$unit',
          isDone: isDone,
          reviewCount: fold.reviewCount(node.id, unit),
          hasDetails: isDone && annotated.contains(unit),
          onTap: () async {
            // markUndone appends an inverse event (non-destructive, reversible by
            // tapping again), so no confirmation — but surface any save failure.
            final logger = ref.read(loggingServiceProvider);
            final messenger = ScaffoldMessenger.of(context);
            try {
              if (isDone) {
                await logger.markUndone(node.id, unit);
              } else {
                await logger.markDone(node.id, unit);
              }
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
            }
          },
          onLongPress: () => _cellMenu(context, ref, unit, isDone),
        );
      },
    );
  }

  Future<void> _cellMenu(
      BuildContext context, WidgetRef ref, int unit, bool isDone) async {
    final logger = ref.read(loggingServiceProvider);
    final label = node.unitLabel?.name ?? 'unit';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDone)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('View / edit details'),
                subtitle: const Text('When you finished, how long, your note'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showUnitDetailsSheet(context, ref, node: node, unit: unit);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_calendar),
              title: Text(isDone
                  ? 'Re-log with date / duration / note'
                  : 'Log with date / duration / note'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final result = await showLogUnitSheet(context,
                    title: '${node.name} · $label $unit');
                if (result == null) return;
                await logger.markDone(node.id, unit,
                    occurredAt: result.occurredAt,
                    durationMin: result.durationMin,
                    note: result.note,
                    haara: result.haara);
              },
            ),
            if (isDone) ...[
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Add chazara (review)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  logger.markReview(node.id, unit);
                },
              ),
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('Un-mark'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  logger.markUndone(node.id, unit);
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.check),
                title: const Text('Mark learned'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  logger.markDone(node.id, unit);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalBanner extends ConsumerWidget {
  const _GoalBanner({required this.goal, required this.nodeId});
  final GoalStatus goal;
  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider).calendar;
    final scheme = Theme.of(context).colorScheme;
    final ok = goal.onTrack;
    final color = goal.achieved
        ? Colors.green
        : (ok ? scheme.primary : scheme.error);
    final text = goal.achieved
        ? 'Goal reached! 🎉'
        : 'Goal ${DateDisplay.format(goal.target, mode)} · '
            'need ${goal.requiredPerDay.toStringAsFixed(2)}/day · '
            '${ok ? 'on track' : 'behind'}';
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(ok ? Icons.trending_up : Icons.trending_down, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color))),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove goal',
            onPressed: () async {
              final previous = ref.read(goalsProvider)[nodeId];
              final messenger = ScaffoldMessenger.of(context);
              await ref.read(goalsProvider.notifier).removeGoal(nodeId);
              if (previous == null) return;
              messenger.showSnackBar(SnackBar(
                content: const Text('Goal removed'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () =>
                      ref.read(goalsProvider.notifier).setGoal(nodeId, previous),
                ),
              ));
            },
          ),
        ],
      ),
    );
  }
}

class _UnitCell extends StatelessWidget {
  const _UnitCell({
    required this.label,
    required this.isDone,
    required this.reviewCount,
    required this.hasDetails,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final bool isDone;
  final int reviewCount;
  final bool hasDetails;
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
            if (hasDetails)
              Positioned(
                left: 5,
                bottom: 4,
                child: Icon(Icons.sticky_note_2,
                    size: 11,
                    color: isDone ? scheme.onPrimary : scheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}
