import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/source_scan.dart';

/// The rule this file enforces: **there is one way to offer the catalog to a
/// user, and it lives in `node_picker.dart`.**
///
/// There were four, and the differences between them were not choices. Two
/// `SimpleDialog`s with different hard-coded widths — 320 and 340 — one of them
/// carrying a comment that said "see the same clamp in cycles_screen.dart"
/// beside a number that was not the same clamp. Both wider than the 240dp
/// screen the app is built for. And the fourth, the node editor's parent
/// dropdown, had neither the qualifier nor the localized sort the other three
/// had spent three comments explaining, so a Hebrew reader picking a parent got
/// an English-ordered list of four identical rows reading "שבת".
///
/// The rule that keeps that from coming back is not "do not paste a dialog". It
/// is that the three decisions with a right answer — which nodes, in what
/// order, under what label — are made in one file, so a fifth picker inherits
/// them instead of re-deciding them.
///
/// **The one deliberate exception is the search delegate**, and it is named
/// here rather than left to be rediscovered. Search *navigates* rather than
/// returning a node, and it splits the qualifier into a subtitle beside the
/// unit count instead of folding it into the title — which is the better shape
/// for a result list and the wrong one for a one-line dropdown.
void main() {
  const escapeHatch = 'node-picker: ok';
  const home = 'lib/features/common/node_picker.dart';
  const naming = 'lib/features/common/naming.dart';

  const bans = <({String why, String pattern, String sample, Set<String> allow})>[
    (
      why: 'hand-rolls a picker dialog — showNodePicker owns the one clamp, '
          'and both copies of it were wider than the screen',
      pattern: r'\bSimpleDialog\(',
      sample: '      builder: (ctx) => SimpleDialog(title: Text(t)),',
      allow: {home},
    ),
    (
      why: 'builds a node list label itself — nodeChoices is what decides that '
          'a flat list of nodes is qualified, and the picker that skipped it '
          'is the one that shipped four indistinguishable rows',
      pattern: r'\bqualifiedNodeName\(',
      sample: 'title: Text(qualifiedNodeName(l10n, catalog, n)),',
      allow: {home, naming},
    ),
    (
      why: 'hand-rolls a node dropdown — NodeDropdown carries the indent, the '
          'ellipsis and the fallback for a value the list no longer contains',
      pattern: r'DropdownButtonFormField<String',
      sample: 'DropdownButtonFormField<String?>(initialValue: _parentId,',
      allow: {home},
    ),
  ];

  test('the regexes actually match the shapes they ban', () {
    for (final ban in bans) {
      expect(RegExp(ban.pattern).hasMatch(ban.sample), isTrue,
          reason: 'the pattern for "${ban.why}" no longer matches its own '
              'sample, so it is guarding nothing');
    }
  });

  test('the picker still exists to be the exception', () {
    expect(File(home).existsSync(), isTrue);
  });

  test('the search delegate is still the named exception, and still different',
      () {
    const search = 'lib/features/search/catalog_search_delegate.dart';
    final source = File(search).readAsStringSync();

    // If search ever starts folding the qualifier into its title, it has become
    // a picker row and should be one — so this assertion failing is a prompt to
    // delete the exception, not to widen it.
    expect(source.contains('nodePath('), isTrue,
        reason: '$search is excused from these rules because it puts the '
            'qualifier in a subtitle beside the unit count. If it stopped '
            'doing that, the exception has outlived its reason.');
    expect(source.contains('qualifiedNodeName('), isFalse);
  });

  test('lib/ offers the catalog in exactly one place', () {
    final violations = <String>[];

    for (final path in dartSourcesUnder()) {
      final lines =
          codeLines(File(path).readAsStringSync(), escapeHatch: escapeHatch);
      for (final ban in bans) {
        if (ban.allow.contains(path)) continue;
        for (final line in lines) {
          if (!RegExp(ban.pattern).hasMatch(line.text)) continue;
          violations.add('$path:${line.line} ${ban.why}\n'
              '    ${line.text.trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Picking a node out of the catalog is built in '
          '$home.\n\n${violations.join('\n')}\n\n'
          'If a line genuinely needs the shape, mark it '
          '`// $escapeHatch — <reason>`.',
    );
  });
}
