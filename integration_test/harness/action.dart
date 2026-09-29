import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'device_profile.dart';

/// One thing a person does to the app, or one thing they look for.
///
/// **A vocabulary, not a script.** A journey is written as a list of these, in
/// the words of the task rather than the mechanics of the framework, so that
/// "mark a daf and watch the percentage move" reads as that and can be pointed
/// at a failure by name. The alternative — raw `tester.tap(find.text(…))` inline
/// in fifty tests — is how a suite ends up testing `find.text`.
///
/// Two properties make the vocabulary honest rather than decorative:
///
/// - **Every step can be driven two ways.** [Tap] and [Press] are the same
///   intent through two inputs, because the two phones this app is built for
///   have almost nothing in common: the Moto G Stylus is a touchscreen and the
///   Sonim XP5s is a D-pad and a numeric keypad with no glass to touch. A suite
///   that only taps has tested the Moto and quietly skipped the Sonim, which is
///   the device the app's compact layout exists for. `--dart-define=
///   HARNESS_INPUT=keys` runs the same journeys through the focus tree and the
///   centre key instead.
/// - **Every step reports where it was.** A failure names the step, the widget it
///   was looking for, and what was on screen instead, because a screenshot with
///   no words next to it costs a person a minute per failure.
abstract class Act {
  const Act();

  /// What this step was trying to do, in a sentence. In the failure report.
  String get intent;

  Future<void> run(HarnessContext c);
}

/// The state one journey runs in: the tester, the device, and how this run is
/// driving the app.
class HarnessContext {
  HarnessContext(this.tester, this.device, this.input);

  final WidgetTester tester;
  final DeviceProfile device;
  final HarnessInput input;

  /// Whether screenshots are being collected on this run.
  ///
  /// Read from a define rather than guessed, because pulling screenshots needs
  /// the driver (`flutter drive`) and on Android needs the surface converted
  /// first. A run that tried to shoot without them would hang or throw in a way
  /// that looks like a product failure, so it is asked for explicitly instead.
  static bool get screenshotsWanted =>
      const String.fromEnvironment('HARNESS_SHOTS') == '1';

  /// Saves the screen as `screenshots/<name>.png` on the host, via the driver.
  Future<void> screenshot(String name) async {
    if (!screenshotsWanted) return;
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await binding.takeScreenshot(name);
  }
}

/// How this run reaches the app's controls.
enum HarnessInput {
  /// By pointer. Correct on a touchscreen; on a keypad phone it is a path no user
  /// has, which is why [HarnessInput.keys] exists.
  pointer,

  /// By focus and the centre key: the only way a Sonim user can reach anything.
  keys,
}

/// Settle the frame, with a deadline.
///
/// `pumpAndSettle`'s default is ten minutes, which is not a timeout so much as a
/// way of turning "this never settles" into a file that appears to hang. A
/// journey that triggers a SnackBar waits out its full timer if the deadline is
/// loose, so every settle here is bounded and a failure names the step that
/// spun rather than blaming whatever ran last.
class Settle extends Act {
  const Settle([this.why = 'to finish what it just started']);

  final String why;

  @override
  String get intent => 'settle $why';

  @override
  Future<void> run(HarnessContext c) async {
    await c.tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 8),
    );
  }
}

/// Taps something a person can see and read.
///
/// [text] is the English string, because the app's English table is the one the
/// ARB keys are written against and a copy change should break a journey
/// loudly rather than silently re-target it. A Hebrew journey exists for the
/// handful of places where mirrored layout is the thing under test.
class Tap extends Act {
  const Tap(this.text, {this.note});

  final String text;
  final String? note;

  @override
  String get intent => 'tap "$text"${note == null ? '' : ' — $note'}';

  @override
  Future<void> run(HarnessContext c) async {
    final finder = _reach(c, find.text(text));
    if (c.input == HarnessInput.pointer) {
      await c.tester.tap(finder, warnIfMissed: false);
    } else {
      await focusAndActivate(c, finder);
    }
    await Settle('after tapping "$text"').run(c);
  }
}

/// Taps the first of [candidates] that is on screen.
///
/// **A concession this harness needs and a shipped test should not.** A journey
/// written without a device to read has to guess at some of the app's copy, and a
/// guess that is wrong should cost one edit to the list rather than a whole
/// journey. Every candidate is reported when none matches, so the failure says
/// what it looked for *and* what was there — which is the difference between a
/// five-minute fix and an archaeology exercise.
class TapAny extends Act {
  const TapAny(this.candidates, {this.note});

