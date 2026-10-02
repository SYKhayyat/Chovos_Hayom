import '../../core/day.dart';
import '../../core/planner_dates.dart';
import '../entities/catalog.dart';
import '../entities/layer.dart';
import 'day_amount.dart';
import 'fold_log.dart';
import 'layer_roles.dart';
import 'learning_plan.dart';
import 'plan_run.dart';

/// Where one plan stands and how fast it is moving.
///
/// **Per plan, never summed.** A day routinely runs several — Daf Yomi *and*
/// seven blatt of a different masechta — and they fall behind independently, so
/// an aggregate would hide exactly the plan that is behind. That is the whole
/// reason this is a value type per plan rather than a row on a report.
///
/// **A fold reader, like [PlanRunProgress] beside it.** Everything here is read
/// out of the log and never stored: asking "am I keeping up" must not be a
/// number that can disagree with what was actually learned, and a stored rate is
/// a number that can.
class PlanStanding {
  const PlanStanding({
    required this.done,
    required this.total,
    required this.activeDays,
    required this.askedPerDay,
    required this.averagePerDay,
    required this.recentPerDay,
    required this.recentDays,
    required this.since,
    this.coversNothing = false,
  });

  /// A plan that names nothing to work through: no sefer in its sequence and no
  /// assignment target either.
  const PlanStanding.empty()
    : done = 0,
      total = null,
      activeDays = 0,
      askedPerDay = null,
      averagePerDay = null,
      recentPerDay = null,
      recentDays = 0,
      since = null,
      coversNothing = true;

  /// Units done by the day asked about. Never a fraction on its own — see [total].
  final int done;

  /// How many units the plan covers, or **null when it has no total**: a range
  /// that wraps, one with no end, or nothing to cover at all.
  ///
  /// Null and not zero, and the difference is the whole point: zero would read
  /// as "there is nothing to do", which is a different statement from "there is
  /// no end to count to".
  final int? total;

  /// The days in the averaging window that the plan actually asked for
  /// something on — the denominator of every rate here.
  ///
  /// **Active days, not calendar days, and that is the rule that keeps the rate
  /// honest.** A plan that fires only on Shabbos and asks ten a Shabbos, kept up
  /// on perfectly, would average 10 ÷ 7 against an asked 10 — and the screen
  /// would say it was running at one seventh of the rate the user set. A
  /// deliberate day off counts in neither side: it asked for nothing, so there
  /// was nothing to fall behind on.
  final int activeDays;

  /// What the plan asked for, per active day, over the whole window.
  ///
  /// Averaged rather than read off `unitsPerDay`, so the weekday and date
  /// overrides land in it: a plan that asks 7 and 3 on Fridays is asked 5.9, and
  /// reporting 7 would make a light-Friday plan look behind for no reason.
  ///
  /// Null when the window holds no day the plan asked for anything on — which
  /// is a real state for a plan whose start date has arrived but whose rule does
  /// not fire until next month, and is not the same claim as asking for zero.
  final double? askedPerDay;

  /// What is actually being done, per active day, over the whole window.
  ///
  /// Null when there is no window to average over — a plan that started today,
  /// or has never been worked on.
  final double? averagePerDay;

  /// The same rate over the last [recentDays] days.
  final double? recentPerDay;

  /// How many days the recent figure actually spans. Fewer than the window on a
  /// young plan, which is the whole reason a recent window on its own is noisy.
  final int recentDays;

  /// The first day of the window runs from.
  final Day? since;

  /// Whether the plan names nothing to work through at all. See [isEmpty].
  final bool coversNothing;

  /// True when the plan names nothing to work through, so there is nothing here
  /// to report — and nothing for a screen to invent a number about.
  ///
  /// **Its own flag rather than inferred from [since] and [total].** Both are
  /// also null for a plan that *does* name a sefer and simply has not been worked
  /// on yet, and reading that as "names nothing" tells a user who has a perfectly
  /// good plan to go and add a sefer they already added. Those are three states —
  /// covers nothing, covers something, worked on none of it — and a screen needs
  /// to say a different thing about each.
  bool get isEmpty => coversNothing;

  /// True when the plan has an end, and so can be a fraction.
  bool get isFinite => total != null;

  /// Whether the plan has been finished.
  ///
  /// False for an endless plan even when every unit is currently marked done: it
  /// has no end, so there is nothing to have finished.
  bool get isComplete => total != null && done >= total!;

