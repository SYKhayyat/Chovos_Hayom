import '../../core/day.dart';
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
  final Day? projectedFinish;
  final Day target;

  bool get achieved => remaining <= 0;

  /// On track if finished, or if current pace meets/exceeds the required pace.
  bool get onTrack => achieved || currentPace >= requiredPerDay;

  /// Projected days early (negative) or late (positive) vs the target.
  ///
  /// Whole calendar days apart, not elapsed hours divided by 24. The previous
  /// `projectedFinish.difference(target).inDays` truncated toward zero, so a
  /// projection landing a day late on a target with any time-of-day on it —
  /// and across a DST boundary, even one at midnight — read as exactly on time.
  int? get daysOffTarget => projectedFinish?.difference(target);

  /// `goalStatusProvider` is a family with one element per node that has a
  /// goal, and each of them watches the log and the clock. Without this, one
  /// marked daf re-notified every goal row in the app; with it, only the goals
  /// whose numbers actually moved do.
  @override
  bool operator ==(Object other) =>
      other is GoalStatus &&
      other.remaining == remaining &&
      other.requiredPerDay == requiredPerDay &&
      other.currentPace == currentPace &&
      other.projectedFinish == projectedFinish &&
      other.target == target;

  @override
  int get hashCode => Object.hash(
      remaining, requiredPerDay, currentPace, projectedFinish, target);
}

/// Evaluates a target-date goal against actual pace. Pure.
class GoalEvaluator {
  const GoalEvaluator._();

  static GoalStatus evaluate({
    required int remaining,
    required Day from,
    required Day target,
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
