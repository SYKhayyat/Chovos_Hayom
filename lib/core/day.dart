/// A calendar day — the day a person would say they learned something on, in
/// whatever timezone they are standing in.
///
/// **Why this is a type and not a helper function.** "Which calendar day is
/// this" was answered nine times across eight files, in two conventions that do
/// not agree. Four files carried a byte-identical private `_dayNumber` (a UTC
/// whole-day ordinal); `Predictor` carried `_dayKey` (a local midnight
/// `DateTime`); and four more sites reached for `a.difference(b).inDays`
/// freehand. Every copy was correct in isolation. The seam between them was
/// not: `Predictor.finishDate` returned a local `DateTime` that all four
/// ordinal files would immediately re-ordinalise, and nothing anywhere pinned
/// the two conventions to each other.
///
/// **The convention that lost, and why.** A local midnight `DateTime` looks
/// like the obvious representation of a day and is a trap, because the two
/// operations you actually want on a day are the two that a local `DateTime`
/// gets wrong twice a year:
///
/// ```dart
/// DateTime(2026, 3, 8).add(const Duration(days: 1))   // 2026-03-09 01:00 — not midnight
/// DateTime(2026, 3, 9).difference(DateTime(2026, 3, 8)).inDays  // 0 — not 1
/// ```
///
/// `Duration` is absolute elapsed time; a calendar day is 23, 24 or 25 hours of
/// it. So "one day later" and "how many days apart" are *integer* operations on
/// a day count, and they only stay integer if the day count is the thing being
/// stored. That is [ordinal], and it is why this type holds an `int` and not a
/// `DateTime`.
///
/// **The one expensive operation is at the boundary, on purpose.** Building a
/// *local* `DateTime` forces a timezone conversion, ~230× the cost of the UTC
/// form, and the day-grouping helpers used to build one per event — a
/// multi-year user paid about a second of it opening the Statistics screen.
/// Grouping happens on [ordinal] (an `int` key, with real `==`/`hashCode`, so
/// a `Map<Day, …>` is as cheap as a `Map<int, …>`), and [midnight] is called
/// once per *distinct day*, only where a `DateTime` has to leave for display.
class Day implements Comparable<Day> {
  /// Wraps a raw whole-day [ordinal]. Prefer [Day.of]; this is for arithmetic
  /// results and for tests that want to name a specific ordinal.
  const Day(this.ordinal);

  /// The calendar day that contains [moment], read in [moment]'s own timezone.
  ///
  /// Routed through `DateTime.utc` so the result is a pure function of the
  /// (year, month, day) fields and nothing else — no offset, no DST, no
  /// dependence on the host's zone.
  factory Day.of(DateTime moment) =>
      Day(DateTime.utc(moment.year, moment.month, moment.day)
              .millisecondsSinceEpoch ~/
          _msPerDay);

  static const _msPerDay = 86400000;

  /// Whole days since 1970-01-01. The identity of the day, and the only field.
  final int ordinal;

  /// Local midnight at the start of this day — the boundary back to `DateTime`,
  /// for display, for date pickers, and for comparing against an instant.
  ///
  /// The expensive direction (see the class doc). Call it once per distinct
  /// day, at the edge; never inside a loop over the event log.
  DateTime get midnight {
    final utc = DateTime.fromMillisecondsSinceEpoch(ordinal * _msPerDay,
        isUtc: true);
    return DateTime(utc.year, utc.month, utc.day);
  }

  /// Day of the week, `DateTime.monday`..`DateTime.sunday`.
  ///
  /// Derived from [ordinal] rather than from a `DateTime`, because the only
  /// caller (the Shabbos-aware projection) wants the weekday of a day it
  /// reached by *counting*, and counting through `Duration` is the bug this
  /// type exists to remove. 1970-01-01 was a Thursday; the double modulo keeps
  /// pre-epoch days correct rather than negative.
  int get weekday => ((ordinal + 3) % 7 + 7) % 7 + 1;

  /// This day plus [days] calendar days. Never lands on 23:00 of the day before.
  Day operator +(int days) => Day(ordinal + days);

  /// This day minus [days] calendar days.
  Day operator -(int days) => Day(ordinal - days);

  /// Whole calendar days from [other] to this day — positive if this is later.
  /// Exact, where `difference(…).inDays` truncates a 23-hour day to zero.
  int difference(Day other) => ordinal - other.ordinal;

  bool operator <(Day other) => ordinal < other.ordinal;
  bool operator <=(Day other) => ordinal <= other.ordinal;
  bool operator >(Day other) => ordinal > other.ordinal;
  bool operator >=(Day other) => ordinal >= other.ordinal;

  /// True if [moment] falls on this calendar day.
  bool contains(DateTime moment) => Day.of(moment) == this;

  @override
  int compareTo(Day other) => ordinal.compareTo(other.ordinal);

  @override
  bool operator ==(Object other) => other is Day && other.ordinal == ordinal;

  @override
  int get hashCode => ordinal.hashCode;

  /// ISO `YYYY-MM-DD`. Diagnostics and test failure output only — user-facing
  /// dates go through `DateDisplay`, which also speaks the Hebrew calendar.
  @override
  String toString() {
    final utc = DateTime.fromMillisecondsSinceEpoch(ordinal * _msPerDay,
        isUtc: true);
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$m-$d';
  }
}
