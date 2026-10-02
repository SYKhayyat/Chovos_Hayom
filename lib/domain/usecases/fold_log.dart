import '../../core/day.dart';
import '../entities/enums.dart';
import '../entities/layer.dart';
import '../entities/learning_event.dart';
import 'layer_roles.dart';

/// The state derived by folding the event log: for each unit of each node, which
/// *layers* are done, how many review passes it has had, when it was learned,
/// when it was last touched, and whether it carries a haara or a duration.
///
/// This is deliberately everything-per-unit rather than a minimal set. Chazara
/// scheduling, the cumulative progress line, siyumim, and the grid's detail dots
/// each used to re-sort and re-fold the whole log to recover one of these — five
/// ordered passes where one will do. Folding once and answering all of them from
/// the result is what keeps a tap on a daf cheap for a user with years of history.
///
/// **Deliberately has no `operator ==`, unlike the other derived value types.**
/// The ones that do — [ProgressNode], [StatsSummary], [BackupStatus] and the
/// rest — earn it because they are compared far more often than they change: a
/// midnight tick or a settings write re-derives them and the answer is usually
/// identical, so a cheap comparison saves a rebuild. This is the opposite. It is
/// rebuilt only when the event log itself emits, and an emission almost always
/// means a unit really was marked, so the comparison would run over five nested
/// maps covering the whole log and then return false — roughly the cost of the
/// fold again, per mark, to catch the rare no-op write (re-saving a haara with
/// the same text, or a `reviewed` event on a unit that is not currently
/// learned). Equality here would be a cost, not a saving. `notify_guard_test.dart`
/// lists the types that must have it, and this is not on that list on purpose.
class LogFold {
  const LogFold({
    required this.completedByNode,
    required this.reviewsByNode,
    required this.doneAtByNode,
    required this.touchedAtByNode,
    required this.annotatedByNode,
    required this.doneCountByNode,
    required this.planDoneCountById,
  });

  /// nodeId -> (unit index -> set of layer ids completed).
  final Map<String, Map<int, Set<String>>> completedByNode;

  /// nodeId -> (unit index -> review count).
  final Map<String, Map<int, int>> reviewsByNode;

  /// nodeId -> (unit index -> when it was *learned*), from the `done` event
  /// currently in force. Un-marking removes it; a later `done` replaces it. This
  /// is the representative date for the cumulative line and for dating a siyum.
  final Map<String, Map<int, DateTime>> doneAtByNode;

  /// nodeId -> (unit index -> when it was last learned *or reviewed*). The
  /// anchor the chazara schedule counts its interval from.
  final Map<String, Map<int, DateTime>> touchedAtByNode;

  /// nodeId -> units whose in-force `done` event carries a haara or a duration.
  /// The grid's "there are details here" dot reads this instead of re-scanning
  /// the log on every rebuild.
  final Map<String, Set<int>> annotatedByNode;

  /// nodeId -> unit -> **day** -> how many times that unit was done that day.
  ///
  /// **Per-day rather than one count, and that is load-bearing.** A single
  /// all-time number cannot answer a historical question: asked "how many times
  /// had I done this by 2019?", it would credit a 2026 tick to 2019. Keyed by day,
  /// every "as of" query is the same sum over the days before it — which is the
  /// query the planner's progress and completion already make, so those keep
  /// working unchanged and start answering questions they previously could not.
  final Map<String, Map<int, Map<Day, int>>> doneCountByNode;

  /// planId -> how many ticks carry it, across the whole log.
  ///
  /// Kept alongside [doneCountByNode] rather than derivable from it, because the
  /// day ledger asks "what did *this plan* have ticked" and answering that from
  /// the per-day map would mean walking the entire log per screen. Off-plan
  /// ticks are absent by design — that is the grid/plan asymmetry.
  final Map<String, int> planDoneCountById;

  /// The layers completed for one unit (empty if none).
  Set<String> completedLayers(String nodeId, int unitIndex) =>
      completedByNode[nodeId]?[unitIndex] ?? const {};

  int reviewCount(String nodeId, int unitIndex) =>
      reviewsByNode[nodeId]?[unitIndex] ?? 0;

  /// When [unitIndex] was learned, or null if it is not currently done.
  DateTime? doneAt(String nodeId, int unitIndex) =>
      doneAtByNode[nodeId]?[unitIndex];

  /// When [unitIndex] was last learned or reviewed, or null if not done.
  DateTime? touchedAt(String nodeId, int unitIndex) =>
      touchedAtByNode[nodeId]?[unitIndex];

  bool isAnnotated(String nodeId, int unitIndex) =>
      annotatedByNode[nodeId]?.contains(unitIndex) ?? false;

