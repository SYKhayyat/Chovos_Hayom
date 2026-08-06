import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/goals.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/goal_status.dart';
import '../common/naming.dart';
import 'report_screen.dart';

/// Every target date you've set, and whether you're keeping to it.
///
/// This screen used to be unable to create the thing it listed. Its only verb
/// was *delete*, and its empty state was an instruction to go somewhere else:
/// open a sefer, find the flag in its app bar, tap it. Meanwhile the Calculator
/// — a separate route, three rows further down the same drawer — had a "By date"
/// mode that asks *what daily rate do I need to finish this by then*, which is
/// the arithmetic behind a goal and nothing else, and then threw the answer
/// away when you left.
///
/// They are two tabs of one report now, so the affordance is real: [_SetGoal]
/// moves to the Calculator, where the picker and the date already are.
class GoalsSection extends ConsumerWidget {
  const GoalsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final l10n = AppLocalizations.of(context);

    if (goals.isEmpty) {
      return ReportEmpty(message: l10n.goalsEmpty, action: const _SetGoal());
    }
    return ListView(
      children: [
        for (final nodeId in goals.keys) _GoalRow(nodeId: nodeId),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Align(child: _SetGoal()),
        ),
      ],
    );
  }
}

/// Sends you to the Calculator tab, which is where a goal is made.
class _SetGoal extends StatelessWidget {
  const _SetGoal();

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      icon: const Icon(Icons.flag_outlined, size: 18),
      label: Text(AppLocalizations.of(context).goalsSetOne),
      onPressed: () => DefaultTabController.of(context)
          .animateTo(ReportSection.calculator.index),
    );
  }
}

class _GoalRow extends ConsumerWidget {
  const _GoalRow({required this.nodeId});
  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(catalogNodeProvider(nodeId));
    final status = ref.watch(goalStatusProvider(nodeId));
    final mode = ref.watch(settingsProvider.select((s) => s.calendar));
    final l10n = AppLocalizations.of(context);
    if (node == null || status == null) return const SizedBox.shrink();
    final name = nodeName(l10n, node);

    // The words, the colour and the arrow all come from [goal_status.dart], so
    // this row and the unit grid's banner cannot drift into saying the same
    // thing two ways again.
    return ListTile(
      leading:
          Icon(goalStatusIcon(status), color: goalStatusColor(context, status)),
      title: Text(name),
      subtitle: Text(goalStatusText(l10n, status, mode)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.tooltipRemoveGoal,
        onPressed: () =>
            removeGoalWithUndo(context, ref, nodeId: nodeId, name: name),
      ),
    );
  }
}
