import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/goals.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/layer.dart';
import '../../domain/usecases/fold_log.dart';
import '../../domain/usecases/goal_evaluator.dart';
import '../common/guarded.dart';
import '../common/missing_item.dart';
import 'add_chazara_sheet.dart';
import 'bulk_actions_sheet.dart';
import 'log_unit_sheet.dart';
import 'mefarshim_config_sheet.dart';
import 'unit_details_sheet.dart';
import 'unit_layers_sheet.dart';

/// Log one unit with a date, a duration, a haara — **and**, on a layered unit,
/// which mefarshim it covers.
///
/// Those two features used to be mutually exclusive: the checklist marked a
/// meforish with no date, duration or haara, and this sheet always wrote
/// `layers: [main]`, so on a layered unit it only marked the text. There was no
/// way to record "I learned Rashi on this daf for 40 minutes and here's my
/// chiddush". One sheet now does both, and the layer checklist is seeded with
/// whatever the unit still needs.
Future<void> logWithDetails(
  BuildContext context,
  WidgetRef ref, {
  required CatalogNode node,
  required int unit,
}) async {
  final view = ref.read(unitLayerViewProvider);
  final fold = ref.read(foldProvider).asData?.value;
  final allLayers = ref.read(allLayersProvider);
  final logger = ref.read(loggingServiceProvider);
  final guard = WriteGuard.of(context, ref);

  final layered = view.isLayered(node.id, unit);
  final checkable = layered ? view.checkableFor(node.id, unit) : const <String>{};
  final learned = fold?.completedLayers(node.id, unit) ?? const <String>{};
  final required = layered ? view.requiredFor(node.id, unit) : const <String>{};
  // Default to what's still outstanding; if nothing is, to everything required.
  final outstanding = required.where((l) => !learned.contains(l)).toSet();

  final result = await showLogUnitSheet(
    context,
    title: '${node.name} · ${node.unitHeading(unit)}',
    nodeId: node.id,
    unitIndex: unit,
    layerOptions: [
      for (final l in allLayers)
        if (checkable.contains(l.id)) l,
    ],
    initialLayers: layered
        ? (outstanding.isNotEmpty ? outstanding : required)
        : const {mainLayerId},
  );
  if (result == null) return;
  await guard.run(
    () => logger.markDone(node.id, unit,
        occurredAt: result.occurredAt,
        durationMin: result.durationMin,
        note: result.note,
        layers: result.layers),
    what: 'Logging ${node.name} · ${node.unitHeading(unit)}',
  );
}

/// A grid of every unit (daf/perek/siman) in a leaf. Tap toggles done; long-press
/// opens a menu to log details, add a chazara (review), or un-mark.
///
/// Addressed by **id**, not by a `CatalogNode`: holding the node meant the screen
/// froze it at push time, so renaming a sefer (or changing its unit count) while
/// its grid was open left the old name in the app bar. Resolving the id against
/// the live catalog on every build is also what lets `/sefer/<id>` be a route.
class UnitGridScreen extends ConsumerWidget {
  const UnitGridScreen({super.key, required this.nodeId});

  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(catalogNodeProvider(nodeId));
    if (node == null) {
      return MissingItemScreen(
        loading: !ref.watch(mergedCatalogProvider).hasValue,
        message: 'This sefer no longer exists.\n'
            'It may have been hidden, deleted, or replaced.',
      );
    }
    return _UnitGrid(node: node);
  }
}

