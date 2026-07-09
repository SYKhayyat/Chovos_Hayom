import '../entities/learning_event.dart';

/// Time-based analytics over the log. Uses the optional `durationMin` recorded
/// on sessions; events without a duration simply don't contribute. Pure.
class TimeStats {
  const TimeStats._();

  /// Total minutes logged across all events that carry a duration.
  static int totalMinutes(Iterable<LearningEvent> events) {
    var sum = 0;
    for (final e in events) {
      final d = e.durationMin;
      if (d != null && d > 0) sum += d;
    }
    return sum;
  }

  /// Minutes logged on or after [start] (compared by `occurredAt`, day-inclusive).
  static int minutesSince(Iterable<LearningEvent> events, DateTime start) {
    final from = DateTime(start.year, start.month, start.day);
    var sum = 0;
    for (final e in events) {
      final d = e.durationMin;
      if (d != null && d > 0 && !e.occurredAt.isBefore(from)) sum += d;
    }
    return sum;
  }

  /// Number of sessions that recorded a duration.
  static int timedSessions(Iterable<LearningEvent> events) =>
      events.where((e) => (e.durationMin ?? 0) > 0).length;

  /// Average minutes per timed session (0 if none).
  static double averageSessionMinutes(Iterable<LearningEvent> events) {
    final n = timedSessions(events);
    return n == 0 ? 0 : totalMinutes(events) / n;
  }
}
