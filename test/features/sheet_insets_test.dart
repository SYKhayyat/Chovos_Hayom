import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/features/dashboard/sort_sheet.dart';
import 'package:chovos_hayom/features/unit_grid/add_chazara_sheet.dart';
import 'package:chovos_hayom/features/unit_grid/bulk_actions_sheet.dart';
import 'package:chovos_hayom/features/unit_grid/log_unit_sheet.dart';
import 'package:chovos_hayom/features/unit_grid/mefarshim_config_sheet.dart';
import 'package:chovos_hayom/features/unit_grid/unit_details_sheet.dart';
import 'package:chovos_hayom/features/unit_grid/unit_layers_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/memory_database.dart';
import '../support/localized_app.dart';

/// Every modal sheet, laid out on a phone that has a system navigation bar.
///
/// The suite had no notion of a platform inset, which is how a primary action
/// came to be laid out *underneath* the navigation bar on every current Android
/// phone with 352 tests staying quiet: taps in the bottom two thirds of "Mark
/// learned" went to the system, and aiming at it opened Recents. Nothing here is
/// clever — it is one `viewPadding` and one `expect` — and that is the point.
///
/// Measured on hardware before any of this existed (moto g stylus 2025, Android
/// 16, 1220x2712, three-button bar 135px tall): the log sheet's Cancel / Mark
/// learned row was laid out at y=2532..2667 while the bar owned y=2577..2712,
/// so a tap at y=2640 — inside the button's own bounds — opened `RecentsActivity`
/// instead. That measurement lived in a one-sheet probe of its own, which this
/// file superseded the moment it covered seven; the numbers are kept here
/// because they are the evidence, and the probe is gone.
///
/// The rule: **a sheet may extend under the navigation bar, but nothing you can
/// tap may.** So this looks only at controls that *begin* above the bar's top
/// edge and requires them to end above it too. A control wholly below that line
/// is content scrolled out of view, which is a different (and legitimate) state.
///
/// Seven of the app's nine sheets are here. The two that are not, said plainly
/// rather than left to look like coverage: the grid's **cell menu**
/// (`unit_grid_screen`) and the **cycles** sheet, both of which open from inside a
/// screen rather than from a function a test can call. Both wrap their content in
/// `SafeArea`, and the cell menu was measured correct on the device — its last
/// item ended flush with the bar's top edge. That is evidence, not a test.
void main() {
  /// Logical pixels of navigation bar, matching a real three-button bar.
  const navBar = 48.0;
  const node = CatalogNode(
    id: 'shas.moed.shabbos',
    parentId: 'shas.moed',
    name: 'Shabbos',
    kind: NodeKind.leaf,
    unitLabel: UnitLabel.daf,
    unitCount: 156,
    unitOffset: 2,
  );

  /// Types a finger can land on, plus [Text] — a sheet whose *only* content is
  /// text has nothing to tap, and text sliding under the navigation bar is its
  /// own defect (that is the state "unit details" is in on an unlearned unit).
  /// Deliberately a list of *classes* rather than a list of the widgets each
  /// sheet happens to use, so a sheet that grows a new button is covered without
  /// anyone remembering to add it here.
  const tappable = <Type>[
    Text,
    FilledButton,
    TextButton,
    ElevatedButton,
    OutlinedButton,
    IconButton,
    ListTile,
    SwitchListTile,
    CheckboxListTile,
    RadioListTile<Object?>,
    TextField,
  ];

  /// Pumps an app whose one button opens [open], then returns every tappable
  /// rect inside the sheet.
  Future<List<(String, Rect)>> openAndMeasure(
    WidgetTester tester,
    void Function(BuildContext context, WidgetRef ref) open,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.viewPadding = const FakeViewPadding(bottom: navBar);
    tester.view.padding = const FakeViewPadding(bottom: navBar);
    tester.view.viewInsets = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider
            .overrideWithValue(memoryRepository()),
        appPreferencesProvider.overrideWithValue(InMemoryPreferences({})),
      ],
      child: localizedApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => open(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget, reason: 'the sheet should be open');

    final out = <(String, Rect)>[];
    for (final type in tappable) {
      final finder = find.descendant(
          of: sheet, matching: find.byType(type), skipOffstage: false);
      for (final element in finder.evaluate()) {
        final box = element.renderObject as RenderBox?;
        if (box == null || !box.hasSize) continue;
        out.add((
          '$type "${_labelOf(element)}"',
          box.localToGlobal(Offset.zero) & box.size,
        ));
      }
    }
    // An empty list would make every assertion below pass while measuring
    // nothing — the exact shape of check this whole exercise exists to remove.
    expect(out, isNotEmpty, reason: 'found no controls to measure');
    return out;
  }

  /// The nav bar's top edge in logical pixels, for the view [openAndMeasure] sets.
  double navBarTop(WidgetTester tester) =>
      tester.view.physicalSize.height / tester.view.devicePixelRatio - navBar;

  void expectClearOfNavBar(WidgetTester tester, List<(String, Rect)> rects) {
    final top = navBarTop(tester);
    for (final (label, rect) in rects) {
      if (rect.top >= top) continue; // scrolled out of view, not under the bar
      expect(rect.bottom, lessThanOrEqualTo(top),
          reason: '$label extends ${rect.bottom - top} logical pixels into the '
              'system navigation bar, where taps belong to the system');
    }
  }

  testWidgets('log unit', (tester) async {
    expectClearOfNavBar(
        tester,
        await openAndMeasure(tester,
            (context, ref) => showLogUnitSheet(context, title: 'Shabbos daf 5')));
  });

  testWidgets('add chazara', (tester) async {
    expectClearOfNavBar(
        tester,
        await openAndMeasure(
            tester,
            (context, ref) =>
                showAddChazaraSheet(context, ref, node: node, unit: 5)));
  });

  testWidgets('bulk actions', (tester) async {
    expectClearOfNavBar(
        tester,
        await openAndMeasure(tester,
            (context, ref) => showBulkActionsSheet(context, ref, node: node)));
  });

  testWidgets('mefarshim config', (tester) async {
    expectClearOfNavBar(
        tester,
        await openAndMeasure(
            tester,
            (context, ref) =>
                showMefarshimConfigSheet(context, ref, node: node)));
  });

  testWidgets('unit details', (tester) async {
    expectClearOfNavBar(
        tester,
        await openAndMeasure(
            tester,
            (context, ref) =>
                showUnitDetailsSheet(context, ref, node: node, unit: 5)));
  });

  testWidgets('unit layers', (tester) async {
    expectClearOfNavBar(
        tester,
        await openAndMeasure(
            tester,
            (context, ref) =>
                showUnitLayersSheet(context, ref, node: node, unit: 5)));
  });

  testWidgets('sort', (tester) async {
    expectClearOfNavBar(tester,
        await openAndMeasure(tester, (context, ref) => showSortSheet(context, ref)));
  });

  testWidgets('the check rejects a sheet that ignores the inset', (tester) async {
    // Doctrine: before trusting a check you wrote, feed it something it must
    // reject. This is the shape both real sheets had — bottom padding that knows
    // about the keyboard and nothing about the navigation bar.
    final rects = await openAndMeasure(
      tester,
      (context, ref) => showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(
              bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Mark learned')),
            ],
          ),
        ),
      ),
    );

    expect(() => expectClearOfNavBar(tester, rects), throwsA(isA<TestFailure>()));
  });
}

/// A control's text, for a failure message that names what is unreachable rather
/// than only its type.
String _labelOf(Element element) {
  String? found;
  void visit(Element e) {
    if (found != null) return;
    final widget = e.widget;
    if (widget is Text && widget.data != null) {
      found = widget.data;
      return;
    }
    e.visitChildren(visit);
  }

  visit(element);
  return found ?? '';
}