  /// Units currently *complete* — every required layer is done. With no
  /// [layers] resolver the requirement is just the text (`{main}`), which
  /// reproduces the pre-layers behaviour exactly.
  Set<int> doneUnits(String nodeId, [LayerRoles? layers]) {
    final byUnit = completedByNode[nodeId];
    if (byUnit == null) return const {};
    final out = <int>{};
    final req = layers?.requiredFor(nodeId) ?? const {mainLayerId};
    byUnit.forEach((unit, completed) {
      if (completed.isEmpty) return;
      if (_subset(req, completed)) out.add(unit);
    });
    return out;
  }

  /// How many times [unitIndex] of [nodeId] has been marked done, ever.
  ///
  /// **A count, not a date, and that changed what this class could answer.** It
  /// used to keep one `doneAt` per unit, so a second tick *overwrote* the first
  /// and "how many times have you done this" was unanswerable — the information
  /// was in the log and thrown away here. A unit learned seven years ago and
  /// again this month has been learned twice, and a summary reporting once is
  /// wrong about the user's own history.
  ///
  /// Counts days, so it is **one less per day than the number of ticks** — which
  /// is the point rather than an approximation: two plans both covering a unit
  /// and both ticked on one day is one *day* done twice, and
  /// [doneCountOn]/[doneCountAsOf] are what every historical question reads.
  int doneCount(String nodeId, int unitIndex) {
    final byDay = doneCountByNode[nodeId]?[unitIndex];
    if (byDay == null) return 0;
    var total = 0;
    for (final n in byDay.values) {
      total += n;
    }
    return total;
  }

  /// How many times [unitIndex] of [nodeId] was done on [day] specifically.
  int doneCountOn(String nodeId, int unitIndex, Day day) =>
      doneCountByNode[nodeId]?[unitIndex]?[day] ?? 0;

  /// How many times [unitIndex] of [nodeId] was done **before** [day].
  ///
  /// **Exclusive, and the exclusion is the rule the planner depends on**: a unit
  /// learned *on* a day has not been done *by* that day, which is what stops a
  /// plan reporting itself finished on the day it finishes. Asking for a day in
  /// the past therefore counts the ticks up to it and no further.
  int doneCountAsOf(String nodeId, int unitIndex, Day day) {
    final byDay = doneCountByNode[nodeId]?[unitIndex];
    if (byDay == null) return 0;
    var total = 0;
    for (final entry in byDay.entries) {
      if (entry.key < day) total += entry.value;
    }
    return total;
  }

  /// How many ticks carry [planId] — what one plan's day ledger asks about.
  ///
  /// Off-plan ticks (a null `planId`, made in the unit grid) are **not** in here,
  /// which is what makes the grid/plan asymmetry work without either screen
  /// knowing about the other: a grid tick cannot add to a plan, and a grid
  /// un-tick cannot remove from one.
  int doneCountForPlan(String planId) {
    var total = 0;
    planDoneCountById.forEach((id, count) {
      if (id == planId) total = count;
    });
    return total;
  }

  /// How many **passes** [unitIndex] of [nodeId] has had: one for being learned,
  /// one more for every `reviewed` event since.
  ///
  /// **"Learned means chazara" (#45), which is a change of meaning and not just
  /// a rename.** A learned unit used to score **zero** here, and a separate
  /// spaced-repetition scheduler decided when it was "due" — a unit with real
  /// state about when you last reviewed it, which had to be maintained from day
  /// one or it quietly lied. The rule now is that the first pass *is* the
  /// learning, so the count is the review count plus one, and nothing is stored.
  ///
  /// The old review counter still exists and is still the right number of
  /// *reviews*, so this is that plus the learning rather than a second thing to
  /// keep in step. A test states it as an identity so the two cannot drift.
  int chazaraCount(String nodeId, int unitIndex) {
    // **Learned is the condition, not a bonus.** A `reviewed` event over a unit
    // that is not currently learned is not a pass at it, and the fold already
    // refuses to count those; asking for the learned set first is what makes
    // this answer "no" rather than a number for something unlearned.
    if (completedLayers(nodeId, unitIndex).isEmpty) return 0;
    if (doneAtByNode[nodeId]?[unitIndex] == null) return 0;
    return reviewCount(nodeId, unitIndex) + 1;
  }

  static bool _subset(Set<String> required, Set<String> have) {
    for (final r in required) {
      if (!have.contains(r)) return false;
    }
    return true;
  }
}

/// Folds an event log into current [LogFold] state.
///
/// This is the single source of truth for "what is learned". Nothing is stored —
/// it is computed here in one pass, which makes `learned > total` impossible by
/// construction (see ARCHITECTURE.md §1).
class FoldLog {
  const FoldLog._();

