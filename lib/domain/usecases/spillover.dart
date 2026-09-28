import '../../core/day.dart';
import 'day_amount.dart';
import 'learning_plan.dart';
import 'recurrence.dart';

/// One day of a plan's schedule, after spillover has been applied.
class ScheduledDay {
  const ScheduledDay({
    required this.day,
    required this.base,
    required this.amount,
    required this.owedEntering,
    required this.owedLeaving,
  });

  final Day day;

  /// What [DayAmount] asks for on this day, before any shortfall is folded in.
  final int base;

  /// What the day actually calls for once [owedEntering] is taken into account.
  /// Equals [base] for every mode except `catchUp`.
  final int amount;

  /// Units still owed as this day began.
  final int owedEntering;

  /// Units still owed once this day's work is done. Never negative: over-delivery
  /// on one day is not a credit against a later one, because the plan says how
  /// much that day asks for and a day cannot be un-asked.
  final int owedLeaving;

  @override
  bool operator ==(Object other) =>
      other is ScheduledDay &&
      other.day == day &&
      other.base == base &&
      other.amount == amount &&
      other.owedEntering == owedEntering &&
      other.owedLeaving == owedLeaving;

  @override
  int get hashCode => Object.hash(day, base, amount, owedEntering, owedLeaving);

  @override
  String toString() => 'ScheduledDay($day, base: $base, amount: $amount, '
      'owed: $owedEntering -> $owedLeaving)';
}

/// A plan's forward schedule: what each day asks for once shortfalls are
/// accounted for, and how far behind that leaves the plan.
///
/// **This is the shortfall, not the progress.** What is owed is a comparison
/// between what the plan asked for and what the log says was learned, and that
/// comparison is what spillover has an opinion about. Deciding when the plan is
/// *finished* is a different question — it needs the plan's total, not its
/// deficit — and lives in the position/siyum projection, which must agree with
/// this walk rather than duplicate it.
///
/// **The log is an input, never a thing this writes.** [doneOn] reports units
/// actually learned; the outstanding balance is derived by comparing it against
/// what the plan asked for. Nothing here touches the event log, so a schedule can
/// be re-projected as many times as the user wants without leaving a trace.
class PlanSchedule {
  const PlanSchedule._();

  /// What [mode] asks for on a day, given [owed] units carried into it.
  ///
  /// `ignore` and `slide` return [base] unchanged, and that is the whole
  /// difference between them: `slide` puts the shortfall somewhere else
  /// ([lagDays] below), `ignore` puts it nowhere. Only `catchUp` grows the day.
  static int amountFor({
    required SpilloverMode mode,
    required int base,
    required int owed,
  }) =>
      switch (mode) {
        SpilloverMode.catchUp => base + owed,
        SpilloverMode.ignore || SpilloverMode.slide => base,
      };

  /// How many days behind schedule [owed] units leaves the plan.
  ///
  /// The unit a day absorbs is [unitsPerDay], so a shortfall of `owed` is
  /// `ceil(owed / unitsPerDay)` days of delay. Zero when there is nothing owed,
  /// and zero when nothing is being learned — with no rate there is no lag to
  /// express, and inventing one would slide a plan that is not behind at all.
  static int lagDays({
    required SpilloverMode mode,
    required int owed,
    required double unitsPerDay,
  }) {
    if (mode != SpilloverMode.slide) return 0;
    if (owed <= 0 || unitsPerDay <= 0) return 0;
    return (owed / unitsPerDay).ceil();
  }

  /// Walks `from..to` inclusive and returns what each day calls for.
  ///
  /// [owedAtStart] is the balance entering [from] and [doneOn] reports what was
  /// actually learned on a given day, so the walk is the only place the log is
  /// read. Days are generated on demand for the window asked, never
  /// materialised past it.
  static List<ScheduledDay> walk(
    LearningPlan plan, {
    required DayInfo Function(Day) info,
    required Day from,
    required Day to,
    required int owedAtStart,
    required int Function(Day day) doneOn,
  }) {
    final out = <ScheduledDay>[];
    var owed = owedAtStart < 0 ? 0 : owedAtStart;
    for (var day = from; day <= to; day += 1) {
      final base = DayAmount.of(plan, info(day));
      final amount = amountFor(
        mode: plan.spillover,
        base: base,
        owed: owed,
      );
      final done = doneOn(day);
      // **Which of these two is right depends on the mode, and getting it wrong
      // is not a rounding error — it compounds.** In `catchUp` the day already
      // asked for the backlog, so the old debt was *spent* getting to this day
      // and the shortfall is only what today asked minus what was done. Adding
      // `owed` again double-counts it, and the balance then doubles every day:
      // 10, 20, 40, 80, 160 for a plan that never learned anything. Every other
      // mode did *not* ask for the backlog, so that debt persists untouched and
      // today's own shortfall is added on top: a straight 10, 20, 30.
      final shortfall = plan.spillover == SpilloverMode.catchUp
          ? amount - done
          : owed + amount - done;
      final leaving = shortfall.clamp(0, 1 << 62);
      out.add(ScheduledDay(
        day: day,
        base: base,
        amount: amount,
        owedEntering: owed,
        owedLeaving: leaving,
      ));
      owed = leaving;
    }
    return out;
  }

  /// The day the last of [remaining] units is projected to be learned, walking
  /// forward from [from], or null if it does not land inside `from..to`.
  ///
  /// This is the siyum date, and it is **derived every time it is asked and never
  /// stored**. The requester was explicit that it depends on exactly one thing —
  /// when everything has been finished — and a cached date would be a second
  /// answer to that question that could disagree with the log it came from. Change
  /// the pace, add a day off, move a date override, and the answer changes; there
  /// is nothing to invalidate because there is nothing held.
  ///
  /// Going forward nothing has been missed yet, so [walk]'s balance starts empty
  /// and the day's amount is its base. [owedAtStart] carries a shortfall already
  /// outstanding from the past, which is how #25's spillover reaches this
  /// projection instead of being a parallel calculation.
  static Day? projectedFinishDay(
    LearningPlan plan, {
    required int remaining,
    required DayInfo Function(Day) info,
    required Day from,
    required Day to,
    int owedAtStart = 0,
  }) {
    if (remaining <= 0) return from;
    var covered = 0;
    for (final day in walk(
      plan,
      info: info,
      from: from,
      to: to,
      owedAtStart: owedAtStart,
      doneOn: _none,
    )) {
      covered += day.amount;
      if (covered >= remaining) return day.day;
    }
    return null;
  }
}

int _none(Day day) => 0;
