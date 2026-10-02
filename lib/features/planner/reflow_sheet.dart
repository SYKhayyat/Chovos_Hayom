import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/plans.dart';
import '../../application/providers.dart';
import '../../core/calendar.dart';
import '../../core/day.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/usecases/fold_log.dart';
import '../../domain/usecases/learning_plan.dart';
import '../../domain/usecases/recompute.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';

/// Recompute — reflow one plan's shortfall over the days that follow.
///
/// **One implementation, two entry points** (the calendar's day sheet and the
/// plan screen). The whole reason this file exists rather than two copies is
/// that "keep the amounts" and "spread them over three days" are decisions a user
/// makes from whichever screen they happen to be on, and two copies of the sheet
/// would be two chances to spread a remainder into a rounding error on one of
/// them. [Recompute] itself was always shared; only the sheet was not.
abstract final class Reflow {
  const Reflow._();

  /// Ask what to do with [plan]'s shortfall as of [from], and apply the answer.
  ///
  /// Reads the log to measure the shortfall and writes **only** the plan: a
  /// reflow is a claim about the schedule, never about what was learned, and
  /// there is no path from here to a repository.
  ///
  /// [mode] only affects how a date is written back to the user, and [from] is
  /// the day being recomputed — the day sheet passes the day it is already
  /// showing, the plan screen asks for one.
  static Future<void> from(
    BuildContext context,
    WidgetRef ref,
    LearningPlan plan,
    Day from,
    CalendarMode mode,
  ) async {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.read(mergedCatalogProvider).asData?.value;
    final fold = ref.read(foldProvider).asData?.value;
    if (catalog == null || fold == null) return;

    final choice = await ask(context, plan, catalog, fold, from);
    if (choice == null || !context.mounted) return;

    final result = switch (choice) {
      ReflowKeep() => Recompute.keepAsIs(plan, catalog, fold, from),
      ReflowSpreadChoice(:final spread) => Recompute.spread(
        plan,
        catalog,
        fold,
        from,
        spread: spread,
      ),
    };

    final navigator = Navigator.of(context);
    if (!navigator.mounted) return;
    await guarded(
      navigator.context,
      ref,
      () => ref.read(plansConfigProvider.notifier).save(result.plan),
      what: message(l10n, result, mode),
    );
  }

  /// The sheet, returning what was chosen. Nothing is applied until it is
  /// answered.
  static Future<ReflowChoice?> ask(
    BuildContext context,
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day from,
  ) {
    final l10n = AppLocalizations.of(context);
    final finish = plan.pacing.finishDay;
    return showModalBottomSheet<ReflowChoice>(
      context: context,
      builder: (sheet) => ReflowSheet(
        l10n: l10n,
        shortfall: Recompute.shortfallAsOf(plan, catalog, fold, from),
        hasEnd: finish != null,
        finishBeforeStart: finish != null && finish < from,
      ),
    );
  }

  /// What the reflow did, in one sentence.
  static String message(
    AppLocalizations l10n,
    ReflowResult result,
    CalendarMode mode,
  ) {
    if (result.spreadOver == 0) {
      return l10n.plansRecomputeKept(result.shortfall);
    }
    final spread = l10n.plansRecomputeDone(result.shortfall, result.spreadOver);
    if (!result.finishDayMoved || result.newFinishDay == null) return spread;
    // **The date is named when it moves.** A siyum that slid without saying so is
    // one the user stops believing, and they would find out on the day.
    return '$spread '
        '${l10n.plansRecomputeFinishMoved(DateDisplay.format(result.newFinishDay!.midnight, mode))}';
  }
}

/// Which mode the reflow sheet is offering. Two, and the issue argues why there
/// are not three: "make it finish by a different date" is editing the plan, now
/// that a plan is a real entity (#41).
sealed class ReflowChoice {
  const ReflowChoice();
}

/// Mode 1 — leave every day as it is. The shortfall stands where it is.
class ReflowKeep extends ReflowChoice {
  const ReflowKeep();
}

/// Mode 2 — spread the shortfall over the days that follow.
class ReflowSpreadChoice extends ReflowChoice {
  const ReflowSpreadChoice(this.spread);

  final ReflowSpread spread;
}

/// The reflow sheet.
///
/// **Asks the two questions in the order they are answered**: what to do, and
/// then over how far. The "how far" options are not all always available —
/// "up to the plan's end" is meaningless on a plan with no end, and it says so
/// rather than appearing and doing nothing.
class ReflowSheet extends StatefulWidget {
  const ReflowSheet({
    super.key,
    required this.l10n,
    required this.shortfall,
    required this.hasEnd,
    required this.finishBeforeStart,
  });

