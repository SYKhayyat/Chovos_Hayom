import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// GRADER PROBE — bidi reordering of the progress templates under Hebrew.
///
/// `app_he.arb` keeps 13 strings byte-identical to English because they are pure
/// interpolation: `progressCount` is `'{learned} / {total}  ({percent}%)'`, and
/// there is nothing in it to translate. That is the right call for the *string*.
///
/// But nothing in `lib/` uses a bidi isolate (`Bidi`, U+200F, U+2068) — the grep
/// finds only chevron flips and two `textDirection:` overrides on text fields —
/// so under a Hebrew `Directionality` the Unicode bidi algorithm resolves these
/// neutrals itself. Digits are weak-LTR and the separators (`/`, `(`, `%`) are
/// neutral, which is the classic setup for a reordered line.
///
/// `rtl_layout_test.dart` asserts chevron direction and tree indent. It does not
/// lay out any string, so whatever this does today, the suite does not know it.
///
/// This measures the rendered order directly rather than reasoning about it:
/// lay the string out under RTL and ask where the first logical character
/// actually landed.
void main() {
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

  test('the progress template keeps its reading order under Hebrew', () {
    // "5 / 100  (5%)" — exactly what progressCount interpolates to.
    const text = '5 / 100  (5%)';

    final ltrFirst = xOf(text, 0, TextDirection.ltr); // the "5" of 5/100
    final ltrLast = xOf(text, text.length - 1, TextDirection.ltr); // ")"
    expect(ltrLast, greaterThan(ltrFirst),
        reason: 'sanity: under LTR the line reads left to right');

    final rtlFirst = xOf(text, 0, TextDirection.rtl);
    final rtlLast = xOf(text, text.length - 1, TextDirection.rtl);

    // Under RTL the numerals must still read as one left-to-right run: the
    // leading "5" to the left of the trailing ")". If the bidi algorithm has
    // reordered the neutrals, the closing paren lands to the LEFT of the
    // leading digit and the user reads "(5%)  100 / 5".
    expect(rtlLast, greaterThan(rtlFirst),
        reason: 'under Hebrew the progress count renders in reverse order');
  });

  test('a bare learned/total fraction is not read as its own inverse', () {
    // `meforishCoverage` and `statsLearnedValue` are '{learned}/{total}' and
    // '{learned} / {total}'. This is the sharper case: reversing punctuation is
    // ugly, but reversing "7/100" into "100/7" reports a *different number*.
    // Measured, not assumed: '7/100' is SAFE — a slash directly between two
    // digits is a Common Separator and joins the numeric run, so it stays
    // left-to-right. `meforishCoverage` is spelled that way and is fine.
    // Padding it with spaces is what breaks it, and `statsLearnedValue` is
    // spelled *that* way.
    final tight = xOf('7/100', 0, TextDirection.rtl);
    expect(xOf('7/100', 4, TextDirection.rtl), greaterThan(tight),
        reason: 'sanity: the un-spaced form is not affected');

    const text = '7 / 100';
    final first = xOf(text, 0, TextDirection.rtl); // the "7"
    final last = xOf(text, text.length - 1, TextDirection.rtl); // last "0"
    expect(last, greaterThan(first),
        reason: '"$text" renders reversed under Hebrew — the user reads the '
            'total and the learned count swapped');
  });
}
