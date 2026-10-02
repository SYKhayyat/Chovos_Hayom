import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/breakpoints.dart';
import 'package:chovos_hayom/core/focus.dart';
import 'package:chovos_hayom/core/planner_dates.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/features/dashboard/dashboard_screen.dart';
import 'package:chovos_hayom/features/planner/calendar_screen.dart';
import 'package:chovos_hayom/features/reports/overview_section.dart';
import 'package:chovos_hayom/features/reports/report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/memory_database.dart';
import '../support/localized_app.dart';

/// The app has to work on a phone with no touchscreen.
///
/// **These tests measure the device in the device's own type — which is not
/// possible here, and the reason is worth stating rather than working around.**
/// The binding's default font is Ahem, which draws every glyph as the same wide
/// box. That is ideal for a layout question and wrong for this file, whose whole
/// job is to model one specific device: a 240dp screen carrying 232dp of
/// segmented-button chrome is a question where Ahem's metrics and Roboto's give
/// different answers, and they did. The `Month` label wraps under Ahem and does
/// not wrap in Roboto; a `Cancel`/`Save` row overflows by 13 pixels under Ahem
/// and fits on the device.
///
/// Loading Roboto was tried, and it is worse than the disease: the engine's copy
/// of it lives at `<flutter>/engine/src/flutter/…`, which a **release** SDK does
/// not ship, so the font silently failed to load on CI and two tests went red
/// there within one push — a suite that is green on one machine and red on
/// another, for a reason that has nothing to do with the app.
///
/// So the suite stays font-agnostic, which is the property every other test in
/// this repository has, and the font question moves somewhere it belongs:
/// `screens.golden.dart` renders these screens in Roboto for a human to look at,
/// and the two layout facts that depend on type are asserted here as the *change*
/// that was made rather than as a measurement. What is left unasserted — whether
/// a 9sp amount is legible on real glass at 213dpi — is not assertable at all
/// and needs the device in a hand.

/// Measured on a Sonim XP5s — Android 7.1.2, a 320x432 screen at 213dpi, which
/// is 240 x 324 logical pixels, a D-pad and a numeric keypad. Everything here
/// is a defect that device showed and a guarantee that the fix for it does not
/// reach the phones that were already fine.

/// The Sonim's logical size, which is what every "compact" test below runs at.
const Size kSonim = Size(240, 324);

/// A comfortable phone, for the "nothing changed here" half of each pair.
const Size kPhone = Size(407, 900);

