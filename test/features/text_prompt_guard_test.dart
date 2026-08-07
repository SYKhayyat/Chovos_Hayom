import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/source_scan.dart';

/// The rule this file enforces: **a dialog does not own a
/// `TextEditingController` unless it is the one written to own one.**
///
/// `text_prompt.dart` exists because four dialogs made a controller beside
/// `showDialog` and disposed it as soon as the await returned. That is wrong,
/// and quietly: the future completes when the route is *popped*, not when it is
/// gone, and the exit animation renders one more frame against a `TextField`
/// that still holds the controller. The next frame throws.
///
/// Having a file for it did not stop two more dialogs hand-rolling it, and the
/// reason is worth keeping: the shared prompt took **one field**, and both of
/// them wanted two. So they each grew a `State`, a pair of controllers, a
/// `dispose`, and a paragraph explaining the bug — three copies of one piece of
/// knowledge, two of them out of reach of the file that is supposed to hold it.
/// It takes a list of fields and a validator now, so there is nothing left to
/// hand-roll, which is the only version of "don't hand-roll this" that holds.
///
/// The shape of the ban is per-*file* rather than per-line, because that is the
/// shape of the mistake: a file that builds an `AlertDialog` and also
/// constructs a `TextEditingController` is a dialog owning its own text state.
/// Screens and sheets own controllers all the time and should — a form is not a
/// dialog, and its controller dies with the route rather than one frame before
/// it.
void main() {
  const escapeHatch = 'text-prompt: ok';
  const home = 'lib/features/common/text_prompt.dart';

  const dialog = r'\bAlertDialog\(';
  const controller = r'\bTextEditingController\(';

  test('the regexes actually match the shapes they ban', () {
    expect(RegExp(dialog).hasMatch('      builder: (_) => AlertDialog('), isTrue);
    expect(
        RegExp(controller).hasMatch(
            '  late final TextEditingController _name = '
            'TextEditingController(text: x);'),
        isTrue);
    // And do not fire on the ordinary form, which is a screen with fields on it
    // rather than a dialog.
    expect(RegExp(dialog).hasMatch('  final _name = TextEditingController();'),
        isFalse);
  });

  test('the prompt still exists to be the exception', () {
    final source = File(home).readAsStringSync();
    expect(source.contains('TextEditingController('), isTrue,
        reason: '$home is excused because it is where the controllers live; if '
            'it stopped holding any, this guard is excusing nothing');
  });

  test('no dialog under lib/ owns its own text state', () {
    final violations = <String>[];

    for (final path in dartSourcesUnder()) {
      if (path == home) continue;
      final lines =
          codeLines(File(path).readAsStringSync(), escapeHatch: escapeHatch);
      final source = lines.map((l) => l.text).join('\n');
      if (!RegExp(dialog).hasMatch(source)) continue;
      for (final line in lines) {
        if (!RegExp(controller).hasMatch(line.text)) continue;
        violations.add('$path:${line.line}\n    ${line.text.trim()}');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'this file builds an AlertDialog and constructs a '
          'TextEditingController, which is the shape that throws "used after '
          'being disposed" one frame after the dialog closes. Use '
          'promptForFields — it takes as many fields as you have and a '
          'validator that keeps the dialog open.\n\n${violations.join('\n')}\n\n'
          'If a line genuinely needs the shape, mark it '
          '`// $escapeHatch — <reason>`.',
    );
  });
}
