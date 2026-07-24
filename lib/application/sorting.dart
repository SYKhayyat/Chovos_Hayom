import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/progress_node.dart';
import 'providers.dart';
import 'settings.dart';

/// How a node's children are ordered in the tree.
enum SortMetric {
  catalog, // original catalog order (no reordering)
  name,
  percent,
  learned, // amount done
  remaining,
  lastLearned, // most recent activity (time finished)
}

// The English labels for these used to live here as a `SortMetricLabel`
// extension. Naming a metric is a presentation decision that depends on the
// reader's language, which the application layer has no business knowing — see
// `features/common/naming.dart`, which holds it now.

/// A tree-sort configuration. [level] scopes which generation is reordered:
/// null = every level; k = only the k-th generation below the sorted root
/// (1 = direct children). [descending] flips the order for that metric.
class SortConfig {
  const SortConfig({
    this.metric = SortMetric.catalog,
    this.descending = false,
    this.level,
  });

  final SortMetric metric;
  final bool descending;
  final int? level;

  bool get active => metric != SortMetric.catalog;

  SortConfig copyWith({SortMetric? metric, bool? descending, Object? level = _keep}) =>
      SortConfig(
        metric: metric ?? this.metric,
        descending: descending ?? this.descending,
        level: level == _keep ? this.level : level as int?,
      );

  static const _keep = Object();
}

/// Most-recent activity (a `done` event's `occurredAt`) rolled up to *every*
/// node id in the forest — a leaf's own last-learned, propagated up to the max
/// across each ancestor's subtree. Memoized, so sorting by "last learned" is an
/// O(1) lookup per node.
///
/// Reads the shared fold rather than re-scanning the log: `doneAtByNode` is
/// already the learned-date of every unit currently done, so this costs only a
/// walk of what the user has actually learned.
///
/// The "is a sort even switched on?" gate lives **here**, not at the call site.
/// The dashboard used to write `sort.active ? ref.watch(this) : const {}`, which
/// bought the same laziness by changing the *set of providers the widget
/// subscribes to* from one build to the next. Riverpod tolerates a conditional
/// watch, but it means subscriptions are torn down and re-established mid-frame,
/// and the app's crash log carries one `setState() called during build` thrown
/// from the provider scope while an overlay was building over this very screen.
/// That stack could not be reproduced (see `dashboard_rebuild_test.dart`), so
/// this is not a proven fix — but a stable subscription set costs nothing and
/// removes the only conditional watch in the app.
final nodeLastActivityProvider = Provider<Map<String, DateTime>>((ref) {
  // Nothing is sorting by it, so nothing needs the roll-up. Same saving as the
  // conditional watch, without the moving subscription.
  if (!ref.watch(settingsProvider.select((s) => s.sort.active))) {
    return const {};
  }
  final fold = ref.watch(foldProvider).asData?.value;
  final forest = ref.watch(progressForestProvider).asData?.value;
  if (forest == null || fold == null) return const {};

  final leafLast = <String, DateTime>{};
  fold.doneAtByNode.forEach((nodeId, byUnit) {
    DateTime? best;
    for (final at in byUnit.values) {
      if (best == null || at.isAfter(best)) best = at;
    }
    if (best != null) leafLast[nodeId] = best;
  });

  final out = <String, DateTime>{};
  DateTime? visit(ProgressNode n) {
    DateTime? best = leafLast[n.id];
    for (final c in n.children) {
      final childBest = visit(c);
      if (childBest != null && (best == null || childBest.isAfter(best))) {
        best = childBest;
      }
    }
    if (best != null) out[n.id] = best;
    return best;
  }

  for (final root in forest) {
    visit(root);
  }
  return out;
});

/// Orders [children] per [config] using [lastActivity] for the last-learned
/// metric. Returns the input unchanged for [SortMetric.catalog] or an inactive
/// config; otherwise a new, stably-sorted list.
List<ProgressNode> sortChildren(
  List<ProgressNode> children,
  SortConfig config,
  Map<String, DateTime> lastActivity,
) {
  if (!config.active || children.length < 2) return children;

  int cmp(ProgressNode a, ProgressNode b) {
    final r = switch (config.metric) {
      SortMetric.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      SortMetric.percent => a.percent.compareTo(b.percent),
      SortMetric.learned => a.learned.compareTo(b.learned),
      SortMetric.remaining => a.remaining.compareTo(b.remaining),
      SortMetric.lastLearned => _cmpNullableDate(
          lastActivity[a.id], lastActivity[b.id]),
      SortMetric.catalog => 0,
    };
    return config.descending ? -r : r;
  }

  final sorted = List<ProgressNode>.of(children);
  // A stable sort keeps catalog order as the tie-breaker.
  _mergeSort(sorted, cmp);
  return sorted;
}

/// Nulls (never learned) sort as the earliest, so with "last learned" ascending
/// they lead and descending they trail.
int _cmpNullableDate(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

/// Dart's [List.sort] is not guaranteed stable; this merge sort is, so equal
/// keys keep their catalog order.
void _mergeSort(List<ProgressNode> list, int Function(ProgressNode, ProgressNode) cmp) {
  if (list.length < 2) return;
  final mid = list.length ~/ 2;
  final left = list.sublist(0, mid);
  final right = list.sublist(mid);
  _mergeSort(left, cmp);
  _mergeSort(right, cmp);
  var i = 0, j = 0, k = 0;
  while (i < left.length && j < right.length) {
    if (cmp(left[i], right[j]) <= 0) {
      list[k++] = left[i++];
    } else {
      list[k++] = right[j++];
    }
  }
  while (i < left.length) {
    list[k++] = left[i++];
  }
  while (j < right.length) {
    list[k++] = right[j++];
  }
}
