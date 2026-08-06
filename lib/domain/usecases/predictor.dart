import '../../core/day.dart';

/// Bidirectional siyum/finish-date engine — the reborn "Calculate" logic.
///
/// Forward:  given a pace, when will I finish?
/// Backward: given a target date, what pace do I need? (the recommendation engine)
///
/// A weekday/Shabbos-aware variant models a different learning amount on Shabbos,
/// matching the legacy app's "advanced" calculation but fed from real remaining
/// counts. All methods are pure; callers pass `from`/`target` explicitly.
///
/// **Everything here is in [Day], in and out.** This engine used to speak local
/// midnight `DateTime`s — it was the only part of the app that did, while four
/// other files worked in day ordinals and re-ordinalised whatever it returned.
/// The mismatch was not academic: projecting a finish date meant adding a
/// `Duration(days:)` to a local `DateTime`, which shifts by an hour across a
/// DST boundary, so a projection that crossed one landed on 23:00 of the day
/// before and every reader that re-normalised it read the wrong day.
class Predictor {
  const Predictor._();

  /// How far ahead a finish date is worth predicting: ~547 years past [from].
  ///
  /// Beyond this the honest answer is "not at this pace" rather than a date in
  /// the fourth millennium, so every method here returns null past it.
  ///
  /// One constant, shared, because this used to be an *iteration cap* and there
  /// were two of them — 200,000 in the cycle walk, 50,000 in the Shabbos one —
  /// which meant the same pace could be "never" to one method and a date to
  /// another, and a flat pace had no cap at all: the dashboard would happily
  /// project the year 3027 while the calculator said the same rate never
  /// finishes.
  static const maxHorizonDays = 200000;

  /// Slack for comparing an accumulated total against [remaining].
  ///
  /// A cycle of `0.1` cannot be summed exactly in binary, and without this a
  /// residue of 1e-17 pushes the answer a whole day out. Nine decimal places of
  /// a daf is not a quantity anyone is tracking.
  static const _epsilon = 1e-9;

  /// Whole days to finish [remaining] units at [perDay] (> 0). Rounds up.
  static int daysToFinish({required int remaining, required double perDay}) {
    if (remaining <= 0) return 0;
    if (perDay <= 0) return -1; // never
    return (remaining / perDay).ceil();
  }

  /// Projected finish date at a flat [perDay] pace.
  ///
  /// [from] counts as the first learning day — the same convention as
  /// [finishDateWithCycle] and [finishDateWithShabbos] — so a flat pace and an
  /// equivalent length-1 cycle predict the *same* date (they previously differed
  /// by a day, giving the Calculator and Dashboard two answers for one pace).
  static Day? finishDate({
    required int remaining,
    required double perDay,
    required Day from,
  }) {
    final days = daysToFinish(remaining: remaining, perDay: perDay);
    if (days < 0) return null;
    if (days == 0) return from;
    // Same horizon as the cycle version, measured the same way (days *after*
    // `from`), so a flat pace and its length-1 cycle agree about "never" as well
    // as about every date.
    if (days - 1 > maxHorizonDays) return null;
    return from + (days - 1);
  }

  /// Units/day required to finish [remaining] by [target] (recommendation).
  /// Returns 0 if already done; `double.infinity` if the target is today/past.
  static double requiredPerDay({
    required int remaining,
    required Day from,
    required Day target,
  }) {
    if (remaining <= 0) return 0;
    final days = target.difference(from);
    if (days <= 0) return double.infinity;
    return remaining / days;
  }

  /// Weekday/Shabbos-aware finish date: [weekdayAmount] on Sun–Fri,
  /// [shabbosAmount] on Shabbos (Saturday), starting on [from] (the first
  /// learning day).
  ///
  /// This *is* a 7-day cycle, so it is one — built aligned to [from]'s weekday
  /// and handed to [finishDateWithCycle]. It used to be a second day-by-day walk
  /// with its own cap and its own off-by-one risk; two implementations of one
  /// calculation is how they came to disagree about when a pace never finishes.
  static Day? finishDateWithShabbos({
    required int remaining,
    required double weekdayAmount,
    required double shabbosAmount,
    required Day from,
  }) {
    return finishDateWithCycle(
      remaining: remaining,
      amounts: [
        for (var i = 0; i < 7; i++)
          (from + i).weekday == DateTime.saturday
              ? shabbosAmount
              : weekdayAmount,
      ],
      startIndex: 0,
      from: from,
    );
  }

  /// Finish date under a repeating [amounts] cycle of any length, where
  /// [startIndex] is the cycle position of [from] (0-based, e.g. day 4 of a
  /// 7-day cycle -> 3). Generalises the flat ([amounts] of length 1) and
  /// weekday/Shabbos (length 7) cases. Returns null if the cycle never
  /// progresses (all amounts <= 0) or if the answer is past [maxHorizonDays].
  ///
  /// **Cost is the length of the cycle, not the length of the answer.** This
  /// walked one day at a time, allocating a `DateTime` per day, up to 200,000
  /// times — and it ran inside `CalculatorScreen.build`, off the text field, on
  /// every keystroke. Typing `0.05` into "amount per day" therefore cost ~80 ms
  /// per character on a phone (measured, AOT; ~3 s in the test VM) before
  /// answering "you will never finish". Nothing about a repeating cycle needs
  /// iterating: the whole cycles are one division, and only the remainder — at
  /// most one cycle — has to be walked.
  static Day? finishDateWithCycle({
    required int remaining,
    required List<double> amounts,
    required int startIndex,
    required Day from,
  }) {
    if (remaining <= 0) return from;
    final n = amounts.length;
    if (n == 0) return null;

    // Rotated so index 0 is [from], and clamped: a negative amount means "did
    // not learn", never "un-learned", which is what the old `if (amt > 0)`
    // guard was doing one day at a time.
    final start = ((startIndex % n) + n) % n;
    final perDay = [
      for (var i = 0; i < n; i++)
        amounts[(start + i) % n] > 0 ? amounts[(start + i) % n] : 0.0,
    ];
    var cycleSum = 0.0;
    for (final a in perDay) {
      cycleSum += a;
    }
    if (cycleSum <= 0) return null; // never progresses

    // The largest number of whole cycles that still leaves something to learn.
    // Checked against the horizon *before* multiplying by the cycle length, so a
    // hopeless pace costs one division rather than 27 million iterations.
    final wholeCycles = (remaining / cycleSum).ceil() - 1;
    if (wholeCycles > maxHorizonDays) return null;

    var offset = wholeCycles > 0 ? wholeCycles * n : 0;
    var left = remaining - (wholeCycles > 0 ? wholeCycles * cycleSum : 0);
    // At most one cycle is left by construction; the second time round is there
    // only so a floating-point residue cannot walk off the end of the list.
    for (var i = 0; i < 2 * n; i++) {
      left -= perDay[i % n];
      if (left <= _epsilon) {
        return offset > maxHorizonDays ? null : from + offset;
      }
      offset++;
    }
    return null;
  }
}
