import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/usecases/day_amount.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:chovos_hayom/domain/usecases/spillover.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a plan does about a day it did not finish (#25).
///
/// The three modes are one question — where does the shortfall go? — answered in
/// units (`catchUp`) or in days (`slide`) or not at all (`ignore`). The test that
/// matters most is the contrast between the two active ones: a plan that catches
/// up finishes on time and has a heavy day; a plan that slides finishes late and
/// never has a heavy day. Anything that made them behave alike would be the whole
/// feature silently doing nothing.
void main() {
  // Day(0) is 1970-01-01, a Thursday.
  const thursday = Day(0);
  const friday = Day(1);
  const sunday = Day(3);
  const monday = Day(4);

  DayInfo info(Day day) =>
      DayInfo(day: day, weekday: day.weekday, dayOfMonth: day.midnight.day);

  LearningPlan plan({
    int unitsPerDay = 10,
    Map<int, int> weekdayAmounts = const {},
    Map<Day, int> dateAmounts = const {},
    SpilloverMode spillover = SpilloverMode.ignore,
  }) => LearningPlan(
    id: 'p',
    name: 'P',
    unitsPerDay: unitsPerDay,
    weekdayAmounts: weekdayAmounts,
    dateAmounts: dateAmounts,
    spillover: spillover,
  );

  List<ScheduledDay> walk(
    LearningPlan p, {
    int owedAtStart = 0,
    int Function(Day day) doneOn = _none,
    Day from = thursday,
    Day to = monday,
  }) => PlanSchedule.walk(
    p,
    info: info,
    from: from,
    to: to,
    owedAtStart: owedAtStart,
    doneOn: doneOn,
  );

  group('the three modes are genuinely different', () {
    test('ignore: a missed day changes nothing downstream', () {
      // Nothing is done at all, so after four days the plan is still asking 10
      // and the balance is still climbing. The schedule never reacts.
      final days = walk(plan(spillover: SpilloverMode.ignore));
      expect(days.map((d) => d.amount), [10, 10, 10, 10, 10]);
      expect(days.last.owedLeaving, 50);
    });

    test('catchUp: a later day asks for the backlog as well as its own', () {
      // Nothing done: Thursday asks 10, Friday asks 10 + the 10 still owed.
      // Linear, not compounding — see the note on the shortfall in `walk`.
      final days = walk(plan(spillover: SpilloverMode.catchUp));
      expect(days.map((d) => d.amount), [10, 20, 30, 40, 50]);
      expect(days.map((d) => d.owedLeaving), [10, 20, 30, 40, 50]);
    });

    test('catchUp does not compound the backlog it is already carrying', () {
      // The regression this pins: if a day that already asked for the backlog
      // also added the old debt to it, the balance would double every day and a
      // plan that had learned *nothing* would be demanding 160 units on day
      // five. The invariant is that the amount a day asks is the base plus what
      // was owed *when it started*, never a function of what it then owes.
      final days = walk(plan(spillover: SpilloverMode.catchUp));
      for (final d in days) {
        expect(
          d.amount,
          d.base + d.owedEntering,
          reason: '$d asked for more than its base plus its opening debt',
        );
      }
      expect(
        days.last.amount,
        lessThan(100),
        reason: 'a linear catch-up of ten a day cannot reach 160',
      );
    });

    test('slide: daily amounts never grow, unlike catchUp', () {
      final days = walk(plan(spillover: SpilloverMode.slide));
      expect(
        days.map((d) => d.amount),
        [10, 10, 10, 10, 10],
        reason: 'the shortfall delays the timeline, it does not enlarge days',
      );
      expect(
        days.last.owedLeaving,
        50,
        reason: 'but the debt is still tracked',
      );
    });

    test(
      'ignore and slide ask the same amount — the difference is the lag',
      () {
        expect(
          PlanSchedule.amountFor(
            mode: SpilloverMode.ignore,
            base: 10,
            owed: 40,
          ),
          10,
        );
        expect(
          PlanSchedule.amountFor(mode: SpilloverMode.slide, base: 10, owed: 40),
          10,
        );
        // ...and only slide expresses it as a delay.
        expect(
          PlanSchedule.lagDays(
            mode: SpilloverMode.slide,
            owed: 40,
            unitsPerDay: 10,
          ),
          4,
        );
        expect(
          PlanSchedule.lagDays(
            mode: SpilloverMode.ignore,
            owed: 40,
            unitsPerDay: 10,
          ),
          0,
        );
      },
    );
  });

  group('catchUp versus slide: the same shortfall, spent differently', () {
    // Ten units a day, nothing learned at all, five days. Every mode ends the
    // window owing 50 — the log is the same in all three. What differs is what
    // the plan asked for along the way and whether it is also late.
    test('catchUp spends the shortfall by asking for more', () {
      final days = walk(plan(spillover: SpilloverMode.catchUp));
      expect(days.map((d) => d.amount), [10, 20, 30, 40, 50]);
      expect(days.last.owedLeaving, 50, reason: 'the debt is unchanged');
      // The whole cost is heavier days, and no delay.
      expect(
        PlanSchedule.lagDays(
          mode: SpilloverMode.catchUp,
          owed: 50,
          unitsPerDay: 10,
        ),
        0,
      );
    });

    test('slide spends it by being late, and never asks for more', () {
      final days = walk(plan(spillover: SpilloverMode.slide));
      expect(days.map((d) => d.amount), [10, 10, 10, 10, 10]);
      expect(days.last.owedLeaving, 50, reason: 'the debt is unchanged');
      // Fifty units behind at ten a day is five days late.
      expect(
        PlanSchedule.lagDays(
          mode: SpilloverMode.slide,
          owed: 50,
          unitsPerDay: 10,
        ),
        5,
      );
    });

    test('ignore spends it nowhere at all', () {
      final days = walk(plan(spillover: SpilloverMode.ignore));
      expect(days.map((d) => d.amount), [10, 10, 10, 10, 10]);
      expect(days.last.owedLeaving, 50);
      // Neither a heavier day nor a delay: the plan is simply a plan.
      expect(
        PlanSchedule.lagDays(
          mode: SpilloverMode.ignore,
          owed: 50,
          unitsPerDay: 10,
        ),
        0,
      );
    });

    test(
      'so catchUp is distinguished from the other two by asking for more',
      () {
        final catchUp = walk(plan(spillover: SpilloverMode.catchUp));
        final others = [
          SpilloverMode.slide,
          SpilloverMode.ignore,
        ].map((m) => walk(plan(spillover: m)));
        for (final day in others) {
          expect(
            day.map((d) => d.amount),
            catchUp.map((d) => d.base),
            reason: 'no mode but catchUp should enlarge a day',
          );
        }
      },
    );
  });

  group('a day off creates no debt', () {
    test('an amount of 0 neither grows nor shrinks the balance', () {
      // The whole reason there is no day-off flag: a rest day asks for nothing,
      // so it must not be read as a day that was missed.
      final p = plan(
        unitsPerDay: 10,
        dateAmounts: {friday: 0},
        spillover: SpilloverMode.catchUp,
      );
      final days = walk(p, doneOn: (day) => day == thursday ? 10 : 0);
      expect(days[0].base, 10);
      expect(days[0].amount, 10);
      expect(days[0].owedLeaving, 0, reason: 'Thursday was done');
      // Friday is a day off: 0 asked, 0 owed, and crucially Saturday is not
      // asked to make up for a "missed" rest day.
      expect(days[1].base, 0);
      expect(days[1].amount, 0);
      expect(days[1].owedEntering, 0);
      expect(days[1].owedLeaving, 0);
      expect(days[2].amount, 10, reason: 'no phantom debt from the day off');
    });

    test('a weekday amount of 0 rests that weekday, adding no debt of its own', () {
      // With catchUp and nothing done, Sunday still carries the backlog that
      // Thursday-Saturday created — a rest day is not a day off from catching up.
      // What it must not do is *add* anything: the balance entering and leaving
      // Sunday is the same number.
      final p = plan(
        unitsPerDay: 10,
        weekdayAmounts: {DateTime.sunday: 0},
        spillover: SpilloverMode.catchUp,
      );
      final days = walk(p);
      final sundayDay = days.firstWhere((d) => d.day == sunday);
      expect(DayAmount.of(p, info(sunday)), 0, reason: 'the base is a rest');
      expect(sundayDay.base, 0);
      expect(
        sundayDay.owedEntering,
        sundayDay.owedLeaving,
        reason:
            'a rest day adds no debt — it only carries what was already there',
      );
    });
  });

  group('the balance', () {
    test('over-delivering on a day does not create a credit', () {
      // Done 15 against a plan of 10. The extra five are not a debt the plan can
      // be finished early with: the plan asks for what it asks for.
      final days = walk(
        plan(spillover: SpilloverMode.catchUp),
        doneOn: (day) => day == thursday ? 15 : 0,
      );
      expect(days.first.owedLeaving, 0, reason: 'clamped, never negative');
    });

    test('a negative starting balance is treated as none owed', () {
      final days = walk(plan(), owedAtStart: -5);
      expect(days.first.owedEntering, 0);
    });

    test('an empty window yields nothing', () {
      expect(walk(plan(), from: thursday, to: thursday - 1), isEmpty);
    });
  });

  group('lagDays', () {
    test('a shortfall of exactly a day is one day of lag', () {
      expect(
        PlanSchedule.lagDays(
          mode: SpilloverMode.slide,
          owed: 10,
          unitsPerDay: 10,
        ),
        1,
      );
    });

    test('a partial shortfall still costs a whole day', () {
      // Four units short at ten a day is not 0.4 days of delay — a plan that
      // owes anything is a day late, because a day is the smallest thing the
      // calendar can express.
      expect(
        PlanSchedule.lagDays(
          mode: SpilloverMode.slide,
          owed: 4,
          unitsPerDay: 10,
        ),
        1,
      );
    });

    test('nothing owed, or no rate, is no lag', () {
      expect(
        PlanSchedule.lagDays(
          mode: SpilloverMode.slide,
          owed: 0,
          unitsPerDay: 10,
        ),
        0,
      );
      expect(
        PlanSchedule.lagDays(
          mode: SpilloverMode.slide,
          owed: 10,
          unitsPerDay: 0,
        ),
        0,
      );
    });
  });

  group('persistence', () {
    test('the mode round-trips', () {
      for (final mode in SpilloverMode.values) {
        expect(
          LearningPlan.fromJson(plan(spillover: mode).toJson()).spillover,
          mode,
        );
      }
    });

    test('a plan with no mode is the default', () {
      expect(
        LearningPlan.fromJson({'id': 'p', 'name': 'P'}).spillover,
        SpilloverMode.ignore,
      );
    });

    test('an unknown mode falls back to ignore rather than throwing', () {
      // A plan is a schedule, and an unreadable setting must not make it
      // un-openable; `ignore` is the one mode that changes no dates.
      expect(
        LearningPlan.fromJson({
          'id': 'p',
          'name': 'P',
          'spillover': 'nope',
        }).spillover,
        SpilloverMode.ignore,
      );
    });

    test('the mode participates in equality', () {
      expect(plan(), plan());
      expect(plan(), isNot(plan(spillover: SpilloverMode.slide)));
    });
  });
}

int _none(Day day) => 0;
