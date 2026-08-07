import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_scan.dart';

/// The rule this file enforces: **there is one `ProgressRepository`, and the
/// tests run against it.**
///
/// `InMemoryProgressRepository` was 344 lines — a fifth larger than the real
/// repository it doubled — and 38 test files used it. Its docstring made two
/// claims. The first, *"no native dependencies"*, was already untrue in
/// practice: three suites ran `AppDatabase(NativeDatabase.memory())` under
/// plain `flutter_test`, in CI, in milliseconds. The second, *"a faithful
/// implementation rather than a stub"*, is the one that cannot be kept, because
/// faithfulness is not a property you write once — and it had already drifted
/// on four axes, each of which is now a test in
/// `test/data/drift_progress_repository_test.dart` that the double passed.
///
/// The docstring was itself honest that this class of drift is why the
/// cross-profile import collision could not fail in any test that used it. That
/// is the argument for not having a second implementation at all, and this is
/// the argument written where it can fail.
///
/// It bans three shapes:
///
/// * a second `implements`/`extends ProgressRepository` under `test/`, other
///   than the failure-injecting wrapper that has to refuse a write on demand —
///   which delegates every other member, so it cannot drift;
/// * `NativeDatabase.memory()` outside `memory_database.dart`, because a
///   database opened by hand is one without the `closeStreamsSynchronously`
///   that keeps a drift query stream from leaving a pending timer, and without
///   the `addTearDown` that closes it;
/// * `watchX(...).first` anywhere — a one-shot read dressed as a live query.
///   Eleven production call sites wrote it before `getCustomNodes` and its two
///   siblings existed, and it does not resolve at all under `flutter_test`'s
///   fake clock, so any widget test that reached one hung rather than failed.
void main() {
  const wrapper = 'test/support/failing_progress_repository.dart';
  const home = 'test/support/memory_database.dart';

  const bans = <({String why, String pattern, String sample, String? allow})>[
    (
      why: 'is a second implementation of ProgressRepository — use '
          'memoryRepository(), or delegate to it as '
          'FailingProgressRepository does',
      pattern: r'(implements|extends)\s+ProgressRepository\b',
      sample: 'class InMemoryProgressRepository implements ProgressRepository {',
      allow: wrapper,
    ),
    (
      why: 'opens a database by hand — use memoryDatabase(), which sets '
          'closeStreamsSynchronously and registers the close',
      pattern: r'NativeDatabase\.memory\(\)',
      sample: 'final db = AppDatabase(NativeDatabase.memory());',
      allow: home,
    ),
    (
      why: 'reads a one-shot value off a live query stream — use the getX() '
          'half of the interface',
      pattern: r'\.watch[A-Z]\w*\([^)]*\)\.first',
      sample: 'final nodes = await repo.watchCustomNodes(profileId).first;',
      allow: null,
    ),
  ];

  const escapeHatch = 'repo-double: ok';

  test('the regexes actually match the shapes they ban', () {
    // The failure mode of every source-scanning check ever written is quietly
    // matching nothing, so each ban carries the line it exists to catch.
    for (final ban in bans) {
      expect(RegExp(ban.pattern).hasMatch(ban.sample), isTrue,
          reason: 'the pattern for "${ban.why}" no longer matches its own '
              'sample, so it is guarding nothing');
    }
  });

  test('no second ProgressRepository, and no database opened by hand', () {
    final violations = <String>[];

    for (final root in ['lib', 'test']) {
      for (final path in dartSourcesUnder(root)) {
        // This file quotes every shape it bans, so that the patterns cannot rot
        // into matching nothing. It cannot also be subject to them.
        if (path.endsWith('repository_double_guard_test.dart')) continue;
        // The one file allowed to name the real repository as its supertype is
        // the interface itself, and the one allowed to implement it is the
        // production class.
        final isProduction =
            path == 'lib/data/repositories/drift_progress_repository.dart';

        for (final line in codeLines(File(path).readAsStringSync(),
            escapeHatch: escapeHatch)) {
          for (final ban in bans) {
            if (path == ban.allow) continue;
            if (isProduction && ban.allow == wrapper) continue;
            if (!RegExp(ban.pattern).hasMatch(line.text)) continue;
            violations.add('$path:${line.line} ${ban.why}\n'
                '    ${line.text.trim()}');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'The tests run against the real repository over an in-memory '
          'SQLite database.\n\n${violations.join('\n')}\n\n'
          'If a line genuinely needs one of these, mark it '
          '`// $escapeHatch — <reason>`.',
    );
  });

  test('every test that needs a repository can get one from one place', () {
    // A weaker but load-bearing claim: the helper is actually used. If this
    // ever reads zero, the suite has quietly grown a different way of getting a
    // repository and the ban above is guarding an empty room.
    var users = 0;
    for (final entity in Directory('test').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.readAsStringSync().contains('memoryRepository()')) users++;
    }
    expect(users, greaterThan(20),
        reason: 'memory_database.dart is how a test gets a repository');
  });
}
