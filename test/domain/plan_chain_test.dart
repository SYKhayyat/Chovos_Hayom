import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/usecases/plan_chain.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan chaining (Phase 4, #9): the chain model and the derivation that
/// answers "which plans in this chain are active on day D" from a log-fold
/// predicate — never from stored state. Written before the implementation.
void main() {
  Day day(int ordinal) => Day(ordinal);

  /// Completion read the way the log reads it. `completeOn(n)` means *every*
  /// plan in the chain finishes during day n: still active on day n (the last
  /// unit is due that day), complete from day n+1 on.
  bool Function(String planId, Day d) completeOn(int completeDay) =>
      (id, d) => d.ordinal > completeDay;

  /// Like [completeOn] but for one named plan — the others stay incomplete,
  /// which is the case the chain derivation actually lives in.
  bool Function(String planId, Day d) finishes(String planId, int completeDay) =>
      (id, d) => id == planId && d.ordinal > completeDay;

  PlanChain chain({
    ChainMode mode = ChainMode.priority,
    List<String> planIds = const ['x', 'y', 'z'],
  }) =>
      PlanChain(id: 'c', name: 'Shas then Rambam', planIds: planIds, mode: mode);

  group('PlanChain', () {
    test('round-trips, both modes', () {
      expect(PlanChain.fromJson(chain().toJson()), chain());
      expect(
        PlanChain.fromJson(chain(mode: ChainMode.strict).toJson()),
        chain(mode: ChainMode.strict),
      );
    });

    test('defaults to the priority queue', () {
      expect(chain().mode, ChainMode.priority);
      final bare =
          PlanChain.fromJson({'id': 'c', 'name': 'C', 'planIds': ['x', 'y']});
      expect(bare.mode, ChainMode.priority);
    });

    test('is a value type', () {
      expect(chain(), chain());
      expect(chain(), isNot(chain(planIds: ['x', 'y'])));
      expect(chain(), isNot(chain(mode: ChainMode.strict)));
      expect(
        chain(),
        isNot(const PlanChain(id: 'other', name: 'N', planIds: ['x'])),
      );
    });

    test('JSON refuses an empty chain', () {
      expect(
        () => PlanChain.fromJson({'id': 'c', 'name': 'C', 'planIds': []}),
        throwsFormatException,
      );
    });

    test('JSON refuses duplicate plan ids', () {
      expect(
        () => PlanChain.fromJson(
            {'id': 'c', 'name': 'C', 'planIds': ['x', 'x']}),
        throwsFormatException,
      );
    });

    test('JSON refuses an unknown mode', () {
      expect(
        () => PlanChain.fromJson(
            {'id': 'c', 'name': 'C', 'planIds': ['x'], 'mode': 'loose'}),
        throwsFormatException,
      );
    });
  });

  group('ChainSchedule.activePlanIndices', () {
    test('strict: the first incomplete plan is the only active one', () {
      final c = chain(mode: ChainMode.strict);
      // x finishes during day 5: active through day 5, y from day 6.
      expect(ChainSchedule.activePlanIndices(c, day(4), finishes('x', 5)), [0]);
      expect(ChainSchedule.activePlanIndices(c, day(5), finishes('x', 5)), [0]);
      expect(ChainSchedule.activePlanIndices(c, day(6), finishes('x', 5)), [1]);
    });

    test('strict: a later plan is never due while an earlier one is behind', () {
      final c = chain(mode: ChainMode.strict, planIds: ['x', 'y']);
      expect(ChainSchedule.activePlanIndices(c, day(0), completeOn(100)), [0]);
      // Even on a day y's own schedule might fire, strict holds y back.
      expect(
        ChainSchedule.activePlanIndices(c, day(0), completeOn(100)),
        isNot(contains(1)),
      );
    });

    test('strict: every plan complete means nothing active', () {
      final c = chain(mode: ChainMode.strict);
      expect(ChainSchedule.activePlanIndices(c, day(9), completeOn(0)), isEmpty);
    });

    test('priority: incomplete plans from the first incomplete onward', () {
      final c = chain();
      // All three incomplete -> all three due, in chain order.
      expect(ChainSchedule.activePlanIndices(c, day(4), completeOn(100)),
          [0, 1, 2]);
      // y completes during day 2: x and z are still due (x spills forward,
      // z is next in the queue past y).
      bool complete(String id, Day d) => id == 'y' && d.ordinal > 2;
      expect(ChainSchedule.activePlanIndices(c, day(4), complete), [0, 2]);
    });

    test('priority: the backlog stays due until it clears', () {
      final c = chain(planIds: ['x', 'y']);
      // x completes during day 10; y is never complete within the window.
      bool complete(String id, Day d) => id == 'x' && d.ordinal > 10;
      expect(ChainSchedule.activePlanIndices(c, day(3), complete), [0, 1]);
      expect(ChainSchedule.activePlanIndices(c, day(10), complete), [0, 1]);
      expect(ChainSchedule.activePlanIndices(c, day(11), complete), [1]);
      expect(ChainSchedule.activePlanIndices(c, day(12), complete), [1]);
    });

    test('priority: all complete means nothing active', () {
      final c = chain();
      expect(ChainSchedule.activePlanIndices(c, day(50), completeOn(0)), isEmpty);
    });

    test('handover moves with an early finish, both modes', () {
      // x finishes during day 5, well before its nominal day 10.
      final strict = chain(mode: ChainMode.strict);
      final priority = chain();
      expect(ChainSchedule.activePlanIndices(strict, day(4), finishes('x', 5)), [0]);
      expect(ChainSchedule.activePlanIndices(strict, day(5), finishes('x', 5)), [0]);
      expect(ChainSchedule.activePlanIndices(strict, day(6), finishes('x', 5)), [1]);
      expect(ChainSchedule.activePlanIndices(priority, day(4), finishes('x', 5)),
          contains(0));
      expect(ChainSchedule.activePlanIndices(priority, day(6), finishes('x', 5)),
          isNot(contains(0)));
    });

    test('handover moves with a late finish, both modes', () {
      // x finishes during day 15, a week behind.
      final strict = chain(mode: ChainMode.strict);
      final priority = chain();
      expect(
          ChainSchedule.activePlanIndices(strict, day(14), finishes('x', 15)), [0]);
      expect(
          ChainSchedule.activePlanIndices(strict, day(15), finishes('x', 15)), [0]);
      expect(
          ChainSchedule.activePlanIndices(strict, day(16), finishes('x', 15)), [1]);
      // priority: y and z are due alongside the overdue x until x clears,
      // then only y and z after day 15.
      expect(ChainSchedule.activePlanIndices(priority, day(14), finishes('x', 15)),
          [0, 1, 2]);
      expect(ChainSchedule.activePlanIndices(priority, day(15), finishes('x', 15)),
          [0, 1, 2]);
      expect(ChainSchedule.activePlanIndices(priority, day(16), finishes('x', 15)),
          [1, 2]);
    });

    test('a chain of one plan is active until it completes', () {
      final c = chain(planIds: ['x']);
      expect(ChainSchedule.activePlanIndices(c, day(3), finishes('x', 10)), [0]);
      expect(ChainSchedule.activePlanIndices(c, day(9), finishes('x', 10)), [0]);
      expect(ChainSchedule.activePlanIndices(c, day(10), finishes('x', 10)), [0]);
      expect(ChainSchedule.activePlanIndices(c, day(11), finishes('x', 10)), isEmpty);
    });

    test('completion flips exactly once, as a log fold would', () {
      // The fold predicate is monotone: once complete, always complete.
      bool complete(String id, Day d) =>
          (id == 'x' && d.ordinal > 5) ||
          (id == 'y' && d.ordinal > 20) ||
          (id == 'z' && d.ordinal > 40);
      final c = chain(mode: ChainMode.strict);
      expect(ChainSchedule.activePlanIndices(c, day(4), complete), [0]);
      expect(ChainSchedule.activePlanIndices(c, day(5), complete), [0]);
      expect(ChainSchedule.activePlanIndices(c, day(6), complete), [1]);
      expect(ChainSchedule.activePlanIndices(c, day(20), complete), [1]);
      expect(ChainSchedule.activePlanIndices(c, day(21), complete), [2]);
      expect(ChainSchedule.activePlanIndices(c, day(40), complete), [2]);
      expect(ChainSchedule.activePlanIndices(c, day(41), complete), isEmpty);
    });

    test('empty chain (unreachable via JSON) answers nothing', () {
      const c = PlanChain(id: 'c', name: 'C', planIds: []);
      expect(ChainSchedule.activePlanIndices(c, day(1), completeOn(0)), isEmpty);
    });
  });

  group('ChainSchedule.activePlanIds', () {
    test('mirrors the indices against the plan list', () {
      final c = chain(mode: ChainMode.strict);
      expect(ChainSchedule.activePlanIds(c, day(4), finishes('x', 5)), ['x']);
      expect(ChainSchedule.activePlanIds(c, day(6), finishes('x', 5)), ['y']);
    });
  });
}