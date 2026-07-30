import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/in_memory_progress_repository.dart';
import '../support/localized_app.dart';

/// GRADER PROBE — a profile that has never been backed up is shown a green tick
/// and told its learning is in a backup that does not exist.
///
/// Found on hardware: create a second profile ("Yosef"), open Settings ->
/// Backup, and the tile reads
///
///   [green verified badge]  Never exported
///                           Everything you have learned is in that backup
///
/// "that backup" is deictic to a backup that was never made. The green
/// `Icons.verified_outlined` is the same reassurance shown to a profile that
/// *is* fully exported.
///
/// Mechanism — `settings_screen.dart:687-700`. The two lines key off different
/// facts and are never reconciled:
///
///   final safe = status.unsavedUnits == 0;
///   leading:  safe ? Icons.verified_outlined (green) : Icons.shield_outlined (red)
///   title:    status.neverBackedUp ? backupNeverExported : backupLastExported(...)
///   subtitle: safe ? backupNothingUnsaved : backupUnsavedUnits(n)
///
/// `neverBackedUp` and `unsavedUnits == 0` are independent, and the combination
/// both-true — a profile with nothing learned yet, which is every profile on its
/// first day — produces the reassurance. `BackupReminder.evaluate` is not at
/// fault: with no events, `touched` is empty and `unsavedUnits` is 0, which is
/// true. The tile is what draws the wrong conclusion from it.
///
/// Verified on the device that the *other* states read correctly: with 156 units
/// marked the same tile said "Never exported / 156 units learned since — they
/// exist only on this device" with the red shield, and after an export it said
/// "Last exported 2026-07-30 / Everything you have learned is in that backup".
/// Only the nothing-learned-and-never-exported corner is wrong — which is the
/// state a new user is in.
void main() {
  testWidgets('a never-exported profile is not told its learning is backed up',
      (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A fresh profile: no events, and no lastBackupAt in preferences.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider
            .overrideWithValue(InMemoryProgressRepository()),
        appPreferencesProvider.overrideWithValue(InMemoryPreferences({})),
      ],
      child: localizedApp(home: const SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Never exported'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Never exported'), findsOneWidget,
        reason: 'this probe is about the never-exported state');

    expect(
      find.text('Everything you have learned is in that backup'),
      findsNothing,
      reason: 'nothing has ever been exported, so there is no "that backup" '
          'for the learning to be in',
    );
    expect(
      find.byIcon(Icons.verified_outlined),
      findsNothing,
      reason: 'a green tick on a profile with no backup is the same all-clear '
          'shown to a profile that has one',
    );
  });
}