  final List<String> candidates;
  final String? note;

  @override
  String get intent => 'tap any of ${candidates.join(', ')}'
      '${note == null ? '' : ' — $note'}';

  @override
  Future<void> run(HarnessContext c) async {
    for (final candidate in candidates) {
      if (find.text(candidate).evaluate().isNotEmpty) {
        await Tap(candidate).run(c);
        return;
      }
    }
    throw StateError(
      'none of ${candidates.join(', ')} is on screen.\n'
      'On screen: ${_visibleText(c).take(40).join(' | ')}',
    );
  }
}

/// Taps something identified by its tooltip — an icon-only control, which is
/// most of the app's navigation.
class TapTooltip extends Act {
  const TapTooltip(this.tooltip, {this.note});

  final String tooltip;
  final String? note;

  @override
  String get intent => 'tap the "$tooltip" control${note == null ? '' : ' — $note'}';

  @override
  Future<void> run(HarnessContext c) async {
    final finder = _reach(c, find.byTooltip(tooltip));
    if (c.input == HarnessInput.pointer) {
      await c.tester.tap(finder, warnIfMissed: false);
    } else {
      await focusAndActivate(c, finder);
    }
    await Settle('after tapping "$tooltip"').run(c);
  }
}

/// Taps the control holding [text], anywhere inside it.
///
/// A row with a title and a chevron is one thing to a person, and three nested
/// widgets to a finder. This is the shape most of the app's lists are.
class TapRow extends Act {
  const TapRow(this.text, {this.note});

  final String text;
  final String? note;

  @override
  String get intent => 'tap the row saying "$text"${note == null ? '' : ' — $note'}';

  @override
  Future<void> run(HarnessContext c) async {
    final finder = _reach(
      c,
      find.ancestor(
        of: find.text(text),
        matching: find.byType(InkWell),
        matchRoot: true,
      ).first,
    );
    if (c.input == HarnessInput.pointer) {
      await c.tester.tap(finder, warnIfMissed: false);
    } else {
      await focusAndActivate(c, finder);
    }
    await Settle('after tapping the "$text" row').run(c);
  }
}

/// Presses and holds — a long press, which on this app is how a unit's details
/// are reached, and how a keyboard phone reaches anything a touchscreen reaches
/// by tapping and holding.
class LongPress extends Act {
  const LongPress(this.text, {this.note});

  final String text;
  final String? note;

  @override
  String get intent => 'long-press "$text"${note == null ? '' : ' — $note'}';

  @override
  Future<void> run(HarnessContext c) async {
    // By pointer in both input modes, and that is a real limitation rather than
    // an oversight: a long press is a *timing*, and `sendKeyEvent` cannot hold a
    // key down. A journey that genuinely needs a long press on a keypad phone
    // says so in its tags instead — see [Journey.tags].
    final finder = _reach(c, find.text(text));
    await c.tester.longPress(finder, warnIfMissed: false);
    await Settle('after long-pressing "$text"').run(c);
  }
}

/// Types into the field a person would be typing into.
class Type extends Act {
  const Type(this.text, {this.into, this.clearFirst = true, this.note});

  final String text;

  /// Which field: the only one, or one labelled [into]. Addressed by label
  /// rather than by position, because "the third field" is a statement about
  /// layout that a Hebrew locale or a long label rearranges.
  final String? into;
  final bool clearFirst;
  final String? note;

  @override
  String get intent => 'type "$text"${into == null ? '' : ' into $into'}'
      '${note == null ? '' : ' — $note'}';

  @override
  Future<void> run(HarnessContext c) async {
    final field = _field(c);
    await const Settle('before typing').run(c);
    if (clearFirst) await c.tester.enterText(field, '');
    await c.tester.enterText(field, text);
    await const Settle('after typing').run(c);
  }

  Finder _field(HarnessContext c) {
    if (into == null) {
      final fields = find.byType(TextField);
      if (fields.evaluate().isEmpty) {
        throw StateError('no text field on screen to type "$text" into');
      }
      return fields.last;
    }
    return find.widgetWithText(TextField, into!);
  }
}

/// Presses a key, which on a keypad phone is the only input there is.
class Press extends Act {
  const Press(this.key, {this.times = 1, this.note});

  final LogicalKeyboardKey key;
  final int times;
  final String? note;

