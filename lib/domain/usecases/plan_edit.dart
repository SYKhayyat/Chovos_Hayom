import '../../core/day.dart';
import 'learning_plan.dart';

/// The two planning commands on a day: `+` and `−`.
///
/// **These edit a plan and nothing else.** No event is written, and nothing after
/// [day] moves. That is the whole distinction from a tick (#42): a tick claims
/// something was learned, these say only what a day *asks for*. A day can ask
/// for eight units and have none of them done — a legitimate state, not a
/// failure — and a command that quietly reflowed the rest of the plan would be
/// making a second, unasked-for decision on the user's behalf.
///
/// Moving a **past** day is therefore the same operation as moving a future one.
/// "I did extra on Tuesday" is the ordinary case rather than an exotic one, and
/// it changes that date's target and nothing else. If the rest of the plan
/// should adjust, that is recompute (#44) and the user asks for it explicitly.
class PlanEdit {
  const PlanEdit._();

  /// [plan] with [units] **more** asked for on [day] than it asked before.
  ///
  /// Raises the day's own answer rather than replacing it, so "+ 1" on a day
  /// already asking for two makes it three, and "+ 1" on a day whose base is
  /// seven makes it eight rather than one. The value it raises from is the same
  /// precedence the calendar reads, so the command and the display cannot
  /// disagree about what is being changed.
  static LearningPlan addUnits(LearningPlan plan, Day day, int units) {
    final current =
        plan.dateAmounts[day] ??
        plan.weekdayAmounts[day.weekday] ??
        plan.unitsPerDay;
    return _setDay(plan, day, current + units);
  }

  /// [plan] with one fewer unit asked for on [day], never below zero.
  ///
  /// Asking for fewer units than the day already asks is a **limit, not an
  /// error**: the alternative is a command that throws because the user pressed
  /// it too often, which is the one thing a control on a phone should not do.
  static LearningPlan removeUnit(LearningPlan plan, Day day) {
    final current =
        plan.dateAmounts[day] ??
        // Not an explicit override, so the day's own answer is the base — and
        // removing from the base has to read it the same way the calendar does,
        // or the command and the display disagree about what it is removing.
        _baseFor(plan, day);
    return _setDay(plan, day, current - 1);
  }

  /// [plan] asking for exactly [amount] on [day], never below zero.
  ///
  /// The counterpart to [addUnits], which is a *delta*. Both exist because the
  /// two commands are different: `+` is "a bit more than it was" and `−` is "one
  /// less than it is", and routing the second through the first meant it added
  /// instead of subtracted — a test caught it, but only because the two were
  /// written separately.
  static LearningPlan _setDay(LearningPlan plan, Day day, int amount) => plan
      .copyWithDateAmounts({...plan.dateAmounts, day: amount < 0 ? 0 : amount});

  /// [plan] with **no answer at all** for [day].
  ///
  /// **Distinct from an amount of `0`, and the difference is the point.** A zero
  /// says the plan was on that day and asked for nothing — a scheduled rest, a
  /// deliberate `0`. Removing the plan says it had nothing to do there, which is
  /// what "taking Thursday off" means, and which is why the day has no entry
  /// afterwards. Collapsing the two would lose a statement the user is making.
  static LearningPlan removePlanFromDay(LearningPlan plan, Day day) {
    if (!plan.dateAmounts.containsKey(day)) return plan;
    return plan.copyWithDateAmounts({...plan.dateAmounts..remove(day)});
  }

  /// A brand-new plan for work done on a day that nothing scheduled.
  ///
  /// **A real plan, not a note.** The owner's ruling: adding to no plan is "as
  /// if there is a new tiny plan" — so it gets an id, a name, a chain and a
  /// recurrence rule, which means it appears in the plan list, can be edited,
  /// and — the reason it has to be a plan at all — **can be ticked**, because
  /// #42's ledger reads the plan and a day with no plan has no row to tick.
  ///
  /// [units] is set as the plan's own base amount *and* as the day's override,
  /// so the day asks for the work immediately and the plan would ask for it
  /// again on any other day. That second half is deliberate and slightly odd: a
  /// standalone add is about *one* day, and a plan that repeats forever is not
  /// what was asked for. The caller is expected to narrow the rule; what matters
  /// here is that the day is right and the plan is editable.
  static LearningPlan standalonePlan({
    required String nodeId,
    required String name,
    required Day day,
    required int units,
  }) {
    final base = units < 0 ? 0 : units;
    return LearningPlan(
      id: 'day-$day-${nodeId.hashCode.toUnsigned(32)}',
      name: name,
      unitsPerDay: base,
      pacing: AmountPerDay(base),
      assignments: const [],
      dateAmounts: {day: base},
      items: [PlanItem(id: 'i1', nodeId: nodeId)],
    );
  }

  /// What [plan] asks for on [day] when it has said nothing specific.
  ///
  /// The same precedence `DayAmount` uses, so this command and the calendar
  /// cannot disagree about which number is being changed.
  static int _baseFor(LearningPlan plan, Day day) {
    final override = plan.dateAmounts[day];
    if (override != null) return override;
    return plan.weekdayAmounts[day.weekday] ?? plan.unitsPerDay;
  }
}
