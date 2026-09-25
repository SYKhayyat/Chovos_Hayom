import '../../core/day.dart';
import '../../core/planner_dates.dart';
import '../entities/catalog.dart';
import 'fold_log.dart';
import 'layer_roles.dart';
import 'learning_plan.dart';
import 'plan_completion.dart';

enum PlannedDayStatus { planned, done, partlyDone, missed }

class PlannedDay {
  const PlannedDay({
    required this.day,
    required this.plans,
    required this.status,
  });

  final Day day;
  final List<LearningPlan> plans;
  final PlannedDayStatus status;
}

class PlannerCalendar {
  const PlannerCalendar._();

  static List<PlannedDay> between({
    required List<LearningPlan> plans,
    required Catalog catalog,
    required LogFold fold,
    required Day from,
    required Day to,
    required Day today,
    LayerRoles? layers,
    bool Function(LearningPlan plan, Day day)? isActive,
  }) {
    final out = <PlannedDay>[];
    for (var day = from; day <= to; day += 1) {
      final firing = [
        for (final plan in plans)
          if ((isActive == null || isActive(plan, day)) &&
              PlannerSchedule.assignmentsOn(plan, dayInfoFor(day)).isNotEmpty)
            plan,
      ];
      if (firing.isEmpty) continue;
      final allDone = firing.every(
        (plan) => PlanCompletion.completeBefore(
          plan,
          catalog,
          fold,
          day + 1,
          layers: layers,
        ),
      );
      final anyProgress = firing.any(
        (plan) => PlanCompletion.hasProgress(
          plan,
          catalog,
          fold,
          day + 1,
          layers: layers,
        ),
      );
      final status = allDone
          ? PlannedDayStatus.done
          : day < today
              ? anyProgress
                  ? PlannedDayStatus.partlyDone
                  : PlannedDayStatus.missed
              : PlannedDayStatus.planned;
      out.add(PlannedDay(day: day, plans: firing, status: status));
    }
    return out;
  }
}
