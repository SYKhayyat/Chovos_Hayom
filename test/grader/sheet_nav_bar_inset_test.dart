import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/features/unit_grid/log_unit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/in_memory_progress_repository.dart';
import '../support/localized_app.dart';

/// GRADER PROBE — the logging sheet's confirm button sits under the system
/// navigation bar.
///
/// Found on hardware (moto g stylus 2025, Android 16, 1220x2712, three-button
/// nav bar 135px tall). Long-press a daf, choose "Log with date / duration /
/// note", and the sheet's "Cancel" / "Mark learned" row is laid out at
/// y=2532..2667 while the nav bar owns y=2577..2712. A tap at y=2640 — inside
/// the button's own bounds — opened `RecentsActivity` instead: the system took
/// it. Two thirds of the primary action's height is dead, and aiming at it
/// throws the user out of the app.
///
/// Mechanism, from the code rather than from the screenshot:
///
///   log_unit_sheet.dart:229   final bottomInset = MediaQuery.of(context).viewInsets.bottom;
///   log_unit_sheet.dart:234   padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
///
/// `viewInsets` is the *keyboard*. The navigation bar is `viewPadding` /
/// `padding`, and nothing here accounts for it — so the sheet is correct while
/// the keyboard is up (verified on the device: the buttons lift to y=1420..1555,
/// clear of everything) and wrong whenever it is down, which is the state the
/// sheet opens in.
///
/// The family, enumerated from every `showModalBottomSheet` call in `lib/`:
/// nine sheets, seven wrap their content in `SafeArea`
/// (`sort_sheet`, `bulk_actions_sheet`, `mefarshim_config_sheet`,
/// `unit_details_sheet`, `unit_layers_sheet`, `cycles_screen`, and the cell menu
/// in `unit_grid_screen`), and the only two that do not — `log_unit_sheet:229`
/// and `add_chazara_sheet:79` — are exactly the two that reach for
/// `viewInsets.bottom` instead. The keyboard inset replaced the nav-bar inset
/// rather than adding to it. Confirmed on the device for both: "Log chazara"
/// lands on the identical y=2532..2667.
///
/// Android 15+ enforces edge-to-edge, so this is not an exotic configuration —
/// it is every current phone.
void main() {
  testWidgets('the log sheet keeps its confirm button clear of the system '
      'navigation bar', (tester) async {
    // A phone-shaped view with a 48-logical-pixel navigation bar and no
    // keyboard: exactly the state the sheet opens in.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    tester.view.padding = const FakeViewPadding(bottom: 48);
    tester.view.viewInsets = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider
            .overrideWithValue(InMemoryProgressRepository()),
        appPreferencesProvider.overrideWithValue(InMemoryPreferences({})),
      ],
      child: localizedApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    showLogUnitSheet(context, title: 'Shabbos (Shas) · daf 5'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Mark learned');
    expect(button, findsOneWidget, reason: 'the sheet should be open');

    final box = tester.getRect(button);
    final navBarTop = tester.view.physicalSize.height /
            tester.view.devicePixelRatio -
        48;

    expect(
      box.bottom,
      lessThanOrEqualTo(navBarTop),
      reason: 'the confirm button extends ${box.bottom - navBarTop} logical '
          'pixels into the system navigation bar, where taps belong to the '
          'system and never reach the app',
    );
  });
}
