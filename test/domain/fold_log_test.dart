import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:flutter_test/flutter_test.dart';

LearningEvent ev(
  String node,
  int unit,
  EventAction action, {
  int seq = 0,
  String? id,
}) {
  final t = DateTime(2026, 1, 1).add(Duration(seconds: seq));
  return LearningEvent(
    id: id ?? '$node-$unit-${action.name}-$seq',
    profileId: 'p',
    nodeId: node,
    unitIndex: unit,
    action: action,
    occurredAt: t,
    loggedAt: t,
  );
}

void main() {
  group('FoldLog', () {
    test('done marks a unit', () {
      final fold = FoldLog.fold([ev('a', 2, EventAction.done)]);
      expect(fold.doneUnits('a'), {2});
    });

    test('undone removes a previously done unit', () {
      final fold = FoldLog.fold([
        ev('a', 2, EventAction.done, seq: 0),
        ev('a', 2, EventAction.undone, seq: 1),
      ]);
      expect(fold.doneUnits('a'), isEmpty);
    });

    test('later done after undone re-marks it', () {
      final fold = FoldLog.fold([
        ev('a', 2, EventAction.done, seq: 0),
        ev('a', 2, EventAction.undone, seq: 1),
        ev('a', 2, EventAction.done, seq: 2),
      ]);
      expect(fold.doneUnits('a'), {2});
    });

    test('fold is order-independent (sorted by loggedAt then id)', () {
      final ordered = [
        ev('a', 2, EventAction.done, seq: 0),
        ev('a', 2, EventAction.undone, seq: 1),
      ];
      final shuffled = [ordered[1], ordered[0]];
      expect(FoldLog.fold(shuffled).doneUnits('a'), isEmpty);
    });

    test('reviewed increments review count without affecting done', () {
      final fold = FoldLog.fold([
        ev('a', 5, EventAction.done, seq: 0),
        ev('a', 5, EventAction.reviewed, seq: 1),
        ev('a', 5, EventAction.reviewed, seq: 2),
      ]);
      expect(fold.doneUnits('a'), {5});
      expect(fold.reviewCount('a', 5), 2);
    });
  });
}
