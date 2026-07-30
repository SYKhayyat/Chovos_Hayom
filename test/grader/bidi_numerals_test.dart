import 'dart:ui' as ui;

import 'package:chovos_hayom/features/common/naming.dart';
import 'package:chovos_hayom/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// GRADER PROBE — bidi reordering of the progress templates under Hebrew.
///
/// `app_he.arb` keeps 13 strings byte-identical to English because they are pure
/// interpolation: `progressCount` is `'{learned} / {total}  ({percent}%)'`, and
/// there is nothing in it to translate. That is the right call for the *string*.
///
/// But nothing in `lib/` used a bidi isolate (`Bidi`, U+200F, U+2068) — the grep
/// found only chevron flips and two `textDirection:` overrides on text fields —
/// so under a Hebrew `Directionality` the Unicode bidi algorithm resolved these
/// neutrals itself. Digits are weak-LTR and the separators (`/`, `(`, `%`) are
/// neutral, which is the classic setup for a reordered line. Confirmed on a real
/// phone screen and on Windows: every row of the tree painted `929 / 0` for
/// "0 learned of 929". The operands swap, so it reports a different number.
///
/// `rtl_layout_test.dart` asserts chevron direction and tree indent. It does not
/// lay out any string, so whatever this does today, the suite does not know it.
///
/// This measures the rendered order directly rather than reasoning about it:
/// lay the string out under RTL and ask where the first logical character
/// actually landed.
///
/// **BUILDER NOTE (W7).** As written, this probe laid out a hard-coded
/// `'5 / 100  (5%)'` — a fact about Flutter's bidi implementation, which no change
/// to this app can alter, so it could never have gone green. What it was *about*
/// is the app's own rendered strings, so it now takes them from the shipped
/// Hebrew table through the same `ltrNumerals` the widgets use. The measurement,
/// the reasoning and the two cases are the grader's, unchanged.
void main() {
  final he = lookupAppLocalizations(const Locale('he'));

  /// The x-offset of the box drawn for the character at [index].
  double xOf(String text, int index, TextDirection direction) {
    final painter = TextPainter(
      text: TextSpan(
          text: text, style: const TextStyle(fontSize: 14, fontFamily: 'Ahem')),
      textDirection: direction,
    )..layout();
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: index, extentOffset: index + 1),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );
    expect(boxes, isNotEmpty, reason: 'no box for index $index of "$text"');
    return boxes.first.left;
  }

  /// Asserts [text] reads left to right whichever way the paragraph runs.
  ///
  /// Compares the first and last *digits* rather than the first and last
  /// characters: an isolate wraps the run in two zero-width controls, and a
  /// zero-width box has no meaningful position.
  void expectReadsLeftToRight(String text, {required String reason}) {
    final first = text.indexOf(RegExp(r'\d'));
    final last = text.lastIndexOf(RegExp(r'\d'));
    expect(first, isNot(-1), reason: 'no digits in "$text"');
    expect(last, greaterThan(first), reason: 'need two digits in "$text"');

    expect(xOf(text, last, TextDirection.ltr),
        greaterThan(xOf(text, first, TextDirection.ltr)),
        reason: 'sanity: under LTR the line reads left to right');
    expect(xOf(text, last, TextDirection.rtl),
        greaterThan(xOf(text, first, TextDirection.rtl)), reason: reason);
  }

  test('the progress template keeps its reading order under Hebrew', () {
    // Exactly what the dashboard paints: the Hebrew table's own template, run
    // through the same helper `progress_tile.dart` uses.
    expectReadsLeftToRight(
      ltrNumerals(he.progressCount(5, 100, '5')),
      reason: 'under Hebrew the progress count renders in reverse order',
    );
  });

  test('a bare learned/total fraction is not read as its own inverse', () {
    // The sharper case: reversing punctuation is ugly, but reversing "7/100"
    // into "100/7" reports a *different number*. Measured, not assumed: '7/100'
    // is SAFE unpadded — a slash directly between two digits is a Common
    // Separator and joins the numeric run — and `meforishCoverage` is spelled
    // that way. `statsLearnedValue` is padded with spaces, which is what breaks
    // it. Both are asserted, because the safety of the first is a property of
    // where its spaces are, not of anyone's intent.
    expectReadsLeftToRight(
      ltrNumerals(he.meforishCoverage(7, 100)),
      reason: 'the un-spaced form must stay left-to-right',
    );
    expectReadsLeftToRight(
      ltrNumerals(he.statsLearnedValue(7, 100)),
      reason: 'the space-padded form renders reversed under Hebrew — the user '
          'reads the total and the learned count swapped',
    );
  });

  test('without the isolate, the padded form really does reverse', () {
    // The control. If Flutter ever stops reordering these, the two tests above
    // would pass for a reason that has nothing to do with the fix, and this is
    // what says so.
    final bare = he.statsLearnedValue(7, 100);
    final first = bare.indexOf(RegExp(r'\d'));
    final last = bare.lastIndexOf(RegExp(r'\d'));

    expect(xOf(bare, last, TextDirection.rtl),
        lessThan(xOf(bare, first, TextDirection.rtl)),
        reason: 'the defect this file exists for: "7 / 100" laid out under RTL '
            'puts its last digit to the LEFT of its first');
  });
}
