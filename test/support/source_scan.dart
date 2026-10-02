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
  // Set when a hatch comment excused the statement the previous line opened.
  // Carried out of the loop so the join below can drop the leftover.
  final hatched = <int>{};
  // Every line carrying a hatch, so the join can spot a statement that opened
  // before the hatch and continued after it.
  final hatchLines = <int>{};
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.contains(escapeHatch)) {
      // A standalone hatch line — the only content of the line is the comment —
      // excuses the statement above it, which is where the shape usually is
      // (a trailing `// log-pass: ok` on the signature line is handled below,
      // where the comment is still attached to code).
      // Mark the line the hatch sits *within*: the last one emitted if it left
      // brackets open, and recorded so the join can drop the whole statement
      // when the statement continues below this line.
      hatchLines.add(i + 1);
      if (out.isNotEmpty && _bracketBalance(out.last.text) > 0) {
        hatched.add(out.last.line);
      }
      continue;
    }
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
    final line = _commentStart(text);
    if (line >= 0) {
      // A trailing hatch — `final x = f(); // day-math: ok — why` — excuses the
      // statement it is written on. The hatch's presence is checked on the raw
      // line above, so reaching here means this line was already excluded.
      text = text.substring(0, line);
    }
    if (text.trim().isEmpty) continue;
    out.add((line: i + 1, text: text));
  }
  return _joinContinuations(out, hatched: hatched, hatchLines: hatchLines);
}

/// Fold a signature the formatter split across lines back into one.
///
/// **Why this is here.** Every guard built on [codeLines] asks whether a source
/// file contains some *shape* — a parameter type, a call, a declaration — and
/// the shape is frequently longer than one line once `dart format` is allowed to
/// run. `List<LearningEvent> get eventsProvider` became
/// `final eventsProvider = StreamProvider<List<LearningEvent>>((ref) {` with
/// the generic on the next line, and a line-at-a-time guard then saw a fragment
/// and reported a violation in a file that is fine.
///
/// A line continues the previous one when it leaves brackets open or ends on an
/// operator, up to a bounded run. The result is the smallest unit a shape can
/// actually live in, which is the thing the guards mean to ask about.
List<CodeLine> _joinContinuations(
  List<CodeLine> lines, {
  required Set<int> hatched,
  required Set<int> hatchLines,
}) {
  /// How far a run may continue before we stop joining.
  ///
  /// Two, and no more. The formatter wraps a shape — an argument list, a lambda
  /// argument — over a line or two and closes it; a run that is still open after
  /// that is not a wrapped shape but a **type body**, and joining a type body
  /// turns every statement inside it into one string, which answers a
  /// per-occurrence question once. Twelve looked generous and was wrong: a short
  /// class still fits inside twelve lines.
  const maxJoinRun = 2;
  final out = <CodeLine>[];
  for (final line in lines) {
    if (out.isEmpty) {
      out.add(line);
      continue;
    }
    final previous = out.removeLast();
    if (hatched.contains(previous.line)) {
      out.add(line);
      continue;
    }
    // A line continues the previous one when it left brackets open **or** ended
    // on an operator: `() async =>` opens nothing and still owns the line below
    // it, which is exactly how the formatter wraps a lambda passed as an
    // argument. Without the second clause, a class joined into one "line" and a
    // guard asking "how many calls parse a backup" answered 1 instead of 2.
    final open =
        _bracketBalance(previous.text) > 0 || _endsWithOperator(previous.text);
    // **Bounded, and deliberately so.** A class body's `{` is open for hundreds
    // of lines, so "join while unbalanced" would hand a guard one eight-hundred
    // line string and answer its question once instead of per occurrence — the
    // call-count guard read 1 where there are 2. What these guards ask about
    // lives in a signature or an argument list, so the join follows a statement
    // and stops after a handful of lines rather than after an entire type.
    if (open && line.line - previous.line <= maxJoinRun) {
      // A hatch anywhere between this statement's first line and this one means
      // the statement as a whole is excused, however it is wrapped.
      final insideHatch = hatchLines.any(
        (h) => h > previous.line && h <= line.line,
      );
      if (insideHatch) {
        hatched.add(previous.line);
        out.add(line);
        continue;
      }
      out.add((
        line: previous.line,
        text: '${previous.text} ${line.text.trim()}',
      ));
    } else {
      out.add(previous);
      out.add(line);
    }
  }
  return out;
}

/// Index of the `//` that starts a comment in [source], or -1.
///
/// Skips string literals, so a `//` inside `'https://…'` is not mistaken for a
/// comment — which would silently truncate the rest of a line and, in a guard,
/// hide the very shape it was looking for.
int _commentStart(String source) {
  // `null` rather than an empty-string sentinel: a sentinel that tests
  // `isNotEmpty` is a sentinel that a NUL byte in the source can impersonate,
  // and a guard whose comment-stripper can be fooled by one byte is a guard
  // that quietly stops seeing the thing it watches for.
  String? quote;
  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    if (quote != null) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
    } else if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
      return i;
    }
  }
  return -1;
}

/// Whether [source] ends on something that clearly continues below it.
bool _endsWithOperator(String source) {
  final trimmed = source.trimRight();
  if (trimmed.isEmpty) return false;
  const operators = [
    '=>',
    '?',
    ':',
    ',',
    '=',
    '+',
    '-',
    '*',
    '/',
    '&',
    '|',
    '.',
  ];
  for (final op in operators) {
    if (trimmed.endsWith(op)) return true;
  }
  return false;
}

/// Net `(`, `[` and `{` count, ignoring anything inside a string literal.
int _bracketBalance(String source) {
  var depth = 0;
  String? quote;
  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    if (quote != null) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
    } else if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
    }
  }
  return depth;
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
