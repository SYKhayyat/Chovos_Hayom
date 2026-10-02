import '../../core/day.dart';
import '../entities/catalog.dart';
import '../entities/layer.dart';
import 'fold_log.dart';
import 'layer_roles.dart';
import 'learning_plan.dart';
import 'plan_run.dart';

/// One unit that is due a review on some day.
///
/// Carries the day it was learned, because "review what you did this week" is a
/// statement about a window and the reader has to be able to say *which* week.
class ReviewDue {
  const ReviewDue({
    required this.nodeId,
    required this.unitIndex,
    this.learnedOn,
  });

  final String nodeId;
  final int unitIndex;

  /// When the unit was learned, or null when the catalog does not have it — a
  /// custom sefer deleted under a plan must not stop the sheet opening.
  final Day? learnedOn;

  @override
  bool operator ==(Object other) =>
      other is ReviewDue &&
      other.nodeId == nodeId &&
      other.unitIndex == unitIndex &&
      other.learnedOn == learnedOn;

  @override
  int get hashCode => Object.hash(nodeId, unitIndex, learnedOn);

  @override
  String toString() => 'ReviewDue($nodeId $unitIndex, learned $learnedOn)';
}

/// When a plan asks to be reviewed.
///
/// **Three forms, and they are the three a person actually says.** A fixed date
/// ("review on 15 Tevet"), a period ("every seven days"), or a weekday (the
/// weekly Shabbos review, and the reason this was asked for at all). A sealed
/// union so "every day of the week and also on the 15th" is not a shape this can
/// hold rather than a thing every call site has to half-enforce.
sealed class ReviewWhen {
  const ReviewWhen();

  /// Whether [day] is a review day for this schedule.
  ///
  /// [reference] is "today", and a schedule that counts from today cannot say
  /// so on its own — **a period measured from nowhere is a period measured from
  /// whichever day you ask about**, which makes every day a review day. It is
  /// passed rather than read from a clock so the question is answerable in a
  /// test, the same reason `parseDateText` takes one.
  bool isReviewDay(Day day, {Day? reference});

  /// A stable name for the stored form, and the only thing [fromJson] accepts
  /// beyond these three.
  String get kind;

  Map<String, dynamic> toJson();
}

/// "Review on this date."
class ReviewOnDate extends ReviewWhen {
  const ReviewOnDate(this.day);

  final Day day;

  @override
  bool isReviewDay(Day other, {Day? reference}) => other == day;

  @override
  String get kind => 'onDate';

  @override
  Map<String, dynamic> toJson() => {'kind': kind, 'day': day.toString()};

  @override
  bool operator ==(Object other) => other is ReviewOnDate && other.day == day;

  @override
  int get hashCode => day.hashCode;

  @override
  String toString() => 'ReviewOnDate($day)';
}

/// "Every *n* days", counted from [from].
///
/// Null [from] means **today**, and is not stored — the same ruling as
/// [LearningPlan.startDay]: a plan created this morning and opened this evening
/// should not mean two different things, and freezing the day would make the
/// second reading a different plan.
class ReviewEveryDays extends ReviewWhen {
  const ReviewEveryDays(this.days, {this.from}) : assert(days > 0);

  final int days;

  /// The day the count starts from, or null for today.
  final Day? from;

  @override
  bool isReviewDay(Day day, {Day? reference}) {
    final start = from ?? reference;
    // **No start and no reference is not a review day**, rather than a day that
    // is one because it was the day asked about. A caller who has no idea what
    // today is has not got an answer, and saying "yes" would be inventing one.
    if (start == null || day < start) return false;
    // By ordinal, not by `.difference()`: the two `Day`s are whole days, so the
    // arithmetic is the same, and `ordinal` is the one that cannot be off by an
    // hour across a daylight-saving boundary.
    return (day.ordinal - start.ordinal) % days == 0;
  }

  @override
  String get kind => 'everyDays';

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'days': days,
    if (from != null) 'from': from.toString(),
  };

  @override
  bool operator ==(Object other) =>
      other is ReviewEveryDays && other.days == days && other.from == from;

  @override
  int get hashCode => Object.hash(days, from);

  @override
  String toString() => 'ReviewEveryDays($days, from: $from)';
}

/// "Review on this weekday" — `DateTime.monday` (1) through
/// `DateTime.sunday` (7), the same numbering `Day.weekday` and the planner's
/// rules use, so nothing has to be converted to compare them.
class ReviewOnWeekday extends ReviewWhen {
  const ReviewOnWeekday(this.weekday);

  final int weekday;

  @override
  bool isReviewDay(Day day, {Day? reference}) => day.weekday == weekday;

  @override
  String get kind => 'onWeekday';

  @override
  Map<String, dynamic> toJson() => {'kind': kind, 'weekday': weekday};

  @override
  bool operator ==(Object other) =>
      other is ReviewOnWeekday && other.weekday == weekday;

  @override
  int get hashCode => weekday.hashCode;

  @override
  String toString() => 'ReviewOnWeekday($weekday)';
}

/// A plan's request to be reviewed: *when*, and *how far back*.
///
/// **Window and schedule together**, because neither means anything without the
/// other — "every seven days" of what?
class PlanReview {
  const PlanReview({required this.windowDays, required this.when});

  /// How many days back the review reaches. 0 is refused at the boundary.
  static const _maxWindow = 3650;

  /// A shorthand for the shape the issue names: everything in the last
  /// [windowDays] days, reviewed on [when].
  factory PlanReview.window(int windowDays, ReviewWhen when) =>
      PlanReview(windowDays: windowDays, when: when);

  final int windowDays;
  final ReviewWhen when;

