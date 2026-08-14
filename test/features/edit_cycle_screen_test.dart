import 'dart:convert';

import 'package:chovos_hayom/application/cycles.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/domain/usecases/learning_cycle.dart';
import 'package:chovos_hayom/features/cycles/edit_cycle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// The screen that builds a learning cycle.
///
/// It had **1.4% coverage** — the least-covered file in the repository, and the
/// one the per-layer coverage gate printed first the day it started saying which
/// files it was unhappy about. That is worth stating plainly: a cycle is the one
/// thing in this app the user constructs rather than merely records, every one of
/// its rules lives in this file, and none of them were held by anything.
///
/// So these are about the rules, not the pixels: what a cycle is allowed to be,
/// that the order is the cycle, that editing edits rather than duplicates, and
/// that a category means everything under it.
void main() {
  const profile = 'default';
  final key = PrefKeys.scoped(profile, PrefKeys.cycles);

  /// The cycles a run has actually persisted, read back out of preferences the
  /// way the app will read them on the next launch — rather than off the
  /// notifier, which would pass just as well if nothing was ever written.
  List<SequentialCycle> saved(InMemoryPreferences prefs) {
    final raw = prefs.getString(key);
    if (raw == null) return const [];
    return CyclesConfig.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>())
        .custom;
  }

  /// Two more leaves under Shas, so "add a category" has something to be about,
  /// and one of them empty — a category the user has made but not filled in.
  ///
  /// Added as custom nodes rather than by faking a second catalog: this is how a
  /// user's own sefer reaches the tree, so the merge is under test too.
  Future<void> addSefarim(ProgressRepository repo) async {
    await repo.addCustomNode(
      profile,
      const CatalogNode(
        id: 'shas.moed.eruvin',
        parentId: 'shas.moed',
        name: 'Eruvin',
        kind: NodeKind.leaf,
        unitLabel: UnitLabel.daf,
        unitCount: 104,
        unitOffset: 2,
      ),
    );
    await repo.addCustomNode(
      profile,
      const CatalogNode(
        id: 'shas.moed.empty',
        parentId: 'shas.moed',
        name: 'Not written yet',
        kind: NodeKind.leaf,
        unitLabel: UnitLabel.daf,
      ),
    );
  }

  ({Widget widget, InMemoryPreferences prefs, ProgressRepository repo}) harness({
    String? cycleId,
    Map<String, String>? seed,
  }) {
    final prefs = InMemoryPreferences(seed);
    final repo = memoryRepository();
    return (
      prefs: prefs,
      repo: repo,
      widget: ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(prefs),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => DateTime(2026, 8, 14, 9)),
        ],
        child: localizedApp(home: EditCycleScreen(cycleId: cycleId)),
      ),
    );
  }

  /// `pumpAndSettle` with a real deadline on it.
  ///
  /// The default is **ten minutes**, which is not a timeout so much as a way of
  /// turning "this never settles" into a file that appears to hang and then
  /// blames whichever test the binding was left wedged in. Fifteen seconds of
  /// frames is far more than any animation here needs, and when it is exceeded
  /// the failure names the line that spun.
  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );

  /// Pump [widget] on a screen tall enough to hold the whole form.
  ///
  /// The form is a `ListView`, so on the 800x600 default the save button is not
  /// merely off-screen — it is never built, and a finder for it comes back
  /// empty. Which is a fair description of a real 240dp Sonim, but it is the
  /// scroll under test then, and that is `keypad_test.dart`'s job.
  Future<void> pump(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await settle(tester);
  }

  /// Open the picker and take the row labelled [label] — the qualified name, as
  /// the picker shows it ("Shabbos — Shas · Moed"), because "Moed" on its own
  /// also appears inside every one of its children's labels.
  Future<void> addSefer(WidgetTester tester, String label) async {
    await tester.tap(find.text('Add a sefer'));
    await settle(tester);
    await tester.tap(find.text(label));
    await settle(tester);
  }

  /// Tap a button that is expected to *refuse*, and check what it said.
  ///
  /// The pumping is spelled out because of what a SnackBar is. A bare
  /// `pumpAndSettle` after the tap waits on a bar sitting behind a **timer**
  /// rather than an animation — which means the ten-minute default, and then a
  /// timeout reported as something else entirely. And a test that ends while
  /// that timer is still pending fails in teardown, several tests away from the
  /// one that armed it, so the last pump lets the bar leave of its own accord.
  Future<void> expectRefusal(
      WidgetTester tester, String button, String message) async {
    await tester.tap(find.text(button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(find.text(message), findsOneWidget);

    // Advance past the bar's four-second life so its timer fires here rather
    // than after the test has ended, then let it animate away.
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
  }

  Future<void> fillIn(WidgetTester tester,
      {required String name, String perDay = '1'}) async {
    await tester.enterText(find.widgetWithText(TextField, 'Name'), name);
    await tester.enterText(
        find.widgetWithText(TextField, 'Units per day'), perDay);
    await settle(tester);
  }

  group('creating one', () {
    testWidgets('a named cycle with a sefer in it is saved and persists',
        (tester) async {
      final h = harness();
      await pump(tester, h.widget);

      await fillIn(tester, name: 'My chazara seder', perDay: '3');
      await addSefer(tester, 'Shabbos — Shas · Moed');
      await tester.tap(find.text('Create cycle'));
      await settle(tester);

      final cycle = saved(h.prefs).single;
      expect(cycle.name, 'My chazara seder');
      expect(cycle.unitsPerDay, 3);
      expect(cycle.repeats, isTrue, reason: 'the default the switch shows');
      expect(cycle.segments.single.nodeId, 'shas.moed.shabbos');
      expect(cycle.segments.single.unitCount, 156);
      expect(cycle.segments.single.unitOffset, 2,
          reason: 'Shabbos starts at daf 2, and a cycle that walks it from 1 '
              'is a cycle whose every day is off by one');
    });

    testWidgets('picking a category takes every sefer under it, in order',
        (tester) async {
      // "All of Shas, in order" is one action rather than thirty-seven — the
      // reason the picker offers categories at all.
      final h = harness();
      await addSefarim(h.repo);
      await pump(tester, h.widget);

      await fillIn(tester, name: 'Shas');
      await addSefer(tester, 'Moed — Shas');
      await tester.tap(find.text('Create cycle'));
      await settle(tester);

      final segments = saved(h.prefs).single.segments;
      expect(segments.map((s) => s.nodeId),
          ['shas.moed.eruvin', 'shas.moed.shabbos'],
          reason: 'the order the tree shows them in — sortOrder, then name, '
              'which is what "in order" has to mean here: the cycle walks the '
              'sefarim in the order the user is looking at, not the order the '
              'rows happen to be stored in');
      expect(segments.map((s) => s.nodeId), isNot(contains('shas.moed.empty')),
          reason: 'a sefer with no units would be a day the cycle spends on '
              'nothing');
    });
  });

  group('what a cycle is not allowed to be', () {
    // Each of these is a `guard.report` branch: the write does not happen, the
    // screen stays open, and the reason is on the screen rather than in a log.
    testWidgets('nameless', (tester) async {
      final h = harness();
      await pump(tester, h.widget);

      await addSefer(tester, 'Shabbos — Shas · Moed');
      await expectRefusal(tester, 'Create cycle', 'Give the cycle a name.');

      expect(saved(h.prefs), isEmpty);
    });

    testWidgets('paced at something that is not a positive number',
        (tester) async {
      // Through `positiveInt`, like every other "is this a positive integer" in
      // the app. A cycle at 0 a day never advances; one at "a few" is a parse
      // this screen must not invent an answer for.
      final h = harness();
      await pump(tester, h.widget);

      await fillIn(tester, name: 'Mishna Yomi', perDay: '0');
      await addSefer(tester, 'Shabbos — Shas · Moed');
      await expectRefusal(
          tester, 'Create cycle', 'Units per day must be at least 1.');

      expect(saved(h.prefs), isEmpty);
    });

    testWidgets('empty of sefarim', (tester) async {
      final h = harness();
      await pump(tester, h.widget);

      await fillIn(tester, name: 'Nothing at all');
      await expectRefusal(tester, 'Create cycle',
          'Add at least one sefer for the cycle to walk.');

      expect(saved(h.prefs), isEmpty);
    });
  });

  group('the order is the cycle', () {
    Future<void> withTwo(WidgetTester tester,
        ({Widget widget, InMemoryPreferences prefs, ProgressRepository repo})
            h) async {
      await addSefarim(h.repo);
      await pump(tester, h.widget);
      await fillIn(tester, name: 'Two sefarim');
      await addSefer(tester, 'Shabbos — Shas · Moed');
      await addSefer(tester, 'Eruvin — Shas · Moed');
    }

    testWidgets('move down swaps a sefer with the one after it',
        (tester) async {
      final h = harness();
      await withTwo(tester, h);

      // The first row's *Move down* — the mouse-and-keyboard path, since the
      // drag handle beside it needs a pointer this device may not have.
      await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_downward).first);
      await settle(tester);
      await tester.tap(find.text('Create cycle'));
      await settle(tester);

      expect(saved(h.prefs).single.segments.map((s) => s.nodeId),
          ['shas.moed.eruvin', 'shas.moed.shabbos']);
    });

    testWidgets('the ends of the list cannot be moved off it', (tester) async {
      final h = harness();
      await withTwo(tester, h);

      final up = tester.widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.arrow_upward));
      final down = tester.widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.arrow_downward));

      expect(up.first.onPressed, isNull, reason: 'the first has nowhere up');
      expect(down.last.onPressed, isNull, reason: 'the last has nowhere down');
      expect(up.last.onPressed, isNotNull);
      expect(down.first.onPressed, isNotNull);
    });

    testWidgets('removing a sefer leaves the rest of the order alone',
        (tester) async {
      final h = harness();
      await withTwo(tester, h);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.close).first);
      await settle(tester);
      await tester.tap(find.text('Create cycle'));
      await settle(tester);

      expect(saved(h.prefs).single.segments.map((s) => s.nodeId),
          ['shas.moed.eruvin']);
    });
  });

  group('editing an existing one', () {
    final existing = SequentialCycle(
      id: 'cycle-1',
      name: 'Mishna Yomi',
      startDate: DateTime(2026, 1, 1),
      unitsPerDay: 2,
      repeats: false,
      segments: const [
        CycleSegment(nodeId: 'shas.moed.shabbos', unitCount: 156, unitOffset: 2),
      ],
    );

    Map<String, String> seedWith(SequentialCycle cycle) => {
          PrefKeys.scoped(profile, PrefKeys.cycles):
              jsonEncode(CyclesConfig(custom: [cycle]).toJson()),
        };

    testWidgets('arrives filled in, rather than as a blank form',
        (tester) async {
      final h = harness(cycleId: 'cycle-1', seed: seedWith(existing));
      await pump(tester, h.widget);

      expect(find.text('Edit cycle'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Mishna Yomi'), findsOneWidget);
      expect(find.widgetWithText(TextField, '2'), findsOneWidget);
      expect(find.text('Shabbos'), findsOneWidget);
      expect(find.text('156 units from 2'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse,
          reason: 'a cycle that does not repeat must not come back saying it '
              'does');
    });

    testWidgets('saves over the cycle rather than adding a second',
        (tester) async {
      // `widget.existing?.id ?? Uuid().v4()` is one `??` away from turning every
      // edit into a duplicate — and a duplicated cycle is not obviously wrong on
      // screen, it just quietly doubles what today asks for.
      final h = harness(cycleId: 'cycle-1', seed: seedWith(existing));
      await pump(tester, h.widget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Mishna Yomi'), 'Mishna Yomi (2 a day)');
      await tester.tap(find.text('Save cycle'));
      await settle(tester);

      final cycles = saved(h.prefs);
      expect(cycles, hasLength(1));
      expect(cycles.single.id, 'cycle-1');
      expect(cycles.single.name, 'Mishna Yomi (2 a day)');
      expect(cycles.single.startDate, DateTime(2026, 1, 1),
          reason: 'the day it started is not a thing an edit invents anew');
    });

    testWidgets('a cycle that no longer exists says so', (tester) async {
      // Reachable by a deep link, or by a bookmark to a cycle since deleted —
      // the screen reads the cycle as it is now, not as it was when the route
      // was written.
      final h = harness(cycleId: 'gone', seed: seedWith(existing));
      await pump(tester, h.widget);

      expect(find.textContaining('no longer exists'), findsOneWidget);
      expect(find.text('Create cycle'), findsNothing);
    });
  });
}
