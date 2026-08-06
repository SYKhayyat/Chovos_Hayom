import 'dart:async';
import 'dart:collection';

import 'package:chovos_hayom/application/goals.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/repositories/catalog_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_database.dart';

/// **How many times the event log is walked, counted.**
///
/// `fold_log.dart` opens by explaining that five ordered passes over the log
/// were collapsed into one, "which is what keeps a tap on a daf cheap for a user
/// with years of history". Downstream of it they had grown back:
/// `statsProvider` held a fold and then made five more passes over the list it
/// came from — the pace, the streak, the heatmap, the total minutes, the
/// month's minutes — `goalStatusProvider` made a sixth *per goal*, and the
/// dashboard made a seventh to decide whether to show a one-line banner.
///
/// None of that was visible. It is invisible to hands-on testing on any
/// hardware, because it scales with event count and a phone you tested last week
/// has a log of roughly zero; it was invisible to `derive_cost_test.dart`, which
/// calls `FoldLog.fold` directly, once, in isolation; and it was invisible to
/// `provider_notify_test.dart`, which counts notifications, and the number of
/// notifications was never the problem — the work done *before* deciding not to
/// notify was.
///
/// So this counts the work. The log hands out a counter on every element read,
/// which is the one thing `ListBase` routes all of iteration, `toList`, `where`
/// and `forEach` through, and the assertions are in whole passes over it.
///
/// The two that matter are not the absolute numbers — those are two, the two
/// indexes — but the *deltas*: adding ten goals must cost zero extra passes, and
/// a midnight tick must cost zero. Both were linear before.
void main() {
  /// Ten leaves, because the claim being tested is about N.
  const leafIds = [
    'shabbos', 'berachos', 'eruvin', 'pesachim', 'yoma',
    'sukkah', 'beitzah', 'rosh_hashanah', 'taanis', 'megillah',
  ];

  Catalog catalog() => Catalog([
        const CatalogNode(
            id: 'root', parentId: null, name: 'Root', kind: NodeKind.category),
        for (final id in leafIds)
          CatalogNode(
            id: id,
            parentId: 'root',
            name: id,
            kind: NodeKind.leaf,
            unitLabel: UnitLabel.daf,
            unitCount: 63,
            unitOffset: 2,
          ),
      ]);

  LearningEvent done(int unit, {String node = 'shabbos'}) => LearningEvent(
        id: '$node#$unit',
        profileId: 'default',
        nodeId: node,
        unitIndex: unit,
        action: EventAction.done,
        occurredAt: DateTime(2026, 1, 5).add(Duration(hours: 24 * (unit % 20))),
        loggedAt: DateTime(2026, 1, 5).add(Duration(hours: 24 * (unit % 20))),
      );

  late _CountingLog log;
  late StreamController<List<LearningEvent>> events;
  late ProviderContainer container;

  setUp(() async {
    log = _CountingLog([for (var u = 2; u < 62; u++) done(u)]);
    events = StreamController<List<LearningEvent>>.broadcast();
    addTearDown(events.close);

    container = ProviderContainer(overrides: [
      catalogRepositoryProvider
          .overrideWithValue(_FixedCatalogRepository(catalog())),
      // Custom nodes, layers and layer configs still come from a real (empty)
      // repository — the merged catalog and the layer roles both watch it.
      progressRepositoryProvider.overrideWithValue(memoryRepository()),
      appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
      clockProvider.overrideWithValue(() => DateTime(2026, 1, 20)),
      // The log is injected rather than written through a repository, so that
      // the thing under measurement is the only implementation detail in play.
      // A second `ProgressRepository` is banned, and rightly.
      eventsProvider.overrideWith((ref) => events.stream),
    ]);
    addTearDown(container.dispose);

    await container.read(catalogProvider.future);
    // Deliberately *not* subscribed: `backupStatusProvider` and
    // `batchHistoryProvider` also walk the log, for the two axes neither index
    // carries — "distinct units touched since an instant", keyed on `loggedAt`,
    // and "group by batch id". Both are one pass each and both are honest; they
    // are excluded here so the numbers below are about the day-indexed answers
    // this file is named for, and not a total that moves when an unrelated
    // provider is added.
    container.listen(statsProvider, (_, _) {});
    events.add(log);
    await pumpEventQueue();
  });

  test('a change to the log costs two passes: one per index', () {
    log.reset();
    events.add(_CountingLog([...log.inner, done(80)]));
    return pumpEventQueue().then((_) {
      // The new list carries its own counter; what this asserts is that the
      // *old* one is not read again, which is what a provider holding onto the
      // previous log and re-scanning it would look like.
      expect(log.passes, 0);
    });
  });

  test('deriving the whole stats surface costs two passes, not seven', () async {
    final fresh = _CountingLog([...log.inner, done(81)]);
    events.add(fresh);
    await pumpEventQueue();
    container.read(statsProvider);

    expect(fresh.passes, 2,
        reason: 'the fold and the day index, once each. Every extra pass here '
            'is a scalar being recomputed from the raw log — which is what '
            'statsProvider did five times over the fold it was already holding');
  });

  test('ten goal rows cost no passes at all', () async {
    // Ten goals is not a stress test; it is a user with a target date on ten
    // mesechtos, which is what the Goals screen is for.
    final controller = container.read(goalsProvider.notifier);
    for (var i = 0; i < leafIds.length; i++) {
      await controller.setGoal(
          leafIds[i], DateTime(2026, 6, 1).add(Duration(hours: 24 * i)));
    }
    await pumpEventQueue();

    log.reset();
    for (final id in leafIds) {
      container.listen(goalStatusProvider(id), (_, _) {});
    }
    await pumpEventQueue();

    expect(log.passes, 0,
        reason: 'each goal used to run PaceEngine.averagePerDay over the whole '
            'log itself, so ten of them cost ten identical thirty-day scans on '
            'every rebuild. The pace is one number for the profile, so it is '
            'derived once, in paceProvider');
  });

  test('a midnight tick re-derives everything and re-reads nothing', () async {
    container.listen(goalStatusProvider('shabbos'), (_, _) {});
    await container
        .read(goalsProvider.notifier)
        .setGoal('shabbos', DateTime(2026, 6, 1));
    await pumpEventQueue();

    log.reset();
    // What midnight and a return to the foreground both do. The clock is
    // overridden with a constant here, as it is in every other suite, so the
    // dependents are invalidated directly — the point is not whether the tick
    // propagates (provider_notify_test.dart owns that) but what re-deriving
    // costs once it does.
    container.invalidate(statsProvider);
    container.invalidate(paceProvider);
    container.invalidate(goalStatusProvider('shabbos'));
    container.read(statsProvider);
    container.read(goalStatusProvider('shabbos'));
    await pumpEventQueue();

    expect(log.passes, 0,
        reason: 'neither index depends on the clock, so a date change re-reads '
            'no events. This used to cost five passes for stats plus one per '
            'goal, every midnight and every app resume');
  });

  test('the counter counts what it claims to', () {
    // A source of truth for the numbers above: iteration, `toList`, `where` and
    // an indexed read all have to register, or every assertion here is a green
    // test measuring nothing.
    final probe = _CountingLog([done(2), done(3), done(4)]);
    for (final _ in probe) {}
    expect(probe.passes, 1);
    probe.toList();
    expect(probe.passes, 2);
    probe.where((e) => e.unitIndex > 2).toList();
    expect(probe.passes, 3);
    probe.reset();
    probe[0];
    expect(probe.visits, 1);
  });
}

/// The event log, counting every element read.
///
/// `ListBase` implements iteration, `toList`, `where`, `map` and `forEach` in
/// terms of `length` and `operator []`, so overriding the one subscript is
/// enough to see all of them — and a `.length` read, which is not a walk, does
/// not register.
class _CountingLog extends ListBase<LearningEvent> {
  _CountingLog(this.inner);

  final List<LearningEvent> inner;
  int visits = 0;

  /// Element reads expressed in whole walks of the log.
  double get passes => inner.isEmpty ? 0 : visits / inner.length;

  void reset() => visits = 0;

  @override
  int get length => inner.length;

  @override
  set length(int value) => throw UnsupportedError('the log is append-only');

  @override
  LearningEvent operator [](int index) {
    visits++;
    return inner[index];
  }

  @override
  void operator []=(int index, LearningEvent value) =>
      throw UnsupportedError('the log is append-only');
}

class _FixedCatalogRepository implements CatalogRepository {
  _FixedCatalogRepository(this.catalog);
  final Catalog catalog;

  @override
  Future<Catalog> load() async => catalog;
}
