import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:flutter_test/flutter_test.dart';

/// The summary counts a tick rather than keeping only the latest one.
///
/// **Why this file exists.** The summary used to keep one date per unit, so a
/// second tick *overwrote* the first and "how many times have you done this" was
/// not answerable at all — the information was in the log and thrown away by the
/// fold. The owner's ruling: a unit learned seven years ago and again now has
/// genuinely been learned twice, and a summary that says once is simply wrong.
///
/// **The shape is per-day, and that is load-bearing rather than convenient.** A
/// single all-time counter cannot answer a historical question: asked "how far
/// along was I in 2019?", it would credit a 2026 tick to 2019. One tally per day
/// makes every "as of" query the same sum — the days before this one — so the
/// planner's existing "done **before** this day" rule keeps working unchanged
/// and starts answering questions it previously could not.
var _seq = 0;
LearningEvent done(String node, int unit, DateTime day, {String? planId}) =>
    LearningEvent(
      id: 'e${_seq++}',
      profileId: 'p',
      nodeId: node,
      unitIndex: unit,
      action: EventAction.done,
      occurredAt: day,
      loggedAt: day,
      planId: planId,
    );

LearningEvent undone(String node, int unit, DateTime day, {String? planId}) =>
    LearningEvent(
      id: 'e${_seq++}',
      profileId: 'p',
      nodeId: node,
      unitIndex: unit,
      action: EventAction.undone,
      occurredAt: day,
      loggedAt: day,
      planId: planId,
    );

final y2019 = DateTime.utc(2019, 5, 1);
final y2026 = DateTime.utc(2026, 3, 1);

void main() {
  setUp(() => _seq = 0);

  group('counting ticks rather than keeping the latest', () {
    test('one tick is a count of one', () {
      final fold = FoldLog.fold([done('n', 2, y2026)]);
      expect(fold.doneCount('n', 2), 1);
    });

    test('two ticks on the same day are two', () {
      // The overlap case: two plans both covering this unit, both ticked on one
      // day. The owner's ruling is that this counts twice.
      final fold = FoldLog.fold([
        done('n', 2, y2026, planId: 'daf-yomi'),
        done('n', 2, y2026, planId: 'slow'),
      ]);
      expect(fold.doneCount('n', 2), 2);
    });

    test('a tick seven years after the first is a second, not a replacement', () {
      // The case that settled the design. `doneAt` is still the later one — that
      // is what "when did I last do this" wants — but the count keeps both.
      final fold = FoldLog.fold([done('n', 2, y2019), done('n', 2, y2026)]);
      expect(fold.doneCount('n', 2), 2);
      expect(fold.doneAt('n', 2), y2026,
          reason: 'the latest date is still what "last did" means');
    });

    test('a unit never ticked is zero, not an error', () {
      expect(FoldLog.fold([]).doneCount('n', 2), 0);
    });
  });

  group('per day, so history is answerable', () {
    test('each day holds its own count', () {
      final fold = FoldLog.fold([
        done('n', 2, y2019),
        done('n', 2, y2026),
      ]);
      expect(fold.doneCountOn('n', 2, Day.of(y2019)), 1);
      expect(fold.doneCountOn('n', 2, Day.of(y2026)), 1);
    });

    test('a day with nothing done reads zero rather than null', () {
      final fold = FoldLog.fold([done('n', 2, y2019)]);
      expect(fold.doneCountOn('n', 2, Day.of(y2026)), 0);
    });

    test('counting as of a day sums only the days before it', () {
      // **This is the reason the tally is per-day.** A single all-time counter
      // would answer 2 here and credit a 2026 tick to 2019.
      final fold = FoldLog.fold([done('n', 2, y2019), done('n', 2, y2026)]);
      expect(fold.doneCountAsOf('n', 2, Day.of(DateTime.utc(2020, 1, 1))), 1);
      expect(fold.doneCountAsOf('n', 2, Day.of(DateTime.utc(2030, 1, 1))), 2);
    });

    test('"as of" is exclusive, so a unit learned that day is still owed',
        () {
      // The rule the whole planner already depends on: a plan must not report
      // itself finished on the day it finishes.
      final fold = FoldLog.fold([done('n', 2, y2026)]);
      expect(fold.doneCountAsOf('n', 2, Day.of(y2026)), 0);
      expect(fold.doneCountAsOf('n', 2, Day.of(y2026) + 1), 1);
    });
  });

  group('off-plan ticks and plan ticks both count', () {
    test('the total is the sum of both kinds', () {
      // The grid tick is a claim about the learner and belongs to no plan; the
      // plan tick is that plan's. Both are real work, so both are counted.
      final fold = FoldLog.fold([
        done('n', 2, y2026),
        done('n', 2, y2026, planId: 'daf-yomi'),
      ]);
      expect(fold.doneCount('n', 2), 2);
    });

    test('and the count for a plan alone can be asked for', () {
      final fold = FoldLog.fold([
        done('n', 2, y2026),
        done('n', 2, y2026, planId: 'daf-yomi'),
      ]);
      expect(fold.doneCountForPlan('daf-yomi'), 1,
          reason: 'the day ledger reads this: what this plan asked, and what was '
              'ticked for it, separately from the grid');
    });

    test('a plan with no ticks has none', () {
      expect(FoldLog.fold([done('n', 2, y2026)]).doneCountForPlan('other'), 0);
    });
  });

  group('un-ticking takes one back', () {
    test('from the day it belongs to, not the latest day', () {
      // The owner: you can tick things in the past, so an un-tick must name the
      // day it is taking back rather than reaching for the most recent one.
      final fold = FoldLog.fold([
        done('n', 2, y2019),
        done('n', 2, y2026),
        undone('n', 2, y2019),
      ]);
      expect(fold.doneCountOn('n', 2, Day.of(y2019)), 0);
      expect(fold.doneCountOn('n', 2, Day.of(y2026)), 1,
          reason: 'the 2026 tick is untouched; an un-tick takes back what it '
              'names and nothing else');
      expect(fold.doneCount('n', 2), 1);
    });

    test('to zero, the unit stops being done', () {
      final fold = FoldLog.fold([done('n', 2, y2026), undone('n', 2, y2026)]);
      expect(fold.doneCount('n', 2), 0);
      expect(fold.completedLayers('n', 2), isEmpty);
    });

    test('an un-tick below zero is refused, not allowed to go negative', () {
      final fold = FoldLog.fold([done('n', 2, y2026), undone('n', 2, y2026)]);
      final again = FoldLog.fold([
        done('n', 2, y2026),
        undone('n', 2, y2026),
        undone('n', 2, y2026),
      ]);
      expect(again.doneCount('n', 2), 0);
      expect(fold.doneCount('n', 2), 0);
    });
  });

  group('a unit stays done while any day still has a tick', () {
    test('a partial un-tick leaves it done', () {
      // Un-ticking 2019 while 2026 stands must not make the unit "not done" —
      // it *was* done, this month. This is the same rule the layer fold uses,
      // and the count is where it is easiest to get wrong.
      final fold = FoldLog.fold([
        done('n', 2, y2019),
        done('n', 2, y2026),
        undone('n', 2, y2019),
      ]);
      expect(fold.completedLayers('n', 2), isNotEmpty,
          reason: 'still done this month, so the progress bar must not drop it');
      expect(fold.doneAt('n', 2), y2026);
    });

    test('and the count reflects only the day that remains', () {
      final fold = FoldLog.fold([
        done('n', 2, y2019),
        done('n', 2, y2026),
        undone('n', 2, y2019),
      ]);
      expect(fold.doneCount('n', 2), 1);
    });
  });
}
