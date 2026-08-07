import 'dart:convert';
import 'dart:io';

import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/usecases/layer_roles.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/layer_roles_dsl.dart';
import '../support/source_scan.dart';

/// The rule this file enforces: **a layer's role is one answer, stored once and
/// resolved once.**
///
/// It used to be two booleans in two tables — *required* and *offered* — with an
/// invariant (required implies offered) that no type expressed. Four states for
/// a three-state answer, and the fourth was repaired by hand at three write
/// sites and re-united (`offered ∪ required`) at four read sites, one of which
/// never went through the class written to reconcile them. The split was
/// replicated through six layers: schema, repository, domain, application,
/// backup and UI.
///
/// Every one of those places is now a single thing. Prose saying so would not
/// fail CI; the two halves of this file do.
void main() {
  group('the split does not grow back', () {
    /// Shapes that only exist if the two-set model is being rebuilt. Each comes
    /// with a sample so the guard cannot rot into a regex matching nothing —
    /// the failure mode of every source-scanning check ever written.
    const bans = <({String why, String pattern, String sample})>[
      (
        why: 'a second resolver over the same tree — one existed, and two '
            'resolvers pinned at different depths is how a node came to '
            'require a meforish it did not offer',
        pattern: r'class\s+OfferedLayers|class\s+LayerRequirements|'
            r'class\s+UnitLayerView',
        sample: 'class OfferedLayers {',
      ),
      (
        why: 'a second stream/table of layer settings — one entry carries a '
            'scope whole answer, so there is nothing to pair a write with',
        pattern: r'watchOfferedLayers|setOfferedLayers|clearOfferedLayers|'
            r'watchLayerRequirements|setLayerRequirement|clearLayerRequirement|'
            r'offered_layer_configs|required_layer_configs',
        sample: 'Stream<List<LayerConfigEntry>> watchOfferedLayers(String p);',
      ),
      (
        why: 'reconciles two sets at a call site — LayerRoles.checkableFor '
            'answers this, and the copies that did it by hand are exactly the '
            'ones that disagreed',
        pattern: r'\.\.\.offered[^,]*,\s*\.\.\.required|'
            r'offered\.forNode|offered\.forUnit',
        sample: 'final show = {...offered.forNode(id), ...required};',
      ),
    ];

    /// The migration is the one place the dead table names must still appear —
    /// it is what reads them for the last time.
    const exempt = {'lib/data/drift/database.dart'};

    /// A line that genuinely needs one of these shapes marks itself and is
    /// skipped, the way every other guard in this suite works.
    ///
    /// This file did not have one. Its scanner was a copy of the others' with
    /// the escape-hatch check quietly dropped, so the rule below was a wall
    /// while its neighbours were speed bumps and nothing said so — which is
    /// what a rule written out five times gets you. The shared scanner in
    /// `source_scan.dart` takes the marker as a required argument for exactly
    /// that reason: a guard cannot forget to have one.
    const escapeHatch = 'layer-role: ok';

    test('the regexes actually match the shapes they ban', () {
      for (final ban in bans) {
        expect(RegExp(ban.pattern).hasMatch(ban.sample), isTrue,
            reason: 'the pattern for "${ban.why}" no longer matches its own '
                'sample, so it is guarding nothing');
      }
    });

    test('no file under lib/ rebuilds the required/offered split', () {
      final offences = <String>[];
      var scanned = 0;
      for (final rel in dartSourcesUnder()) {
        if (exempt.contains(rel)) continue;
        scanned++;
        for (final line in codeLines(File(rel).readAsStringSync(),
            escapeHatch: escapeHatch)) {
          for (final ban in bans) {
            if (RegExp(ban.pattern).hasMatch(line.text)) {
              offences.add('$rel:${line.line} — ${ban.why}\n    ${line.text.trim()}');
            }
          }
        }
      }
      expect(scanned, greaterThan(50),
          reason: 'the scan found almost nothing to read, so it is not '
              'guarding the tree it thinks it is');
      expect(offences, isEmpty,
          reason: 'these rebuild the two-set model:\n${offences.join('\n')}');
    });
  });

  group('a screen does not work out a unit\'s mefarshim for itself', () {
    /// The second half of the same rule, one layer up.
    ///
    /// The roles are resolved once — that is the group above. *Which mefarshim
    /// to show for this unit, and in what state* was then worked out from those
    /// roles and the fold separately by four screens, and they disagreed on the
    /// case that matters: a meforish learned on a unit and turned off or
    /// deleted since.
    ///
    /// The chazara sheet's version filtered its options through the mefarshim
    /// list while seeding its selection from the log, so such a layer was
    /// **selected and invisible** — submitted with no checkbox to untick it
    /// from. `UnitMefarshim` answers it once and hands out named slices;
    /// `unit_mefarshim_test.dart` holds each of them.
    const escapeHatch = 'unit-mefarshim: ok';

    /// Where the question is allowed to be asked from first principles.
    const home = 'lib/domain/usecases/unit_mefarshim.dart';

    const bans = <({String why, String pattern, String sample})>[
      (
        why: 'reads the log\'s per-unit layers inside features/ — that is one '
            'half of the question UnitMefarshim answers, and every screen that '
            'took just this half got the deleted-meforish case wrong',
        pattern: r'\.completedLayers\(',
        sample: 'final learned = fold.completedLayers(node.id, unit);',
      ),
      (
        why: 'reads a unit\'s required set inside features/ — the other half',
        pattern: r'\.requiredFor\(',
        sample: 'final required = roles.requiredFor(node.id, unit);',
      ),
    ];

    // `forUnit` is deliberately **not** banned, and not by oversight. On its
    // own it is a role map with no done-state in it, so it cannot produce a
    // checklist without the first ban above — and the name collides with
    // `UnitHistoryFinder.forUnit`, which is a different question about the same
    // two arguments. A pattern that catches both is a pattern that has to be
    // argued with rather than obeyed.
    //
    // `checkableForNode` is likewise allowed: the bulk sheet and the tree's
    // coverage bars ask about a *node*, where there is no unit and no fold, and
    // that genuinely is a different question.

    test('the regexes actually match the shapes they ban', () {
      for (final ban in bans) {
        expect(RegExp(ban.pattern).hasMatch(ban.sample), isTrue,
            reason: 'the pattern for "${ban.why}" no longer matches its own '
                'sample, so it is guarding nothing');
      }
    });

    test('the question still has somewhere to be asked', () {
      expect(File(home).existsSync(), isTrue);
    });

    test('nothing under features/ builds the answer itself', () {
      final offences = <String>[];
      var scanned = 0;
      for (final rel in dartSourcesUnder('lib/features')) {
        scanned++;
        for (final line in codeLines(File(rel).readAsStringSync(),
            escapeHatch: escapeHatch)) {
          for (final ban in bans) {
            if (!RegExp(ban.pattern).hasMatch(line.text)) continue;
            offences.add('$rel:${line.line} — ${ban.why}\n'
                '    ${line.text.trim()}');
          }
        }
      }

      expect(scanned, greaterThan(20),
          reason: 'the scan found almost nothing to read, so it is not '
              'guarding the tree it thinks it is');
      expect(offences, isEmpty,
          reason: 'ask UnitMefarshim.of(...) and take the slice you want — '
              '`checkable` to log, `reviewable` for a chazara, `all` for the '
              'checklist:\n${offences.join('\n')}');
    });
  });

  group('every role survives the round trip', () {
    // The silent rot mode: someone adds a third role, and it reads back as
    // `optional` because a decoder was not updated. Nothing throws; a required
    // meforish quietly stops gating completion, and units the user has not
    // finished start showing as done. These iterate `LayerRole.values`, so
    // adding a value without teaching the codecs about it fails the build.

    test('every role survives LayerRole.fromName', () {
      for (final role in LayerRole.values) {
        expect(LayerRole.fromName(role.name), role,
            reason: '${role.name} does not read back as itself');
      }
    });

    test('every role survives the backup JSON round trip', () {
      final entry = LayerConfigEntry(
        nodeId: 'shas',
        unitIndex: -1,
        roles: {
          for (final (i, role) in LayerRole.values.indexed) 'layer$i': role,
        },
      );
      final back = LayerConfigEntry.fromJson(
          jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>);
      expect(back.roles, entry.roles);
      expect(back.nodeId, entry.nodeId);
      expect(back.unitIndex, entry.unitIndex);
    });

    test('an unknown role reads as optional rather than gating completion', () {
      // The safe direction: a config naming a role this build does not know
      // should stay tickable, not silently start deciding whether a unit is
      // done.
      final back = LayerConfigEntry.fromJson(const {
        'nodeId': 'shas',
        'unitIndex': -1,
        'roles': {'rashi': 'whatever-comes-next'},
      });
      expect(back.roles['rashi'], LayerRole.optional);
    });

    test('a legacy backup array reads back under the role it came from', () {
      // Pre-v5 backups have two arrays where membership was the whole meaning.
      // Reading `requirements` as optional un-completes the user's tree.
      final req = LayerConfigEntry.fromJson(
          const {'nodeId': 'shas', 'unitIndex': -1, 'layers': ['main']},
          legacyRole: LayerRole.required);
      final off = LayerConfigEntry.fromJson(
          const {'nodeId': 'shas', 'unitIndex': -1, 'layers': ['maharsha']},
          legacyRole: LayerRole.optional);
      expect(req.roles, {'main': LayerRole.required});
      expect(off.roles, {'maharsha': LayerRole.optional});
    });
  });

  test('a required layer is checkable, with no reconciliation step', () {
    // The invariant the two-boolean model could break and had to repair. It is
    // not enforced here — it is unrepresentable, because there is one entry per
    // layer. This asserts that the type still has that property.
    final r = LayerRoles(nodeConfig: {
      'shas': roles(required: ['main', 'rashi'], optional: ['maharsha'])
    });
    for (final id in r.requiredFor('shas', 0)) {
      expect(r.forUnit('shas', 0).keys, contains(id));
    }
    expect(r.forUnit('shas', 0).keys, {'main', 'rashi', 'maharsha'});
  });
}
