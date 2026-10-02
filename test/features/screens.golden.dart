import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'dart:io';

import 'package:chovos_hayom/core/calendar.dart';
import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/features/common/date_field.dart';
import 'package:chovos_hayom/features/planner/calendar_screen.dart';
import 'package:chovos_hayom/features/planner/edit_plan_advanced_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// Renders the screens to PNG so they can be **looked at**, not just asserted on.
///
/// Everything in this repository's tests is a claim about numbers: a scale
/// factor, an exception, a string. None of it is a claim about whether a 9sp
/// amount is readable on a 240x324 screen at 213dpi, and that is exactly the
/// question the 240dp month cell raised — a scale of 0.97 means "not much
/// shrinking", which is not the same as "legible", and only an eye settles it.
///
/// **Not named `*_test.dart`, so the suite never collects it.** It compares
/// against the committed PNGs by default, which would put a screenshot in CI's
/// path for no benefit; run it on demand instead:
///
///     flutter test test/features/screens.golden.dart --update-goldens
///
/// which rewrites the PNGs. Then open them, or have an agent read them — which
/// is the point. Every other test in this repository is a claim about numbers,
/// and a scale factor of 0.97 is not a claim about whether a 9sp amount is
/// readable on a 240x324 screen at 213dpi.
///
/// The real fonts the device uses, so the renders show letters and icons.
///
/// A golden from `flutter test` draws every glyph as a filled rectangle: the
/// binding's default font is Ahem, which is deliberately a box so that tests can
/// assert on *layout* without depending on a typeface. That is exactly wrong
/// for a screenshot meant to answer "is this readable" — the whole point of
/// looking is the glyphs, and the boxes are not glyphs.
///
/// Roboto is what Material uses on Android, where this app's target device
/// runs, and Material's own icon family for the same reason — without it every
/// `Icon` in the app is a hollow square, which reads as a broken product in a
/// screenshot when it is only a missing font. Both come from the engine's own
/// tree, found by search rather than written as a path so this file is not one
/// machine's fingerprint.
///
/// This is still not the device. Roboto at 213dpi seen by a person is the only
/// version of that claim that counts, and nothing here can settle it.
Future<void> loadDeviceFonts() async {
  final home = Platform.environment['HOME'] ?? '';
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '$home/flutter-3.44.4';
  const engineFonts =
      '/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf';
  final wanted = {
    'Roboto': [
      '$flutterRoot$engineFonts',
      // A release SDK keeps the same tree.
      '${Platform.environment['FLUTTER_ROOT'] ?? ''}$engineFonts',
    ],
    'MaterialIcons': [
      '$flutterRoot/engine/src/flutter/tools/font_subset/fixtures/'
          'MaterialIcons-Regular.ttf',
    ],
    // **Roboto has no Hebrew in it.** Without a Hebrew family the entire Hebrew
    // interface renders as notdef boxes — which is the entire point of the
    // parser, the calendar's Hebrew mode and the date field's right-to-left
    // layout, none of which had been *looked* at before this. The family is
    // found by search for the same reason as the others, and its absence is
    // reported rather than silently producing boxes.
    'Noto Sans Hebrew': [
      for (final dir in [
        '/run/current-system/sw/share/X11/fonts',
        '$home/.nix-profile/share/X11/fonts',
      ])
        '$dir/NotoSansHebrew.ttf',
    ],
  };
  for (final entry in wanted.entries) {
    final paths = entry.value.toSet();
    final file = paths
        .map(File.new)
        .firstWhere((f) => f.existsSync(), orElse: () => File('/nonexistent'));
    if (!file.existsSync()) {
      // ignore: avoid_print
      print(
        'No ${entry.key} found; the render will have boxes. Tried:\n'
        '${paths.join('\n')}',
      );
      continue;
    }
    final loader = FontLoader(entry.key)
      ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
  }
}

