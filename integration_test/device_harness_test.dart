import 'package:chovos_hayom/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness/action.dart';
import 'harness/device_profile.dart';
import 'harness/journey.dart';
import 'harness/coverage.dart';

/// The device harness: the app, driven as a person drives it, on real hardware.
///
/// **This is the half of the testing that cannot happen on a host.** Everything
/// in `test/` runs against Ahem — every glyph the same wide box — at whatever
/// size a `TestFlutterView` was told to be. That is the right instrument for
/// logic and the wrong one for layout, and it is blind to four things this
/// harness exists to see:
///
/// - **Real type.** Whether a label fits depends on the font, and the last two
///   defects found in this repository — a segmented control that read "Mo / nth"
///   and a month cell shrunk to 78% — were both invisible to a suite rendering
///   in a font no device has, and both were visible within a second of looking.
/// - **Real size.** Each run sweeps the device's own viewport *and* the other
///   phone's, so a run on the Moto checks the 240dp layout and a run on the
///   Sonim checks the roomy one. One device can stand in for the other.
/// - **Real input.** `--dart-define=HARNESS_INPUT=keys` drives the same
///   journeys through the focus tree and the centre key, which is the only input
///   the Sonim has. A suite that only taps has tested the Moto and skipped the
///   phone the app's compact layout exists for.
/// - **Real wiring.** The real `main()`, the real Drift database, the real
///   312-node catalog with its real Hebrew names — none of which a fake
///   repository stands in for.
///
/// **Expect the first run to fail, and read the failures as harness bugs until
/// they are proved otherwise.** This was written without a device attached, so
/// some of the app's copy is guessed. A guess is wrong costs one edit to a
/// candidate list; a wrong assumption about the app costs a rewrite. Every
/// failure names the step, prints what *was* on screen, and saves a screenshot,
/// so triage is reading rather than archaeology.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // On Android a screenshot comes from the Flutter surface, which has to be
  // converted to an image before it can be read.
  //
  // There is no `revertFlutterImage` in this version of the package — the
  // doc comment on `convertFlutterSurfaceToImage` promises one and the class does
  // not have it — so nothing is converted back. That is only a problem for what
  // comes *after* the harness, which is nothing: the process ends with the run.
  if (HarnessContext.screenshotsWanted) {
    setUpAll(() async {
      try {
        await binding.convertFlutterSurfaceToImage();
      } catch (e) {
        say('  (screenshots unavailable: $e)');
      }
    });
  }

  final results = <JourneyResult>[];

  testWidgets('every journey, on this device', (tester) async {
    // Registered before anything can change it, and inside the test because
    // only here is there a `tester` to put it back through. A device left at
    // 1.3x text for whatever the person opens next would be a side effect of a
    // test run, which is not a thing a test should have.
    addTearDown(() => Viewport.restoreTextScale(tester));

    await app.main();
    await _settle(tester, 'the app starting up');

    final device = DeviceProfile.read(tester);
    say('\n=== Chovos Hayom device harness ===');
    say('  device:  ${device.describe}');
    say('  input:   ${_input().name}');
    say('  shots:   ${HarnessContext.screenshotsWanted}');
    say('  hebrew:  ${hebrewRenders() ? 'renders' : 'DOES NOT RENDER'}');

    final journeys = _journeys();
    const only = String.fromEnvironment('HARNESS_ONLY');
    final selected = only.isEmpty
        ? journeys
        : journeys.where((j) => j.id.contains(only)).toList();
    if (only.isNotEmpty && selected.isEmpty) {
      say('  no journey matches HARNESS_ONLY=$only. Available:');
      for (final journey in journeys) {
        say('    ${journey.id}');
      }
    }
    say('  running ${selected.length} of ${journeys.length} journeys\n');

    final runner = HarnessRunner(results);
    for (final journey in selected) {
      if (journey.byKeysOnly && _input() != HarnessInput.keys) continue;
      await runner.run(tester, device, _input(), journeys: [journey]);
      say(results.last.line);
    }

    say(runner.coverage());
    say(runner.report());
  }, timeout: const Timeout(Duration(minutes: 25)));
}

/// A deadline on every settle, because `pumpAndSettle`'s default is ten minutes
/// and a journey that trips a never-settling animation would otherwise hold the
/// whole run for the length of a coffee.
Future<void> _settle(WidgetTester tester, String why) => tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 8),
    );

HarnessInput _input() =>
    const String.fromEnvironment('HARNESS_INPUT') == 'keys'
        ? HarnessInput.keys
        : HarnessInput.pointer;

/// Every journey, in the order a person would meet them.
///
/// **Learning first, then planning, then the app around them**, because that is
/// the order the app presents and because the later journeys assume the earlier
/// ones left something behind. That is deliberate and it is also a real
/// limitation: a journey that depends on another's data is not independent, and
/// the report says which ones those are by making the failure point at the
/// journey before it.
List<Journey> _journeys() => allJourneys();
