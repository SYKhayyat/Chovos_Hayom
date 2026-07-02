import 'predictor.dart';

/// Whether a target-date goal is on track, and what pace it needs.
class GoalStatus {
  const GoalStatus({
    required this.remaining,
    required this.requiredPerDay,
    required this.currentPace,
    required this.projectedFinish,
    required this.target,
  });

  final int remaining;
  final double requiredPerDay;
  final double currentPace;
  final DateTime? projectedFinish;
  final DateTime target;

  bool get achieved => remaining <= 0;

  /// On track if finished, or if current pace meets/exceeds the required pace.
  bool get onTrack => achieved || currentPace >= requiredPerDay;

  /// Projected days early (negative) or late (positive) vs the target.
  int? get daysOffTarget {
    if (projectedFinish == null) return null;
    return projectedFinish!.difference(target).inDays;
  }
}

/// Evaluates a target-date goal against actual pace. Pure.
class GoalEvaluator {
  const GoalEvaluator._();

  static GoalStatus evaluate({
    required int remaining,
    required DateTime from,
    required DateTime target,
    required double currentPace,
  }) {
    return GoalStatus(
      remaining: remaining,
      requiredPerDay:
          Predictor.requiredPerDay(remaining: remaining, from: from, target: target),
      currentPace: currentPace,
      projectedFinish: currentPace > 0
          ? Predictor.finishDate(remaining: remaining, perDay: currentPace, from: from)
          : null,
      target: target,
    );
  }
}
