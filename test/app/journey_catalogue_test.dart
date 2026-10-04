import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/harness/action.dart';
import '../../integration_test/harness/coverage.dart';
import '../../integration_test/harness/device_profile.dart';
import '../../integration_test/harness/journey.dart';
import '../support/fake_catalog.dart';
import '../support/memory_database.dart';

/// **The device journeys, run without a device.**
///
/// The harness is written against `WidgetTester` and nothing else — the only
/// genuinely device-bound piece is `HarnessContext.screenshot()`, which is
/// already inert unless `HARNESS_SHOTS` is set. So the catalogue can be run
/// here, at a chosen phone's size, in about fifteen seconds.
///
/// That is worth having for one reason above all: **it produces the failure text**.
/// #49's whole method is "run it, read the step and what *was* on screen", and
/// that was a device-day per attempt. Here it is a `grep`:
///
/// ```
/// FAIL  learning/mark-a-daf
///   at: 5/8 — tap any of 1, 2, 3 — the first daf in the grid
///   Bad state: none of 1, 2, 3 is on screen.
///   On screen: Kol HaTorah Kula | 0 / 156 (0.0%) | … | Learning tree | Plans
/// ```
///
/// **What it is not.** This is a pre-flight, not a verdict, and it is easy to
/// over-read:
///
/// - It uses `FakeCatalogRepository` and an in-memory log, so a journey that
///   needs real catalogue depth or a populated planner will fail here for a
///   reason that says nothing about the device.
/// - Hebrew renders as notdef boxes, so any journey asserting on Hebrew text
///   measures the font, not the app.
/// - `HarnessInput.keys` is meaningless here — there is no D-pad. The Sonim's
///   only input path cannot be exercised off-device at all.
///
/// So a failure here means *"look at this step"*, and a pass means *"nothing
/// obviously wrong, on a fake, in one input mode"*. Neither is a green light for
/// closing a device issue.
///
/// ## Running it
///
/// Off by default, because a catalogue with known failures must not sit in CI
/// failing on every push while the real fixes are still open (#51 blocks #49):
///
/// ```
/// flutter test --dart-define=JOURNEY_PROBE=true test/app/journey_catalogue_test.dart
/// flutter test --dart-define=JOURNEY_PROBE=true --dart-define=JOURNEY_PROBE_SIZE=phone \
///   test/app/journey_catalogue_test.dart
/// ```
const bool _probe = bool.fromEnvironment('JOURNEY_PROBE');
const String _size = String.fromEnvironment(
  'JOURNEY_PROBE_SIZE',
  defaultValue: 'sonim',
);

void main() {
  testWidgets('the device journeys, off-device', (tester) async {
    if (!_probe) {
      // Not a skip marker in the report: a skipped test is a question nobody
      // asked. One line saying how to run it is more use.
      say(
        'journey catalogue: off. Run it with --dart-define=JOURNEY_PROBE=true '
        '(and JOURNEY_PROBE_SIZE=phone for 411x891).',
      );
      return;
    }

    const sonim = _size != 'phone';
    const dp = sonim ? kSonimDp : kPhoneDp;
    const dpr = sonim ? kSonimDpr : 2.625;

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view
      ..physicalSize = dp * dpr
      ..devicePixelRatio = dpr;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(memoryRepository()),
        ],
        child: const ChovosHayomApp(),
      ),
    );
    await tester.pumpAndSettle();

    const device = DeviceProfile(
      size: dp,
      devicePixelRatio: dpr,
      platform: 'android',
      textScale: 1,
    );
    say('=== journey catalogue (off-device) ===');
    say('  ${device.describe}');

    final results = <JourneyResult>[];
    await HarnessRunner(
      results,
    ).run(tester, device, HarnessInput.pointer, journeys: allJourneys());

    say(
      '\n=== ${HarnessRunner(results).passed} passed, ${results.length - HarnessRunner(results).passed} failed ===',
    );
    for (final r in results) {
      say(r.line);
    }
  });
}
