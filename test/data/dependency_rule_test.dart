import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/source_scan.dart';

/// The rule this file enforces: **only the composition roots reach into
/// `data/`.**
///
/// `ARCHITECTURE.md` §3 states the layering — `domain/` is pure Dart, `data/`
/// depends on `domain/`, and `application/` and `features/` talk to `data/`
/// through the two repository interfaces. Stated, and until now not enforced.
///
/// It is the answer to a question this codebase was asked and had no way to
/// settle: *is `ProgressRepository` worth twenty-four members and 109 lines for
/// one production implementation and one delegating test double?* Counting
/// members cannot answer it, and neither can taste. What the interface actually
/// buys is this line — without it, the backup service, the logging service, the
/// customisations reader, the providers and one screen would each import
/// `data/drift/`, and `drift` would become a compile-time dependency of the
/// layer that holds the app's rules. That is worth 109 lines. Now it is worth
/// 109 lines *and* it fails the build when somebody stops believing it.
///
/// Two files are exempt and both are composition roots: `providers.dart`, which
/// is where the concrete implementations are handed to Riverpod, and `main.dart`,
/// which supplies the platform preference store. A third name on this list is a
/// layering decision somebody is making, which is the point of it being a list.
void main() {
  const escapeHatch = 'layering: ok';
  const roots = {
    'lib/application/providers.dart': 'the composition root: where the concrete '
        'repositories are handed to Riverpod',
    'lib/main.dart': 'supplies the platform preference store at startup',
  };

  final dataImport = RegExp(r"""import\s+'[^']*data/""");

  test('the regex matches the shape it bans', () {
    expect(dataImport.hasMatch("import '../data/drift/database.dart';"), isTrue);
    expect(dataImport.hasMatch("import '../domain/entities/layer.dart';"),
        isFalse);
  });

  test('every root named here still exists', () {
    for (final root in roots.keys) {
      expect(File(root).existsSync(), isTrue,
          reason: '$root is exempt from the layering rule and has moved');
    }
  });

  test('nothing outside data/ imports data/, except the roots', () {
    final violations = <String>[];

    for (final path in dartSourcesUnder()) {
      if (path.startsWith('lib/data/')) continue;
      if (roots.containsKey(path)) continue;
      for (final line
          in codeLines(File(path).readAsStringSync(), escapeHatch: escapeHatch)) {
        if (!dataImport.hasMatch(line.text)) continue;
        violations.add('$path:${line.line}\n    ${line.text.trim()}');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'talk to storage through ProgressRepository or CatalogRepository. '
          'An import of data/ from application/ or features/ makes drift a '
          'compile-time dependency of the layer holding the app\'s '
          'rules.\n\n${violations.join('\n')}',
    );
  });

  test('and domain/ imports neither data/ nor Flutter', () {
    // The stronger half of the same rule, and the one the whole derive engine
    // rests on: `domain/` is plain Dart, so every fold, roll-up and predictor in
    // it can be tested without a widget binding — which is why those suites run
    // in milliseconds.
    final violations = <String>[];
    final flutter = RegExp(r"""import\s+'package:(flutter|flutter_riverpod|drift)/""");

    for (final path in dartSourcesUnder('lib/domain')) {
      for (final line
          in codeLines(File(path).readAsStringSync(), escapeHatch: escapeHatch)) {
        if (dataImport.hasMatch(line.text) || flutter.hasMatch(line.text)) {
          violations.add('$path:${line.line}\n    ${line.text.trim()}');
        }
      }
    }

    expect(violations, isEmpty,
        reason: 'domain/ is pure Dart: no Flutter, no Riverpod, no Drift, no '
            'data/.\n\n${violations.join('\n')}');
  });
}
