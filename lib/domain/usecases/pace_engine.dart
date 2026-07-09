import '../entities/enums.dart';
import '../entities/learning_event.dart';

/// Derives learning pace and consistency metrics from the event log.
///
/// All time-dependent methods take an explicit `now`/date rather than reading a
/// hidden clock, so the engine stays pure and fully testable. Calendar-day math
/// uses a UTC day-ordinal ([_dayNumber]) so it is immune to DST transitions —
/// stepping "one day back" never lands on 23:00 of the wrong day.
class PaceEngine {
  const PaceEngine._();

  /// Count of `done` events on the calendar day of [day] (local time), keyed on
  /// *when it was learned* (`occurredAt`).
  static int unitsOn(Iterable<LearningEvent> events, DateTime day) {
    final target = _dayNumber(day);
    final units = <String>{};
    for (final e in events) {
      if (e.action != EventAction.done) continue;
      if (_dayNumber(e.occurredAt) != target) continue;
      units.add('${e.nodeId} ${e.unitIndex}');
    }
    return units.length;
  }

  /// Count of `done` events *recorded* on the calendar day of [day], keyed on
  /// `loggedAt`. Used by the reminder policy — "did I record anything today?" —
  /// so that backdating a session doesn't wrongly suppress or trigger a nudge.
  static int recordedOn(Iterable<LearningEvent> events, DateTime day) {
    final target = _dayNumber(day);
    return events
        .where((e) => e.action == EventAction.done)
        .where((e) => _dayNumber(e.loggedAt) == target)
        .length;
  }

  /// Average `done` units per day over the window ending at [now] (inclusive).
  ///
  /// The divisor is the number of days the profile has actually existed *within*
  /// the window, not the full [windowDays]. A user three days in who learned
  /// 3/day reads as 1.0/day, not 0.1/day — otherwise brand-new profiles get
  /// wildly pessimistic pace and finish-date predictions. Returns 0 if nothing
  /// was learned in the window.
  static double averagePerDay(
    Iterable<LearningEvent> events, {
    required DateTime now,
    int windowDays = 30,
  }) {
    if (windowDays <= 0) return 0;
    final today = _dayNumber(now);
    final windowStart = today - (windowDays - 1);

    // Count *distinct* units learned in the window, not raw done events, so
    // re-marking the same unit (or done→undo→done) doesn't inflate the pace.
    final inWindow = <String>{};
    int? earliest;
    for (final e in events) {
      if (e.action != EventAction.done) continue;
      final d = _dayNumber(e.occurredAt);
      if (earliest == null || d < earliest) earliest = d;
      if (d >= windowStart && d <= today) {
        inWindow.add('${e.nodeId} ${e.unitIndex}');
      }
    }
    if (inWindow.isEmpty || earliest == null) return 0;

    // Don't average over days before the user ever started learning.
    final effectiveStart = earliest > windowStart ? earliest : windowStart;
    final effectiveDays = today - effectiveStart + 1;
    return inWindow.length / effectiveDays;
  }

  /// Current consecutive-day streak of learning, counting back from [now].
  /// If nothing was learned today or yesterday, the streak is 0.
  static int currentStreak(Iterable<LearningEvent> events, {required DateTime now}) {
    final days = events
        .where((e) => e.action == EventAction.done)
        .map((e) => _dayNumber(e.occurredAt))
        .toSet();
    if (days.isEmpty) return 0;

    var cursor = _dayNumber(now);
    // Allow the streak to be "alive" if today has nothing yet but yesterday does.
    if (!days.contains(cursor)) {
      cursor -= 1;
      if (!days.contains(cursor)) return 0;
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor -= 1;
    }
    return streak;
  }

  /// Whole-day ordinal in UTC — a DST-safe integer key for a local calendar day.
  static int _dayNumber(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
}
