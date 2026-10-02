import '../../core/day.dart';
import '../../core/planner_dates.dart';
import '../entities/catalog.dart';
import 'day_amount.dart';
import 'fold_log.dart';
import 'learning_plan.dart';
import 'plan_run.dart';

/// How far the shortfall is spread.
///
/// **Three ways to say it, and the third is a different question rather than a
/// shorter answer.** A plan with an end can spread "up to its end"; a plan with
/// no end is infinite, so there is no end to spread into and the only remaining
/// answers are a number or "all". [untilEnd] on an endless plan therefore
/// behaves as [all] — the same question, already answered.
class ReflowSpread {
  const ReflowSpread._(this._kind, this.days);

  final _ReflowKind _kind;

  /// The number of days, for [ReflowSpread.days]; null otherwise.
  final int? days;

  /// Spread over the next [n] days.
  const ReflowSpread.days(int n) : this._(_ReflowKind.days, n);

  /// Spread over every day that follows, as far as the plan runs.
  static const all = ReflowSpread._(_ReflowKind.all, null);

  /// Spread up to the plan's end — which an endless plan does not have, in which
  /// case this is [all].
  static const untilEnd = ReflowSpread._(_ReflowKind.untilEnd, null);
}

enum _ReflowKind { days, all, untilEnd }

/// What a reflow did, and what the screen needs to report it.
///
/// **The finish date travels with the result rather than being derived again by
/// the caller**, because "did it move" and "to when" are one fact and a screen
/// that recomputes it can disagree with the plan it just wrote.
class ReflowResult {
  const ReflowResult({
    required this.plan,
    required this.shortfall,
    required this.spreadOver,
    this.newFinishDay,
    this.finishDayMoved = false,
  });

  /// The plan as it should now be, or the same plan when nothing was owed.
  final LearningPlan plan;

  /// Units the plan asked for and did not get, as of the chosen day.
  final int shortfall;

  /// How many days absorbed the shortfall. Zero when nothing was spread.
  final int spreadOver;

  /// The plan's finish date after the reflow, whether or not it moved — so a
  /// screen can say "still {that date}" rather than showing nothing.
  final Day? newFinishDay;

  /// Whether the finish date was pushed. The user is told when it is, because a
  /// siyum date that moved quietly is a date they stop believing.
  final bool finishDayMoved;
}

/// Reflow: spread one plan's shortfall over the days that follow.
///
/// **It exists because reflow was inexpressible.** A day could be overridden
/// individually, but "this plan now runs three more days" was not a statement
/// the model could hold — a plan was a recurrence rule over independent days
/// with no end to move (#41). Writing a date override per day is what this does,
/// and it is inert with respect to everything else: `+` and `−` (#43) change one
/// day on purpose, and this changes many on purpose.
///
/// **Three promises, and all three are structural rather than checked. There is
/// no repository here to write to, so no event can be written; the signature
/// takes one plan and returns one plan, so no other plan can be touched; and the
/// forward walk from [from] cannot reach a day already past.**
class Recompute {
  const Recompute._();

  /// How many days ahead a reflow is willing to write, as a backstop.
  ///
  /// "All" is unbounded by definition, and a plan with an end is bounded by it,
  /// so this only bites on a plan that is neither: finite in every sense and
  /// still open-ended. A thousand days is far past any real plan's length and
  /// exists so a malformed one cannot produce a million date overrides.
  static const _horizon = 1000;

  /// Mode 1: leave every day's target as it is. The shortfall stands where it is.
  ///
  /// **A no-op that still measures.** The screen shows the amount owed, because
  /// "you are 3 behind and here is why" is the reason to look, and the answer
  /// being "I know" is a legitimate one.
  static ReflowResult keepAsIs(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day from,
  ) => ReflowResult(
    plan: plan,
    shortfall: shortfallAsOf(plan, catalog, fold, from),
    spreadOver: 0,
    newFinishDay: plan.pacing.finishDay,
  );

  /// Mode 2: spread [spread]'s shortfall over the days that follow.
  ///
  /// **Evenly, with the remainder going to the earliest days.** A 5-unit
  /// shortfall over 2 days is 3 then 2, not 2 then 2 — rounding that drops the
  /// remainder is how a reflow quietly loses work, and the test that pins it is
  /// the one that adds the days back up.
  ///
  /// Rest days are **skipped, not given work**. A day off is an amount of 0;
  /// spreading onto it would either override the rest or silently swallow a
  /// unit, and skipping is the only one of the three that keeps the shortfall
  /// whole.
  static ReflowResult spread(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day from, {
    required ReflowSpread spread,
  }) {
    final owed = shortfallAsOf(plan, catalog, fold, from);
    if (owed <= 0) {
      // Nothing owed, nothing written. Not a spread of 0 across some days —
      // that would put date overrides on days that never had any, and a plan
      // that looks reflowed when it was not is a lie about its own history.
      return ReflowResult(
        plan: plan,
        shortfall: 0,
        spreadOver: 0,
        newFinishDay: plan.pacing.finishDay,
      );
    }

    final window = _window(plan, spread, from);
    if (window.isEmpty) {
      return ReflowResult(
        plan: plan,
        shortfall: owed,
        spreadOver: 0,
        newFinishDay: plan.pacing.finishDay,
      );
    }

    final per = owed ~/ window.length;
    var remainder = owed % window.length;
    final amounts = <Day, int>{...plan.dateAmounts};
    for (final day in window) {
      final extra = per + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;
      if (extra <= 0) continue;
      amounts[day] = DayAmount.of(plan, dayInfoFor(day)) + extra;
    }

    final last = window.last;
    final finish = plan.pacing.finishDay;
    var moved = false;
    var newFinish = finish;
    if (finish != null && last > finish) {
      // **The owner: everything is customizable**, so a reflow that could not
      // honour the plan's own constraint would not be a reflow. The date moves
      // to where the work now lands, and `finishDayMoved` makes the screen say
      // so — a siyum that moved quietly is one the user stops believing.
      newFinish = last;
      moved = true;
    }

    return ReflowResult(
      plan: _withPacing(plan, amounts, newFinish),
      shortfall: owed,
      spreadOver: window.length,
      newFinishDay: newFinish,
      finishDayMoved: moved,
    );
  }

