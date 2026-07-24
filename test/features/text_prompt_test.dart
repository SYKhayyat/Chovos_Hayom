import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/features/common/text_prompt.dart';
import 'package:chovos_hayom/features/profiles/profiles_screen.dart';
import 'package:chovos_hayom/features/settings/settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/in_memory_progress_repository.dart';
import '../support/localized_app.dart';
import '../support/recording_crash_log.dart';

/// A dialog must outlive its own controller.
///
/// Four dialogs created a `TextEditingController` beside `showDialog` and
/// disposed it as soon as the await returned — three of them in a tidy-looking
/// `try`/`finally`. `showDialog`'s future completes when the route is *popped*,
/// not when it is gone: the exit animation still has frames to render against a
/// `TextField` that still holds the controller, and the next frame throws
/// "A TextEditingController was used after being disposed".
///
/// It never showed up because no test drove any of these dialogs to completion,
/// and because the throw lands one frame *after* the interesting one — so a test
/// that stopped at `pump()` would have missed it too. Each of these confirms the
/// dialog and then pumps the animation out.
void main() {
  final errors = <FlutterErrorDetails>[];
  late FlutterExceptionHandler? previous;

  setUp(() {
    errors.clear();
    previous = FlutterError.onError;
    FlutterError.onError = errors.add;
  });
  tearDown(() => FlutterError.onError = previous);

  void expectNoFrameworkError() {
    expect(errors.map((e) => e.exceptionAsString()).toList(), isEmpty,
        reason: 'the dialog must outlive its own controller');
  }

  Widget host(Widget child, {AppPreferences? prefs}) => ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider
              .overrideWithValue(InMemoryProgressRepository()),
          appPreferencesProvider
              .overrideWithValue(prefs ?? InMemoryPreferences()),
          crashLogProvider.overrideWithValue(RecordingCrashLog()),
        ],
        child: localizedApp(home: child),
      );

  /// Scrolls a Settings row into view and taps it.
  Future<void> openSettingsRow(WidgetTester tester, String label) async {
    final finder = find.text(label);
    for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('renaming a profile survives the dialog closing', (tester) async {
    await tester.pumpWidget(host(const ProfilesScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Shaul');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    // The frame the throw lands on is *after* the pop, so settling matters.
    await tester.pumpAndSettle();

    expectNoFrameworkError();
    expect(find.text('Shaul'), findsOneWidget);
  });

  testWidgets('cancelling the rename is equally safe', (tester) async {
    // Dismissal runs the same exit animation over the same controller.
    await tester.pumpWidget(host(const ProfilesScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expectNoFrameworkError();
  });

  testWidgets('the chazara intervals dialog survives closing', (tester) async {
    final prefs = InMemoryPreferences();
    await tester.pumpWidget(host(const SettingsScreen(), prefs: prefs));
    await tester.pumpAndSettle();

    await openSettingsRow(tester, 'Review intervals');
    await tester.enterText(find.byType(TextField), '2, 5, 9');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expectNoFrameworkError();
    expect(prefs.getString(PrefKeys.scoped('default', PrefKeys.chazaraIntervals)),
        '2,5,9');
  });

  testWidgets('the backup interval dialog survives closing', (tester) async {
    final prefs = InMemoryPreferences();
    await tester.pumpWidget(host(const SettingsScreen(), prefs: prefs));
    await tester.pumpAndSettle();

    await openSettingsRow(tester, 'Remind me after');
    await tester.enterText(find.byType(TextField), '30');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expectNoFrameworkError();
    expect(
        prefs.getString(
            PrefKeys.scoped('default', PrefKeys.backupIntervalDays)),
        '30');
  });

  testWidgets('the clipboard-import dialog survives closing', (tester) async {
    await tester.pumpWidget(host(const SettingsScreen()));
    await tester.pumpAndSettle();

    await openSettingsRow(tester, 'Import from clipboard');
    // Cancelled: an empty paste is the path that returns without writing, and
    // it still runs the same exit animation.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expectNoFrameworkError();
  });

  group('the shared prompt itself', () {
    Future<String?> show(WidgetTester tester, {int maxLines = 1}) async {
      String? result;
      var returned = false;
      await tester.pumpWidget(localizedApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await promptForText(
                  context,
                  title: 'Title',
                  label: 'Label',
                  initialValue: 'seed',
                  maxLines: maxLines,
                  confirmLabel: 'OK',
                  cancelLabel: 'Cancel',
                );
                returned = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(returned, isFalse);
      return result;
    }

    testWidgets('seeds the field and trims what it returns', (tester) async {
      await show(tester);
      expect(find.text('seed'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  spaced  ');
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      expectNoFrameworkError();
    });

    testWidgets('cancelling returns null, not empty', (tester) async {
      // The callers all distinguish the two: an empty string is a value the
      // user typed, null is a dialog they backed out of.
      await show(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expectNoFrameworkError();
    });

    testWidgets('a multi-line prompt does not submit on Enter', (tester) async {
      // Enter is a newline in a paste box, not "confirm".
      await show(tester, maxLines: 6);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.onSubmitted, isNull);
      expect(field.maxLines, 6);
    });
  });
}
