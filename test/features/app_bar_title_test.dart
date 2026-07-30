import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/features/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/in_memory_progress_repository.dart';
import '../support/localized_app.dart';

/// The app bar has to fit the app's own name.
///
/// On a 1220x2712 phone the English bar read "Chovos …", and "Chovo…" at 1.6x
/// font scale: five actions plus the drawer button left the title nothing. Hebrew
/// ("חובות היום") fits, so it was invisible to anyone testing in the locale the
/// app is really for — and it is the first thing every English user sees.
void main() {
  Widget dashboard({double textScale = 1.0}) => ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider
              .overrideWithValue(InMemoryProgressRepository()),
          appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
          clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
        ],
        child: localizedApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: const DashboardScreen(),
          ),
        ),
      );

  /// Pumps a phone-width dashboard and returns the title's paragraph.
  Future<RenderParagraph> title(WidgetTester tester,
      {double textScale = 1.0}) async {
    // 407 logical pixels: the 1220px/450dpi phone this was measured on.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(407, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(dashboard(textScale: textScale));
    await tester.pumpAndSettle();
    return tester.renderObject<RenderParagraph>(find.text('Chovos Hayom'));
  }

  testWidgets('the whole name is painted at the default font size',
      (tester) async {
    expect((await title(tester)).didExceedMaxLines, isFalse,
        reason: 'the app bar truncated the app name to "Chovos …"');
  });

  testWidgets('and at 1.6x font scale, where it truncated to "Chovo…"',
      (tester) async {
    expect((await title(tester, textScale: 1.6)).didExceedMaxLines, isFalse,
        reason: 'a large-font user reads even less of it');
  });

  testWidgets('the bar keeps only what acts on the tree in front of you',
      (tester) async {
    await title(tester);

    // Expand, sort, search: three things that do something to *this* tree.
    expect(find.byTooltip('Expand all'), findsOneWidget);
    expect(find.byTooltip('Sort'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    // The two that were navigation wearing an action's clothes.
    expect(find.byTooltip('Statistics'), findsNothing);
    expect(find.byTooltip('Siyum calculator'), findsNothing);
  });

  testWidgets('and the two that moved are named rows in the drawer',
      (tester) async {
    await title(tester);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    // Not merely present — reachable, since an icon that vanished from the bar
    // and reappeared nowhere is a feature removed rather than moved.
    expect(find.widgetWithText(ListTile, 'Statistics'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Siyum calculator'), findsOneWidget);
  });
}
