/// Bidirectional siyum/finish-date engine — the reborn "Calculate" logic.
///
/// Forward:  given a pace, when will I finish?
/// Backward: given a target date, what pace do I need? (the recommendation engine)
///
/// A weekday/Shabbos-aware variant models a different learning amount on Shabbos,
/// matching the legacy app's "advanced" calculation but fed from real remaining
/// counts. All methods are pure; callers pass `from`/`target` explicitly.
class Predictor {
  const Predictor._();

  /// Whole days to finish [remaining] units at [perDay] (> 0). Rounds up.
  static int daysToFinish({required int remaining, required double perDay}) {
    if (remaining <= 0) return 0;
    if (perDay <= 0) return -1; // never
    return (remaining / perDay).ceil();
  }

  /// Projected finish date at a flat [perDay] pace.
  static DateTime? finishDate({
    required int remaining,
    required double perDay,
    required DateTime from,
  }) {
    final days = daysToFinish(remaining: remaining, perDay: perDay);
    if (days < 0) return null;
    return _dayKey(from).add(Duration(days: days));
  }

  /// Units/day required to finish [remaining] by [target] (recommendation).
  /// Returns 0 if already done; `double.infinity` if the target is today/past.
  static double requiredPerDay({
    required int remaining,
    required DateTime from,
    required DateTime target,
  }) {
    if (remaining <= 0) return 0;
    final days = _dayKey(target).difference(_dayKey(from)).inDays;
    if (days <= 0) return double.infinity;
    return remaining / days;
  }

  /// Weekday/Shabbos-aware finish date: [weekdayAmount] on Sun–Fri,
  /// [shabbosAmount] on Shabbos (Saturday). Iterates day by day from [from]
  /// (the first learning day) until [remaining] is exhausted.
  static DateTime? finishDateWithShabbos({
    required int remaining,
    required double weekdayAmount,
    required double shabbosAmount,
    required DateTime from,
  }) {
    if (remaining <= 0) return _dayKey(from);
    final weeklyRate = weekdayAmount * 6 + shabbosAmount;
    if (weeklyRate <= 0) return null; // never

    var left = remaining.toDouble();
    var day = _dayKey(from);
    // Hard cap to avoid pathological loops (~137 years).
    for (var i = 0; i < 50000; i++) {
      final amount =
          day.weekday == DateTime.saturday ? shabbosAmount : weekdayAmount;
      left -= amount;
      if (left <= 0) return day;
      day = day.add(const Duration(days: 1));
    }
    return null;
  }

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
}
