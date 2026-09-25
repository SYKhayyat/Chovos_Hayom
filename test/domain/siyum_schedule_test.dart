import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/entities/progress_node.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/roll_up.dart';
import 'package:chovos_hayom/domain/usecases/siyum.dart';
import 'package:chovos_hayom/domain/usecases/siyum_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

var _seq = 0;
LearningEvent done(String node, int unit, DateTime day) => LearningEvent(
      id: 'e${_seq++}',
      profileId: 'p',
      nodeId: node,
      unitIndex: unit,
      action: EventAction.done,
      occurredAt: day,
      loggedAt: day,
    );

final catalog = Catalog([
  const CatalogNode(id: 'root', parentId: null, name: 'Root', kind: NodeKind.category),
  const CatalogNode(
      id: 'small',
      parentId: 'root',
      name: 'Small',
      kind: NodeKind.leaf,
      unitLabel: UnitLabel.perek,
      unitCount: 3,
      unitOffset: 1),
  const CatalogNode(
      id: 'big',
      parentId: 'root',
      name: 'Big',
      kind: NodeKind.leaf,
      unitLabel: UnitLabel.daf,
      unitCount: 5,
      unitOffset: 2),
]);

final today = Day.of(DateTime(2026, 1, 1));

List<ProgressNode> forestFor(List<LearningEvent> events) =>
    RollUp.buildForest(catalog, FoldLog.fold(events));

List<ScheduledSiyum> projectedFor(
  List<LearningEvent> events, {
  double perDay = 1,
  Day? from,
}) =>
    SiyumSchedule.projected(
      forest: forestFor(events),
      perDay: perDay,
      today: from ?? today,
    );

