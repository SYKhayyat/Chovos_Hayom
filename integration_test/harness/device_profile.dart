import 'package:chovos_hayom/core/breakpoints.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journey.dart';

/// What the harness knows about the phone it is running on, and the two layout
/// classes it cares about.
///
/// This exists because the two devices this app is built for are opposites in
/// every dimension that matters to a layout: a Moto G Stylus is 1080x2400 at
/// 2.75x with a touchscreen, and a Sonim XP5s is 320x432 at 213dpi — 240x324
/// logical pixels — with a D-pad and a numeric keypad and nothing to touch. A
/// suite that runs on one and not the other is a suite that has tested half the
/// product.
///
/// So the harness does not only run at the device's **native** size. It also
/// runs at the *other* class, by resizing the view: the Moto checks that a
/// 240dp layout is sound, and the Sonim checks that a 1080x2400 one is. One run
/// then covers both, on either phone, and a run on both phones covers the
/// device-specific input paths as well.
class DeviceProfile {
  const DeviceProfile({
    required this.size,
    required this.devicePixelRatio,
    required this.platform,
    required this.textScale,
  });

  final Size size;
  final double devicePixelRatio;
  final String platform;
  final double textScale;

  bool get isCompact => size.width < kCompactWidth;

  /// One line, printed first, so a failure report says which phone it was on.
  String get describe =>
      '${size.width.round()}x${size.height.round()} dp '
      'at ${devicePixelRatio.toStringAsFixed(2)}x, $platform, '
      'text scale ${textScale.toStringAsFixed(2)}'
      '${isCompact ? ' (compact)' : ''}';

  static DeviceProfile read(WidgetTester tester) => DeviceProfile(
    size: tester.view.physicalSize / tester.view.devicePixelRatio,
    devicePixelRatio: tester.view.devicePixelRatio,
    platform: defaultTargetPlatform.name,
    textScale: tester.platformDispatcher.textScaleFactor,
  );
}

/// The Sonim XP5s, in logical pixels.
///
/// 320x432 at 213dpi, which is 240x324 logical and a device pixel ratio of
/// 213/160. Written down because the whole reason this harness exists is that
/// this layout has to be checked, and a number written in a test is a number
/// somebody can check.
const Size kSonimDp = Size(240, 324);
const double kSonimDpr = 213 / 160;

/// A phone-sized viewport, for the other direction: the harness runs a compact
/// class on a big screen and a roomy class on a small one.
const Size kPhoneDp = Size(411, 891);

/// A layout class the harness sweeps a screen at.
class Viewport {
  const Viewport({
    required this.name,
    required this.size,
    this.textScale = 1.0,
  });

  final String name;

  /// Logical size.
  final Size size;
  final double textScale;

  @override
  String toString() =>
      '$name (${size.width.round()}x${size.height.round()} dp'
      '${textScale == 1.0 ? '' : ', text ${textScale}x'})';

  /// Applies this viewport to the test view, keeping the device's own ratio so
  /// a physical-pixel screen reports physical pixels.
  void apply(WidgetTester tester) {
    tester.view
      ..devicePixelRatio = tester.view.devicePixelRatio
      ..physicalSize = size * tester.view.devicePixelRatio
      ..padding = FakeViewPadding.zero
      ..viewInsets = FakeViewPadding.zero;
    // Large text is one of the two things a device sees and a widget test cannot:
    // `MediaQuery.textScalerOf` in a test is always 1.0, so a layout that clips
    // at 1.3x is invisible to the suite. This deliberately overrides whatever
    // the OS is set to, which is why [DeviceProfile.read] is called *before*
    // the first viewport is applied — otherwise the harness would report its own
    // override as the device's setting.
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
  }

  /// Hands the OS text scale back, so a harness run cannot leave a device set to
  /// 1.3x for whatever the person opens next.
  static void restoreTextScale(WidgetTester tester) {
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }
}

/// The viewports a run sweeps, in order.
///
/// **Native first and always**: it is the one that is really this phone, and it
/// is the one whose screenshots mean anything for the person holding it. The
/// emulated class comes second, and is the reason one device can stand in for
/// the other.
List<Viewport> viewportsUnderTest(DeviceProfile device) => [
  Viewport(
    name: 'native ${device.isCompact ? 'compact' : 'roomy'}',
    size: device.size,
  ),
  Viewport(
    name: device.isCompact ? 'roomy' : 'compact',
    size: device.isCompact ? kPhoneDp : kSonimDp,
  ),
  // A third pass at a **larger text scale**, on the compact class only,
  // because that is where overflow is born: an 8sp label that fits at 240dp
  // stops fitting the moment a reader turns their system font up, and this
  // app is for people who read Hebrew script all day.
  if (!device.isCompact)
    const Viewport(name: 'compact, large text', size: kSonimDp, textScale: 1.3),
];

/// Whether this device can actually draw Hebrew.
///
/// **The question the screenshot harness could not answer and this one can.** A
/// Material text style names *Roboto*, and Roboto has no Hebrew glyphs, so
/// Hebrew is rendered by whatever the engine falls back to — on a real device
/// that is the system Hebrew font, and in a widget test it is a box. So
/// "does Hebrew render here" is a question about the device, not about the app,
/// and the only way to ask it is on one.
///
/// The test is to measure it: a codepoint in the **private use area** has no
/// glyph in any real font, so it is always drawn as the same "notdef" box, and
/// its width is that box's width. If Hebrew text comes out exactly as wide as
/// that box, it *is* that box, and the answer is no. A string of several letters
/// is used rather than one so that a coincidental match is not a real risk.
bool hebrewRenders() {
  const sample = 'שבט עמודים';
  const notdef = '\uE000\uE001\uE002\uE003';
  final real = _textWidth(sample);
  final box = _textWidth(notdef);
  say(
    '  Hebrew probe: "$sample" is ${real.toStringAsFixed(1)}px wide, '
    'a notdef box is ${box.toStringAsFixed(1)}px '
    '${real == box ? '(NOT rendering)' : '(rendering)'}',
  );
  return real != box;
}

/// The width [text] comes out at in the app's default face.
double _textWidth(String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: const TextStyle(fontSize: 20)),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
