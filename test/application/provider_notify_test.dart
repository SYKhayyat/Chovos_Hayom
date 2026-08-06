import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/application/backup_status.dart';
import 'package:chovos_hayom/application/goals.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/settings.dart';
import 'package:chovos_hayom/application/sorting.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/repositories/catalog_repository.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_database.dart';

/// **What notifies what, counted.**
///
/// Riverpod re-notifies whenever `previous != next`, and until this landed
/// nothing in `lib/` had an `operator ==` — every provider returned a
/// freshly-allocated object, so *every* hand-off in the graph notified
/// unconditionally. One marked daf re-ran the whole chain: the fold, all ~312
/// rolled-up nodes, the index, then every `progressNodeProvider` and
/// `goalStatusProvider` element anyone had opened this session, because a family
/// keeps its elements alive forever unless told not to.
///
/// The derivation still runs — that part is correct and cheap, and
/// `derive_cost_test.dart` measures it. What changed is where it *stops*: at the
/// value boundary, when the value did not move. These tests count the crossings.
///
/// Every one of them fails on the pre-fix code, which is the only thing that
/// makes them worth their runtime.
void main() {
  /// Two leaves under two parents, so "a change over here" and "a change over
  /// there" are distinguishable — the shared `fakeCatalog()` has one leaf, and
  /// one leaf cannot show that a mark is *scoped*.
  Catalog twoLeafCatalog() => Catalog(const [
        CatalogNode(
            id: 'root',
            parentId: null,
            name: 'Kol HaTorah Kula',
            kind: NodeKind.category),
        CatalogNode(
            id: 'shas',
            parentId: 'root',
            name: 'Shas',
            kind: NodeKind.category),
        CatalogNode(
            id: 'shas.moed',
            parentId: 'shas',
            name: 'Moed',
            kind: NodeKind.category),
        CatalogNode(
          id: 'shas.moed.shabbos',
          parentId: 'shas.moed',
          name: 'Shabbos',
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.daf,
          unitCount: 156,
          unitOffset: 2,
        ),
        CatalogNode(
            id: 'shas.zeraim',
            parentId: 'root',
            name: 'Zeraim',
            kind: NodeKind.category),
        CatalogNode(
          id: 'shas.zeraim.berachos',
          parentId: 'shas.zeraim',
          name: 'Berachos',
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.daf,
          unitCount: 63,
          unitOffset: 2,
        ),
      ]);

  LearningEvent done(String nodeId, int unit) => LearningEvent(
        id: '$nodeId#$unit',
        profileId: 'default',
        nodeId: nodeId,
        unitIndex: unit,
        action: EventAction.done,
        occurredAt: DateTime(2026, 1, 1),
        loggedAt: DateTime(2026, 1, 1),
      );

  late ProgressRepository repo;
  late ProviderContainer container;

  setUp(() async {
    repo = memoryRepository();
    container = ProviderContainer(overrides: [
      catalogRepositoryProvider
          .overrideWithValue(_FixedCatalogRepository(twoLeafCatalog())),
      progressRepositoryProvider.overrideWithValue(repo),
      appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
      clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
    ]);
    addTearDown(container.dispose);
    // Warm the whole graph before any counter is attached.
    //
    // Riverpod builds lazily, so a provider first reached *inside* a test is
    // created there — and `eventsProvider` is a stream, so its element starts in
    // `loading` and emits again the moment the log arrives. Counting from a cold
    // graph therefore counts that loading → loaded transition as if it were the
    // change under test, which is a green test measuring the wrong thing in one
    // direction and a red one in the other. Subscribing here also keeps these
    // alive for the test's duration, which is what an open screen would do.
    await container.read(catalogProvider.future);
    container.listen(eventsProvider, (_, _) {});
    container.listen(progressIndexProvider, (_, _) {});
    container.listen(statsProvider, (_, _) {});
    container.listen(backupStatusProvider, (_, _) {});
    await pumpEventQueue();
  });

  group('progressNodeProvider', () {
    test('a mark in one mesechta does not notify another one', () async {
      // Both elements alive, as they would be with two screens open — or, before
      // autoDispose, with two screens merely having *been* open.
      final shabbos = _Counter();
      final berachos = _Counter();
      container.listen(progressNodeProvider('shas.moed.shabbos'),
          (_, _) => shabbos.bump());
      container.listen(progressNodeProvider('shas.zeraim.berachos'),
          (_, _) => berachos.bump());

      await repo.addEvent(done('shas.moed.shabbos', 12));
      await pumpEventQueue();

      expect(shabbos.value, 1, reason: 'its own subtree gained a daf');
      expect(berachos.value, 0,
          reason: 'Berachos did not move, so nothing that renders Berachos — '
              'its tile, its goal row, its open screen — should rebuild');
    });

    test('a mark notifies every node on its own ancestor chain', () async {
      final leaf = _Counter();
      final parent = _Counter();
      final root = _Counter();
      final sibling = _Counter();
      container.listen(
          progressNodeProvider('shas.moed.shabbos'), (_, _) => leaf.bump());
      container.listen(
          progressNodeProvider('shas.moed'), (_, _) => parent.bump());
      container.listen(progressNodeProvider('root'), (_, _) => root.bump());
      container.listen(
          progressNodeProvider('shas.zeraim'), (_, _) => sibling.bump());

      await repo.addEvent(done('shas.moed.shabbos', 12));
      await pumpEventQueue();

      expect([leaf.value, parent.value, root.value], [1, 1, 1],
          reason: 'learned rolls up, so the chain genuinely changed');
      expect(sibling.value, 0);
    });

    test('an element is disposed once nothing is listening to it', () async {
      final node = progressNodeProvider('shas.moed.shabbos');
      final sub = container.listen(node, (_, _) {});
      expect(container.exists(node), isTrue);

      sub.close();
      await pumpEventQueue();

      expect(container.exists(node), isFalse,
          reason: 'a family without autoDispose keeps one element per argument '
              'for the life of the container, and each of them re-derives on '
              'every mark — for screens that were closed an hour ago');
    });
  });

  group('goalStatusProvider', () {
    test('a mark that moves none of this goal\'s numbers does not notify it',
        () async {
      await container
          .read(goalsProvider.notifier)
          .setGoal('shas.zeraim.berachos', DateTime(2026, 6, 1));
      final berachosGoal = _Counter();
      container.listen(
          goalStatusProvider('shas.zeraim.berachos'),
          (_, _) => berachosGoal.bump());

      // A different mesechta *and* outside the 30-day pace window, so neither
      // `remaining` nor `currentPace` moves. The provider still re-derives — it
      // watches the log — it just has nothing new to say, and says nothing.
      await repo.addEvent(LearningEvent(
        id: 'ancient',
        profileId: 'default',
        nodeId: 'shas.moed.shabbos',
        unitIndex: 12,
        action: EventAction.done,
        occurredAt: DateTime(2020, 1, 1),
        loggedAt: DateTime(2020, 1, 1),
      ));
      await pumpEventQueue();

      expect(berachosGoal.value, 0);
    });

    test('a mark inside the pace window notifies every goal, and should',
        () async {
      // The honest other half, pinned so a later "optimisation" cannot quietly
      // take it away. `currentPace` is a whole-log average, so learning a daf of
      // Shabbos genuinely changes whether the *Berachos* goal is on track. That
      // rebuild is the feature, not the waste.
      await container
          .read(goalsProvider.notifier)
          .setGoal('shas.zeraim.berachos', DateTime(2026, 6, 1));
      final berachosGoal = _Counter();
      container.listen(
          goalStatusProvider('shas.zeraim.berachos'),
          (_, _) => berachosGoal.bump());

      await repo.addEvent(done('shas.moed.shabbos', 12));
      await pumpEventQueue();

      expect(berachosGoal.value, 1);
    });

    test('a mark inside the goal\'s own node does re-evaluate it', () async {
      await container
          .read(goalsProvider.notifier)
          .setGoal('shas.moed.shabbos', DateTime(2026, 6, 1));
      final goal = _Counter();
      container.listen(
          goalStatusProvider('shas.moed.shabbos'), (_, _) => goal.bump());

      await repo.addEvent(done('shas.moed.shabbos', 12));
      await pumpEventQueue();

      expect(goal.value, 1, reason: 'remaining went down; the row must say so');
    });
  });

  group('settingsProvider', () {
    test('changing the backup interval does not notify a calendar reader',
        () async {
      final calendar = _Counter();
      final sort = _Counter();
      final wholeObject = _Counter();
      container.listen(settingsProvider.select((s) => s.calendar),
          (_, _) => calendar.bump());
      container.listen(
          settingsProvider.select((s) => s.sort), (_, _) => sort.bump());
      container.listen(settingsProvider, (_, _) => wholeObject.bump());

      await container.read(settingsProvider.notifier).setBackupIntervalDays(30);
      await pumpEventQueue();

      expect(calendar.value, 0);
      expect(sort.value, 0);
      // The negative control, and the reason the `.select`s at the call sites
      // are not decoration: anything watching the whole object still rebuilds.
      // Thirteen screens did — the calculator, cycles, goals, the journal,
      // siyumim, stats and the unit grid, because one number in Settings moved.
      expect(wholeObject.value, 1);
    });

    test('a settings write that changes nothing notifies nobody', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.setBackupIntervalDays(30);
      await pumpEventQueue();

      final wholeObject = _Counter();
      container.listen(settingsProvider, (_, _) => wholeObject.bump());
      await notifier.setBackupIntervalDays(30);
      await pumpEventQueue();

      expect(wholeObject.value, 0,
          reason: 'SettingsState has value equality, so re-writing the same '
              'value is not a change');
    });

    test('SortConfig compares by value, so a reloaded config is not a change',
        () async {
      // `_load()` rebuilds a *fresh* SortConfig from the stored strings, which
      // is what `applyBackup`, `clearAll` and a profile switch all go through.
      //
      // Deliberately the *wide* mode: a merge now declines to overwrite a key
      // the profile already has, so a second merge would notify nobody by never
      // writing — which would pass this test without exercising the reload this
      // test is about. `restoreEverything` clears and rewrites every time, so
      // the only thing standing between it and a notification is `SortConfig.==`.
      final sort = _Counter();
      container.listen(
          settingsProvider.select((s) => s.sort), (_, _) => sort.bump());
      await container.read(settingsProvider.notifier).applyBackup(
          {PrefKeys.sortMetric: SortMetric.name.name},
          ImportMode.restoreEverything);
      await pumpEventQueue();
      expect(sort.value, 1, reason: 'the metric genuinely changed');

      await container.read(settingsProvider.notifier).applyBackup(
          {PrefKeys.sortMetric: SortMetric.name.name},
          ImportMode.restoreEverything);
      await pumpEventQueue();
      expect(sort.value, 1, reason: 'the second import says the same thing');
    });
  });

  group('the clock', () {
    test('a rebuilt clock is a different function, so the tick propagates', () {
      // The one-character bug this file's neighbours could not see:
      // `return DateTime.now;` is a static tear-off and Dart canonicalises
      // those, so the provider rebuilt and then handed back a value `==` to the
      // last one. Riverpod propagated nothing; the midnight timer and
      // `invalidateClock` on resume both fired into a wall, and today's Daf Yomi
      // stayed frozen on the day the app was opened.
      //
      // Deliberately does **not** override `clockProvider` — all 19 other call
      // sites do, with `() => fixedDate`, a fresh closure that is never equal to
      // anything. That is why the suite could not observe this.
      final real = ProviderContainer();
      addTearDown(real.dispose);

      var notifications = 0;
      real.listen(clockProvider, (_, _) => notifications++);
      real.invalidate(clockProvider);
      real.read(clockProvider);

      expect(notifications, 1,
          reason: 'if the clock hands back the identical object on every '
              'rebuild, nothing date-dependent ever re-derives');
    });

    test('re-deriving stats over unchanged data notifies nobody', () async {
      await repo.addEvent(done('shas.moed.shabbos', 12));
      await pumpEventQueue();

      final stats = _Counter();
      final backup = _Counter();
      container.listen(statsProvider, (_, _) => stats.bump());
      container.listen(backupStatusProvider, (_, _) => backup.bump());

      // What a midnight tick and a return to the foreground both do: force
      // everything date-dependent to re-derive. The work runs; the answers are
      // the same; nothing that renders them should repaint.
      //
      // Invalidated directly rather than through `clockProvider`, because the
      // clock is overridden with a *constant* here as it is in all 19 other
      // suites — invalidating that hands back the identical function and
      // nothing downstream rebuilds at all, so it would prove nothing. This
      // forces the rebuild and asks what comes out of it.
      container.invalidate(statsProvider);
      container.invalidate(backupStatusProvider);
      container.read(statsProvider);
      container.read(backupStatusProvider);
      await pumpEventQueue();

      expect(stats.value, 0);
      expect(backup.value, 0);
    });

    test('stats still notify when the numbers actually move', () async {
      final stats = _Counter();
      container.listen(statsProvider, (_, _) => stats.bump());
      await repo.addEvent(done('shas.moed.shabbos', 12));
      await pumpEventQueue();
      expect(stats.value, 1);
    });
  });
}

/// A notification tally.
class _Counter {
  int value = 0;
  void bump() => value++;
}

class _FixedCatalogRepository implements CatalogRepository {
  _FixedCatalogRepository(this.catalog);
  final Catalog catalog;

  @override
  Future<Catalog> load() async => catalog;
}
