import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/plans.dart';
import '../../application/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';

class PlannerTodayScreen extends ConsumerWidget {
  const PlannerTodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(todayAssignmentsProvider);
    final l10n = AppLocalizations.of(context);
    final groups = <String, List<TodayAssignment>>{};
    for (final assignment in assignments) {
      groups.putIfAbsent(assignment.plan.id, () => []).add(assignment);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.plannerTodayTitle)),
      body: assignments.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.plannerTodayEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: [
                for (final group in groups.values) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      group.first.plan.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final assignment in group)
                    _AssignmentTile(assignment: assignment),
                ],
              ],
            ),
    );
  }
}

class _AssignmentTile extends ConsumerWidget {
  const _AssignmentTile({required this.assignment});

  final TodayAssignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final node = assignment.node;
    final unit = assignment.unitIndex;
    final heading = nodeAndUnit(l10n, node, unit ?? node.unitOffset);
    final title = unit == null
        ? l10n.plannerTodayComplete
        : '${l10n.plannerTodayLogUnit(unit)} · $heading';

    return ListTile(
      leading: Icon(
        unit == null ? Icons.check_circle_outline : Icons.today_outlined,
      ),
      title: Text(title),
      subtitle: Text(
        assignment.assignment.label ?? l10n.plannerTodayScheduled,
      ),
      trailing: unit == null
          ? null
          : FilledButton(
              onPressed: () => _log(context, ref, unit),
              child: Text(l10n.actionMark),
            ),
    );
  }

  Future<void> _log(BuildContext context, WidgetRef ref, int unit) async {
    final l10n = AppLocalizations.of(context);
    final logger = ref.read(loggingServiceProvider);
    final name = nodeAndUnit(l10n, assignment.node, unit);
    await guarded(
      context,
      ref,
      () => logger.markDone(assignment.unitNodeId, unit),
      what: l10n.whatMarkingLearned(name),
    );
  }
}
