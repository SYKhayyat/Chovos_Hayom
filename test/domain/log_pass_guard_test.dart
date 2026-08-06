import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The rule this file enforces: **the event log is folded, and then questions
/// are asked of the folds — not of the log.**
///
/// That rule was already written down. `fold_log.dart` opens by explaining that
/// chazara scheduling, the progress line, siyumim and the grid's detail dots
/// each used to re-fold the whole log to recover one number, "five ordered
/// passes where one will do", and that folding once "is what keeps a tap on a
/// daf cheap for a user with years of history". Two files away, `statsProvider`
/// held that fold and then made five more passes over the list it came from;
/// `goalStatusProvider` made one more per goal; the dashboard made one more for
/// a banner. A comment cannot fail CI, so it did not stop any of them.
///
/// This does, by banning the parameter that makes a second pass typable: a
/// function taking the whole log. The allowlist below is the complete set of
/// things that legitimately consume it, one per *axis* — and the reason each is
/// its own axis is written next to it, because "add another one" is exactly the
/// move this is here to slow down.
///
/// `log_pass_count_test.dart` is the other half and the stronger one: it counts
/// actual passes through a live provider graph, so a walk that evades the regex
/// still has to get past a number.
void main() {
  /// The files entitled to take `Iterable<LearningEvent>`, and why each is a
  /// question no other file's answer can be derived from.
  const allowed = <String, String>{
    'lib/domain/usecases/fold_log.dart':
        'membership per unit — what is learned *now*',
    'lib/domain/usecases/log_activity.dart':
        'the log by calendar day — what happened, and when',
    'lib/domain/usecases/batch_history.dart':
        'grouping by batch id, for the durable undo list',
    'lib/domain/usecases/unit_history.dart':
        'one unit\'s own events, in order, for its details sheet',
    'lib/domain/usecases/backup_reminder.dart':
        'distinct units touched since an *instant*, keyed on loggedAt — a '
            'boundary no day index can answer',
    'lib/application/backup_service.dart':
        'serialising the log to a file, which is the log itself and not a '
            'question about it',
    'lib/application/logging_service.dart': 'writing events, not reading them',
  };

  /// A parameter (or local) typed as the whole log. `List<LearningEvent>` and
  /// `Iterable<LearningEvent>` both, because either one is a full pass waiting
  /// to happen.
  final logParameter = RegExp(r'(Iterable|List)<LearningEvent>');

  const escapeHatch = 'log-pass: ok';

  List<({int line, String text})> codeLines(String source) {
    final out = <({int line, String text})>[];
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

  test('the pattern still matches the shape it bans', () {
    // The failure mode of every source-scanning check is quietly matching
    // nothing, so it is asserted against the line it exists to catch.
    expect(
        logParameter.hasMatch(
            'static double averagePerDay(Iterable<LearningEvent> events, {'),
        isTrue);
    expect(logParameter.hasMatch('final events = ref.watch(eventsProvider);'),
        isFalse,
        reason: 'watching the log is not the ban — taking it is');
  });

  test('every file on the allowlist exists and still takes the log', () {
    // An allowlist that has drifted off the files it names is an allowlist that
    // has quietly stopped meaning anything.
    for (final entry in allowed.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} is gone');
      expect(
          codeLines(file.readAsStringSync())
              .any((l) => logParameter.hasMatch(l.text)),
          isTrue,
          reason: '${entry.key} is allowed to take the whole log for '
              '"${entry.value}" and no longer does — drop it from the list');
    }
  });

  test('nothing else in lib/ takes the whole event log', () {
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.contains('/l10n/generated/') || path.endsWith('.g.dart')) {
        continue;
      }
      if (allowed.containsKey(path)) continue;
      // The repository layer is the log's own boundary: its interface and its
      // implementation are what a `List<LearningEvent>` comes *out of*.
      if (path == 'lib/domain/repositories/progress_repository.dart' ||
          path == 'lib/data/repositories/drift_progress_repository.dart') {
        continue;
      }

      for (final line in codeLines(entity.readAsStringSync())) {
        if (!logParameter.hasMatch(line.text)) continue;
        violations.add('$path:${line.line}\n    ${line.text.trim()}');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'A function that takes the whole event log walks the whole event '
          'log, and it runs once per caller rather than once per change. Ask '
          'LogFold (what is learned now) or LogActivity (what happened, and '
          'when) instead. If the question is genuinely a new axis over the raw '
          'log, add the file to the allowlist in this test with the reason, or '
          'mark the line `// $escapeHatch — <reason>`.\n\n'
          '${violations.join('\n')}',
    );
  });
}
