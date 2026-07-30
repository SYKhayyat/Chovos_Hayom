import 'package:chovos_hayom/application/backup_status.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/features/dashboard/dashboard_screen.dart';
import 'package:chovos_hayom/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/failing_progress_repository.dart';
import '../support/in_memory_progress_repository.dart';
import '../support/localized_app.dart';
import '../support/recording_crash_log.dart';

/// The stamp that says "this profile is safe" must only ever be written when it
/// is true.
///
/// The whole feature is one warning; a false "last exported: today" doesn't just
/// fail to help, it actively silences the warning that would have. So the
/// timestamp is written after the export returns, and never on a failure or a
/// cancel.
void main() {
  final now = DateTime(2026, 3, 1, 10);

  LearningEvent done(int unit, DateTime at) => LearningEvent(
        id: 'e$unit',
        profileId: 'default',
        nodeId: 'shas.moed.shabbos',
        unitIndex: unit,
        action: EventAction.done,
        occurredAt: at,
        loggedAt: at,
      );

  void mockClipboard(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
  }

  late RecordingCrashLog crashLog;
  setUp(() => crashLog = RecordingCrashLog());

  ProviderScope settings(InMemoryProgressRepository repo, AppPreferences prefs) =>
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
          appPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(() => now),
          // The write guard awaits the crash log before it reports a failure,
          // and the real one writes a file through a platform channel — which a
          // widget test's fake-async zone never completes, so the failure path
          // would deadlock before it said anything.
          crashLogProvider.overrideWithValue(crashLog),
        ],
        child: localizedApp(home: const SettingsScreen()),
      );

  testWidgets('a successful export stamps the profile as backed up',
      (tester) async {
    final repo = InMemoryProgressRepository();
    await repo.addEvent(done(2, DateTime(2026, 2, 1)));
    final prefs = InMemoryPreferences();
    mockClipboard(tester);

    await tester.pumpWidget(settings(repo, prefs));
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    expect(container.read(backupStatusProvider).neverBackedUp, isTrue);
    expect(container.read(backupStatusProvider).unsavedUnits, 1);

    await tester.scrollUntilVisible(find.text('Export to clipboard'), 200);
    // scrollUntilVisible stops the moment the target is attached, which can
    // leave it flush against the viewport edge where a tap misses it.
    await tester.ensureVisible(find.text('Export to clipboard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export to clipboard'));
    await tester.pumpAndSettle();

    final status = container.read(backupStatusProvider);
    expect(status.neverBackedUp, isFalse);
    expect(status.lastBackupAt, now);
    expect(status.unsavedUnits, 0, reason: 'the export now contains it all');
    expect(status.due, isFalse);
    // Persisted, not just held in memory — a reminder that resets on every
    // launch is no reminder.
    expect(prefs.getString(PrefKeys.scoped('default', PrefKeys.lastBackupAt)),
        now.toIso8601String());
  });

  testWidgets('a failed export does NOT stamp the profile as backed up',
      (tester) async {
    // The failure mode the whole feature exists to prevent: telling someone
    // their learning is saved when the export never happened. Building a backup
    // starts by reading every event, so a log that refuses to be read is how an
    // export realistically dies.
    final repo = FailingProgressRepository(failEventReads: true);
    final prefs = InMemoryPreferences();
    mockClipboard(tester);

    await tester.pumpWidget(settings(repo, prefs));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Export to clipboard'), 200);
    // scrollUntilVisible stops the moment the target is attached, which can
    // leave it flush against the viewport edge where a tap misses it.
    await tester.ensureVisible(find.text('Export to clipboard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export to clipboard'));
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    expect(container.read(backupStatusProvider).neverBackedUp, isTrue);
    expect(prefs.getString(PrefKeys.scoped('default', PrefKeys.lastBackupAt)),
        isNull);
    // And it said so, through the same guard as every other write — and the
    // failure is in the crash log rather than only on a snackbar that goes away.
    expect(find.textContaining('failed'), findsOneWidget);
    expect(find.text('Exported to clipboard'), findsNothing);
    expect(crashLog.entries.single,
        contains(FailingProgressRepository.message));
  });

  /// All four corners of the standing tile.
  ///
  /// Its title read off `neverBackedUp` and its icon and subtitle read off
  /// `unsavedUnits == 0`, with nothing reconciling them — so a brand-new profile
  /// (both true) got "Never exported" under a green tick reading "Everything you
  /// have learned is in that backup", about a backup that did not exist. Three of
  /// these four states were always right, which is why a test for one state would
  /// not have found it: the defect is in the *combination*, so the table is the
  /// test.
  group('the backup standing tile', () {
    const stamp = 'lastBackupAt';

    Future<Finder> pumpTile(
      WidgetTester tester, {
      required bool exported,
      required int learned,
    }) async {
      final repo = InMemoryProgressRepository();
      for (var i = 0; i < learned; i++) {
        await repo.addEvent(done(2 + i, DateTime(2026, 2, 20)));
      }
      final prefs = InMemoryPreferences({
        if (exported)
          PrefKeys.scoped('default', stamp): DateTime(2026, 2, 10)
              .toIso8601String(),
      });

      await tester.pumpWidget(settings(repo, prefs));
      await tester.pumpAndSettle();
      final title = find.textContaining('exported');
      await tester.scrollUntilVisible(title, 200);
      await tester.pumpAndSettle();
      return title;
    }

    testWidgets('a new profile is neither reassured nor alarmed',
        (tester) async {
      final title = await pumpTile(tester, exported: false, learned: 0);

      expect(tester.widget<Text>(title).data, 'Never exported');
      expect(find.text('Nothing to back up yet — export as soon as you have '
          'learned something'), findsOneWidget);
      expect(find.text('Everything you have learned is in that backup'),
          findsNothing,
          reason: 'there is no "that backup" for the learning to be in');
      expect(find.byIcon(Icons.verified_outlined), findsNothing,
          reason: 'a green tick here is the same all-clear a covered profile '
              'gets');
    });

    testWidgets('learning with no export at all is named as at risk',
        (tester) async {
      final title = await pumpTile(tester, exported: false, learned: 1);

      expect(tester.widget<Text>(title).data, 'Never exported');
      expect(
          find.text(
              '1 unit learned since — it exists only on this device'),
          findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('a fully-exported profile is the one that gets the tick',
        (tester) async {
      // Exported after the learning: nothing outstanding.
      final repo = InMemoryProgressRepository();
      await repo.addEvent(done(2, DateTime(2026, 2, 1)));
      final prefs = InMemoryPreferences({
        PrefKeys.scoped('default', stamp):
            DateTime(2026, 2, 20).toIso8601String(),
      });
      await tester.pumpWidget(settings(repo, prefs));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.textContaining('exported'), 200);
      await tester.pumpAndSettle();

      expect(find.textContaining('Last exported'), findsOneWidget);
      expect(find.text('Everything you have learned is in that backup'),
          findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    });

    testWidgets('learning since the last export is counted', (tester) async {
      final title = await pumpTile(tester, exported: true, learned: 2);

      expect(tester.widget<Text>(title).data, startsWith('Last exported'));
      expect(
          find.text(
              '2 units learned since — they exist only on this device'),
          findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsNothing);
    });
  });

  testWidgets('the dashboard warns when learning has never been backed up',
      (tester) async {
    final repo = InMemoryProgressRepository();
    await repo.addEvent(done(2, DateTime(2026, 2, 1)));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(repo),
        appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
        clockProvider.overrideWithValue(() => now),
      ],
      child: localizedApp(home: const DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('never been backed up'), findsOneWidget);
    expect(find.text('Back up'), findsOneWidget);
  });

  testWidgets('an empty profile is not warned at', (tester) async {
    // A fresh install must not open on a warning about data that doesn't exist.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider
            .overrideWithValue(InMemoryProgressRepository()),
        appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
        clockProvider.overrideWithValue(() => now),
      ],
      child: localizedApp(home: const DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Back up'), findsNothing);
  });

  testWidgets('the banner can be switched off from the banner itself',
      (tester) async {
    // The switch has always existed in Settings, but a warning you can only
    // silence by hunting through a screen — possibly in a language you don't
    // read — is a warning that just becomes noise.
    final repo = InMemoryProgressRepository();
    await repo.addEvent(done(2, DateTime(2026, 2, 1)));
    final prefs = InMemoryPreferences();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(repo),
        appPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => now),
        crashLogProvider.overrideWithValue(crashLog),
      ],
      child: localizedApp(home: const DashboardScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Back up'), findsOneWidget);

    await tester.tap(find.byTooltip('Turn off this reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Back up'), findsNothing);
    // It says where to turn it back on rather than just vanishing...
    expect(find.textContaining('Settings'), findsOneWidget);
    // ...and the choice is persisted, not just this session's.
    expect(
        prefs.getString(
            PrefKeys.scoped('default', PrefKeys.backupReminderEnabled)),
        'false');
  });

  testWidgets('dismissing the banner is undoable', (tester) async {
    // Turning off a safety warning by mis-tap must cost nothing.
    final repo = InMemoryProgressRepository();
    await repo.addEvent(done(2, DateTime(2026, 2, 1)));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(repo),
        appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
        clockProvider.overrideWithValue(() => now),
        crashLogProvider.overrideWithValue(crashLog),
      ],
      child: localizedApp(home: const DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Turn off this reminder'));
    await tester.pumpAndSettle();
    expect(find.text('Back up'), findsNothing);

    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Back up'), findsOneWidget);
  });

  testWidgets('turning the reminder off removes the banner', (tester) async {
    final repo = InMemoryProgressRepository();
    await repo.addEvent(done(2, DateTime(2026, 2, 1)));
    final prefs = InMemoryPreferences({
      PrefKeys.scoped('default', PrefKeys.backupReminderEnabled): 'false',
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(repo),
        appPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => now),
      ],
      child: localizedApp(home: const DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Back up'), findsNothing);
  });
}