  final AppLocalizations l10n;

  /// Units outstanding as of the day being recomputed from. Shown first, because
  /// the amount is the reason anyone opened this.
  final int shortfall;

  final bool hasEnd;

  /// The finish date is already behind the day being recomputed from, so
  /// "spread up to the end" has no days in it.
  final bool finishBeforeStart;

  @override
  State<ReflowSheet> createState() => _ReflowSheetState();
}

class _ReflowSheetState extends State<ReflowSheet> {
  bool _spread = true;
  int _days = 3;
  bool _spreadAll = false;
  bool _spreadUntilEnd = false;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.plansRecompute,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.plansRecomputeKept(widget.shortfall),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (widget.shortfall == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.plansRecomputeNothingOwed,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          RadioGroup<bool>(
            groupValue: _spread,
            onChanged: (v) => setState(() => _spread = v ?? _spread),
            child: Column(
              children: [
                RadioListTile<bool>(
                  key: const ValueKey('recompute-keep'),
                  contentPadding: EdgeInsets.zero,
                  value: false,
                  title: Text(l10n.plansRecomputeKeep),
                  subtitle: Text(l10n.plansRecomputeKeepHelp),
                ),
                RadioListTile<bool>(
                  key: const ValueKey('recompute-spread'),
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  title: Text(l10n.plansRecomputeSpread),
                  subtitle: Text(l10n.plansRecomputeSpreadHelp),
                ),
              ],
            ),
          ),
          if (_spread && widget.shortfall > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n.plansRecomputeOver,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            RadioGroup<_SpreadChoice>(
              groupValue: _current(),
              onChanged: (v) => setState(() => _applyChoice(v!)),
              child: Column(
                children: [
                  for (final n in const [3, 7, 14])
                    RadioListTile<_SpreadChoice>(
                      key: ValueKey('recompute-days-$n'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _SpreadChoice.days(n),
                      title: Text(l10n.plansRecomputeDays(n)),
                    ),
                  RadioListTile<_SpreadChoice>(
                    key: const ValueKey('recompute-all'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: const _SpreadChoice.all(),
                    title: Text(l10n.plansRecomputeAll),
                  ),
                  if (widget.hasEnd && !widget.finishBeforeStart)
                    RadioListTile<_SpreadChoice>(
                      key: const ValueKey('recompute-until-end'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: const _SpreadChoice.untilEnd(),
                      title: Text(l10n.plansRecomputeUntilEnd),
                    ),
                ],
              ),
            ),
            if (!widget.hasEnd)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.plansRecomputeNoEnd,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.plansCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('recompute-apply'),
                  onPressed: () => Navigator.of(context).pop(
                    _spread
                        ? ReflowSpreadChoice(_toSpread)
                        : const ReflowKeep(),
                  ),
                  child: Text(l10n.plansSave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The current choice, for the radio group's comparison and for the result.
  _SpreadChoice _current() => _spreadUntilEnd
      ? const _SpreadChoice.untilEnd()
      : _spreadAll
      ? const _SpreadChoice.all()
      : _SpreadChoice.days(_days);

  void _applyChoice(_SpreadChoice choice) => setState(() {
    _days = choice.days ?? _days;
    _spreadAll = choice.all;
    _spreadUntilEnd = choice.untilEnd;
  });

  /// The domain value the sheet's choice becomes.
  ReflowSpread get _toSpread {
    if (_spreadUntilEnd) return ReflowSpread.untilEnd;
    if (_spreadAll) return ReflowSpread.all;
    return ReflowSpread.days(_days);
  }
}

/// A choice of how far to spread. A tiny class rather than an enum so "N days"
/// can be a value the radio group compares.
class _SpreadChoice {
  const _SpreadChoice(this.days, {this.all = false, this.untilEnd = false});

  const _SpreadChoice.days(int n) : this(n);

  const _SpreadChoice.all() : this(null, all: true);

  const _SpreadChoice.untilEnd() : this(null, untilEnd: true);

  final int? days;
  final bool all;
  final bool untilEnd;

  @override
  bool operator ==(Object other) =>
      other is _SpreadChoice &&
      other.days == days &&
      other.all == all &&
      other.untilEnd == untilEnd;

  @override
  int get hashCode => Object.hash(days, all, untilEnd);
}
