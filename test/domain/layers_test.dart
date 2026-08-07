import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/layer_roles.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/layer_roles_dsl.dart';

LearningEvent ev(
  EventAction action, {
  int seq = 0,
  int unit = 2,
  String node = 'a',
  List<String> layers = const ['main'],
}) {
  final t = DateTime(2026, 1, 1).add(Duration(seconds: seq));
  return LearningEvent(
    id: '$node-$unit-${action.name}-$seq-${layers.join()}',
    profileId: 'p',
    nodeId: node,
    unitIndex: unit,
    action: action,
    occurredAt: t,
    loggedAt: t,
    layers: layers,
  );
}

void main() {
  group('layer-aware fold', () {
    test('completedLayers accumulates across done events', () {
      final fold = FoldLog.fold([
        ev(EventAction.done, seq: 0, layers: ['main']),
        ev(EventAction.done, seq: 1, layers: ['rashi']),
      ]);
      expect(fold.completedLayers('a', 2), {'main', 'rashi'});
    });

    test('a unit is done only when every required layer is present', () {
      final req = LayerRoles(
          nodeConfig: {'a': roles(required: ['main', 'rashi'])});
      final partial = FoldLog.fold([ev(EventAction.done, layers: ['main'])]);
      expect(partial.doneUnits('a', req), isEmpty);

      final full = FoldLog.fold([
        ev(EventAction.done, seq: 0, layers: ['main']),
        ev(EventAction.done, seq: 1, layers: ['rashi']),
      ]);
      expect(full.doneUnits('a', req), {2});
    });

    test('with no resolver, text alone completes a unit (legacy behavior)', () {
      final fold = FoldLog.fold([ev(EventAction.done, layers: ['main'])]);
      expect(fold.doneUnits('a'), {2});
    });

    test('undone removes only the named layers', () {
      final fold = FoldLog.fold([
        ev(EventAction.done, seq: 0, layers: ['main', 'rashi']),
        ev(EventAction.undone, seq: 1, layers: ['rashi']),
      ]);
      expect(fold.completedLayers('a', 2), {'main'});
    });

    test('un-ticking one meforish keeps the unit’s date, chazaras and haara', () {
      // The data-loss trap: un-marking an *optional* meforish wiped the review
      // count, the learned-on date and the haara of a unit that is still done.
      final fold = FoldLog.fold([
        LearningEvent(
          id: 'd0',
          profileId: 'p',
          nodeId: 'a',
          unitIndex: 2,
          action: EventAction.done,
          occurredAt: DateTime(2026, 1, 1),
          loggedAt: DateTime(2026, 1, 1),
          layers: const ['main', 'rashi', 'tosafos'],
          note: 'a chiddush',
          durationMin: 45,
        ),
        ev(EventAction.reviewed, seq: 1, unit: 2),
        ev(EventAction.reviewed, seq: 2, unit: 2),
        // Un-tick only Tosafos — main and rashi survive.
        ev(EventAction.undone, seq: 3, unit: 2, layers: ['tosafos']),
      ]);

      expect(fold.completedLayers('a', 2), {'main', 'rashi'});
      expect(fold.reviewCount('a', 2), 2, reason: 'chazaras must not vanish');
      expect(fold.doneAt('a', 2), isNotNull, reason: 'the learned-on date survives');
      expect(fold.touchedAt('a', 2), isNotNull);
      expect(fold.isAnnotated('a', 2), isTrue, reason: 'the haara survives');
    });

    test('un-ticking the last meforish clears the unit’s history', () {
      // A *full* un-mark still resets everything, so a later re-mark starts fresh.
      final fold = FoldLog.fold([
        LearningEvent(
          id: 'd0',
          profileId: 'p',
          nodeId: 'a',
          unitIndex: 2,
          action: EventAction.done,
          occurredAt: DateTime(2026, 1, 1),
          loggedAt: DateTime(2026, 1, 1),
          layers: const ['main', 'rashi'],
          note: 'note',
          durationMin: 10,
        ),
        ev(EventAction.reviewed, seq: 1, unit: 2),
        ev(EventAction.undone, seq: 2, unit: 2, layers: ['main', 'rashi']),
      ]);

      expect(fold.completedLayers('a', 2), isEmpty);
      expect(fold.reviewCount('a', 2), 0);
      expect(fold.doneAt('a', 2), isNull);
      expect(fold.touchedAt('a', 2), isNull);
      expect(fold.isAnnotated('a', 2), isFalse);
    });
  });

  group('LayerRoles resolution', () {
    test('inherits from the nearest configured ancestor', () {
      final r = LayerRoles(
        nodeConfig: {'shas': roles(required: ['main', 'rashi'])},
        parentOf: {'shas': null, 'bavli': 'shas', 'shabbos': 'bavli'},
      );
      expect(r.requiredForNode('shabbos'), {'main', 'rashi'});
    });

    test('a nearer node overrides an ancestor', () {
      final r = LayerRoles(
        nodeConfig: {
          'shas': roles(required: ['main', 'rashi']),
          'shabbos': roles(required: ['main']),
        },
        parentOf: {'shas': null, 'shabbos': 'shas'},
      );
      expect(r.requiredForNode('shabbos'), {'main'});
    });

    test('a per-unit override beats the node config', () {
      final r = LayerRoles(
        nodeConfig: {'a': roles(required: ['main'])},
        unitConfig: {
          'a': {5: roles(required: ['main', 'tosafos'])}
        },
      );
      expect(r.requiredFor('a', 2), {'main'});
      expect(r.requiredFor('a', 5), {'main', 'tosafos'});
    });

    test('unconfigured nodes default to text-only', () {
      final r = LayerRoles();
      expect(r.requiredForNode('anything'), {'main'});
      expect(r.checkableForNode('anything'), {'main'});
      expect(r.isLayered('anything', 0), isFalse);
    });
  });

  // This group is what `offered_layers_test.dart` and the `UnitLayerView` half
  // of this file used to prove separately, about two resolvers that had to be
  // kept in step. It is one resolver now, so it is one group.
  group('optional vs required', () {
    test('checkable includes optional; done depends only on required', () {
      final r = LayerRoles(
          nodeConfig: {
            'a': roles(required: ['main'], optional: ['rashi'])
          });

      expect(r.requiredFor('a', 2), {'main'});
      expect(r.forUnit('a', 2).keys, {'main', 'rashi'});
      // An optional meforish still makes the unit layered (shows a checklist).
      expect(r.isLayered('a', 2), isTrue);

      // Learning only the text completes the unit — the optional rashi does not
      // gate it...
      final textOnly = FoldLog.fold([ev(EventAction.done, layers: ['main'])]);
      expect(textOnly.doneUnits('a', r), {2});
      // ...and the fraction, which tracks only required, reads full.
      expect(r.fraction('a', 2, textOnly), 1.0);
    });

    test('a required layer is checkable by construction', () {
      // The old model could express "required but not offered" — a fourth state
      // that meant nothing — and every reader had to repair it with
      // `offered ∪ required`. A role map has one entry per layer, so a required
      // layer is in the map, so it is checkable. There is nothing to reconcile.
      final r = LayerRoles(
          nodeConfig: {
            'a': roles(required: ['main', 'tosafos'])
          });
      expect(r.forUnit('a', 2).keys.toSet().containsAll(r.requiredFor('a', 2)),
          isTrue);
      expect(r.forUnit('a', 2).keys, {'main', 'tosafos'});
    });

    test('text-only unit is not layered', () {
      expect(LayerRoles().isLayered('a', 2), isFalse);
    });

    test('an all-optional node completes on nothing', () {
      // Nothing required means nothing gates completion, and `fraction` must not
      // divide by zero on the way to saying so.
      final r = LayerRoles(
          nodeConfig: {
            'a': roles(optional: ['rashi', 'tosafos'])
          });
      final none = FoldLog.fold(<LearningEvent>[]);
      expect(r.requiredFor('a', 2), isEmpty);
      expect(r.fraction('a', 2, none), 0.0);
    });
  });
}
