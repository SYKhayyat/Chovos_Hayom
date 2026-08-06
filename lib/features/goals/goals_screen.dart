import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/goals.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final mode = ref.watch(settingsProvider.select((s) => s.calendar));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.goalsTitle)),
      body: goals.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.goalsEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: [
                for (final nodeId in goals.keys)
                  _GoalRow(nodeId: nodeId, mode: mode),
              ],
            ),
    );
  }
}

class _GoalRow extends ConsumerWidget {
  const _GoalRow({required this.nodeId, required this.mode});
  final String nodeId;
  final CalendarMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(catalogNodeProvider(nodeId));
    final status = ref.watch(goalStatusProvider(nodeId));
    final target = ref.watch(goalsProvider)[nodeId];
    final l10n = AppLocalizations.of(context);
    if (node == null || status == null || target == null) {
      return const SizedBox.shrink();
    }
    final ok = status.onTrack;
    final color = status.achieved
        ? Colors.green
        : (ok ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error);

    return ListTile(
      leading: Icon(status.achieved
          ? Icons.emoji_events
          : (ok ? Icons.trending_up : Icons.trending_down), color: color),
      title: Text(nodeName(l10n, node)),
      subtitle: Text(status.achieved
          ? l10n.goalRowReached
          : l10n.goalRowStatus(
              DateDisplay.format(target, mode),
              status.requiredPerDay.toStringAsFixed(2),
              ok ? l10n.goalOnTrack : l10n.goalBehind,
            )),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.tooltipRemoveGoal,
        onPressed: () => _remove(context, ref, nodeName(l10n, node), target),
      ),
    );
  }

  Future<void> _remove(
      BuildContext context, WidgetRef ref, String name, DateTime target) async {
    final goals = ref.read(goalsProvider.notifier);
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    await guard.run(
      () => goals.removeGoal(nodeId),
      what: l10n.whatRemovingGoal(name),
      success: l10n.goalRemovedFor(name),
      undo: SnackBarAction(
        label: l10n.actionUndo,
        onPressed: () => guard.run(() => goals.setGoal(nodeId, target),
            what: l10n.whatRestoringGoal(name)),
      ),
    );
  }
}
