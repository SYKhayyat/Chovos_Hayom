import 'dart:ui' as ui;

import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/features/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/in_memory_progress_repository.dart';
import '../support/localized_app.dart';

/// Layout that has to mirror, and did not.
///
/// Translating the strings was only half of right-to-left. The tree indents each
/// generation with a physical `EdgeInsets.only(left:)`, so under a Hebrew layout
/// a child was pushed *away* from the edge its text begins on — it appeared
/// outdented from its parent, which reads as the opposite of what nesting means.
/// Found by looking at the running app; invisible to every test in the suite,
/// because a string comparison cannot see which side of the screen a thing is on.
///
/// These measure geometry instead, in both directions, so the fix is pinned from
/// both sides.
void main() {
  Widget dashboard(Locale locale) => ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider
              .overrideWithValue(InMemoryProgressRepository()),
          appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
          clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
        ],
        child: localizedApp(home: const DashboardScreen(), locale: locale),
      );

  /// Opens root → Shas so there are three generations on screen at once. The
  /// root opens itself on arrival, so only Shas is left to press.
  /// The fake catalog carries no Hebrew names, so the titles stay findable by
  /// their English text in either locale — which is what lets one helper serve
  /// both tests.
  Future<void> expandTwoLevels(WidgetTester tester) async {
    await tester.tap(find.text('Shas'));
    await tester.pumpAndSettle();
  }

  testWidgets('a Hebrew layout indents the tree from the right', (tester) async {
    await tester.pumpWidget(dashboard(const Locale('he')));
    await tester.pumpAndSettle();
    await expandTwoLevels(tester);

    expect(Directionality.of(tester.element(find.text('Shas'))),
        TextDirection.rtl);

    // Right-to-left: text begins at the right edge, so each deeper generation
    // starts *further from* it. A child's right edge must be left of its
    // parent's.
    final root = tester.getTopRight(find.text('Kol HaTorah Kula')).dx;
    final shas = tester.getTopRight(find.text('Shas')).dx;
    final moed = tester.getTopRight(find.text('Moed')).dx;

    expect(shas, lessThan(root), reason: 'Shas must indent from its parent');
    expect(moed, lessThan(shas), reason: 'Moed must indent from Shas');
    // The step is the same 16px per level the LTR tree uses.
    expect(root - shas, closeTo(16, 0.5));
    expect(shas - moed, closeTo(16, 0.5));
  });

  testWidgets('an English layout still indents from the left', (tester) async {
    await tester.pumpWidget(dashboard(const Locale('en')));
    await tester.pumpAndSettle();
    await expandTwoLevels(tester);

    final root = tester.getTopLeft(find.text('Kol HaTorah Kula')).dx;
    final shas = tester.getTopLeft(find.text('Shas')).dx;
    final moed = tester.getTopLeft(find.text('Moed')).dx;

    expect(shas, greaterThan(root));
    expect(moed, greaterThan(shas));
    expect(shas - root, closeTo(16, 0.5));
    expect(moed - shas, closeTo(16, 0.5));
  });

  testWidgets('the progress line reads left to right inside the Hebrew tree',
      (tester) async {
    // End to end, on the widget the user reads: `bidi_numerals_test.dart` pins
    // the *string*, and this pins the call site, because a template that is safe
    // and a widget that forgot to isolate it look identical from the string's
    // side. Painted, this row said "929 / 0" for "0 learned of 929".
    await tester.pumpWidget(dashboard(const Locale('he')));
    await tester.pumpAndSettle();

    final line = find.textContaining('0 / 156');
    expect(line, findsWidgets, reason: 'the tree shows learned / total');

    final painted = tester.widget<Text>(line.first).data!;
    final painter = TextPainter(
      text: TextSpan(text: painted),
      textDirection: TextDirection.rtl,
    )..layout();
    ui.Rect boxOf(int index) => painter
        .getBoxesForSelection(
            TextSelection(baseOffset: index, extentOffset: index + 1))
        .first
        .toRect();

    final firstDigit = painted.indexOf(RegExp(r'\d'));
    final lastDigit = painted.lastIndexOf(RegExp(r'\d'));
    expect(boxOf(lastDigit).left, greaterThan(boxOf(firstDigit).left),
        reason: 'the numerator is painted left of the total, so "0 / 156" is '
            'not read as "156 / 0"');
  });

  testWidgets('the drill-in chevron points the way the text runs',
      (tester) async {
    // A chevron that always points right is telling a right-to-left reader to
    // go back.
    await tester.pumpWidget(dashboard(const Locale('he')));
    await tester.pumpAndSettle();
    await expandTwoLevels(tester);
    await tester.tap(find.text('Moed'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsWidgets);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('...and points right under English', (tester) async {
    await tester.pumpWidget(dashboard(const Locale('en')));
    await tester.pumpAndSettle();
    await expandTwoLevels(tester);
    await tester.tap(find.text('Moed'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_right), findsWidgets);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });
}
