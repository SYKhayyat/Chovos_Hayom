import 'dart:async';

import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/settings.dart';
import 'package:chovos_hayom/core/calendar.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/features/history/bulk_history_screen.dart';
import 'package:chovos_hayom/features/journal/notes_journal_screen.dart';
import 'package:chovos_hayom/features/unit_grid/unit_details_sheet.dart';
import 'package:chovos_hayom/features/unit_grid/unit_grid_screen.dart';
import 'package:chovos_hayom/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/counting_log.dart';
import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// **How many times a mark walks the log, counted with the real screens up.**
///
/// `log_pass_count_test.dart` counts the same thing in a bare container, and
/// says so plainly in its own setUp: two providers are *deliberately not
/// subscribed*, so its numbers stay about the day-indexed answers it is named
/// for. That is the right call for that file and it leaves the question this one
/// answers open, because a user does not choose the subscription set — the
/// screen they happen to be on does.
///
/// The report's open note reads: *"`backupStatusProvider` still walks the log,
/// on a third axis neither index carries. Same for the journal, the details
/// sheet and the bulk-undo list."* All four are true, and the numbers below are
/// what they actually cost. Measured on this machine over a 3,000-event log —
/// seven years of daf yomi — the mandatory pair is ~660µs for `FoldLog.fold`
/// and ~690µs for `LogActivity.of`; against that, the backup axis is **28µs**,
/// the batch grouping 25µs, one unit's history 27µs and the journal's
/// filter-and-sort 36µs. The third axis costs two percent of the two indexes it
/// rides along with. It is not the thing to fix; the two indexes are, if
/// anything ever is.
///
/// So what is worth pinning is not the microseconds — they belong to whatever
/// machine ran them — but the *shape*: three passes per mark and no more,
/// wherever the mark is made, and nothing at all for a screen that is not on
/// screen. A fourth pass appearing here is a new axis someone added without
/// noticing, which is exactly how the nine-passes-per-mark this whole line of
/// work started with grew.
void main() {
  LearningEvent done(int i) => LearningEvent(
        id: 'e$i',
        profileId: 'default',
        nodeId: 'shas.moed.shabbos',
        unitIndex: 2 + (i % 150),
        action: EventAction.done,
        occurredAt: DateTime(2025, 1, 1).add(Duration(hours: i * 6)),
        loggedAt: DateTime(2025, 1, 1).add(Duration(hours: i * 6)),
        // Every eleventh event carries a haara, so the journal has rows to build
        // rather than a filter that falls out on the first field.
        note: i % 11 == 0 ? 'haara' : null,
      );

  CountingLog logOf(int count) =>
      CountingLog([for (var i = 0; i < count; i++) done(i)]);

  /// Pump without settling.
  ///
  /// `pumpAndSettle` cannot be used here: until the log's first emission the
  /// dashboard shows a `CircularProgressIndicator`, which never settles by
  /// design, and the whole point of this file is to control when that emission
  /// happens.
  Future<void> pump(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  late StreamController<List<LearningEvent>> events;

  setUp(() {
    events = StreamController<List<LearningEvent>>.broadcast();
    addTearDown(events.close);
  });

  /// The log is injected rather than written through a repository — the same
  /// reasoning as `log_pass_count_test.dart`, and the only way to hand the graph
  /// a list that counts its own reads.
  Widget scoped(Widget child) => ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(memoryRepository()),
          appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
          eventsProvider.overrideWith((ref) => events.stream),
        ],
        child: child,
      );

  group('the real app', () {
    testWidgets('a mark costs three passes with the dashboard up',
        (tester) async {
      await tester.pumpWidget(scoped(const ChovosHayomApp()));
      await pump(tester);
      events.add(logOf(300));
      await pump(tester);

      final fresh = logOf(301);
      events.add(fresh);
      await pump(tester);

      expect(fresh.passes, 3,
          reason: 'the fold, the day index, and the backup axis — one each. The '
              'third is the one the report leaves open: distinct units recorded '
              'since an instant, keyed on loggedAt, which neither index can '
              'answer. A fourth here is a walk nobody accounted for');
    });

    testWidgets('and three from the grid, where marks are actually made',
        (tester) async {
      await tester.pumpWidget(scoped(const ChovosHayomApp()));
      await pump(tester);
      events.add(logOf(300));
      await pump(tester);

      for (final row in ['Shas', 'Moed', 'Shabbos']) {
        await tester.tap(find.text(row));
        await pump(tester);
      }

      final fresh = logOf(301);
      events.add(fresh);
      await pump(tester);

      expect(fresh.passes, 3,
          reason: 'the grid asks one question — membership — and on its own it '
              'costs one pass. The other two are the dashboard underneath: a '
              'pushed route does not stop the screen it covered from '
              're-deriving, and should not, because the alternative is arriving '
              'back at a stale tree or flushing a derived ancestor mid-build. '
              'So three is the number for the hot path, not two');
    });
  });

  /// One screen at a time, so the three passes above can be attributed rather
  /// than guessed at. Two of these ask the log something no index carries —
  /// *group by batch id* for the durable undo list, *every event with a haara*
  /// for the journal — and the third is the grid, which wants membership and is
  /// the reason the fold exists.
  ///
  /// Each is one pass per change while it is up, which is the price of its axis.
  /// The half worth pinning is the other one: none of these providers is
  /// `autoDispose`, so each outlives the screen that created it — and with
  /// nothing listening it is marked dirty and left alone rather than recomputed.
  group('one screen at a time', () {
    for (final screen in <({String name, Widget widget, String axis})>[
      (
        name: 'the Notes Journal',
        widget: const NotesJournalScreen(),
        axis: 'every event carrying a haara, newest first',
      ),
      (
        name: 'the bulk-undo list',
        widget: const BulkHistoryScreen(),
        axis: 'the log grouped by batch id',
      ),
      (
        name: 'a unit grid',
        widget: const UnitGridScreen(nodeId: 'shas.moed.shabbos'),
        axis: 'membership per unit, and nothing else',
      ),
    ]) {
      testWidgets('${screen.name} costs one pass up, none away',
          (tester) async {
        var open = true;
        late StateSetter setOpen;

        await tester.pumpWidget(scoped(
          localizedApp(
            home: StatefulBuilder(builder: (context, setState) {
              setOpen = setState;
              return open ? screen.widget : const SizedBox.shrink();
            }),
          ),
        ));
        await pump(tester);
        events.add(logOf(200));
        await pump(tester);

        final whileUp = logOf(201);
        events.add(whileUp);
        await pump(tester);
        expect(whileUp.passes, 1,
            reason: '${screen.axis} — one walk per change, which is the price '
                'of the axis and is paid while it is being looked at');

        setOpen(() => open = false);
        await pump(tester);

        final whileAway = logOf(202);
        events.add(whileAway);
        await pump(tester);
        expect(whileAway.passes, 0,
            reason: 'the provider outlives the screen — it is not autoDispose — '
                'but with nothing listening it is marked dirty and left alone. '
                'If this ever reads 1, every mark made anywhere in the app is '
                'paying for a screen the user closed');
      });
    }
  });

  /// The unit details sheet is the weakest of the four and is kept as it is.
  ///
  /// It filters the whole log per *build* rather than per change, so a rebuild
  /// that has nothing to do with the log — a rotation, the soft keyboard
  /// opening under a nested sheet, a calendar-mode change — walks it again. That
  /// is pinned here rather than argued away, because the reason it is tolerable
  /// is a measurement (27µs against a 3,000-event log, two percent of the mark
  /// that opened it) and not the "it only sees its own writes" the report
  /// originally claimed, which the second expectation below is a direct
  /// counter-example to.
  ///
  /// The fix would be a memo keyed on log identity, as `BackupStatusNotifier`
  /// holds one — *not* a derived provider, which is the shape that throws
  /// `setState() during build` when a sheet pops. See `derived_flush_test.dart`.
  group('the unit details sheet', () {
    /// Pump a host screen, hand it a log, and open the sheet over it — the
    /// counter is reset on the way out, so each test below measures only what
    /// it does next.
    ///
    /// The host holds `eventsProvider` open the way the unit grid does in the
    /// app: a broadcast stream drops what it emits when nothing is subscribed,
    /// which would leave the sheet reading an empty log and every count zero.
    Future<({WidgetRef ref, CountingLog log})> openSheet(
        WidgetTester tester) async {
      late WidgetRef hostRef;
      await tester.pumpWidget(scoped(
        localizedApp(
          home: Consumer(builder: (context, ref, _) {
            hostRef = ref;
            ref.watch(eventsProvider);
            return Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showUnitDetailsSheet(context, ref,
                      node: fakeCatalog().byId('shas.moed.shabbos')!, unit: 2),
                  child: const Text('open'),
                ),
              ),
            );
          }),
        ),
      ));
      await pump(tester);
      final log = logOf(200);
      events.add(log);
      await pump(tester);

      log.reset();
      await tester.tap(find.text('open'));
      await pump(tester);
      expect(log.passes, 1,
          reason: "one unit's own events, in order — the axis the sheet exists "
              'for, and the one time it is unavoidable');
      log.reset();
      return (ref: hostRef, log: log);
    }

    testWidgets('walks it again for a rebuild that is not a log change',
        (tester) async {
      final open = await openSheet(tester);

      // A metrics change: a rotation, or the keyboard that a nested log or
      // chazara sheet brings up on top of this one.
      tester.view.physicalSize = const Size(400, 700);
      addTearDown(tester.view.resetPhysicalSize);
      await pump(tester);

      expect(open.log.passes, 1,
          reason: 'nothing about the log changed and it was filtered again. '
              'Accepted at this size — see the group doc — but it is a '
              'per-build walk and not a per-change one, and that is the honest '
              'name for it');
    });

    testWidgets('and not at all for a settings field it does not read',
        (tester) async {
      final open = await openSheet(tester);

      await open.ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
      await pump(tester);
      expect(open.log.passes, 0,
          reason: 'it takes one field out of the settings through a `.select`, '
              'so a theme write does not rebuild it. Without that select a '
              'per-build walk would make every settings write a log walk — '
              'which is the exact shape backupStatusProvider was fixed for');

      // The one field it does read, for contrast: this is a real rebuild.
      await open.ref.read(settingsProvider.notifier).setCalendar(CalendarMode.hebrew);
      await pump(tester);
      expect(open.log.passes, 1,
          reason: 'the sheet renders dates, so a calendar change genuinely '
              'rebuilds it — and a per-build walk turns that into a log walk');
    });
  });
}
