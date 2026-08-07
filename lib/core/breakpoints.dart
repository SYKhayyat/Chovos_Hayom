/// Support for phones that have no touchscreen at all — a D-pad, a centre key
/// and a numeric keypad, and nothing else.
///
/// The device this was built against is a Sonim XP5s: Android 7.1.2, a 320x432
/// screen at 213dpi, which is **240 x 324 logical pixels**. Material's smallest
/// design target is 320x480, so this is a quarter narrower and a third shorter
/// than anything upstream accounts for, and every fixed width or fixed aspect
/// ratio in the app was written for a screen that is not this one.
///
/// Measured on that device before any of this existed: the app ran, focus moved
/// on the D-pad and the centre key activated things — Flutter gives all of that
/// for free — but *nothing on screen ever changed to say what was selected*.
/// Pressing the centre key on the unit grid opened "Bulk actions", because focus
/// had started on an app bar icon and there was no way to know. One more press
/// would have marked an entire sefer learned. That is the defect this work
/// exists to remove: the app was operable and blind.
///
/// **This was one file called `keypad.dart`, and the name had stopped being
/// true.** Of its 425 lines only about nineteen are genuinely "this device is
/// 240dp"; three of its six parts — the app bar folding, the scroll wrapper and
/// the focus ring — are unconditional cross-platform improvements that would be
/// worth keeping if the Sonim went in a river. A screen importing `keypad.dart`
/// to decide whether to show a checkmark in a segmented button was importing a
/// file that did not describe what it was being asked for. Nothing was deleted:
/// it is three files named for what they hold, and the device story lives here
/// because this is the file that holds the measurement.
library;

import 'package:flutter/material.dart';

/// Widths below this belong to a keypad phone rather than a small touchscreen.
///
/// The narrowest ordinary phone is 320dp and a common one is 360dp, so this
/// threshold cannot fire on a real touchscreen; the target device is 240dp.
const double kCompactWidth = 300;

/// Whether the app is drawing on a keypad-phone screen.
///
/// Layout decisions keyed off this are about *width*, not about the input
/// device — a 240dp screen needs one column whether or not it can be touched.
bool isCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kCompactWidth;

/// Applies the handful of theme tweaks a 240dp screen needs, or nothing at all
/// on any other screen.
///
/// This sits in `MaterialApp.builder` rather than in the `ThemeData` itself
/// because the decision needs a `MediaQuery`, which does not exist yet where the
/// theme is built.
Widget compactTheme(BuildContext context, Widget child) {
  if (!isCompact(context)) return child;
  final theme = Theme.of(context);
  return Theme(
    data: theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        // Material's 22sp title needs about 160dp for two ordinary words, and
        // "Learning cycles" was arriving as "Learning…" on a bar that had the
        // room and was just asking for too much of it. One step down, plus half
        // the usual gap after the back button, fits the longest title this app
        // has — and it is still the largest text on the screen.
        titleTextStyle: theme.textTheme.titleMedium
            ?.copyWith(color: theme.colorScheme.onSurface),
        titleSpacing: 8,
      ),
    ),
    child: child,
  );
}