  @override
  String get intent => 'press ${key.keyLabel}'
      '${times == 1 ? '' : ' $times times'}'
      '${note == null ? '' : ' — $note'}';

  @override
  Future<void> run(HarnessContext c) async {
    for (var i = 0; i < times; i++) {
      await c.tester.sendKeyEvent(key);
      await Settle('after ${key.keyLabel}').run(c);
    }
  }
}

/// Goes back, the way the phone's own key does.
class Back extends Act {
  const Back({this.note});

  final String? note;

  @override
  String get intent => 'go back${note == null ? '' : ' — $note'}';

  @override
  Future<void> run(HarnessContext c) async {
    if (c.input == HarnessInput.keys) {
      await const Press(LogicalKeyboardKey.escape).run(c);
      return;
    }
    await const TapTooltip('Back').run(c);
  }
}

/// Scrolls until [text] is on screen — the gesture, not a fling.
class ScrollTo extends Act {
  const ScrollTo(this.text, {this.maxDrags = 24, this.note});

  final String text;
  final int maxDrags;
  final String? note;

  @override
  String get intent => 'scroll to "$text"${note == null ? '' : ' — $note'}';

  @override
  Future<void> run(HarnessContext c) async {
    final target = find.text(text);
    for (var i = 0; i < maxDrags; i++) {
      if (target.evaluate().isNotEmpty) {
        await c.tester.ensureVisible(target.first);
        await Settle('after revealing "$text"').run(c);
        return;
      }
      await c.tester.drag(
        find.byType(Scrollable).last,
        const Offset(0, -120),
      );
      await Settle('while scrolling to "$text"').run(c);
    }
    if (target.evaluate().isEmpty) {
      throw StateError(
        'scrolled $maxDrags times and "$text" never came on screen',
      );
    }
  }
}

/// The user sees [text]. The most-used step in the vocabulary by far, and the
/// one that carries the meaning: the consequence, not the mechanism.
class See extends Act {
  const See(this.text, {this.note});

  final String text;
  final String? note;

  @override
  String get intent => 'see "$text"${note == null ? '' : ' — $note'}';

  @override
  Future<void> run(HarnessContext c) async {
    await Settle('before looking for "$text"').run(c);
    if (find.text(text).evaluate().isEmpty) {
      throw StateError(
        '"$text" is not on screen.\n'
        'On screen: ${_visibleText(c).take(40).join(' | ')}',
      );
    }
  }
}

/// The user does **not** see [text].
///
/// Held as its own step rather than as the absence of [See], because "the day
/// off I just set is not shown as a blank" is a claim about the app and needs to
/// fail on its own when it stops being true.
class SeeNothing extends Act {
  const SeeNothing(this.text, {this.note});

  final String text;
  final String? note;

  @override
  String get intent => 'not see "$text"${note == null ? '' : ' — $note'}';

  @override
  Future<void> run(HarnessContext c) async {
    await Settle('before looking for the absence of "$text"').run(c);
    if (find.text(text).evaluate().isNotEmpty) {
      throw StateError('"$text" is on screen and should not be');
    }
  }
}

/// One of [candidates] is on screen — for a value that is derived, like a
/// total, where the exact figure is the app's business and not the journey's.
class SeeAnyOf extends Act {
  const SeeAnyOf(this.candidates, {this.note});

  final List<String> candidates;
  final String? note;

  @override
  String get intent => 'see one of ${candidates.join(', ')}'
      '${note == null ? '' : ' — $note'}';

  @override
  Future<void> run(HarnessContext c) async {
    await const Settle('before looking for any of them').run(c);
    if (candidates.every((t) => find.text(t).evaluate().isEmpty)) {
      throw StateError(
        'none of ${candidates.join(', ')} is on screen.\n'
        'On screen: ${_visibleText(c).take(40).join(' | ')}',
      );
    }
  }
}

/// A screenshot, which is the evidence a person looks at when a step fails and
/// the only record of what the screen *looked* like rather than what it said.
class Shot extends Act {
  const Shot(this.name);

  final String name;

  @override
  String get intent => 'screenshot $name';

  @override
  Future<void> run(HarnessContext c) => c.screenshot(name);
}