void main() {
  setUp(() => _seq = 0);

  group('a scheduled siyum is a forecast of the log, not a second truth', () {
    test('an untouched catalog projects every level, root included', () {
      // Nothing learned at 1/day: Small owes 3 (day+2), Big owes 5 (day+4),
      // Root rolls up both to 8 (day+7). So the schedule is soonest-first and
      // leads with the leaves, ending on the whole-catalog siyum.
      final scheduled = projectedFor([], perDay: 1);
      expect(scheduled.map((s) => s.node.id), ['small', 'big', 'root']);
      expect(scheduled.map((s) => s.day),
          [today + 2, today + 4, today + 7]);
      expect(scheduled.map((s) => s.remaining), [3, 5, 8]);
      expect(scheduled.first.isCategory, isFalse);
      expect(scheduled.last.isCategory, isTrue, reason: 'root is a category');
    });

    test('the projection reads remaining, so progress pulls the day nearer', () {
      // Small is 3 units; with 1 of 3 done it owes 2, so at 1/day it lands a
      // day sooner than an untouched Small would.
      final before = projectedFor([]).firstWhere((s) => s.node.id == 'small');
      final after = projectedFor([done('small', 1, DateTime(2026, 1, 1))])
          .firstWhere((s) => s.node.id == 'small');
      expect(before.remaining, 3);
      expect(after.remaining, 2);
      expect(after.day, today + 1);
    });

    test('a completed node drops out of the schedule entirely', () {
      // Marking the last unit of Small does not "confirm" a stored siyum — the
      // node stops being unfinished, so there is nothing left to project, and the
      // real siyum now comes from the log's own finder.
      final events = [
        for (var u = 1; u <= 3; u++) done('small', u, DateTime(2026, 1, 1)),
      ];
      final fold = FoldLog.fold(events);
      final forest = RollUp.buildForest(catalog, fold);

      final scheduled = SiyumSchedule.projected(
          forest: forest, perDay: 1, today: today);
      expect(scheduled.map((s) => s.node.id), isNot(contains('small')));

      // The two halves agree: small is no longer scheduled, and the real siyum
      // has taken over from the log's own finder.
      expect(SiyumFinder.completed(forest, fold).map((s) => s.node.id),
          contains('small'));
    });

    test('the scheduled and completed views partition the nodes', () {
      // Small done, Big not: exactly one of {scheduled, completed} holds each
      // node, which is what "no second truth" means operationally.
      final events = [
        for (var u = 1; u <= 3; u++) done('small', u, DateTime(2026, 1, 1)),
      ];
      final fold = FoldLog.fold(events);
      final forest = RollUp.buildForest(catalog, fold);

      final scheduledIds = SiyumSchedule.projected(
              forest: forest, perDay: 1, today: today)
          .map((s) => s.node.id)
          .toSet();
      final completedIds =
          SiyumFinder.completed(forest, fold).map((s) => s.node.id).toSet();

      // Small is complete; root and Big are still owed. No overlap.
      expect(completedIds, contains('small'));
      expect(scheduledIds.intersection(completedIds), isEmpty);
    });
  });

  group('SiyumSchedule.projected', () {
    test('no pace means no honest day, so nothing is scheduled', () {
      // With no pace Predictor would answer "never"; scheduling nothing keeps
      // the calendar from inventing a date.
      expect(projectedFor([], perDay: 0), isEmpty);
      expect(projectedFor([], perDay: -1), isEmpty);
    });

    test('a category with one unfinished child is still scheduled', () {
      // Small complete, Big not: Root is owed Big's remaining 4 units, so Root
      // has a real future siyum even though one of its leaves already landed.
      final events = [
        for (var u = 1; u <= 3; u++) done('small', u, DateTime(2026, 1, 1)),
        done('big', 2, DateTime(2026, 1, 1)),
      ];
      final scheduled = projectedFor(events, perDay: 1);
      expect(scheduled.map((s) => s.node.id).toSet(), {'root', 'big'});
      expect(scheduled.map((s) => s.node.id), isNot(contains('small')));
      // Both owe Big's 4 remaining units, so they share the day at 1/day.
      expect(scheduled.every((s) => s.remaining == 4), isTrue);
      expect(scheduled.every((s) => s.day == today + 3), isTrue);
    });

    test('a faster pace schedules every siyum sooner', () {
      final events = [done('small', 1, DateTime(2026, 1, 1))];
      final slow = projectedFor(events, perDay: 1)
          .firstWhere((s) => s.node.id == 'small');
      final fast = projectedFor(events, perDay: 2)
          .firstWhere((s) => s.node.id == 'small');
      expect(fast.day, today);
      expect(slow.day, today + 1);
    });

    test('is sorted soonest day first', () {
      // Untouched at 1/day: Small owes 3 (day+2), Big owes 5 (day+4), Root owes
      // 8 (day+7). The list must read as a timeline.
      final scheduled = projectedFor([], perDay: 1);
      final days = scheduled.map((s) => s.day).toList();
      expect(days, [today + 2, today + 4, today + 7]);
      for (var i = 1; i < days.length; i++) {
        expect(days[i - 1] <= days[i], isTrue);
      }
    });

    test('same-day ties lead with the larger siyum', () {
      // At a fast pace every node finishes today; order must be by size.
      final scheduled = projectedFor([], perDay: 100);
      expect(scheduled.map((s) => s.remaining), [8, 5, 3]);
    });

    test('an empty forest schedules nothing', () {
      expect(
        SiyumSchedule.projected(forest: const [], perDay: 1, today: today),
        isEmpty,
      );
    });
  });

  group('ScheduledSiyum', () {
    test('is a value type', () {
      final forest = forestFor([]);
      List<ScheduledSiyum> project() => SiyumSchedule.projected(
          forest: forest, perDay: 1, today: today);
      expect(project().first, project().first);
      // Different remaining (progress) is a different siyum.
      final progressed = SiyumSchedule.projected(
        forest: RollUp.buildForest(catalog, FoldLog.fold([
          done('small', 1, DateTime(2026, 1, 1)),
        ])),
        perDay: 1,
        today: today,
      );
      expect(project().first, isNot(progressed.firstWhere(
            (s) => s.node.id == 'small' && s.remaining != project().first.remaining,
          )));
    });
  });
}
