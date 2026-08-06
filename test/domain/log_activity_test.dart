import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/log_activity.dart';
import 'package:flutter_test/flutter_test.dart';

LearningEvent ev(
  DateTime day, {
  int unit = 2,
  String node = 'a',
  EventAction action = EventAction.done,
  int? mins,
  DateTime? logged,
}) =>
    LearningEvent(
      id: '$node-$unit-${action.name}-${day.toIso8601String()}'
          '-${logged?.toIso8601String() ?? ''}-$mins',
      profileId: 'p',
      nodeId: node,
      unitIndex: unit,
      action: action,
      occurredAt: day,
      loggedAt: logged ?? day,
      durationMin: mins,
    );

// ---------------------------------------------------------------------------
// The definitions, written out the long way.
//
// These are the five passes over the raw log that `statsProvider` used to make
// and `goalStatusProvider` used to make again per goal — copied here verbatim
// from the code they replaced. They are the *specification*: the index is only
// worth having if it answers exactly what a full scan would have, and the way
// an index quietly stops doing that is a bucket that misses an edge (an event
// backdated across the window boundary, a duration on a `reviewed` pass, a
// re-mark on a second day). So every property below is asserted against these
// rather than against a hand-written expected number.
// ---------------------------------------------------------------------------

double naiveAveragePerDay(List<LearningEvent> events,
    {required DateTime now, int windowDays = 30}) {
  if (windowDays <= 0) return 0;
  final today = Day.of(now);
  final windowStart = today - (windowDays - 1);
  final inWindow = <String>{};
  Day? earliest;
  for (final e in events) {
    if (e.action != EventAction.done) continue;
    final d = Day.of(e.occurredAt);
    if (earliest == null || d < earliest) earliest = d;
    if (d >= windowStart && d <= today) {
      inWindow.add('${e.nodeId} ${e.unitIndex}');
    }
  }
  if (inWindow.isEmpty || earliest == null) return 0;
  final effectiveStart = earliest > windowStart ? earliest : windowStart;
  return inWindow.length / (today.difference(effectiveStart) + 1);
}

