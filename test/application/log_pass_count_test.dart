import 'dart:async';

import 'package:chovos_hayom/application/backup_status.dart';
import 'package:chovos_hayom/application/goals.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/settings.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/repositories/catalog_repository.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/counting_log.dart';
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
/// So this counts the work. The log hands out a counter on every element read
/// ([CountingLog]), which is the one thing `ListBase` routes all of iteration,
/// `toList`, `where` and `forEach` through, and the assertions are in whole
/// passes over it.
///
/// The two that matter are not the absolute numbers — those are two, the two
/// indexes — but the *deltas*: adding ten goals must cost zero extra passes, and
/// a midnight tick must cost zero. Both were linear before.
///
/// **This file chooses its own subscriptions, which is its blind spot.** The
/// numbers below are what the graph costs when a test decides what is being
/// watched; a user does not. `log_pass_screen_test.dart` counts the same way
/// with real screens mounted, where the subscription set is whatever the app
/// actually holds, and it is the file that owns the axes excluded here.
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

  late CountingLog log;
  late StreamController<List<LearningEvent>> events;
  late ProviderContainer container;

  setUp(() async {
    log = CountingLog([for (var u = 2; u < 62; u++) done(u)]);
    events = StreamController<List<LearningEvent>>.broadcast();
    addTearDown(events.close);

    container = ProviderContainer(overrides: [
      catalogRepositoryProvider
          .overrideWithValue(_FixedCatalogRepository(catalog())),
      // Custom nodes, layers and layer configs still come from a real (empty)
      // repository — the merged catalog and the layer roles both watch it.
      progressRepositoryProvider.overrideWithValue(memoryRepository()),
      appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
      // A builder rather than `overrideWithValue`, so the clock can be
      // *invalidated* — which is what a midnight tick and an app resume both do
      // to it, and the only way to make one happen to a provider without
      // disposing that provider's own element.
      clockProvider.overrideWith((ref) => () => DateTime(2026, 1, 20)),
      // The log is injected rather than written through a repository, so that
      // the thing under measurement is the only implementation detail in play.
      // A second `ProgressRepository` is banned, and rightly.
      eventsProvider.overrideWith((ref) => events.stream),
    ]);
    addTearDown(container.dispose);

    await container.read(catalogProvider.future);
    // Deliberately *not* subscribed here: `backupStatusProvider` and
    // `batchHistoryProvider` also walk the log, for the two axes neither index
    // carries — "distinct units touched since an instant", keyed on `loggedAt`,
    // and "group by batch id". They are excluded from the numbers below so those
    // stay about the day-indexed answers this file is named for, and not a total
    // that moves when an unrelated provider is added. The backup axis gets its
    // own group at the bottom, because "one pass each and both honest" was true
    // of the pass and false of when it ran. `batchHistoryProvider` is counted in
    // `log_pass_screen_test.dart` instead, on the two screens that watch it —
    // where the thing worth knowing is that it costs nothing on every other one.
    container.listen(statsProvider, (_, _) {});
    events.add(log);
    await pumpEventQueue();
  });

  test('a change to the log costs two passes: one per index', () {
    log.reset();
    events.add(CountingLog([...log.inner, done(80)]));
    return pumpEventQueue().then((_) {
      // The new list carries its own counter; what this asserts is that the
      // *old* one is not read again, which is what a provider holding onto the
      // previous log and re-scanning it would look like.
      expect(log.passes, 0);
    });
  });

  test('deriving the whole stats surface costs two passes, not seven', () async {
    final fresh = CountingLog([...log.inner, done(81)]);
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

  /// The backup reminder is the third axis over the log — distinct units
  /// recorded since an *instant*, keyed on `loggedAt`, which neither day index
  /// can answer. One pass per change is the honest price of that, and it is not
  /// what these are about: the provider also watched the clock and the whole
  /// settings object, and the count it walks the log to produce depends on
  /// neither. So a midnight tick, an app resume and every theme toggle each paid
  /// a full walk of the log to arrive at the number they already had.
  ///
  /// It was invisible for the usual two reasons and one new one:
  /// `provider_notify_test.dart` asserts a tick over unchanged data notifies
  /// nobody, which was true and never the question; and this file's own
  /// "a midnight tick re-derives everything and re-reads nothing" excluded the
  /// one provider that re-read.
  group('the backup axis', () {
    /// What the dashboard does: it watches this from the moment the app opens,
    /// so it is live for every tick and every settings write.
    void watchBackup() => container.listen(backupStatusProvider, (_, _) {});

    test('a midnight tick costs it nothing', () async {
      watchBackup();
      await pumpEventQueue();

      log.reset();
      // The *clock* is invalidated, not the provider under test — the two are
      // not interchangeable here. Invalidating `backupStatusProvider` disposes
      // its element, which would throw away the memo along with it and measure
      // a cold start; a real tick only ever hands it a new `DateTime Function()`
      // and asks again. (The fresh closure is what makes that a change at all —
      // see the note on `clockProvider`.)
      container.invalidate(clockProvider);
      container.read(backupStatusProvider);
      await pumpEventQueue();

      expect(log.passes, 0,
          reason: 'the units recorded since the last export cannot change '
              'because the date did. Only `daysSinceBackup` moves at midnight, '
              'and that is a subtraction');
    });

    test('changing an unrelated setting costs it nothing', () async {
      watchBackup();
      await pumpEventQueue();

      log.reset();
      await container.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
      await pumpEventQueue();

      expect(log.passes, 0,
          reason: 'it needs two scalars out of the settings object and watched '
              'the whole of it, so switching to dark mode walked every event '
              'ever recorded');
    });

    test('a log change costs it exactly one pass', () async {
      watchBackup();
      await pumpEventQueue();

      final fresh = CountingLog([...log.inner, done(82)]);
      events.add(fresh);
      await pumpEventQueue();
      container.read(statsProvider);
      container.read(backupStatusProvider);

      expect(fresh.passes, 3,
          reason: 'the fold, the day index, and the backup axis once each. This '
              'is the number that is allowed to be non-zero — a new event '
              'genuinely can change what is unsaved');
    });
  });

  test('the counter counts what it claims to', () {
    // A source of truth for the numbers above *and* for the ones in
    // `log_pass_screen_test.dart`, which counts the same way over real screens:
    // iteration, `toList`, `where` and an indexed read all have to register, or
    // every assertion in both files is a green test measuring nothing.
    final probe = CountingLog([done(2), done(3), done(4)]);
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

class _FixedCatalogRepository implements CatalogRepository {
  _FixedCatalogRepository(this.catalog);
  final Catalog catalog;

  @override
  Future<Catalog> load() async => catalog;
}
