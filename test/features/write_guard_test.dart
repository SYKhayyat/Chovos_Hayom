import 'dart:convert';

import 'package:chovos_hayom/app/routes.dart';
import 'package:chovos_hayom/application/cycles.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/daf_yomi.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/domain/usecases/learning_cycle.dart';
import 'package:chovos_hayom/features/common/guarded.dart';
import 'package:chovos_hayom/features/cycles/cycles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/failing_progress_repository.dart';
import '../support/in_memory_progress_repository.dart';
import '../support/localized_app.dart';
import '../support/recording_crash_log.dart';

/// A button that runs one guarded write — the smallest thing that exercises the
/// policy without a whole screen around it.
class _GuardedButton extends ConsumerWidget {
  const _GuardedButton({required this.write, this.undo});

  final Future<void> Function() write;

  /// The optional Undo the success message carries — which is what decides
  /// whether that message can ever go away on its own.
  final SnackBarAction? undo;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => guarded(context, ref, write,
                what: 'Marking this daf learned', success: 'Marked', undo: undo),
            child: const Text('go'),
          ),
        ),
      );
}

void main() {
  late RecordingCrashLog crashLog;

  setUp(() => crashLog = RecordingCrashLog());

  // Riverpod does not export the `Override` type, so the knobs are named rather
  // than passed as a list.
  Widget wrap(
    Widget child, {
    ProgressRepository? repo,
    AppPreferences? prefs,
    DateTime Function()? clock,
  }) =>
      ProviderScope(
        overrides: [
          crashLogProvider.overrideWithValue(crashLog),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          if (repo != null) progressRepositoryProvider.overrideWithValue(repo),
          if (prefs != null) appPreferencesProvider.overrideWithValue(prefs),
          if (clock != null) clockProvider.overrideWithValue(clock),
        ],
        // The router is wired because the guard's *Details* action pushes a
        // named route — the app always has it, so a harness without it would be
        // testing something the app never does. Likewise the localizations: the
        // guard now resolves its failure sentence and its *Details* label from
        // them, so a harness without them tests a guard the app never builds.
        child: localizedApp(
          home: child,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onUnknownRoute: AppRouter.onUnknownRoute,
        ),
      );

  group('WriteGuard', () {
    testWidgets('reports success only after the write actually succeeded',
        (tester) async {
      var wrote = false;
      await tester.pumpWidget(
          wrap(_GuardedButton(write: () async => wrote = true)));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(wrote, isTrue);
      expect(find.text('Marked'), findsOneWidget);
      expect(crashLog.entries, isEmpty);
    });

    testWidgets('a failed write says so, and never claims success',
        (tester) async {
      await tester.pumpWidget(wrap(
          _GuardedButton(write: () async => throw StateError('no disk'))));
      await tester.tap(find.text('go'));
      await tester.pump();

      expect(find.text('Marking this daf learned failed.'), findsOneWidget);
      expect(find.text('Marked'), findsNothing);
    });

    testWidgets('a failed write lands in the crash log, named by what it was',
        (tester) async {
      await tester.pumpWidget(wrap(
          _GuardedButton(write: () async => throw StateError('no disk'))));
      await tester.tap(find.text('go'));
      await tester.pump();

      expect(crashLog.entries, hasLength(1));
      expect(crashLog.entries.single, contains('Marking this daf learned'));
      expect(crashLog.entries.single, contains('no disk'));
    });

    testWidgets('the failure offers the crash log, and gets there',
        (tester) async {
      await tester.pumpWidget(wrap(
          _GuardedButton(write: () async => throw StateError('no disk'))));
      await tester.tap(find.text('go'));
      // Long enough for the snackbar to finish sliding in, short enough that it
      // has not yet timed out — the action is only tappable in between.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text('Crash log'), findsOneWidget);
      expect(find.textContaining('no disk'), findsOneWidget);
    });

    /// Every message this app shows goes out through the guard, so this is the
    /// one place the rule can be stated.
    ///
    /// Flutter defaults `SnackBar.persist` to `action != null`: a bar carrying
    /// an Undo or a Details button stays up until *something* takes it away, and
    /// on a touchscreen that something is a swipe. A keypad phone has no swipe.
    /// Measured on the Sonim, dismissing the backup banner replaced it with
    /// "Backup reminder off — turn it back on in Settings → Backup" across the
    /// bottom third of the screen, and it was still there a minute later with no
    /// key on the device that would remove it. The user's report — that the
    /// warning could not be dismissed — was exactly right: dismissing it
    /// produced something permanent.
    testWidgets('a message carrying an action still goes away by itself',
        (tester) async {
      await tester.pumpWidget(wrap(_GuardedButton(
        write: () async {},
        undo: SnackBarAction(label: 'Undo', onPressed: () {}),
      )));
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('Marked'), findsOneWidget);

      // Long enough to walk a D-pad over to Undo...
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Marked'), findsOneWidget,
          reason: 'an Undo nobody can reach in time is not an Undo');

      // ...and then it leaves on its own, which on that phone is the only way
      // it can leave at all.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Marked'), findsNothing);
    });
  });

  group('Learning cycles · log today', () {
    // One cycle over the fake catalog's only leaf, starting today, so "today's
    // unit" is its first daf and the Log button is on screen.
    final today = DateTime(2026, 3, 15, 9);
    final cycle = SequentialCycle(
      id: 'c1',
      name: 'My seder',
      startDate: today,
      segments: const [
        CycleSegment(nodeId: 'shas.moed.shabbos', unitCount: 156, unitOffset: 2),
      ],
    );
    final prefs = <String, String>{
      PrefKeys.scoped('default', PrefKeys.cycles): jsonEncode(CyclesConfig(
        hiddenBuiltIns: const {
          CalendarCycle.bavliId,
          CalendarCycle.yerushalmiId,
        },
        custom: [cycle],
      ).toJson()),
    };

    Widget cyclesScreen(InMemoryProgressRepository repo) => wrap(
          const CyclesScreen(),
          repo: repo,
          prefs: InMemoryPreferences(prefs),
          clock: () => today,
        );

    testWidgets('a write that fails is not reported as "Logged"',
        (tester) async {
      await tester.pumpWidget(cyclesScreen(FailingProgressRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log daf 2'));
      await tester.pump();

      // The bug this replaces: fire-and-forget, then "Logged ✓" regardless.
      expect(find.textContaining('Logged'), findsNothing);
      expect(find.textContaining('failed.'), findsOneWidget);
      expect(crashLog.entries.single,
          contains(FailingProgressRepository.message));
    });

    testWidgets('a write that succeeds says so, once it has', (tester) async {
      await tester.pumpWidget(
          cyclesScreen(FailingProgressRepository(failWrites: false)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log daf 2'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Logged'), findsOneWidget);
      expect(crashLog.entries, isEmpty);
      // …and the row now reads back from the log rather than from the tap.
      expect(find.textContaining('Learned'), findsOneWidget);
    });
  });
}