  /// Whether work is going in more slowly than the plan asks for.
  ///
  /// **The recent figure, not the whole-plan average**, because that is the one
  /// that answers the question the screen is opened for: a plan that started
  /// well and stopped is behind, and a whole-plan average would average the
  /// good start into the answer.
  ///
  /// False when there is no rate to judge — a fresh plan is not behind, it has
  /// not started, and neither is one whose window held no active day.
  bool get isBehind {
    final rate = recentPerDay;
    final asked = askedPerDay;
    if (rate == null || asked == null || asked <= 0) return false;
    return rate < asked;
  }

  @override
  bool operator ==(Object other) =>
      other is PlanStanding &&
      other.done == done &&
      other.total == total &&
      other.activeDays == activeDays &&
      other.askedPerDay == askedPerDay &&
      other.averagePerDay == averagePerDay &&
      other.recentPerDay == recentPerDay &&
      other.recentDays == recentDays &&
      other.since == since &&
      other.coversNothing == coversNothing;

  @override
  int get hashCode => Object.hash(
    done,
    total,
    activeDays,
    askedPerDay,
    averagePerDay,
    recentPerDay,
    recentDays,
    since,
    coversNothing,
  );

  @override
  String toString() =>
      'PlanStanding(done: $done of ${total ?? 'no total'}, '
      'average: $averagePerDay, recent: $recentPerDay, asked: $askedPerDay)';
}

/// How fast a plan is actually moving, against how fast it says it should.
///
/// **The rate is the answer to "am I keeping up?", and the calendar cannot give
/// it.** The calendar says what a day asks for; only the log says what happened,
/// and "a plan asking 7 blatt a day that you have been doing 3 on is a plan
/// about to fall behind" is a comparison between those two and nothing else shows
/// it.
class PlanRate {
  const PlanRate._();

  /// How far back the recent rate looks, in days.
  ///
  /// **A week, and both figures are reported rather than one.** A whole-plan
  /// average hides a plan that started well and stopped; a recent window is
  /// noisy on a plan three days old. Showing one of them picks a side of that
  /// trade, and this is the only place in the app where the two answers
  /// disagree — so the screen shows both, each named with the window it covers,
  /// and the user reads the one that answers their question.
  static const recentWindow = 7;

  /// Where [plan] stands as of [asOf], and how fast it is moving.
  ///
  /// [asOf] is the day being asked about and is **excluded from the window**,
  /// so the average runs over whole days rather than over one that is still
  /// happening. This is the opposite of what [Recompute.shortfallAsOf] does with
  /// the same day, and deliberately so: a shortfall is asked for on the day it
  /// happens and wants that day's work counted, whereas a *rate* averaged over a
  /// partly-finished day is depressed by work not yet done rather than by work
  /// not done — a plan read as 3 a day because this morning has not happened
  /// yet is a number nobody can act on.
  ///
  /// The window starts at the plan's own [LearningPlan.startDay] when it has
  /// one. When it has none — which means "today" — there is no start to measure
  /// from, and the first day the plan has any work in it is used instead, because
  /// a rate averaged over one unfinished day is not a rate.
  static PlanStanding of(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day asOf, {
    LayerRoles? layers,
    int recentDays = recentWindow,
  }) {
    final done = PlanRunProgress.doneUnits(
      plan,
      catalog,
      fold,
      asOf,
      layers: layers,
    );
    final total = PlanRunProgress.totalUnits(plan, catalog);
    // **Nothing to measure, and said so rather than reported as zero.**
    // `totalUnits` is null for three different reasons — wraps, no end, and
    // names-nothing — and only the ranges can tell them apart. Reading the first
    // as the second is how a schedule with no sefer in it would be reported as
    // an infinite plan with nothing done, which is a lie about a real plan.
    if (PlanRange.rangesOf(plan, catalog).every((r) => r == null)) {
      return const PlanStanding.empty();
    }

    final since = _since(plan, catalog, fold, asOf, layers);
    if (since == null) {
      // **The plan covers something and has had none of it worked on** — a
      // different state from covering nothing, and told differently. Returning
      // the empty standing here would tell a user who set a plan up yesterday
      // to go and add a sefer they already added. The counts are real and are
      // kept; only the rates are missing, because there is no window to average.
      return PlanStanding(
        done: done,
        total: total,
        activeDays: 0,
        askedPerDay: null,
        averagePerDay: null,
        recentPerDay: null,
        recentDays: 0,
        since: null,
      );
    }

    final recentFrom = asOf - recentDays;
    final recentSince = recentFrom < since ? since : recentFrom;

    final asked = _askedOver(plan, since, asOf);
    final recent = _askedOver(plan, recentSince, asOf);

    return PlanStanding(
      done: done,
      total: total,
      activeDays: asked.days,
      askedPerDay: _rate(asked.units, asked.days),
      averagePerDay: _rate(
        _unitDays(plan, catalog, fold, since, asOf, layers),
        asked.days,
      ),
      recentPerDay: _rate(
        _unitDays(plan, catalog, fold, recentSince, asOf, layers),
        recent.days,
      ),
      recentDays: recent.days,
      since: since,
    );
  }

