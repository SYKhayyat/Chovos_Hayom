import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/planner_calendar.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';

void main() {
  const leaf = 'shas.moed.shabbos';
  final catalog = fakeCatalog();
  const plan = LearningPlan(
    id: 'p',
    name: 'P',
    assignments: [
      PlanAssignment(id: 'a', rule: DailyRule(), targetNodeId: leaf),
    ],
  );

  LogFold fold(Map<int, DateTime> doneAt) => LogFold(
        completedByNode: {
          leaf: {for (final u in doneAt.keys) u: {mainLayerId}},
        },
        reviewsByNode: const {},
        doneAtByNode: {leaf: doneAt},
        touchedAtByNode: const {},
        annotatedByNode: const {},
      );

  List<PlannedDay> days(LogFold log) => PlannerCalendar.between(
        plans: [plan],
        catalog: catalog,
        fold: log,
        from: Day.of(DateTime(2026, 1, 8)),
        to: Day.of(DateTime(2026, 1, 12)),
        today: Day.of(DateTime(2026, 1, 10)),
      );

  test('classifies past and future planned days from the log', () {
    final result = days(fold(const {}));
    expect(result.map((d) => d.status), [
      PlannedDayStatus.missed,
      PlannedDayStatus.missed,
      PlannedDayStatus.planned,
      PlannedDayStatus.planned,
      PlannedDayStatus.planned,
    ]);
  });

  test('classifies a complete day and a partly done day', () {
    final complete = fold({
      for (var unit = 2; unit < 158; unit++) unit: DateTime(2026, 1, 8),
    });
    expect(days(complete).first.status, PlannedDayStatus.done);

    final partial = fold({2: DateTime(2026, 1, 8)});
    expect(days(partial).first.status, PlannedDayStatus.partlyDone);
  });
}