/// Brings [finder] on screen, failing loudly rather than silently tapping
/// something off the edge of the display.
Finder _reach(HarnessContext c, Finder finder) {
  if (finder.evaluate().isEmpty) {
    throw StateError(
      'nothing on screen to tap.\n'
      'On screen: ${_visibleText(c).take(40).join(' | ')}',
    );
  }
  if (finder.evaluate().length > 1) {
    // Ambiguity is worth knowing about rather than resolving silently: a finder
    // matching two things means the screen has two of that label, which is
    // usually a real finding about the app and never a reason to tap the first.
    throw StateError(
      '${finder.evaluate().length} things on screen match, so the tap would be '
      'a guess. On screen: ${_visibleText(c).take(40).join(' | ')}',
    );
  }
  return finder;
}

/// Walks focus onto [finder] and presses the centre key.
///
/// **The keypad path, and the reason [HarnessInput] exists.** Directional focus
/// only moves between nodes that take focus, and a `ListTile` is not one — a row
/// is an `InkWell` with a focusable inside it, or nothing at all. So this does
/// what a D-pad user does: press a direction until the control has focus, then
/// press enter. The cap is a real constraint and not politeness: a control that
/// focus cannot reach in twenty presses is a control that phone's user cannot
/// reach either, and saying so is the point.
Future<void> focusAndActivate(
  HarnessContext c,
  Finder finder, {
  int maxPresses = 20,
}) async {
  for (var i = 0; i < maxPresses; i++) {
    if (_hasFocus(c, finder)) {
      await c.tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await const Settle('after activating by key').run(c);
      return;
    }
    // Down is the direction that reaches the body of a screen from its app bar,
    // which is where a journey starts.
    await c.tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await c.tester.pump(const Duration(milliseconds: 50));
  }
  if (_hasFocus(c, finder)) {
    await c.tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await const Settle('after activating by key').run(c);
    return;
  }
  throw StateError(
    'no route by key to the widget this step wanted, after $maxPresses presses '
    'of "down". A D-pad user cannot reach it either.',
  );
}

bool _hasFocus(HarnessContext c, Finder finder) {
  final focus = FocusManager.instance.primaryFocus;
  if (focus?.context == null) return false;
  final element = find.byWidget(focus!.context!.widget);
  if (finder.evaluate().isEmpty || element.evaluate().isEmpty) return false;
  // Focus is on *something*; the question is whether it is inside the control
  // this step wanted, or is the control.
  final target = finder.evaluate().first;
  return target == element.evaluate().first ||
      _isAncestorOf(target, element.evaluate().first);
}

bool _isAncestorOf(Element ancestor, Element node) {
  Element? current = node;
  for (var depth = 0; depth < 40 && current != null; depth++) {
    if (identical(current, ancestor)) return true;
    // The public way up the tree. `Element.visitParentElement` is not part of
    // the stable API and a harness that used it would break on a Flutter
    // upgrade for no reason — and this file is meant to survive upgrades.
    current = _parentOf(current);
  }
  return false;
}

Element? _parentOf(Element element) {
  Element? parent;
  element.visitAncestorElements((e) {
    parent ??= e;
    // The framework's implementation starts at `_parent`, so the first callback
    // *is* the direct parent and returning false stops there. Walking to the
    // root would find a `FocusScope` above every screen, and stopping at "some
    // ancestor named Focus" is the same answer for every press — which is what
    // made this hard to get right by reading alone.
    return false;
  });
  return parent;
}

/// Asserts the screen is showing something rather than a blank page.
///
/// Cheap, and it catches the failure a per-screen "did not throw" check cannot:
/// a screen that renders nothing at all throws nothing.
class SomethingIsShown extends Act {
  const SomethingIsShown({this.note});

  final String? note;

  @override
  String get intent => 'the screen has content on it'
      '${note == null ? '' : ' — $note'}';

  @override
  Future<void> run(HarnessContext c) async {
    await const Settle('before looking at the screen').run(c);
    final texts = find.byType(Text).evaluate().length;
    final rows = find.byType(Row).evaluate().length;
    if (texts + rows < 4) {
      throw StateError(
        'the screen is essentially empty: $texts Text widgets, $rows Rows. '
        'On screen: ${_visibleText(c).take(30).join(' | ')}',
      );
    }
  }
}

/// Every non-empty string on screen, for a failure that says what *was* there.
Iterable<String> _visibleText(HarnessContext c) sync* {
  for (final text in c.tester.widgetList<Text>(find.byType(Text))) {
    final data = text.data;
    if (data != null && data.trim().isNotEmpty) yield data;
  }
}
