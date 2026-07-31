import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/keypad.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/features/dashboard/dashboard_screen.dart';
import 'package:chovos_hayom/features/stats/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/in_memory_progress_repository.dart';
import '../support/localized_app.dart';

/// The app has to work on a phone with no touchscreen.
///
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
          progressRepositoryProvider
              .overrideWithValue(InMemoryProgressRepository()),
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
          progressRepositoryProvider
              .overrideWithValue(InMemoryProgressRepository()),
          appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
          clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
        ],
        child: localizedApp(home: const StatsScreen()),
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

    testWidgets('and loses none of them — each is in the menu, with a name',
        (tester) async {
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

    testWidgets('while a normal phone keeps the three buttons it always had',
        (tester) async {
      sized(tester, kPhone);
      await tester.pumpWidget(dashboard());
      await tester.pumpAndSettle();

      expect(find.byTooltip('Collapse all'), findsOneWidget);
      expect(find.byTooltip('Sort'), findsOneWidget);
      expect(find.byTooltip('Search'), findsOneWidget);
      expect(find.byTooltip('More actions'), findsNothing);
    });
  });

  group('the statistics screen', () {
    testWidgets('lays out on a 240dp screen without overflowing',
        (tester) async {
      sized(tester, kSonim);
      await tester.pumpWidget(stats());
      await tester.pumpAndSettle();

      // The screen was `GridView.count(crossAxisCount: 2, childAspectRatio:
      // 2.4)`, which pins each tile's height to a fraction of its width: a
      // 100x41 box holding a label and a bold number that need about 55. Every
      // value spilled over the card below it. An overflow raises here.
      expect(tester.takeException(), isNull);
      expect(find.byType(StatsScreen), findsOneWidget);
    });

    testWidgets('and scrolls on a D-pad, having nothing focusable in it',
        (tester) async {
      sized(tester, kSonim);
      await tester.pumpWidget(stats());
      await tester.pumpAndSettle();

      final list = find.byType(Scrollable).first;
      final before = tester.widget<Scrollable>(list).controller!.offset;

      // Directional focus moves between focusable widgets and scrolls only to
      // reveal one. A screen of plain figures has none, so on the device four
      // presses of "down" moved nothing at all and the chart below the fold
      // could not be reached by any sequence of keys.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(tester.widget<Scrollable>(list).controller!.offset,
          greaterThan(before));
    });
  });

  group('the focus ring', () {
    /// A button that can be focused on demand, wrapped the way
    /// `MaterialApp.builder` wraps every route in the real app.
    Future<FocusNode> pumpRinged(WidgetTester tester, Size size) async {
      sized(tester, size);
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(MaterialApp(
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
      ));
      await tester.pumpAndSettle();
      return node;
    }

    testWidgets('is drawn on a keypad screen, where focus is otherwise unseen',
        (tester) async {
      final node = await pumpRinged(tester, kSonim);
      expect(find.byKey(focusRingKey), findsNothing,
          reason: 'nothing has focus yet');

      node.requestFocus();
      await tester.pumpAndSettle();

      expect(find.byKey(focusRingKey), findsOneWidget);
    });

    testWidgets('stays away on a touchscreen phone that has seen no key',
        (tester) async {
      final node = await pumpRinged(tester, kPhone);
      node.requestFocus();
      await tester.pumpAndSettle();

      // The whole point of the gate: a phone this app already ran on well must
      // look exactly as it did. Focus alone is not enough there — rings are for
      // people navigating by key, and touching a control is not that.
      expect(find.byKey(focusRingKey), findsNothing);
    });

    testWidgets('but appears on that phone once a key is used, for keyboards',
        (tester) async {
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
      final repo = InMemoryProgressRepository();
      await repo.addEvent(LearningEvent(
        id: 'e1',
        profileId: 'default',
        nodeId: 'shas.moed.shabbos',
        unitIndex: 2,
        action: EventAction.done,
        occurredAt: DateTime(2026, 1, 10),
        loggedAt: DateTime(2026, 1, 10),
      ));

      await tester.pumpWidget(ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
          appPreferencesProvider.overrideWithValue(InMemoryPreferences({})),
          clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
        ],
        child: localizedApp(home: const DashboardScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('gets a readable width for its prose on a 240dp screen',
        (tester) async {
      await pumpBanner(tester, kSonim);

      final headline =
          find.text('1 unit of your learning has never been backed up.');
      expect(headline, findsOneWidget);

      // A shield, this prose, a "Back up" button and a close button want about
      // 202dp of the 184 the card leaves at this width, so the `Expanded` around
      // the prose got what was left — nothing — and wrapped it to ONE CHARACTER
      // PER LINE. A column of single red letters, on the banner whose entire job
      // is to be read. Stacking the parts is what gives it its width back.
      final paragraph = tester.renderObject<RenderBox>(headline);
      expect(paragraph.size.width, greaterThan(120),
          reason: 'the banner text collapsed to a narrow column again');
    });

    testWidgets('names its dismiss control instead of hiding it in an icon',
        (tester) async {
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

    testWidgets('and keeps the close icon on a screen that can hover it',
        (tester) async {
      await pumpBanner(tester, kPhone);

      expect(find.byTooltip('Turn off this reminder'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('drops its second paragraph where there is no room for it',
        (tester) async {
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
      expect(find.textContaining('It lives only on this device'),
          findsOneWidget);
    });
  });

  group('isCompact', () {
    testWidgets('is true at the Sonim size and false on an ordinary phone',
        (tester) async {
      late bool sonim;
      late bool phone;

      sized(tester, kSonim);
      await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) {
        sonim = isCompact(context);
        return const SizedBox();
      })));
      tester.view.physicalSize = kPhone;
      await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) {
        phone = isCompact(context);
        return const SizedBox();
      })));

      expect(sonim, isTrue);
      // 320dp is the narrowest phone anyone ships, so the threshold cannot fire
      // on a real touchscreen.
      expect(phone, isFalse);
    });
  });
}
