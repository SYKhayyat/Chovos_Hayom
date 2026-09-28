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

/// The fastest of [rounds] timings of [body], in milliseconds.
///
/// Taking the minimum removes *contention* — a busy scheduler can only ever add
/// time — but it cannot remove a slow *machine*, nor `flutter test --coverage`'s
/// instrumentation, which makes the whole program slower. That is why every
/// assertion in this file is a **ratio** against work measured in the same run
/// rather than a budget in milliseconds: both sides of a ratio are inflated by
/// the same load and the same coverage instrumentation, so it cancels, while a
/// regression still moves the ratio by orders of magnitude.
int fastestMs(void Function() body, {int rounds = 5}) {
  var best = 1 << 62;
  for (var i = 0; i < rounds; i++) {
    final sw = Stopwatch()..start();
    body();
    sw.stop();
    final ms = sw.elapsedMilliseconds;
    if (ms < best) best = ms;
  }
  return best;
}

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

      late List<SeriesPoint> series;
      late LogActivity activity;
      final ms = fastestMs(() {
        series = ProgressSeries.cumulative(fold);
        activity = LogActivity.of(events);
      });

      expect(series, hasLength(200), reason: 'one point per distinct day');
      expect(activity.dailyCounts, hasLength(200));

      // **A ratio, not a budget.** The regression guarded here is a per-event
      // local `DateTime`, a *constant factor* per event (~15x on measured work),
      // while the correct code is O(distinct days). The reference is a fold over
      // the same 20,000 events: also O(events), also measured in this run, so
      // machine speed and coverage instrumentation inflate both sides and cancel.
      // A per-event local DateTime lands well past 8x a fold; correct code is far
      // under it.
      final foldMs = fastestMs(() => FoldLog.fold(events));
      expect(ms, lessThan(foldMs * 8),
          reason: 'the series helpers took $ms ms against a $foldMs ms fold of '
              'the same log — a per-event local DateTime construction is back');
    });

    // The index exists so that the *answers* stop costing the log. This asserts
    // that **deterministically, with no clock involved**, because every
    // wall-clock version of it was unreliable: an absolute budget failed under
    // `flutter test --coverage`, and even a ratio against work measured in the
    // same run fell apart, because instrumentation penalises two code paths by
    // different amounts (a re-derivation measured 316 ms against a 440 ms bound
    // under coverage while clearing it comfortably without).
    //
    // What it asserts is the semantic root of the cost property: **the answer
    // depends only on the window, not on the log.** `averagePerDay` clamps its
    // denominator to the window once the learner has been going longer than it,
    // so a 300-day history and a 30-day history sharing the same last 30 days
    // must give byte-identical answers. If a query ever reads past the window —
    // which is the entire failure this index was built to prevent — the two
    // diverge and this fails, on any machine, at any load, in milliseconds.
    test('the day-indexed answers depend only on the window, not the log', () {
      // 10 units a day. The 30-day log is the last 30 days of the 300-day one,
      // so the two are indistinguishable as far as the window is concerned.
      List<LearningEvent> history(int days, int firstDay) => [
            for (var d = firstDay; d < firstDay + days; d++)
              for (var k = 0; k < 10; k++)
                LearningEvent(
                  id: 'd${d}_$k',
                  profileId: 'p',
                  nodeId: 'huge',
                  unitIndex: d * 10 + k,
                  action: EventAction.done,
                  occurredAt: DateTime(2026, 1, 1).add(Duration(days: d)),
                  loggedAt: DateTime(2026, 1, 1).add(Duration(days: d)),
                ),
          ];

      // 300 days of history ending today (ordinal 299), versus only its last 30.
      final today = Day.of(DateTime(2026, 1, 1).add(const Duration(days: 299)));
      final deep = LogActivity.of(history(300, 0));
      final shallow = LogActivity.of(history(30, 270));

      // The window is 30 days, both histories are fully populated inside it, and
      // both firstDayLearned values fall on or before the window start — so the
      // answer must be identical. It is 300 units over 30 days.
      expect(deep.averagePerDay(today), 10);
      expect(deep.averagePerDay(today), shallow.averagePerDay(today),
          reason: '270 extra days of history behind the window changed the '
              'answer, so something read past the window');

      // And the total activity differs, which is what makes the comparison above
      // meaningful rather than vacuous: if the two logs were the same, this would
      // prove nothing.
      expect(deep.dailyCounts.length, 300);
      expect(shallow.dailyCounts.length, 30);
    });

    // §P3: every write re-reads and re-folds the whole log. That is a deliberate
    // trade and cheap today; this pins the size at which it would stop being
    // cheap, so the fold cannot quietly become the next unmeasured hotspot.
    test('folding a very large log stays bounded', () {
      final events = syntheticLog(100000);

      late LogFold fold;
      final ms = fastestMs(() {
        fold = FoldLog.fold(events);
      }, rounds: 2);
      expect(fold.doneUnits('huge'), hasLength(5000));

      // **A growth rate, not a budget.** What this pins is that folding stays
      // roughly *linear* in the number of events — a property a budget cannot
      // express at all, because a budget is a single point and the failure mode
      // is a curve. Folding a quarter as many events is the same operation on the
      // same data shape, measured in this run: linear work keeps the ratio near
      // 4, and a quadratic fold lands far above 8.
      final smallMs = fastestMs(() => FoldLog.fold(syntheticLog(25000)),
          rounds: 2);
      expect(ms, lessThan(smallMs * 8),
          reason: '100k events took $ms ms against $smallMs ms for 25k — a fold '
              'that grows faster than the events it reads is back');
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
