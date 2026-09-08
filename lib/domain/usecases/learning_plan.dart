import 'package:chovos_hayom/core/day.dart';

import 'recurrence.dart';

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

/// A learning plan: a named set of assignments sharing a default display
/// calendar.
///
/// The epic's principle: the schedule is a plan; the log is reality. This is
/// the plan half. A plan fires on a day when any assignment's rule matches;
/// overlapping assignments all fire — "Mishna Yomi daily + Chumash on
/// Wednesdays" is one plan with two assignments, both due on a Wednesday.
class LearningPlan {
  const LearningPlan({
    required this.id,
    required this.name,
    this.assignments = const [],
    this.displayCalendar = RuleCalendar.gregorian,
  });

  final String id;
  final String name;
  final List<PlanAssignment> assignments;

  /// The calendar a plan's days are shown in by default. A rule may still
  /// declare its own (see [RecurrenceRule.calendar]).
  final RuleCalendar displayCalendar;

  bool get hasHebrewRules =>
      assignments.any((a) => a.rule.calendar == RuleCalendar.hebrew);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'displayCalendar': displayCalendar.name,
        'assignments': [for (final a in assignments) a.toJson()],
      };

  factory LearningPlan.fromJson(Map<String, dynamic> json) => LearningPlan(
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
      );

  @override
  bool operator ==(Object other) =>
      other is LearningPlan &&
      other.id == id &&
      other.name == name &&
      other.displayCalendar == displayCalendar &&
      _sameAssignments(assignments, other.assignments);

  @override
  int get hashCode =>
      Object.hash(id, name, displayCalendar, Object.hashAll(assignments));

  static bool _sameAssignments(List<PlanAssignment> a, List<PlanAssignment> b) {
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
  static List<PlanAssignment> assignmentsOn(LearningPlan plan, DayInfo info) =>
      [for (final a in plan.assignments) if (a.rule.matches(info)) a];

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