int naiveStreak(List<LearningEvent> events, {required DateTime now}) {
  final days = events
      .where((e) => e.action == EventAction.done)
      .map((e) => Day.of(e.occurredAt))
      .toSet();
  if (days.isEmpty) return 0;
  var cursor = Day.of(now);
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

Map<Day, int> naiveDailyDone(List<LearningEvent> events) {
  final byDay = <Day, Set<String>>{};
  for (final e in events) {
    if (e.action != EventAction.done) continue;
    (byDay[Day.of(e.occurredAt)] ??= <String>{})
        .add('${e.nodeId} ${e.unitIndex}');
  }
  return {for (final e in byDay.entries) e.key: e.value.length};
}

int naiveTotalMinutes(List<LearningEvent> events) {
  var sum = 0;
  for (final e in events) {
    final d = e.durationMin;
    if (d != null && d > 0) sum += d;
  }
  return sum;
}

int naiveMinutesSince(List<LearningEvent> events, DateTime start) {
  final from = Day.of(start).midnight;
  var sum = 0;
  for (final e in events) {
    final d = e.durationMin;
    if (d != null && d > 0 && !e.occurredAt.isBefore(from)) sum += d;
  }
  return sum;
}

int naiveRecordedOn(List<LearningEvent> events, DateTime day) {
  final target = Day.of(day);
  return events
      .where((e) => e.action == EventAction.done)
      .where((e) => Day.of(e.loggedAt) == target)
      .length;
}

/// A log that exercises every edge the buckets could drop: two units on one
/// day, one unit on two days, an un-mark, a `reviewed` pass carrying a
/// duration, a backdated recording, a zero duration, and a gap.
List<LearningEvent> get messyLog => [
      ev(DateTime(2026, 1, 8, 12), unit: 5, mins: 30),
      ev(DateTime(2026, 1, 9, 12), unit: 4),
      ev(DateTime(2026, 1, 10, 9), unit: 2, mins: 45),
      ev(DateTime(2026, 1, 10, 21), unit: 3),
      // Same unit, a second day — one unit of pace, two days of heatmap.
      ev(DateTime(2026, 1, 12, 8), unit: 2),
      // A re-mark on a day it was already marked — collapses to one.
      ev(DateTime(2026, 1, 12, 22), unit: 2, node: 'a'),
      ev(DateTime(2026, 1, 13), unit: 4, action: EventAction.undone),
      // A chazara that took twenty minutes: time spent, not a unit learned.
      ev(DateTime(2026, 1, 13), unit: 5, action: EventAction.reviewed, mins: 20),
      // Learned on the 14th, written down on the 20th.
      ev(DateTime(2026, 1, 14), unit: 9, logged: DateTime(2026, 1, 20)),
      // A duration of zero is not a session.
      ev(DateTime(2026, 1, 15), unit: 11, mins: 0),
      ev(DateTime(2026, 2, 2), unit: 12, node: 'b', mins: 20),
    ];

void main() {
  group('one pass answers what the five passes did', () {
    final events = messyLog;
    final activity = LogActivity.of(events);

    test('the heatmap matches a direct scan, day for day', () {
      expect(activity.dailyCounts, naiveDailyDone(events));
    });

    test('the pace matches a direct scan, at every window end', () {
      // Every day from before the log starts to after it ends, so the window
      // boundary sweeps across every event in it in both directions.
      for (var d = 0; d <= 40; d++) {
        final now = DateTime(2026, 1, 5).add(Duration(hours: 24 * d));
        expect(
          activity.averagePerDay(Day.of(now), windowDays: 30),
          closeTo(naiveAveragePerDay(events, now: now, windowDays: 30), 1e-12),
          reason: 'pace disagrees at $now',
        );
      }
    });

    test('the streak matches a direct scan, at every window end', () {
      for (var d = 0; d <= 40; d++) {
        final now = DateTime(2026, 1, 5).add(Duration(hours: 24 * d));
        expect(activity.streakEndingAt(Day.of(now)), naiveStreak(events, now: now),
            reason: 'streak disagrees at $now');
      }
    });

    test('the minutes match a direct scan, at every boundary', () {
      expect(activity.totalMinutes, naiveTotalMinutes(events));
      for (var d = 0; d <= 40; d++) {
        final start = DateTime(2026, 1, 5).add(Duration(hours: 24 * d));
        expect(activity.minutesSince(Day.of(start)),
            naiveMinutesSince(events, start),
            reason: 'minutes disagree from $start');
      }
    });

    test('what was recorded on a day matches a direct scan', () {
      for (var d = 0; d <= 40; d++) {
        final day = DateTime(2026, 1, 5).add(Duration(hours: 24 * d));
        expect(activity.recordedOn(Day.of(day)), naiveRecordedOn(events, day),
            reason: 'recorded count disagrees on $day');
      }
    });
  });

  group('the axes stay separate', () {
    final activity = LogActivity.of(messyLog);

    test('learning is dated by occurredAt and recording by loggedAt', () {
      // Learned on the 14th, written down on the 20th: it is on the heatmap on
      // the 14th and it is what stops the nudge on the 20th.
      expect(activity.unitsOn(Day.of(DateTime(2026, 1, 14))), 1);
      expect(activity.recordedOn(Day.of(DateTime(2026, 1, 14))), 0);
      expect(activity.recordedOn(Day.of(DateTime(2026, 1, 20))), 1);
    });

    test('a reviewed pass contributes minutes and no units', () {
      expect(activity.minutesByDay[Day.of(DateTime(2026, 1, 13))], 20);
      expect(activity.unitsOn(Day.of(DateTime(2026, 1, 13))), 0);
    });

    test('an un-marked unit stays in the history it happened in', () {
      // The fold forgets unit 4; this does not. The heatmap for the 9th is a
      // record of a day, not a claim about what is currently learned.
      expect(activity.unitsOn(Day.of(DateTime(2026, 1, 9))), 1);
    });

    test('a unit marked twice on one day counts once', () {
      expect(activity.unitsOn(Day.of(DateTime(2026, 1, 12))), 1);
    });

    test('a unit marked on two days is one unit of pace and two of heatmap', () {
      expect(activity.unitsOn(Day.of(DateTime(2026, 1, 10))), 2);
      expect(activity.unitsOn(Day.of(DateTime(2026, 1, 12))), 1);
      // Jan 10 and Jan 12 together hold units 2, 3 and 2 again — three marks,
      // two distinct units.
      final pace = LogActivity.of([
        ev(DateTime(2026, 1, 10), unit: 2),
        ev(DateTime(2026, 1, 11), unit: 3),
        ev(DateTime(2026, 1, 12), unit: 2),
      ]).averagePerDay(Day.of(DateTime(2026, 1, 12)), windowDays: 30);
      expect(pace, closeTo(2 / 3, 1e-12));
    });
  });

  group('pace', () {
    // Kept from `pace_engine_test.dart`: these are the two cases the divisor
    // exists for, and they are worth stating in their own terms rather than
    // only as "the same as a full scan".
    final events = [
      ev(DateTime(2026, 1, 10, 9), unit: 2),
      ev(DateTime(2026, 1, 10, 21), unit: 3),
      ev(DateTime(2026, 1, 9, 12), unit: 4),
      ev(DateTime(2026, 1, 8, 12), unit: 5),
    ];

    test('divides by days active, not the full window, for new users', () {
      // 4 done spanning Jan 8-10 (3 active days) — a 3-day-old profile learning
      // ~1.3/day should not read as 0.13/day.
      expect(
        LogActivity.of(events).averagePerDay(Day.of(DateTime(2026, 1, 10))),
        closeTo(4 / 3, 1e-9),
      );
    });

    test('divides by the full window once the profile is older than it', () {
      final older = [ev(DateTime(2025, 11, 1), unit: 99), ...events];
      expect(
        LogActivity.of(older).averagePerDay(Day.of(DateTime(2026, 1, 10))),
        closeTo(4 / 30, 1e-9),
      );
    });

    test('the first day ever learned is what widens the divisor', () {
      // It lies outside the window, so it is the one part of the answer the
      // window walk cannot see and the index has to carry.
      final older = [ev(DateTime(2025, 11, 1), unit: 99), ...events];
      expect(LogActivity.of(older).firstDayLearned,
          Day.of(DateTime(2025, 11, 1)));
      expect(LogActivity.of(events).firstDayLearned,
          Day.of(DateTime(2026, 1, 8)));
    });

    test('a non-positive window is zero, not a division by zero', () {
      expect(LogActivity.of(events)
          .averagePerDay(Day.of(DateTime(2026, 1, 10)), windowDays: 0), 0);
    });
  });

  group('streak', () {
    final events = [
      ev(DateTime(2026, 1, 10, 9), unit: 2),
      ev(DateTime(2026, 1, 9, 12), unit: 4),
      ev(DateTime(2026, 1, 8, 12), unit: 5),
    ];

    test('counts consecutive days back from today', () {
      expect(
          LogActivity.of(events).streakEndingAt(Day.of(DateTime(2026, 1, 10))),
          3);
    });

    test('stays alive when today is empty but yesterday learned', () {
      expect(
          LogActivity.of(events).streakEndingAt(Day.of(DateTime(2026, 1, 11))),
          3);
    });

    test('is zero after a two-day gap', () {
      expect(
          LogActivity.of(events).streakEndingAt(Day.of(DateTime(2026, 1, 12))),
          0);
    });
  });

  group('minutes', () {
    // Kept from `time_stats_test.dart`. `timedSessions` and
    // `averageSessionMinutes` are not here because they are not anywhere: they
    // had no caller outside that file and were deleted with it rather than
    // carried into the index, where they would have been dead code with a
    // faster implementation.
    final events = [
      ev(DateTime(2026, 1, 1), mins: 30),
      ev(DateTime(2026, 1, 15), mins: 45),
      ev(DateTime(2026, 2, 2), mins: 20),
      ev(DateTime(2026, 2, 3)),
    ];

    test('totalMinutes sums recorded durations, ignoring null', () {
      expect(LogActivity.of(events).totalMinutes, 95);
    });

    test('minutesSince counts only on/after the given day', () {
      expect(
          LogActivity.of(events).minutesSince(Day.of(DateTime(2026, 2, 1))), 20);
    });

    test('minutesSince is day-inclusive from the first moment of the day', () {
      // A session at 08:00 counts for a window starting "on" that day, however
      // late in it the boundary instant was built.
      final e = [ev(DateTime(2026, 2, 1, 8), mins: 15)];
      expect(LogActivity.of(e).minutesSince(Day.of(DateTime(2026, 2, 1, 23))), 15);
    });
  });

  group('an empty log', () {
    test('answers zero to everything rather than throwing', () {
      final activity = LogActivity.of(const []);
      final today = Day.of(DateTime(2026, 1, 10));
      expect(activity.isEmpty, isTrue);
      expect(activity.averagePerDay(today), 0);
      expect(activity.streakEndingAt(today), 0);
      expect(activity.totalMinutes, 0);
      expect(activity.minutesSince(today), 0);
      expect(activity.unitsOn(today), 0);
      expect(activity.recordedOn(today), 0);
      expect(activity.firstDayLearned, isNull);
      expect(activity.dailyCounts, isEmpty);
    });

    test('LogActivity.empty is that answer, for a log still loading', () {
      const activity = LogActivity.empty;
      final today = Day.of(DateTime(2026, 1, 10));
      expect(activity.isEmpty, isTrue);
      expect(activity.averagePerDay(today), 0);
      expect(activity.streakEndingAt(today), 0);
    });
  });

  test('the heatmap map is handed out by identity, not rebuilt per read', () {
    // `StatsSummary.dailyActivity` holds this and compares it with `mapEquals`,
    // which checks identity first. Handing out the index's own map is what
    // makes a midnight tick cost one pointer read instead of a walk over every
    // day the user has ever learned on.
    final activity = LogActivity.of(messyLog);
    expect(identical(activity.dailyCounts, activity.dailyCounts), isTrue);
  });

  test('grouping happens on the day, not on the clock time within it', () {
    // The behaviour both the `Day` migration and the earlier local-DateTime fix
    // had to preserve: events at different hours of one calendar day collapse.
    final activity = LogActivity.of([
      ev(DateTime(2026, 3, 9, 0, 30), unit: 2),
      ev(DateTime(2026, 3, 9, 23, 45), unit: 3),
    ]);
    expect(activity.dailyCounts.keys, [Day.of(DateTime(2026, 3, 9))]);
    expect(activity.unitsOn(Day.of(DateTime(2026, 3, 9))), 2);
  });

  test('a streak spanning a DST boundary counts calendar days', () {
    // Spring forward in a northern-hemisphere zone falls in March; the day is
    // 23 hours long, and stepping the cursor by elapsed time rather than by day
    // count is what used to lose it. `Day` arithmetic has no hour to lose, and
    // this passes in any host timezone.
    final activity = LogActivity.of([
      for (var d = 0; d < 5; d++)
        ev(Day(Day.of(DateTime(2026, 3, 7)).ordinal + d).midnight
            .add(const Duration(hours: 10)), unit: d),
    ]);
    expect(activity.streakEndingAt(Day.of(DateTime(2026, 3, 11))), 5);
  });
}
