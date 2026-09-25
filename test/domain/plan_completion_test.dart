import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/plan_completion.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';

/// Plan completion (Phase 2, #7 / Phase 4, #9): the predicate that says a plan
/// is finished, folded from the log. Written before the implementation.
///
/// The fake catalog is root → Shas → Moed → Shabbos, where Shabbos is a leaf
/// with units 2..157 (unitCount 156, unitOffset 2).
void main() {
  const leaf = 'shas.moed.shabbos';
  const category = 'shas.moed';

  Day day(int y, int m, int d) => Day.of(DateTime(y, m, d));

  LogFold foldWhere(Map<int, DateTime> doneAt) => LogFold(
        completedByNode: {
          leaf: {for (final u in doneAt.keys) u: {mainLayerId}},
        },
        reviewsByNode: const {},
        doneAtByNode: {leaf: doneAt},
        touchedAtByNode: const {},
        annotatedByNode: const {},
      );

  /// Every unit of the Shabbos leaf done on [onDay].
  LogFold allShabbos(DateTime onDay) =>
      foldWhere({for (var u = 2; u < 158; u++) u: onDay});

  LearningPlan plan({
    String? target = leaf,
  }) =>
      LearningPlan(
        id: 'p',
        name: 'P',
        assignments: [PlanAssignment(id: 'a', rule: const DailyRule(), targetNodeId: target)],
      );

  group('nodeCompleteBefore', () {
    test('a leaf with every unit done the day before is complete', () {
      final fold = allShabbos(DateTime(2026, 9, 9));
      expect(
        PlanCompletion.nodeCompleteBefore(
            fakeCatalog().byId(leaf)!, fakeCatalog(), fold, day(2026, 9, 10)),
        isTrue,
      );
    });

    test('a leaf whose last unit was done *today* is not complete before today',
        () {
      final fold = allShabbos(DateTime(2026, 9, 10));
      expect(
        PlanCompletion.nodeCompleteBefore(
            fakeCatalog().byId(leaf)!, fakeCatalog(), fold, day(2026, 9, 10)),
        isFalse,
        reason: 'the day the last unit is due, the node is still active',
      );
    });

    test('a leaf with one unit missing is not complete', () {
      final map = {for (var u = 2; u < 158; u++) u: DateTime(2026, 9, 9)}
        ..remove(100);
      expect(
        PlanCompletion.nodeCompleteBefore(fakeCatalog().byId(leaf)!,
            fakeCatalog(), foldWhere(map), day(2026, 9, 10)),
        isFalse,
      );
    });

    test('a leaf with nothing done is not complete', () {
      expect(
        PlanCompletion.nodeCompleteBefore(fakeCatalog().byId(leaf)!,
            fakeCatalog(), foldWhere(const {}), day(2026, 9, 10)),
        isFalse,
      );
    });

    test('a category requires every leaf under it', () {
      expect(
        PlanCompletion.nodeCompleteBefore(fakeCatalog().byId(category)!,
            fakeCatalog(), allShabbos(DateTime(2026, 9, 9)), day(2026, 9, 10)),
        isTrue,
      );
      expect(
        PlanCompletion.nodeCompleteBefore(fakeCatalog().byId(category)!,
            fakeCatalog(), foldWhere(const {}), day(2026, 9, 10)),
        isFalse,
      );
    });
  });

  group('completeBefore', () {
    test('a plan targeting a complete leaf completes', () {
      expect(
        PlanCompletion.completeBefore(
            plan(), fakeCatalog(), allShabbos(DateTime(2026, 9, 9)), day(2026, 9, 10)),
        isTrue,
      );
    });

    test('a plan targeting an incomplete leaf does not complete', () {
      expect(
        PlanCompletion.completeBefore(
            plan(), fakeCatalog(), allShabbos(DateTime(2026, 9, 10)), day(2026, 9, 10)),
        isFalse,
      );
    });

    test('a plan with an empty assignment list can never complete', () {
      expect(
        PlanCompletion.completeBefore(const LearningPlan(id: 'p', name: 'P'),
            fakeCatalog(), foldWhere(const {}), day(2026, 9, 10)),
        isFalse,
      );
    });

    test('an assignment with no target can never complete', () {
      final untargeted = plan(target: null);
      expect(
        PlanCompletion.completeBefore(untargeted, fakeCatalog(),
            allShabbos(DateTime(2026, 9, 9)), day(2026, 9, 10)),
        isFalse,
      );
    });

    test('a target the catalog does not have can never complete', () {
      final ghost = plan(target: 'nope');
      expect(
        PlanCompletion.completeBefore(ghost, fakeCatalog(),
            allShabbos(DateTime(2026, 9, 9)), day(2026, 9, 10)),
        isFalse,
      );
    });
  });
}