  /// Fold [events] into current state. Events are processed in **append order**
  /// ([LearningEvent.loggedAt], then [LearningEvent.id] as a stable tiebreak) so
  /// the result is deterministic regardless of input ordering.
  static LogFold fold(Iterable<LearningEvent> events) {
    final sorted = events.toList()
      ..sort((a, b) {
        final c = a.loggedAt.compareTo(b.loggedAt);
        return c != 0 ? c : a.id.compareTo(b.id);
      });

    final completed = <String, Map<int, Set<String>>>{};
    final reviews = <String, Map<int, int>>{};
    final doneAt = <String, Map<int, DateTime>>{};
    final touchedAt = <String, Map<int, DateTime>>{};
    final annotated = <String, Set<int>>{};
    final doneCount = <String, Map<int, Map<Day, int>>>{};
    final planCounts = <String, int>{};

    for (final e in sorted) {
      switch (e.action) {
        case EventAction.done:
          final byUnit = completed[e.nodeId] ??= <int, Set<String>>{};
          (byUnit[e.unitIndex] ??= <String>{}).addAll(e.layers);
          // A later `done` supersedes the earlier one's date and annotations —
          // the same rule UnitHistoryFinder shows the user.
          (doneAt[e.nodeId] ??= <int, DateTime>{})[e.unitIndex] = e.occurredAt;
          (touchedAt[e.nodeId] ??= <int, DateTime>{})[e.unitIndex] = e.occurredAt;
          // **Counted, not overwritten.** The date above is still "the last time",
          // which is a different question; this is "how many times", and it is
          // keyed by the day the user gave the tick — so a tick made on Friday
          // for last Thursday lands on Thursday, and un-ticking Thursday takes
          // Thursday's back rather than the most recent one's.
          final byDay = doneCount[e.nodeId] ??= <int, Map<Day, int>>{};
          final days = byDay[e.unitIndex] ??= <Day, int>{};
          final tickedDay = Day.of(e.occurredAt);
          days[tickedDay] = (days[tickedDay] ?? 0) + 1;
          final planId = e.planId;
          if (planId != null) {
            planCounts[planId] = (planCounts[planId] ?? 0) + 1;
          }
          final hasDetails =
              (e.note != null && e.note!.isNotEmpty) || e.durationMin != null;
          if (hasDetails) {
            (annotated[e.nodeId] ??= <int>{}).add(e.unitIndex);
          } else {
            annotated[e.nodeId]?.remove(e.unitIndex);
          }
        case EventAction.undone:
          final set = completed[e.nodeId]?[e.unitIndex];
          if (set != null) {
            set.removeAll(e.layers);
            if (set.isEmpty) {
              completed[e.nodeId]!.remove(e.unitIndex);
              // Only a *full* un-mark clears the unit's review history, so a
              // later re-mark starts fresh — which is what the grid's ↻ badge
              // promises. A partial un-mark — un-ticking one optional meforish
              // while its required set survives — must leave the date, chazara
              // count and haara intact: the unit is still learned, and the
              // cumulative chart, the chazara report and its siyum all read
              // these. Clearing them here was silent data loss.
              reviews[e.nodeId]?.remove(e.unitIndex);
              doneAt[e.nodeId]?.remove(e.unitIndex);
              touchedAt[e.nodeId]?.remove(e.unitIndex);
              annotated[e.nodeId]?.remove(e.unitIndex);
            }
          }
          // **The count is taken back from the day the un-tick names**, and only
          // if that day still holds a tick. Not the latest day, and not
          // unconditionally: you can tick things in the past, so an un-tick is a
          // statement about a particular day rather than a mechanical undo of
          // "the most recent one". Clamped at zero so a stray un-tick cannot
          // drive a count negative, which would be a number no read explains.
          //
          // A day running out does **not** un-learn the unit — the layers above
          // decide that, and they survive any day still holding a tick. The two
          // agreeing is the whole point of keeping them separate: "learned once
          // rather than twice" and "not learned" are different statements.
          final undoneDay = Day.of(e.occurredAt);
          final days = doneCount[e.nodeId]?[e.unitIndex];
          if (days != null && days.containsKey(undoneDay)) {
            final left = days[undoneDay]! - 1;
            if (left <= 0) {
              days.remove(undoneDay);
            } else {
              days[undoneDay] = left;
            }
          }
          final planId = e.planId;
          if (planId != null && planCounts.containsKey(planId)) {
            final left = planCounts[planId]! - 1;
            if (left <= 0) {
              planCounts.remove(planId);
            } else {
              planCounts[planId] = left;
            }
          }
        case EventAction.reviewed:
          // A pass over something not currently learned isn't a chazara of it,
          // so it moves nothing. (UnitHistoryFinder shows the same to the user.)
          if (touchedAt[e.nodeId]?[e.unitIndex] == null) continue;
          final byUnit = reviews[e.nodeId] ??= <int, int>{};
          byUnit[e.unitIndex] = (byUnit[e.unitIndex] ?? 0) + 1;
          touchedAt[e.nodeId]![e.unitIndex] = e.occurredAt;
      }
    }

    return LogFold(
      completedByNode: completed,
      reviewsByNode: reviews,
      doneAtByNode: doneAt,
      touchedAtByNode: touchedAt,
      annotatedByNode: annotated,
      doneCountByNode: doneCount,
      planDoneCountById: planCounts,
    );
  }
}