  /// The first day of the window, or null when there is none to speak of.
  ///
  /// A [LearningPlan.startDay] in the future means the plan has not started, so
  /// there is nothing to average: a plan asking to begin next month is not
  /// running slowly, it is not running.
  static Day? _since(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day asOf,
    LayerRoles? layers,
  ) {
    final start = plan.startDay;
    if (start != null) return start < asOf ? start : null;
    return _firstDone(plan, catalog, fold, asOf, layers);
  }

  /// The first day before [asOf] on which any unit of [plan] was done.
  ///
  /// Null when nothing was, which is a plan with no work in its log yet — and
  /// not something to substitute a today-shaped zero for.
  static Day? _firstDone(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day asOf,
    LayerRoles? layers,
  ) {
    Day? earliest;
    for (final (node, unit) in _walk(plan, catalog)) {
      final days = fold.doneCountByNode[node]?[unit];
      if (days == null) continue;
      for (final day in days.keys) {
        if (day >= asOf) continue;
        if (earliest == null || day < earliest) earliest = day;
      }
    }
    return earliest;
  }

  /// How many unit-days the plan covers in `from..until`.
  ///
  /// **A unit counts once per day it was done, however many times it was ticked
  /// that day.** Three ticks of one daf is one daf's work, and a rate that
  /// counted them three times would let a duplicate tap make a plan look as
  /// though it were flying. Re-learning on a *later* day does count again, and
  /// has to: an endless plan's whole progress is re-learning, so "first time
  /// only" would decay the rate to zero on precisely the plans that most need it.
  ///
  /// **Only while the unit still counts as learned.** A unit the user has
  /// un-ticked has nothing on it to have been done, the same rule
  /// [PlanRunProgress.doneUnits] counts by — so the rate and the standing cannot
  /// disagree about which units are done.
  static int _unitDays(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day from,
    Day until,
    LayerRoles? layers,
  ) {
    var count = 0;
    for (final (node, unit) in _walk(plan, catalog)) {
      if (!_isDoneNow(fold, node, unit, layers)) continue;
      final days = fold.doneCountByNode[node]?[unit];
      if (days == null) continue;
      for (final day in days.keys) {
        if (day >= from && day < until) count++;
      }
    }
    return count;
  }

  /// The days in `from..until` the plan asked for something on, and what it asked
  /// for in total.
  ///
  /// Both halves from one walk, because a denominator counted separately from a
  /// numerator is a rate that can be divided by a different number than it was
  /// measured against.
  static ({int days, int units}) _askedOver(
    LearningPlan plan,
    Day from,
    Day until,
  ) {
    var days = 0;
    var units = 0;
    for (var d = from; d < until; d += 1) {
      final info = dayInfoFor(d);
      // **A day that does not fire is not a day off.** The plan had nothing to
      // do there, which is a different statement from being on that day and
      // asking for nothing — and only the second is a day that could have been
      // fallen behind on.
      if (PlannerSchedule.assignmentsOn(plan, info).isEmpty) continue;
      final amount = DayAmount.of(plan, info);
      if (amount <= 0) continue;
      days++;
      units += amount;
    }
    return (days: days, units: units);
  }

  /// Units per active day, or null when there were no active days.
  ///
  /// Null rather than zero for the empty window, because "you have done nothing
  /// per day" and "there were no days to do anything on" are different claims
  /// and the screen says the second one.
  static double? _rate(int units, int days) => days <= 0 ? null : units / days;

  /// Every unit of [plan] — its sequence's ranges, or its assignment targets'
  /// when it has no sequence, per [PlanRange.rangesOf].
  static Iterable<(String, int)> _walk(
    LearningPlan plan,
    Catalog catalog,
  ) sync* {
    for (final range in PlanRange.rangesOf(plan, catalog)) {
      if (range == null) continue;
      for (final (node, unit) in range.walk(catalog)) {
        yield (node.id, unit);
      }
    }
  }

  static bool _isDoneNow(
    LogFold fold,
    String nodeId,
    int unit,
    LayerRoles? layers,
  ) => _requiredFor(
    layers,
    nodeId,
  ).every(fold.completedLayers(nodeId, unit).contains);

  static Set<String> _requiredFor(LayerRoles? layers, String nodeId) =>
      layers?.requiredFor(nodeId) ?? {mainLayerId};
}