class _UnitGrid extends ConsumerWidget {
  const _UnitGrid({required this.node});

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
            icon: const Icon(Icons.checklist),
            tooltip: 'Finish all / clear all',
            onPressed: () => showBulkActionsSheet(context, ref, node: node),
          ),
          IconButton(
            icon: const Icon(Icons.auto_stories_outlined),
            tooltip: 'Mefarshim',
            onPressed: () => showMefarshimConfigSheet(context, ref, node: node),
          ),
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Set goal date',
            onPressed: () => _setGoal(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          if (goal != null) _GoalBanner(goal: goal, nodeId: node.id, name: node.name),
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
    final guard = WriteGuard.of(context, ref);
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 180)),
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    await guard.run(
      () => ref.read(goalsProvider.notifier).setGoal(node.id, picked),
      what: 'Setting a goal for ${node.name}',
    );
  }

  Widget _grid(BuildContext context, WidgetRef ref, LogFold fold) {
    final required = ref.watch(layerRequirementsProvider);
    final view = ref.watch(unitLayerViewProvider);
    final done = fold.doneUnits(node.id, required);
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
        // A unit shows the per-layer checklist when it *offers* more than the
        // text (offered ∪ required); its fill fraction tracks only the *required*
        // layers, so optional mefarshim never inflate progress.
        final layered = view.isLayered(node.id, unit);
        final fraction = isDone
            ? 1.0
            : (layered ? view.fraction(node.id, unit, fold) : 0.0);
        return _UnitCell(
          label: node.unitDisplay(unit),
          isDone: isDone,
          fraction: fraction,
          reviewCount: fold.reviewCount(node.id, unit),
          // The "there are details here" dot. Comes off the shared fold rather
          // than a scan of the whole log on every grid rebuild.
          hasDetails: isDone && fold.isAnnotated(node.id, unit),
          onTap: () async {
            // Layered units open a per-meforish checklist; text-only units
            // toggle with a single tap (reversible — tapping again undoes).
            if (layered) {
              await showUnitLayersSheet(context, ref, node: node, unit: unit);
              return;
            }
            final logger = ref.read(loggingServiceProvider);
            final heading = '${node.name} · ${node.unitHeading(unit)}';
            await guarded(
              context,
              ref,
              () => isDone
                  ? logger.markUndone(node.id, unit)
                  : logger.markDone(node.id, unit),
              what: isDone ? 'Un-marking $heading' : 'Marking $heading learned',
            );
          },
          onLongPress: () => _cellMenu(context, ref, unit, isDone),
        );
      },
    );
  }

  Future<void> _cellMenu(
      BuildContext context, WidgetRef ref, int unit, bool isDone) async {
    final logger = ref.read(loggingServiceProvider);
    final heading = '${node.name} · ${node.unitHeading(unit)}';
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
                await logWithDetails(context, ref, node: node, unit: unit);
              },
            ),
            if (isDone) ...[
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Add chazara (review)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showAddChazaraSheet(context, ref, node: node, unit: unit);
                },
              ),
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('Un-mark'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  guarded(context, ref, () => logger.markUndone(node.id, unit),
                      what: 'Un-marking $heading');
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.check),
                title: const Text('Mark learned'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  guarded(context, ref, () => logger.markDone(node.id, unit),
                      what: 'Marking $heading learned');
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalBanner extends ConsumerWidget {
  const _GoalBanner(
      {required this.goal, required this.nodeId, required this.name});
  final GoalStatus goal;
  final String nodeId;
  final String name;

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
            onPressed: () => _remove(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final previous = ref.read(goalsProvider)[nodeId];
    final goals = ref.read(goalsProvider.notifier);
    final guard = WriteGuard.of(context, ref);
    await guard.run(
      () => goals.removeGoal(nodeId),
      what: 'Removing the goal for $name',
      success: previous == null ? null : 'Goal removed',
      undo: previous == null
          ? null
          : SnackBarAction(
              label: 'Undo',
              // Restoring is itself a write, so it reports like one rather than
              // silently doing nothing if it fails.
              onPressed: () => guard.run(() => goals.setGoal(nodeId, previous),
                  what: 'Restoring the goal for $name'),
            ),
    );
  }
}

class _UnitCell extends StatelessWidget {
  const _UnitCell({
    required this.label,
    required this.isDone,
    required this.fraction,
    required this.reviewCount,
    required this.hasDetails,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final bool isDone;

  /// 0..1 share of required layers done — a partial fill for layered units.
  final double fraction;
  final int reviewCount;
  final bool hasDetails;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final partial = !isDone && fraction > 0;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      // Right-click / secondary-tap opens the same menu — desktop-friendly, no
      // touchscreen required.
      onSecondaryTap: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: isDone ? scheme.primary : scheme.surfaceContainerHighest,
          ),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Partial-completion fill rising from the bottom.
              if (partial)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: fraction.clamp(0.05, 1),
                      child: Container(
                        color: scheme.primary.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    // Shrink long named-unit labels so they still fit the cell.
                    fontSize: label.length > 3 ? 10 : 14,
                    color: isDone ? scheme.onPrimary : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
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
      ),
    );
  }
}
