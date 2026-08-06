import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/log_activity.dart';
import 'package:chovos_hayom/domain/usecases/mefarshim_stats.dart';
import 'package:chovos_hayom/domain/usecases/progress_series.dart';
import 'package:chovos_hayom/domain/usecases/roll_up.dart';
import 'package:chovos_hayom/domain/usecases/siyum.dart';
import 'package:flutter_test/flutter_test.dart';

/// A log of [count] `done` events spread over [days] distinct calendar days.
///
/// The day DateTimes are built once up front, so generating the log is not part
/// of anything a test then measures.
List<LearningEvent> syntheticLog(int count, {int days = 200}) {
  final dayOf = [
    for (var d = 0; d < days; d++) DateTime(2026, 1, 1).add(Duration(days: d)),
  ];
  return [
    for (var i = 0; i < count; i++)
      LearningEvent(
        id: 'e$i',
        profileId: 'p',
        nodeId: 'huge',
        unitIndex: i % 5000,
        action: EventAction.done,
        occurredAt: dayOf[i % days],
        loggedAt: dayOf[i % days],
      ),
  ];
}

/// A leaf that records every time something walks its full unit range.
///
/// Deriving progress must cost what the user has *learned*, not what exists —
/// otherwise every tap on a daf pays for all 12,000 units of the catalog, and
/// the app gets slower for exactly the users with the most history. This makes
/// that a property the suite can assert rather than a claim in a comment.
class _CountingLeaf extends CatalogNode {
  _CountingLeaf({
    required super.id,
    required super.parentId,
    required super.name,
    required int units,
  }) : super(
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.daf,
          unitCount: units,
          unitOffset: 1,
        );

  int fullScans = 0;

  @override
  Iterable<int> get unitIndices {
    fullScans++;
    return super.unitIndices;
  }
}

LearningEvent done(String node, int unit, {List<String> layers = const ['main']}) =>
    LearningEvent(
      id: '$node-$unit-${layers.join()}',
      profileId: 'p',
      nodeId: node,
      unitIndex: unit,
      action: EventAction.done,
      occurredAt: DateTime(2026, 1, 1),
      loggedAt: DateTime(2026, 1, 1),
      layers: layers,
    );

