import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/session_timer.dart';
import 'package:chovos_hayom/application/settings.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/calendar.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/features/dashboard/session_banner.dart';
import 'package:chovos_hayom/features/journal/notes_journal_screen.dart';
import 'package:chovos_hayom/features/reports/overview_section.dart';
import 'package:chovos_hayom/features/reports/siyumim_section.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/memory_database.dart';
import '../support/localized_app.dart';

/// **Rebuilds, counted on the real screens.**
///
/// `provider_notify_test.dart` counts what the provider graph says; this counts
/// what the widget tree does about it. The two are different questions, and the
/// gap between them is where the report's claim lived: the providers were doing
/// the right derivation and then thirteen screens watched the *whole*
/// `SettingsState` object to read one enum out of it, so changing the backup
/// interval rebuilt the calculator, cycles, goals, the journal, siyumim, stats
/// and the unit grid.
///
/// Counting is via [debugOnRebuildDirtyWidget], the framework's own hook — the
/// same one the "Track widget rebuilds" toggle in DevTools uses. It fires for
/// every element that actually rebuilds, which is exactly the quantity being
/// argued about.
void main() {
  /// Rebuild tallies by widget runtime type, from the moment [reset] is called.
  late Map<String, int> rebuilds;

  setUp(() {
    rebuilds = <String, int>{};
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      final name = element.widget.runtimeType.toString();
      rebuilds[name] = (rebuilds[name] ?? 0) + 1;
    };
  });

  tearDown(() => debugOnRebuildDirtyWidget = null);

  LearningEvent done(int unit) => LearningEvent(
        id: 'e$unit',
        profileId: 'default',
        nodeId: 'shas.moed.shabbos',
        unitIndex: unit,
        action: EventAction.done,
        occurredAt: DateTime(2026, 1, 9),
        loggedAt: DateTime(2026, 1, 9),
      );

  Widget scoped(Widget home, ProgressRepository repo) => ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
          appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
          clockProvider.overrideWithValue(() => DateTime(2026, 1, 10, 12)),
        ],
        child: localizedApp(home: home),
      );

  group('a settings write nobody on screen reads', () {
    /// The three screens whose only interest in Settings is the calendar mode,
    /// which the backup interval does not touch. Before the `.select`s they
    /// watched the whole object and rebuilt on any settings write at all.
    for (final screen in <({String name, Widget widget})>[
      (name: 'OverviewSection', widget: reportSection(const OverviewSection())),
      (name: 'SiyumimSection', widget: reportSection(const SiyumimSection())),
      (name: 'NotesJournalScreen', widget: const NotesJournalScreen()),
    ]) {
      testWidgets('does not rebuild ${screen.name}', (tester) async {
        final repo = memoryRepository();
        await repo.addEvent(done(2));
        await tester.pumpWidget(scoped(screen.widget, repo));
        await tester.pumpAndSettle();

        final ref = ProviderScope.containerOf(
            tester.element(find.byType(MaterialApp)),
            listen: false);

        rebuilds.clear();
        await ref.read(settingsProvider.notifier).setBackupIntervalDays(21);
        await tester.pumpAndSettle();

        expect(rebuilds[screen.name] ?? 0, 0,
            reason: '${screen.name} reads s.calendar and nothing else. '
                'A number in the backup section of Settings is not its '
                'business.');
      });
    }

    testWidgets('but a change it *does* read still rebuilds it', (tester) async {
      // The control. A `.select` that never fires is indistinguishable from a
      // missing subscription, and the difference only shows up as a screen that
      // has quietly stopped updating.
      final repo = memoryRepository();
      await repo.addEvent(done(2));
      await tester.pumpWidget(scoped(reportSection(const OverviewSection()), repo));
      await tester.pumpAndSettle();

      final ref = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
          listen: false);

      rebuilds.clear();
      await ref.read(settingsProvider.notifier).setCalendar(CalendarMode.hebrew);
      await tester.pumpAndSettle();

      expect(rebuilds['OverviewSection'] ?? 0, greaterThan(0));
    });
  });

  group('the session banner\'s one-second ticker', () {
    testWidgets('does not run when there is no session', (tester) async {
      final repo = memoryRepository();
      await tester.pumpWidget(scoped(const SessionBanner(), repo));
      await tester.pumpAndSettle();

      rebuilds.clear();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(rebuilds['SessionBanner'] ?? 0, 0,
          reason: 'this widget renders SizedBox.shrink() with no session, and '
              'it used to wake up once a second for the life of the process to '
              'redraw it — on a battery-powered keypad phone');
    });

    testWidgets('does not run while a session is merely paused', (tester) async {
      final repo = memoryRepository();
      await tester.pumpWidget(scoped(const SessionBanner(), repo));
      await tester.pumpAndSettle();

      final ref = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
          listen: false);
      final timer = ref.read(sessionTimerProvider.notifier);
      await timer.start(now: DateTime(2026, 1, 10, 12));
      await timer.pause(DateTime(2026, 1, 10, 12, 5));
      await tester.pumpAndSettle();

      rebuilds.clear();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(rebuilds['SessionBanner'] ?? 0, 0,
          reason: 'a paused session\'s elapsed time is the banked total, which '
              'does not move until it is resumed');
    });

    testWidgets('does run while a session is running', (tester) async {
      // The control that stops the two above from being satisfied by simply
      // deleting the ticker.
      final repo = memoryRepository();
      await tester.pumpWidget(scoped(const SessionBanner(), repo));
      await tester.pumpAndSettle();

      final ref = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
          listen: false);
      await ref
          .read(sessionTimerProvider.notifier)
          .start(now: DateTime(2026, 1, 10, 12));
      await tester.pumpAndSettle();

      rebuilds.clear();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(rebuilds['SessionBanner'] ?? 0, 3,
          reason: 'the readout counts up once a second while it is running');

      // Leave nothing pending: the binding asserts on a live timer at teardown.
      await ref.read(sessionTimerProvider.notifier).reset();
      await tester.pumpAndSettle();
    });
  });
}
