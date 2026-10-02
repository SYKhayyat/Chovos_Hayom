import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/plans.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../app/routes.dart';
import '../../core/calendar.dart';
import '../../core/day.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/usecases/plan_position.dart';
import '../../domain/usecases/plan_rate.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/date_field.dart';
import '../common/naming.dart';
import 'reflow_sheet.dart';

/// One plan's own screen: where it stands, how fast it is actually moving, and
/// the home of recompute.
///
/// **A new screen, not a change to the calendar** — and the reason is the
/// issue's: the calendar can say what a day asks for, and only this can say
/// whether the learner is keeping up with it. "A plan asking 7 blatt a day that
/// you have been doing 3 on is a plan about to fall behind, and nothing on the
/// calendar says so" is a comparison between the plan and the log, which is the
/// one thing a calendar of dates cannot express.
///
/// **Per plan, never across them.** A day routinely runs several, and they fall
/// behind independently, so this screen is reached by opening one plan.
///
/// Displays and expresses intent. Every number here is read from a fold
/// ([PlanRate], [PlanProgress]) rather than computed in a `build`, and the one
/// action it owns — recompute — is [Reflow]'s, the same implementation the day's
/// sheet runs.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final plan = ref.watch(planByIdProvider(planId));
    final standing = ref.watch(planStandingProvider(planId));

    return Scaffold(
      appBar: AppBar(
        title: Text(plan?.name ?? l10n.plansTitle),
        actions: [
          // Edit lives here rather than being what tapping a plan does, so the
          // list's tap can open this screen — which is what a person tapping a
          // plan name is asking for, and editing was never the same request.
          if (plan != null)
            // **A word, not an icon.** Two reasons, and neither is taste: the
            // Sonim has no touchscreen, so this has to be findable and
            // announceable from a tooltip, and the golden renders icons from a
            // deliberately partial engine fixture in which the pencil is a
            // notdef box — a photograph of a broken app. The editor's own app
            // bar already does this with a `Save` button.
            TextButton(
              key: const ValueKey('plan-edit'),
              onPressed: () =>
                  Navigator.of(context).pushNamed(Routes.editPlan(planId)),
              child: Text(l10n.planEdit),
            ),
        ],
      ),
      body: switch ((plan, standing)) {
        // Still loading, or the plan was deleted from under the screen. Both are
        // "nothing to show"; the log being unreadable is not a plan with no
        // progress, and printing a standing for it would be inventing one.
        (null, _) || (_, null) => const SizedBox.shrink(),
        (_, final PlanStanding s) => _PlanBody(
          planId: planId,
          standing: s,
          position: ref.watch(planPositionProvider(planId)),
          catalog: ref.watch(mergedCatalogProvider).asData?.value,
        ),
      },
    );
  }
}

/// Where [planId] has got to in its sequence, or null while it cannot be read.
///
/// A provider rather than a derivation in the screen, so the walk over the
/// plan's ranges happens once per change instead of once per rebuild — and so
/// that a screen that does not care (the one showing only a rate) can skip it
/// entirely.
final planPositionProvider = Provider.autoDispose.family<PlanPosition?, String>(
  (ref, id) {
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final fold = ref.watch(foldProvider).asData?.value;
    final plan = ref.watch(planByIdProvider(id));
    if (catalog == null || fold == null || plan == null) return null;
    return PlanProgress.positionOn(
      plan,
      catalog,
      fold,
      Day.of(ref.watch(clockProvider)()),
      layers: ref.watch(layerRolesProvider),
    );
  },
);

class _PlanBody extends ConsumerWidget {
  const _PlanBody({
    required this.planId,
    required this.standing,
    required this.position,
    required this.catalog,
  });

  final String planId;
  final PlanStanding standing;
  final PlanPosition? position;
  final Catalog? catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(settingsProvider.select((s) => s.calendar));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Standing(standing: standing, position: position, catalog: catalog),
        const Divider(height: 32),
        _Rate(standing: standing, mode: mode),
        const Divider(height: 32),
        // **The home of recompute** (#47). One implementation with the day's
        // sheet, so "keep the amounts" and "spread them over three days" mean
        // the same thing wherever they are reached from.
        OutlinedButton.icon(
          key: const ValueKey('plan-recompute'),
          icon: const Icon(Icons.auto_fix_high),
          label: Text(l10n.planRecomputeFrom),
          onPressed: () => _recompute(context, ref),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.planRecomputeFromHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Ask which day, then hand off to the shared reflow.
  ///
  /// The day sheet passes the day it is already showing; there is no such day
  /// here, so the reader is asked — in the reader's own calendar and through
  /// the same field every other date in the app is typed into (#32), rather than
  /// with a second `showDatePicker` that could only offer a Gregorian grid.
  Future<void> _recompute(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final mode = ref.read(settingsProvider).calendar;
    final navigator = Navigator.of(context);
    final today = Day.of(ref.read(clockProvider)());
    // **Read before the await, and null-checked.** The plan can be deleted from
    // the editor this screen links to, and a `!` here would be a throw on a
    // screen the user comes back to.
    final plan = ref.read(planByIdProvider(planId));
    if (plan == null) return;

    final from = await promptForDate(
      context,
      initial: today,
      reference: today,
      mode: mode,
      title: l10n.planRecomputeDayTitle,
      confirmLabel: l10n.plansSave,
      cancelLabel: l10n.plansCancel,
    );
    if (from == null || !navigator.mounted) return;
    await Reflow.from(navigator.context, ref, plan, from, mode);
  }
}

/// How far the plan has got.
class _Standing extends StatelessWidget {
  const _Standing({
    required this.standing,
    required this.position,
    required this.catalog,
  });

