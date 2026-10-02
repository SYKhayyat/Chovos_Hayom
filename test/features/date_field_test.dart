import 'package:chovos_hayom/core/calendar.dart';
import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/features/common/date_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

/// The shared date control (#32).
///
/// The parser's own tests pin *what* it reads; these pin what a person gets when
/// they type it: that the field says what it understood, that it refuses loudly
/// and stays open, that an ambiguous date is reported rather than resolved, and
/// that the calendar grid still works — because replacing a picker with a text
/// field would be a straight trade for every reader who wants to look at a year
/// and tap it.
void main() {
  const gregorian = CalendarMode.gregorian;

  /// The day the dialog was closed with, or null if it is still open.
  Day? returned;

  Future<void> pump(
    WidgetTester tester, {
    Day? initial,
    Day? reference,
    CalendarMode mode = gregorian,
  }) async {
    returned = null;
    await tester.pumpWidget(
      localizedApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  returned = await promptForDate(
                    context,
                    initial: initial ?? _tenJanuary,
                    reference: reference ?? _tenJanuary,
                    mode: mode,
                    title: 'When',
                    confirmLabel: 'Save',
                    cancelLabel: 'Cancel',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).last, text);
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  /// The dialog's own text field(), and not the one behind the trigger.
  Finder field() => find.byType(TextField).last;

  testWidgets(
    'opens on the day it is changing, in the reader\u2019s calendar',
    (tester) async {
      // A Hebrew reader must not be handed a field full of ISO digits, which is
      // the same defect as #30: the value is right and unreadable.
      await pump(tester, mode: CalendarMode.hebrew);
      expect(
        DateDisplay.format(_tenJanuary.midnight, CalendarMode.hebrew),
        isNot(contains('2026-01-10')),
      );
      expect(
        tester.widget<TextField>(field()).controller!.text,
        DateDisplay.format(_tenJanuary.midnight, CalendarMode.hebrew),
      );
    },
  );

  testWidgets('echoes what it understood, as it is typed', (tester) async {
    await pump(tester);
    await type(tester, '4 Jan 2026');
    expect(find.text('That is 2026-01-04.'), findsOneWidget);
  });

  testWidgets('and a year it filled in is part of the echo', (tester) async {
    // The whole reason the echo exists: `Jan 4` does not say 2026, the
    // reference did, and a year that arrives from nowhere else has to be seen.
    await pump(tester, reference: _tenJanuary2029);
    await type(tester, 'Jan 4');
    expect(find.text('That is 2029-01-04.'), findsOneWidget);
  });

  testWidgets('the echo is gone for input that is not a date', (tester) async {
    await pump(tester);
    await type(tester, 'nonsense');
    expect(find.textContaining('That is '), findsNothing);
  });

  testWidgets('refuses nonsense loudly and stays open', (tester) async {
    await pump(tester);
    await type(tester, 'the day after tomorrow');
    await confirm(tester);

    expect(find.text('That is not a date this can read.'), findsOneWidget);
    expect(returned, isNull, reason: 'nothing was chosen');
    // Still open, with the text the reader typed still in it — on a keypad
    // phone, re-entering a date is a dozen key presses.
    expect(field(), findsOneWidget);
    expect(
      tester.widget<TextField>(field()).controller!.text,
      'the day after tomorrow',
    );
  });

  testWidgets('reports an ambiguous date rather than picking one', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, '4/1/2026');
    await confirm(tester);

    // Both readings named, neither chosen. An override on the wrong day is a
    // plan quietly asking for nothing.
    expect(find.textContaining('2026-01-04'), findsWidgets);
    expect(find.textContaining('2026-04-01'), findsWidgets);
    expect(returned, isNull);
    expect(field(), findsOneWidget);
  });

  testWidgets('accepts Hebrew script and transliteration alike', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, '4 Tevat 5786');
    await confirm(tester);
    expect(returned, Day.of(DateTime(2025, 12, 24)));

    returned = null;
    await pump(tester);
    await type(tester, 'ד׳ טבת תשפ״ו');
    await confirm(tester);
    expect(returned, Day.of(DateTime(2025, 12, 24)));
  });

  testWidgets('confirms on Enter, because a field is a field', (tester) async {
    await pump(tester);
    await type(tester, '4 Jan 2026');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(returned, Day.of(DateTime(2026, 1, 4)));
  });

  testWidgets('the calendar grid is still there, and writes the field', (
    tester,
  ) async {
    // The trade this control refuses to make: a field is better for a reader who
    // knows the date, a grid is better for one who wants to *find* it. So the
    // grid is reachable, and choosing from it puts the day **into the field**
    // rather than ending the dialog — the reader can still see what was chosen
    // and correct it, which a picker-only flow never allowed.
    await pump(tester);
    await tester.tap(find.byTooltip('Pick a date'));
    await tester.pumpAndSettle();

    expect(
      find.byType(CalendarDatePicker),
      findsOneWidget,
      reason:
          'the grid opens on the day the field names, so the two never '
          'disagree about which day is being changed',
    );

    final cell = find.descendant(
      of: find.byType(CalendarDatePicker),
      matching: find.text('15'),
    );
    expect(cell, findsOneWidget);
    await tester.tap(cell);
    await tester.pumpAndSettle();
    // The picker has its own confirm, and pressing it is what returns a day.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      field(),
      findsOneWidget,
      reason: 'choosing from the grid is not the end',
    );
    expect(tester.widget<TextField>(field()).controller!.text, '2026-01-15');
  });

  testWidgets('a Hebrew field is laid out right to left', (tester) async {
    await pump(tester);
    await type(tester, 'ד׳ טבת תשפ״ו');
    expect(tester.widget<TextField>(field()).textDirection, TextDirection.rtl);
    // And a Latin one is not — including a transliterated Hebrew date, which
    // is Hebrew by month and Latin by keyboard.
    await type(tester, '4 Tevet 5786');
    expect(tester.widget<TextField>(field()).textDirection, TextDirection.ltr);
  });

  testWidgets('a date outside the screen\u2019s range is refused, like the grid', (
    tester,
  ) async {
    // The half that is easy to forget: the calendar will not *offer* a day
    // before 2000, and a field that accepted one anyway would let a plan hold a
    // date its own calendar cannot reach. Typing is not a way around the bounds.
    await pump(tester);
    await type(tester, '1 Jan 1850');
    await confirm(tester);

    expect(
      find.text('That date is outside the range this screen can show.'),
      findsOneWidget,
    );
    expect(returned, isNull);
    expect(
      field(),
      findsOneWidget,
      reason: 'still open, still holding the text',
    );
  });

  testWidgets('and the year either side of the range', (tester) async {
    // Both ends, because a bound checked at one end is not a bound. 2400 is a
    // perfectly readable date and perfectly unreachable.
    // Cancelled between the two, deliberately: a *refused* entry leaves its
    // screen on the navigator, and re-pumping over it is how a test ends up
    // asserting against the previous test's route.
    await pump(tester);
    await type(tester, '1 Jan 2400');
    await confirm(tester);
    expect(returned, isNull);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    await pump(tester);
    await type(tester, '1 Jan 2000');
    await confirm(tester);
    expect(
      returned,
      Day.of(DateTime(2000, 1, 1)),
      reason: 'the first day in range is fine, so the bound is inclusive',
    );
  });

  testWidgets('is a full-screen route, not a dialog', (tester) async {
    // It was an `AlertDialog`, and every test for it ran at 800x600 while the
    // 240dp test of the screen that opens it never opened it. Rendered at the
    // device's real 320x432 pixels the title was cut off *above* the top of the
    // screen and the help text cut off mid-line — and making it scrollable did
    // not fix that, it made the same defect quieter.
    //
    // So this asserts the **decision**, at whatever size: a route with its own
    // scaffold, a title in an app bar where a short screen cannot clip it, prose
    // in a list that scrolls under buttons that are pinned.
    //
    // What it deliberately does not assert is that the content *fits* 324
    // logical pixels, because that is a statement about a font and this suite
    // renders in the test font: the button row overflows by 13 pixels there and
    // fits on the device. Asserting it here produced a test that was red in CI
    // and wrong about the product. The screenshot in `screens.golden.dart`,
    // rendered in Roboto, is the check for that, and a person holding the phone
    // is the only one that settles it.
    await pump(tester);

    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'a dialog is the shape that was clipped',
    );
    expect(find.byType(AppBar), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('When')),
      findsOneWidget,
      reason:
          'the title lives in the app bar, which a short screen cannot clip',
    );
    expect(
      find.byType(ListView),
      findsOneWidget,
      reason: 'the prose scrolls under the buttons rather than being cut off',
    );
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
  });

  testWidgets('cancelling chooses nothing', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(returned, isNull);
  });

  testWidgets('the formats it accepts are stated, not left to be guessed', (
    tester,
  ) async {
    // A parser that reads three ways to write a date and says nothing about them
    // is a parser the reader has to discover by trying.
    await pump(tester);
    expect(
      find.textContaining('2026-01-04'),
      findsOneWidget,
      reason: 'the help line names the Gregorian forms',
    );
    expect(find.textContaining('Tevet'), findsOneWidget);
    expect(find.textContaining('טבת'), findsOneWidget);
  });
}

/// 10 January 2026 — a Saturday, and the day most of this file is about.
///
/// Named through `Day.of` rather than as an ordinal literal: an ordinal is a
/// magic number that is wrong the moment anyone reads it, and the whole point
/// of `Day` is that a day is not a timestamp.
final _tenJanuary = Day.of(DateTime(2026, 1, 10));
final _tenJanuary2029 = Day.of(DateTime(2029, 1, 10));