void main() {
  late _CountingLeaf huge;
  late Catalog catalog;

  setUp(() {
    // Far larger than Shas, so a full-range walk would be unmistakable.
    huge = _CountingLeaf(
        id: 'huge', parentId: 'root', name: 'Huge', units: 500000);
    catalog = Catalog([
      const CatalogNode(
          id: 'root', parentId: null, name: 'Root', kind: NodeKind.category),
      huge,
    ]);
  });

  test('rolling up a barely-touched leaf never walks its whole unit range', () {
    final fold = FoldLog.fold([
      done('huge', 1, layers: ['main', 'rashi']),
      done('huge', 2),
    ]);

    final root = RollUp.buildForest(catalog, fold).single;

    expect(huge.fullScans, 0,
        reason: 'per-layer coverage must walk the marked units, not all 500k');
    expect(root.learned, 2);
    expect(root.total, 500000);
    expect(root.learnedFor('rashi'), 1);
  });

  test('finding siyumim never walks the range of an unfinished leaf', () {
    final fold = FoldLog.fold([done('huge', 1)]);
    final forest = RollUp.buildForest(catalog, fold);
    huge.fullScans = 0;

    expect(SiyumFinder.completed(forest, fold), isEmpty);
    expect(huge.fullScans, 0);
  });

  test('per-meforish totals scale with what is learned, not the catalog', () {
    final fold = FoldLog.fold([
      done('huge', 1, layers: ['main', 'rashi']),
      done('huge', 2, layers: ['main']),
    ]);
    final forest = RollUp.buildForest(catalog, fold);
    huge.fullScans = 0;

    // Reading the roll-up rather than re-deriving from the fold, so this now
    // costs the number of *roots* and touches the catalog not at all.
    final stats = MefarshimStats.of(forest);

    expect(huge.fullScans, 0);
    expect(stats.firstWhere((s) => s.layerId == 'main').learnedUnits, 2);
    expect(stats.firstWhere((s) => s.layerId == 'rashi').learnedUnits, 1);
  });

  // The scans-counter above catches *algorithmic* regressions (walking the whole
  // catalog instead of what was learned). It cannot see a **constant-factor**
  // one — and that is exactly what went wrong last time: `ProgressSeries` keyed
  // its maps on a *local* `DateTime(y, m, d)`, which forces a timezone
  // conversion ~230× more expensive than the UTC form, once per event. Nothing
  // scanned anything extra; the Statistics screen simply took a second to open.
  //
  // So these two are wall-clock, with thresholds an order of magnitude above the
  // measured cost — a slow CI box cannot trip them, while the code they replaced
  // (481 ms for the same input) fails them by a wide margin.
  group('cost stays cheap as history grows', () {
    test('the series helpers cost O(distinct days), not O(events)', () {
      // 20,000 events over 200 days — a serious multi-year user.
      final events = syntheticLog(20000);
      final fold = FoldLog.fold(events);

      // Warm up first, exactly as the original benchmark did: the first call
      // also pays for JIT-compiling these functions, which is several times the
      // steady-state cost and would make the threshold meaningless.
      ProgressSeries.cumulative(fold);
      LogActivity.of(events);

      final sw = Stopwatch()..start();
      final series = ProgressSeries.cumulative(fold);
      final activity = LogActivity.of(events);
      sw.stop();

      expect(series, hasLength(200), reason: 'one point per distinct day');
      expect(activity.dailyCounts, hasLength(200));
      // Measured at ~145 ms for all three of the helpers this replaced. The
      // version *they* replaced keyed on a local DateTime per event, which
      // alone is ~2,200 ms for 20,000 of them — so this threshold has room for
      // a slow machine and none for that bug.
      expect(sw.elapsedMilliseconds, lessThan(800),
          reason: 'the series helpers took ${sw.elapsedMilliseconds} ms — a '
              'per-event local DateTime construction is back');
    });

    // The index exists so that the *answers* stop costing the log. These pin
    // that: each is asked against a 20,000-event history and must not care.
    test('the day-indexed answers cost the day, not the log', () {
      final events = syntheticLog(20000);
      final activity = LogActivity.of(events);
      final today = Day.of(DateTime(2026, 1, 1).add(const Duration(days: 199)));

      // Warm up, then ask each answer a thousand times. A thousand full scans
      // of 20,000 events is twenty million event visits; a thousand map lookups
      // is not, and only one of those fits in the budget below.
      activity.averagePerDay(today);
      activity.streakEndingAt(today);
      activity.minutesSince(today);

      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        activity.averagePerDay(today);
        activity.streakEndingAt(today);
        activity.minutesSince(today);
      }
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(500),
          reason: '1,000 rounds of pace+streak+minutes took '
              '${sw.elapsedMilliseconds} ms — one of them is scanning the log '
              'again. This is the shape the goal screen had: N goals, N scans.');
    });

    // §P3: every write re-reads and re-folds the whole log. That is a deliberate
    // trade and cheap today; this pins the size at which it would stop being
    // cheap, so the fold cannot quietly become the next unmeasured hotspot.
    test('folding a very large log stays bounded', () {
      final events = syntheticLog(100000);

      final sw = Stopwatch()..start();
      final fold = FoldLog.fold(events);
      sw.stop();

      expect(fold.doneUnits('huge'), hasLength(5000));
      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: 'folding 100k events took ${sw.elapsedMilliseconds} ms');
    });
  });

  test('out-of-range marks still cannot inflate learned', () {
    // The clamp has to survive the switch from walking units to walking marks.
    const small = CatalogNode(
        id: 'small',
        parentId: 'root',
        name: 'Small',
        kind: NodeKind.leaf,
        unitLabel: UnitLabel.daf,
        unitCount: 2,
        unitOffset: 1);
    final c = Catalog([
      const CatalogNode(
          id: 'root', parentId: null, name: 'Root', kind: NodeKind.category),
      small,
    ]);
    final fold = FoldLog.fold([
      done('small', 1, layers: ['main', 'rashi']),
      done('small', 2),
      done('small', 900, layers: ['main', 'rashi']), // out of range
    ]);

    final root = RollUp.buildForest(c, fold).single;
    expect(root.learned, 2);
    expect(root.learnedFor('rashi'), 1, reason: 'the stray mark is not counted');
  });
}
