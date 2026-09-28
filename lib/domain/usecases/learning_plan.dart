import 'package:chovos_hayom/core/day.dart';

import 'recurrence.dart';
import '../../core/equality.dart';

/// One thing a plan schedules: a recurrence rule, and what it schedules when
/// it fires.
///
/// [targetNodeId] names the catalog node the assignment is about; the planner
/// does not yet say *which unit* of that node — the sequential fold that
/// answers "what unit is due" is a later phase. This phase is the *when*.
class PlanAssignment {
  const PlanAssignment({
    required this.id,
    required this.rule,
    this.targetNodeId,
    this.unitsPerFiring = 1,
    this.label,
  });

  final String id;
  final RecurrenceRule rule;

  /// Catalog node this assignment schedules learning of, if any.
  final String? targetNodeId;

  /// How many units a firing day calls for.
  final int unitsPerFiring;

  /// A human note (e.g. "after Shacharis"). Purely descriptive.
  final String? label;

  Map<String, dynamic> toJson() => {
        'id': id,
        'rule': rule.toJson(),
        if (targetNodeId != null) 'targetNodeId': targetNodeId,
        'unitsPerFiring': unitsPerFiring,
        if (label != null) 'label': label,
      };

  factory PlanAssignment.fromJson(Map<String, dynamic> json) {
    final units = (json['unitsPerFiring'] as num?)?.toInt() ?? 1;
    if (units < 1) {
      throw const FormatException('unitsPerFiring must be at least 1');
    }
    return PlanAssignment(
      id: json['id'] as String,
      rule: RecurrenceRule.fromJson(
          (json['rule'] as Map<dynamic, dynamic>).cast<String, dynamic>()),
      targetNodeId: json['targetNodeId'] as String?,
      unitsPerFiring: units,
      label: json['label'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlanAssignment &&
      other.id == id &&
      other.rule == rule &&
      other.targetNodeId == targetNodeId &&
      other.unitsPerFiring == unitsPerFiring &&
      other.label == label;

  @override
  int get hashCode => Object.hash(id, rule, targetNodeId, unitsPerFiring, label);
}

class PlanOverride {
  const PlanOverride({
    required this.assignmentId,
    required this.from,
    required this.to,
  });

  final String assignmentId;
  final Day from;
  final Day to;

  Map<String, dynamic> toJson() => {
        'assignmentId': assignmentId,
        'from': from.toString(),
        'to': to.toString(),
      };

  factory PlanOverride.fromJson(Map<String, dynamic> json) => PlanOverride(
        assignmentId: json['assignmentId'] as String,
        from: Day.of(DateTime.parse(json['from'] as String)),
        to: Day.of(DateTime.parse(json['to'] as String)),
      );

  @override
  bool operator ==(Object other) =>
      other is PlanOverride &&
      other.assignmentId == assignmentId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(assignmentId, from, to);
}

/// The plan half. A plan fires on a day when any assignment's rule matches;
/// overlapping assignments all fire.
/// One entry in a plan's ordered sequence of seferim — "Yoma, then Sukkah, then
/// Chagigah, then Moed".
///
/// **A sequence, not a set of [PlanAssignment]s.** An assignment says *when*
/// something fires and may overlap freely; an item says *what comes next*, and
/// the order is the whole point. Keeping them separate is what lets a plan say
/// "ten a day, daily" (the assignment) and "work through these four in this
/// order" (the items) without either overloading the other.
class PlanItem {
  const PlanItem({
    required this.id,
    required this.nodeId,
    this.label,
  });

  final String id;

  /// The catalog node this item works through. Stored by id so the sequence
  /// survives the node being renamed.
  final String nodeId;

  /// An optional display name for the step, when the catalog's is not what the
  /// user wants to read.
  final String? label;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nodeId': nodeId,
        if (label != null) 'label': label,
      };

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
        id: json['id'] as String,
        nodeId: json['nodeId'] as String,
        label: json['label'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is PlanItem &&
      other.id == id &&
      other.nodeId == nodeId &&
      other.label == label;

  @override
  int get hashCode => Object.hash(id, nodeId, label);
}

/// What a plan does about a day it did not finish.
///
/// The two active modes look like opposite policies and are really the same
/// question — *where does the shortfall go?* — answered in units or in days.
enum SpilloverMode {
  /// The schedule is a plan. A day that was not finished is simply not finished;
  /// nothing downstream moves. This is the default, and the only mode that needs
  /// no arithmetic at all.
  ignore,

  /// The uncompleted units roll into the next day, so the daily target grows
  /// until the backlog clears. The finish date stays where the plan said it would
  /// be; the cost is a day where you owe more than you planned.
  ///
  /// Right for a short plan — Chulljuna is two days long, and skipping one
  /// without also making it up means never finishing it.
  catchUp,

  /// The daily amount never grows, and the whole schedule slides later by the
  /// shortfall instead. The cost is a later finish date rather than a heavier
  /// day.
  ///
  /// Right for a fast plan — nobody wants a 14-daf Daf Yomi day because they
  /// missed a Thursday, and sliding the finish is the cheaper trade.
  slide,
}

class LearningPlan {
  const LearningPlan({
    required this.id,
    required this.name,
    this.assignments = const [],
    this.overrides = const [],
    this.displayCalendar = RuleCalendar.gregorian,
    this.unitsPerDay = 1,
    this.weekdayAmounts = const {},
    this.dateAmounts = const {},
    this.spillover = SpilloverMode.ignore,
    this.items = const [],
    this.flowsToNextItem = false,
  });

  final String id;
  final String name;
  final List<PlanAssignment> assignments;
  final List<PlanOverride> overrides;

  /// The calendar a plan's days are shown in by default. A rule may still
  /// declare its own (see [RecurrenceRule].calendar).
  final RuleCalendar displayCalendar;

  /// The plan's base daily target: how many units a plain firing day asks for.
  ///
  /// Distinct from [PlanAssignment.unitsPerFiring], which is what *one
  /// assignment* calls for. This is the plan-wide figure the calendar and the
  /// projection read, so a plan can state "ten a day" once and have every day
  /// answer that unless an override says otherwise.
  final int unitsPerDay;

  /// `DateTime.monday` (1) .. `DateTime.sunday` (7) -> amount, for **arbitrary
  /// subsets**: Tuesday alone, Tuesday *and* Thursday, Shabbos, any combination.
  /// Not just the weekday/Shabbos split, because a user who wants "lighter on
  /// Tuesdays" is the common case and a two-way flag cannot say it.
  ///
  /// A value of `0` is legal and means "nothing on this weekday".
  final Map<int, int> weekdayAmounts;

  /// A specific [Day] -> amount, for one-off differences: a holiday, a sick day,
  /// the second day of Rosh Hashanah, a doubled day.
  ///
  /// **This is also how a day off is expressed** — an amount of `0` for that
  /// date. There is deliberately no separate day-off flag: a flag and an amount
  /// would be two ways to say the same thing, and the two could disagree, leaving
  /// a day that is both "off" and "asking for units" with no way to tell which
  /// one won.
  final Map<Day, int> dateAmounts;

  /// What this plan does about a day it does not finish. See [SpilloverMode].
  final SpilloverMode spillover;

  /// The seferim this plan works through, in order. Empty means the plan has no
  /// sequence and the position is just "the assignment's target".
  final List<PlanItem> items;

  /// Whether finishing one item starts the next, or the plan stops there.
  ///
  /// Off by default: a plan that lists four seferim and is told to stop at the
  /// first is expressing a real intention (learn Yoma, then decide), and
  /// defaulting to flowing on would quietly discard it.
  final bool flowsToNextItem;


  bool get hasHebrewRules =>
      assignments.any((a) => a.rule.calendar == RuleCalendar.hebrew);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'displayCalendar': displayCalendar.name,
        'assignments': [for (final a in assignments) a.toJson()],
        'overrides': [for (final o in overrides) o.toJson()],
        'unitsPerDay': unitsPerDay,
        'spillover': spillover.name,
        if (items.isNotEmpty) 'items': [for (final i in items) i.toJson()],
        'flowsToNextItem': flowsToNextItem,
        if (weekdayAmounts.isNotEmpty)
          'weekdayAmounts': {
            for (final e in weekdayAmounts.entries) '${e.key}': e.value,
          },
        if (dateAmounts.isNotEmpty)
          'dateAmounts': {
            // Keyed by ISO `YYYY-MM-DD`, the same shape `PlanOverride` uses and
            // the only string form of a day that survives a round trip.
            for (final e in dateAmounts.entries) e.key.toString(): e.value,
          },
      };

  factory LearningPlan.fromJson(Map<String, dynamic> json) {
    final unitsPerDay = (json['unitsPerDay'] as num?)?.toInt() ?? 1;
    if (unitsPerDay < 0) {
      throw const FormatException('unitsPerDay must not be negative');
    }
    return LearningPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      displayCalendar: RuleCalendar.values.firstWhere(
        (c) => c.name == json['displayCalendar'],
        orElse: () => RuleCalendar.gregorian,
      ),
      assignments: [
        for (final a in (json['assignments'] as List<dynamic>? ?? const []))
          PlanAssignment.fromJson(
              (a as Map<dynamic, dynamic>).cast<String, dynamic>()),
      ],
      overrides: [
        for (final o in (json['overrides'] as List<dynamic>? ?? const []))
          PlanOverride.fromJson(
              (o as Map<dynamic, dynamic>).cast<String, dynamic>()),
      ],
      unitsPerDay: unitsPerDay,
      // An unknown name falls back to `ignore` rather than throwing: a plan
      // written by a newer build, or a hand-edited file, should still schedule.
      // Nothing about the plan's *dates* changes, only how a missed day is read,
      // and the one that changes nothing is the safe answer.
      spillover: SpilloverMode.values.firstWhere(
        (m) => m.name == json['spillover'],
        orElse: () => SpilloverMode.ignore,
      ),
      items: [
        for (final i in (json['items'] as List<dynamic>? ?? const []))
          PlanItem.fromJson((i as Map<dynamic, dynamic>).cast<String, dynamic>()),
      ],
      flowsToNextItem: json['flowsToNextItem'] == true,
      weekdayAmounts: _weekdayAmountsFrom(json['weekdayAmounts']),
      dateAmounts: _dateAmountsFrom(json['dateAmounts']),
    );
  }

  /// Weekday keys are validated rather than coerced. A stored `0` or `8` would
  /// otherwise be a silently-unreachable override — a setting the user believes
  /// is in force and that never fires, which is the failure mode this whole
  /// feature is most able to produce.
  static Map<int, int> _weekdayAmountsFrom(Object? raw) {
    if (raw == null) return const {};
    final out = <int, int>{};
    for (final entry in (raw as Map<dynamic, dynamic>).entries) {
      final weekday = int.parse(entry.key as String);
      if (weekday < DateTime.monday || weekday > DateTime.sunday) {
        throw FormatException('weekday must be 1..7, got $weekday');
      }
      out[weekday] = _amount(entry.value, 'weekday amount');
    }
    return out;
  }

  static Map<Day, int> _dateAmountsFrom(Object? raw) {
    if (raw == null) return const {};
    final out = <Day, int>{};
    for (final entry in (raw as Map<dynamic, dynamic>).entries) {
      out[Day.of(DateTime.parse(entry.key as String))] =
          _amount(entry.value, 'date amount');
    }
    return out;
  }

  static int _amount(Object? raw, String what) {
    final value = (raw as num).toInt();
    if (value < 0) throw FormatException('$what must not be negative');
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is LearningPlan &&
      other.id == id &&
      other.name == name &&
      other.displayCalendar == displayCalendar &&
      other.unitsPerDay == unitsPerDay &&
      other.spillover == spillover &&
      other.flowsToNextItem == flowsToNextItem &&
      _sameItems(items, other.items) &&
      mapEquals(other.weekdayAmounts, weekdayAmounts) &&
      mapEquals(other.dateAmounts, dateAmounts) &&
      _sameAssignments(assignments, other.assignments) &&
      _sameOverrides(overrides, other.overrides);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        displayCalendar,
        unitsPerDay,
        spillover,
        Object.hashAllUnordered(
          weekdayAmounts.entries.map((e) => Object.hash(e.key, e.value)),
        ),
        Object.hashAllUnordered(
          dateAmounts.entries.map((e) => Object.hash(e.key, e.value)),
        ),
        Object.hashAll(assignments),
        Object.hashAll(overrides),
      );

  static bool _sameAssignments(List<PlanAssignment> a, List<PlanAssignment> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameItems(List<PlanItem> a, List<PlanItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameOverrides(List<PlanOverride> a, List<PlanOverride> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The planner's answers: which days a plan fires on, and what fires on a day.
///
/// Everything here is a derivation over the plan's own rules; the event log is
/// not touched. Days are generated on demand for the window asked — never
/// materialised years ahead, so a daf-yomi-sized plan costs nothing until a
/// visible window asks.
class PlannerSchedule {
  const PlannerSchedule._();

  /// The assignments of [plan] that fire on [info], in plan order.
  static List<PlanAssignment> assignmentsOn(LearningPlan plan, DayInfo info) {
    final movedFrom = {
      for (final o in plan.overrides)
        if (o.from == info.day) o.assignmentId,
    };
    final active = <PlanAssignment>[
      for (final a in plan.assignments)
        if (a.rule.matches(info) && !movedFrom.contains(a.id)) a,
    ];
    final present = {for (final a in active) a.id};
    return [
      ...active,
      for (final a in plan.assignments)
        if (plan.overrides.any((o) =>
            o.assignmentId == a.id && o.to == info.day) &&
            !present.contains(a.id))
          a,
    ];
  }

  /// Move one occurrence without changing the plan's rule.
  static LearningPlan move(
    LearningPlan plan, {
    required String assignmentId,
    required Day from,
    required Day to,
  }) =>
      LearningPlan(
        id: plan.id,
        name: plan.name,
        assignments: plan.assignments,
        displayCalendar: plan.displayCalendar,
        overrides: [
          ...plan.overrides.where((o) =>
              o.assignmentId != assignmentId || o.from != from),
          PlanOverride(assignmentId: assignmentId, from: from, to: to),
        ],
      );

  /// Move every occurrence from [from] through [through] by [days].
  static LearningPlan shiftAfter(
    LearningPlan plan, {
    required Day from,
    required Day through,
    required int days,
    required DayInfo Function(Day) info,
  }) {
    if (days == 0) return plan;
    var next = plan;
    for (final day in daysOn(plan, info, from, through)) {
      for (final assignment in assignmentsOn(plan, info(day))) {
        next = move(
          next,
          assignmentId: assignment.id,
          from: day,
          to: day + days,
        );
      }
    }
    return next;
  }

  /// Every day in `from..to` inclusive on which any assignment of [plan]
  /// fires, ascending. A day with two firing assignments appears once.
  static Iterable<Day> daysOn(
    LearningPlan plan,
    DayInfo Function(Day) info,
    Day from,
    Day to,
  ) sync* {
    for (var d = from; d <= to; d = d + 1) {
      final day = info(d);
      if (plan.assignments.any((a) => a.rule.matches(day))) yield d;
    }
  }
}