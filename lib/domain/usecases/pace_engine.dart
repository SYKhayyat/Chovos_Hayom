import '../entities/enums.dart';
import '../entities/learning_event.dart';

/// Derives learning pace and consistency metrics from the event log.
///
/// All time-dependent methods take an explicit `now`/date rather than reading a
/// hidden clock, so the engine stays pure and fully testable.
class PaceEngine {
  const PaceEngine._();

  /// Count of `done` events on the calendar day of [day] (local time).
  static int unitsOn(Iterable<LearningEvent> events, DateTime day) {
    final target = _dayKey(day);
    return events
        .where((e) => e.action == EventAction.done)
        .where((e) => _dayKey(e.occurredAt) == target)
        .length;
  }

  /// Average `done` units per day over the [windowDays] ending at [now]
  /// (inclusive). Returns 0 if the window is empty.
  static double averagePerDay(
    Iterable<LearningEvent> events, {
    required DateTime now,
    int windowDays = 30,
  }) {
    if (windowDays <= 0) return 0;
    final start = _dayKey(now).subtract(Duration(days: windowDays - 1));
    final count = events
        .where((e) => e.action == EventAction.done)
        .where((e) => !_dayKey(e.occurredAt).isBefore(start))
        .where((e) => !_dayKey(e.occurredAt).isAfter(_dayKey(now)))
        .length;
    return count / windowDays;
  }

  /// Current consecutive-day streak of learning, counting back from [now].
  /// If nothing was learned today or yesterday, the streak is 0.
  static int currentStreak(Iterable<LearningEvent> events, {required DateTime now}) {
    final days = events
        .where((e) => e.action == EventAction.done)
        .map((e) => _dayKey(e.occurredAt))
        .toSet();
    if (days.isEmpty) return 0;

    final today = _dayKey(now);
    var cursor = today;
    // Allow the streak to be "alive" if today has nothing yet but yesterday does.
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
}
