import '../../core/day.dart';
import '../entities/enums.dart';
import '../entities/learning_event.dart';

/// The log indexed by *calendar day* — how much was learned on each of them, how
/// much was recorded on each of them, and how many minutes went into them.
///
/// **Why this exists, and why it is not [LogFold].** The fold answers "what is
/// learned *now*": it resolves membership per unit, so an un-marked daf leaves
/// it entirely and a re-marked one carries only its latest date. That is the
/// right answer for the tree, the chazara schedule and a siyum, and it is the
/// wrong answer for every question about *history*. "How many days in a row have
/// I learned" and "what does the heatmap show for last March" are asked of what
/// happened, not of what survived. Merging the two would make one of them quietly
/// wrong, so there are two indexes over one log and they are named for the
/// question they answer.
///
/// **What it replaces.** `fold_log.dart` opens by explaining that five ordered
/// passes over the log were collapsed into one, "which is what keeps a tap on a
/// daf cheap for a user with years of history". Downstream of it, `statsProvider`
/// then made five more passes — `averagePerDay`, `currentStreak`, `dailyDone`,
/// `totalMinutes`, `minutesSince` — over the log it was already holding a fold
/// of; `goalStatusProvider` made a sixth *per goal*, so N goals cost N+1
/// identical thirty-day scans on every rebuild; and the dashboard made a seventh
/// to decide whether to show a one-line nudge. Nine full walks plus one per goal,
/// per mark, for numbers that one pass produces. None of it was visible in
/// testing: the whole thing scales with event count, and a phone you tested last
/// week has a log of roughly zero.
///
/// **Deliberately has no `operator ==`, for [LogFold]'s reason.** It is rebuilt
/// only when the log itself emits, and an emission almost always means something
/// really changed, so comparing four maps over the whole history would cost the
/// pass again to catch a rare no-op write. What it does instead is hand out the
/// *same map instance* for as long as the log is unchanged — [dailyCounts] flows
/// straight into `StatsSummary.dailyActivity`, whose `mapEquals` checks identity
/// first, so a midnight tick compares it in one pointer read.
class LogActivity {
  const LogActivity({
    required this.unitsDoneByDay,
    required this.dailyCounts,
    required this.recordedDoneByDay,
    required this.minutesByDay,
    required this.totalMinutes,
    required this.firstDayLearned,
  });

  /// Empty history — what every consumer sees while the log is still loading.
  static const empty = LogActivity(
    unitsDoneByDay: {},
    dailyCounts: {},
    recordedDoneByDay: {},
    minutesByDay: {},
    totalMinutes: 0,
    firstDayLearned: null,
  );

  /// day -> the distinct units marked `done` on it, keyed on **`occurredAt`**
  /// (when it was learned). A unit marked twice on one day appears once; a unit
  /// later un-marked stays, because it still happened.
  ///
  /// The sets are kept rather than reduced to counts because [averagePerDay]
  /// needs unit *identity* across a window — a daf learned on two days inside
  /// the window is one unit of pace, not two, and counts per day cannot tell.
  final Map<Day, Set<String>> unitsDoneByDay;

  /// The lengths of [unitsDoneByDay], precomputed — the activity heatmap.
  final Map<Day, int> dailyCounts;

  /// day -> number of `done` events **recorded** on it, keyed on `loggedAt`.
  ///
  /// A separate axis from [unitsDoneByDay] on purpose: the nudge asks "did I
  /// write anything down today?", so backdating yesterday's seder still counts
  /// as activity today. Events rather than distinct units, matching the only
  /// question asked of it (`> 0`).
  final Map<Day, int> recordedDoneByDay;

  /// day -> minutes logged on it, over events of *any* action that carry a
  /// duration. A chazara pass is time spent learning and is counted.
  final Map<Day, int> minutesByDay;

  /// Minutes across the whole log — the sum of [minutesByDay], kept as a scalar
  /// because it is read on every Statistics build and never varies with a date.
  final int totalMinutes;

  /// The earliest day anything was learned, or null if nothing ever was.
  /// [averagePerDay] divides by days the profile has actually existed, and this
  /// is the only part of that answer that lies outside the window.
  final Day? firstDayLearned;

  bool get isEmpty => unitsDoneByDay.isEmpty;

