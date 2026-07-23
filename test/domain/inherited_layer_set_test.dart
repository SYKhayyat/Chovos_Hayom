import 'package:chovos_hayom/domain/usecases/inherited_layer_set.dart';
import 'package:flutter_test/flutter_test.dart';

/// shas -> shas.moed -> shas.moed.shabbos
const _parents = <String, String?>{
  'shas': null,
  'shas.moed': 'shas',
  'shas.moed.shabbos': 'shas.moed',
};

InheritedLayerSet setWith({
  Map<String, Set<String>> nodeConfig = const {},
  Map<String, Map<int, Set<String>>> unitConfig = const {},
  Map<String, String?> parentOf = _parents,
}) =>
    InheritedLayerSet(
      nodeConfig: nodeConfig,
      unitConfig: unitConfig,
      parentOf: parentOf,
      defaultSet: const {'main'},
    );

void main() {
  test('a set pinned high applies all the way down', () {
    // The point of the whole engine: "require Rashi across Shas" is one setting.
    final s = setWith(nodeConfig: {
      'shas': {'main', 'rashi'}
    });
    expect(s.forNode('shas.moed.shabbos'), {'main', 'rashi'});
    expect(s.forUnit('shas.moed.shabbos', 12), {'main', 'rashi'});
  });

  test('a nearer node overrides an ancestor', () {
    final s = setWith(nodeConfig: {
      'shas': {'main', 'rashi'},
      'shas.moed': {'main'},
    });
    expect(s.forNode('shas.moed.shabbos'), {'main'});
  });

  test('a unit override beats its node', () {
    final s = setWith(
      nodeConfig: {
        'shas': {'main', 'rashi'}
      },
      unitConfig: {
        'shas.moed.shabbos': {
          12: {'main'}
        }
      },
    );
    expect(s.forUnit('shas.moed.shabbos', 12), {'main'});
    expect(s.forUnit('shas.moed.shabbos', 13), {'main', 'rashi'});
  });

  test('an explicitly-empty pin means "back to the default here"', () {
    final s = setWith(nodeConfig: {
      'shas': {'main', 'rashi'},
      'shas.moed': <String>{},
    });
    expect(s.forNode('shas.moed.shabbos'), {'main'});
  });

  test('nothing configured anywhere gives the default', () {
    expect(setWith().forNode('shas.moed.shabbos'), {'main'});
  });

  test('an unknown node falls back to the default rather than throwing', () {
    expect(setWith().forNode('who.knows'), {'main'});
  });

  group('malformed hierarchies cannot hang the resolver', () {
    // A cycle here used to recurse forever: an unrecoverable hang on every
    // rebuild, from data that is merely wrong. Import validation and the node
    // editor both prevent one being created, but the resolver must be safe
    // whatever it is handed.
    test('a two-node parent cycle resolves to the default', () {
      final s = setWith(parentOf: const {'a': 'b', 'b': 'a'});
      expect(s.forNode('a'), {'main'});
      expect(s.forNode('b'), {'main'});
    });

    test('a node that is its own parent resolves to the default', () {
      expect(setWith(parentOf: const {'a': 'a'}).forNode('a'), {'main'});
    });

    test('a config inside a cycle is still honoured', () {
      final s = setWith(
        nodeConfig: {
          'b': {'main', 'rashi'}
        },
        parentOf: const {'a': 'b', 'b': 'a'},
      );
      expect(s.forNode('a'), {'main', 'rashi'});
    });

    test('a chain that leads into a cycle does not hang', () {
      final s = setWith(parentOf: const {'x': 'a', 'a': 'b', 'b': 'a'});
      expect(s.forNode('x'), {'main'});
    });
  });

  test('repeated lookups memoize the whole chain', () {
    final s = setWith(nodeConfig: {
      'shas': {'main', 'rashi'}
    });
    final first = s.forNode('shas.moed.shabbos');
    // Same identity, not merely equal — the chain was cached on the way down.
    expect(identical(s.forNode('shas.moed.shabbos'), first), isTrue);
    expect(identical(s.forNode('shas.moed'), first), isTrue);
  });
}
