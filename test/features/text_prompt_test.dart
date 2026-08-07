import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/features/common/text_prompt.dart';
import 'package:chovos_hayom/features/profiles/profiles_screen.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/features/settings/settings_screen.dart';
import 'package:chovos_hayom/features/unit_grid/unit_grid_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/memory_database.dart';
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
              .overrideWithValue(memoryRepository()),
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

  /// The two interval settings, two rows apart, which used to disagree about
  /// what happens to input neither of them can use: one silently kept the parts
  /// it understood, the other closed and complained on a snackbar.
  group('both interval dialogs say no the same way', () {
    testWidgets('a part it cannot read is named, and nothing is saved',
        (tester) async {
      final prefs = InMemoryPreferences();
      await tester.pumpWidget(host(const SettingsScreen(), prefs: prefs));
      await tester.pumpAndSettle();

      await openSettingsRow(tester, 'Review intervals');
      await tester.enterText(find.byType(TextField), '2, 5, x');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // Still open, still holding what was typed — and explicit about which
      // part it did not understand. This used to save [2, 5] and close.
      expect(find.text('Not a number of days: x'), findsOneWidget);
      expect(find.text('2, 5, x'), findsOneWidget);
      expect(prefs.getString(PrefKeys.scoped('default', PrefKeys.chazaraIntervals)),
          isNull);

      await tester.enterText(find.byType(TextField), '2, 5, 9');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(prefs.getString(PrefKeys.scoped('default', PrefKeys.chazaraIntervals)),
          '2,5,9');
      expectNoFrameworkError();
    });

    testWidgets('an empty schedule is refused rather than silently defaulted',
        (tester) async {
      await tester.pumpWidget(host(const SettingsScreen()));
      await tester.pumpAndSettle();

      await openSettingsRow(tester, 'Review intervals');
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('at least one interval'), findsOneWidget);
      expectNoFrameworkError();
    });

    testWidgets('and the backup interval refuses in the same place',
        (tester) async {
      final prefs = InMemoryPreferences();
      await tester.pumpWidget(host(const SettingsScreen(), prefs: prefs));
      await tester.pumpAndSettle();

      await openSettingsRow(tester, 'Remind me after');
      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // In the dialog, not on a snackbar behind a dialog that has already gone.
      expect(find.text('Enter a number of days above 0.'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(
          prefs.getString(PrefKeys.scoped('default', PrefKeys.backupIntervalDays)),
          isNull);
      expectNoFrameworkError();
    });
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

  /// The two things the prompt could not do, which is why two dialogs
  /// hand-rolled the controller-ownership it exists to hold: more than one
  /// field, and rejecting input without closing.
  group('more than one field, and saying no', () {
    Future<Map<String, String>?> show(
      WidgetTester tester, {
      String? Function(Map<String, String>)? validate,
      PromptLayout layout = PromptLayout.column,
    }) async {
      Map<String, String>? result;
      await tester.pumpWidget(localizedApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await promptForFields(
                context,
                title: 'Title',
                confirmLabel: 'OK',
                cancelLabel: 'Cancel',
                footer: 'Either is enough',
                validate: validate,
                layout: layout,
                fields: const [
                  PromptField(key: 'from', label: 'From', initialValue: '2'),
                  PromptField(key: 'to', label: 'To', initialValue: '10'),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('returns every field, keyed, and seeds each one',
        (tester) async {
      await show(tester);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Either is enough'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '2'), ' 4 ');
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      expectNoFrameworkError();
    });

    testWidgets('only the last single-line field submits on Enter',
        (tester) async {
      await show(tester);
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.first.onSubmitted, isNull);
      expect(fields.last.onSubmitted, isNotNull);
    });

    testWidgets('a rejected value keeps the dialog open with the typing in it',
        (tester) async {
      // The whole reason the range dialog owned its own state. Closing and
      // then complaining throws away two numbers, which on a keypad phone is a
      // dozen key presses to re-enter.
      var calls = 0;
      await show(tester, validate: (v) {
        calls++;
        return v['from'] == '99' ? 'Out of range' : null;
      });

      await tester.enterText(find.widgetWithText(TextField, '2'), '99');
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.text('Out of range'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget, reason: 'still open');
      expect(find.text('99'), findsOneWidget, reason: 'and still typed in');

      await tester.enterText(find.widgetWithText(TextField, '99'), '3');
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      expect(find.text('Title'), findsNothing);
      expectNoFrameworkError();
    });

    testWidgets('cancelling never runs the validator', (tester) async {
      var calls = 0;
      await show(tester, validate: (_) {
        calls++;
        return 'no';
      });
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expectNoFrameworkError();
    });
  });

  /// The two dialogs that had hand-rolled all of the above, driven through the
  /// app rather than through the prompt.
  group('the two that hand-rolled it', () {
    /// The unit grid, which is where both of these are reached from.
    Widget grid(ProgressRepository repo) => ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
            progressRepositoryProvider.overrideWithValue(repo),
            crashLogProvider.overrideWithValue(RecordingCrashLog()),
          ],
          child: localizedApp(
              home: const UnitGridScreen(nodeId: 'shas.moed.shabbos')),
        );

    testWidgets('adding a meforish still takes both names', (tester) async {
      final repo = memoryRepository();
      await tester.pumpWidget(grid(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Mefarshim'));
      await tester.pumpAndSettle();
      // Eleven built-in mefarshim above it, so the button is below the fold.
      await tester.ensureVisible(find.text('Add a meforish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a meforish'));
      await tester.pumpAndSettle();

      // Two fields, the Hebrew one right-to-left whatever locale the app is in,
      // and the "either is enough" note under them — all of which the
      // hand-rolled dialog had built for itself.
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, hasLength(2));
      expect(fields.last.textDirection, TextDirection.rtl);
      expect(find.textContaining('Either one is enough'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Maharam');
      await tester.enterText(find.byType(TextField).last, 'מהר״ם');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expectNoFrameworkError();
      final layers = await repo.getCustomLayers('default');
      expect(layers.single.name, 'Maharam');
      expect(layers.single.nameHebrew, 'מהר״ם');
    });

    testWidgets('an out-of-range finish stays open and says why',
        (tester) async {
      await tester.pumpWidget(grid(memoryRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Finish all / clear all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish a range…'));
      await tester.pumpAndSettle();

      // Shabbos runs 2..157, so 500 is not a daf it has.
      await tester.enterText(find.widgetWithText(TextField, '157'), '500');
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      await tester.pumpAndSettle();

      expect(find.text('Units run from 2 to 157.'), findsOneWidget);
      expect(find.text('500'), findsOneWidget,
          reason: 'a rejected range must not throw away what was typed');

      // And a good one goes through to the confirmation, which counts units.
      await tester.enterText(find.widgetWithText(TextField, '500'), '5');
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      await tester.pumpAndSettle();

      expect(find.textContaining('4 units'), findsOneWidget);
      expectNoFrameworkError();
    });
  });
}