void main() {
  Widget dashboard({bool ring = false}) => ProviderScope(
    overrides: [
      catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
      progressRepositoryProvider.overrideWithValue(memoryRepository()),
      appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
      clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
    ],
    child: localizedApp(
      home: ring
          ? const FocusRingOverlay(child: DashboardScreen())
          : const DashboardScreen(),
    ),
  );

  Widget stats() => ProviderScope(
    overrides: [
      catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
      progressRepositoryProvider.overrideWithValue(memoryRepository()),
      appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
      clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
    ],
    child: localizedApp(home: const ReportScreen()),
  );

  /// Renders at [size] logical pixels, the way the device reports itself.
  void sized(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  group('the app bar on a 240dp screen', () {
    testWidgets('folds its actions away so the title has room', (tester) async {
      sized(tester, kSonim);
      await tester.pumpWidget(dashboard());
      await tester.pumpAndSettle();

      // The bar's own name, which a FittedBox had been scaling down to an
      // illegible dash to make room for three icons.
      expect(find.text('Chovos Hayom'), findsOneWidget);
      expect(find.byTooltip('More actions'), findsOneWidget);
      expect(find.byTooltip('Expand all'), findsNothing);
    });

    testWidgets('and loses none of them — each is in the menu, with a name', (
      tester,
    ) async {
      sized(tester, kSonim);
      await tester.pumpWidget(dashboard());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      // Folding an action away must not be the same as deleting it. On this
      // screen they gained labels they never had as bare icons. ("Collapse all"
      // rather than "Expand all" because the dashboard now opens with its top
      // level already open — see dashboard_lazy_test.)
      expect(find.text('Collapse all'), findsOneWidget);
      expect(find.text('Sort'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
    });

    testWidgets('while a normal phone keeps the three buttons it always had', (
      tester,
    ) async {
      sized(tester, kPhone);
      await tester.pumpWidget(dashboard());
      await tester.pumpAndSettle();

      expect(find.byTooltip('Collapse all'), findsOneWidget);
      expect(find.byTooltip('Sort'), findsOneWidget);
      expect(find.byTooltip('Search'), findsOneWidget);
      expect(find.byTooltip('More actions'), findsNothing);
    });
  });

  group('the report screen', () {
    testWidgets('lays out on a 240dp screen without overflowing', (
      tester,
    ) async {
      sized(tester, kSonim);
      await tester.pumpWidget(stats());
      await tester.pumpAndSettle();

      // The screen was `GridView.count(crossAxisCount: 2, childAspectRatio:
      // 2.4)`, which pins each tile's height to a fraction of its width: a
      // 100x41 box holding a label and a bold number that need about 55. Every
      // value spilled over the card below it. An overflow raises here.
      expect(tester.takeException(), isNull);
      expect(find.byType(OverviewSection), findsOneWidget);
    });

    testWidgets('and so does every one of its tabs', (tester) async {
      // Five labels across 240dp is what the scrolling tab bar is for, and the
      // section under it is a different layout each time. Checking only the
      // one the report opens on would leave four untested layouts behind two
      // key presses.
      sized(tester, kSonim);
      await tester.pumpWidget(stats());
      await tester.pumpAndSettle();

      for (final tab in ['Calculator', 'Goals', 'Siyumim', 'Mefarshim']) {
        await tester.scrollUntilVisible(
          find.widgetWithText(Tab, tab),
          60,
          scrollable: find
              .descendant(
                of: find.byType(TabBar),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.widgetWithText(Tab, tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });

    testWidgets('and scrolls on a D-pad, having nothing focusable in it', (
      tester,
    ) async {
      sized(tester, kSonim);
      await tester.pumpWidget(stats());
      await tester.pumpAndSettle();

      // The section's own list, named rather than taken as "the first
      // Scrollable": at 240dp the report's tab bar is itself scrollable and
      // sits above this, and so does the TabBarView's pager.
      final list = find
          .descendant(
            of: find.byType(OverviewSection),
            matching: find.byType(Scrollable),
          )
          .first;
      final before = tester.widget<Scrollable>(list).controller!.offset;

      // Directional focus moves between focusable widgets and scrolls only to
      // reveal one. A screen of plain figures has none, so on the device four
      // presses of "down" moved nothing at all and the chart below the fold
      // could not be reached by any sequence of keys.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Scrollable>(list).controller!.offset,
        greaterThan(before),
      );
    });

    testWidgets('and the tab bar above it can be reached, and left again', (
      tester,
    ) async {
      // The one interaction the merge introduced. Five report routes became
      // five tabs, and a tab bar is a second axis of navigation on a device
      // that has one comfortable one — so the round trip has to work by key or
      // four fifths of the report is unreachable on this phone.
      //
      // It nearly did not. `DpadScroll` claims focus on arrival and holds it,
      // turning up and down into scrolling; at either end it deliberately does
      // *not* claim the key, so focus can leave. Getting back in is the half
      // that needed the work: the wrapper was `skipTraversal: true`, which
      // makes it invisible to directional focus, and its autofocus only fires
      // when nothing in the scope holds focus — which after a tab switch is
      // false, because the tab does. Reachable one way and not the other.
      sized(tester, kSonim);
      await tester.pumpWidget(stats());
      await tester.pumpAndSettle();

      bool inTabBar() => find
          .ancestor(
            of: find.byWidget(
              FocusManager.instance.primaryFocus!.context!.widget,
            ),
            matching: find.byType(TabBar),
          )
          .evaluate()
          .isNotEmpty;

      expect(inTabBar(), isFalse, reason: 'the section starts focused');

      // Up, at the top of a list that is already at the top: unclaimed, so
      // traversal takes it.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(inTabBar(), isTrue, reason: 'up from the top leaves the section');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(inTabBar(), isFalse, reason: 'and down comes back into it');
    });
  });

  group('the focus ring', () {
    /// A button that can be focused on demand, wrapped the way
    /// `MaterialApp.builder` wraps every route in the real app.
    Future<FocusNode> pumpRinged(WidgetTester tester, Size size) async {
      sized(tester, size);
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: FocusRingOverlay(
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 120,
                  height: 40,
                  child: TextButton(
                    focusNode: node,
                    onPressed: () {},
                    child: const Text('x'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return node;
    }

    testWidgets(
      'is drawn on a keypad screen, where focus is otherwise unseen',
      (tester) async {
        final node = await pumpRinged(tester, kSonim);
        expect(
          find.byKey(focusRingKey),
          findsNothing,
          reason: 'nothing has focus yet',
        );

        node.requestFocus();
        await tester.pumpAndSettle();

        expect(find.byKey(focusRingKey), findsOneWidget);
      },
    );

    testWidgets('stays away on a touchscreen phone that has seen no key', (
      tester,
    ) async {
      final node = await pumpRinged(tester, kPhone);
      node.requestFocus();
      await tester.pumpAndSettle();

      // The whole point of the gate: a phone this app already ran on well must
      // look exactly as it did. Focus alone is not enough there — rings are for
      // people navigating by key, and touching a control is not that.
      expect(find.byKey(focusRingKey), findsNothing);
    });

    testWidgets('but appears on that phone once a key is used, for keyboards', (
      tester,
    ) async {
      final node = await pumpRinged(tester, kPhone);
      node.requestFocus();
      await tester.pumpAndSettle();
      // A key that moves nothing. Tab would traverse focus off the button and
      // leave nothing to ring, which says less about the rule being tested.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();

      // Which is the app's existing "everything works with a keyboard" rule
      // getting a clearer indicator than Material's default wash, rather than
      // anything new.
      expect(find.byKey(focusRingKey), findsOneWidget);
    });
  });

  group('the backup banner', () {
    /// The dashboard at [size] with one unit learned and no export — so the
    /// banner is genuinely due rather than merely rendered.
    Future<void> pumpBanner(WidgetTester tester, Size size) async {
      sized(tester, size);
      final repo = memoryRepository();
      await repo.addEvent(
        LearningEvent(
          id: 'e1',
          profileId: 'default',
          nodeId: 'shas.moed.shabbos',
          unitIndex: 2,
          action: EventAction.done,
          occurredAt: DateTime(2026, 1, 10),
          loggedAt: DateTime(2026, 1, 10),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              FakeCatalogRepository(),
            ),
            progressRepositoryProvider.overrideWithValue(repo),
            appPreferencesProvider.overrideWithValue(InMemoryPreferences({})),
            clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
          ],
          child: localizedApp(home: const DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('gets a readable width for its prose on a 240dp screen', (
      tester,
    ) async {
      await pumpBanner(tester, kSonim);

      final headline = find.text(
        '1 unit of your learning has never been backed up.',
      );
      expect(headline, findsOneWidget);

      // A shield, this prose, a "Back up" button and a close button want about
      // 202dp of the 184 the card leaves at this width, so the `Expanded` around
      // the prose got what was left — nothing — and wrapped it to ONE CHARACTER
      // PER LINE. A column of single red letters, on the banner whose entire job
      // is to be read. Stacking the parts is what gives it its width back.
      final paragraph = tester.renderObject<RenderBox>(headline);
      expect(
        paragraph.size.width,
        greaterThan(120),
        reason: 'the banner text collapsed to a narrow column again',
      );
    });

    testWidgets('names its dismiss control instead of hiding it in an icon', (
      tester,
    ) async {
      await pumpBanner(tester, kSonim);

      // On the device the ✕ was reachable only by pressing *right* from "Back
      // up" — plain down skipped it for the tree — and what it did was written
      // in a tooltip, which needs a pointer this phone does not have. The one
      // control that silences the warning was both unlabelled and off the path.
      expect(find.text('Turn off this reminder'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.tap(find.text('Turn off this reminder'));
      await tester.pumpAndSettle();
      expect(find.text('Back up'), findsNothing);
    });

    testWidgets('and keeps the close icon on a screen that can hover it', (
      tester,
    ) async {
      await pumpBanner(tester, kPhone);

      expect(find.byTooltip('Turn off this reminder'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('drops its second paragraph where there is no room for it', (
      tester,
    ) async {
      await pumpBanner(tester, kSonim);

      // Headline, reasoning and two buttons come to more than the 244dp the
      // dashboard has under its app bar, so the app opened on a card that filled
      // the screen with the tree entirely below the fold — and nothing to say
      // there was anything under it. What goes is the explanatory sentence; it
      // is still on the Settings screen this banner's own button leads to, under
      // the switch that controls the reminder.
      //
      // Asserted as a rule rather than as a height: widget tests draw in a font
      // whose every glyph is a square em, so a measurement here says more about
      // the test font than about the phone. The height itself was checked on the
      // device.
      expect(find.textContaining('It lives only on this device'), findsNothing);
      expect(find.textContaining('never been backed up'), findsOneWidget);
    });

    testWidgets('and keeps it on a screen with the room', (tester) async {
      await pumpBanner(tester, kPhone);
      expect(
        find.textContaining('It lives only on this device'),
        findsOneWidget,
      );
    });
  });

  // #31: the planner calendar was the one screen in the app that had never been
  // on this list, and it is the screen a D-pad user browses most — a calendar
  // you can only reach by tapping a chevron is a calendar you cannot reach at
  // all on this phone.
  group('the planner calendar', () {
    Widget calendar() => ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(memoryRepository()),
        appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
        clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
      ],
      child: localizedApp(home: const PlannerCalendarScreen()),
    );

    /// What the calendar is showing, as the heading states it.
    ///
    /// The heading is the screen's answer to "which range, and when", so it is
    /// what a key press on this device has to be able to change — found by its
    /// key, because a bare `Text` is not a thing a finder can point at.
    String heading(WidgetTester tester) => (tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('calendar-heading')),
        matching: find.byType(Text),
      ),
    )).data!;

    testWidgets('lays out in all three ranges without overflowing', (
      tester,
    ) async {
      sized(tester, kSonim);
      await tester.pumpWidget(calendar());
      await tester.pumpAndSettle();

      // A month cell is a seventh of 240dp — 28 logical pixels — and the day
      // number over the amount is about 31 of them. Every cell with something
      // due on it overflowed by a few pixels and drew a yellow stripe across the
      // month, which is this screen on this device being unusable rather than
      // merely untidy.
      for (final range in ['Month', 'Week', 'Day']) {
        await tester.tap(find.text(range));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: range);
      }
    });

    testWidgets('the arrows are reachable by key and press with the centre key', (
      tester,
    ) async {
      sized(tester, kSonim);
      await tester.pumpWidget(calendar());
      await tester.pumpAndSettle();
      expect(heading(tester), '2026-01-01');

      /// Which app-bar arrow is focused, read as an *ancestor* of the focused
      /// node — what holds focus inside a Material button is its own `Focus`,
      /// not the `IconButton`, so asking whether the focused widget *is* the
      /// button answers no on a screen where focus works perfectly well.
      String? focusedArrow() {
        final focus = FocusManager.instance.primaryFocus;
        if (focus?.context == null) return null;
        for (final tip in ['Next month', 'Previous month']) {
          if (find
              .ancestor(
                of: find.byWidget(focus!.context!.widget),
                matching: find.byTooltip(tip),
              )
              .evaluate()
              .isNotEmpty) {
            return tip;
          }
        }
        return null;
      }

      // Down reaches the first arrow, and *left/right* moves between the two —
      // which is the axis a D-pad actually has, and the reason the two chevrons
      // are one focus stop apart rather than two. Down alone would skip the
      // second and drop into the grid.
      //
      // The arrows are the only way between periods, and the calendar was not
      // in this suite at all before, so nothing had ever claimed a D-pad user
      // could reach them.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(focusedArrow(), 'Previous month', reason: 'the first stop');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(focusedArrow(), 'Next month', reason: 'and across to the other');

      // The centre key presses it: a control this phone can focus but not
      // activate is the same as an invisible one.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(heading(tester), '2026-02-01');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(focusedArrow(), 'Previous month');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        heading(tester),
        '2026-01-01',
        reason: 'and back, so the arrows are not a one-way ratchet',
      );
    });

    testWidgets('the range selector is given less room, on purpose', (
      tester,
    ) async {
      // Three segments with three labels, each padded 12dp either side, is
      // 232dp of chrome on a screen 208dp wide, so the longest label wrapped
      // mid-word and the control read "Mo / nth" — in *month* range only,
      // because the selected segment also carries a checkmark and Month is the
      // longest of the three words. So the default view of the default screen
      // had a clipped label on this device.
      //
      // Asserted as the two things that were changed rather than as the label's
      // rendered height, because **a height is a statement about a font**: under
      // the test font this same control wraps and reads as broken while fitting
      // perfectly in the device's own type. A test that reported the font as a
      // defect of the product was worse than no test, and it was red in CI
      // within one push. The visual check is `screens.golden.dart`, rendered in
      // Roboto, and this guards the change that made it pass.
      sized(tester, kSonim);
      await tester.pumpWidget(calendar());
      await tester.pumpAndSettle();

      final button = tester.widget<SegmentedButton<PlannerCalendarRange>>(
        find.byType(SegmentedButton<PlannerCalendarRange>),
      );
      expect(
        button.showSelectedIcon,
        isFalse,
        reason: 'the checkmark is 24dp the longest label does not have',
      );
      // The padding is asserted as *present and compact-only* rather than by
      // reading the number back: `SegmentedButton` merges the style it is given
      // with its own, and resolving the merged padding reports Material's
      // default 12 whatever was passed in. Asserting the value would therefore
      // be asserting the framework, not this screen.
      expect(
        button.style,
        isNotNull,
        reason: 'a compact screen gets its own padding',
      );
      expect(button.style!.padding, isNotNull);
    });

    testWidgets('an ordinary phone keeps its checkmark and its padding', (
      tester,
    ) async {
      // The other half of the pair, and the one a fix for this device is most
      // likely to forget: a change that quietly made every other screen worse
      // would pass the test above.
      sized(tester, kPhone);
      await tester.pumpWidget(calendar());
      await tester.pumpAndSettle();

      final button = tester.widget<SegmentedButton<PlannerCalendarRange>>(
        find.byType(SegmentedButton<PlannerCalendarRange>),
      );
      expect(button.showSelectedIcon, isTrue);
      expect(
        button.style?.padding,
        isNull,
        reason: 'no compact styling off a compact screen',
      );
    });

    testWidgets('a month cell fits this width by using smaller type', (
      tester,
    ) async {
      // The 240dp cell is 28 logical pixels and a day number over an amount
      // needs about 36 of them stacked, so the cell had to give something up.
      // `FittedBox(scaleDown)` fixed the overflow by scaling the *day number*
      // along with the amount, and at 0.78 the number that has to be readable
      // came out near 11sp — a legibility problem traded for a smaller one,
      // which is not a fix.
      //
      // So the type is chosen small enough to fit and the scale is only the
      // backstop. Asserted as a number because "it does not overflow" is the
      // assertion that let the first version through.
      sized(tester, kSonim);
      await tester.pumpWidget(calendar());
      await tester.pumpAndSettle();

      final scales = <double>[];
      for (final found in find.byType(FittedBox).evaluate()) {
        final box = found.widget as FittedBox;
        if (box.fit != BoxFit.scaleDown || box.child == null) continue;
        final outer = tester.renderObject<RenderBox>(find.byWidget(box));
        final inner = tester.renderObject<RenderBox>(find.byWidget(box.child!));
        if (inner.size.width > 0) {
          scales.add(outer.size.width / inner.size.width);
        }
      }
      expect(scales, isNotEmpty, reason: 'the month grid is on screen');
      for (final scale in scales) {
        expect(
          scale,
          greaterThan(0.9),
          reason: 'the type should fit; the scale is a backstop, not the fix',
        );
      }
    });

    testWidgets('and an ordinary phone is not shrunk at all', (tester) async {
      // The other half of the pair: a fix for this device that quietly made
      // every other one worse would pass the test above.
      sized(tester, kPhone);
      await tester.pumpWidget(calendar());
      await tester.pumpAndSettle();

      for (final found in find.byType(FittedBox).evaluate()) {
        final box = found.widget as FittedBox;
        if (box.fit != BoxFit.scaleDown || box.child == null) continue;
        final outer = tester.renderObject<RenderBox>(find.byWidget(box));
        final inner = tester.renderObject<RenderBox>(find.byWidget(box.child!));
        if (inner.size.width == 0) continue;
        expect(outer.size.width / inner.size.width, 1.0);
      }
    });

    testWidgets('and left and right page it, once focus is on the calendar', (
      tester,
    ) async {
      // The half of #31 that a swipe was covering on its own. A `PageView`
      // answers a drag and nothing else, and this device has a D-pad and no
      // touchscreen — so paging was reachable by finger only, and a reader who
      // had focus on the calendar had to go back up to the bar to move at all.
      //
      // Focus is put *in* the page first, because that is the honest shape of it:
      // a D-pad user has pressed "down" to get off the app bar, and from there
      // left and right are the paging gesture.
      sized(tester, kSonim);
      await tester.pumpWidget(calendar());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // the arrows
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // the selector
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // into the page
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(heading(tester), '2026-02-01', reason: 'paged forward a month');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(heading(tester), '2026-01-01', reason: 'and back');
    });

    testWidgets('but the range selector keeps its own left and right', (
      tester,
    ) async {
      // The reason the pager listens *above* its pages and not on them: the
      // SegmentedButton moves between its own segments with left and right, and
      // a page handler that took the key first would make the range unreachable
      // on exactly the device that needs it.
      sized(tester, kSonim);
      await tester.pumpWidget(calendar());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      // The heading still names January: a segment changed, the month did not.
      expect(heading(tester), '2026-01-01');
      expect(find.text('Week'), findsOneWidget);
    });

    testWidgets('the range can be changed by key at this size', (tester) async {
      sized(tester, kSonim);
      await tester.pumpWidget(calendar());
      await tester.pumpAndSettle();

      // Down off the arrows and into the range selector, which is the other
      // thing this screen has to be operable without a finger.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      final focus = FocusManager.instance.primaryFocus!;
      final inSelector = find
          .ancestor(
            of: find.byWidget(focus.context!.widget),
            matching: find.byType(SegmentedButton<PlannerCalendarRange>),
          )
          .evaluate()
          .isNotEmpty;
      expect(
        inSelector,
        isTrue,
        reason: 'the range selector must be reachable on a 240dp screen',
      );
    });

    testWidgets('a day range is a whole day of tapping, not a whole month', (
      tester,
    ) async {
      sized(tester, kSonim);
      await tester.pumpWidget(calendar());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
      expect(heading(tester), '2026-01-10');

      await tester.tap(find.byTooltip('Next day'));
      await tester.pumpAndSettle();
      expect(heading(tester), '2026-01-11');
    });
  });

  group('isCompact', () {
    testWidgets('is true at the Sonim size and false on an ordinary phone', (
      tester,
    ) async {
      late bool sonim;
      late bool phone;

      sized(tester, kSonim);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              sonim = isCompact(context);
              return const SizedBox();
            },
          ),
        ),
      );
      tester.view.physicalSize = kPhone;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              phone = isCompact(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(sonim, isTrue);
      // 320dp is the narrowest phone anyone ships, so the threshold cannot fire
      // on a real touchscreen.
      expect(phone, isFalse);
    });
  });
}
