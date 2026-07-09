import 'package:chovos_hayom/domain/usecases/goal_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final from = DateTime(2026, 1, 1);
  final target = DateTime(2026, 1, 11); // 10 days out

  test('behind when current pace is below required', () {
    final s = GoalEvaluator.evaluate(
        remaining: 100, from: from, target: target, currentPace: 5);
    expect(s.requiredPerDay, closeTo(10, 0.001));
    expect(s.onTrack, isFalse);
    // 100 at 5/day = 20 learning days, today inclusive -> Jan 1 + 19 = Jan 20.
    expect(s.projectedFinish, DateTime(2026, 1, 20));
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
}
