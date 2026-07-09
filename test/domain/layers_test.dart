import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/layer_requirements.dart';
import 'package:flutter_test/flutter_test.dart';

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
      final req = LayerRequirements(nodeConfig: {
        'a': {'main', 'rashi'}
      });
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
  });

  group('LayerRequirements resolution', () {
    test('inherits from the nearest configured ancestor', () {
      final req = LayerRequirements(
        nodeConfig: {
          'shas': {'main', 'rashi'}
        },
        parentOf: {'shas': null, 'bavli': 'shas', 'shabbos': 'bavli'},
      );
      expect(req.forNode('shabbos'), {'main', 'rashi'});
    });

    test('a nearer node overrides an ancestor', () {
      final req = LayerRequirements(
        nodeConfig: {
          'shas': {'main', 'rashi'},
          'shabbos': {'main'},
        },
        parentOf: {'shas': null, 'shabbos': 'shas'},
      );
      expect(req.forNode('shabbos'), {'main'});
    });

    test('a per-unit override beats the node set', () {
      final req = LayerRequirements(
        nodeConfig: {
          'a': {'main'}
        },
        unitConfig: {
          'a': {
            5: {'main', 'tosafos'}
          }
        },
      );
      expect(req.forUnit('a', 2), {'main'});
      expect(req.forUnit('a', 5), {'main', 'tosafos'});
    });

    test('unconfigured nodes default to text-only', () {
      final req = LayerRequirements();
      expect(req.forNode('anything'), {'main'});
      expect(req.hasLayers('anything', 0), isFalse);
    });
  });
}
