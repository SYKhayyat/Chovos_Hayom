import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/chazara.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:flutter_test/flutter_test.dart';

/// #45 — chazara is one rule: **learned means chazara**.
///
/// **What this file is really about.** Before this, a unit that had been learned
/// but never reviewed had a chazara count of **zero**, and a spaced-repetition
/// scheduler decided when it was "due". The rule now is that the first pass *is*
/// the learning: a learned unit has been chazara'd once, and every later pass is
/// counted on top. Nothing needs to be scheduled and nothing needs to be stored,
/// because the count is a fold over the log.
///
/// That matters for #42 in particular: marking a unit done from the calendar
/// writes a `done` event, and under the old rule that unit was **not** chazara'd.
/// Under this one it is, with no second event written — the two must not both
/// write review state, so only `done` is ever written and the rest is derived.
var _seq = 0;
LearningEvent ev(String node, int unit, EventAction action, int day) =>
    LearningEvent(
      id: 'e${_seq++}',
      profileId: 'p',
      nodeId: node,
      unitIndex: unit,
      action: action,
      occurredAt: DateTime.utc(2026, 3, day),
      loggedAt: DateTime.utc(2026, 3, day),
    );

void main() {
  setUp(() => _seq = 0);

  group('learning is the first pass', () {
    test('a unit learned once has one chazara, not zero', () {
      // The whole issue in one assertion. The old count was 0, which made a
      // freshly-learned unit look unreviewed forever.
      final fold = FoldLog.fold([ev('n', 2, EventAction.done, 1)]);
      expect(fold.chazaraCount('n', 2), 1);
    });

    test('a unit never learned has none', () {
      expect(FoldLog.fold([]).chazaraCount('n', 2), 0);
    });

    test('two passes make two', () {
      final fold = FoldLog.fold([
        ev('n', 2, EventAction.done, 1),
        ev('n', 2, EventAction.reviewed, 2),
      ]);
      expect(fold.chazaraCount('n', 2), 2);
    });

    test('and it is the same as the review count plus the learning', () {
      // Stated as an identity so the two cannot drift: the old review counter
      // still exists and is still the right number of *reviews*, so the chazara
      // count is that plus the learning rather than a second thing to maintain.
      final fold = FoldLog.fold([
        ev('n', 2, EventAction.done, 1),
        ev('n', 2, EventAction.reviewed, 2),
        ev('n', 2, EventAction.reviewed, 3),
      ]);
      expect(fold.reviewCount('n', 2), 2);
      expect(fold.chazaraCount('n', 2), 3);
    });
  });

  group('and the count is the whole report', () {
    test('a review of something not learned counts for nothing', () {
      // The old fold already refused this, and it is right: a chazara of
      // something you have not learned is not a pass at it.
      final fold = FoldLog.fold([ev('n', 2, EventAction.reviewed, 1)]);
      expect(fold.chazaraCount('n', 2), 0);
      expect(Chazara.reviewedUnits(fold), isEmpty);
    });

    test('the report is every unit with at least one pass', () {
      final fold = FoldLog.fold([
        ev('a', 1, EventAction.done, 1),
        ev('a', 2, EventAction.done, 1),
        ev('b', 5, EventAction.done, 1),
      ]);
      final report = Chazara.reviewedUnits(fold);
      expect(
        report.length,
        3,
        reason: 'learned is chazara, so three units have one pass each',
      );
      expect(report.firstWhere((r) => r.nodeId == 'a').passes, 1);
    });

    test('sorted by most passes, so the most-reviewed is first', () {
      // A report is read for "what have I been over most", and that is not the
      // order a unit-indexed map happens to produce.
      final fold = FoldLog.fold([
        ev('a', 1, EventAction.done, 1),
        ev('a', 1, EventAction.reviewed, 2),
        ev('a', 1, EventAction.reviewed, 3),
        ev('b', 1, EventAction.done, 1),
      ]);
      final report = Chazara.reviewedUnits(fold);
      expect(report.first.nodeId, 'a');
      expect(report.first.passes, 3);
      expect(report.last.nodeId, 'b');
    });

    test('and there is nothing to be "due" any more', () {
      // The consequence worth stating: with no stored intervals and no
      // scheduler, the question "what is due today" has no answer by
      // construction rather than by being switched off.
      expect(Chazara.hasSchedule, isFalse);
    });
  });

  group('un-marking', () {
    test('takes the passes with it, as before', () {
      // A full un-mark clears the unit's review history, and it must clear the
      // chazara too — otherwise an un-learned unit would keep a pass count and
      // the two would describe different histories.
      final fold = FoldLog.fold([
        ev('n', 2, EventAction.done, 1),
        ev('n', 2, EventAction.reviewed, 2),
        ev('n', 2, EventAction.undone, 3),
      ]);
      expect(fold.chazaraCount('n', 2), 0);
      expect(fold.completedLayers('n', 2), isEmpty);
    });

    test('a partial un-mark leaves the passes alone', () {
      // Un-ticking an optional meforish while the required set survives must not
      // touch the count: the unit is still learned, so it still has its passes.
      final fold = FoldLog.fold([
        LearningEvent(
          id: 'e1',
          profileId: 'p',
          nodeId: 'n',
          unitIndex: 2,
          action: EventAction.done,
          occurredAt: DateTime.utc(2026, 3, 1),
          loggedAt: DateTime.utc(2026, 3, 1),
        ),
        ev('n', 2, EventAction.reviewed, 2),
        LearningEvent(
          id: 'e3',
          profileId: 'p',
          nodeId: 'n',
          unitIndex: 2,
          action: EventAction.undone,
          occurredAt: DateTime.utc(2026, 3, 3),
          loggedAt: DateTime.utc(2026, 3, 3),
          layers: const ['rashi'],
        ),
      ]);
      expect(
        fold.chazaraCount('n', 2),
        2,
        reason: 'the unit is still learned, so both passes stand',
      );
    });
  });
}