  /// Distinct units learned on [day].
  int unitsOn(Day day) => unitsDoneByDay[day]?.length ?? 0;

  /// `done` events recorded on [day] (by `loggedAt`).
  int recordedOn(Day day) => recordedDoneByDay[day] ?? 0;

  /// Average distinct units learned per day over the [windowDays]-day window
  /// ending at [today] (inclusive).
  ///
  /// The divisor is the number of days the profile has actually existed *within*
  /// the window, not the full [windowDays]. A user three days in who learned
  /// 3/day reads as 1.0/day, not 0.1/day — otherwise brand-new profiles get
  /// wildly pessimistic pace and finish-date predictions. Returns 0 if nothing
  /// was learned in the window.
  ///
  /// Costs [windowDays] map lookups plus the units inside the window, where the
  /// log scan it replaces cost one pass over every event ever recorded. Walking
  /// the window rather than the index's own keys is what bounds it: a user seven
  /// years in has ~2,500 days of keys and still only thirty of them matter.
  double averagePerDay(Day today, {int windowDays = 30}) {
    if (windowDays <= 0) return 0;
    final earliest = firstDayLearned;
    if (earliest == null) return 0;
    final windowStart = today - (windowDays - 1);

    final inWindow = <String>{};
    for (var day = windowStart; day <= today; day += 1) {
      final units = unitsDoneByDay[day];
      if (units != null) inWindow.addAll(units);
    }
    if (inWindow.isEmpty) return 0;

    // Don't average over days before the user ever started learning.
    final effectiveStart = earliest > windowStart ? earliest : windowStart;
    return inWindow.length / (today.difference(effectiveStart) + 1);
  }

  /// Consecutive-day learning streak ending at [today]. The streak is still
  /// alive if today has nothing yet but yesterday does; 0 otherwise.
  ///
  /// Costs the length of the streak, where the scan it replaces built a set of
  /// every day in the log first.
  int streakEndingAt(Day today) {
    if (unitsDoneByDay.isEmpty) return 0;
    var cursor = today;
    if (!unitsDoneByDay.containsKey(cursor)) {
      cursor -= 1;
      if (!unitsDoneByDay.containsKey(cursor)) return 0;
    }
    var streak = 0;
    while (unitsDoneByDay.containsKey(cursor)) {
      streak++;
      cursor -= 1;
    }
    return streak;
  }

  /// Minutes logged on or after [from], day-inclusive.
  int minutesSince(Day from) {
    var sum = 0;
    for (final entry in minutesByDay.entries) {
      if (entry.key >= from) sum += entry.value;
    }
    return sum;
  }

  /// Index [events] in one pass.
  ///
  /// Order-independent — every aggregate here is a set, a sum or a minimum — so
  /// unlike [FoldLog.fold] this does not sort first. Two linear passes over the
  /// log per change, and the other one is the one that has to sort.
  static LogActivity of(Iterable<LearningEvent> events) {
    final unitsByDay = <Day, Set<String>>{};
    final recorded = <Day, int>{};
    final minutes = <Day, int>{};
    var totalMinutes = 0;
    Day? firstLearned;

    for (final e in events) {
      // `Day.of` reads the fields of a `DateTime` through `DateTime.utc`, so it
      // costs no timezone conversion — but it is still the per-event work here,
      // so each instant is asked for its day at most once.
      final duration = e.durationMin;
      final hasDuration = duration != null && duration > 0;
      final isDone = e.action == EventAction.done;
      if (!hasDuration && !isDone) continue;

      final day = Day.of(e.occurredAt);
      if (hasDuration) {
        minutes[day] = (minutes[day] ?? 0) + duration;
        totalMinutes += duration;
      }
      if (!isDone) continue;

      (unitsByDay[day] ??= <String>{}).add('${e.nodeId} ${e.unitIndex}');
      if (firstLearned == null || day < firstLearned) firstLearned = day;
      final logged = Day.of(e.loggedAt);
      recorded[logged] = (recorded[logged] ?? 0) + 1;
    }

    return LogActivity(
      unitsDoneByDay: unitsByDay,
      dailyCounts: {
        for (final entry in unitsByDay.entries) entry.key: entry.value.length,
      },
      recordedDoneByDay: recorded,
      minutesByDay: minutes,
      totalMinutes: totalMinutes,
      firstDayLearned: firstLearned,
    );
  }
}
