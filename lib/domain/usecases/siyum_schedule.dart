import '../../core/day.dart';
import '../entities/catalog_node.dart';
import '../entities/progress_node.dart';
import 'predictor.dart';
import 'siyum.dart';

/// A siyum that has not happened yet: the day an unfinished node is projected
/// to be finished, given what the log says is left and the current pace.
///
/// **This is a forecast, not a record — the whole point.** Nothing here is
/// stored. The day is recomputed from the log's roll-up and [Predictor] every
/// time the pace or the log changes, and the moment the last unit under [node]
/// is actually marked, the node stops being projected (it is complete) and the
/// *real* siyum surfaces in the roll of honour from that same log. So the
/// planner never holds a second truth about a siyum; it only forecasts when the
/// log's own answer will arrive.
///
/// [SiyumFinder.completed] is the backward half of this pair — the siyumim that
/// have landed — and the two read one forest, so a scheduled siyum and the
/// siyum that replaces it can never disagree about what is finished.
class ScheduledSiyum {
  const ScheduledSiyum({
    required this.node,
    required this.day,
    required this.remaining,
  });

  /// The node whose completion is projected.
  final CatalogNode node;

  /// The projected day the last remaining unit under [node] is learned.
  final Day day;

  /// How many units are still owed under [node] at projection time.
  final int remaining;

  /// A siyum on a category is a siyum on everything under it.
  bool get isCategory => !node.isLeaf;

  // Value equality, node by identity. `CatalogNode` deliberately has no `==`
  // (see `ProgressNode`'s note): the catalog is loaded once and the merged
  // provider re-uses the same instances, so a pointer check is both the cheap
  // comparison and the true one.
  @override
  bool operator ==(Object other) =>
      other is ScheduledSiyum &&
      identical(other.node, node) &&
      other.day == day &&
      other.remaining == remaining;

  @override
  int get hashCode => Object.hash(node.id, day, remaining);
}

/// The forward twin of [SiyumFinder.completed]: every unfinished node, and the
/// day its siyum is projected to land.
///
/// The calendar offers a siyum a recurring or one-off slot so the user knows it
/// is coming. That slot is this projection, and — the invariant that matters —
/// it is *derived from the same rolled-up log the real siyum comes from*, not
/// from a parallel store that could drift. Marking the last daf does not "confirm"
/// a scheduled siyum against a saved answer; the node simply stops being
/// unfinished, and the confirmed siyum takes over from the log exactly as it
/// always did.
class SiyumSchedule {
  const SiyumSchedule._();

  /// Upcoming siyumim, soonest day first; same-day ties put the larger siyum
  /// (more units still owed) first, so a calendar day that could host several
  /// leads with the biggest one.
  ///
  /// Every unfinished node counts, at every level — the same "every level
  /// counts" rule [SiyumFinder.completed] applies to the ones that landed. A
  /// node with no honest projection is left out: with no pace there is no day to
  /// schedule, and [Predictor] says `null` rather than inventing one.
  static List<ScheduledSiyum> projected({
    required List<ProgressNode> forest,
    required double perDay,
    required Day today,
  }) {
    // No pace, no honest day. Returning here also keeps the walk off the forest
    // entirely when nothing is being learned.
    if (perDay <= 0) return const [];

    final out = <ScheduledSiyum>[];
    void visit(ProgressNode n) {
      for (final child in n.children) {
        visit(child);
      }
      if (n.isComplete || n.remaining <= 0) return;
      final day = Predictor.finishDate(
        remaining: n.remaining,
        perDay: perDay,
        from: today,
      );
      if (day == null) return;
      out.add(ScheduledSiyum(node: n.node, day: day, remaining: n.remaining));
    }

    for (final root in forest) {
      visit(root);
    }

    out.sort((a, b) {
      final byDay = a.day.compareTo(b.day);
      return byDay != 0 ? byDay : b.remaining.compareTo(a.remaining);
    });
    return out;
  }
}
