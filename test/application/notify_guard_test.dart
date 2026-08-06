import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The three rules that keep the provider graph from notifying everything about
/// everything again — enforced, rather than stated.
///
/// This exists because the codebase already *had* the rules. `sorting.dart`
/// spends ten lines condemning conditional watches; `dashboard_screen.dart` says
/// "watched unconditionally, so this widget's set of subscriptions is the same
/// on every build" and then watched conditionally sixty-eight lines below it, in
/// the same `build` method. A comment cannot fail CI, so it does not stop the
/// next one. These do:
///
/// 1. **Every provider family is `autoDispose`.** A family without it keeps one
///    element per argument for the life of the app, and every one of them
///    re-derives on every change — for screens closed an hour ago.
/// 2. **Nobody watches the whole `SettingsState` to read one field of it.**
///    Thirteen screens did, so changing the backup interval rebuilt the
///    calculator, cycles, goals, the journal, siyumim, stats and the unit grid.
/// 3. **Every value type a provider hands out compares all of its fields.** The
///    `==`s are the reason any of the above works, and the way they rot is a
///    field added to the class and not to the comparison — which is silent, and
///    shows up as a screen that has quietly stopped updating.
void main() {
  List<File> dartFiles(String root) => [
        for (final e in Directory(root).listSync(recursive: true))
          if (e is File &&
              e.path.endsWith('.dart') &&
              !e.path.replaceAll(r'\', '/').contains('/l10n/generated/') &&
              !e.path.endsWith('.g.dart'))
            e,
      ];

  String posix(File f) => f.path.replaceAll(r'\', '/');

  test('every provider family is autoDispose', () {
    // `Provider.family<…>` — as opposed to `Provider.autoDispose.family<…>`.
    final kept = RegExp(r'(?<!autoDispose\.)family<');
    final violations = <String>[];

    for (final file in dartFiles('lib')) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//') || line.trimLeft().startsWith('///')) {
          continue;
        }
        if (!line.contains('family<')) continue;
        if (!kept.hasMatch(line)) continue;
        violations.add('${posix(file)}:${i + 1}\n    ${line.trim()}');
      }
    }

    expect(violations, isEmpty,
        reason: 'A Riverpod family keeps one element per argument alive for the '
            'life of the container. Use `Provider.autoDispose.family`, or if an '
            'element genuinely must outlive its listeners, say so with '
            '`ref.keepAlive()` inside it rather than by dropping the '
            'modifier.\n\n${violations.join('\n')}');
  });

  test('nothing watches the whole SettingsState to read one field', () {
    /// The one place that legitimately wants the whole object: the Settings
    /// screen renders every field.
    ///
    /// `backup_status.dart` was here too, on the grounds that it reads two
    /// fields and is itself watched through a `.select`. That was the wrong test
    /// — a `.select` downstream stops the *rebuild*, not the *re-derivation*,
    /// and this provider's re-derivation walked the event log. Two fields out of
    /// nine is exactly the case `.select` exists for, so it now uses two of them
    /// and is off the list.
    const allowed = {
      'lib/features/settings/settings_screen.dart',
    };
    // `ref.watch(settingsProvider)` with no `.select` before the closing paren.
    final unselected = RegExp(r'watch\(\s*settingsProvider\s*\)');
    final violations = <String>[];

    for (final file in dartFiles('lib')) {
      if (allowed.contains(posix(file))) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!unselected.hasMatch(lines[i])) continue;
        violations.add('${posix(file)}:${i + 1}\n    ${lines[i].trim()}');
      }
    }

    expect(violations, isEmpty,
        reason: 'Every setter allocates a new SettingsState, so watching the '
            'whole object means rebuilding on a change to a field you do not '
            'read. Use `settingsProvider.select((s) => s.theOneField)`.'
            '\n\n${violations.join('\n')}');
  });

  group('value types compare all of their fields', () {
    /// The types a provider hands straight out, and where they live. If a
    /// provider starts returning a new type, it belongs on this list — which is
    /// itself checked below, so the list cannot silently name a class that has
    /// been renamed or deleted out from under it.
    const types = <String, String>{
      'ProgressNode': 'lib/domain/entities/progress_node.dart',
      'SeriesPoint': 'lib/domain/usecases/progress_series.dart',
      'BackupStatus': 'lib/domain/usecases/backup_reminder.dart',
      'GoalStatus': 'lib/domain/usecases/goal_evaluator.dart',
      'StatsSummary': 'lib/application/stats.dart',
      'SettingsState': 'lib/application/settings.dart',
      'SortConfig': 'lib/application/sorting.dart',
      'SessionTimerState': 'lib/application/session_timer.dart',
    };

    /// The body of `class [name]` in [source], by brace matching — so fields of
    /// a *neighbouring* class in the same file are not attributed to this one.
    String classBody(String source, String name) {
      final start = RegExp('class\\s+$name\\b').firstMatch(source);
      expect(start, isNotNull,
          reason: 'this guard names a class that no longer exists');
      var i = source.indexOf('{', start!.end);
      final open = i;
      var depth = 0;
      for (; i < source.length; i++) {
        if (source[i] == '{') depth++;
        if (source[i] == '}') {
          depth--;
          if (depth == 0) return source.substring(open + 1, i);
        }
      }
      fail('unbalanced braces in class $name');
    }

    for (final entry in types.entries) {
      test(entry.key, () {
        final body = classBody(File(entry.value).readAsStringSync(), entry.key);

        // Instance fields, at the class's own indent level. Comments are
        // stripped first so a doc comment mentioning `final` cannot invent one.
        //
        // `final x = <something>;` is deliberately not matched: an instance
        // field with an initializer cannot reference `this`, so it holds the
        // same value in every instance and is never part of identity.
        final code = body
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        final fields = RegExp(r'^\s{2}final\s+[\w<>,\s?]+?\s(\w+);',
                multiLine: true)
            .allMatches(code)
            .map((m) => m.group(1)!)
            .toList();
        expect(fields, isNotEmpty,
            reason: 'no fields found — the field regex has stopped matching, '
                'which would make this guard silently vacuous');

        final equals = RegExp(r'bool operator ==\(Object other\) =>(.*?);',
                dotAll: true)
            .firstMatch(code);
        expect(equals, isNotNull,
            reason: '${entry.key} is handed out by a provider and has no '
                'operator ==, so every rebuild of it notifies unconditionally');

        final compared = equals!.group(1)!;
        final missing = [
          for (final f in fields)
            if (!RegExp('\\b$f\\b').hasMatch(compared)) f,
        ];
        expect(missing, isEmpty,
            reason: '${entry.key}.operator == ignores ${missing.join(', ')}. '
                'A field left out of the comparison is a change the UI will '
                'never hear about — the failure mode is a screen that has '
                'quietly stopped updating, which no other test looks for.');
      });
    }
  });
}