void main() {
  // The Sonim XP5s: 320x432 at 213dpi, which is 240x324 logical pixels and a
  // device pixel ratio of 1.33. The logical size is what layout uses; the ratio
  // is what makes the PNG the same number of pixels as the glass.
  const sonimDpr = 213 / 160;
  const sonim = Size(240 * sonimDpr, 324 * sonimDpr);

  const shootKey = ValueKey('shoot');

  /// The app, with the debug banner off — see [localizedApp].
  Widget appOf(Widget home) => localizedApp(home: home, showBanner: false);

  /// One plan, asking something every day, so a month cell has an amount in it.
  const plansJson =
      '{"plans":[{"id":"p","name":"Yoma",'
      '"displayCalendar":"gregorian","assignments":[{"id":"a",'
      '"rule":{"type":"daily"},"targetNodeId":"shas.moed.shabbos",'
      '"unitsPerFiring":3,"label":"after Shacharis"}],"overrides":[],'
      '"unitsPerDay":12,"spillover":"ignore","flowsToNextItem":true,'
      '"weekdayAmounts":{"6":0}}]}';

  Future<void> at(
    WidgetTester tester, {
    required Widget home,
    Size size = sonim,
    String? plans = plansJson,
    ProgressRepository? repo,
  }) async {
    tester.view.devicePixelRatio = sonimDpr;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(
            InMemoryPreferences(
              plans == null
                  ? null
                  : {PrefKeys.scoped('default', PrefKeys.plans): plans},
            ),
          ),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(
            repo ?? memoryRepository(),
          ),
          clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
        ],
        // A boundary to capture, because the test binding's root render object is
        // a `_ReusableRenderView` and not a `RenderRepaintBoundary` — so there is
        // nothing to call `toImage` on without putting one here.
        // `debugShowCheckedModeBanner: false` because the debug banner is a red
        // ribbon across the top right corner of *every* render, and it is very
        // easy to read one of these and think the app has a red stripe on it.
        child: RepaintBoundary(key: shootKey, child: appOf(home)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Writes the current frame to `test/features/goldens/<name>.png`.
  ///
  /// Through `matchesGoldenFile`, not `toImage`. Rasterising by hand returns a
  /// future that never completes in a headless test — it wedges rather than
  /// failing, which is the most expensive kind of no — whereas this is the path
  /// Flutter supports, and `--update-goldens` writes the file.
  Future<void> shoot(WidgetTester tester, String name) =>
      expectLater(find.byKey(shootKey), matchesGoldenFile('goldens/$name.png'));

  setUpAll(loadDeviceFonts);

  testWidgets('the calendar, month range', (tester) async {
    final repo = memoryRepository();
    // A second sefer under Moed, so "add a sefer" has a category to offer and
    // the total is a real one.
    await repo.addCustomNode(
      'default',
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
    await at(tester, home: const PlannerCalendarScreen(), repo: repo);
    await shoot(tester, '01-calendar-month-sonim');
  });

  testWidgets('the calendar, week range', (tester) async {
    await at(tester, home: const PlannerCalendarScreen());
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    await shoot(tester, '02-calendar-week-sonim');
  });

  testWidgets('the calendar, day range', (tester) async {
    await at(tester, home: const PlannerCalendarScreen());
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    await shoot(tester, '03-calendar-day-sonim');
  });

  testWidgets('the date entry, with a Hebrew date typed', (tester) async {
    await at(
      tester,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => promptForDate(
                context,
                initial: Day.of(DateTime(2026, 1, 10)),
                reference: Day.of(DateTime(2026, 1, 10)),
                mode: CalendarMode.gregorian,
                title: 'Amount for that date',
                confirmLabel: 'Save',
                cancelLabel: 'Cancel',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '4 Tevet 5786');
    await tester.pumpAndSettle();
    await shoot(tester, '04-date-entry-sonim');
  });

  testWidgets('the plan editor, sequence and overrides', (tester) async {
    await at(
      tester,
      home: const EditPlanAdvancedScreen(planId: 'p'),
      plans:
          '{"plans":[{"id":"p","name":"Yoma","displayCalendar":"gregorian",'
          '"assignments":[{"id":"a","rule":{"type":"daily"}}],"overrides":[],'
          '"unitsPerDay":12,"spillover":"ignore","flowsToNextItem":true,'
          '"items":[{"id":"i0","nodeId":"shas.moed.shabbos"},'
          '{"id":"i1","nodeId":"shas.moed"}],'
          '"weekdayAmounts":{"6":0}}]}',
    );
    await shoot(tester, '05-plan-sequence-sonim');
  });

  testWidgets('the calendar in Hebrew, which no previous render could show', (
    tester,
  ) async {
    await at(
      tester,
      home: const PlannerCalendarScreen(),
      plans:
          '{"plans":[{"id":"p","name":"\u05d9\u05d5\u05de\u05d4",'
          '"displayCalendar":"hebrew","assignments":[{"id":"a",'
          '"rule":{"type":"daily"},"targetNodeId":"shas.moed.shabbos"}],'
          '"overrides":[],"unitsPerDay":12,"spillover":"ignore",'
          '"flowsToNextItem":true}]}',
    );
    // The setting the app stores is the *calendar* to show; a reader also has to
    // have turned it on. This is the view as such a reader sees it.
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    await shoot(tester, '07-calendar-month-hebrew');
  });

  testWidgets('the date field with a Hebrew-script date in it', (tester) async {
    await at(
      tester,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => promptForDate(
                context,
                initial: Day.of(DateTime(2026, 1, 10)),
                reference: Day.of(DateTime(2026, 1, 10)),
                mode: CalendarMode.gregorian,
                title: 'Set the date',
                confirmLabel: 'Save',
                cancelLabel: 'Cancel',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // The form the app's own formatter emits, typed back into the field that
    // parses it: the round trip, in Hebrew script, on a 240dp screen.
    await tester.enterText(find.byType(TextField).last, 'ג׳ תשרי תשפ״ז');
    await tester.pumpAndSettle();
    await shoot(tester, '08-date-entry-hebrew');
  });

  testWidgets('the calendar on an ordinary phone, for comparison', (
    tester,
  ) async {
    await at(
      tester,
      home: const PlannerCalendarScreen(),
      size: const Size(400 * 2, 900 * 2),
    );
    await shoot(tester, '06-calendar-month-phone');
  });
}
