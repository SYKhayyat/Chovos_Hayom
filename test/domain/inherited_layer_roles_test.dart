import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/usecases/inherited_layer_roles.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/layer_roles_dsl.dart';

/// shas -> shas.moed -> shas.moed.shabbos
const _parents = <String, String?>{
  'shas': null,
  'shas.moed': 'shas',
  'shas.moed.shabbos': 'shas.moed',
};

InheritedLayerRoles setWith({
  Map<String, Map<String, LayerRole>> nodeConfig = const {},
  Map<String, Map<int, Map<String, LayerRole>>> unitConfig = const {},
  Map<String, String?> parentOf = _parents,
}) =>
    InheritedLayerRoles(
      nodeConfig: nodeConfig,
      unitConfig: unitConfig,
      parentOf: parentOf,
    );

void main() {
  test('a config pinned high applies all the way down', () {
    // The point of the whole engine: "require Rashi across Shas" is one setting.
    final s = setWith(nodeConfig: {'shas': roles(required: ['main', 'rashi'])});
    expect(s.forNode('shas.moed.shabbos'), roles(required: ['main', 'rashi']));
    expect(
        s.forUnit('shas.moed.shabbos', 12), roles(required: ['main', 'rashi']));
  });

  test('a nearer node overrides an ancestor', () {
    final s = setWith(nodeConfig: {
      'shas': roles(required: ['main', 'rashi']),
      'shas.moed': roles(required: ['main']),
    });
    expect(s.forNode('shas.moed.shabbos'), roles(required: ['main']));
  });

  test('a unit override beats its node', () {
    final s = setWith(
      nodeConfig: {'shas': roles(required: ['main', 'rashi'])},
      unitConfig: {
        'shas.moed.shabbos': {12: roles(required: ['main'])}
      },
    );
    expect(s.forUnit('shas.moed.shabbos', 12), roles(required: ['main']));
    expect(
        s.forUnit('shas.moed.shabbos', 13), roles(required: ['main', 'rashi']));
  });

  test('the role travels with the id, not just membership', () {
    // The reason this engine resolves a map rather than a set: an ancestor that
    // *requires* Rashi and a child that merely *offers* it are different
    // answers, and two set-resolvers could only express the difference by being
    // pinned at different depths — which is what they used to do.
    final s = setWith(nodeConfig: {
      'shas': roles(required: ['main', 'rashi']),
      'shas.moed': roles(required: ['main'], optional: ['rashi']),
    });
    expect(s.forNode('shas')['rashi'], LayerRole.required);
    expect(s.forNode('shas.moed.shabbos')['rashi'], LayerRole.optional);
  });

  test('an explicitly-empty pin means "back to the default here"', () {
    final s = setWith(nodeConfig: {
      'shas': roles(required: ['main', 'rashi']),
      'shas.moed': const <String, LayerRole>{},
    });
    expect(s.forNode('shas.moed.shabbos'), defaultLayerRoles);
  });

  test('nothing configured anywhere gives the default', () {
    expect(setWith().forNode('shas.moed.shabbos'), defaultLayerRoles);
  });

  test('the default is the text, required — the pre-layers behaviour', () {
    expect(defaultLayerRoles, {mainLayerId: LayerRole.required});
  });

  test('an unknown node falls back to the default rather than throwing', () {
    expect(setWith().forNode('who.knows'), defaultLayerRoles);
  });

  group('malformed hierarchies cannot hang the resolver', () {
    // A cycle here used to recurse forever: an unrecoverable hang on every
    // rebuild, from data that is merely wrong. Import validation and the node
    // editor both prevent one being created, but the resolver must be safe
    // whatever it is handed.
    test('a two-node parent cycle resolves to the default', () {
      final s = setWith(parentOf: const {'a': 'b', 'b': 'a'});
      expect(s.forNode('a'), defaultLayerRoles);
      expect(s.forNode('b'), defaultLayerRoles);
    });

    test('a node that is its own parent resolves to the default', () {
      expect(setWith(parentOf: const {'a': 'a'}).forNode('a'),
          defaultLayerRoles);
    });

    test('a config inside a cycle is still honoured', () {
      final s = setWith(
        nodeConfig: {'b': roles(required: ['main', 'rashi'])},
        parentOf: const {'a': 'b', 'b': 'a'},
      );
      expect(s.forNode('a'), roles(required: ['main', 'rashi']));
    });

    test('a chain that leads into a cycle does not hang', () {
      final s = setWith(parentOf: const {'x': 'a', 'a': 'b', 'b': 'a'});
      expect(s.forNode('x'), defaultLayerRoles);
    });
  });

  group('pinnedSource distinguishes "set here" from "inherited" from "default"',
      () {
    test('names the nearest configured ancestor, or the node itself', () {
      final s =
          setWith(nodeConfig: {'shas': roles(required: ['main', 'rashi'])});
      expect(s.pinnedSource('shas.moed.shabbos'), 'shas');
      expect(s.pinnedSource('shas'), 'shas');
    });

    test('is null when nothing is configured up the chain', () {
      expect(setWith().pinnedSource('shas.moed.shabbos'), isNull);
    });

    test('terminates on a parent cycle rather than hanging', () {
      final s = setWith(parentOf: const {'a': 'b', 'b': 'a'});
      expect(s.pinnedSource('a'), isNull);
    });
  });

  test('repeated lookups memoize the whole chain', () {
    final s = setWith(nodeConfig: {'shas': roles(required: ['main', 'rashi'])});
    final first = s.forNode('shas.moed.shabbos');
    // Same identity, not merely equal — the chain was cached on the way down.
    expect(identical(s.forNode('shas.moed.shabbos'), first), isTrue);
    expect(identical(s.forNode('shas.moed'), first), isTrue);
  });
}
