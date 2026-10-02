import 'package:kosher_dart/kosher_dart.dart';

import '../domain/usecases/recurrence.dart';
import 'day.dart';

/// The reader the planner uses: fills a [DayInfo] for a [Day], Hebrew fields
/// included.
///
/// This is the one place the domain's recurrence engine meets the Hebrew
/// calendar. [DayInfo] is pure; the Hebrew fields are kosher_dart's, read off
/// the day's local midnight — the sanctioned "once per distinct day, at the
/// edge" conversion, never inside a loop over the event log. kosher_dart's
/// Hebrew month numbers are the ones [HebrewMonth] names.
DayInfo dayInfoFor(Day day) {
  final midnight = day.midnight;
  final jd = JewishDate.fromDateTime(midnight);
  return DayInfo(
    day: day,
    weekday: day.weekday,
    dayOfMonth: midnight.day,
    hebrewDayOfMonth: jd.getJewishDayOfMonth(),
    hebrewMonth: jd.getJewishMonth(),
    hebrewYear: jd.getJewishYear(),
  );
}

/// How much of the calendar one page shows.
///
/// **A granularity, not a layout.** Each of the three derives its window from an
/// anchor [Day] by the same rule — *the first day of the unit containing it* —
/// and a day range is the degenerate case of that rule rather than a separate
/// path. That is the whole reason the view is anchored on a day (#29) instead of
/// on a month: with one derivation, day, week and month are three arguments to
/// one function instead of three functions agreeing by hand.
enum PlannerCalendarRange {
  day,
  week,
  month;

  /// How many consecutive days one page holds.
  ///
  /// 42 for a month, not "the days in it": the grid is six rows of seven, so
  /// every month is drawn at the same size and the page never changes height as
  /// the arrow moves from a 28-day February to a 31-day March.
  int get dayCount => switch (this) {
    PlannerCalendarRange.day => 1,
    PlannerCalendarRange.week => 7,
    PlannerCalendarRange.month => 42,
  };

  /// The first day of the page that contains [anchor].
  ///
  /// Week and month both align to the **Monday** on or before their first day,
  /// so a week is Monday-to-Sunday and a month grid is six whole weeks rather
  /// than six ragged rows.
  Day startFrom(Day anchor) => switch (this) {
    PlannerCalendarRange.day => anchor,
    PlannerCalendarRange.week => _mondayOnOrBefore(anchor),
    PlannerCalendarRange.month => _mondayOnOrBefore(
      Day.of(DateTime(anchor.midnight.year, anchor.midnight.month, 1)),
    ),
  };

  /// The day a page of this range is **named** by — the date a heading for the
  /// page should print.
  ///
  /// Distinct from [startFrom], and the distinction is the whole reason a month
  /// heading has to be computed separately. A month page opens on the Monday
  /// *before* the 1st, because six rows of seven have to be filled from
  /// somewhere; printing that as the month's name puts "2025-12-29" over
  /// January, which is a heading about December sitting above January. So the
  /// page starts on the padding day and the range is named by its own first
  /// day, and a week — which has no padding to begin with — is the same value
  /// in both.
  Day namedDay(Day anchor) => switch (this) {
    PlannerCalendarRange.day => anchor,
    PlannerCalendarRange.week => _mondayOnOrBefore(anchor),
    PlannerCalendarRange.month => Day.of(
      DateTime(anchor.midnight.year, anchor.midnight.month, 1),
    ),
  };

  /// The anchor a page [delta] steps away should hold, so that
  /// `startFrom(step(anchor, d))` is the window [delta] pages on.
  ///
  /// Two properties are worth stating, because the second is the one that is easy
  /// to get wrong. First, it is an involution: stepping out and back returns the
  /// anchor you started from, so the arrows are not a one-way ratchet. Second,
  /// each step starts from the **unit's own first day** rather than from
  /// wherever the anchor happened to sit inside it — which is why stepping a
  /// month from the 31st lands on the 1st of the next month and not on the 3rd
  /// of the one after.
  Day step(Day anchor, int delta) => switch (this) {
    PlannerCalendarRange.day => anchor + delta,
    PlannerCalendarRange.week => _mondayOnOrBefore(anchor) + (delta * 7),
    PlannerCalendarRange.month => _addMonths(
      Day.of(DateTime(anchor.midnight.year, anchor.midnight.month, 1)),
      delta,
    ),
  };

  /// [anchor] shifted by [delta] months, clamped to the target month's length.
  ///
  /// The clamp is not reachable from [step] any more — it starts from the 1st,
  /// which every month has — and it stays because this is the general form of
  /// "shift a date by whole months", which a caller with a real day-of-month
  /// still needs and which silently spills into the following month otherwise.
  static Day _addMonths(Day anchor, int delta) {
    final d = anchor.midnight;
    final firstOfTarget = DateTime(d.year, d.month + delta, 1);
    final lastDay = DateTime(
      firstOfTarget.year,
      firstOfTarget.month + 1,
      0,
    ).day;
    return Day.of(
      DateTime(
        firstOfTarget.year,
        firstOfTarget.month,
        d.day <= lastDay ? d.day : lastDay,
      ),
    );
  }

  static Day _mondayOnOrBefore(Day day) => day - (day.weekday - 1);
}

/// The [dayCount] consecutive days a page holds, starting at [start].
///
/// Returned as a list rather than a count so a caller cannot ask for "42 days
/// from March" — the caller asks for the days a page *has*, and the length is
/// the range's to decide.
List<Day> calendarWindow(Day anchor, PlannerCalendarRange range) => [
  for (var i = 0; i < range.dayCount; i++) range.startFrom(anchor) + i,
];
