import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/goals.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../domain/usecases/goal_evaluator.dart';
import '../../l10n/generated/app_localizations.dart';
import 'guarded.dart';

/// One goal, said one way, and removed one way.
///
/// A goal is rendered in two places — the unit grid's banner and the Goals
/// section of the report — and until this file existed each had written the same
/// three facts out for itself, against **two ARB templates for one sentence**
/// (`"Goal {date} · need {rate}/day · {status}"` and
/// `"By {date} · need {rate}/day · {status}"`), with two spellings of "reached"
/// and two copies of remove-with-undo. Nothing forced them to agree, and they
/// had already drifted: only one of them named the sefer in its "removed"
/// snackbar, so undoing from the other told you a goal had gone without saying
/// which.
///
/// The colour is part of the reading, not decoration: a goal is green when it is
/// already met, the primary colour when the current pace still reaches it, and
/// the error colour when it does not. [GoalStatus.onTrack] is the only thing
/// that decides that, in one place, for both renderings.

/// What a goal says: its date, the pace it needs, and whether that pace is being
/// held — or that it is already done.
String goalStatusText(
    AppLocalizations l10n, GoalStatus goal, CalendarMode mode) {
  if (goal.achieved) return l10n.goalReached;
  return l10n.goalStatus(
    DateDisplay.format(goal.target.midnight, mode),
    goal.requiredPerDay.toStringAsFixed(2),
    goal.onTrack ? l10n.goalOnTrack : l10n.goalBehind,
  );
}

/// The colour that carries the same verdict as the words.
Color goalStatusColor(BuildContext context, GoalStatus goal) {
  final scheme = Theme.of(context).colorScheme;
  if (goal.achieved) return Colors.green;
  return goal.onTrack ? scheme.primary : scheme.error;
}

/// Which way the trend arrow points. An achieved goal points up: it was met.
IconData goalStatusIcon(GoalStatus goal) => goal.achieved
    ? Icons.emoji_events
    : (goal.onTrack ? Icons.trending_up : Icons.trending_down);

/// Removes [nodeId]'s goal, offering an Undo that restores **the same target
/// date** rather than a blank one.
///
/// Reading the current target before the write is what makes that possible, and
/// it is also the null check: a row whose goal has already gone offers no undo
/// instead of an undo that would invent a goal.
Future<void> removeGoalWithUndo(
  BuildContext context,
  WidgetRef ref, {
  required String nodeId,
  required String name,
}) async {
  final previous = ref.read(goalsProvider)[nodeId];
  final goals = ref.read(goalsProvider.notifier);
  final guard = WriteGuard.of(context, ref);
  final l10n = AppLocalizations.of(context);
  await guard.run(
    () => goals.removeGoal(nodeId),
    what: l10n.whatRemovingGoal(name),
    success: previous == null ? null : l10n.goalRemovedFor(name),
    undo: previous == null
        ? null
        : SnackBarAction(
            label: l10n.actionUndo,
            // Restoring is itself a write, so it reports like one rather than
            // silently doing nothing if it fails.
            onPressed: () => guard.run(() => goals.setGoal(nodeId, previous),
                what: l10n.whatRestoringGoal(name)),
          ),
  );
}

/// The goal line as the unit grid wears it: a tinted strip across the top of the
/// sefer it belongs to, with a close button that removes it.
class GoalBanner extends ConsumerWidget {
  const GoalBanner(
      {super.key,
      required this.goal,
      required this.nodeId,
      required this.name});

  final GoalStatus goal;
  final String nodeId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.calendar));
    final l10n = AppLocalizations.of(context);
    final color = goalStatusColor(context, goal);
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(goalStatusIcon(goal), color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(goalStatusText(l10n, goal, mode),
                  style: TextStyle(color: color))),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: l10n.tooltipRemoveGoal,
            onPressed: () =>
                removeGoalWithUndo(context, ref, nodeId: nodeId, name: name),
          ),
        ],
      ),
    );
  }
}
