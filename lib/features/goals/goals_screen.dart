import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/goals.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final mode = ref.watch(settingsProvider).calendar;

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: goals.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No goals yet.\nOpen any sefer and tap the flag to set a target date.',
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
      title: Text(node.name),
      subtitle: Text(status.achieved
          ? 'Reached!'
          : 'By ${DateDisplay.format(target, mode)} · '
              'need ${status.requiredPerDay.toStringAsFixed(2)}/day · '
              '${ok ? 'on track' : 'behind'}'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => ref.read(goalsProvider.notifier).removeGoal(nodeId),
      ),
    );
  }
}
