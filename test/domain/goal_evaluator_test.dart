import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/usecases/goal_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final from = Day.of(DateTime(2026, 1, 1));
  final target = Day.of(DateTime(2026, 1, 11)); // 10 days out

  test('behind when current pace is below required', () {
    final s = GoalEvaluator.evaluate(
        remaining: 100, from: from, target: target, currentPace: 5);
    expect(s.requiredPerDay, closeTo(10, 0.001));
    expect(s.onTrack, isFalse);
    // 100 at 5/day = 20 learning days, today inclusive -> Jan 1 + 19 = Jan 20.
    expect(s.projectedFinish, Day.of(DateTime(2026, 1, 20)));
    expect(s.daysOffTarget, 9);
  });

  test('on track when pace meets required', () {
    final s = GoalEvaluator.evaluate(
        remaining: 100, from: from, target: target, currentPace: 10);
    expect(s.onTrack, isTrue);
  });

  test('achieved when nothing remains', () {
    final s = GoalEvaluator.evaluate(
        remaining: 0, from: from, target: target, currentPace: 0);
    expect(s.achieved, isTrue);
    expect(s.onTrack, isTrue);
    expect(s.requiredPerDay, 0);
  });

  test('daysOffTarget is null when there is no projection', () {
    final s = GoalEvaluator.evaluate(
        remaining: 100, from: from, target: target, currentPace: 0);
    expect(s.projectedFinish, isNull);
    expect(s.daysOffTarget, isNull);
  });

  // `daysOffTarget` was `projectedFinish.difference(target).inDays` — a
  // `Duration` truncated toward zero. Any calendar day shorter than 24 hours,
  // or any target carrying a time of day, made "one day late" read as zero.
  // Now both sides are `Day`, so the answer is a subtraction of day counts and
  // there is no hour left to lose.
  test('a day late reads as a day late, on every day of the year', () {
    for (var i = 0; i < 365; i++) {
      final day = Day.of(DateTime(2026, 1, 1)) + i;
      final s = GoalEvaluator.evaluate(
        // 2 units at 1/day finishes on `day + 1`, one day past a target of
        // `day` — the smallest miss the tile is supposed to report.
        remaining: 2,
        from: day,
        target: day,
        currentPace: 1,
      );
      expect(s.projectedFinish, day + 1, reason: '$day');
      expect(s.daysOffTarget, 1, reason: '$day');
    }
  });
}
