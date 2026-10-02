import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/plan_review.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

/// #50, part 2 — a plan that asks to be reviewed.
///
/// > on day *x*, everything the plan covered in the last *y* days is due a review.
///
/// **Which needs no stored state at all**, and that is the whole design: it is a
/// query over the log on the same terms as everything else here. There is no
/// review date to write and none to keep in step.
var _seq = 0;

LearningEvent done(String node, int unit, Day day) => LearningEvent(
  id: 'e${_seq++}',
  profileId: 'p',
  nodeId: node,
  unitIndex: unit,
  action: EventAction.done,
  occurredAt: day.midnight,
  loggedAt: day.midnight,
);

LearningEvent reviewed(String node, int unit, Day day) => LearningEvent(
  id: 'r${_seq++}',
  profileId: 'p',
  nodeId: node,
  unitIndex: unit,
  action: EventAction.reviewed,
  occurredAt: day.midnight,
  loggedAt: day.midnight,
);

/// A Saturday, so the weekday rule has something to bite on.
final sabbath = Day.of(DateTime.utc(2026, 3, 14));

final catalog = Catalog([
  const CatalogNode(
    id: 'root',
    parentId: null,
    name: 'Root',
    kind: NodeKind.category,
  ),
  const CatalogNode(
    id: 's',
    parentId: 'root',
    name: 'S',
    kind: NodeKind.leaf,
    unitLabel: UnitLabel.daf,
    unitCount: 10,
    unitOffset: 2,
  ),
]);

LearningPlan plan({PlanReview? review, int startUnit = 2, int endUnit = 11}) =>
    LearningPlan(
      id: 'p',
      name: 'P',
      unitsPerDay: 2,
      items: [
        PlanItem(id: 'i1', nodeId: 's', startUnit: startUnit, endUnit: endUnit),
      ],
      assignments: const [PlanAssignment(id: 'a', rule: DailyRule())],
      review: review,
    );

List<ReviewDue> dueOn(LearningPlan p, LogFold fold, Day day) =>
    PlanReviewFold.dueOn(p, catalog, fold, day);

/// The weekly Shabbos review — the schedule the issue names, named once so the
/// tests read as "a seven-day window reviewed each Saturday".
ReviewWhen onWeekday() => const ReviewOnWeekday(DateTime.saturday);