  Map<String, dynamic> toJson() => {
    'windowDays': windowDays,
    'when': when.toJson(),
  };

  factory PlanReview.fromJson(Map<String, dynamic> json) {
    final window = (json['windowDays'] as num?)?.toInt();
    if (window == null || window < 1 || window > _maxWindow) {
      throw FormatException(
        'review windowDays must be 1..$_maxWindow, got $window',
      );
    }
    return PlanReview(windowDays: window, when: _whenFrom(json['when']));
  }

  static ReviewWhen _whenFrom(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('a review needs a "when"');
    }
    final json = raw.cast<String, dynamic>();
    return switch (json['kind']) {
      'onDate' => ReviewOnDate(Day.of(DateTime.parse(json['day'] as String))),
      'everyDays' => ReviewEveryDays(
        _num(json['days'], 'days'),
        from: json['from'] == null
            ? null
            : Day.of(DateTime.parse(json['from'] as String)),
      ),
      // **The weekday is checked here, not above the switch**, because only this
      // form carries one. Validating it unconditionally refused every other
      // schedule for a field they do not have — which is the same mistake as
      // reading a null as a default.
      'onWeekday' => ReviewOnWeekday(_weekday(json['weekday'])),
      // Refused rather than defaulted. A schedule this build cannot render is
      // not something to guess at: a plan that says "review on the 15th" and
      // quietly reviews on nothing is a plan the user believes is working.
      // Written as a statement because `raw` is dynamic and a switch expression
      // over it cannot be proved exhaustive.
      _ => throw FormatException('unknown review schedule: ${json['kind']}'),
    };
  }

  /// A weekday in the planner's own numbering, refused outside 1..7.
  static int _weekday(Object? raw) {
    final weekday = _num(raw, 'weekday');
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      throw FormatException('review weekday must be 1..7, got $weekday');
    }
    return weekday;
  }

  /// A positive whole number, and the one place it is checked — the same rule
  /// `PlanPacing` and `PlanItem` use for the numbers they hold.
  static int _num(Object? raw, String what) {
    final value = (raw as num?)?.toInt();
    if (value == null) throw FormatException('review $what is missing');
    if (value < 1) {
      throw FormatException('review $what must not be less than 1, got $value');
    }
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is PlanReview &&
      other.windowDays == windowDays &&
      other.when == when;

  @override
  int get hashCode => Object.hash(windowDays, when);

  @override
  String toString() => 'PlanReview($when, last $windowDays days)';
}

/// What a plan asks to be reviewed: a fold over the log, like everything else.
///
/// > on day *x*, everything the plan covered in the last *y* days is due a review.
///
/// **This asks, it does not record.** A review the user did not perform is a
/// write this repository treats very carefully — so the plan says when it would
/// like one back, and the log records the ones that actually happened. There is
/// no stored review date anywhere, which is also what makes the whole question
/// answerable: it is a query, not a schedule to maintain.
class PlanReviewFold {
  const PlanReviewFold._();

  /// Everything [plan] would like reviewed on [day], oldest first.
  ///
  /// Empty when the plan says nothing about review, or [day] is not one of its
  /// review days. **Both are answers rather than gaps**: a plan with no review
  /// schedule has nothing to ask, and a day that is not a review day asks
  /// nothing — which is why this is a fold over one day rather than a list of
  /// pending reviews the app was keeping.
  ///
  /// **Due means learned, inside the window, and never yet reviewed.** A unit
  /// that has had its one review is not asked for a second: the plan asks for a
  /// review of what it covered, not a standing appointment, and a plan that kept
  /// re-asking would turn the report into a to-do list of work already done.
  static List<ReviewDue> dueOn(
    LearningPlan plan,
    Catalog catalog,
    LogFold fold,
    Day day, {
    LayerRoles? layers,
  }) {
    final review = plan.review;
    // `day` is the reference for a schedule that counts from today: this fold
    // asks about a day, and "today" is the day being asked about.
    if (review == null || !review.when.isReviewDay(day, reference: day)) {
      return const [];
    }

    final from = day - review.windowDays;
    final out = <ReviewDue>[];
    for (final range in PlanRange.rangesOf(plan, catalog)) {
      if (range == null) continue;
      for (final (node, unit) in range.walk(catalog)) {
        final required = layers?.requiredFor(node.id) ?? {mainLayerId};
        if (!required.every(fold.completedLayers(node.id, unit).contains)) {
          continue;
        }
        // **Already reviewed, so not due.** [chazaraCount] counts passes as
        // reviews + 1 (#45), so one pass means learned and never returned to.
        if (fold.chazaraCount(node.id, unit) > 1) continue;
        final at = fold.doneAt(node.id, unit);
        if (at == null) continue;
        final learnedOn = Day.of(at);
        // The window is inclusive of its first day and exclusive of today: what
        // you learned *today* has not had a week's chance to settle.
        if (learnedOn < from || learnedOn >= day) continue;
        out.add(
          ReviewDue(nodeId: node.id, unitIndex: unit, learnedOn: learnedOn),
        );
      }
    }
    // **Oldest first**, which is the order a review is done in — and `Day` is
    // already `Comparable` by ordinal, so the window's own ordering is the one
    // used here rather than a second idea of "which day was earlier".
    out.sort((a, b) {
      final byDay = (a.learnedOn?.ordinal ?? 0).compareTo(
        b.learnedOn?.ordinal ?? 0,
      );
      if (byDay != 0) return byDay;
      final byNode = a.nodeId.compareTo(b.nodeId);
      return byNode != 0 ? byNode : a.unitIndex.compareTo(b.unitIndex);
    });
    return out;
  }
}
