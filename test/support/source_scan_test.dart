import 'package:flutter_test/flutter_test.dart';

import 'source_scan.dart';

/// [codeLines] is shared by a dozen source guards, and the two changes made for
/// the formatter broke three of them before anything failed loudly. So the
/// behaviour it needs to have is stated here rather than inferred from whoever
/// notices next.
void main() {
  group('codeLines', () {
    test('comments are not code', () {
      final scanned = codeLines('''
/// A doc comment with 86400000 in it.
// A line comment too.
final real = 86400000;
''', escapeHatch: 'x: ok');
      expect(scanned.map((l) => l.text.trim()), ['final real = 86400000;']);
    });

    test('a // inside a string is not a comment', () {
      // Truncating here would hide the code after the URL, which is the code a
      // guard is looking for.
      final scanned = codeLines(
        "final u = Uri.parse('https://example.test/x'); final after = 1;",
        escapeHatch: 'x: ok',
      );
      expect(scanned.single.text, contains('final after = 1;'));
    });

    test('a shape split across lines is seen whole', () {
      // What the formatter does to `StreamProvider<List<LearningEvent>>((ref)`.
      final scanned = codeLines('''
final eventsProvider = StreamProvider<List<LearningEvent>>((ref) {
  return repo.watch();
});
''', escapeHatch: 'x: ok');
      expect(
        scanned.first.text,
        contains(RegExp(r'StreamProvider<List<LearningEvent>>')),
      );
    });

    test('a line ending on => continues', () {
      // A lambda argument: opens no bracket and still owns the next line.
      final scanned = codeLines('''
final ok = await guard.run(
  () async =>
      outcome = await BackupService.parse(payload),
  what: 'x',
);
''', escapeHatch: 'x: ok');
      expect(
        scanned.any((l) => l.text.contains('BackupService.parse')),
        isTrue,
      );
    });

    test('a class body is not absorbed whole', () {
      // The bug that made a call-count guard read 1 where there were 2.
      final scanned = codeLines('''
class Widget1 {
  final a = 1;
  void f() {
    first();
    second();
  }
}
''', escapeHatch: 'x: ok');
      expect(
        scanned.where((l) => l.text.contains('first()')).length,
        1,
        reason: 'each statement must remain separately findable',
      );
      expect(scanned.length, greaterThan(1));
    });

    test('a hatch excuses the statement it sits inside', () {
      // Not just its own line: the shape is on the line above the comment.
      final scanned = codeLines('''
final events = StreamProvider<List<Event>>((ref) {
  // x: ok — the log's own carrier
  return repo.watch();
});
''', escapeHatch: 'x: ok');
      expect(scanned.any((l) => l.text.contains('StreamProvider')), isFalse);
    });

    test('a trailing hatch excuses its own line', () {
      final scanned = codeLines(
        'final x = 1; // x: ok — deliberate',
        escapeHatch: 'x: ok',
      );
      expect(scanned, isEmpty);
    });

    test('a doc comment cannot impersonate a hatch', () {
      // The hatch check runs on the raw line, before comments are stripped, so
      // a doc comment quoting the marker must not exempt anything.
      final scanned = codeLines('''
/// See the `x: ok` hatch.
final real = 1;
''', escapeHatch: 'x: ok');
      expect(scanned.single.text.trim(), 'final real = 1;');
    });
  });
}
