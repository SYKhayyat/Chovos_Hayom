import 'dart:io';

/// Reading the codebase as text, for the guards that fail the build on the
/// *shape* of a mistake rather than on its consequences.
///
/// Six files do this — day math, log passes, layer roles, report shape,
/// repository doubles, and now the node picker — and five of them had written
/// the same two helpers out for themselves: a comment stripper so the doc
/// comment explaining a ban does not trip it, and a `lib/` walk that skips
/// generated code. Byte-identical in four of them.
///
/// The fifth had drifted, in the way this whole class of duplication drifts:
/// `layer_role_guard_test.dart`'s copy silently **dropped the escape hatch**.
/// Every other guard in the suite says, in its own docstring, that it is a
/// speed bump and not a wall — a line that genuinely needs the banned shape
/// marks itself and is skipped. That one was a wall, and nothing said so. Which
/// is the point of the finding these guards were written to close: a rule
/// stated five times is a rule with five slightly different meanings.

/// One line of real code: what it says, with comments removed, and where it is.
typedef CodeLine = ({int line, String text});

/// [source] with comments stripped and blank lines dropped.
///
/// Comments go first so that the doc comment *explaining* a ban — which by
/// definition quotes the shape being banned — does not trip it. The escape
/// hatch is read from the raw line before anything is stripped, so it works
/// whether it is written as a trailing comment or inside one.
///
/// [escapeHatch] is the marker a line uses to excuse itself, e.g.
/// `day-math: ok`. Every guard has one, and a guard without one is a rule
/// nobody can disagree with in a code review — which is not the same thing as
/// a rule nobody should break.
List<CodeLine> codeLines(String source, {required String escapeHatch}) {
  final out = <CodeLine>[];
  var inBlock = false;
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.contains(escapeHatch)) continue;
    var text = raw;
    if (inBlock) {
      final end = text.indexOf('*/');
      if (end < 0) continue;
      text = text.substring(end + 2);
      inBlock = false;
    }
    final block = text.indexOf('/*');
    if (block >= 0) {
      final end = text.indexOf('*/', block + 2);
      if (end < 0) {
        text = text.substring(0, block);
        inBlock = true;
      } else {
        text = text.substring(0, block) + text.substring(end + 2);
      }
    }
    final line = text.indexOf('//');
    if (line >= 0) text = text.substring(0, line);
    if (text.trim().isEmpty) continue;
    out.add((line: i + 1, text: text));
  }
  return out;
}

/// Every hand-written Dart file under [root], as forward-slashed paths.
///
/// Generated code is excluded and named as such: the localizations table and
/// the `.g.dart` files are not ours to hold to any of these rules, and a guard
/// that scanned them would be reporting on a code generator's habits.
Iterable<String> dartSourcesUnder([String root = 'lib']) sync* {
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path.contains('/l10n/generated/') || path.endsWith('.g.dart')) continue;
    yield path;
  }
}
