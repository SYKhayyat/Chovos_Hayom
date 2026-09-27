import 'learning_plan.dart';
import 'recurrence.dart';

/// What a plan asks for on a given day.
///
/// One job, deliberately in its own type: a plan can now express "ten a day,
/// five on Tuesdays, nothing on the 4th", and the question "what does this day
/// want?" is asked from the calendar, the projection and eventually the day's
/// own screen. Three call sites asking a plan that question is exactly how three
/// different answers get written down.
///
/// **Precedence, most specific first:**
///
///     date override  >  weekday override  >  the plan's base amount
///
/// A date is the most specific statement a user can make, so it wins outright;
/// a weekday is broader; the base is what a day says when nothing else does.
/// Overlapping entries are not conflicts at all — that is the point of a
/// hierarchy — so there is nothing to resolve and nothing to report.
///
/// **An amount of `0` is a real answer, not a missing one.** "Nothing on this
/// day" is how a day off is expressed, and it is what makes the chain
/// `dateAmounts[day] ?? weekdayAmounts[weekday] ?? unitsPerDay` correct with a
/// plain `??`: the lookup asks whether the *key* is present, never whether the
/// *value* is truthy. An implementation that reached for `0` as a sentinel, or
/// used `||` instead of `??`, would quietly turn every day off into an ordinary
/// day at the base amount.
class DayAmount {
  const DayAmount._();

  /// The units [plan] calls for on the day [info] describes.
  static int of(LearningPlan plan, DayInfo info) =>
      plan.dateAmounts[info.day] ??
      plan.weekdayAmounts[info.weekday] ??
      plan.unitsPerDay;
}
