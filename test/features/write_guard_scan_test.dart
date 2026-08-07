import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/source_scan.dart';

/// The rule this file enforces: **a user-initiated write goes through
/// `guarded()` or `WriteGuard.run()`.**
///
/// `README.md` said the `unawaited_futures` lint kept new writes inside the
/// guard. It does not, and the claim was not merely optimistic — it was checked
/// and it is wrong in two of the three shapes this codebase writes in:
///
/// ```dart
/// onPressed: () => write(),        // not flagged  ← the dominant shape here
/// onPressed: () { write(); },      // not flagged
/// onPressed: () async { write(); } // flagged
/// ```
///
/// The lint only fires on an expression statement inside an **async** body, and
/// almost every write in this app is a sync arrow closure handed to `onPressed`,
/// `onChanged` or `onTap`. So the rule the README credits to the analyzer was in
/// fact held up by the author remembering it, which is this whole document's
/// subject.
///
/// **What it scans.** The write verbs are *derived*, not listed: every method on
/// `ProgressRepository` that is not a `get`/`watch`/`transaction`, every public
/// future on `LoggingService`, and every public future on a Riverpod `Notifier`
/// in `application/`. A verb list typed out here would go stale the first time
/// somebody added a setter; this one cannot.
///
/// **Receivers matter as much as verbs.** `remove`, `record`, `save`, `reset`
/// and `delete` are all writes on some controller *and* ordinary methods on a
/// `Set`, a `Map` or a `CrashLog`. So a call only counts when the receiver is
/// something a write comes out of: a local bound from `ref.read(…notifier)`,
/// `ref.read(progressRepositoryProvider)`, `ref.read(loggingServiceProvider)`,
/// a `BackupService`, or one of those reads inline.
///
/// **It is a speed bump, not a wall.** A helper that writes on behalf of callers
/// which all wrap it says so with `// write-guard: ok — <reason>`; there are two
/// such lines and each names its callers.
void main() {
  const escapeHatch = 'write-guard: ok';

  /// [source] with comments *and string literals* blanked, keeping every
  /// newline so line numbers survive.
  ///
  /// Strings matter here in a way they do not for the other guards: this one
  /// matches parentheses to find the enclosing call, and a lone `(` inside a
  /// `Text('(')` would throw the whole file's nesting out.
  String blanked(String source) {
    final out = StringBuffer();
    var i = 0;
    void skip(int to) {
      for (var k = i; k < to && k < source.length; k++) {
        out.write(source[k] == '\n' ? '\n' : ' ');
      }
      i = to;
    }

    while (i < source.length) {
      if (source.startsWith('/*', i)) {
        final end = source.indexOf('*/', i + 2);
        skip(end < 0 ? source.length : end + 2);
        continue;
      }
      if (source.startsWith('//', i)) {
        final end = source.indexOf('\n', i);
        skip(end < 0 ? source.length : end);
        continue;
      }
      final c = source[i];
      if (c == "'" || c == '"') {
        final triple = source.startsWith(c * 3, i);
        if (triple) {
          final end = source.indexOf(c * 3, i + 3);
          skip(end < 0 ? source.length : end + 3);
        } else {
          var j = i + 1;
          while (j < source.length && source[j] != c) {
            if (source[j] == r'\') j++;
            j++;
          }
          skip(j + 1);
        }
        continue;
      }
      out.write(c);
      i++;
    }
    return out.toString();
  }

  /// The methods that write, read out of the code that defines them.
  Set<String> writeVerbs() {
    final verbs = <String>{};
    void take(String path, {bool skipReads = false}) {
      final source = blanked(File(path).readAsStringSync());
      for (final m
          in RegExp(r'Future<[^>]*>\s+(\w+)\(').allMatches(source)) {
        final name = m.group(1)!;
        if (name.startsWith('_') || name == 'build') continue;
        if (skipReads &&
            (name.startsWith('get') ||
                name.startsWith('watch') ||
                name == 'transaction')) {
          continue;
        }
        verbs.add(name);
      }
    }

    take('lib/domain/repositories/progress_repository.dart', skipReads: true);
    take('lib/application/logging_service.dart');
    for (final path in dartSourcesUnder('lib/application')) {
      final source = blanked(File(path).readAsStringSync());
      if (!RegExp(r'class \w+ extends (Async)?Notifier<').hasMatch(source)) {
        continue;
      }
      take(path);
    }
    return verbs;
  }

  test('the verbs are derived from the code that defines them', () {
    final verbs = writeVerbs();
    // A handful of specific ones, so the derivation cannot quietly start
    // returning an empty set and pass.
    expect(verbs, containsAll(<String>['markDone', 'addEvent', 'setGoal',
      'setLayerConfig', 'removeBatch', 'setChazaraIntervals']));
    expect(verbs, isNot(contains('getEvents')));
    expect(verbs, isNot(contains('watchEvents')));
    expect(verbs.length, greaterThan(20));
  });

  test('every write under features/ is inside a guard', () {
    final verbs = writeVerbs().toList()..sort();
    final violations = <String>[];

    /// A read that yields something writes come out of.
    final writerRead = RegExp(r'(?:ref|container|_container)\s*\.\s*read\(\s*'
        r'(?:\w+\.notifier|progressRepositoryProvider|loggingServiceProvider)');

    for (final path in dartSourcesUnder('lib/features')) {
      final raw = File(path).readAsStringSync();
      final code = blanked(raw);
      // Lines carrying the escape hatch are read off the *raw* source, since
      // the marker lives in a comment.
      final excused = <int>{
        for (var i = 0; i < raw.split('\n').length; i++)
          if (raw.split('\n')[i].contains(escapeHatch)) i + 1,
      };

      // Locals bound from a writer — `final logger = ref.read(...)`, which is
      // the correct shape: capture before the await, then write inside the
      // guard.
      final writers = <String>{
        for (final m
            in RegExp(r'(?:final|var)\s+(\w+)\s*=\s*(?:await\s+)?([^;]+);',
                    dotAll: true)
                .allMatches(code))
          if (writerRead.hasMatch(m.group(2)!)) m.group(1)!,
        for (final m in RegExp(r'(?:final|var)\s+(\w+)\s*=\s*BackupService\(')
            .allMatches(code))
          m.group(1)!,
      };

      // What identifier opens each `(` — so an enclosing `guarded(` or
      // `guard.run(` can be recognised.
      final opener = <int, String>{};
      final open = <int>[];
      for (var i = 0; i < code.length; i++) {
        if (code[i] == '(') {
          open.add(i);
          final before = code.substring(i < 40 ? 0 : i - 40, i);
          opener[i] =
              RegExp(r'([A-Za-z_][\w.]*)$').firstMatch(before)?.group(1) ?? '';
        } else if (code[i] == ')' && open.isNotEmpty) {
          open.removeLast();
        }
      }

      final receiver = [
        ...writers,
        r'read\(\s*(?:\w+\.notifier|progressRepositoryProvider|'
            r'loggingServiceProvider)[^)]*\)',
        r'BackupService\([^)]*\)',
      ].join('|');
      final call = RegExp('(?:$receiver)'
          r'\s*\.\s*('
          '${verbs.join('|')}'
          r')\(');

      final depth = <int>[];
      for (var i = 0; i < code.length; i++) {
        if (code[i] == '(') {
          depth.add(i);
        } else if (code[i] == ')' && depth.isNotEmpty) {
          depth.removeLast();
        }
        final m = call.matchAsPrefix(code, i);
        if (m == null) continue;
        final guarded = depth.any((o) {
          final name = opener[o] ?? '';
          final last = name.split('.').last;
          return last == 'guarded' || last == 'run';
        });
        if (guarded) continue;
        // The call can span lines — `ref` on one, `.read(...)` on the next,
        // the verb on a third — so the marker counts wherever in it it sits.
        final line = '\n'.allMatches(code.substring(0, i)).length + 1;
        final lastLine = '\n'.allMatches(code.substring(0, m.end)).length + 1;
        if ([for (var l = line; l <= lastLine; l++) l].any(excused.contains)) {
          continue;
        }
        violations.add('$path:$line ${m.group(1)}');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'a write the user started must be awaited, reported and — on '
          'failure — recorded, and the lint does not catch these: '
          '`onPressed: () => write()` is a sync arrow closure and '
          '`unawaited_futures` only fires inside async bodies.\n\n'
          '${violations.join('\n')}\n\n'
          'If a helper is wrapped by every caller, mark the line '
          '`// $escapeHatch — <which callers>`.',
    );
  });
}