  /// Units [plan] asked for by [asOf] and did not get.
  ///
  /// Read from the same fold and the same range-aware rules as everything else,
  /// so "short" here means the same as "owed" on the plan screen. A plan with no
  /// end has no total, but a **shortfall is still a real number** — it is what is
  /// missing so far, which is not the same question as how much there is.
  ///
  /// **Measured up to the day *after* [asOf], not up to [asOf].** Every count in
  /// this codebase is "done **by** the day" — a unit learned *on* it is not yet
  /// done, which is what stops a plan reporting itself finished on the day it
  /// finishes. A shortfall measured the same way would ignore the very first
  /// day's work, and the day you are recomputing from is the one whose work you
  /// most want counted. So: the asked amount runs to [asOf] inclusive, the done
  /// count to the following day, and the two meet honestly.
  static int shortfallAsOf(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day asOf, {
    Day? from,
  }) {
    final done = PlanRunProgress.doneUnits(plan, catalog, fold, asOf + 1);
    final asked = _askedBy(plan, asOf, from ?? plan.startDay ?? asOf);
    final owed = asked - done;
    return owed < 0 ? 0 : owed;
  }

  /// What the plan has asked for over `from..asOf`, inclusive.
  ///
  /// **From the plan's own start, not from a fixed floor.** The plan knows when
  /// it began — [LearningPlan.startDay], or the first day the log records — and
  /// walking back from "now" instead would ask about every day since the epoch,
  /// which is both wrong and slow: the first version of this summed 36,500 days
  /// to answer "how far behind am I" and reported a shortfall of 182,505.
  static int _askedBy(LearningPlan plan, Day asOf, Day from) {
    var total = 0;
    for (var d = from; d <= asOf; d += 1) {
      total += DayAmount.of(plan, dayInfoFor(d));
    }
    return total;
  }

  /// The active days the shortfall is spread over, in order.
  ///
  /// Bounded three ways, all of them necessary: by how many the caller asked
  /// for, by the plan's finish date when there is one, and by [_horizon].
  static List<Day> _window(LearningPlan plan, ReflowSpread spread, Day from) {
    final wanted = switch (spread._kind) {
      _ReflowKind.days => spread.days ?? 0,
      _ReflowKind.all => _horizon,
      // An endless plan has no end to spread into, and "all" is the same
      // question with the answer already known.
      // Both unbounded here; `untilEnd` is bounded by the date in [_window],
      // which is where "as far as this plan runs" is actually a question about
      // the plan rather than about a number of days.
      _ReflowKind.untilEnd => _horizon,
    };
    if (wanted <= 0) return const [];

    // **The window is not capped at the finish date.** The first version capped
    // it there, which made the date *unable* to move: `all` stopped at the
    // finish, so the last day written was never past it and the "did it move"
    // answer was always no. Capping and then asking whether the work overran the
    // cap is a contradiction, and it silently turns "the date moves" into a
    // feature that can never fire.
    //
    // So the window runs as far as the spread asks, and the finish date follows
    // the work. That is the owner's ruling — everything is customizable, so a
    // reflow that could not honour the plan's own constraint would not be a
    // reflow — and it is why [ReflowSpread.untilEnd] and [ReflowSpread.all] now
    // differ only for a plan that has an end to reach.
    // `untilEnd` is bounded **as a count** by the plan's own end, which is the
    // question it asks — "spread it across the rest of this plan" — while
    // `all` is not, and is what pushes the finish date along. Both are needed:
    // one is "absorb the shortfall before the siyum", the other is "the work now
    // runs longer than the plan said", and they are different intentions.
    final finish = plan.pacing.finishDay;
    final bounded =
        spread._kind == _ReflowKind.untilEnd &&
        finish != null &&
        from <= finish;
    final out = <Day>[];
    for (var i = 0; out.length < wanted && i < _horizon; i++) {
      final day = from + i;
      if (bounded && day > finish) break;
      if (DayAmount.of(plan, dayInfoFor(day)) > 0) out.add(day);
    }
    return out;
  }

  static LearningPlan _withPacing(
    LearningPlan plan,
    Map<Day, int> amounts,
    Day? finish,
  ) {
    final base = plan.copyWithDateAmounts(amounts);
    if (finish == null) return base;
    return LearningPlan(
      id: base.id,
      name: base.name,
      assignments: base.assignments,
      overrides: base.overrides,
      displayCalendar: base.displayCalendar,
      unitsPerDay: base.unitsPerDay,
      weekdayAmounts: base.weekdayAmounts,
      dateAmounts: base.dateAmounts,
      spillover: base.spillover,
      items: base.items,
      flowsToNextItem: base.flowsToNextItem,
      startDay: base.startDay,
      pacing: FinishBy(finish),
    );
  }
}