  final PlanStanding standing;
  final PlanPosition? position;
  final Catalog? catalog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.planStandingTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        // **A plan that names no sefer says so, rather than showing zero.** Zero
        // units done on a plan that covers nothing is not progress, and printing
        // it would be reporting a schedule as an endless plan with no work in it
        // — which is the mis-report this screen exists to avoid being the cause
        // of. Only the standing is replaced, never the rest of the screen: a
        // reflow is about what a day *asks for*, which a plan with no sefer
        // still asks for, so hiding the button here would take away the one thing
        // the user can usefully do.
        if (standing.isEmpty)
          Text(l10n.planStandingNone, style: theme.textTheme.bodyMedium)
        else ...[
          // **A fraction only where there is a total.** An endless plan reports a
          // bare count and no bar, because a bar needs a denominator and inventing
          // one for a plan with no end is the number this repository's rules
          // exist to stop — a bar silently under-reporting its own plan.
          if (standing.isFinite)
            LinearProgressIndicator(value: _fraction(standing)),
          const SizedBox(height: 8),
          Text(
            standing.isFinite
                ? l10n.planStandingProgress(standing.done, standing.total!)
                : l10n.planStandingCount(standing.done),
            style: theme.textTheme.bodyLarge,
          ),
          if (position != null) ...[
            const SizedBox(height: 4),
            Text(_whereOn(l10n, position!), style: theme.textTheme.bodySmall),
          ],
        ],
      ],
    );
  }

  /// The fraction, guarded: a total of zero would divide, and a `done` above a
  /// `total` (a sefer that grew under a finished plan) would exceed one and
  /// throw on the way to the bar.
  double? _fraction(PlanStanding s) {
    final total = s.total;
    if (total == null || total <= 0) return null;
    return (s.done / total).clamp(0.0, 1.0);
  }

  /// Which unit this plan is on, named through the shared node-and-unit heading
  /// so it reads the same as every other place a daf is named.
  String _whereOn(AppLocalizations l10n, PlanPosition p) {
    if (p.isComplete) return l10n.planStandingFinished;
    final unit = p.unitIndex;
    final node = p.unitNodeId == null ? null : catalog?.byId(p.unitNodeId!);
    if (unit == null || node == null) return l10n.planStandingFinished;
    return l10n.planStandingOn(nodeAndUnit(l10n, node, unit));
  }
}

/// How much the plan is actually doing per day, against what it asks.
class _Rate extends StatelessWidget {
  const _Rate({required this.standing, required this.mode});

  final PlanStanding standing;
  final CalendarMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final average = standing.averagePerDay;
    final recent = standing.recentPerDay;
    final since = standing.since;

    // Nothing to have a rate of. The standing above has already said why, and a
    // "0 a day" line under it would be a second, weaker version of the same
    // sentence.
    if (standing.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.planRateTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (average == null)
          Text(l10n.planRateNone, style: theme.textTheme.bodySmall)
        else ...[
          // **Both windows, each named with the days it covers.** The issue asks
          // whether to show a whole-plan average, a recent window, or both: a
          // whole-plan average hides a plan that started well and stopped, and a
          // recent window is noisy on a young plan. Each weakness is the other's
          // cure and this is the only screen in the app where they disagree, so
          // both are on it, each with the window that makes it honest.
          Text(
            l10n.planRateAverage(
              measuredPerDayText(average),
              DateDisplay.format(since!.midnight, mode),
            ),
            style: theme.textTheme.bodyLarge,
          ),
          if (recent != null)
            Text(
              l10n.planRateRecent(
                measuredPerDayText(recent),
                standing.recentDays,
              ),
              style: theme.textTheme.bodySmall,
            ),
          if (standing.askedPerDay != null)
            Text(
              l10n.planRateAsked(measuredPerDayText(standing.askedPerDay!)),
              style: theme.textTheme.bodySmall,
            ),
          // Said plainly, because the numbers above are two columns of figures
          // and the question the screen was opened for is a yes or no. Coloured
          // through the theme rather than a hard-coded red, so it follows the
          // app's own light/dark and error colours.
          if (standing.isBehind)
            Text(
              l10n.planRateBehind,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ],
    );
  }
}