void main() {
  setUp(() => _seq = 0);

  group('when a review falls', () {
    test('on a named date, only on that date', () {
      final when = ReviewOnDate(sabbath);
      expect(when.isReviewDay(sabbath), isTrue);
      expect(when.isReviewDay(sabbath + 1), isFalse);
      expect(when.isReviewDay(sabbath - 1), isFalse);
    });

    test('every n days, counted from a start', () {
      final when = ReviewEveryDays(7, from: sabbath);
      expect(when.isReviewDay(sabbath), isTrue);
      expect(when.isReviewDay(sabbath + 7), isTrue);
      expect(when.isReviewDay(sabbath + 8), isFalse);
      expect(
        when.isReviewDay(sabbath - 1),
        isFalse,
        reason: 'and never before it began',
      );
    });

    test('every n days with no start is measured from today', () {
      // **Null means today, and is not stored** — the same ruling as
      // `LearningPlan.startDay`, so "begins when I made it" stays true rather
      // than freezing the day and making the second reading a different plan.
      const when = ReviewEveryDays(3);
      expect(when.from, isNull);
      final now = Day.of(DateTime.utc(2026, 3, 10));
      expect(when.isReviewDay(now, reference: now), isTrue);
      expect(when.isReviewDay(now + 3, reference: now), isTrue);
      expect(when.isReviewDay(now + 1, reference: now), isFalse);
      expect(
        when.isReviewDay(now, reference: null),
        isFalse,
        reason:
            'a period measured from nowhere would otherwise be measured from '
            'whichever day was asked about, making every day a review day',
      );
    });

    test('on a weekday', () {
      const when = ReviewOnWeekday(DateTime.saturday);
      expect(when.isReviewDay(sabbath), isTrue);
      expect(when.isReviewDay(sabbath + 7), isTrue);
      expect(when.isReviewDay(sabbath + 1), isFalse);
    });

    test('every n days refuses a non-positive count at the boundary', () {
      // **Refused where it is stored, not only by an assert.** A period of zero
      // would fire on every day and a negative one on none, and an assert is
      // compiled out of a release build — so the check that matters is the one
      // on the way in from JSON, like every other number the planner holds.
      expect(
        () => PlanReview.fromJson({
          'windowDays': 7,
          'when': {'kind': 'everyDays', 'days': 0},
        }),
        throwsFormatException,
      );
      expect(
        () => PlanReview.fromJson({
          'windowDays': 7,
          'when': {'kind': 'everyDays', 'days': -1},
        }),
        throwsFormatException,
      );
      // And the window itself is checked, because a zero-day window would claim
      // to review nothing and still show a review day.
      expect(
        () => PlanReview.fromJson({
          'windowDays': 0,
          'when': {'kind': 'onWeekday', 'weekday': 6},
        }),
        throwsFormatException,
      );
    });
  });

  group('what is due on a review day', () {
    test('nothing on a day that is not a review day', () {
      final fold = FoldLog.fold([done('s', 2, sabbath - 2)]);
      expect(
        dueOn(
          plan(review: PlanReview.window(7, onWeekday())),
          fold,
          sabbath + 1,
        ),
        isEmpty,
      );
    });

    test('a unit learned inside the window, and not yet reviewed', () {
      final fold = FoldLog.fold([done('s', 2, sabbath - 2)]);
      final due = dueOn(
        plan(review: PlanReview.window(7, onWeekday())),
        fold,
        sabbath,
      );
      expect(due.map((d) => d.unitIndex), [2]);
    });

    test('a unit learned outside the window is not due', () {
      // **The window is the point of the feature.** "Everything planned in the
      // last y days" — a daf learned a year ago has had its chazara long since.
      final fold = FoldLog.fold([done('s', 2, sabbath - 40)]);
      expect(
        dueOn(plan(review: PlanReview.window(7, onWeekday())), fold, sabbath),
        isEmpty,
      );
    });

    test('a unit already reviewed once is not due again', () {
      final fold = FoldLog.fold([
        done('s', 2, sabbath - 2),
        reviewed('s', 2, sabbath - 1),
      ]);
      expect(
        dueOn(plan(review: PlanReview.window(7, onWeekday())), fold, sabbath),
        isEmpty,
        reason:
            'the plan asks for one review of it, not a standing appointment. A '
            'plan that kept re-asking would make the report a to-do list of '
            'work already done',
      );
    });

    test('a unit not yet learned is not due', () {
      expect(
        dueOn(
          plan(review: PlanReview.window(7, onWeekday())),
          FoldLog.fold([]),
          sabbath,
        ),
        isEmpty,
      );
    });

    test('the window counts calendar days, on every plan', () {
      // **Decided here rather than inherited.** A plan whose *rule* is written in
      // the Hebrew calendar still asks for a window of days, and a Hebrew month
      // is 29 or 30 of them. Making the window Hebrew for those plans and
      // Gregorian for the rest would be a difference nobody would notice until a
      // unit sat due for two weeks, so the window is calendar days for everyone
      // and the rule calendar governs only which days the plan fires on.
      final fold = FoldLog.fold([done('s', 2, sabbath - 8)]);
      expect(
        dueOn(plan(review: PlanReview.window(7, onWeekday())), fold, sabbath),
        isEmpty,
        reason: 'eight days back is outside a seven-day window',
      );
    });
  });

  group('and it asks rather than records', () {
    test('computing what is due writes nothing', () {
      final fold = FoldLog.fold([done('s', 2, sabbath - 2)]);
      final before = fold.reviewCount('s', 2);
      dueOn(plan(review: PlanReview.window(7, onWeekday())), fold, sabbath);
      expect(
        fold.reviewCount('s', 2),
        before,
        reason:
            'a review the user did not perform is a write this repository '
            'treats very carefully; the plan asks, and the log records what '
            'actually happened',
      );
    });
  });

  group('a plan that says nothing about review', () {
    test('never has anything due', () {
      final fold = FoldLog.fold([done('s', 2, sabbath - 2)]);
      expect(
        dueOn(plan(), fold, sabbath),
        isEmpty,
        reason: 'the absence of a schedule is a real answer, not a default one',
      );
    });
  });

  group('two plans covering one unit', () {
    test('the unit is due once, not twice', () {
      // **One unit is one unit.** The same daf covered by two plans is still one
      // thing to come back to, and listing it twice would double-count the work
      // and make a two-plan day look like a backlog.
      final fold = FoldLog.fold([done('s', 2, sabbath - 2)]);
      final a = plan(review: PlanReview.window(7, onWeekday()));
      final b = LearningPlan(
        id: 'q',
        name: 'Q',
        unitsPerDay: 1,
        items: const [PlanItem(id: 'i1', nodeId: 's')],
        assignments: const [PlanAssignment(id: 'a', rule: DailyRule())],
        review: PlanReview.window(7, onWeekday()),
      );
      final both = {
        ...PlanReviewFold.dueOn(a, catalog, fold, sabbath),
        ...PlanReviewFold.dueOn(b, catalog, fold, sabbath),
      };
      expect(
        both.where((d) => d.nodeId == 's' && d.unitIndex == 2),
        hasLength(1),
      );
    });
  });

  group('the schedule round-trips', () {
    test('through JSON, and an unknown kind is refused', () {
      for (final review in [
        PlanReview.window(7, onWeekday()),
        PlanReview.window(30, const ReviewOnDate(Day(1))),
        PlanReview.window(1, ReviewEveryDays(7, from: sabbath)),
      ]) {
        final p = plan(review: review);
        expect(LearningPlan.fromJson(p.toJson()).review, review);
        expect(p, plan(review: review));
      }
      expect(
        () => PlanReview.fromJson({
          'windowDays': 7,
          'when': {'kind': 'whenever'},
        }),
        throwsFormatException,
      );
    });
  });

  group('the values are value types', () {
    test('equal schedules collapse in a set, which needs hashCode', () {
      // `==` alone is not enough to be a set member, and a type that compares
      // equal but hashes differently is one of the silent ones: anything keyed on
      // it would keep a stale copy per rebuild.
      for (final review in [
        PlanReview.window(7, onWeekday()),
        PlanReview.window(30, const ReviewOnDate(Day(1))),
        PlanReview.window(1, ReviewEveryDays(7, from: sabbath)),
      ]) {
        final same = PlanReview.fromJson(review.toJson());
        expect(same, review);
        expect(same.hashCode, review.hashCode);
        expect({review, same}, hasLength(1), reason: '$review');
        expect(review.toString(), contains('last ${review.windowDays} days'));
      }
    });

    test('and each field is part of what makes them equal', () {
      expect(
        PlanReview.window(7, onWeekday()),
        isNot(PlanReview.window(8, onWeekday())),
      );
      expect(
        PlanReview.window(7, onWeekday()),
        isNot(PlanReview.window(7, const ReviewOnWeekday(DateTime.friday))),
      );
      expect(
        ReviewEveryDays(7, from: sabbath),
        isNot(ReviewEveryDays(7, from: sabbath + 1)),
      );
      expect(const ReviewOnDate(Day(1)), isNot(const ReviewOnDate(Day(2))));
      expect(const ReviewOnWeekday(6), isNot(const ReviewOnWeekday(5)));
      expect(const ReviewOnDate(Day(1)).toString(), contains('ReviewOnDate'));
      expect(const ReviewEveryDays(3).toString(), contains('ReviewEveryDays'));
      expect(const ReviewOnWeekday(6).toString(), contains('ReviewOnWeekday'));
    });

    test('a due unit is identified by its node, unit and day', () {
      // **Built by a call, not two `const`s.** Two identical consts are equal
      // before the test runs, so the analyzer folds the set literal and the
      // assertion would be testing the compiler rather than `hashCode`.
      ReviewDue build() => ReviewDue(
        nodeId: 's',
        unitIndex: 2,
        learnedOn: Day.of(DateTime(2026, 1, 5)),
      );
      final a = build();
      final same = build();
      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect({a, same}, hasLength(1));
      expect(a, isNot(const ReviewDue(nodeId: 's', unitIndex: 3)));
      expect(a.toString(), contains('ReviewDue'));
      // A unit whose sefer the catalog no longer has still prints.
      expect(
        const ReviewDue(nodeId: 'gone', unitIndex: 2).toString(),
        contains('gone'),
      );
    });
  });
}
