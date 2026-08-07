import 'dart:io';

import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rules that keep the forest invariant load-bearing rather than incidental.
///
/// `catalog_forest_test.dart` asserts that [Catalog] repairs a broken tree.
/// This file guards the two ways that stops mattering, both of which are silent:
///
/// 1. **The repair is removed.** Eight walks across the app assume it now, and
///    two of them (`BulkHistoryScreen._commonAncestor`,
///    `CatalogEditor.cloneStructure`) have no visited-set of their own — the
///    first loops forever building a list, the second overflows the stack.
///    Neither fails a test that does not feed it a loop, so the invariant has to
///    be asserted from outside its own file, against a `Catalog` built the way
///    production builds one.
///
/// 2. **A second cycle check grows back.** `BackupValidator` used to carry one,
///    justified by a crash that did not exist, and it needed a map of the entire
///    bundled catalog (`knownParents`) threaded through the settings screen on
///    every import in order to see the case that mattered. It was deleted
///    because the invariant is wider — it also covers the loops the node editor
///    and the clone can create with no file involved. A check in the importer is
///    a second answer to a question that has one, and the first sign of it is
///    the parameter coming back.
///
/// Each ban carries a sample of the shape it must catch, so the guard cannot rot
/// into a regex that matches nothing — which is how every source-scanning check
/// dies. Verified by feeding it violations, not by assuming.
void main() {
  const bans = <({String why, String pattern, String sample})>[
    (
      why: 'threads a parent map into the importer again — that map existed '
          'only to feed the deleted cycle check, and Catalog needs nothing '
          'from the caller to keep its promise',
      pattern: r'\bknownParents\b',
      sample: '    Map<String, String?> knownParents = const {},',
    ),
    (
      why: 'is a second opinion about whether the catalog can loop — '
          'Catalog._asForest is the answer, and two answers is how the '
          'app came to have six visited-sets and two infinite loops',
      pattern: r'''(is its own ancestor|contains a loop|hierarchy contains)''',
      sample: r"      throw const BackupFormatException('…contains a loop.');",
    ),
  ];

  test('the regexes actually match the shapes they ban', () {
    for (final ban in bans) {
      expect(RegExp(ban.pattern).hasMatch(ban.sample), isTrue,
          reason: 'the pattern for "${ban.why}" no longer matches its own '
              'sample, so it is guarding nothing');
    }
  });

  test('no second cycle check, and no parent map to feed one', () {
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.contains('/l10n/generated/') || path.endsWith('.g.dart')) {
        continue;
      }
      // The invariant's own file is the one place entitled to reason about
      // loops; it is where the single answer lives.
      if (path.endsWith('lib/domain/entities/catalog.dart')) continue;

      final lines = entity.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final text = lines[i];
        if (text.trimLeft().startsWith('//') ||
            text.trimLeft().startsWith('///')) {
          continue;
        }
        for (final ban in bans) {
          if (RegExp(ban.pattern).hasMatch(text)) {
            violations.add('$path:${i + 1} ${ban.why}\n    ${text.trim()}');
          }
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'the forest invariant has grown a rival:\n'
            '${violations.join('\n')}');
  });

  test('the invariant holds for a catalog built the way the app builds one', () {
    // Not a restatement of `catalog_forest_test.dart`: that file constructs
    // `Catalog` directly. This one goes through the same overlay the merged
    // catalog provider does — bundled rows with a custom row of the same id laid
    // over them — because that is the only way a loop reaches the app, and it is
    // the shape a well-meaning refactor of the provider would break.
    const bundled = [
      CatalogNode(id: 'root', parentId: null, name: 'Root', kind: NodeKind.category),
      CatalogNode(id: 'shas', parentId: 'root', name: 'Shas', kind: NodeKind.category),
      CatalogNode(id: 'moed', parentId: 'shas', name: 'Moed', kind: NodeKind.category),
      CatalogNode(
          id: 'shabbos', parentId: 'moed', name: 'Shabbos', kind: NodeKind.leaf,
          unitLabel: UnitLabel.daf, unitCount: 4, unitOffset: 2),
    ];
    const override = CatalogNode(
        id: 'shas', parentId: 'moed', name: 'Shas', kind: NodeKind.category);

    final byId = {for (final n in bundled) n.id: n}..[override.id] = override;
    final catalog = Catalog(byId.values.toList());

    for (final start in catalog.all) {
      var current = start;
      var steps = 0;
      while (current.parentId != null) {
        current = catalog.byId(current.parentId!)!;
        expect(++steps, lessThanOrEqualTo(catalog.all.length),
            reason: 'the chain above ${start.id} does not terminate');
      }
    }
    // And the leaf is still findable from a root, which is the property that
    // matters: a repair that loses the user's sefer is not a repair. Note what
    // is *not* asserted — which node ends up on top. The cut is the lowest id
    // in the ring, so here Moed rises above Shas, and there is no way to cut a
    // ring that keeps everyone's idea of which way up it was.
    expect(
      [for (final r in catalog.roots) ...catalog.leavesUnder(r.id)]
          .map((n) => n.id),
      contains('shabbos'),
    );
  });
}
