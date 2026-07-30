import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/features/unit_grid/unit_grid_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/in_memory_progress_repository.dart';
import '../support/localized_app.dart';

/// The grid, driven by a keyboard and nothing else.
///
/// This project's rule is that every action works with a mouse *and* a keyboard,
/// with no touchscreen assumed. Measured on the Windows build, the grid met half
/// of it: Tab reached the cells and Enter marked one — but nothing on screen said
/// which cell was focused (the `InkWell`'s highlight paints behind the filled
/// container), and the cell menu had no keyboard route at all. `lib/` contained
/// no key handling of any kind, so duration, haara, chazara and *View / edit
/// details* were unreachable without a pointing device.
void main() {
  Widget grid() => ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider
              .overrideWithValue(InMemoryProgressRepository()),
          appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
          clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
        ],
        child: localizedApp(
            home: const UnitGridScreen(nodeId: 'shas.moed.shabbos')),
      );

  /// Tabs until a grid cell holds focus, then returns its border.
  Future<BoxBorder?> tabToFirstCell(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final focused = find.descendant(
        of: find.byType(InkWell),
        matching: find.byType(Container),
      );
      for (final element in focused.evaluate()) {
        final container = element.widget as Container;
        final decoration = container.decoration;
        if (decoration is BoxDecoration && decoration.border != null) {
          return decoration.border;
        }
      }
    }
    return null;
  }

  testWidgets('a focused cell is visible, not merely focusable', (tester) async {
    await tester.pumpWidget(grid());
    await tester.pumpAndSettle();

    expect(await tabToFirstCell(tester), isNotNull,
        reason: 'Tab reaches the cells and Enter marks them, so a keyboard user '
            'who cannot see which cell is focused is marking blind');
  });

  testWidgets('the cell menu opens from the keyboard', (tester) async {
    await tester.pumpWidget(grid());
    await tester.pumpAndSettle();
    expect(await tabToFirstCell(tester), isNotNull, reason: 'need a focused cell');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();

    // The whole point: everything the menu carries is what a keyboard could not
    // reach before — logging with a date and a duration, a haara, a chazara.
    expect(find.text('Log with date / duration / note'), findsOneWidget);
    expect(find.text('Mark learned'), findsOneWidget);
  });

  testWidgets('the context-menu key opens it too', (tester) async {
    // Shift+F10 works on every keyboard; the dedicated key exists on most
    // full-size Windows keyboards and no laptop. Both are bound, so both are
    // asserted — a binding nobody tests is a binding that quietly stops working.
    await tester.pumpWidget(grid());
    await tester.pumpAndSettle();
    expect(await tabToFirstCell(tester), isNotNull, reason: 'need a focused cell');

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();

    expect(find.text('Log with date / duration / note'), findsOneWidget);
  });

  testWidgets('Enter still marks the focused cell', (tester) async {
    // The half that already worked, pinned: adding a shortcut layer above the
    // InkWell must not swallow activation.
    await tester.pumpWidget(grid());
    await tester.pumpAndSettle();
    expect(await tabToFirstCell(tester), isNotNull, reason: 'need a focused cell');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
        tester.element(find.byType(UnitGridScreen)));
    final events = await container.read(progressRepositoryProvider)
        .getEvents(container.read(activeProfileProvider));
    expect(events, hasLength(1),
        reason: 'Enter on a focused cell marks it learned');
  });
}
