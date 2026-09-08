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